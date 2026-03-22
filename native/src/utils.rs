use std::time::{SystemTime, UNIX_EPOCH};

use aes::cipher::{block_padding::Pkcs7, BlockEncryptMut, KeyIvInit};
use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use rand::Rng;
use sha1::{Digest, Sha1};
use url::Url;

use crate::constants::AES_CHARS;
use crate::error::{Result, TimetableError};

pub fn random_str(n: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..n)
        .map(|_| AES_CHARS[rng.gen_range(0..AES_CHARS.len())] as char)
        .collect()
}

/// AES-CBC + PKCS7 + Base64，对齐 SSO 前端逻辑：random64 + password
pub fn encrypt_password(plain: &str, salt: &str) -> Result<String> {
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

pub fn sha1_hex(s: &str) -> String {
    let mut h = Sha1::new();
    h.update(s.as_bytes());
    format!("{:x}", h.finalize())
}

pub fn url_origin(url_str: &str) -> String {
    let Ok(u) = Url::parse(url_str) else {
        return String::new();
    };
    let port_part = u.port().map(|p| format!(":{}", p)).unwrap_or_default();
    format!(
        "{}://{}{}",
        u.scheme(),
        u.host_str().unwrap_or(""),
        port_part
    )
}

pub fn resolve_url(base: &str, relative: &str) -> String {
    Url::parse(base)
        .ok()
        .and_then(|b| b.join(relative).ok())
        .map(|u| u.to_string())
        .unwrap_or_else(|| relative.to_owned())
}

pub fn get_query_param(url_str: &str, key: &str) -> Option<String> {
    Url::parse(url_str)
        .ok()?
        .query_pairs()
        .find(|(k, _)| k.as_ref() == key)
        .map(|(_, v)| v.into_owned())
}

pub fn add_or_replace_query(base_url: &str, key: &str, value: &str) -> String {
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

pub fn context_path_from_url(post_url: &str) -> String {
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

pub fn unix_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

pub fn is_login_page(html: &str) -> bool {
    ["账号登录", "请输入密码", "authserver/login", "passwordText"]
        .iter()
        .any(|&k| html.contains(k))
}
