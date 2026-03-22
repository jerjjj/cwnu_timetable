import 'dart:convert';

import '../src/rust/api.dart' as rust_api;

class GradeItem {
  final String courseName;
  final double credit;
  final String score;
  final double gradePoint;
  final String courseType;

  GradeItem({
    required this.courseName,
    required this.credit,
    required this.score,
    required this.gradePoint,
    required this.courseType,
  });

  factory GradeItem.fromJson(Map<String, dynamic> json) {
    return GradeItem(
      courseName: json['course_name'] as String? ?? '未知课程',
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      score: json['score']?.toString() ?? '--',
      gradePoint: (json['grade_point'] as num?)?.toDouble() ?? 0,
      courseType: json['course_type'] as String? ?? '未知',
    );
  }
}

class GradeService {
  /// 获取成绩原始 JSON
  static Future<Map<String, dynamic>> fetchGradesJson({
    required String ssoUsername,
    required String ssoPassword,
    required String jwxtUsername,
    required String jwxtPassword,
  }) async {
    final jsonStr = await rust_api.fetchGradesJsonSimpleFrb(
      ssoUsername: ssoUsername,
      ssoPassword: ssoPassword,
      jwxtUsername: jwxtUsername,
      jwxtPassword: jwxtPassword,
    );
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// 获取所有可用学期
  static List<Map<String, dynamic>> getSemesters(Map<String, dynamic> rawData) {
    final semesters = rawData['semesters'] as List<dynamic>? ?? [];
    return semesters.cast<Map<String, dynamic>>();
  }

  /// 获取指定学期的成绩
  static List<GradeItem> getGradesBySemester(
    Map<String, dynamic> rawData,
    String semesterId,
  ) {
    final semesterGrades =
        rawData['semesterId2studentGrades'] as Map<String, dynamic>? ?? {};
    final grades = semesterGrades[semesterId] as List<dynamic>? ?? [];

    return grades.map((item) {
      if (item is! Map<String, dynamic>) {
        return GradeItem(
          courseName: '未知课程',
          credit: 0,
          score: '--',
          gradePoint: 0,
          courseType: '未知',
        );
      }

      final course = item['course'] as Map<String, dynamic>? ?? {};
      final courseType = item['courseType'] as Map<String, dynamic>? ?? {};
      final courseProperty = item['courseProperty'] as Map<String, dynamic>?;

      String courseTypeName = '未知';
      if (courseProperty != null) {
        courseTypeName =
            courseProperty['nameZh'] ?? courseProperty['name'] ?? '';
      }
      if (courseTypeName == '未知' || courseTypeName.isEmpty) {
        courseTypeName = courseType['nameZh'] ?? courseType['name'] ?? '未知';
      }

      return GradeItem(
        courseName: course['nameZh'] ?? '未知课程',
        credit: (course['credits'] as num?)?.toDouble() ?? 0,
        score: item['gaGrade']?.toString() ?? '--',
        gradePoint: (item['gp'] as num?)?.toDouble() ?? 0,
        courseType: courseTypeName,
      );
    }).toList();
  }

  /// 获取所有学期的成绩（简化格式）
  static List<GradeItem> getAllGrades(Map<String, dynamic> rawData) {
    final semesterGrades =
        rawData['semesterId2studentGrades'] as Map<String, dynamic>? ?? {};
    final allGrades = <GradeItem>[];

    for (final entry in semesterGrades.entries) {
      final grades = getGradesBySemester(rawData, entry.key);
      allGrades.addAll(grades);
    }

    return allGrades;
  }

  /// 计算总学分和平均成绩
  static Map<String, dynamic> calculateStats(List<GradeItem> grades) {
    double totalCredits = 0;
    double totalScore = 0;

    for (final grade in grades) {
      final score = double.tryParse(grade.score);
      if (score != null) {
        totalCredits += grade.credit;
        totalScore += score * grade.credit;
      }
    }

    final avgScore = totalCredits > 0
        ? ((totalScore / totalCredits) * 100).round() / 100
        : 0.0;

    return {
      'total_credits': totalCredits,
      'avg_score': avgScore,
      'course_count': grades.length,
    };
  }
}
