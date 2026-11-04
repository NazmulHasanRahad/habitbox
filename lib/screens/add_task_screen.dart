import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/task_controller.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../utils/date_key.dart';
import '../utils/task_palette.dart';
import '../widgets/app_bar_shell.dart';
import '../widgets/task_action_sheets.dart';

/// Full-screen task form opened from the dashboard's add action and the details
/// screen's edit action. Pass [initialTask] to reuse it for editing.
///
/// Sections: Title -> When (due date, time) -> Steps. Everything is saved
/// through [TaskController], which decides what the edit means for a recurring
/// series.
class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key, this.initialTask});

  final Task? initialTask;

  bool get isEditing => initialTask != null;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stepController = TextEditingController();

  /// One row of the step list. [existing] carries the stored subtask through
  /// the form so a rename never resets its done state or its position.
  final List<_StepRow> _steps = <_StepRow>[];

  String? _dueDateKey;
  int? _dueMinutesOfDay;

  /// Extra days the same task is created on, oldest first. Only a new task can
  /// span days: editing one row is an edit of that row's own day.
  final List<String> _extraDateKeys = <String>[];

  String? _titleError;
  String? _saveError;
  bool _saving = false;

  Task? get _initial => widget.initialTask;

  TaskController get _controller => Get.find<TaskController>();

  bool get _hasDueDate => _dueDateKey != null;

  /// The due date tile's one line: the day, any extra days, and the time on it.
  String get _dueSummary {
    final day = _dueDateKey;
    if (day == null) return 'No due date';
    final label = _extraDateKeys.isEmpty
        ? _dayLabel(day)
        : '${_dayLabel(day)} +${_extraDateKeys.length} more';
    final minutes = _dueMinutesOfDay;
    return minutes == null ? label : '$label · ${_timeLabel(minutes)}';
  }

  @override
  void initState() {
    super.initState();
    // The add-step button lights up with what is typed in the field.
    _stepController.addListener(_onStepInput);
    final initial = _initial;
    if (initial == null) {
      // A new task defaults to the day the dashboard is looking at, so adding
      // one from 'Tomorrow' does not silently schedule it for today.
      _dueDateKey = _controller.selectedDateKey.value;
      return;
    }
    _titleController.text = initial.title;
    _descriptionController.text = initial.description ?? '';
    _dueDateKey = initial.dueDateKey;
    _dueMinutesOfDay = initial.dueMinutesOfDay;
    for (final subtask in _controller.subtasksFor(initial)) {
      _steps.add(
        _StepRow(
          existing: subtask,
          controller: TextEditingController(text: subtask.title),
        ),
      );
    }
  }

  @override
  void dispose() {
    _stepController.removeListener(_onStepInput);
    _titleController.dispose();
    _descriptionController.dispose();
    _stepController.dispose();
    for (final row in _steps) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _onStepInput() => setState(() {});

  /// Whether the form's step list differs from the stored one — the scopes that
  /// cannot carry a step change are disabled on that basis.
  bool get _stepsChanged {
    final stored = _controller.subtasksFor(_initial!);
    if (stored.length != _steps.length) return true;
    for (var i = 0; i < _steps.length; i++) {
      final row = _steps[i];
      final existing = row.existing;
      if (existing == null || existing.id != stored[i].id) return true;
      if (existing.title != row.controller.text.trim()) return true;
    }
    return false;
  }

  void _addStep() {
    final title = _stepController.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.vibrate();
    setState(() {
      _steps.add(_StepRow(controller: TextEditingController(text: title)));
      _stepController.clear();
    });
  }

  void _removeStep(int index) {
    setState(() => _steps.removeAt(index).controller.dispose());
  }

  /// Moves a step one place. The order the form leaves them in is the order the
  /// repository stores, so a move here is the reorder.
  void _moveStep(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _steps.length) return;
    HapticFeedback.vibrate();
    setState(() {
      final row = _steps.removeAt(index);
      _steps.insert(target, row);
    });
  }

  /// Every day the form writes: the due date plus the extra ones, oldest first.
  List<String> get _dateKeys =>
      [if (_dueDateKey != null) _dueDateKey!, ..._extraDateKeys]..sort();

  Future<void> _addDate() async {
    final primary = _dueDateKey;
    // Extra days hang off the main due date; without one there is nothing to
    // add a second day to.
    if (primary == null) return;
    final last = _extraDateKeys.isEmpty ? primary : _extraDateKeys.last;
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromKey(last),
      firstDate: shiftDays(today, -366),
      lastDate: shiftDays(today, 366 * 5),
      helpText: 'Another date',
    );
    if (picked == null || !mounted) return;
    final dateKey = dateKeyFor(picked);
    if (dateKey == primary || _extraDateKeys.contains(dateKey)) return;
    HapticFeedback.vibrate();
    setState(() => _extraDateKeys.add(dateKey));
    _extraDateKeys.sort();
  }

  void _removeDate(String dateKey) {
    setState(() => _extraDateKeys.remove(dateKey));
  }

  /// One flow, two pickers: the day first, then the moment on it. Backing out
  /// of the time sheet still keeps the day that was just picked.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromKey(_dueDateKey ?? todayDateKey),
      firstDate: shiftDays(today, -366),
      lastDate: shiftDays(today, 366 * 5),
      helpText: 'Due date',
    );
    if (picked == null || !mounted) return;
    final dateKey = dateKeyFor(picked);
    setState(() {
      _dueDateKey = dateKey;
      // The main day cannot also be one of the extra ones.
      _extraDateKeys.remove(dateKey);
    });
    await _pickTime();
  }

  Future<void> _pickTime() async {
    final base = _dueMinutesOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: base == null
          ? TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: base ~/ 60, minute: base % 60),
      helpText: 'Due time',
    );
    if (picked == null || !mounted) return;
    setState(() => _dueMinutesOfDay = picked.hour * 60 + picked.minute);
  }

  /// Built field by field rather than with copyWith, so the series fields the
  /// form does not show (recurrence, archive state, the parent chain) are
  /// passed through untouched instead of being re-invented.
  Task _draft(String title) {
    final description = _descriptionController.text.trim();
    final initial = _initial;
    final now = DateTime.now();
    if (initial == null) {
      return Task(
        title: title,
        description: description.isEmpty ? null : description,
        dueDateKey: _dueDateKey,
        dueMinutesOfDay: _hasDueDate ? _dueMinutesOfDay : null,
        createdAt: now,
        updatedAt: now,
      );
    }
    return Task(
      id: initial.id,
      title: title,
      description: description.isEmpty ? null : description,
      dueDateKey: _dueDateKey,
      dueMinutesOfDay: _hasDueDate ? _dueMinutesOfDay : null,
      recurrence: initial.recurrence,
      recurrenceInterval: initial.recurrenceInterval,
      recurrenceStartKey: initial.recurrenceStartKey,
      recurrenceUntilKey: initial.recurrenceUntilKey,
      parentTaskId: initial.parentTaskId,
      reminderLeadMinutes: initial.reminderLeadMinutes,
      createdAt: initial.createdAt,
      updatedAt: initial.updatedAt,
      archived: initial.archived,
      deletedAt: initial.deletedAt,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter a title.');
      return;
    }

    final initial = _initial;
    var scope = TaskEditScope.series;
    var occurrenceKey = initial == null
        ? null
        : _controller.occurrenceKeyFor(initial);
    if (initial != null && initial.recurrence != TaskRecurrence.none) {
      final picked = await TaskScopeSheet.show(
        context,
        task: initial,
        scopes: TaskEditScope.values,
        stepsChanged: _stepsChanged,
      );
      // Backing out of the sheet means nothing was written.
      if (picked == null) return;
      scope = picked;
    }

    final draft = _draft(title);
    final subtasks = [
      for (final row in _steps)
        SubtaskDraft(existing: row.existing, title: row.controller.text.trim()),
    ];

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final days = _dateKeys;
      if (initial == null && days.length > 1) {
        // One entry, several days: a row for each of them.
        await _controller.createTaskOnDays(
          template: draft,
          dateKeys: days,
          subtaskTitles: [for (final row in _steps) row.controller.text.trim()],
        );
      } else {
        await _controller.saveTask(
          draft,
          scope: scope,
          occurrenceKey: occurrenceKey,
          subtasks: subtasks,
        );
      }
      if (mounted) Get.back();
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _field(
    ThemeData theme, {
    String? label,
    String? hint,
    IconData? leading,
    String? error,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final scheme = theme.colorScheme;
    final idle = scheme.outlineVariant;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      // The character limit is a guard, not information the form needs; the
      // counter under the field only made the card taller.
      counterText: '',
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 13,
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
      floatingLabelStyle: TextStyle(color: scheme.primary, fontSize: 12),
      errorStyle: theme.textTheme.labelSmall?.copyWith(
        color: scheme.error,
        height: 1.2,
      ),
      errorText: error,
      prefixIcon: leading == null
          ? null
          : Icon(leading, size: 18, color: scheme.onSurfaceVariant),
      // The default 48dp icon slot is most of an input's height on its own.
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 34),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      border: border(idle),
      enabledBorder: border(idle),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.6),
    );
  }

  /// One grouped block of the form: a titled card that holds its own fields, so
  /// the whole form reads as three decisions instead of a long flat list.
  /// Omit [title] for a card whose fields speak for themselves.
  Widget _formCard(
    ThemeData theme, {
    String? title,
    String? hint,
    Widget? trailing,
    required List<Widget> children,
  }) {
    final scheme = theme.colorScheme;
    final hasHeader = title != null || trailing != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader)
            Row(
              children: [
                Expanded(
                  child: Text(
                    title?.toUpperCase() ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.3,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (hasHeader || hint != null) const SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }

  Widget _whenTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final scheme = theme.colorScheme;
    final contentColor = enabled
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.45);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 7, 5, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: contentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: contentColor,
                      ),
                    ),
                  ],
                ),
              ),
              // A set value can be cleared; an empty one only opens the picker.
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: enabled ? onClear : null,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(Icons.close, size: 17, color: scheme.error),
                )
              else
                Icon(
                  enabled ? Icons.chevron_right : Icons.lock_outline,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The extra days a single entry is created on. Each one is removable, and
  /// the button only appears while a main due date exists to add to.
  Widget _moreDates(ThemeData theme) {
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_extraDateKeys.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final dateKey in _extraDateKeys)
                Container(
                  padding: const EdgeInsets.fromLTRB(9, 2, 2, 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dayLabel(dateKey),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove date',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        onPressed: () => _removeDate(dateKey),
                        icon: Icon(
                          Icons.close,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 34,
          // Full width so the button sits centred in the card instead of
          // shrink-wrapped to its label.
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addDate,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              textStyle: const TextStyle(fontSize: 12.5),
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.edit_calendar, size: 16),
            label: Text(
              _extraDateKeys.isEmpty ? 'Add another date' : 'Add one more date',
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepRow(int index, ThemeData theme) {
    final row = _steps[index];
    final scheme = theme.colorScheme;
    final done = row.existing?.done == true;
    final palette = TaskPalette(scheme);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(7, 2, 2, 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done
              ? palette.success.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          // A stored step keeps its own tick; a new one shows where it sits.
          Tooltip(
            message: done ? 'Already done' : 'Not done yet',
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: done ? palette.success : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: row.controller,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          _MiniButton(
            icon: Icons.arrow_upward,
            tooltip: 'Move up',
            // The first step has nowhere to go up to, so it shows no button.
            onTap: index == 0 ? null : () => _moveStep(index, -1),
          ),
          _MiniButton(
            icon: Icons.arrow_downward,
            tooltip: 'Move down',
            onTap: index == _steps.length - 1
                ? null
                : () => _moveStep(index, 1),
          ),
          _MiniButton(
            icon: Icons.close,
            tooltip: 'Remove step',
            color: scheme.error,
            onTap: () => _removeStep(index),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleFilled = _titleController.text.trim().isNotEmpty;
    final stepReady = _stepController.text.trim().isNotEmpty;
    // The page keeps its full height (see `resizeToAvoidBottomInset` below), so
    // the list needs to grow its own tail by whatever the keyboard covers —
    // otherwise the last card could never be scrolled into the open band.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      // Lifting the save bar is done by hand in [_saveBar]. Relying on the
      // scaffold slot instead means the bar only clears the keyboard when the
      // window itself is resized, which edge-to-edge Android no longer
      // guarantees — and the button ended up behind the keyboard.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBarBackButton(),
        title: Text(widget.isEditing ? 'Edit task' : 'Add task'),
      ),
      body: Column(
        // Stretch, not the default centred cross axis: the save bar has to keep
        // the full width it had as a `bottomNavigationBar`, otherwise it shrinks
        // to the button and the page background shows through on both sides.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, 2, 12, 12 + keyboard),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _formCard(
                  theme,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 80,
                      autofocus: !widget.isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: _field(
                        theme,
                        label: 'Title',
                        hint: 'e.g. Reply to the advisor',
                        leading: Icons.task_alt,
                        error: _titleError,
                      ),
                      onChanged: (value) {
                        if (value.trim().isEmpty && _titleError == null) {
                          setState(() => _titleError = 'Enter a title.');
                        } else if (value.trim().isNotEmpty &&
                            _titleError != null) {
                          setState(() => _titleError = null);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLength: 240,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      decoration: _field(
                        theme,
                        label: 'Notes (optional)',
                        hint: 'Anything that helps when you pick this up',
                        leading: Icons.notes_outlined,
                      ),
                    ),
                  ],
                ),
                _formCard(
                  theme,
                  title: 'When',
                  hint: widget.isEditing
                      ? null
                      : 'Pick more than one date to create it on each of them.',
                  children: [
                    _whenTile(
                      theme,
                      icon: Icons.event_outlined,
                      label: 'Due date',
                      value: _dueSummary,
                      enabled: true,
                      onTap: _pickDate,
                      onClear: _dueDateKey == null
                          ? null
                          : () => setState(() {
                              _dueDateKey = null;
                              _dueMinutesOfDay = null;
                              // Without a main day there is nothing for the extras to
                              // belong to.
                              _extraDateKeys.clear();
                            }),
                    ),
                    if (!widget.isEditing && _hasDueDate) ...[
                      const SizedBox(height: 7),
                      _moreDates(theme),
                    ],
                  ],
                ),
                _formCard(
                  theme,
                  title: 'Steps',
                  hint: _steps.isEmpty
                      ? 'Break the task down if it helps.'
                      : null,
                  trailing: _steps.isEmpty
                      ? null
                      : Text(
                          '${_steps.length} ${_steps.length == 1 ? 'step' : 'steps'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  children: [
                    for (var index = 0; index < _steps.length; index++)
                      _stepRow(index, theme),
                    TextField(
                      controller: _stepController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 60,
                      decoration: InputDecoration(
                        hintText: 'Add a step',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Add step',
                          onPressed: stepReady ? _addStep : null,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.add,
                            size: 18,
                            color: stepReady
                                ? scheme.primary
                                : scheme.onSurfaceVariant.withValues(
                                    alpha: 0.45,
                                  ),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _addStep(),
                    ),
                  ],
                ),
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _saveError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _saveBar(context, theme, titleFilled),
        ],
      ),
    );
  }

  /// The save action, pinned to the bottom of the page and lifted over the soft
  /// keyboard by hand.
  ///
  /// The system gesture inset is subtracted from the lift because [SafeArea]
  /// already reserves it; adding both would push the bar one inset too high.
  Widget _saveBar(BuildContext context, ThemeData theme, bool titleFilled) {
    final scheme = theme.colorScheme;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final system = MediaQuery.paddingOf(context).bottom;
    final lift = insets > system ? insets - system : 0.0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: lift),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 7, 12, 9),
          child: FilledButton.icon(
            // Saving is only possible with a title and never twice at once.
            onPressed: _saving || !titleFilled ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 19),
            label: Text(
              widget.isEditing
                  ? 'Save changes'
                  : _dateKeys.length > 1
                  ? 'Create on ${_dateKeys.length} days'
                  : 'Create task',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _dayLabel(String dateKey) {
    final date = dateFromKey(dateKey);
    if (dateKey == todayDateKey) return 'Today';
    if (dateKey == dateKeyFor(shiftDays(today, 1))) return 'Tomorrow';
    if (dateKey == dateKeyFor(shiftDays(today, -1))) return 'Yesterday';
    return DateFormat(
      date.year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy',
    ).format(date);
  }

  String _timeLabel(int minutes) => DateFormat(
    'h:mm a',
  ).format(DateTime(DateTime.now().year, 1, 1, minutes ~/ 60, minutes % 60));
}

class _StepRow {
  _StepRow({this.existing, required this.controller});

  final Subtask? existing;
  final TextEditingController controller;
}

/// A 26dp icon button for the step rows. A disabled one draws nothing rather
/// than sitting there greyed out, so the row never shows a control that cannot
/// be used.
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox(width: 4);
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: color ?? scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
