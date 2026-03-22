use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;

use regex::Regex;
use reqwest::blocking::Client;
use reqwest::header::{ACCEPT, ACCEPT_LANGUAGE, ORIGIN, REFERER};
use scraper::{Html, Selector};
use serde_json::Value;

use crate::constants::SSO_URL;
use crate::error::{Result, TimetableError};
use crate::utils::*;

/// SSO 登录第一阶段产生的会话状态，可跨线程传递。
pub struct SsoLoginSession {
    pub client: Client,
    pub post_url: String,
    pub payload: HashMap<String, String>,
    pub origin: String,
    pub timeout: Duration,
}

// SAFETY: reqwest::blocking::Client is Send + Sync, all other fields are Send + Sync.
unsafe impl Send for SsoLoginSession {}
unsafe impl Sync for SsoLoginSession {}

/// 全局挂起的 SSO 会话（用于 Flutter 侧两阶段登录）
pub static PENDING_SSO: Mutex<Option<SsoLoginSession>> = Mutex::new(None);

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
        session
            .payload
            .insert("captcha".to_owned(), captcha.to_owned());
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

/// 内部便捷包装：无验证码直接完成登录（自动刷新路径使用）
pub fn sso_login(username: &str, password: &str, timeout: Duration) -> Result<Client> {
    let (session, captcha_bytes) = sso_login_phase1(username, password, timeout)?;
    if captcha_bytes.is_some() {
        return Err(TimetableError::SsoLogin(
            "SSO 登录需要图形验证码，请使用「登录」页面完成验证".to_owned(),
        ));
    }
    sso_login_phase2(session, "")
}
