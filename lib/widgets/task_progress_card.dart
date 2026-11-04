import 'package:flutter/material.dart';

import '../utils/task_palette.dart';

/// The dashboard's daily numbers: what is finished for the day being viewed,
/// what is left, and what has already slipped past its due moment.
class TaskProgressCard extends StatelessWidget {
  const TaskProgressCard({
    super.key,
    required this.dateLabel,
    required this.total,
    required this.completed,
    required this.overdue,
  });

  final String dateLabel;

  /// Tasks belonging to the selected day, whatever their status.
  final int total;
  final int completed;

  /// Open tasks past due, across every day — a count, not part of [total].
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = TaskPalette(scheme);
    final progress = total == 0 ? 0.0 : completed / total;
    final remaining = total - completed;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // The percentage stays neutral: colour on this bar is earned by
              // completing something, not by the label.
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Tooltip(
                message: '$completed of $total done on $dateLabel',
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: Duration(
                        milliseconds: disableAnimations ? 0 : 320,
                      ),
                      curve: Curves.easeOutCubic,
                      width: progress <= 0
                          ? 0
                          : (width * progress).clamp(8.0, width),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(palette.success, Colors.white, 0.18)!,
                            palette.success,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: palette.success.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                value: '$completed',
                label: 'completed',
                color: completed > 0
                    ? palette.success
                    : scheme.onSurfaceVariant,
              ),
              _divider(scheme),
              _Stat(
                value: '$remaining',
                label: 'left',
                color: scheme.onSurfaceVariant,
              ),
              _divider(scheme),
              _Stat(
                value: '$overdue',
                label: 'overdue',
                color: overdue > 0 ? palette.danger : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme scheme) => Container(
    width: 1,
    height: 22,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: scheme.outlineVariant,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
