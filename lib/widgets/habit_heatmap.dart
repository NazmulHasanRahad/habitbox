import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/habit.dart';
import '../utils/date_key.dart';

/// GitHub-style contribution heatmap for the details screen.
/// Newest week is anchored to the right; tapping a cell selects its date.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.entries,
    required this.accent,
    required this.selectedDateKey,
    required this.onSelect,
  });

  final Habit habit;
  final Map<String, double> entries;
  final Color accent;
  final String? selectedDateKey;
  final ValueChanged<DateTime> onSelect;

  static const double cellSize = 10;
  static const double cellGap = 2;
  static const int weeks = 52;

  static final DateFormat _monthLabel = DateFormat('MMM');

  /// Rows always start on Monday so the heatmap and the month calendar below
  /// it agree on which weekday a cell belongs to.
  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  Color _cellColor(String key) {
    final muted = accent.withValues(alpha: 0.16);
    final value = entries[key];
    if (value == null || value <= 0) return muted;
    if (habit.type == HabitType.yesNo) return accent;
    final goal = habit.goalValue;
    final fraction = goal == null || goal <= 0
        ? 1.0
        : (value / goal).clamp(0.0, 1.0);
    return Color.lerp(muted, accent, 0.35 + 0.65 * fraction)!;
  }

  @override
  Widget build(BuildContext context) {
    // Monday of the current week, then back by (weeks - 1) weeks.
    final gridStart = shiftDays(today, -(today.weekday - 1) - (weeks - 1) * 7);
    final columnCount = daysBetween(gridStart, today) ~/ 7 + 1;
    final columnWidth = cellSize + cellGap;

    // reverse:true anchors the newest week to the right edge. The weekday
    // label column sits outside the scroller so it never scrolls away.
    return SizedBox(
      height: 16 + cellSize * 7 + cellGap * 6,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            height: 16 + cellSize * 7 + cellGap * 6,
            child: Padding(
              // Same 16px month-label band as the columns, so every label sits
              // exactly on its own row of cells.
              padding: const EdgeInsets.only(right: 6, top: 16),
              child: Column(
                children: List.generate(7, (row) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: row < 6 ? cellGap : 0),
                    child: SizedBox(
                      height: cellSize,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _weekdayLabels[row],
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              itemCount: columnCount,
              itemBuilder: (context, index) {
                final column = columnCount - 1 - index;
                final firstDayOfWeek = shiftDays(gridStart, column * 7);
                // Show the month name above the week that starts a new month.
                final showLabel =
                    column == 0 ||
                    firstDayOfWeek.month !=
                        shiftDays(gridStart, (column - 1) * 7).month;
                return SizedBox(
                  width: columnWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 16,
                        child: showLabel
                            // A week column is only 16px wide, so the 3-letter
                            // month name has to spill into the neighbouring
                            // gap instead of wrapping to "Ja"/"Fe".
                            ? OverflowBox(
                                alignment: column == columnCount - 1
                                    ? Alignment.topRight
                                    : Alignment.topLeft,
                                minWidth: 0,
                                maxWidth: double.infinity,
                                child: Text(
                                  _monthLabel.format(firstDayOfWeek),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    height: 1,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      ...List.generate(7, (row) {
                        final bottomGap = row < 6 ? cellGap : 0.0;
                        final date = shiftDays(gridStart, column * 7 + row);
                        if (date.isAfter(today)) {
                          return SizedBox(
                            width: cellSize,
                            height: cellSize + bottomGap,
                          );
                        }
                        final key = dateKeyFor(date);
                        final isSelected = key == selectedDateKey;
                        final isToday = key == todayDateKey;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: cellGap,
                            bottom: bottomGap,
                          ),
                          child: GestureDetector(
                            onTap: () => onSelect(date),
                            child: Container(
                              width: cellSize,
                              height: cellSize,
                              decoration: BoxDecoration(
                                color: _cellColor(key),
                                borderRadius: BorderRadius.circular(3),
                                border: isToday || isSelected
                                    ? Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        width: 1.4,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
