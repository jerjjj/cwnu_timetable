import 'package:flutter_test/flutter_test.dart';

import 'package:cwnu_demo/services/grade_service.dart';

void main() {
  group('GradeService', () {
    test('GradeItem fromJson parses valid JSON', () {
      final json = {
        'course_name': '高等数学',
        'credit': 4.0,
        'score': '85',
        'grade_point': 3.5,
        'course_type': '必修',
      };

      final item = GradeItem.fromJson(json);

      expect(item.courseName, '高等数学');
      expect(item.credit, 4.0);
      expect(item.score, '85');
      expect(item.gradePoint, 3.5);
      expect(item.courseType, '必修');
    });

    test('getSemesters returns semesters list', () {
      final rawData = {
        'semesters': [
          {'id': 221, 'nameZh': '2025-2026-1'},
          {'id': 222, 'nameZh': '2025-2026-2'},
        ],
      };

      final semesters = GradeService.getSemesters(rawData);

      expect(semesters.length, 2);
      expect(semesters[0]['id'], 221);
    });

    test('getGradesBySemester returns grades for semester', () {
      final rawData = {
        'semesterId2studentGrades': {
          '221': [
            {
              'course': {'nameZh': '高等数学', 'credits': 4.0},
              'gaGrade': '85',
              'gp': 3.5,
              'courseType': {'nameZh': '必修'},
              'courseProperty': {'nameZh': '专业必修课'},
            },
          ],
        },
      };

      final grades = GradeService.getGradesBySemester(rawData, '221');

      expect(grades.length, 1);
      expect(grades[0].courseName, '高等数学');
      expect(grades[0].credit, 4.0);
      expect(grades[0].score, '85');
      expect(grades[0].gradePoint, 3.5);
      expect(grades[0].courseType, '专业必修课');
    });

    test('calculateGpa computes correctly', () {
      final grades = [
        GradeItem(
          courseName: '课程1',
          credit: 4.0,
          score: '85',
          gradePoint: 3.5,
          courseType: '必修',
        ),
        GradeItem(
          courseName: '课程2',
          credit: 3.0,
          score: '90',
          gradePoint: 4.0,
          courseType: '必修',
        ),
      ];

      final result = GradeService.calculateStats(grades);

      expect(result['total_credits'], 7.0);
      expect(result['avg_score'], 87.14);
    });
  });
}
