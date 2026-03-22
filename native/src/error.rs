use std::io;

use thiserror::Error;

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
