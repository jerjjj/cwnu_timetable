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

/// 使用默认参数快速获取成绩 JSON（学期 221，超时 30 秒）
#[frb]
pub async fn fetch_grades_json_simple_frb(
    sso_username: String,
    sso_password: String,
    jwxt_username: String,
    jwxt_password: String,
) -> anyhow::Result<String> {
    let result = tokio::task::spawn_blocking(move || -> anyhow::Result<serde_json::Value> {
        let timeout = std::time::Duration::from_secs(30);
        
        // SSO 登录
        let client = crate::sso_login(&sso_username, &sso_password, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 教务登录
        let jwxt_user = if jwxt_username.is_empty() { &sso_username } else { &jwxt_username };
        let jwxt_pwd = if jwxt_password.is_empty() { &sso_password } else { &jwxt_password };
        
        let jwxt_login_page = format!("{}/student/login", crate::JWXT_APP_BASE);
        let r = client.get(&jwxt_login_page).timeout(timeout).send()
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        r.error_for_status_ref().map_err(|e| anyhow::anyhow!(e.to_string()))?;
        let refer_url = r.url().to_string();
        let _ = r.text().map_err(|e| anyhow::anyhow!(e.to_string()))?;
        crate::jwxt_login(&client, &refer_url, jwxt_user, jwxt_pwd, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 自动获取学生ID和成绩页面URL
        let (student_id, grade_page_url) = crate::get_student_id(&client, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 获取成绩（默认学期 221）
        crate::get_grades_with_client(&client, &grade_page_url, &student_id, 221, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))
    })
    .await
    .map_err(|e| anyhow::anyhow!("spawn_blocking 错误: {}", e))??;

    Ok(serde_json::to_string(&result)?)
}

// ---------------------------------------------------------------------------
// 成绩查询接口（支持两阶段验证码）
// ---------------------------------------------------------------------------

/// 成绩查询第一阶段：初始化 SSO 登录并检查是否需要验证码。
/// 与课表查询共享同一个会话机制。
///
/// - 返回 `None`：无需验证码，可直接调用 `fetch_grades_with_captcha_frb`（captcha 传空）。
/// - 返回 `Some(bytes)`：需要验证码，bytes 为验证码图片数据。
#[frb]
pub async fn check_sso_captcha_for_grades_frb(
    username: String,
    password: String,
) -> anyhow::Result<Option<Vec<u8>>> {
    // 复用现有的验证码检查逻辑
    check_sso_captcha_frb(username, password).await
}

/// 成绩查询第二阶段：使用第一阶段存储的会话完成登录并获取成绩。
///
/// `captcha`：验证码文本，无需验证码时传空字符串。
/// 需先调用 `check_sso_captcha_for_grades_frb` 初始化会话。
#[frb]
pub async fn fetch_grades_json_frb(
    jwxt_username: String,
    jwxt_password: String,
    captcha: String,
    semester_id: i64,
) -> anyhow::Result<String> {
    let semester_id = u32::try_from(semester_id)
        .map_err(|_| anyhow::anyhow!("semester_id 非法: {}", semester_id))?;

    // 取出存储的会话
    let session = crate::PENDING_SSO
        .lock()
        .map_err(|e| anyhow::anyhow!("锁错误: {}", e))?
        .take()
        .ok_or_else(|| anyhow::anyhow!("未找到 SSO 会话，请先调用 checkSsoCaptchaForGradesFrb"))?;

    let result = tokio::task::spawn_blocking(move || -> anyhow::Result<serde_json::Value> {
        let timeout = session.timeout;
        let client = crate::sso_login_phase2(session, &captcha)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 教务登录
        let jwxt_login_page = format!("{}/student/login", crate::JWXT_APP_BASE);
        let r = client.get(&jwxt_login_page).timeout(timeout).send()
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        r.error_for_status_ref().map_err(|e| anyhow::anyhow!(e.to_string()))?;
        let refer_url = r.url().to_string();
        let _ = r.text().map_err(|e| anyhow::anyhow!(e.to_string()))?;
        crate::jwxt_login(&client, &refer_url, &jwxt_username, &jwxt_password, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 自动获取学生ID和成绩页面URL
        let (student_id, grade_page_url) = crate::get_student_id(&client, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 获取成绩
        crate::get_grades_with_client(&client, &grade_page_url, &student_id, semester_id, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))
    })
    .await
    .map_err(|e| anyhow::anyhow!("spawn_blocking 错误: {}", e))??;

    Ok(serde_json::to_string(&result)?)
}

/// 获取解析后的成绩数据（支持两阶段验证码）
#[frb]
pub async fn fetch_grades_parsed_frb(
    jwxt_username: String,
    jwxt_password: String,
    captcha: String,
    semester_ids: Vec<i64>,
) -> anyhow::Result<String> {
    let semester_ids: Vec<u32> = semester_ids
        .into_iter()
        .map(|id| u32::try_from(id).map_err(|_| anyhow::anyhow!("semester_id 非法: {}", id)))
        .collect::<anyhow::Result<Vec<_>>>()?;

    // 取出存储的会话
    let session = crate::PENDING_SSO
        .lock()
        .map_err(|e| anyhow::anyhow!("锁错误: {}", e))?
        .take()
        .ok_or_else(|| anyhow::anyhow!("未找到 SSO 会话，请先调用 checkSsoCaptchaForGradesFrb"))?;

    let result = tokio::task::spawn_blocking(move || -> anyhow::Result<crate::GradeReport> {
        let timeout = session.timeout;
        let client = crate::sso_login_phase2(session, &captcha)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 教务登录
        let jwxt_login_page = format!("{}/student/login", crate::JWXT_APP_BASE);
        let r = client.get(&jwxt_login_page).timeout(timeout).send()
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        r.error_for_status_ref().map_err(|e| anyhow::anyhow!(e.to_string()))?;
        let refer_url = r.url().to_string();
        let _ = r.text().map_err(|e| anyhow::anyhow!(e.to_string()))?;
        crate::jwxt_login(&client, &refer_url, &jwxt_username, &jwxt_password, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 自动获取学生ID和成绩页面URL
        let (student_id, grade_page_url) = crate::get_student_id(&client, timeout)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        
        // 获取各学期成绩
        let mut semesters = Vec::new();
        for &semester_id in &semester_ids {
            let json = crate::get_grades_with_client(&client, &grade_page_url, &student_id, semester_id, timeout)
                .map_err(|e| anyhow::anyhow!(e.to_string()))?;
            if let Some(semester_grades) = crate::parse_grades_json(&json, semester_id) {
                semesters.push(semester_grades);
            }
        }
        
        // 计算总绩点和总学分
        let total_credits: f64 = semesters.iter().map(|s| s.semester_credits).sum();
        let total_grade_points: f64 = semesters
            .iter()
            .flat_map(|s| &s.courses)
            .map(|c| c.grade_point * c.credit)
            .sum();
        let overall_gpa = if total_credits > 0.0 {
            (total_grade_points / total_credits * 100.0).round() / 100.0
        } else {
            0.0
        };
        
        Ok(crate::GradeReport {
            semesters,
            overall_gpa,
            total_credits,
        })
    })
    .await
    .map_err(|e| anyhow::anyhow!("spawn_blocking 错误: {}", e))??;

    Ok(serde_json::to_string(&result)?)
}

