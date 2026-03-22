use std::time::Duration;

use reqwest::blocking::Client;
use reqwest::header::REFERER;
use serde_json::Value;

use crate::constants::JWXT_APP_BASE;
use crate::error::{Result, TimetableError};
use crate::utils::{sha1_hex, unix_millis};

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

pub fn jwxt_login(
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

    let data = jwxt_do_post(
        client, &login_url, refer_url, username, &encrypted, "", timeout,
    )?;

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
            "教务系统需要图形验证码，移动端暂不支持，请稍后重试或在电脑端完成登录后再使用"
                .to_owned(),
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
