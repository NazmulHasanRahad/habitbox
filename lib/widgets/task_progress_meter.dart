import 'package:flutter/material.dart';

import '../controllers/task_controller.dart';
import '../utils/task_palette.dart';

/// The slim bar in a day's heading line: one segment per task of that day,
/// coloured by how that task is going.
///
/// It carries no text at all — the heading names the day and prints the day's
/// 'done of total' beside it — so the bar is free to be nothing but a shape,
/// and to stretch across whatever width the name leaves. Done
/// tasks wear the success tone, past due ones the danger tone, and open ones a
/// faint neutral.
class TaskProgressMeter extends StatelessWidget {
  const TaskProgressMeter({super.key, required this.slices});

  final List<TaskDaySlice> slices;

  static const double _height = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = TaskPalette(scheme);

    // Empty days still draw the bar: a strip that only appears when there is
    // work reads as a glitch rather than as a plan.
    if (slices.isEmpty) {
      return Container(
        height: _height,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(_height / 2),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(_height / 2),
      child: SizedBox(
        height: _height,
        child: Row(
          children: [
            for (final (i, slice) in slices.indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 1.5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: slice.done
                          ? palette.success
                          : slice.pastDue
                          ? palette.danger.withValues(alpha: 0.7)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
