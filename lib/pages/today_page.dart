import 'package:flutter/material.dart';

import '../config/class_period_time_ranges.dart';
import '../config/color_palette.dart';
import '../config/course_utils.dart';
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
  final _palette = ColorPalette();

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
      // 清除缓存
      _cachedTodayCourses = null;
      _cachedWeek = null;
      _cachedWeekday = null;
    });
  }

  Future<void> reloadTermStartDate() async {
    final date = await SessionStore.loadTermStartDate();
    if (!mounted) {
      return;
    }
    setState(() {
      _termStartDate = date;
      // 清除缓存
      _cachedTodayCourses = null;
      _cachedWeek = null;
      _cachedWeekday = null;
    });
  }

  int _currentWeek() => CourseUtils.computeCurrentWeek(
    termStartDate: _termStartDate,
    maxWeek: CourseUtils.findMaxWeek(_records),
  );

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

  Color _statusBackgroundColor(String status, bool isDark) {
    if (isDark) {
      switch (status) {
        case '上课中':
          return const Color(0xFF1B3D2F);
        case '已结束':
          return const Color(0xFF2D3238);
        default:
          return const Color(0xFF3D3425);
      }
    }
    switch (status) {
      case '上课中':
        return const Color(0xFFDBF6E8);
      case '已结束':
        return const Color(0xFFE8ECF1);
      default:
        return const Color(0xFFFFF1D8);
    }
  }

  Color _statusTextColor(String status, bool isDark) {
    if (isDark) {
      switch (status) {
        case '上课中':
          return const Color(0xFF7DDCA0);
        case '已结束':
          return const Color(0xFF8B9199);
        default:
          return const Color(0xFFD4A857);
      }
    }
    switch (status) {
      case '上课中':
        return const Color(0xFF1C7A4F);
      case '已结束':
        return const Color(0xFF5A6572);
      default:
        return const Color(0xFF8A5A13);
    }
  }

  Color _accentColor(String key) => _palette.colorFor(key);

  List<CourseRecord>? _cachedTodayCourses;
  int? _cachedWeek;
  int? _cachedWeekday;

  List<CourseRecord> _todayCourses() {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final currentWeek = _currentWeek();

    // 使用缓存避免重复计算
    if (_cachedTodayCourses != null &&
        _cachedWeek == currentWeek &&
        _cachedWeekday == todayWeekday) {
      return _cachedTodayCourses!;
    }

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

    final merged = grouped.values.map(CourseUtils.mergeRecords).toList();
    merged.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    _cachedTodayCourses = merged;
    _cachedWeek = currentWeek;
    _cachedWeekday = todayWeekday;

    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeek = _currentWeek();
    final weekdayText = _weekdayLabels[now.weekday - 1];
    final courses = _todayCourses();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('第$currentWeek周 $weekdayText'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : null,
                gradient: isDark
                    ? null
                    : const LinearGradient(
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
                  ? Center(
                      child: Text(
                        '今天没课哦，好好休息吧~',
                        style: TextStyle(
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : const Color(0xFF1F4E73),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = courses[index];
                        final accent = _accentColor(record.courseName);
                        final status = _courseStatus(record);
                        return Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.surfaceContainerHigh
                                : Colors.white.withValues(alpha: 0.95),
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
                                        Icon(
                                          Icons.navigation,
                                          size: 14,
                                          color: isDark
                                              ? theme
                                                    .colorScheme
                                                    .onSurfaceVariant
                                              : const Color(0xFF6F8EA8),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatCourseTime(record),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.25,
                                            color: isDark
                                                ? theme
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                : const Color(0xFF2E4558),
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
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${record.startPeriod}-${record.endPeriod}节',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
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
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            record.placeName.trim().isEmpty
                                                ? '地点待定'
                                                : record.placeName.trim(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  theme.colorScheme.onSurface,
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
                                    color: _statusBackgroundColor(
                                      status,
                                      isDark,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _statusTextColor(status, isDark),
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
