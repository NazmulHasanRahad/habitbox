import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../utils/habit_icon.dart';
import '../utils/habit_palette.dart';
import 'count_habit_body.dart';
import 'yes_no_habit_body.dart';

/// Dark rounded card that renders one habit with its history chart.
class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final palette = HabitPalette(Color(habit.color));
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: habit.type == HabitType.yesNo
          ? YesNoHabitBody(habit: habit, palette: palette)
          : CountHabitBody(habit: habit, palette: palette),
    );
  }
}

/// Shared header control for marking today. Rounded square button that fills
/// with the habit accent color once the day is done.
class HabitMarkButton extends StatelessWidget {
  const HabitMarkButton({
    super.key,
    required this.palette,
    required this.done,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final HabitPalette palette;
  final bool done;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  /// The check every card type shows for a completed day.
  static Widget doneIcon(HabitPalette palette) =>
      Icon(Icons.check, size: 22, color: palette.foreground);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? palette.accent
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done
                  ? palette.accent
                  : Colors.white.withValues(alpha: 0.18),
              width: 1.4,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Circular progress ring used by count/measure cards: the arc tracks today's
/// fraction of the goal with a + in the middle. Once the goal is met it swaps
/// to the same filled-accent check the yes/no card shows.
class HabitProgressMarkButton extends StatelessWidget {
  const HabitProgressMarkButton({
    super.key,
    required this.palette,
    required this.fraction,
    required this.tooltip,
    required this.onTap,
  });

  final HabitPalette palette;

  /// Today's progress toward the goal, clamped to 0..1 by the caller.
  final double fraction;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = fraction >= 1;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: complete ? palette.accent : Colors.transparent,
            shape: BoxShape.circle,
            border: complete
                ? Border.all(color: palette.accent, width: 1.4)
                : null,
          ),
          child: complete
              ? HabitMarkButton.doneIcon(palette)
              : SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          strokeWidth: 3.4,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.bright,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.add,
                        size: 20,
                        color: palette.foregroundSoft,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Shared card header: accent-colored icon tile, habit name, description,
/// and a trailing widget.
class HabitCardHeader extends StatelessWidget {
  const HabitCardHeader({
    super.key,
    required this.habit,
    required this.palette,
    required this.trailing,
  });

  final Habit habit;
  final HabitPalette palette;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final description = habit.description?.trim() ?? '';

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            habitIconData(habit.iconCodePoint),
            color: palette.foreground,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontSize: 16,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foregroundSoft,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}
