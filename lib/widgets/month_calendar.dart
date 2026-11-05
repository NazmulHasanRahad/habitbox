
import 'package:flutter/material.dart';

import '../utils/date_key.dart';

/// Premium Monday-start monthly calendar.
/// Existing date logic and callbacks are preserved.
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
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(displayMonth.year, displayMonth.month);
    final daysInMonth =
        DateTime(displayMonth.year, displayMonth.month + 1, 0).day;

    final leading = first.weekday - 1;

    final weekCount = (leading + daysInMonth) ~/ 7 +
        ((leading + daysInMonth) % 7 == 0 ? 0 : 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Weekday header
        Row(
          children: _weekdayLabels.map((label) {
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Colors.white38,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // Monthly date grid
        ...List.generate(weekCount, (week) {
          return Row(
            children: List.generate(7, (slot) {
              final date = DateTime(
                first.year,
                first.month,
                week * 7 + slot - leading + 1,
              );

              return Expanded(
                child: _dayCell(date, first),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _dayCell(DateTime date, DateTime first) {
    final key = dateKeyFor(date);

    final inMonth =
        date.month == first.month && date.year == first.year;

    final isFuture = key.compareTo(todayDateKey) > 0;
    final isToday = key == todayDateKey;
    final isSelected = key == selectedDateKey;
    final isMarked = markedKeys.contains(key);

    final isActive = inMonth && !isFuture;

    final Color textColor;

    if (!inMonth || isFuture) {
      textColor = Colors.white.withValues(alpha: 0.16);
    } else if (isSelected) {
      textColor = accent;
    } else if (isToday) {
      textColor = Colors.white;
    } else {
      textColor = Colors.white.withValues(alpha: 0.88);
    }

    final Color? backgroundColor = isSelected
        ? accent.withValues(alpha: 0.17)
        : isMarked && inMonth && !isFuture
        ? accent.withValues(alpha: 0.09)
        : null;

    final Border? border = isSelected
        ? Border.all(
      color: accent.withValues(alpha: 0.85),
      width: 1.2,
    )
        : isToday
        ? Border.all(
      color: Colors.white.withValues(alpha: 0.48),
      width: 1.1,
    )
        : null;

    return GestureDetector(
      onTap: isFuture ? null : () => onDayTap(date),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),

            const SizedBox(height: 4),

            // Marked date indicator
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isMarked && isActive
                    ? accent
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
