import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../utils/habit_icon.dart';
import '../widgets/app_bar_shell.dart';
import 'icon_picker_screen.dart';

/// Full-screen "Add habit" form opened from the Home Screen FAB.
/// Pass [initialHabit] to reuse it as the Edit Habit form.
/// Sections: Habit Icon -> Habit Name -> Habit Type -> Goal Settings -> Reminder
/// -> Color. Saves to SQLite through [HabitController] and closes on success.
class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key, this.initialHabit});

  final Habit? initialHabit;

  bool get isEditing => initialHabit != null;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  /// Fixed palette; the first eight entries are the colors older versions
  /// shipped with, so existing habits still match one.
  static const List<int> _colors = <int>[
    0xFF7C4DFF, // violet
    0xFF9C27B0, // purple
    0xFFE040FB, // magenta
    0xFFEC407A, // pink
    0xFFE91E63, // deep pink
    0xFFEF5350, // light red
    0xFFF44336, // red
    0xFFFF7043, // coral
    0xFFFF9800, // orange
    0xFFFFA726, // amber orange
    0xFFFFC107, // amber
    0xFFFFEB3B, // yellow
    0xFFC0CA33, // lime
    0xFF9CCC65, // light green
    0xFF4CAF50, // green
    0xFF26A69A, // teal
    0xFF009688, // dark teal
    0xFF26C6DA, // cyan
    0xFF29B6F6, // light blue
    0xFF2196F3, // blue
    0xFF3F51B5, // indigo
    0xFF5C6BC0, // deep indigo
    0xFF78909C, // blue grey
    0xFF8D6E63, // brown
    0xFF9E9E9E, // grey
  ];

  static const List<_TypeOption> _types = <_TypeOption>[
    _TypeOption(
      type: HabitType.yesNo,
      label: 'Yes / No',
      description: 'Mark each day complete or incomplete',
      icon: Icons.check_circle_outline,
    ),
    _TypeOption(
      type: HabitType.count,
      label: 'Count',
      description: 'Track a daily quantity',
      icon: Icons.tag,
    ),
    _TypeOption(
      type: HabitType.measure,
      label: 'Measure',
      description: 'Track a measurable value',
      icon: Icons.straighten,
    ),
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  /// Time a freshly switched-on reminder starts at, so the common case is one
  /// tap. The user can change it straight after.
  static const int _defaultReminderMinutes = 9 * 60;

  HabitType _type = HabitType.yesNo;
  int _colorValue = _colors[0];
  int _iconCodePoint = Icons.monitor_heart.codePoint;
  String? _nameError;
  String? _goalError;
  bool _saving = false;

  /// Reminder time as minutes since midnight, or null when the habit has none.
  int? _reminderMinutes;
  int _reminderDays = 127;

  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  Habit? get _initial => widget.initialHabit;

  Color get _accent => Color(_colorValue);

  @override
  void initState() {
    super.initState();
    final initial = _initial;
    if (initial == null) return;
    _nameController.text = initial.name;
    _descriptionController.text = initial.description ?? '';
    _goalController.text = initial.goalValue == null
        ? ''
        : initial.goalValue! % 1 == 0
        ? initial.goalValue!.toInt().toString()
        : initial.goalValue!.toString();
    _unitController.text = initial.unit ?? '';
    _type = initial.type;
    // Stored values are reused as-is, so a habit keeps its own icon and
    // color even when it is not part of the current palette.
    _colorValue = initial.color;
    _iconCodePoint = initial.iconCodePoint;
    _reminderMinutes = initial.reminderMinutes;
    _reminderDays = initial.reminderDays;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _onTypeChanged(HabitType type) {
    setState(() {
      _type = type;
      _goalError = null;
      if (type == HabitType.yesNo) {
        _goalController.clear();
        _unitController.clear();
      }
    });
  }

  Future<void> _pickIcon() async {
    final picked = await Get.to<int>(
      () =>
          IconPickerScreen(selectedCodePoint: _iconCodePoint, accent: _accent),
    );
    if (picked == null || !mounted) return;
    setState(() => _iconCodePoint = picked);
  }

  /// Switching the reminder on asks for the notification permission first, so
  /// a refusal is reported here instead of leaving a reminder that can never
  /// fire. Cancelling the time picker leaves the reminder off.
  Future<void> _onReminderToggled(bool on) async {
    if (!on) {
      setState(() => _reminderMinutes = null);
      return;
    }

    final service = NotificationService.instance;
    if (!service.isReady) await service.initialize();
    if (!mounted) return;
    if (!service.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Habit reminders could not start. Check notification setup and try again.',
          ),
        ),
      );
      return;
    }

    final granted = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'HabitBox cannot post notifications. Allow them in your device '
            'settings, then switch this on again.',
          ),
        ),
      );
      return;
    }
    await _pickReminderTime(_defaultReminderMinutes);
  }

  void _toggleReminderDay(int day) {
    final updatedDays = _reminderDays ^ (1 << day);
    if (updatedDays == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one reminder day.')),
      );
      return;
    }
    setState(() => _reminderDays = updatedDays);
  }

  /// Opens the clock. [current] is preserved when the user backs out.
  Future<void> _pickReminderTime(int current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderMinutes = picked.hour * 60 + picked.minute);
  }

  /// The reminder time in the device's own 12/24-hour convention.
  String _timeLabel(BuildContext context, int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  double? _parsedGoal() {
    final text = _goalController.text.trim();
    if (text.isEmpty) return null;
    return num.tryParse(text)?.toDouble();
  }

  bool _validateGoal() {
    if (_type == HabitType.yesNo) return true;
    final text = _goalController.text.trim();
    if (text.isEmpty) {
      _goalError = null;
      return true;
    }
    final value = num.tryParse(text)?.toDouble();
    if (value == null) {
      _goalError = 'Enter a valid number.';
      return false;
    }
    if (_type == HabitType.count) {
      if (value < 0 || value != value.roundToDouble()) {
        _goalError = 'Goal must be a whole number of 0 or more.';
        return false;
      }
    } else {
      if (value <= 0) {
        _goalError = 'Goal must be greater than 0.';
        return false;
      }
    }
    _goalError = null;
    return true;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final goalValid = _validateGoal();
    setState(() => _nameError = name.isEmpty ? 'Enter a habit name.' : null);
    if (name.isEmpty || !goalValid) return;

    setState(() => _saving = true);
    try {
      double? goal;
      String? unit;
      if (_type != HabitType.yesNo) {
        goal = _parsedGoal();
        if (_type == HabitType.count) goal = goal?.roundToDouble();
        final unitText = _unitController.text.trim();
        if (unitText.isNotEmpty) unit = unitText;
      }
      final descriptionText = _descriptionController.text.trim();
      final controller = Get.find<HabitController>();
      final initial = _initial;
      final habit = Habit(
        // Editing keeps id, creation time and home position; entries stay.
        id: initial?.id,
        name: name,
        type: _type,
        color: _colorValue,
        iconCodePoint: _iconCodePoint,
        goalValue: goal,
        unit: unit,
        createdAt: initial?.createdAt ?? DateTime.now(),
        sortOrder: initial?.sortOrder ?? 0,
        description: descriptionText.isEmpty ? null : descriptionText,
        reminderMinutes: _reminderMinutes,
        reminderDays: _reminderDays,
      );
      if (initial == null) {
        await controller.addHabit(habit);
      } else {
        await controller.updateHabit(habit);
      }
      if (mounted) Get.back();
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
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final idle = theme.colorScheme.outlineVariant;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 14,
      ),
      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: _accent),
      errorText: error,
      prefixIcon: leading == null
          ? null
          : Icon(leading, size: 20, color: theme.colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(idle),
      enabledBorder: border(idle),
      focusedBorder: border(_accent, 1.6),
      errorBorder: border(theme.colorScheme.error),
      focusedErrorBorder: border(theme.colorScheme.error, 1.6),
    );
  }

  Widget _section(ThemeData theme, String title, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconAvatar(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickIcon,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.18),
                  border: Border.all(color: _accent, width: 1.4),
                ),
                child: Icon(
                  habitIconData(_iconCodePoint),
                  size: 34,
                  color: _accent,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.edit,
                    size: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tap to choose from the icon library',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Compact segmented control. The selected type's description and icon sit
  /// below it, which keeps the buttons small enough for narrow screens.
  Widget _typeSelector(ThemeData theme) {
    final selected = _types.firstWhere((option) => option.type == _type);
    final accent = _accent;
    final onAccent = accent.computeLuminance() > 0.55
        ? Colors.black87
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.55,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              for (final option in _types)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTypeChanged(option.type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        color: option.type == _type
                            ? accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            option.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: option.type == _type
                                  ? onAccent
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(selected.icon, size: 15, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.3,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// One row for the whole reminder setting: a switch to turn it on and off,
  /// and the time itself, which opens the clock when tapped. Both the label and
  /// the tap target stay quiet while the reminder is off.
  Widget _reminderCard(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final minutes = _reminderMinutes;
    final enabled = minutes != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => _pickReminderTime(minutes) : null,
              child: Row(
                children: [
                  Icon(
                    enabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none,
                    size: 20,
                    color: enabled ? _accent : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enabled
                              ? '${_reminderDaySummary()} at ${_timeLabel(context, minutes)}'
                              : 'No reminder',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: enabled
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          enabled
                              ? 'Tap to change the time'
                              : 'Switch on to choose days and time',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(value: enabled, onChanged: _onReminderToggled),
        ],
      ),
    );
  }

  String _reminderDaySummary() {
    if (_reminderDays == 127) return 'Every day';
    return [
      for (var day = 0; day < _weekdayLabels.length; day++)
        if ((_reminderDays & (1 << day)) != 0) _weekdayLabels[day],
    ].join(', ');
  }

  Widget _reminderDaySelector(ThemeData theme) {
    if (_reminderMinutes == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 7,
        runSpacing: 4,
        children: [
          for (var day = 0; day < _weekdayLabels.length; day++)
            FilterChip(
              label: Text(_weekdayLabels[day]),
              selected: (_reminderDays & (1 << day)) != 0,
              onSelected: (_) => _toggleReminderDay(day),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: (_reminderDays & (1 << day)) != 0
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              selectedColor: _accent.withValues(alpha: 0.22),
              side: BorderSide(
                color: (_reminderDays & (1 << day)) != 0
                    ? _accent
                    : theme.colorScheme.outlineVariant,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
        ],
      ),
    );
  }

  Widget _colorGrid(ThemeData theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final value in _colors)
          Builder(
            builder: (context) {
              final selected = value == _colorValue;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _colorValue = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 46,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(value),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.onSurface
                          : Colors.black.withValues(alpha: 0.25),
                      width: selected ? 2.2 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 17,
                          color: Color(value).computeLuminance() > 0.55
                              ? Colors.black87
                              : Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent;
    final showGoal = _type != HabitType.yesNo;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBarBackButton(),
        title: Text(widget.isEditing ? 'Edit habit' : 'Add habit'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _iconAvatar(theme),
          const SizedBox(height: 24),
          _section(theme, 'Habit Name'),
          TextField(
            controller: _nameController,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: _field(
              theme,
              label: 'Name',
              hint: 'e.g. Read 20 pages',
              leading: Icons.label_outline,
              error: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLength: 120,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _field(
              theme,
              label: 'Description (optional)',
              hint: 'Why this habit matters to you',
              leading: Icons.notes_outlined,
            ),
          ),
          const SizedBox(height: 24),
          _section(theme, 'Habit Type'),
          _typeSelector(theme),
          if (showGoal) ...[
            const SizedBox(height: 24),
            _section(theme, 'Goal Settings'),
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.numberWithOptions(
                decimal: _type == HabitType.measure,
              ),
              textAlignVertical: TextAlignVertical.center,
              decoration: _field(
                theme,
                label: _type == HabitType.count
                    ? 'Daily goal (whole number, optional)'
                    : 'Daily goal (e.g. 30.5, optional)',
                leading: Icons.flag_outlined,
                error: _goalError,
              ),
              onChanged: (_) {
                if (_goalError != null) setState(() => _goalError = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _field(
                theme,
                label: _type == HabitType.measure
                    ? 'Unit (recommended)'
                    : 'Unit (optional)',
                hint: 'pages, km, minutes, glasses',
                leading: Icons.straighten,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _section(
            theme,
            'Reminder',
            hint: 'Choose one or more days and a time for your reminder',
          ),
          _reminderCard(context, theme),
          _reminderDaySelector(theme),
          const SizedBox(height: 24),
          _section(theme, 'Color'),
          _colorGrid(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: accent.computeLuminance() > 0.55
                ? Colors.black87
                : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 20),
          label: Text(
            widget.isEditing ? 'Save changes' : 'Create habit',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _TypeOption {
  const _TypeOption({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
  });

  final HabitType type;
  final String label;
  final String description;
  final IconData icon;
}
