mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod api;

// 模块声明
pub mod constants;
pub mod error;
pub mod grade;
pub mod jwxt;
pub mod sso;
pub mod timetable;
pub mod utils;

// Re-export 常用类型和函数
pub use constants::*;
pub use error::{Result, TimetableError};
pub use grade::{
    get_grades, get_grades_with_client, get_student_id, parse_grades_json, CourseGrade,
    GradeReport, SemesterGrades,
};
pub use jwxt::jwxt_login;
pub use sso::{sso_login, sso_login_phase1, sso_login_phase2, PENDING_SSO, SsoLoginSession};
pub use timetable::{get_timetable, get_timetable_with_client};
