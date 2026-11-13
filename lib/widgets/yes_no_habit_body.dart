import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../utils/date_key.dart';
import '../utils/habit_palette.dart';
import 'habit_card.dart';

/// Yes/No habit card body: header + GitHub-style weekly heatmap that
/// scrolls horizontally while the header stays fixed.
/// Only today's cell can be marked; past dates are history-only.
class YesNoHabitBody extends StatelessWidget {
  const YesNoHabitBody({super.key, required this.habit, required this.palette});

  final Habit habit;
  final HabitPalette palette;

  /// 7 cells + 6 gaps, sized to match the count/measure chart area height
  /// so both card types render at the same total height.
  static const double cellSize = 10;
  static const double cellGap = 2.5;


  /// A full year of weeks (matches [HabitController.historyDays]) so the
  /// strip always overflows the card and stays scrollable.
  static const int weeks = 60;

  /// Today's mark control; the shared shell keeps it identical to the
  /// count/measure card's completed state.
  Widget _markButton(HabitController controller) {
    final done = controller.isDone(habit, todayDateKey);
    return HabitMarkButton(
      palette: palette,
      done: done,
      tooltip: done ? 'Unmark today' : 'Mark today',
      onTap: () => controller.toggleYesNo(habit, todayDateKey),
      child: done
          ? HabitMarkButton.doneIcon(palette)
          : Icon(
              Icons.check,
              size: 22,
              color: palette.foregroundSoft,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HabitController>();
    final gridStart = shiftDays(today, -(today.weekday % 7) - (weeks - 1) * 7);
    final columnCount = daysBetween(gridStart, today) ~/ 7 + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => HabitCardHeader(
            habit: habit,
            palette: palette,
            trailing: _markButton(controller),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: cellSize * 7 + cellGap * 6,
          child: Obx(() {
            // Snapshot observables synchronously: ListView.builder's
            // itemBuilder runs during layout, outside Obx's build scope.
            final stored =
                controller.entries[habit.id] ?? const <String, double>{};
            final doneKeys = <String>{
              for (final e in stored.entries)
                if (e.value >= 0.5) e.key,
            };
            // reverse:true anchors the newest week to the right edge, so a
            // short grid never leaves a gap on the right and no initial
            // scroll jump is needed; older weeks scroll in from the left.
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              itemCount: columnCount,
              itemBuilder: (context, index) {
                final column = columnCount - 1 - index;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (row) {
                    // Only rows above the last one carry a bottom gap, so
                    // the column height matches the heatmap SizedBox exactly.
                    final bottomGap = row < 6 ? cellGap : 0.0;
                    final date = shiftDays(gridStart, column * 7 + row);
                    if (date.isAfter(today)) {
                      return SizedBox(
                        width: cellSize,
                        height: cellSize + bottomGap,
                      );
                    }
                    final key = dateKeyFor(date);
                    final isToday = key == todayDateKey;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: cellGap,
                        bottom: bottomGap,
                      ),
                      child: GestureDetector(
                        onTap: isToday
                            ? () => controller.toggleYesNo(habit, key)
                            : null,
                        child: Container(
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            color: doneKeys.contains(key)
                                ? palette.bright
                                : palette.muted.withAlpha(10),
                            borderRadius: BorderRadius.circular(3),
                            border: isToday
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    width: .8,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
