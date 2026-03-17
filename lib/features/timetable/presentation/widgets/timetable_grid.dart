import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../../../models/course_record.dart';

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.days,
    required this.totalPeriods,
    required this.selectedWeek,
    required this.termStartDate,
    required this.recordsByDay,
    required this.colorFor,
    required this.onCourseTap,
  });

  final List<String> days;
  final int totalPeriods;
  final int selectedWeek;
  final DateTime termStartDate;
  final List<CourseRecord> Function(int day) recordsByDay;
  final Color Function(String key) colorFor;
  final void Function(CourseRecord record, Color color) onCourseTap;

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _dateForDay(int dayIndex) {
    final offsetDays = (selectedWeek - 1) * 7 + dayIndex;
    return _normalizeDate(termStartDate).add(Duration(days: offsetDays));
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

  List<CourseRecord> _selectRecordsForDisplay(List<CourseRecord> dayRecords) {
    final currentWeekOnly = dayRecords
        .where((record) => record.week.contains(selectedWeek))
        .toList();
    if (currentWeekOnly.isEmpty) {
      return const <CourseRecord>[];
    }

    final mergedByCourse = <String, List<CourseRecord>>{};
    for (final record in currentWeekOnly) {
      final key =
          '${record.courseName}|${record.dayOfWeek}|${record.startPeriod}-${record.endPeriod}';
      mergedByCourse.putIfAbsent(key, () => <CourseRecord>[]).add(record);
    }
    final normalized = mergedByCourse.values.map(_mergeRecords).toList();

    final grouped = <String, List<CourseRecord>>{};
    for (final record in normalized) {
      final key = '${record.startPeriod}-${record.endPeriod}';
      grouped.putIfAbsent(key, () => <CourseRecord>[]).add(record);
    }

    final selected = <CourseRecord>[];
    for (final entry in grouped.entries) {
      final records = entry.value;
      // 同一时间段只显示一个课程，按课程名排序后选择第一个。
      records.sort((a, b) => a.courseName.compareTo(b.courseName));
      selected.add(records.first);
    }

    selected.sort((a, b) {
      final startCompare = a.startPeriod.compareTo(b.startPeriod);
      if (startCompare != 0) {
        return startCompare;
      }
      return a.endPeriod.compareTo(b.endPeriod);
    });
    return _resolveOverlappingRecords(selected);
  }

  List<CourseRecord> _resolveOverlappingRecords(List<CourseRecord> records) {
    if (records.length <= 1) {
      return records;
    }

    CourseRecord pickBetter(CourseRecord a, CourseRecord b) {
      final aDuration = a.endPeriod - a.startPeriod;
      final bDuration = b.endPeriod - b.startPeriod;
      if (aDuration != bDuration) {
        // Prefer more specific ranges (e.g. 1-2 over 1-5) to avoid overlap.
        return aDuration < bDuration ? a : b;
      }

      final aWeekCount = a.week.length;
      final bWeekCount = b.week.length;
      if (aWeekCount != bWeekCount) {
        return aWeekCount > bWeekCount ? a : b;
      }

      return a.startPeriod <= b.startPeriod ? a : b;
    }

    final byPeriod = <int, CourseRecord>{};
    for (final record in records) {
      for (var p = record.startPeriod; p <= record.endPeriod; p++) {
        final current = byPeriod[p];
        if (current == null) {
          byPeriod[p] = record;
        } else {
          byPeriod[p] = pickBetter(current, record);
        }
      }
    }

    final unique = byPeriod.values.toSet().toList();
    unique.sort((a, b) {
      final startCompare = a.startPeriod.compareTo(b.startPeriod);
      if (startCompare != 0) {
        return startCompare;
      }
      return a.endPeriod.compareTo(b.endPeriod);
    });
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7FC3F5), Color(0xFF9AD4F8), Color(0xFFB8E0F8)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const leftWidth = 24.0;
          const headerHeight = 32.0;
          const rowHeight = 98.0;

          final gridHeight = totalPeriods * rowHeight;
          final fittedDayWidth = (constraints.maxWidth - leftWidth) / 7;
          final dayWidth = fittedDayWidth < 62 ? 62.0 : fittedDayWidth;
          final tableWidth = leftWidth + dayWidth * 7;
          final today = _normalizeDate(DateTime.now());
          final monthLabel =
              '${_dateForDay(0).month.toString().padLeft(2, '0')}\n月';

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: SingleChildScrollView(
                child: SizedBox(
                  height: headerHeight + gridHeight + 12,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: leftWidth,
                        height: headerHeight,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E3B62),
                            border: Border.all(
                              color: const Color(0xFF3D84BE),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            monthLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: leftWidth,
                        right: 0,
                        top: 0,
                        height: headerHeight,
                        child: Row(
                          children: List.generate(7, (i) {
                            final dayDate = _dateForDay(i);
                            final isToday = dayDate == today;
                            return Container(
                              width: dayWidth,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? const Color(0xFF1E5B8B)
                                    : const Color(0xFF2B6EA7),
                                border: Border.all(
                                  color: const Color(0xFF3D84BE),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    days[i],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${dayDate.day}日',
                                    style: const TextStyle(
                                      color: Color(0xFFDDF0FF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 9,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                      Positioned(
                        top: headerHeight,
                        left: 0,
                        width: leftWidth,
                        height: gridHeight,
                        child: Column(
                          children: List.generate(totalPeriods, (i) {
                            return SizedBox(
                              height: rowHeight,
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF255D86),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      Positioned(
                        top: headerHeight,
                        left: leftWidth,
                        right: 0,
                        height: gridHeight,
                        child: CustomPaint(
                          painter: _GridPainter(
                            rowHeight: rowHeight,
                            dayWidth: dayWidth,
                            totalPeriods: totalPeriods,
                          ),
                        ),
                      ),
                      Positioned(
                        top: headerHeight,
                        left: leftWidth,
                        right: 0,
                        height: gridHeight,
                        child: Row(
                          children: List.generate(7, (dayIdx) {
                            final day = dayIdx + 1;
                            final dayRecords = _selectRecordsForDisplay(
                              recordsByDay(day),
                            );
                            return SizedBox(
                              width: dayWidth,
                              child: Stack(
                                children: dayRecords.map((record) {
                                  final isCurrentWeek = record.week.contains(
                                    selectedWeek,
                                  );
                                  final top =
                                      (record.startPeriod - 1) * rowHeight + 8;
                                  final height =
                                      (record.endPeriod -
                                              record.startPeriod +
                                              1) *
                                          rowHeight -
                                      16;
                                  final color = isCurrentWeek
                                      ? colorFor(record.courseName)
                                      : const Color(0xFFE2E7EE);
                                  final location = record.placeName.trim();
                                  final locationText = location.isEmpty
                                      ? '@待定'
                                      : '@$location';
                                  final titlePrefix = isCurrentWeek
                                      ? ''
                                      : '[非本周]\n';
                                  return Positioned(
                                    left: 1,
                                    right: 1,
                                    top: top,
                                    height: height < 34 ? 34 : height,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => onCourseTap(record, color),
                                        child: Ink(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Center(
                                            child: AutoSizeText(
                                              '$titlePrefix${record.courseName}\n$locationText',
                                              style: TextStyle(
                                                color: isCurrentWeek
                                                    ? Colors.white
                                                    : const Color(0xFF5B6470),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                height: 1.1,
                                              ),
                                              minFontSize: 7,
                                              maxLines: 12,
                                              overflow: TextOverflow.visible,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.rowHeight,
    required this.dayWidth,
    required this.totalPeriods,
  });

  final double rowHeight;
  final double dayWidth;
  final int totalPeriods;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x6689BCE3)
      ..strokeWidth = 0.6;

    for (var row = 0; row <= totalPeriods; row++) {
      final y = rowHeight * row;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (var column = 0; column <= 7; column++) {
      final x = dayWidth * column;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return rowHeight != oldDelegate.rowHeight ||
        dayWidth != oldDelegate.dayWidth ||
        totalPeriods != oldDelegate.totalPeriods;
  }
}
