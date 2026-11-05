
import 'package:flutter/material.dart';

import '../utils/date_key.dart';

/// Premium Monday-start monthly calendar.
/// Existing date logic and callbacks are preserved.
///
/// Two readings of a day are supported:
///  * the default one — a dot under the day number, for a yes/no habit;
///  * the measured one — passing [entries] prints the logged value against
///    [goalValue] inside the cell, so a count/measure day shows both how much
///    was done and what the target was.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.displayMonth,
    required this.markedKeys,
    required this.selectedDateKey,
    required this.accent,
    required this.onDayTap,
    this.entries,
    this.goalValue,
  });

  /// Any DateTime inside the month being displayed.
  final DateTime displayMonth;
  final Set<String> markedKeys;
  final String selectedDateKey;
  final Color accent;
  final ValueChanged<DateTime> onDayTap;

  /// Logged value per `yyyy-MM-dd` key. Null keeps the dot-style cells.
  final Map<String, double>? entries;

  /// The habit's daily target, printed after the value when present.
  final double? goalValue;

  static const List<String> _weekdayLabels = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  /// Measured cells need room for a second line under the day number.
  bool get _showsValues => entries != null;

  double get _cellHeight => _showsValues ? 56 : 48;

  static String _shortNumber(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

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
        height: _cellHeight,
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

            if (_showsValues) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 11,
                child: _valueLabel(key, isActive),
              ),
            ] else ...[
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
          ],
        ),
      ),
    );
  }

  /// `value/target` for a measured day, e.g. `8/10`. A day that reached the
  /// target wears the full accent; a partial one is dimmed. Days in the
  /// neighbouring months or in the future stay blank.
  Widget _valueLabel(String key, bool isActive) {
    if (!isActive) return const SizedBox.shrink();
    final value = entries?[key];
    if (value == null || value <= 0) return const SizedBox.shrink();

    final goal = goalValue;
    final hasGoal = goal != null && goal > 0;
    final reached = hasGoal && value >= goal;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: _shortNumber(value),
              style: TextStyle(
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w700,
                color: reached
                    ? accent
                    : accent.withValues(alpha: 0.72),
              ),
            ),
            if (hasGoal)
              TextSpan(
                text: '/${_shortNumber(goal)}',
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: reached
                      ? Colors.white70
                      : Colors.white38,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
