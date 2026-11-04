import 'package:flutter/material.dart';

import '../utils/date_key.dart';

/// Monday-start monthly grid with adjacent-month days, marked-date
/// highlighting, today border and a distinct selected day.
/// Future days are shown but cannot be selected.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.displayMonth,
    required this.markedKeys,
    required this.selectedDateKey,
    required this.accent,
    required this.onDayTap,
  });

  /// Any DateTime inside the month being displayed.
  final DateTime displayMonth;
  final Set<String> markedKeys;
  final String selectedDateKey;
  final Color accent;
  final ValueChanged<DateTime> onDayTap;

  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(displayMonth.year, displayMonth.month);
    // Day 0 of the next month rolls back to the last day of this month.
    final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-start offset
    final weekCount =
        (leading + daysInMonth) ~/ 7 +
        ((leading + daysInMonth) % 7 == 0 ? 0 : 1);

    return Column(
      children: [
        Row(
          children: _weekdayLabels.map((label) {
            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        ...List.generate(weekCount, (week) {
          return Row(
            children: List.generate(7, (slot) {
              final date = DateTime(
                first.year,
                first.month,
                week * 7 + slot - leading + 1,
              );
              return Expanded(child: _dayCell(date, first));
            }),
          );
        }),
      ],
    );
  }

  Widget _dayCell(DateTime date, DateTime first) {
    final key = dateKeyFor(date);
    final inMonth = date.month == first.month && date.year == first.year;
    final isFuture = key.compareTo(todayDateKey) > 0;
    final isToday = key == todayDateKey;
    final isSelected = key == selectedDateKey;
    final isMarked = markedKeys.contains(key);

    final Color textColor;
    if (!inMonth || isFuture) {
      textColor = Colors.white24;
    } else if (isMarked || isSelected || isToday) {
      textColor = accent;
    } else {
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: isFuture ? null : () => onDayTap(date),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected || (isMarked && inMonth)
              ? accent.withValues(alpha: 0.18)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: isToday || isSelected
              ? Border.all(
                  color: isSelected ? accent : Colors.white38,
                  width: 1.4,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            SizedBox(
              height: 8,
              child: isMarked && inMonth && !isFuture
                  ? Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
