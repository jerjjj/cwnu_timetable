use std::time::Duration;

use regex::Regex;
use reqwest::blocking::Client;
use reqwest::header::{ACCEPT, ACCEPT_LANGUAGE, REFERER};
use serde::Serialize;
use serde_json::Value;

use crate::constants::JWXT_APP_BASE;
use crate::error::{Result, TimetableError};
use crate::jwxt::jwxt_login;
use crate::sso::sso_login;

/// 单门课程成绩
#[derive(Debug, Serialize, Clone)]
pub struct CourseGrade {
    /// 课程代码
    pub course_code: String,
    /// 课程名称
    pub course_name: String,
    /// 学分
    pub credit: f64,
    /// 成绩
    pub score: String,
    /// 绩点
    pub grade_point: f64,
    /// 课程属性（必修/选修等）
    pub course_type: String,
    /// 是否及格
    pub passed: bool,
}

/// 学期成绩汇总
#[derive(Debug, Serialize, Clone)]
pub struct SemesterGrades {
    /// 学期 ID
    pub semester_id: u32,
    /// 学期名称
    pub semester_name: String,
    /// 课程成绩列表
    pub courses: Vec<CourseGrade>,
    /// 学期平均绩点
    pub semester_gpa: f64,
    /// 学期总学分
    pub semester_credits: f64,
}

/// 完整成绩信息
#[derive(Debug, Serialize, Clone)]
pub struct GradeReport {
    /// 学期成绩列表
    pub semesters: Vec<SemesterGrades>,
    /// 总平均绩点
    pub overall_gpa: f64,
    /// 总学分
    pub total_credits: f64,
}

/// 解析单个成绩项
fn parse_grade_item(item: &Value) -> Option<CourseGrade> {
    let course = item.get("course")?;

    let course_code = course
        .get("code")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();

    let course_name = course
        .get("nameZh")
        .and_then(Value::as_str)
        .unwrap_or("未知课程")
        .to_string();

    let credit = course.get("credits").and_then(Value::as_f64).unwrap_or(0.0);

    let score = item
        .get("score")
        .and_then(Value::as_str)
        .or_else(|| item.get("scoreStr").and_then(Value::as_str))
        .unwrap_or("--")
        .to_string();

    let grade_point = item
        .get("gp")
        .and_then(Value::as_f64)
        .or_else(|| item.get("gradePoint").and_then(Value::as_f64))
        .unwrap_or(0.0);

    let course_type = item
        .get("courseType")
        .and_then(|ct| ct.get("nameZh"))
        .and_then(Value::as_str)
        .or_else(|| item.get("courseTypeName").and_then(Value::as_str))
        .unwrap_or("未知")
        .to_string();

    let passed = score.parse::<f64>().map(|s| s >= 60.0).unwrap_or(false)
        || score.contains("通过")
        || score.contains("合格");

    Some(CourseGrade {
        course_code,
        course_name,
        credit,
        score,
        grade_point,
        course_type,
        passed,
    })
}

/// 解析成绩 JSON 响应
pub fn parse_grades_json(json: &Value, semester_id: u32) -> Option<SemesterGrades> {
    let rows = json.get("rows").and_then(Value::as_array)?;

    let courses: Vec<CourseGrade> = rows.iter().filter_map(parse_grade_item).collect();

    let total_credits: f64 = courses.iter().map(|c| c.credit).sum();
    let total_grade_points: f64 = courses.iter().map(|c| c.grade_point * c.credit).sum();
    let semester_gpa = if total_credits > 0.0 {
        (total_grade_points / total_credits * 100.0).round() / 100.0
    } else {
        0.0
    };

    Some(SemesterGrades {
        semester_id,
        semester_name: format!("学期{}", semester_id),
        courses,
        semester_gpa,
        semester_credits: total_credits,
    })
}

/// 获取学生ID（登录后自动获取）
pub fn get_student_id(client: &Client, timeout: Duration) -> Result<(String, String)> {
    let grade_url = format!("{}/student/for-std/grade/sheet", JWXT_APP_BASE);
    let resp = client.get(&grade_url).timeout(timeout).send()?;
    resp.error_for_status_ref()?;
    let final_url = resp.url().to_string();

    let url_re = Regex::new(r#"/student/for-std/grade/sheet/semester-index/(\d+)"#)
        .map_err(|e| TimetableError::Parse(format!("正则表达式错误: {}", e)))?;
    if let Some(captures) = url_re.captures(&final_url) {
        if let Some(id) = captures.get(1) {
            return Ok((id.as_str().to_string(), final_url));
        }
    }

    Err(TimetableError::Parse("无法获取学生ID".to_owned()))
}

/// 获取指定学期的成绩
pub fn get_grades_with_client(
    client: &Client,
    grade_page_url: &str,
    student_id: &str,
    semester_id: u32,
    timeout: Duration,
) -> Result<Value> {
    let grade_api_url = format!(
        "{}/student/for-std/grade/sheet/info/{}?vpn-12-o2-jwxt.cwnu.edu.cn&semester={}",
        JWXT_APP_BASE, student_id, semester_id
    );

    let resp = client
        .get(&grade_api_url)
        .timeout(timeout)
        .header(ACCEPT, "*/*")
        .header(
            ACCEPT_LANGUAGE,
            "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
        )
        .header(REFERER, grade_page_url)
        .header("Sec-Fetch-Dest", "empty")
        .header("Sec-Fetch-Mode", "cors")
        .header("Sec-Fetch-Site", "same-origin")
        .header("X-Requested-With", "XMLHttpRequest")
        .send()?;
    resp.error_for_status_ref()?;
    resp.json::<Value>()
        .map_err(|e| TimetableError::Parse(format!("成绩 JSON 解析失败: {}", e)))
}

/// 完整成绩查询流程（自动获取学生ID）
pub fn get_grades(
    sso_username: &str,
    sso_password: &str,
    jwxt_username: &str,
    jwxt_password: &str,
    semester_ids: &[u32],
    timeout_secs: u64,
) -> Result<GradeReport> {
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

    // SSO 登录
    let client = sso_login(sso_username, sso_password, timeout)?;

    // 教务登录
    let jwxt_login_page = format!("{}/student/login", JWXT_APP_BASE);
    let r = client.get(&jwxt_login_page).timeout(timeout).send()?;
    r.error_for_status_ref()?;
    let refer_url = r.url().to_string();
    let _ = r.text()?;
    jwxt_login(&client, &refer_url, jwxt_user, jwxt_pwd, timeout)?;

    // 自动获取学生ID和成绩页面URL
    let (student_id, grade_page_url) = get_student_id(&client, timeout)?;

    // 获取各学期成绩
    let mut semesters = Vec::new();
    for &semester_id in semester_ids {
        let json =
            get_grades_with_client(&client, &grade_page_url, &student_id, semester_id, timeout)?;
        if let Some(semester_grades) = parse_grades_json(&json, semester_id) {
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

    Ok(GradeReport {
        semesters,
        overall_gpa,
        total_credits,
    })
}
