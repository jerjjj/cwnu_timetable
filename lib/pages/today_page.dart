import 'package:flutter/material.dart';

import '../config/class_period_time_ranges.dart';
import '../models/course_record.dart';
import '../services/session_store.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.initialRecords});

  final List<CourseRecord> initialRecords;

  @override
  State<TodayPage> createState() => TodayPageState();
}

class TodayPageState extends State<TodayPage> {
  static const _weekdayLabels = <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  late List<CourseRecord> _records;
  late DateTime _termStartDate;
  bool _loading = true;
  final Map<String, Color> _courseColorCache = <String, Color>{};
  final Set<int> _usedColorValues = <int>{};
  final List<double> _usedHues = <double>[];

  @override
  void initState() {
    super.initState();
    _records = widget.initialRecords;
    _termStartDate = SessionStore.defaultTermStartDate();
    _load();
  }

  Future<void> _load() async {
    final date = await SessionStore.loadTermStartDate();
    final cached = await SessionStore.loadCachedRecords();
    if (!mounted) {
      return;
    }
    setState(() {
      _termStartDate = date;
      if (cached.isNotEmpty) {
        _records = cached;
      }
      _loading = false;
    });
  }

  Future<void> reloadFromCache() async {
    final cached = await SessionStore.loadCachedRecords();
    if (!mounted) {
      return;
    }
    setState(() {
      if (cached.isNotEmpty) {
        _records = cached;
      }
    });
  }

  Future<void> reloadTermStartDate() async {
    final date = await SessionStore.loadTermStartDate();
    if (!mounted) {
      return;
    }
    setState(() {
      _termStartDate = date;
    });
  }

  int _findMaxWeek() {
    var maxWeek = 1;
    for (final r in _records) {
      for (final w in r.week) {
        if (w > maxWeek) {
          maxWeek = w;
        }
      }
    }
    return maxWeek;
  }

  int _computeCurrentWeek() {
    final maxWeek = _findMaxWeek();
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      _termStartDate.year,
      _termStartDate.month,
      _termStartDate.day,
    );

    final diffDays = todayDate.difference(startDate).inDays;
    var week = diffDays < 0 ? 1 : (diffDays ~/ 7) + 1;
    if (week < 1) {
      week = 1;
    }
    if (week > maxWeek) {
      week = maxWeek;
    }
    return week;
  }

  String _formatCourseTime(CourseRecord record) {
    final start = classPeriodTimeRanges[record.startPeriod];
    final end = classPeriodTimeRanges[record.endPeriod];
    if (start == null || end == null) {
      return '第${record.startPeriod}-${record.endPeriod}节';
    }
    final startPart = start.split('-').first;
    final endPart = end.split('-').last;
    return '$startPart\n$endPart';
  }

  DateTime? _dateTimeForPeriod(int period, {required bool isStart}) {
    final value = classPeriodTimeRanges[period];
    if (value == null) {
      return null;
    }
    final parts = value.split('-');
    if (parts.length != 2) {
      return null;
    }
    final text = isStart ? parts.first : parts.last;
    final hhmm = text.split(':');
    if (hhmm.length != 2) {
      return null;
    }
    final hour = int.tryParse(hhmm[0]);
    final minute = int.tryParse(hhmm[1]);
    if (hour == null || minute == null) {
      return null;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _courseStatus(CourseRecord record) {
    final startAt = _dateTimeForPeriod(record.startPeriod, isStart: true);
    final endAt = _dateTimeForPeriod(record.endPeriod, isStart: false);
    if (startAt == null || endAt == null) {
      return '未开始';
    }

    final now = DateTime.now();
    if (now.isBefore(startAt)) {
      return '未开始';
    }
    if (now.isAfter(endAt)) {
      return '已结束';
    }
    return '上课中';
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case '上课中':
        return const Color(0xFFDBF6E8);
      case '已结束':
        return const Color(0xFFE8ECF1);
      default:
        return const Color(0xFFFFF1D8);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case '上课中':
        return const Color(0xFF1C7A4F);
      case '已结束':
        return const Color(0xFF5A6572);
      default:
        return const Color(0xFF8A5A13);
    }
  }

  bool _isHueFarEnough(double hue) {
    const minGap = 34.0;
    for (final usedHue in _usedHues) {
      final rawDiff = (hue - usedHue).abs();
      final diff = rawDiff > 180 ? 360 - rawDiff : rawDiff;
      if (diff < minGap) {
        return false;
      }
    }
    return true;
  }

  Color _accentColor(String key) {
    final cached = _courseColorCache[key];
    if (cached != null) {
      return cached;
    }

    final seed = key.hashCode & 0x7fffffff;
    for (var i = 0; i < 72; i++) {
      final hue = ((seed % 360) + i * 137.50776405) % 360;
      if (!_isHueFarEnough(hue)) {
        continue;
      }

      final saturation = 0.58 + ((seed + i * 17) % 12) / 100.0;
      final lightness = 0.64 + ((seed + i * 29) % 10) / 100.0;
      final candidate = HSLColor.fromAHSL(
        1,
        hue,
        saturation.clamp(0.56, 0.72),
        lightness.clamp(0.62, 0.74),
      ).toColor();
      final value = candidate.value;
      if (!_usedColorValues.contains(value)) {
        _usedColorValues.add(value);
        _usedHues.add(hue);
        _courseColorCache[key] = candidate;
        return candidate;
      }
    }

    final fallback = HSLColor.fromAHSL(
      1,
      (seed % 360).toDouble(),
      0.64,
      0.7,
    ).toColor();
    _usedColorValues.add(fallback.value);
    _usedHues.add((seed % 360).toDouble());
    _courseColorCache[key] = fallback;
    return fallback;
  }

  List<String> _teacherTokens(String teacherText) {
    return teacherText
        .split(RegExp(r'[、,，;；/\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _mergeTeacherText(Iterable<String> texts) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final text in texts) {
      for (final token in _teacherTokens(text)) {
        if (seen.add(token)) {
          ordered.add(token);
        }
      }
    }
    return ordered.join('、');
  }

  CourseRecord _mergeRecords(List<CourseRecord> records) {
    final base = records.first;
    final mergedWeeks = records.expand((record) => record.week).toSet().toList()
      ..sort();
    final mergedTeacher = _mergeTeacherText(
      records.map((record) => record.teacher),
    );
    final mergedCampus = records
        .map((record) => record.campusName.trim())
        .firstWhere((text) => text.isNotEmpty, orElse: () => base.campusName);
    final mergedPlace = records
        .map((record) => record.placeName.trim())
        .firstWhere((text) => text.isNotEmpty, orElse: () => base.placeName);
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

  List<CourseRecord> _todayCourses() {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final currentWeek = _computeCurrentWeek();

    final courses = _records
        .where((r) => !r.isOnline)
        .where((r) => r.dayOfWeek == todayWeekday)
        .where((r) => r.week.contains(currentWeek))
        .toList();

    final grouped = <String, List<CourseRecord>>{};
    for (final record in courses) {
      final key =
          '${record.courseName}|${record.dayOfWeek}|${record.startPeriod}-${record.endPeriod}';
      grouped.putIfAbsent(key, () => <CourseRecord>[]).add(record);
    }

    final merged = grouped.values.map(_mergeRecords).toList();
    merged.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeek = _computeCurrentWeek();
    final weekdayText = _weekdayLabels[now.weekday - 1];
    final courses = _todayCourses();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      appBar: AppBar(
        title: Text('第$currentWeek周 $weekdayText'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF2F4F8),
        surfaceTintColor: const Color(0xFFF2F4F8),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF4EA8E5),
                    Color(0xFF7DB9E6),
                    Color(0xFFD4E9F9),
                  ],
                ),
              ),
              child: courses.isEmpty
                  ? const Center(
                      child: Text(
                        '今天没课哦，好好休息吧~',
                        style: TextStyle(
                          color: Color(0xFF1F4E73),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      itemCount: courses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = courses[index];
                        final accent = _accentColor(record.courseName);
                        final status = _courseStatus(record);
                        return Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Stack(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 1),
                                        const Icon(
                                          Icons.navigation,
                                          size: 14,
                                          color: Color(0xFF6F8EA8),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatCourseTime(record),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            height: 1.25,
                                            color: Color(0xFF2E4558),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 4,
                                    height: 82,
                                    margin: const EdgeInsets.only(
                                      left: 4,
                                      right: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  record.courseName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1D2430),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${record.startPeriod}-${record.endPeriod}节',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1D2430),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            record.teacher.trim().isEmpty
                                                ? '暂无教师'
                                                : record.teacher.trim(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1D2430),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            record.placeName.trim().isEmpty
                                                ? '地点待定'
                                                : record.placeName.trim(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1D2430),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusBackgroundColor(status),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _statusTextColor(status),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
