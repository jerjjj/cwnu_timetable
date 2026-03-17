class CourseRecord {
  CourseRecord({
    required this.courseName,
    required this.week,
    required this.dayOfWeek,
    required this.periods,
    required this.teacher,
    required this.campusName,
    required this.placeName,
    required this.isOnline,
  });

  final String courseName;
  final List<int> week;
  final int dayOfWeek;
  final String periods;
  final String teacher;
  final String campusName;
  final String placeName;
  final bool isOnline;

  factory CourseRecord.fromJson(Map<String, dynamic> json) {
    return CourseRecord(
      courseName: json['course_name']?.toString() ?? '未命名课程',
      week: (json['week'] is List)
          ? (json['week'] as List)
                .map((e) => int.tryParse(e.toString()) ?? -1)
                .where((e) => e > 0)
                .toList()
          : <int>[],
      dayOfWeek: int.tryParse(json['day_of_week']?.toString() ?? '') ?? 1,
      periods: json['periods']?.toString() ?? '',
      teacher: json['teacher']?.toString() ?? '',
      campusName: json['campus_name']?.toString() ?? '',
      placeName: json['place_name']?.toString() ?? '',
      isOnline: _parseIsOnline(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_name': courseName,
      'week': week,
      'day_of_week': dayOfWeek,
      'periods': periods,
      'teacher': teacher,
      'campus_name': campusName,
      'place_name': placeName,
      'is_online': isOnline,
    };
  }

  static bool _parseIsOnline(Map<String, dynamic> json) {
    final raw = json['is_online'];
    if (raw is bool) {
      return raw;
    }

    final text = '${json['campus_name'] ?? ''} ${json['place_name'] ?? ''}'
        .trim();
    return text.contains('网络课程') || text.contains('线上');
  }

  int get startPeriod {
    final periodsList = _extractPeriods(periods);
    return periodsList.first;
  }

  int get endPeriod {
    final periodsList = _extractPeriods(periods);
    return periodsList.last;
  }

  static List<int> _extractPeriods(String value) {
    final digitMatches = RegExp(
      r'\d+',
    ).allMatches(value).map((m) => int.parse(m.group(0)!)).toList();
    if (digitMatches.isNotEmpty) {
      if (digitMatches.length == 1) {
        return [digitMatches.first, digitMatches.first];
      }
      return [digitMatches.first, digitMatches.last];
    }

    final cn = <String, int>{
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
    };
    final tokens = RegExp(
      r'[一二三四五六七八九十]+',
    ).allMatches(value).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) {
      return const [1, 1];
    }

    int toNum(String t) {
      if (t == '十') {
        return 10;
      }
      if (t.startsWith('十') && t.length == 2) {
        return 10 + (cn[t.substring(1)] ?? 0);
      }
      if (t.endsWith('十') && t.length == 2) {
        return (cn[t.substring(0, 1)] ?? 0) * 10;
      }
      if (t.length == 2 && t.contains('十')) {
        return (cn[t.substring(0, 1)] ?? 0) * 10 + (cn[t.substring(1)] ?? 0);
      }
      return cn[t] ?? 1;
    }

    if (tokens.length == 1) {
      final n = toNum(tokens.first);
      return [n, n];
    }
    return [toNum(tokens.first), toNum(tokens.last)];
  }
}
