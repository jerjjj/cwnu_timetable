mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod api;
// 西华师范大学教务系统课表获取库
//
// 用法:
// ```no_run
// use get_timetable::get_timetable;
// let data = get_timetable("学号", "门户密码", "", "", 241, 2, 15).unwrap();
// println!("{}", serde_json::to_string_pretty(&data).unwrap());
// ```

use std::collections::HashMap;
use std::io;
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use aes::cipher::{block_padding::Pkcs7, BlockEncryptMut, KeyIvInit};
use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use rand::Rng;
use regex::Regex;
use reqwest::blocking::Client;
use reqwest::header::{ACCEPT, ACCEPT_LANGUAGE, ORIGIN, REFERER};
use scraper::{Html, Selector};
use serde_json::Value;
use sha1::{Digest, Sha1};
use thiserror::Error;
use url::Url;

// ---------------------------------------------------------------------------
// 常量
// ---------------------------------------------------------------------------

const AES_CHARS: &[u8] = b"ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678";
const SSO_URL: &str = "https://webvpn.cwnu.edu.cn/";
const VPN_MARKER: &str = "vpn-12-o2-jwxt.cwnu.edu.cn";

/// WebVPN 教务代理根地址
pub const JWXT_APP_BASE: &str =
    "https://webvpn.cwnu.edu.cn/https\
     /77726476706e69737468656265737421fae0598869337f5e6b468ca88d1b203b";

// ---------------------------------------------------------------------------
// 错误类型
// ---------------------------------------------------------------------------

#[derive(Error, Debug)]
pub enum TimetableError {
    #[error("HTTP 请求失败: {0}")]
    Http(#[from] reqwest::Error),

    #[error("SSO 登录失败: {0}")]
    SsoLogin(String),

    #[error("教务系统登录失败: {0}")]
    JwxtLogin(String),

    #[error("页面解析失败: {0}")]
    Parse(String),

    #[error("加密错误: {0}")]
    Crypto(String),

    #[error("IO 错误: {0}")]
    Io(#[from] io::Error),
}

pub type Result<T> = std::result::Result<T, TimetableError>;

// ---------------------------------------------------------------------------
// 内部工具函数
// ---------------------------------------------------------------------------

fn random_str(n: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..n)
        .map(|_| AES_CHARS[rng.gen_range(0..AES_CHARS.len())] as char)
        .collect()
}

/// AES-CBC + PKCS7 + Base64，对齐 SSO 前端逻辑：random64 + password
fn encrypt_password(plain: &str, salt: &str) -> Result<String> {
    let data = format!("{}{}", random_str(64), plain);
    let key = salt.trim().as_bytes();
    let iv_str = random_str(16);
    let iv = iv_str.as_bytes();

    let ct: Vec<u8> = match key.len() {
        16 => {
            type E = cbc::Encryptor<aes::Aes128>;
            E::new_from_slices(key, iv)
                .map_err(|e| TimetableError::Crypto(e.to_string()))?
                .encrypt_padded_vec_mut::<Pkcs7>(data.as_bytes())
        }
        24 => {
            type E = cbc::Encryptor<aes::Aes192>;
            E::new_from_slices(key, iv)
                .map_err(|e| TimetableError::Crypto(e.to_string()))?
                .encrypt_padded_vec_mut::<Pkcs7>(data.as_bytes())
        }
        32 => {
            type E = cbc::Encryptor<aes::Aes256>;
            E::new_from_slices(key, iv)
                .map_err(|e| TimetableError::Crypto(e.to_string()))?
                .encrypt_padded_vec_mut::<Pkcs7>(data.as_bytes())
        }
        n => {
            return Err(TimetableError::Crypto(format!(
                "不支持的 AES 密钥长度: {} 字节",
                n
            )))
        }
    };

    Ok(BASE64.encode(&ct))
}

fn sha1_hex(s: &str) -> String {
    let mut h = Sha1::new();
    h.update(s.as_bytes());
    format!("{:x}", h.finalize())
}

fn url_origin(url_str: &str) -> String {
    let Ok(u) = Url::parse(url_str) else {
        return String::new();
    };
    let port_part = u.port().map(|p| format!(":{}", p)).unwrap_or_default();
    format!("{}://{}{}", u.scheme(), u.host_str().unwrap_or(""), port_part)
}

fn resolve_url(base: &str, relative: &str) -> String {
    Url::parse(base)
        .ok()
        .and_then(|b| b.join(relative).ok())
        .map(|u| u.to_string())
        .unwrap_or_else(|| relative.to_owned())
}

fn get_query_param(url_str: &str, key: &str) -> Option<String> {
    Url::parse(url_str)
        .ok()?
        .query_pairs()
        .find(|(k, _)| k.as_ref() == key)
        .map(|(_, v)| v.into_owned())
}

fn add_or_replace_query(base_url: &str, key: &str, value: &str) -> String {
    let Ok(mut parsed) = Url::parse(base_url) else {
        return base_url.to_owned();
    };
    let pairs: Vec<(String, String)> = parsed
        .query_pairs()
        .filter(|(k, _)| k.as_ref() != key)
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    {
        let mut qp = parsed.query_pairs_mut();
        qp.clear();
        for (k, v) in &pairs {
            qp.append_pair(k, v);
        }
        qp.append_pair(key, value);
    }
    parsed.to_string()
}

fn context_path_from_url(post_url: &str) -> String {
    let path = Url::parse(post_url)
        .map(|u| u.path().to_owned())
        .unwrap_or_default();
    if let Some(idx) = path.rfind("/login") {
        if idx > 0 {
            return path[..idx].to_owned();
        }
    }
    "/authserver".to_owned()
}

fn unix_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

fn is_login_page(html: &str) -> bool {
    ["账号登录", "请输入密码", "authserver/login", "passwordText"]
        .iter()
        .any(|&k| html.contains(k))
}

// ---------------------------------------------------------------------------
// SSO 登录（WebVPN）
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// SSO 会话状态（两阶段登录）
// ---------------------------------------------------------------------------

/// SSO 登录第一阶段产生的会话状态，可跨线程传递。
pub struct SsoLoginSession {
    client: Client,
    post_url: String,
    payload: HashMap<String, String>,
    origin: String,
    timeout: Duration,
}

// SAFETY: reqwest::blocking::Client is Send + Sync, all other fields are Send + Sync.
unsafe impl Send for SsoLoginSession {}
unsafe impl Sync for SsoLoginSession {}

/// 全局挂起的 SSO 会话（用于 Flutter 侧两阶段登录）
static PENDING_SSO: Mutex<Option<SsoLoginSession>> = Mutex::new(None);

// ---------------------------------------------------------------------------
// SSO 登录（WebVPN）
// ---------------------------------------------------------------------------

/// Phase 1：初始化 SSO 登录，检查验证码需求。
/// 返回会话状态；若需要验证码，同时返回验证码图片字节。
pub fn sso_login_phase1(
    username: &str,
    password: &str,
    timeout: Duration,
) -> Result<(SsoLoginSession, Option<Vec<u8>>)> {
    let client = Client::builder()
        .cookie_store(true)
        .user_agent("Mozilla/5.0")
        .redirect(reqwest::redirect::Policy::limited(30))
        .http1_only()
        .build()
        .map_err(TimetableError::Http)?;

    let origin = url_origin(SSO_URL);

    // 1. 获取登录页
    let resp = client
        .get(SSO_URL)
        .timeout(timeout)
        .header(ACCEPT, "text/html,application/xhtml+xml,*/*;q=0.8")
        .header(ACCEPT_LANGUAGE, "zh-CN,zh;q=0.9")
        .header(ORIGIN, &origin)
        .header(REFERER, SSO_URL)
        .send()?;
    resp.error_for_status_ref()?;
    let final_url = resp.url().to_string();
    let html = resp.text()?;
    let doc = Html::parse_document(&html);

    // 2. 解析登录表单
    let form_sel = Selector::parse("form#pwdFromId").unwrap();
    let all_form_sel = Selector::parse("form").unwrap();
    let form_el = doc
        .select(&form_sel)
        .next()
        .or_else(|| {
            doc.select(&all_form_sel).find(|f| {
                f.value()
                    .attr("action")
                    .map_or(false, |a| a.contains("authserver/login"))
            })
        })
        .ok_or_else(|| TimetableError::Parse("未找到 SSO 登录表单".to_owned()))?;

    // 3. 获取 pwdEncryptSalt
    let salt_sel = Selector::parse("#pwdEncryptSalt").unwrap();
    let salt = doc
        .select(&salt_sel)
        .next()
        .and_then(|e| e.value().attr("value"))
        .filter(|s| !s.is_empty())
        .ok_or_else(|| TimetableError::Parse("未找到 pwdEncryptSalt".to_owned()))?
        .to_owned();

    // 4. 构建 POST URL
    let action = form_el
        .value()
        .attr("action")
        .ok_or_else(|| TimetableError::Parse("表单缺少 action".to_owned()))?;
    let mut post_url = resolve_url(&final_url, action);

    // 5. 提取 service（先从 URL 参数，再从页面 JS）
    let service = get_query_param(SSO_URL, "service").unwrap_or_default();
    let service = if service.is_empty() {
        Regex::new(r#"var\s+service\s*=\s*\[\s*"([^"]*)"\s*\]"#)
            .ok()
            .and_then(|re| re.captures(&html))
            .and_then(|c| c.get(1))
            .map(|m| m.as_str().replace(r"\/", "/"))
            .unwrap_or_default()
    } else {
        service
    };
    if !service.is_empty() && !post_url.contains("service=") {
        post_url = add_or_replace_query(&post_url, "service", &service);
    }

    // 6. 收集表单隐藏字段
    let input_sel = Selector::parse("input").unwrap();
    let mut payload: HashMap<String, String> = HashMap::new();
    for inp in form_el.select(&input_sel) {
        if let Some(name) = inp.value().attr("name") {
            payload.insert(
                name.to_owned(),
                inp.value().attr("value").unwrap_or("").to_owned(),
            );
        }
    }
    payload.insert("username".to_owned(), username.to_owned());
    payload.insert("password".to_owned(), encrypt_password(password, &salt)?);
    payload
        .entry("_eventId".to_owned())
        .or_insert_with(|| "submit".to_owned());
    payload
        .entry("cllt".to_owned())
        .or_insert_with(|| "userNameLogin".to_owned());
    payload
        .entry("dllt".to_owned())
        .or_insert_with(|| "generalLogin".to_owned());
    if payload.contains_key("passwordText") {
        payload.insert("passwordText".to_owned(), String::new());
    }

    // 7. 检查是否需要图形验证码
    let ctx = context_path_from_url(&post_url);
    let captcha_check_url = format!("{}{}/checkNeedCaptcha.htl", origin, ctx);
    let need_captcha = client
        .get(&captcha_check_url)
        .timeout(timeout)
        .query(&[("username", username)])
        .send()
        .ok()
        .and_then(|r| r.json::<Value>().ok())
        .and_then(|v| v.get("isNeed").and_then(Value::as_bool))
        .unwrap_or(false);

    let captcha_bytes = if need_captcha {
        let img_url = format!("{}{}/getCaptcha.htl?{}", origin, ctx, unix_millis());
        client
            .get(&img_url)
            .timeout(timeout)
            .send()
            .ok()
            .and_then(|r| r.bytes().ok())
            .map(|b| b.to_vec())
    } else {
        None
    };

    let session = SsoLoginSession {
        client,
        post_url,
        payload,
        origin,
        timeout,
    };
    Ok((session, captcha_bytes))
}

/// Phase 2：完成 SSO 登录 POST，返回持有 cookie 的 Client。
/// `captcha` 传空字符串表示无需验证码。
pub fn sso_login_phase2(mut session: SsoLoginSession, captcha: &str) -> Result<Client> {
    if !captcha.is_empty() {
        session.payload.insert("captcha".to_owned(), captcha.to_owned());
    }
    let resp = session
        .client
        .post(&session.post_url)
        .timeout(session.timeout)
        .header(ACCEPT, "text/html,application/xhtml+xml,*/*;q=0.8")
        .header(ACCEPT_LANGUAGE, "zh-CN,zh;q=0.9")
        .header(ORIGIN, &session.origin)
        .header(REFERER, SSO_URL)
        .form(&session.payload)
        .send()?;
    resp.error_for_status_ref()?;
    let body = resp.text()?;
    if is_login_page(&body) {
        return Err(TimetableError::SsoLogin(
            "SSO 登录失败：仍在登录页，请检查账号密码".to_owned(),
        ));
    }
    Ok(session.client)
}

// 内部便捷包装：无验证码直接完成登录（自动刷新路径使用）
fn sso_login(username: &str, password: &str, timeout: Duration) -> Result<Client> {
    let (session, captcha_bytes) = sso_login_phase1(username, password, timeout)?;
    if captcha_bytes.is_some() {
        return Err(TimetableError::SsoLogin(
            "SSO 登录需要图形验证码，请使用「登录」页面完成验证".to_owned(),
        ));
    }
    sso_login_phase2(session, "")
}

// ---------------------------------------------------------------------------
// JWXT 本地登录（salt + SHA1）
// ---------------------------------------------------------------------------

fn jwxt_do_post(
    client: &Client,
    login_url: &str,
    refer_url: &str,
    username: &str,
    encrypted: &str,
    captcha: &str,
    timeout: Duration,
) -> Result<Value> {
    let body = serde_json::json!({
        "username": username,
        "password": encrypted,
        "captcha": captcha,
    });
    let resp = client
        .post(login_url)
        .timeout(timeout)
        .header(REFERER, refer_url)
        .json(&body)
        .send()?;
    resp.error_for_status_ref()?;
    resp.json::<Value>()
        .map_err(|e| TimetableError::JwxtLogin(format!("响应非 JSON: {}", e)))
}

fn jwxt_login(
    client: &Client,
    refer_url: &str,
    username: &str,
    password: &str,
    timeout: Duration,
) -> Result<()> {
    let salt_url = format!("{}/student/login-salt", JWXT_APP_BASE);
    let login_url = format!("{}/student/login", JWXT_APP_BASE);

    // 获取盐值
    let raw = client.get(&salt_url).timeout(timeout).send()?.text()?;
    let salt = raw.trim();
    if salt.is_empty() {
        return Err(TimetableError::JwxtLogin("未获取到教务登录盐值".to_owned()));
    }

    // SHA1(salt-password)
    let encrypted = sha1_hex(&format!("{}-{}", salt, password));

    let mut data =
        jwxt_do_post(client, &login_url, refer_url, username, &encrypted, "", timeout)?;

    // 如果需要验证码
    if !data.get("result").and_then(Value::as_bool).unwrap_or(false)
        && data
            .get("needCaptcha")
            .and_then(Value::as_bool)
            .unwrap_or(false)
    {
        let cap_url = format!(
            "{}/student/login-captcha?vpn-1&d={}",
            JWXT_APP_BASE,
            unix_millis()
        );
        let _ = (client, &cap_url);
        return Err(TimetableError::JwxtLogin(
            "教务系统需要图形验证码，移动端暂不支持，请稍后重试或在电脑端完成登录后再使用".to_owned(),
        ));
    }

    if !data.get("result").and_then(Value::as_bool).unwrap_or(false) {
        let msg = data
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("未知错误");
        let need_cap = data
            .get("needCaptcha")
            .and_then(Value::as_bool)
            .unwrap_or(false);
        return Err(TimetableError::JwxtLogin(format!(
            "{} (needCaptcha={})",
            msg, need_cap
        )));
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// 公开接口
// ---------------------------------------------------------------------------

/// 登录 WebVPN + 教务系统，返回课表 JSON。
///
/// # 参数
/// - `sso_username` / `sso_password`: 统一认证凭据
/// - `jwxt_username` / `jwxt_password`: 教务系统凭据，留空则使用统一认证凭据
/// - `semester_id`: 学期 ID（通常为 241）
/// - `biz_type_id`: bizTypeId（通常为 2）
/// - `week_index`: 周次基准（1 = 从第 1 周起，0 = 服务端自动用当前周）
/// - `timeout_secs`: HTTP 请求超时秒数
/// 通过已鉴权的 Client 完成 JWXT 登录 + 课表抓取（可供验证码两阶段路径复用）。
pub fn get_timetable_with_client(
    client: Client,
    jwxt_username: &str,
    jwxt_password: &str,
    semester_id: u32,
    biz_type_id: u32,
    week_index: u32,
    timeout: Duration,
) -> Result<Value> {
    let jwxt_user = if jwxt_username.is_empty() {
        jwxt_username
    } else {
        jwxt_username
    };
    let jwxt_pwd = if jwxt_password.is_empty() {
        jwxt_password
    } else {
        jwxt_password
    };

    let jwxt_login_page = format!("{}/student/login", JWXT_APP_BASE);
    let jwxt_course_table = format!("{}/student/for-std/course-table", JWXT_APP_BASE);
    let jwxt_get_data = format!("{}/student/for-std/course-table/get-data", JWXT_APP_BASE);
    let week_index_param = if week_index > 0 {
        format!("&weekIndex={}", week_index)
    } else {
        String::new()
    };

    // 访问 JWXT 登录页
    let r = client
        .get(&jwxt_login_page)
        .timeout(timeout)
        .send()?;
    r.error_for_status_ref()?;
    let refer_url = r.url().to_string();
    let _ = r.text()?;

    // 教务本地登录
    jwxt_login(&client, &refer_url, jwxt_user, jwxt_pwd, timeout)?;

    // 访问课表页建立 Referer
    let _ = client.get(&jwxt_course_table).timeout(timeout).send()?;

    // 拉取课表 JSON
    let api_url = format!(
        "{}?{}&bizTypeId={}&semesterId={}{}",
        jwxt_get_data, VPN_MARKER, biz_type_id, semester_id, week_index_param
    );
    let resp = client
        .get(&api_url)
        .timeout(timeout)
        .header(REFERER, &jwxt_course_table)
        .header(ACCEPT, "application/json, text/plain, */*")
        .send()?;
    resp.error_for_status_ref()?;
    resp.json::<Value>()
        .map_err(|e| TimetableError::JwxtLogin(format!("课表 JSON 解析失败: {}", e)))
}

pub fn get_timetable(
    sso_username: &str,
    sso_password: &str,
    jwxt_username: &str,
    jwxt_password: &str,
    semester_id: u32,
    biz_type_id: u32,
    week_index: u32,
    timeout_secs: u64,
) -> Result<Value> {
    let jwxt_user = if jwxt_username.is_empty() { sso_username } else { jwxt_username };
    let jwxt_pwd  = if jwxt_password.is_empty()  { sso_password  } else { jwxt_password  };
    let timeout = Duration::from_secs(timeout_secs);
    let client = sso_login(sso_username, sso_password, timeout)?;
    get_timetable_with_client(client, jwxt_user, jwxt_pwd, semester_id, biz_type_id, week_index, timeout)
}
