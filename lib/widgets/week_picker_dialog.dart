import 'package:flutter/material.dart';

class WeekPickerDialog extends StatelessWidget {
  const WeekPickerDialog({
    super.key,
    required this.weeks,
    required this.selectedWeek,
    required this.onWeekSelected,
  });

  final List<int> weeks;
  final int selectedWeek;
  final ValueChanged<int> onWeekSelected;

  static Future<void> show(
    BuildContext context, {
    required int maxWeek,
    required int selectedWeek,
    required ValueChanged<int> onWeekSelected,
  }) {
    final end = maxWeek < 20 ? maxWeek : 20;
    final weeks = List.generate(end, (i) => i + 1);

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => WeekPickerDialog(
        weeks: weeks,
        selectedWeek: selectedWeek,
        onWeekSelected: onWeekSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF4F6FA),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
              final isSelected = week == selectedWeek;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    onWeekSelected(week);
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
  }
}
