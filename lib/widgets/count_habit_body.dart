import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../utils/date_key.dart';
import '../utils/habit_palette.dart';
import 'habit_card.dart';
import 'habit_value_sheet.dart';

/// Count/Measure habit card body: header with today's value and a
/// horizontally scrollable bar chart of the last days.
class CountHabitBody extends StatefulWidget {
  const CountHabitBody({super.key, required this.habit, required this.palette});

  final Habit habit;
  final HabitPalette palette;

  static const int visibleDays = 120;
  static const double barWidth = 12;
  static const double barGap = 2;
  static const double chartHeight = 60;

  /// 20% rounder than the previous 9px, still under half the bar width so the
  /// base stays square-ish when a bar is short.
  static const double barRadius = 5;

  @override
  State<CountHabitBody> createState() => _CountHabitBodyState();
}

class _CountHabitBodyState extends State<CountHabitBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatValue(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  /// Today's mark control: the shared rounded rectangle, showing a progress
  /// ring until the goal is reached and then exactly the check the yes/no
  /// card uses. Tapping it opens the value dialog without triggering Details.
  Widget _todayAction(Habit habit, HabitController controller) {
    final palette = widget.palette;
    final value = controller.valueFor(habit, todayDateKey) ?? 0;
    final goal = habit.goalValue;
    final hasGoal = goal != null && goal > 0;
    final isComplete = goal != null && goal > 0 && value >= goal;
    final progress = goal == null || goal <= 0
        ? 0.0
        : (value / goal).clamp(0.0, 1.0);

    return HabitMarkButton(
      palette: palette,
      done: isComplete,
      tooltip: isComplete ? 'Edit today' : 'Log today',
      onTap: () => HabitValueSheet.show(context, habit),
      child: isComplete
          ? HabitMarkButton.doneIcon(palette)
          : SizedBox(
              width: 34,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasGoal)
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3.5,
                        strokeCap: StrokeCap.round,
                        color: palette.bright,
                        backgroundColor: palette.muted,
                      ),
                    )
                  else
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.muted, width: 3.5),
                      ),
                    ),
                  Icon(Icons.add, size: 20, color: palette.foreground),
                ],
              ),
            ),
    );
  }

  String _todayLabel(HabitController controller) {
    final habit = widget.habit;
    final value = controller.valueFor(habit, todayDateKey);
    final unit = habit.unit;
    final suffix = unit == null || unit.isEmpty ? '' : ' $unit';
    final goal = habit.goalValue;
    if (goal != null) {
      return '${_formatValue(value ?? 0)}/${_formatValue(goal)}$suffix';
    }
    if (value == null) return unit == null ? '—' : '— $unit';
    return '${_formatValue(value)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HabitController>();
    final palette = widget.palette;
    final habit = widget.habit;
    final days = lastNDays(CountHabitBody.visibleDays);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => HabitCardHeader(
            habit: habit,
            palette: palette,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _todayLabel(controller),
                  style: TextStyle(
                    color: palette.foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                _todayAction(habit, controller),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: CountHabitBody.chartHeight + 22,
          child: Obx(() {
            final values = controller.entries[habit.id] ?? const {};
            // Scale is capped by the goal (when set) or the biggest saved
            // value, so one huge entry can never flatten the whole chart.
            var maxValue = habit.goalValue ?? 0;
            for (final day in days) {
              final v = values[dateKeyFor(day)];
              if (v != null && v > maxValue) maxValue = v;
            }
            if (maxValue <= 0) maxValue = 1;

            return ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final key = dateKeyFor(day);
                final isToday = key == todayDateKey;
                final value = values[key];
                final fraction = value == null
                    ? 0.0
                    : (value / maxValue).clamp(0.0, 1.0);
                final barHeight = value != null && value > 0
                    ? 4.0 + fraction * (CountHabitBody.chartHeight - 6)
                    : 0.0;

                return GestureDetector(
                  // Only today's bar can be logged; past bars are history.
                  onTap: isToday
                      ? () => HabitValueSheet.show(context, habit)
                      : null,
                  child: SizedBox(
                    width: CountHabitBody.barWidth + CountHabitBody.barGap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: CountHabitBody.barWidth,
                          height: CountHabitBody.chartHeight,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  width: CountHabitBody.barWidth,
                                  height: CountHabitBody.chartHeight,
                                  decoration: BoxDecoration(
                                    color: palette.muted,
                                    borderRadius: BorderRadius.circular(
                                      CountHabitBody.barRadius,
                                    ),
                                  ),
                                ),
                                if (barHeight > 0)
                                  Container(
                                    width: CountHabitBody.barWidth,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: palette.bright,
                                      borderRadius: BorderRadius.circular(
                                        CountHabitBody.barRadius,
                                      ),
                                      border: isToday
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 1.6,
                                            )
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isToday
                                ? palette.foreground
                                : palette.foregroundSoft,
                            fontSize: 11,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
