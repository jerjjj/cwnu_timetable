import 'package:flutter/material.dart';

import '../models/course_record.dart';

class CourseDetailDialog extends StatelessWidget {
  const CourseDetailDialog({
    super.key,
    required this.record,
    required this.color,
    required this.teacherText,
    required this.placeText,
    required this.timeText,
    required this.weeksText,
  });

  final CourseRecord record;
  final Color color;
  final String teacherText;
  final String placeText;
  final String timeText;
  final String weeksText;

  static Future<void> show(
    BuildContext context, {
    required CourseRecord record,
    required Color color,
    required String teacherText,
    required String placeText,
    required String timeText,
    required String weeksText,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => CourseDetailDialog(
        record: record,
        color: color,
        teacherText: teacherText,
        placeText: placeText,
        timeText: timeText,
        weeksText: weeksText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
              record.courseName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _InfoText(teacherText),
            const SizedBox(height: 6),
            _InfoText(placeText),
            const SizedBox(height: 6),
            _InfoText(timeText),
            const SizedBox(height: 6),
            _InfoText(weeksText),
          ],
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
