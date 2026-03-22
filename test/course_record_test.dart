import 'package:flutter_test/flutter_test.dart';

import 'package:cwnu_demo/models/course_record.dart';

void main() {
  group('CourseRecord', () {
    group('fromJson', () {
      test('parses valid JSON', () {
        final json = {
          'course_name': '高等数学',
          'week': [1, 2, 3],
          'day_of_week': 1,
          'periods': '1-2',
          'teacher': '张三',
          'campus_name': '主校区',
          'place_name': 'A101',
          'is_online': false,
        };

        final record = CourseRecord.fromJson(json);

        expect(record.courseName, equals('高等数学'));
        expect(record.week, equals([1, 2, 3]));
        expect(record.dayOfWeek, equals(1));
        expect(record.periods, equals('1-2'));
        expect(record.teacher, equals('张三'));
        expect(record.campusName, equals('主校区'));
        expect(record.placeName, equals('A101'));
        expect(record.isOnline, isFalse);
      });

      test('handles missing fields', () {
        final json = <String, dynamic>{};
        final record = CourseRecord.fromJson(json);

        expect(record.courseName, equals('未命名课程'));
        expect(record.week, isEmpty);
        expect(record.dayOfWeek, equals(1));
        expect(record.periods, equals(''));
        expect(record.teacher, equals(''));
        expect(record.campusName, equals(''));
        expect(record.placeName, equals(''));
      });

      test('detects online course from campus_name', () {
        final json = {'campus_name': '网络课程', 'place_name': ''};
        final record = CourseRecord.fromJson(json);
        expect(record.isOnline, isTrue);
      });

      test('detects online course from place_name', () {
        final json = {'campus_name': '', 'place_name': '线上'};
        final record = CourseRecord.fromJson(json);
        expect(record.isOnline, isTrue);
      });
    });

    group('toJson', () {
      test('converts to JSON correctly', () {
        final record = CourseRecord(
          courseName: '高等数学',
          week: [1, 2, 3],
          dayOfWeek: 1,
          periods: '1-2',
          teacher: '张三',
          campusName: '主校区',
          placeName: 'A101',
          isOnline: false,
        );

        final json = record.toJson();

        expect(json['course_name'], equals('高等数学'));
        expect(json['week'], equals([1, 2, 3]));
        expect(json['day_of_week'], equals(1));
        expect(json['periods'], equals('1-2'));
        expect(json['teacher'], equals('张三'));
        expect(json['campus_name'], equals('主校区'));
        expect(json['place_name'], equals('A101'));
        expect(json['is_online'], isFalse);
      });
    });

    group('startPeriod and endPeriod', () {
      test('parses numeric periods', () {
        final record = CourseRecord(
          courseName: 'test',
          week: [1],
          dayOfWeek: 1,
          periods: '1-3',
          teacher: '',
          campusName: '',
          placeName: '',
          isOnline: false,
        );

        expect(record.startPeriod, equals(1));
        expect(record.endPeriod, equals(3));
      });

      test('parses single period', () {
        final record = CourseRecord(
          courseName: 'test',
          week: [1],
          dayOfWeek: 1,
          periods: '5',
          teacher: '',
          campusName: '',
          placeName: '',
          isOnline: false,
        );

        expect(record.startPeriod, equals(5));
        expect(record.endPeriod, equals(5));
      });

      test('parses Chinese periods', () {
        final record = CourseRecord(
          courseName: 'test',
          week: [1],
          dayOfWeek: 1,
          periods: '第三到五节',
          teacher: '',
          campusName: '',
          placeName: '',
          isOnline: false,
        );

        expect(record.startPeriod, equals(3));
        expect(record.endPeriod, equals(5));
      });

      test('handles empty periods', () {
        final record = CourseRecord(
          courseName: 'test',
          week: [1],
          dayOfWeek: 1,
          periods: '',
          teacher: '',
          campusName: '',
          placeName: '',
          isOnline: false,
        );

        expect(record.startPeriod, equals(1));
        expect(record.endPeriod, equals(1));
      });
    });
  });
}
