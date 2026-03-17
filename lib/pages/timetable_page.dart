import 'package:flutter/material.dart';

import '../config/class_period_time_ranges.dart';
import '../features/timetable/presentation/widgets/online_courses_sheet.dart';
import '../features/timetable/presentation/widgets/timetable_grid.dart';
import '../models/auth_session.dart';
import '../models/course_record.dart';
import '../services/session_store.dart';
import '../services/timetable_api.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({
    super.key,
    required this.session,
    required this.initialRecords,
  });

  final AuthSession session;
  final List<CourseRecord> initialRecords;

  @override
  State<TimetablePage> createState() => TimetablePageState();
}

class TimetablePageState extends State<TimetablePage> {
  static const _days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  late List<CourseRecord> _records;
  late int _maxWeek;
  late int _selectedWeek;
  late DateTime _termStartDate;
  final Map<String, Color> _courseColorCache = <String, Color>{};
  final Set<int> _usedColorValues = <int>{};
  final List<double> _usedHues = <double>[];
  bool _isRefreshing = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _records = widget.initialRecords;
    _maxWeek = _findMaxWeek(_records);
    _termStartDate = SessionStore.defaultTermStartDate();
    _selectedWeek = _computeCurrentWeek(maxWeek: _maxWeek);
    _loadTermStartDate();
    _maybeAutoRefreshTimetable();
  }

  Future<void> _maybeAutoRefreshTimetable() async {
    final shouldRefresh = await SessionStore.shouldAutoRefreshTimetable();
    if (!shouldRefresh || !mounted) {
      return;
    }
    await _refreshTimetable(silent: true);
  }

  Future<void> _loadTermStartDate() async {
    final date = await SessionStore.loadTermStartDate();
    if (!mounted) {
      return;
    }
    setState(() {
      _termStartDate = date;
      _selectedWeek = _computeCurrentWeek(maxWeek: _maxWeek);
    });
  }

  Future<void> reloadTermStartDate() => _loadTermStartDate();

  Future<void> checkAndRefreshForWidget() async {
    final shouldRefresh = await SessionStore.shouldRefreshTimetableForWidget();
    if (shouldRefresh && mounted) {
      await _refreshTimetable(silent: true);
      await SessionStore.markWidgetSyncedNow();
    }
  }

  int _computeCurrentWeek({required int maxWeek}) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
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

  int _findMaxWeek(List<CourseRecord> records) {
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

  List<CourseRecord> get _visibleRecords {
    return _records.where((r) => !r.isOnline).toList();
  }

  List<CourseRecord> get _onlineRecords {
    final list = _records.where((r) => r.isOnline).toList();
    list.sort((a, b) {
      final aWeek = a.week.isEmpty ? 0 : a.week.first;
      final bWeek = b.week.isEmpty ? 0 : b.week.first;
      final weekCompare = aWeek.compareTo(bWeek);
      if (weekCompare != 0) {
        return weekCompare;
      }
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) {
        return dayCompare;
      }
      return a.startPeriod.compareTo(b.startPeriod);
    });
    return list;
  }

  List<CourseRecord> _recordsByDay(int day) {
    final list = _visibleRecords.where((r) => r.dayOfWeek == day).toList();
    list.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
    return list;
  }

  int get _totalPeriods {
    var maxPeriod = 12;
    for (final record in _visibleRecords) {
      if (record.endPeriod > maxPeriod) {
        maxPeriod = record.endPeriod;
      }
    }
    return maxPeriod;
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

  Color _colorFor(String key) {
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

  String _formatWeekRanges(List<int> weeks) {
    if (weeks.isEmpty) {
      return '';
    }
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

  CourseRecord _resolveCurrentWeekRecord(CourseRecord tapped) {
    final candidates = _visibleRecords.where((record) {
      return record.courseName == tapped.courseName &&
          record.dayOfWeek == tapped.dayOfWeek &&
          record.startPeriod == tapped.startPeriod &&
          record.endPeriod == tapped.endPeriod &&
          record.week.contains(_selectedWeek);
    }).toList();
    return candidates.isNotEmpty ? _mergeRecords(candidates) : tapped;
  }

  String _formatCourseTime(CourseRecord record) {
    final start = classPeriodTimeRanges[record.startPeriod];
    final end = classPeriodTimeRanges[record.endPeriod];
    if (start != null && end != null) {
      final startPart = start.split('-').first;
      final endPart = end.split('-').last;
      return '$startPart - $endPart';
    }
    return '第${record.startPeriod}-${record.endPeriod}节';
  }

  void _showCourseDialog(CourseRecord record, Color color) {
    final currentWeekRecord = _resolveCurrentWeekRecord(record);
    final teacherText = currentWeekRecord.teacher.trim().isEmpty
        ? '暂无教师'
        : currentWeekRecord.teacher.trim();
    final placeText = currentWeekRecord.placeName.trim().isEmpty
        ? '地点待定'
        : currentWeekRecord.placeName.trim();
    final timeText = _formatCourseTime(currentWeekRecord);
    final weeksText = _formatWeekRanges(currentWeekRecord.week);
    const textColor = Colors.white;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: color.withValues(alpha: 0.96),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentWeekRecord.courseName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  teacherText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  placeText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  weeksText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOnlineCourses() {
    final onlineRecords = _onlineRecords;
    if (onlineRecords.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('当前没有线上课程'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => OnlineCoursesSheet(
        records: onlineRecords,
        days: _days,
        formatWeekRanges: _formatWeekRanges,
        colorFor: _colorFor,
      ),
    );
  }

  void _showWeekPickerDialog() {
    final end = _maxWeek < 20 ? _maxWeek : 20;
    final weeks = List.generate(end, (i) => i + 1);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFF4F6FA),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: 360,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: weeks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.82,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final week = weeks[index];
                  final isSelected = week == _selectedWeek;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _selectedWeek = week;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE2F0FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF3B78AC)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '第$week周',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: const Color(0xFF1C2A39),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUpdateToast() {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('课表更新成功'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshTimetable({bool silent = false}) async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      if (!silent) {
        _errorText = null;
      }
    });

    try {
      final records = await TimetableApi.fetchReadableTimetable(
        ssoUsername: widget.session.username,
        ssoPassword: widget.session.password,
        jwxtUsername: widget.session.username,
        jwxtPassword: widget.session.jwxtPassword,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        final newMaxWeek = _findMaxWeek(records);
        _maxWeek = newMaxWeek;
        _selectedWeek = _computeCurrentWeek(maxWeek: newMaxWeek);
      });
      await SessionStore.saveCachedRecords(records);
      await SessionStore.markTimetableSyncedNow();
      _showUpdateToast();
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      appBar: AppBar(
        leadingWidth: 108,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: TextButton(
            onPressed: _showOnlineCourses,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, size: 18),
                SizedBox(width: 4),
                Text('线上课'),
              ],
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
        title: Text('第$_selectedWeek周'),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showWeekPickerDialog,
            icon: const Icon(Icons.view_module_rounded),
            tooltip: '切换周次',
          ),
          IconButton(
            onPressed: _isRefreshing ? null : () => _refreshTimetable(),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新课表',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorText != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFE9E9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _errorText!,
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            ),
          Expanded(
            child: TimetableGrid(
              days: _days,
              totalPeriods: _totalPeriods,
              selectedWeek: _selectedWeek,
              termStartDate: _termStartDate,
              recordsByDay: _recordsByDay,
              colorFor: _colorFor,
              onCourseTap: _showCourseDialog,
            ),
          ),
        ],
      ),
    );
  }
}
