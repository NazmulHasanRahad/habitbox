import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../utils/date_key.dart';
import '../utils/habit_icon.dart';

/// Bottom sheet to log a day's value of a count/measure habit: tap the plus
/// and minus pads (or the quick chips) to step the value, then save.
/// Defaults to today; the details screen passes a selected past date.
class HabitValueSheet extends StatefulWidget {
  const HabitValueSheet({super.key, required this.habit, this.dateKey});

  final Habit habit;
  final String? dateKey;

  static Future<void> show(
    BuildContext context,
    Habit habit, {
    String? dateKey,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      // Inherit the details screen's local (dark) theme when used there.
      useRootNavigator: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          HabitValueSheet(habit: habit, dateKey: dateKey ?? todayDateKey),
    );
  }

  @override
  State<HabitValueSheet> createState() => _HabitValueSheetState();
}

class _HabitValueSheetState extends State<HabitValueSheet> {
  static const double _step = 1;

  late double _value;
  bool _manualEntry = false;
  String? _errorText;
  final TextEditingController _textController = TextEditingController();

  String get _dateKey => widget.dateKey ?? todayDateKey;

  HabitController get _controller => Get.find<HabitController>();

  @override
  void initState() {
    super.initState();
    _value = _controller.valueFor(widget.habit, _dateKey) ?? 0;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  static String _formatValue(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  void _bump(double delta) {
    final next = (_value + delta);
    HapticFeedback.vibrate();
    setState(() {
      _value = next < 0 ? 0 : next;
      _errorText = null;
      if (_manualEntry) _textController.text = _formatValue(_value);
    });
  }

  void _setValue(double value) => _bump(value - _value);

  void _toggleManualEntry() {
    setState(() {
      _manualEntry = !_manualEntry;
      if (_manualEntry) {
        _textController.text = _formatValue(_value);
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      }
    });
  }

  void _onTextChanged(String text) {
    final parsed = num.tryParse(text.trim());
    if (parsed == null || parsed < 0) {
      setState(() => _errorText = 'Enter a valid non-negative number.');
      return;
    }
    setState(() {
      _value = parsed.toDouble();
      _errorText = null;
    });
  }

  Future<void> _save() async {
    if (_errorText != null) return;
    HapticFeedback.vibrate();
    var value = _value;
    if (widget.habit.type == HabitType.count) value = value.roundToDouble();
    await _controller.saveValue(widget.habit, _dateKey, value);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clearEntry() async {
    HapticFeedback.vibrate();
    await _controller.saveValue(widget.habit, _dateKey, null);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _stepper(
    ThemeData theme,
    Color accent, {
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 62,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? accent.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.7,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled
                ? accent.withValues(alpha: 0.4)
                : theme.colorScheme.outlineVariant,
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: filled ? accent : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _valueBox(ThemeData theme) {
    if (_manualEntry) {
      return SizedBox(
        height: 72,
        child: TextField(
          controller: _textController,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: _boxBorder(theme.colorScheme.outlineVariant),
            enabledBorder: _boxBorder(theme.colorScheme.outlineVariant),
            focusedBorder: _boxBorder(theme.colorScheme.primary, 1.6),
          ),
          onChanged: _onTextChanged,
          onSubmitted: (_) => _toggleManualEntry(),
        ),
      );
    }
    return GestureDetector(
      onTap: _toggleManualEntry,
      child: Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.7,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 1.2,
          ),
        ),
        child: Text(
          _formatValue(_value),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _boxBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _chip(
    ThemeData theme,
    Color accent,
    String label,
    IconData icon, {
    bool highlighted = false,
    required VoidCallback onTap,
  }) {
    final color = highlighted ? accent : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted
                ? accent.withValues(alpha: 0.16)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: highlighted
                  ? accent.withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habit = widget.habit;
    final accent = Color(habit.color);
    final onAccent = accent.computeLuminance() > 0.55
        ? Colors.black87
        : Colors.white;
    final unit = habit.unit;
    final goal = habit.goalValue;
    final hasGoal = goal != null && goal > 0;
    final hasEntry = _controller.valueFor(habit, _dateKey) != null;
    final isToday = _dateKey == todayDateKey;
    final when = isToday
        ? 'Today'
        : DateFormat('EEE d MMM yyyy').format(DateTime.parse(_dateKey));
    final progress = hasGoal
        ? (_value / goal).clamp(0.0, 1.0)
        : (_value > 0 ? 1.0 : 0.0);
    final percent = hasGoal ? (_value / goal * 100).round() : null;

    return Padding(
      // Lift the sheet above the keyboard while manual entry is focused.
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
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    habitIconData(habit.iconCodePoint),
                    size: 23,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unit == null || unit.isEmpty ? when : '$when · $unit',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _stepper(
                  theme,
                  accent,
                  icon: Icons.remove,
                  onTap: () => _bump(-_step),
                  filled: false,
                ),
                const SizedBox(width: 10),
                Expanded(child: _valueBox(theme)),
                const SizedBox(width: 10),
                _stepper(
                  theme,
                  accent,
                  icon: Icons.add,
                  onTap: () => _bump(_step),
                  filled: true,
                ),
              ],
            ),
            SizedBox(height: _errorText == null ? 14 : 6),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: accent.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  hasGoal ? Icons.adjust : Icons.help_outline,
                  size: 16,
                  color: hasGoal ? accent : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasGoal
                        ? 'Goal ${_formatValue(goal)}${unit == null || unit.isEmpty ? '' : ' $unit'}'
                        : 'No daily goal',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasGoal
                          ? accent
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (percent != null)
                  Text(
                    '$percent%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: percent >= 100
                          ? accent
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _chip(
                  theme,
                  accent,
                  '+1',
                  Icons.add,
                  onTap: () => _bump(_step),
                ),
                const SizedBox(width: 8),
                _chip(theme, accent, '+5', Icons.add, onTap: () => _bump(5)),
                const SizedBox(width: 8),
                if (hasGoal)
                  _chip(
                    theme,
                    accent,
                    _formatValue(goal),
                    Icons.adjust,
                    highlighted: true,
                    onTap: () => _setValue(goal),
                  )
                else
                  _chip(
                    theme,
                    accent,
                    '+10',
                    Icons.add,
                    onTap: () => _bump(10),
                  ),
                const SizedBox(width: 8),
                _chip(
                  theme,
                  accent,
                  '0',
                  Icons.replay,
                  onTap: () => _setValue(0),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (hasEntry) ...[
                  IconButton(
                    tooltip: 'Clear entry',
                    onPressed: _clearEntry,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 21,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  tooltip: _manualEntry ? 'Use buttons' : 'Type a value',
                  onPressed: _toggleManualEntry,
                  style: IconButton.styleFrom(
                    backgroundColor: _manualEntry
                        ? accent.withValues(alpha: 0.16)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.7,
                          ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: Icon(
                    _manualEntry ? Icons.grid_view : Icons.edit_outlined,
                    size: 21,
                    color: _manualEntry ? accent : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _save,
                      child: Text(
                        'Save ${_formatValue(_value)}${unit == null || unit.isEmpty ? '' : ' $unit'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
