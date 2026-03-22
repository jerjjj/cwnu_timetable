use std::time::Duration;

use reqwest::blocking::Client;
use reqwest::header::{ACCEPT, REFERER};
use serde_json::Value;

use crate::constants::{JWXT_APP_BASE, VPN_MARKER};
use crate::error::Result;
use crate::jwxt::jwxt_login;
use crate::sso::sso_login;

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
    let r = client.get(&jwxt_login_page).timeout(timeout).send()?;
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
        .map_err(|e| crate::error::TimetableError::JwxtLogin(format!("课表 JSON 解析失败: {}", e)))
}

/// 登录 WebVPN + 教务系统，返回课表 JSON。
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
    let jwxt_user = if jwxt_username.is_empty() {
        sso_username
    } else {
        jwxt_username
    };
    let jwxt_pwd = if jwxt_password.is_empty() {
        sso_password
    } else {
        jwxt_password
    };
    let timeout = Duration::from_secs(timeout_secs);
    let client = sso_login(sso_username, sso_password, timeout)?;
    get_timetable_with_client(
        client,
        jwxt_user,
        jwxt_pwd,
        semester_id,
        biz_type_id,
        week_index,
        timeout,
    )
}
