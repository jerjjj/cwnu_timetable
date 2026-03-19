import '../models/course_record.dart';

class CourseUtils {
  CourseUtils._();

  static int findMaxWeek(List<CourseRecord> records) {
    var maxWeek = 1;
    for (final r in records) {
      for (final w in r.week) {
        if (w > maxWeek) {
          maxWeek = w;
        }
      }
    }
    return maxWeek;
  }

  static int computeCurrentWeek({
    required DateTime termStartDate,
    required int maxWeek,
  }) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      termStartDate.year,
      termStartDate.month,
      termStartDate.day,
    );

    final diffDays = todayDate.difference(startDate).inDays;
    var week = diffDays < 0 ? 1 : (diffDays ~/ 7) + 1;
    if (week < 1) week = 1;
    if (week > maxWeek) week = maxWeek;
    return week;
  }

  static String formatWeekRanges(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = [...weeks]..sort();
    final ranges = <String>[];
    var start = sorted.first;
    var end = sorted.first;

    for (var i = 1; i < sorted.length; i++) {
      final w = sorted[i];
      if (w == end + 1) {
        end = w;
      } else {
        ranges.add(start == end ? '$start周' : '$start-$end周');
        start = w;
        end = w;
      }
    }
    ranges.add(start == end ? '$start周' : '$start-$end周');
    return ranges.join(',');
  }

  static List<String> teacherTokens(String teacherText) {
    return teacherText
        .split(RegExp(r'[、,，;；/\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String mergeTeacherText(Iterable<String> texts) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final text in texts) {
      for (final token in teacherTokens(text)) {
        if (seen.add(token)) {
          ordered.add(token);
        }
      }
    }
    return ordered.join('、');
  }

  static CourseRecord mergeRecords(List<CourseRecord> records) {
    final base = records.first;
    final mergedWeeks = records.expand((r) => r.week).toSet().toList()..sort();
    final mergedTeacher = mergeTeacherText(records.map((r) => r.teacher));
    final mergedCampus = records
        .map((r) => r.campusName.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => base.campusName);
    final mergedPlace = records
        .map((r) => r.placeName.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => base.placeName);
    return CourseRecord(
      courseName: base.courseName,
      week: mergedWeeks,
      dayOfWeek: base.dayOfWeek,
      periods: base.periods,
      teacher: mergedTeacher,
      campusName: mergedCampus,
      placeName: mergedPlace,
      isOnline: base.isOnline,
    );
  }
}
