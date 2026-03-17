import 'package:flutter/material.dart';

import '../../../../models/course_record.dart';

class OnlineCoursesSheet extends StatelessWidget {
  const OnlineCoursesSheet({
    super.key,
    required this.records,
    required this.days,
    required this.formatWeekRanges,
    required this.colorFor,
  });

  final List<CourseRecord> records;
  final List<String> days;
  final String Function(List<int> weeks) formatWeekRanges;
  final Color Function(String key) colorFor;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '线上课程',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '共 ${records.length} 门',
                style: const TextStyle(color: Color(0xFF5F6B7A)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final color = colorFor(
                      '${record.courseName}-${record.teacher}-${record.placeName}',
                    );
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.18),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.courseName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${formatWeekRanges(record.week)}  ${days[record.dayOfWeek - 1]} ${record.periods}',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (record.teacher.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('教师：${record.teacher}'),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '地点：${record.placeName.isEmpty ? '线上' : record.placeName}',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
