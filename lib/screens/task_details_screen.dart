import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/task_controller.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../utils/date_key.dart';
import '../utils/task_palette.dart';
import '../widgets/app_bar_shell.dart';
import '../widgets/task_action_sheets.dart';
import 'add_task_screen.dart';

/// Everything about one task, with the actions that change it.
///
/// The screen is drawn from [TaskController]'s in-memory rows, so a completion,
/// a step edit or a save from the editor repaints it without another query.
class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({super.key, required this.taskId});

  final int taskId;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final TextEditingController _stepController = TextEditingController();

  TaskController get _controller => Get.find<TaskController>();

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  Future<void> _openEditor(Task task) async {
    await Get.to(() => AddTaskScreen(initialTask: task));
  }

  /// Nothing is removed on the tap that asks for it: the sheet has to be
  /// confirmed, and a recurring task picks the scope there.
  Future<void> _confirmDelete(
    Task task, {
    required int steps,
    required int daysMarked,
  }) async {
    final choice = await TaskDeleteSheet.show(
      context,
      task: task,
      subtaskTotal: steps,
      completionCount: daysMarked,
    );
    final id = task.id;
    if (choice == null || id == null || !mounted) return;
    if (choice == TaskDeleteScope.series) {
      await _controller.deleteTask(id);
    } else {
      await _controller.endSeriesBefore(id, _controller.occurrenceKeyFor(task));
    }
    if (mounted) Get.back();
  }

  Future<void> _addStep(Task task) async {
    final title = _stepController.text.trim();
    if (title.isEmpty) return;
    await _controller.addSubtask(task, title);
    _stepController.clear();
  }

  Future<void> _renameStep(Subtask subtask) async {
    final field = TextEditingController(text: subtask.title);
    final title = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Rename step'),
          content: TextField(
            controller: field,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: 'Step title',
              hintStyle: TextStyle(color: scheme.onSurfaceVariant),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: scheme.primary),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(field.text),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
    field.dispose();
    if (title == null) return;
    await _controller.renameSubtask(subtask, title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = TaskPalette(theme.colorScheme);
    final controller = _controller;

    // One Obx over the whole scaffold, reading every observable it draws.
    return Obx(() {
      final task = controller.taskById(widget.taskId);

      if (task == null) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const AppBarBackButton(),
            title: const Text('Task'),
          ),
          body: const Center(child: Text('This task is no longer here.')),
        );
      }

      final steps = controller.subtasksFor(task);
      final stepsDone = steps.where((step) => step.done).length;
      final isComplete = controller.isComplete(task);
      final isOverdue = controller.isOverdue(task);
      final daysMarked = controller.completions
          .where((completion) => completion.taskId == task.id)
          .length;

      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBarBackButton(),
          title: const Text('Task'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppBarShell.gap),
              child: AppBarShell(
                tooltip: 'Edit task',
                onTap: () => _openEditor(task),
                child: const AppBarGlyph(Icons.edit_outlined),
              ),
            ),
            AppBarShell(
              tooltip: 'Delete task',
              onTap: () => _confirmDelete(
                task,
                steps: steps.length,
                daysMarked: daysMarked,
              ),
              child: const AppBarGlyph(Icons.delete_outline),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _headerCard(
              theme,
              palette,
              task,
              isComplete: isComplete,
              isOverdue: isOverdue,
            ),
            const SizedBox(height: 12),
            _factsCard(theme, task, daysMarked: daysMarked),
            const SizedBox(height: 12),
            _stepsCard(theme, palette, task, steps, stepsDone),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: isComplete
              ? FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => controller.toggleComplete(task),
                  icon: const Icon(Icons.replay),
                  label: const Text('Completed — tap to undo'),
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.success,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => controller.toggleComplete(task),
                  icon: const Icon(Icons.check),
                  label: Text(
                    'Mark done',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      );
    });
  }

  Widget _card(ThemeData theme, {required List<Widget> children}) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _headerCard(
    ThemeData theme,
    TaskPalette palette,
    Task task, {
    required bool isComplete,
    required bool isOverdue,
  }) {
    final scheme = theme.colorScheme;
    final status = isComplete
        ? ('Done', palette.success)
        : isOverdue
        ? ('Past due', palette.danger)
        : ('Open', scheme.onSurfaceVariant);

    return _card(
      theme,
      children: [
        _tag(theme, label: status.$1, color: status.$2, filled: isComplete),
        const SizedBox(height: 12),
        Text(
          task.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: isComplete ? scheme.onSurfaceVariant : scheme.onSurface,
            decoration: isComplete ? TextDecoration.lineThrough : null,
            decorationColor: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (task.description == null || task.description!.isEmpty)
              ? 'No notes'
              : task.description!,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _factsCard(ThemeData theme, Task task, {required int daysMarked}) {
    final scheme = theme.colorScheme;
    final rows = <(String, String)>[
      (
        'Due',
        task.dueDateKey == null
            ? 'No due date'
            : _whenLabel(task.dueDateKey!, task.dueMinutesOfDay),
      ),
      if (task.recurrence != TaskRecurrence.none)
        ('Repeats', _recurrenceLabel(task)),
      if (task.reminderLeadMinutes != null)
        ('Reminder', '${_leadLabel(task.reminderLeadMinutes!)} before'),
      if (daysMarked > 0)
        ('Days marked', '$daysMarked ${daysMarked == 1 ? 'day' : 'days'}'),
      ('Created', _stamp(task.createdAt)),
      ('Updated', _stamp(task.updatedAt)),
    ];

    return _card(
      theme,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  row.$2,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stepsCard(
    ThemeData theme,
    TaskPalette palette,
    Task task,
    List<Subtask> steps,
    int stepsDone,
  ) {
    final scheme = theme.colorScheme;
    return _card(
      theme,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'STEPS',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              steps.isEmpty ? 'None yet' : '$stepsDone/${steps.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: steps.isNotEmpty && stepsDone == steps.length
                    ? palette.success
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final step in steps) _stepRow(theme, palette, step),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _stepController,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: 'Add a step',
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            suffixIcon: IconButton(
              tooltip: 'Add step',
              onPressed: () => _addStep(task),
              icon: Icon(Icons.add, size: 20, color: scheme.primary),
            ),
          ),
          onSubmitted: (_) => _addStep(task),
        ),
      ],
    );
  }

  Widget _stepRow(ThemeData theme, TaskPalette palette, Subtask step) {
    final scheme = theme.colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _controller.toggleSubtask(step),
            child: Icon(
              step.done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: step.done ? palette.success : scheme.outline,
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _renameStep(step),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                step.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: step.done ? scheme.onSurfaceVariant : scheme.onSurface,
                  decoration: step.done ? TextDecoration.lineThrough : null,
                  decorationColor: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Remove step',
          onPressed: () => _controller.removeSubtask(step),
          icon: Icon(
            Icons.close,
            size: 17,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _tag(
    ThemeData theme, {
    required String label,
    required Color color,
    required bool filled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.9 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: filled ? Colors.black : color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _whenLabel(String dateKey, int? minutes) {
    final date = dateFromKey(dateKey);
    final day = dateKey == todayDateKey
        ? 'Today'
        : dateKey == dateKeyFor(shiftDays(today, 1))
        ? 'Tomorrow'
        : dateKey == dateKeyFor(shiftDays(today, -1))
        ? 'Yesterday'
        : DateFormat(
            date.year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy',
          ).format(date);
    if (minutes == null) return day;
    return '$day · ${_timeLabel(minutes)}';
  }

  String _timeLabel(int minutes) => DateFormat(
    'h:mm a',
  ).format(DateTime(DateTime.now().year, 1, 1, minutes ~/ 60, minutes % 60));

  /// Same wording the card's tooltip uses, so a reminder reads identically.
  String _leadLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()} h'
        : '${hours.toStringAsFixed(1)} h';
  }

  String _recurrenceLabel(Task task) => switch (task.recurrence) {
    TaskRecurrence.none => 'Does not repeat',
    TaskRecurrence.daily => 'Every day',
    TaskRecurrence.weekly => 'Every week',
    TaskRecurrence.monthly => 'Every month',
    TaskRecurrence.custom => 'Every ${task.recurrenceInterval ?? 1} days',
  };

  String _stamp(DateTime moment) =>
      DateFormat('d MMM yyyy, h:mm a').format(moment);
}
