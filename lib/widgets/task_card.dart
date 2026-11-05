import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/subtask.dart';
import '../models/task.dart';
import '../utils/date_key.dart';
import '../utils/task_palette.dart';

/// One line of the task list, drawn in the same language as the habit cards.
///
/// Colour only answers a question here: the mark box lights up when the day's
/// work is done, and the due chip turns warning when the task has slipped. The
/// card's own body carries only a faint wash of its task's hue, deep enough to
/// tell one card from the next and pale enough that a long list still reads
/// calm with the title as the loudest thing on it.
///
/// Steps live in a folded panel inside the card. The pill at the right edge
/// carries the count and opens it, and a step can be ticked right there — that
/// tap never reaches the card's own action, so opening steps or finishing one
/// never opens the details screen.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.isComplete,
    required this.isOverdue,
    required this.onToggle,
    this.subtasks = const [],
    this.onToggleSubtask,
    this.onTap,
  });

  final Task task;
  final bool isComplete;
  final bool isOverdue;
  final VoidCallback onToggle;
  final List<Subtask> subtasks;

  /// Ticks one step from the card. Null leaves the list read-only.
  final ValueChanged<Subtask>? onToggleSubtask;

  /// Opens the details screen for this task.
  final VoidCallback? onTap;

  static const double radius = 10;

  /// The mark box, plus the invisible margin that makes it comfortable to
  /// catch. The folded steps line up under the title with the same total
  /// offset, so one column of text reads down the card.
  static const double markSize = 26;
  static const double _markPad = 6;
  static const double _gap = 10;
  static const double indent = _markPad + markSize + _gap;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _stepsOpen = false;

  Task get task => widget.task;

  int get _subtasksDone => widget.subtasks.where((step) => step.done).length;

  /// The card's own tint, picked from the task rather than from a dice roll:
  /// stepping the hue by the golden angle spreads neighbouring ids across the
  /// wheel, and a task that is rebuilt, re-sorted or scrolled back into view
  /// still wears the colour it had before. A task that has never been saved has
  /// no id yet, so its title stands in for one.
  static Color _wash(Task task, bool isDark) {
    final seed = task.id ?? task.title.hashCode;
    final hue = (seed.abs() * 137.507) % 360;

    return HSLColor.fromAHSL(
      1,
      hue,
      isDark ? 0.52 : 0.72,
      isDark ? 0.30 : 0.86,
    ).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = TaskPalette(scheme);
    final instant = (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final isComplete = widget.isComplete;
    // Past due only means something about a task that is still open.
    final pastDue = widget.isOverdue && !isComplete;
    final subtaskTotal = widget.subtasks.length;
    final note = task.description?.trim() ?? '';
    // The one accent the card owns, and only the step bar wears it.
    final accent = pastDue
        ? palette.danger
        : isComplete
        ? palette.success
        : scheme.onSurfaceVariant;
    // Dark surfaces need a shadow that separates without greyening the card,
    // while light ones want the same depth carried almost invisibly.
    final isDark = scheme.brightness == Brightness.dark;
    final wash = _wash(task, isDark);

    return DecoratedBox(
      decoration: BoxDecoration(
        // A hairline, not a frame. Only a slipped task shows any colour here.
        border: Border.all(
          color: pastDue
              ? palette.danger.withValues(alpha: 0.3)
              : scheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.08),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(TaskCard.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              scheme.surfaceContainerHigh,
              wash,
              isDark ? 0.42 : 0.38,
            )!,
            Color.lerp(
              scheme.surfaceContainerHigh,
              wash,
              isDark ? 0.28 : 0.25,
            )!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.34 : 0.07),
            blurRadius: isDark ? 10 : 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TaskCard.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _MarkBox(
                      key: const ValueKey('task-mark-box'),
                      done: isComplete,
                      instant: instant,
                      onTap: widget.onToggle,
                    ),
                    const SizedBox(width: TaskCard._gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: isComplete
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                              decoration: isComplete
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: palette.danger.withValues(
                                alpha: 0.8,
                              ),
                              decorationThickness: 2.5,
                            ),
                          ),
                          // The note is the task's own words, so it reads as
                          // part of the title block rather than as chrome.
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11.5,
                                height: 1.3,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          _MetaRow(task: task, pastDue: pastDue),
                        ],
                      ),
                    ),
                    if (subtaskTotal > 0) ...[
                      const SizedBox(width: 6),
                      _FoldButton(
                        open: _stepsOpen,
                        total: subtaskTotal,
                        done: _subtasksDone,
                        instant: instant,
                        onTap: () => setState(() => _stepsOpen = !_stepsOpen),
                      ),
                    ],
                  ],
                ),
                // AnimatedSize keeps the fold smooth instead of snapping
                // the list under the card.
                AnimatedSize(
                  duration: instant,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _stepsOpen && subtaskTotal > 0
                      ? _StepPanel(
                          subtasks: widget.subtasks,
                          done: _subtasksDone,
                          accent: accent,
                          onToggle: widget.onToggleSubtask,
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's mark control: a quiet rounded box while the task is open, that
/// fills and takes the success colour only once the day's work is actually
/// done. An open box carries no glyph, so the card never shows a ring inside a
/// ring.
class _MarkBox extends StatelessWidget {
  const _MarkBox({
    super.key,
    required this.done,
    required this.instant,
    required this.onTap,
  });

  final bool done;
  final Duration instant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = TaskPalette(scheme);

    return Tooltip(
      message: done ? 'Mark as not done' : 'Mark as done',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The box stays small and quiet; the margin keeps it easy to tap.
        child: Padding(
          padding: const EdgeInsets.all(TaskCard._markPad),
          child: AnimatedContainer(
            duration: instant,
            curve: Curves.easeOutCubic,
            width: TaskCard.markSize,
            height: TaskCard.markSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done
                  ? palette.success.withValues(alpha: 0.18)
                  : scheme.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: done
                    ? palette.success.withValues(alpha: 0.6)
                    : scheme.outline.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: AnimatedSwitcher(
              duration: instant,
              child: done
                  ? Icon(
                      Icons.check_rounded,
                      key: const ValueKey('checked'),
                      size: 16,
                      color: palette.success,
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ),
        ),
      ),
    );
  }
}

/// The steps handle: a small pill at the card's right edge that holds the count
/// and the arrow together, so the folded card still answers the one question
/// the panel would. It takes colour when the panel is open or every step is
/// finished, and stays neutral otherwise.
class _FoldButton extends StatelessWidget {
  const _FoldButton({
    required this.open,
    required this.total,
    required this.done,
    required this.instant,
    required this.onTap,
  });

  final bool open;
  final int total;
  final int done;
  final Duration instant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = TaskPalette(scheme);
    final allDone = done == total;
    final Color tint = open
        ? scheme.onSurface
        : allDone
        ? palette.success
        : scheme.onSurfaceVariant;

    return Tooltip(
      message: open ? 'Hide steps' : 'Show $total steps',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The pill has to take the tap for itself, otherwise opening the
        // steps would also open the details screen.
        onTap: onTap,
        child: AnimatedContainer(
          duration: instant,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: open
                ? tint.withValues(alpha: 0.12)
                : scheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: open
                  ? tint.withValues(alpha: 0.35)
                  : scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$done/$total',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  height: 1.2,
                  letterSpacing: 0.2,
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: instant,
                curve: Curves.easeOutCubic,
                child: Icon(Icons.expand_more, size: 17, color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The folded step list: its own score line, a bar that fills as steps close,
/// and rows that tick on tap.
class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.subtasks,
    required this.done,
    required this.accent,
    required this.onToggle,
  });

  final List<Subtask> subtasks;
  final int done;
  final Color accent;
  final ValueChanged<Subtask>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = TaskPalette(scheme);
    final total = subtasks.length;
    final allDone = done == total;

    return Padding(
      // Lines up under the title.
      padding: const EdgeInsets.only(top: 6, left: TaskCard.indent, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: scheme.onSurface.withValues(alpha: 0.07)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'STEPS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation(
                        allDone
                            ? palette.success
                            : accent.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final step in subtasks) _StepRow(step: step, onToggle: onToggle),
        ],
      ),
    );
  }
}

/// A step is the mark box's smaller twin: a light dot that turns into a check
/// when the step is done, so one gesture reads the same all over the card.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.onToggle});

  final Subtask step;
  final ValueChanged<Subtask>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = TaskPalette(scheme);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      // The innermost ink well wins the tap, so ticking a step never opens the
      // details screen.
      onTap: onToggle == null ? null : () => onToggle!(step),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          children: [
            Icon(
              step.done ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: step.done
                  ? palette.success
                  : scheme.outline.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                step.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.25,
                  color: step.done
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface.withValues(alpha: 0.9),
                  decoration: step.done ? TextDecoration.lineThrough : null,
                  decorationColor: palette.danger.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's small facts, each with a tooltip where the glyph alone is not
/// enough. The step count is not here: it rides on the fold handle instead, so a
/// card never says the same thing twice.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.task, required this.pastDue});

  final Task task;
  final bool pastDue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = TaskPalette(scheme);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 3,
      children: [
        if (task.dueDateKey != null)
          _MetaChip(
            icon: pastDue ? Icons.error_outline : Icons.schedule,
            text: _dueLabel(task.dueDateKey!, task.dueMinutesOfDay),
            color: pastDue ? palette.danger : scheme.onSurfaceVariant,
            bold: pastDue,
            tooltip: pastDue ? 'Past due' : null,
            fill: pastDue
                ? palette.danger.withValues(alpha: 0.1)
                : scheme.onSurface.withValues(alpha: 0.05),
          ),
        if (task.reminderLeadMinutes != null)
          Tooltip(
            message: 'Reminder ${_leadLabel(task.reminderLeadMinutes!)} before',
            child: Icon(
              Icons.notifications_none,
              size: 14,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
      ],
    );
  }

  String _dueLabel(String dateKey, int? minutes) {
    final date = dateFromKey(dateKey);
    final day = dateKey == todayDateKey
        ? 'Today'
        : dateKey == dateKeyFor(shiftDays(today, 1))
        ? 'Tomorrow'
        : DateFormat(
            date.year == DateTime.now().year ? 'd MMM' : 'd MMM yyyy',
          ).format(date);
    if (minutes == null) return day;
    final hour = minutes ~/ 60;
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$day · $hour:$minute';
  }

  String _leadLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()} h'
        : '${hours.toStringAsFixed(1)} h';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.text,
    required this.color,
    required this.fill,
    this.icon,
    this.bold = false,
    this.tooltip,
  });

  final String text;
  final Color color;
  final Color fill;
  final IconData? icon;
  final bool bold;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10.5,
      height: 1.2,
      letterSpacing: 0.2,
      color: color,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(text, style: style),
        ],
      ),
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}
