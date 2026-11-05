
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/habit.dart';
import '../utils/date_key.dart';

/// Compact horizontal daily bar chart for the habit details screen.
/// Uses smaller bars, tighter spacing, and subtle rounded corners.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.habit,
    required this.entries,
    required this.accent,
    required this.selectedDateKey,
    required this.onSelect,
    this.windowDays = 365,
  });

  final Habit habit;
  final Map<String, double> entries;
  final Color accent;
  final String? selectedDateKey;
  final ValueChanged<DateTime> onSelect;

  /// Number of days shown by default.
  /// Older dates are included when saved entries exist.
  final int windowDays;

  // Compact chart dimensions
  static const double barWidth = 8;
  static const double barGap = 3;
  static const double chartHeight = 64;
  static const double valueLabelHeight = 12;
  static const double dayLabelHeight = 20;
  static const double barRadius = 3;
  static const double verticalGap = 2;

  static final DateFormat _monthLabel = DateFormat('MMM');

  static String _formatValue(double value) {
    return value % 1 == 0
        ? value.toInt().toString()
        : value.toString();
  }

  bool _isMarked(double? value) {
    return value != null && value > 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final miss = Color.lerp(
      scheme.error,
      Colors.white,
      0.15,
    )!;

    final hit = Color.lerp(
      accent,
      Colors.white,
      0.25,
    )!;

    // Goal progress reads as a traffic scale: behind, on track, reached.
    final onTrack = Color.lerp(
      const Color(0xFFFFC107),
      Colors.white,
      0.18,
    )!;

    final goal = habit.goalValue;
    final hasGoal = goal != null && goal > 0;

    final defaultStart = shiftDays(today, -(windowDays - 1));
    var startDate = defaultStart;

    // Extend the chart when older logged entries exist.
    for (final key in entries.keys) {
      if (!_isMarked(entries[key]) || key.compareTo(todayDateKey) > 0) {
        continue;
      }

      final date = DateTime.parse(key);

      if (date.isBefore(startDate)) {
        startDate = date;
      }
    }

    final days = <DateTime>[
      for (
      var d = startDate;
      !d.isAfter(today);
      d = shiftDays(d, 1)
      )
        d,
    ];

    // Keep the chart scale goal-aware when a goal is configured.
    var maxValue = goal ?? 0.0;

    for (final day in days) {
      final value = entries[dateKeyFor(day)];

      if (value != null && value > maxValue) {
        maxValue = value;
      }
    }

    if (maxValue <= 0) {
      maxValue = 1;
    }

    return SizedBox(
      height: valueLabelHeight +
          verticalGap +
          chartHeight +
          verticalGap +
          dayLabelHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[days.length - 1 - index];
          final key = dateKeyFor(day);

          final isToday = key == todayDateKey;
          final isSelected = key == selectedDateKey;
          final value = entries[key];
          final marked = _isMarked(value);

          final logged = value ?? 0;

          // Without a goal a day is simply logged or not; with one the bar
          // colour reports how far it is under the target.
          final Color barColor;
          if (!hasGoal) {
            barColor = marked ? hit : miss;
          } else if (logged >= goal) {
            barColor = hit;
          } else if (logged >= goal * 0.5) {
            barColor = onTrack;
          } else {
            barColor = miss;
          }

          final fraction = marked
              ? (value! / maxValue).clamp(0.0, 1.0)
              : 0.0;

          final barHeight = marked
              ? 6.0 + fraction * (chartHeight - 6.0)
              : 0.0;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(day),
            child: SizedBox(
              width: barWidth + barGap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logged value
                  SizedBox(
                    height: valueLabelHeight,
                    child: marked
                        ? Text(
                      _formatValue(value!),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.1,
                        color: barColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                        : null,
                  ),

                  const SizedBox(height: verticalGap),

                  // Daily bar
                  SizedBox(
                    width: barWidth,
                    height: chartHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Compact background track
                          Container(
                            width: barWidth,
                            height: chartHeight,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(
                                barRadius,
                              ),
                              border: isSelected
                                  ? Border.all(
                                color: Colors.white,
                                width: 1.2,
                              )
                                  : isToday
                                  ? Border.all(
                                color: Colors.white54,
                                width: 1,
                              )
                                  : null,
                            ),
                          ),

                          // Actual logged value
                          if (barHeight > 0)
                            Container(
                              width: barWidth,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(
                                  barRadius,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: verticalGap),

                  // Day number and month label
                  SizedBox(
                    height: dayLabelHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            color: isToday || isSelected
                                ? Colors.white
                                : Colors.white38,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),

                        if (day.day == 1)
                          Text(
                            _monthLabel.format(day),
                            style: const TextStyle(
                              fontSize: 9,
                              height: 1.1,
                              color: Colors.white38,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
