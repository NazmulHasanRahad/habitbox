import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../utils/habit_icon.dart';
import '../utils/habit_palette.dart';
import 'count_habit_body.dart';
import 'yes_no_habit_body.dart';

/// Rounded colored card that renders one habit with its history chart.
class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final palette = HabitPalette(Color(habit.color));
    return Container(
      decoration: BoxDecoration(
        color: palette.card.withOpacity(.9),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: habit.type == HabitType.yesNo
          ? YesNoHabitBody(habit: habit, palette: palette)
          : CountHabitBody(habit: habit, palette: palette),
    );
  }
}

/// Shared header control for marking today. Both card types use the same
/// 50x44 rounded rectangle and light up identically once the day is done.
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
      Icon(Icons.check, size: 20, color: palette.bright);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 44,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? palette.bright.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: done
                  ? palette.bright.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.22),
              width: 1.4,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shared card header: icon tile, habit name, and a trailing widget.
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            habitIconData(habit.iconCodePoint),
            color: palette.foreground,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
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
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foregroundSoft,
                    fontSize: 11.5,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 5),
        trailing,
      ],
    );
  }
}
