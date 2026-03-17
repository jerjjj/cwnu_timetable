use flutter_rust_bridge::frb;
use std::time::Duration;

/// frb 初始化（由生成的 Dart 代码自动调用）
#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// 抓取课表原始 JSON 字符串。
///
/// 参数使用默认值：学期 241，bizTypeId 2，超时 30 秒。
/// 返回的 JSON 结构与教务系统 get-data 接口一致，供 Flutter 侧解析。
#[frb]
pub async fn fetch_timetable_json_frb(
    sso_username: String,
    sso_password: String,
    jwxt_username: String,
    jwxt_password: String,
    semester_id: i64,
    biz_type_id: i64,
    timeout_sec: u64,
) -> anyhow::Result<String> {
    let semester_id = u32::try_from(semester_id)
        .map_err(|_| anyhow::anyhow!("semester_id 非法: {}", semester_id))?;
    let biz_type_id =
        u32::try_from(biz_type_id).map_err(|_| anyhow::anyhow!("biz_type_id 非法: {}", biz_type_id))?;

    let result = tokio::task::spawn_blocking(move || {
        crate::get_timetable(
            &sso_username,
            &sso_password,
            &jwxt_username,
            &jwxt_password,
            semester_id,
            biz_type_id,
            1,
            timeout_sec,
        )
    })
    .await
    .map_err(|e| anyhow::anyhow!("spawn_blocking 错误: {}", e))?
    .map_err(|e| anyhow::anyhow!(e.to_string()))?;

    Ok(serde_json::to_string(&result)?)
}

/// 使用默认参数快速获取课表 JSON（学期 241，超时 30 秒）
#[frb]
pub async fn fetch_timetable_json_simple_frb(
    sso_username: String,
    sso_password: String,
    jwxt_username: String,
    jwxt_password: String,
) -> anyhow::Result<String> {
    fetch_timetable_json_frb(
        sso_username,
        sso_password,
        jwxt_username,
        jwxt_password,
        241,
        2,
        30,
    )
    .await
}

/// 第一阶段：初始化 SSO 登录并检查是否需要验证码。
///
/// - 返回 `None`：无需验证码，会话已存储，可直接调用 `fetch_timetable_json_with_captcha_frb`（captcha 传空）。
/// - 返回 `Some(bytes)`：需要验证码，bytes 为验证码图片数据（JPEG/PNG），展示给用户后传回。
#[frb]
pub async fn check_sso_captcha_frb(
    username: String,
    password: String,
) -> anyhow::Result<Option<Vec<u8>>> {
    let result = tokio::task::spawn_blocking(move || {
        crate::sso_login_phase1(&username, &password, Duration::from_secs(30))
    })
    .await
    .map_err(|e| anyhow::anyhow!("spawn_blocking 错误: {}", e))?
    .map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let (session, captcha_bytes) = result;

    // 存储会话供第二阶段使用
    if let Ok(mut guard) = crate::PENDING_SSO.lock() {
        *guard = Some(session);
    }

    Ok(captcha_bytes)
}

/// 第二阶段：使用第一阶段存储的会话完成 SSO 登录并抓取课表。
///
/// `captcha`：验证码文本，无需验证码时传空字符串。
/// 需先调用 `check_sso_captcha_frb` 初始化会话。
#[frb]
pub async fn fetch_timetable_json_with_captcha_frb(
    jwxt_username: String,
    jwxt_password: String,
    captcha: String,
) -> anyhow::Result<String> {
    // 取出存储的会话
    let session = crate::PENDING_SSO
        .lock()
        .map_err(|e| anyhow::anyhow!("锁错误: {}", e))?
        .take()
        .ok_or_else(|| anyhow::anyhow!("未找到 SSO 会话，请先调用 checkSsoCaptchaFrb"))?;

    let result = tokio::task::spawn_blocking(move || -> anyhow::Result<String> {
        let timeout = session.timeout;
        let client = crate::sso_login_phase2(session, &captcha)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        let data = crate::get_timetable_with_client(
            client,
            &jwxt_username,
            &jwxt_password,
            241,
            2,
            1,
            timeout,
        )
        .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        Ok(serde_json::to_string(&data)?)
    })
    .await
    .map_err(|e| anyhow::anyhow!("spawn_blocking 错误: {}", e))??;

    Ok(result)
}

