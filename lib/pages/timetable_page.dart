import 'package:flutter/material.dart';

import '../config/class_period_time_ranges.dart';
import '../config/color_palette.dart';
import '../config/course_utils.dart';
import '../features/timetable/presentation/widgets/online_courses_sheet.dart';
import '../features/timetable/presentation/widgets/timetable_grid.dart';
import '../models/auth_session.dart';
import '../models/course_record.dart';
import '../services/session_store.dart';
import '../services/timetable_api.dart';
import '../widgets/course_detail_dialog.dart';
import '../widgets/week_picker_dialog.dart';

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
  final _palette = ColorPalette();
  bool _isRefreshing = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _records = widget.initialRecords;
    _maxWeek = CourseUtils.findMaxWeek(_records);
    _termStartDate = SessionStore.defaultTermStartDate();
    _selectedWeek = CourseUtils.computeCurrentWeek(
      termStartDate: _termStartDate,
      maxWeek: _maxWeek,
    );
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
      _selectedWeek = CourseUtils.computeCurrentWeek(
        termStartDate: _termStartDate,
        maxWeek: _maxWeek,
      );
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

  List<CourseRecord> get _visibleRecords {
    return _records.where((r) => !r.isOnline).toList();
  }

  List<CourseRecord> get _onlineRecords {
    final list = _records.where((r) => r.isOnline).toList();
    list.sort((a, b) {
      final aWeek = a.week.isEmpty ? 0 : a.week.first;
      final bWeek = b.week.isEmpty ? 0 : b.week.first;
      final weekCompare = aWeek.compareTo(bWeek);
      if (weekCompare != 0) return weekCompare;
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
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

  Color _colorFor(String key) => _palette.colorFor(key);

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
    final candidates = _visibleRecords
        .where(
          (r) =>
              r.courseName == record.courseName &&
              r.dayOfWeek == record.dayOfWeek &&
              r.startPeriod == record.startPeriod &&
              r.endPeriod == record.endPeriod &&
              r.week.contains(_selectedWeek),
        )
        .toList();
    final currentWeekRecord = candidates.isNotEmpty
        ? CourseUtils.mergeRecords(candidates)
        : record;

    CourseDetailDialog.show(
      context,
      record: currentWeekRecord,
      color: color,
      teacherText: currentWeekRecord.teacher.trim().isEmpty
          ? '暂无教师'
          : currentWeekRecord.teacher.trim(),
      placeText: currentWeekRecord.placeName.trim().isEmpty
          ? '地点待定'
          : currentWeekRecord.placeName.trim(),
      timeText: _formatCourseTime(currentWeekRecord),
      weeksText: CourseUtils.formatWeekRanges(currentWeekRecord.week),
    );
  }

  void _showWeekPickerDialog() {
    WeekPickerDialog.show(
      context,
      maxWeek: _maxWeek,
      selectedWeek: _selectedWeek,
      onWeekSelected: (week) {
        setState(() {
          _selectedWeek = week;
        });
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
        formatWeekRanges: CourseUtils.formatWeekRanges,
        colorFor: _colorFor,
      ),
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
        final newMaxWeek = CourseUtils.findMaxWeek(records);
        _maxWeek = newMaxWeek;
        _selectedWeek = CourseUtils.computeCurrentWeek(
          termStartDate: _termStartDate,
          maxWeek: newMaxWeek,
        );
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leadingWidth: 108,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: TextButton(
            onPressed: _showOnlineCourses,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, size: 18),
                SizedBox(width: 4),
                Text('线上课'),
              ],
            ),
          ),
        ),
        title: Text('第$_selectedWeek周'),
        centerTitle: true,
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
