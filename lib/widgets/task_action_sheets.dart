import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../controllers/task_controller.dart';
import '../models/task.dart';
import '../utils/date_key.dart';

/// Which part of a series a deletion applies to. One occurrence on its own
/// cannot be removed: the schema stores per-day *values*, not per-day rows, so
/// there is nothing to delete for a single day.
enum TaskDeleteScope {
  futureOccurrences(
    'This and future occurrences',
    'Days up to today keep their steps, their marks and their history.',
  ),
  series(
    'Entire series',
    'Every day of the series disappears, including the ones already done.',
  );

  const TaskDeleteScope(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// The two confirmations the task editor and details screen need: which scope an
/// edit saves to, and whether a delete removes the future or the whole series.
///
/// Both are bottom sheets shaped like the habit value sheet — handle, title,
/// option tiles, then the actions — so a destructive choice always has to be
/// read before it can be made.
class TaskScopeSheet {
  /// Prompts for the scope of an edit to [task]. Returns null when the user
  /// backs out, in which case nothing has been written.
  static Future<TaskEditScope?> show(
    BuildContext context, {
    required Task task,
    required List<TaskEditScope> scopes,
    required bool stepsChanged,
  }) {
    return showModalBottomSheet<TaskEditScope>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ScopeSheetBody(
        task: task,
        scopes: scopes,
        stepsChanged: stepsChanged,
      ),
    );
  }
}

class _ScopeSheetBody extends StatelessWidget {
  const _ScopeSheetBody({
    required this.task,
    required this.scopes,
    required this.stepsChanged,
  });

  final Task task;
  final List<TaskEditScope> scopes;
  final bool stepsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Steps live on the series row itself, so only the series scope can carry a
    // step change; offering a narrower one would silently drop it.
    bool carriesSteps(TaskEditScope scope) =>
        !stepsChanged || scope == TaskEditScope.series;
    final dayLabel = _occurrenceLabel(task);

    return _SheetScaffold(
      title: 'Apply this change to',
      subtitle: task.title,
      content: [
        for (final scope in scopes)
          _OptionTile(
            label: scope.label,
            // The day the editor is open on, spelled out rather than implied.
            explanation: scope == TaskEditScope.occurrence
                ? 'Only $dayLabel. The rest of the series keeps its current '
                      'values.'
                : scope.explanation,
            enabled: carriesSteps(scope),
            onTap: () => Navigator.of(context).pop(scope),
          ),
        if (stepsChanged)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'You changed the steps, so only the whole series can be updated.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
      actions: [_Cancel(onPressed: () => Navigator.of(context).pop())],
    );
  }
}

class TaskDeleteSheet {
  /// Confirms deleting [task]. Returns null unless the user taps the destructive
  /// action, so a stray tap can never remove anything.
  static Future<TaskDeleteScope?> show(
    BuildContext context, {
    required Task task,
    required int subtaskTotal,
    required int completionCount,
  }) {
    return showModalBottomSheet<TaskDeleteScope>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DeleteSheetBody(
        task: task,
        subtaskTotal: subtaskTotal,
        completionCount: completionCount,
      ),
    );
  }
}

class _DeleteSheetBody extends StatefulWidget {
  const _DeleteSheetBody({
    required this.task,
    required this.subtaskTotal,
    required this.completionCount,
  });

  final Task task;
  final int subtaskTotal;
  final int completionCount;

  @override
  State<_DeleteSheetBody> createState() => _DeleteSheetBodyState();
}

class _DeleteSheetBodyState extends State<_DeleteSheetBody> {
  // The gentler scope starts selected: the series option is one tap away but
  // should never be the default for a destructive action.
  TaskDeleteScope _choice = TaskDeleteScope.futureOccurrences;

  bool get _isRecurring => widget.task.recurrence != TaskRecurrence.none;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dayLabel = _occurrenceLabel(widget.task);

    return _SheetScaffold(
      title: _isRecurring ? 'Delete this recurring task?' : 'Delete this task?',
      subtitle: widget.task.title,
      content: [
        Text(
          _warning(dayLabel),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 12),
          for (final scope in TaskDeleteScope.values)
            _OptionTile(
              label: scope.label,
              explanation: scope == TaskDeleteScope.futureOccurrences
                  ? 'Stops the series from $dayLabel onwards.'
                  : scope.explanation,
              selected: scope == _choice,
              onTap: () => setState(() => _choice = scope),
            ),
        ],
      ],
      actions: [
        _Cancel(onPressed: () => Navigator.of(context).pop()),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: () {
                HapticFeedback.vibrate();
                // A plain task has no scopes to choose, but it still pops the
                // one it means, so a null result always means 'cancelled'.
                Navigator.of(
                  context,
                ).pop(_isRecurring ? _choice : TaskDeleteScope.series);
              },
              child: const Text(
                'Delete task',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Says out loud what the chosen scope really takes away, including how much
  /// of the task's history is involved.
  String _warning(String dayLabel) {
    final days = widget.completionCount;
    final steps = widget.subtaskTotal;
    final carries = days == 0 && steps == 0
        ? 'Nothing is recorded on it yet.'
        : [
            if (days > 0) '$days marked ${days == 1 ? 'day' : 'days'}',
            if (steps > 0) '$steps ${steps == 1 ? 'step' : 'steps'}',
          ].join(' and ');
    final carried = days == 0 && steps == 0 ? '' : 'It carries $carries.';

    if (!_isRecurring) {
      return '${widget.task.title} moves to the trash rather than being '
          'erased. $carried The rows stay in the database, so the task can be '
          'restored.';
    }
    return _choice == TaskDeleteScope.futureOccurrences
        ? 'Days before $dayLabel keep their steps and their marks. From '
              '$dayLabel the series stops. $carried Nothing is erased.'
        : 'Every day of this series goes to the trash, including the days '
              'already done. $carried The rows stay in the database, so the '
              'whole series can be restored.';
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // Lift above the keyboard-free safe area the same way the value sheet does.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...content,
            const SizedBox(height: 16),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.explanation,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  final String label;
  final String explanation;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
        : selected
        ? scheme.primary
        : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: enabled
            ? (selected
                  ? scheme.primary.withValues(alpha: 0.10)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.55)
                    : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 19,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        explanation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cancel extends StatelessWidget {
  const _Cancel({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.onSurface,
            side: BorderSide(color: scheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          onPressed: onPressed,
          child: const Text('Cancel', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

/// 'Fri 6 Nov' for the occurrence the editor is working on.
String _occurrenceLabel(Task task) => DateFormat(
  'EEE d MMM',
).format(dateFromKey(task.dueDateKey ?? dateKeyFor(task.createdAt)));
