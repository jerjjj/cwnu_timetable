use get_timetable::{
    get_grades, get_grades_with_client, get_student_id, get_timetable, sso_login_phase1,
    sso_login_phase2,
};
use std::io::{self, Write};
use std::time::Duration;

fn prompt(msg: &str) -> String {
    print!("{}", msg);
    io::stdout().flush().unwrap();
    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();
    input.trim().to_string()
}

fn main() {
    println!("=== 西华师范大学 教务系统测试工具 ===\n");

    let username = prompt("请输入学号/用户名: ");
    let sso_password = prompt("请输入信息门户密码: ");
    let jwxt_password = prompt("请输入教务系统密码: ");

    println!("\n请选择功能:");
    println!("1. 查询课表");
    println!("2. 查询成绩");
    println!("3. 全部查询");

    let choice = prompt("\n请输入选项 (1/2/3): ");

    match choice.as_str() {
        "1" => {
            println!("\n正在查询课表...");
            match get_timetable(
                &username,
                &sso_password,
                &username,
                &jwxt_password,
                241,
                2,
                1,
                30,
            ) {
                Ok(data) => {
                    println!("\n=== 课表数据 ===");
                    println!("{}", serde_json::to_string_pretty(&data).unwrap());

                    if let Some(lessons) = data.get("lessons").and_then(|l| l.as_array()) {
                        println!("\n共找到 {} 节课", lessons.len());
                    }
                }
                Err(e) => {
                    eprintln!("\n查询失败: {}", e);
                }
            }
        }
        "2" => {
            let semester_input = prompt("请输入学期ID (如 221, 241): ");
            let semester_id: u32 = semester_input.parse().unwrap_or(241);

            println!("\n正在查询成绩...");
            match query_grades_debug(&username, &sso_password, &jwxt_password, semester_id) {
                Ok(json) => {
                    println!("\n=== 成绩原始数据 ===");
                    println!("{}", json);
                }
                Err(e) => {
                    eprintln!("\n查询失败: {}", e);
                }
            }
        }
        "3" => {
            println!("\n正在查询课表...");
            match get_timetable(
                &username,
                &sso_password,
                &username,
                &jwxt_password,
                241,
                2,
                1,
                30,
            ) {
                Ok(data) => {
                    println!("\n=== 课表数据 ===");
                    if let Some(lessons) = data.get("lessons").and_then(|l| l.as_array()) {
                        println!("共找到 {} 节课", lessons.len());
                        for (i, lesson) in lessons.iter().take(5).enumerate() {
                            let name = lesson
                                .get("courseName")
                                .and_then(|n| n.as_str())
                                .unwrap_or("未知");
                            println!("  {}. {}", i + 1, name);
                        }
                        if lessons.len() > 5 {
                            println!("  ... 还有 {} 节课", lessons.len() - 5);
                        }
                    }
                }
                Err(e) => {
                    eprintln!("\n课表查询失败: {}", e);
                }
            }

            let semester_input = prompt("\n请输入学期ID (如 221, 241): ");
            let semester_id: u32 = semester_input.parse().unwrap_or(241);

            println!("\n正在查询成绩...");
            match query_grades_debug(&username, &sso_password, &jwxt_password, semester_id) {
                Ok(json) => {
                    println!("\n=== 成绩原始数据 ===");
                    println!("{}", json);
                }
                Err(e) => {
                    eprintln!("\n成绩查询失败: {}", e);
                }
            }
        }
        _ => {
            println!("无效选项");
        }
    }

    println!("\n按回车键退出...");
    let _ = prompt("");
}

/// 调试版成绩查询
fn query_grades_debug(
    username: &str,
    sso_password: &str,
    jwxt_password: &str,
    semester_id: u32,
) -> Result<String, Box<dyn std::error::Error>> {
    let timeout = Duration::from_secs(30);

    // 第一阶段：检查验证码
    println!("  正在初始化信息门户登录...");
    let (session, captcha_bytes) = sso_login_phase1(username, sso_password, timeout)?;

    let captcha = if let Some(img_bytes) = captcha_bytes {
        println!("  需要验证码，图片已保存到 captcha.png");
        std::fs::write("captcha.png", &img_bytes)?;
        prompt("  请输入验证码: ")
    } else {
        println!("  无需验证码");
        String::new()
    };

    // 第二阶段：完成信息门户登录
    println!("  正在完成信息门户登录...");
    let client = sso_login_phase2(session, &captcha)?;

    // 教务登录
    println!("  正在登录教务系统...");
    let jwxt_login_page = format!("{}/student/login", get_timetable::JWXT_APP_BASE);
    let r = client.get(&jwxt_login_page).timeout(timeout).send()?;
    r.error_for_status_ref()?;
    let refer_url = r.url().to_string();
    let _ = r.text()?;
    get_timetable::jwxt_login(&client, &refer_url, username, jwxt_password, timeout)?;

    // 获取学生ID和成绩页面URL
    println!("  正在获取学生ID...");
    let (student_id, grade_page_url) = get_student_id(&client, timeout)?;
    println!("  学生ID: {}", student_id);
    println!("  成绩页面URL: {}", grade_page_url);

    // 构建成绩API URL
    let grade_api_url = format!(
        "{}/student/for-std/grade/sheet/info/{}?vpn-12-o2-jwxt.cwnu.edu.cn&semester={}",
        get_timetable::JWXT_APP_BASE,
        student_id,
        semester_id
    );
    println!("  成绩API URL: {}", grade_api_url);

    // 获取成绩
    println!("  正在获取成绩...");
    let json = get_grades_with_client(&client, &grade_page_url, &student_id, semester_id, timeout)?;

    Ok(serde_json::to_string_pretty(&json)?)
}
