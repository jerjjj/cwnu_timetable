import 'package:flutter_test/flutter_test.dart';

import 'package:cwnu_demo/config/course_utils.dart';
import 'package:cwnu_demo/models/course_record.dart';

void main() {
  group('CourseUtils', () {
    group('findMaxWeek', () {
      test('returns 1 for empty list', () {
        expect(CourseUtils.findMaxWeek([]), equals(1));
      });

      test('returns max week from records', () {
        final records = [
          CourseRecord(
            courseName: '课程1',
            week: [1, 2, 3],
            dayOfWeek: 1,
            periods: '1-2',
            teacher: '老师',
            campusName: '校区',
            placeName: '教室',
            isOnline: false,
          ),
          CourseRecord(
            courseName: '课程2',
            week: [5, 8, 12],
            dayOfWeek: 2,
            periods: '3-4',
            teacher: '老师',
            campusName: '校区',
            placeName: '教室',
            isOnline: false,
          ),
        ];
        expect(CourseUtils.findMaxWeek(records), equals(12));
      });
    });

    group('formatWeekRanges', () {
      test('returns empty string for empty list', () {
        expect(CourseUtils.formatWeekRanges([]), equals(''));
      });

      test('formats single week', () {
        expect(CourseUtils.formatWeekRanges([5]), equals('5周'));
      });

      test('formats consecutive weeks', () {
        expect(CourseUtils.formatWeekRanges([1, 2, 3, 4, 5]), equals('1-5周'));
      });

      test('formats non-consecutive weeks', () {
        expect(CourseUtils.formatWeekRanges([1, 3, 5]), equals('1周,3周,5周'));
      });

      test('formats mixed weeks', () {
        expect(
          CourseUtils.formatWeekRanges([1, 2, 3, 5, 6, 8]),
          equals('1-3周,5-6周,8周'),
        );
      });

      test('handles unsorted input', () {
        expect(CourseUtils.formatWeekRanges([5, 1, 3, 2, 4]), equals('1-5周'));
      });
    });

    group('teacherTokens', () {
      test('splits by comma', () {
        expect(CourseUtils.teacherTokens('张三,李四'), equals(['张三', '李四']));
      });

      test('splits by Chinese comma', () {
        expect(CourseUtils.teacherTokens('张三，李四'), equals(['张三', '李四']));
      });

      test('splits by semicolon', () {
        expect(CourseUtils.teacherTokens('张三;李四'), equals(['张三', '李四']));
      });

      test('splits by space', () {
        expect(CourseUtils.teacherTokens('张三 李四'), equals(['张三', '李四']));
      });

      test('handles mixed delimiters', () {
        expect(
          CourseUtils.teacherTokens('张三,李四；王五/赵六'),
          equals(['张三', '李四', '王五', '赵六']),
        );
      });

      test('filters empty strings', () {
        expect(CourseUtils.teacherTokens('张三,,李四'), equals(['张三', '李四']));
      });

      test('returns empty list for empty input', () {
        expect(CourseUtils.teacherTokens(''), equals([]));
      });
    });

    group('mergeTeacherText', () {
      test('merges and deduplicates', () {
        expect(
          CourseUtils.mergeTeacherText(['张三,李四', '张三,王五']),
          equals('张三、李四、王五'),
        );
      });

      test('handles empty input', () {
        expect(CourseUtils.mergeTeacherText([]), equals(''));
      });
    });

    group('mergeRecords', () {
      test('merges records with same name', () {
        final records = [
          CourseRecord(
            courseName: '高等数学',
            week: [1, 2, 3],
            dayOfWeek: 1,
            periods: '1-2',
            teacher: '张三',
            campusName: '主校区',
            placeName: 'A101',
            isOnline: false,
          ),
          CourseRecord(
            courseName: '高等数学',
            week: [4, 5, 6],
            dayOfWeek: 1,
            periods: '1-2',
            teacher: '李四',
            campusName: '主校区',
            placeName: 'A102',
            isOnline: false,
          ),
        ];

        final merged = CourseUtils.mergeRecords(records);

        expect(merged.courseName, equals('高等数学'));
        expect(merged.week, equals([1, 2, 3, 4, 5, 6]));
        expect(merged.teacher, equals('张三、李四'));
        expect(merged.dayOfWeek, equals(1));
        expect(merged.periods, equals('1-2'));
      });
    });
  });
}
