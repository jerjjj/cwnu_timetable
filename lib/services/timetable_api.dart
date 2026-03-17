import 'dart:convert';
import 'dart:typed_data';

import '../models/course_record.dart';
import '../src/rust/api.dart' as rust_api;

class TimetableApi {
  static Future<List<CourseRecord>> fetchReadableTimetable({
    required String ssoUsername,
    required String ssoPassword,
    required String jwxtUsername,
    required String jwxtPassword,
  }) async {
    try {
      return await _fetchViaRustFfi(
        ssoUsername: ssoUsername,
        ssoPassword: ssoPassword,
        jwxtUsername: jwxtUsername,
        jwxtPassword: jwxtPassword,
      );
    } on Exception catch (e) {
      throw Exception('Rust抓取失败: $e');
    }
  }

  /// 第一阶段：检查 SSO 是否需要验证码并存储会话。
  /// 返回 null 表示无需验证码，可直接调用 [fetchReadableTimetableWithCaptcha]（captcha 传空）。
  /// 返回 Uint8List 表示需要验证码，内容为图片字节（JPEG/PNG）。
  static Future<Uint8List?> checkSsoCaptcha({
    required String ssoUsername,
    required String ssoPassword,
  }) async {
    try {
      return await rust_api.checkSsoCaptchaFrb(
        username: ssoUsername,
        password: ssoPassword,
      );
    } on Exception catch (e) {
      throw Exception('Rust抓取失败: $e');
    }
  }

  /// 第二阶段：使用已存储的 SSO 会话完成登录并拉取课表。
  /// 无需验证码时 [captcha] 传空字符串。
  static Future<List<CourseRecord>> fetchReadableTimetableWithCaptcha({
    required String jwxtUsername,
    required String jwxtPassword,
    required String captcha,
  }) async {
    try {
      final jsonStr = await rust_api.fetchTimetableJsonWithCaptchaFrb(
        jwxtUsername: jwxtUsername,
        jwxtPassword: jwxtPassword,
        captcha: captcha,
      );
      final rawData = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _parseRecords(rawData);
    } on Exception catch (e) {
      throw Exception('Rust抓取失败: $e');
    }
  }

  static Future<List<CourseRecord>> _fetchViaRustFfi({
    required String ssoUsername,
    required String ssoPassword,
    required String jwxtUsername,
    required String jwxtPassword,
  }) async {
    final jsonStr = await rust_api.fetchTimetableJsonSimpleFrb(
      ssoUsername: ssoUsername,
      ssoPassword: ssoPassword,
      jwxtUsername: jwxtUsername,
      jwxtPassword: jwxtPassword,
    );
    final rawData = jsonDecode(jsonStr) as Map<String, dynamic>;
    return _parseRecords(rawData);
  }

  static List<CourseRecord> _parseRecords(Map<String, dynamic> rawData) {
    final lessonsRaw = rawData['lessons'];
    final lessons = lessonsRaw is List ? lessonsRaw : <dynamic>[];
    final records = <CourseRecord>[];

    final schedulePattern = RegExp(
      r'(\d+\s*~\s*\d+周|\d+周)\s+(周[一二三四五六日天])\s+(第[一二三四五六七八九十\d]+节(?:\s*~\s*第[一二三四五六七八九十\d]+节)?)\s*(.*)',
    );
    const dayMap = {
      '周一': 1,
      '周二': 2,
      '周三': 3,
      '周四': 4,
      '周五': 5,
      '周六': 6,
      '周日': 7,
      '周天': 7,
    };

    for (final lessonRaw in lessons) {
      if (lessonRaw is! Map) {
        continue;
      }
      final lesson = lessonRaw.cast<String, dynamic>();
      final course = (lesson['course'] is Map)
          ? (lesson['course'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final scheduleText =
          (((lesson['scheduleText'] as Map?)?['dateTimePlacePersonText']
                  as Map?)?['textZh'])
              ?.toString() ??
          '';
      if (scheduleText.trim().isEmpty) {
        continue;
      }

      final courseName = (course['nameZh'] ?? lesson['nameZh'] ?? '未命名课程')
          .toString();
      final teacherFallback = _parseTeachers(
        lesson['teacherAssignmentStr']?.toString(),
      );
      final campusFallback =
          ((lesson['campus'] as Map?)?['nameZh'])?.toString() ?? '';

      for (final line
          in scheduleText
              .split(RegExp(r'[;；\n\r]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)) {
        final match = schedulePattern.firstMatch(line);
        if (match == null) {
          continue;
        }

        final weekText = (match.group(1) ?? '').replaceAll(RegExp(r'\s+'), '');
        final weeks = _expandWeeks(weekText);
        final dayNum = dayMap[(match.group(2) ?? '').trim()];
        if (dayNum == null) {
          continue;
        }
        final periods = (match.group(3) ?? '').replaceAll(RegExp(r'\s+'), '');
        final rest = match.group(4) ?? '';

        final locTea = _parseLocationTeacher(rest, teacherFallback);
        final splitLoc = _splitCampusPlace(locTea.location);

        var campus = splitLoc.campus;
        var place = splitLoc.place;
        if (campus.isEmpty) {
          campus = campusFallback;
        }
        final isOnline =
            campus == '网络课程' ||
            place == '线上' ||
            locTea.location.contains('网络课程');
        if (place.isEmpty && campus == '网络课程') {
          place = '线上';
        }
        if (place.isEmpty && locTea.location.isNotEmpty) {
          place = locTea.location;
        }

        records.add(
          CourseRecord(
            courseName: courseName,
            week: weeks,
            dayOfWeek: dayNum,
            periods: periods,
            teacher: locTea.teacher,
            campusName: campus,
            placeName: place,
            isOnline: isOnline,
          ),
        );
      }
    }

    return records;
  }

  static String _parseTeachers(String? assignment) {
    if (assignment == null || assignment.trim().isEmpty) {
      return '';
    }
    final list = <String>[];
    for (final item in assignment.split(RegExp(r'[;；,，]+'))) {
      var s = item.trim();
      if (s.isEmpty) {
        continue;
      }
      s = s.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
      if (s.isNotEmpty) {
        list.add(s);
      }
    }
    return list.join('、');
  }

  static List<int> _expandWeeks(String text) {
    final m1 = RegExp(r'^(\d+)~(\d+)周$').firstMatch(text);
    if (m1 != null) {
      final s = int.parse(m1.group(1)!);
      final e = int.parse(m1.group(2)!);
      if (s <= e) {
        return List<int>.generate(e - s + 1, (i) => s + i);
      }
    }
    final m2 = RegExp(r'^(\d+)周$').firstMatch(text);
    if (m2 != null) {
      return [int.parse(m2.group(1)!)];
    }
    return <int>[];
  }

  static ({String location, String teacher}) _parseLocationTeacher(
    String rest,
    String fallbackTeacher,
  ) {
    final normalized = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return (location: '', teacher: fallbackTeacher);
    }

    final tokens = normalized.split(' ');
    if (tokens.length == 1) {
      return (location: tokens.first, teacher: fallbackTeacher);
    }

    var teacher = tokens.last;
    var location = tokens.sublist(0, tokens.length - 1).join(' ').trim();

    if (RegExp(r'课程|校区|楼|实验室|田径场').hasMatch(teacher)) {
      teacher = fallbackTeacher;
      location = normalized;
    }

    if (teacher.isEmpty) {
      teacher = fallbackTeacher;
    }

    return (location: location, teacher: teacher);
  }

  static ({String campus, String place}) _splitCampusPlace(String location) {
    final normalized = location.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return (campus: '', place: '');
    }
    if (normalized.contains('网络课程')) {
      return (campus: '网络课程', place: '');
    }
    final m = RegExp(r'^(.*?校区)\s*(.*)$').firstMatch(normalized);
    if (m != null) {
      return (
        campus: (m.group(1) ?? '').trim(),
        place: (m.group(2) ?? '').trim(),
      );
    }
    return (campus: '', place: normalized);
  }
}
