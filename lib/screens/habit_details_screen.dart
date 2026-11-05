import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../repositories/habit_repository.dart';
import '../utils/date_key.dart';
import '../utils/habit_icon.dart';
import '../widgets/app_bar_shell.dart';
import '../widgets/daily_bar_chart.dart';
import '../widgets/habit_heatmap.dart';
import '../widgets/habit_value_sheet.dart';
import '../widgets/month_calendar.dart';
import 'add_habit_screen.dart';

/// Dark details screen: contribution heatmap, monthly calendar and
/// marking of any past/today date, plus edit and delete actions.
class HabitDetailsScreen extends StatefulWidget {
  const HabitDetailsScreen({super.key, required this.habitId});

  final int habitId;

  @override
  State<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends State<HabitDetailsScreen> {
  final HabitRepository _repository = HabitRepository();

  static final DateFormat _monthTitle = DateFormat('MMM yyyy');
  static final DateFormat _monthShort = DateFormat('MMM');
  static final DateFormat _selectedTitle = DateFormat('EEEE, d MMMM yyyy');

  /// The day the habit began, shown once in the record card.
  static final DateFormat _startLabel = DateFormat('d MMM yyyy');

  /// How far back the month picker and the arrows are allowed to go.
  static const int _historyMonths = 24;

  Habit? _habit;
  Map<String, double> _entries = {};
  DateTime _displayMonth = today;
  String _selectedDateKey = todayDateKey;
  bool _missing = false;

  HabitController get _controller => Get.find<HabitController>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final habit = await _repository.getHabit(widget.habitId);
    final all = await _repository.getEntriesForRange(
      widget.habitId,
      '0000-01-01',
      '9999-12-31',
    );
    if (!mounted) return;
    if (habit == null) {
      setState(() => _missing = true);
      return;
    }
    setState(() {
      _habit = habit;
      _entries = {for (final e in all) e.dateKey: e.value};
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDateKey = dateKeyFor(date);
      _displayMonth = DateTime(date.year, date.month);
    });
  }

  /// Consecutive marked days ending today. Today only breaks the chain once it
  /// is over, so a morning never reads back as a streak of zero.
  static int _streakToToday(Set<String> markedKeys) {
    var cursor = today;
    if (!markedKeys.contains(dateKeyFor(cursor))) {
      cursor = shiftDays(cursor, -1);
    }
    var streak = 0;
    while (markedKeys.contains(dateKeyFor(cursor))) {
      streak++;
      cursor = shiftDays(cursor, -1);
    }
    return streak;
  }

  /// Longest run of consecutive marked days over the habit's whole history.
  static int _longestRun(List<String> sortedKeys) {
    var best = 0;
    var run = 0;
    for (var i = 0; i < sortedKeys.length; i++) {
      run =
          i > 0 &&
              daysBetween(
                    dateFromKey(sortedKeys[i - 1]),
                    dateFromKey(sortedKeys[i]),
                  ) ==
                  1
          ? run + 1
          : 1;
      if (run > best) best = run;
    }
    return best;
  }

  Future<void> _openEditor(Habit habit) async {
    await Get.to(() => AddHabitScreen(initialHabit: habit));
    _load();
  }

  Future<void> _confirmDelete(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text(
          '"${habit.name}" and all of its tracking history will be '
          'permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.deleteHabit(habit.id!);
    if (mounted) Get.back();
  }

  /// Tapping any day on the chart or the calendar writes that day straight
  /// away: a yes/no habit asks for confirmation, a count/measure habit opens the
  /// value sheet on it. The chart widgets and the month calendar already refuse
  /// future days, so a tap is always a day that can be written to.
  Future<void> _tapDate(Habit habit, DateTime date) async {
    final dateKey = dateKeyFor(date);
    setState(() {
      _selectedDateKey = dateKey;
      _displayMonth = DateTime(date.year, date.month);
    });
    if (habit.type != HabitType.yesNo) {
      await HabitValueSheet.show(context, habit, dateKey: dateKey);
      _load();
      return;
    }
    final marked = (_entries[dateKey] ?? 0) >= 0.5;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(marked ? 'Remove mark?' : 'Mark this day done?'),
        content: Text(_selectedTitle.format(date)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: marked
                  ? Colors.red.shade700
                  : Color(habit.color),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              marked ? 'Remove' : 'Mark done',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.toggleYesNo(habit, dateKey);
    _load();
  }

  // ---------------------------------------------------------------------------
  // Month navigation
  // ---------------------------------------------------------------------------

  bool get _canGoNext {
    return DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
    ).isBefore(DateTime(today.year, today.month + 1));
  }

  /// Keeps the picker and the arrows inside the same 24 months of history.
  bool get _canGoPrev {
    return DateTime(
      _displayMonth.year,
      _displayMonth.month,
    ).isAfter(DateTime(today.year, today.month - (_historyMonths - 1)));
  }

  void _stepMonth(int delta) {
    setState(() {
      _displayMonth = DateTime(
        _displayMonth.year,
        _displayMonth.month + delta,
      );
    });
  }

  /// Month selection, newest first. Replaces the bare dropdown so the range on
  /// offer is visible at a glance and one tap is enough to jump.
  Future<void> _pickMonth(Color accent) async {
    final options = <DateTime>[
      for (var i = 0; i < _historyMonths; i++)
        DateTime(today.year, today.month - i),
    ];
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: _darkTheme(accent),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF17141C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Jump to month',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'The last $_historyMonths months',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white38),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final month in options) _monthChip(ctx, month, accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _displayMonth = DateTime(picked.year, picked.month));
  }

  Widget _monthChip(BuildContext ctx, DateTime month, Color accent) {
    final selected =
        month.year == _displayMonth.year && month.month == _displayMonth.month;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(ctx).pop(month),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.60)
                : Colors.white12,
          ),
        ),
        child: Text(
          '${_monthShort.format(month)} ${month.year}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? accent : Colors.white70,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  static String _shortNumber(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  static String _typeLabel(HabitType type) => switch (type) {
    HabitType.yesNo => 'Yes / No',
    HabitType.count => 'Count',
    HabitType.measure => 'Measure',
  };

  ThemeData _darkTheme(Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'JetBrainsMono',
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0D12),
    );
  }

  Widget _card({required Color accent, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(accent, Colors.black, 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }

  /// Icon, name and description on one baseline-friendly row, followed by two
  /// quiet pills that say how the habit is tracked and what its target is.
  Widget _header(Habit habit, Color accent) {
    final description = habit.description?.trim();
    final goal = habit.goalValue;
    final unit = habit.unit?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.24),
            accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.50)),
            ),
            child: Icon(
              habitIconData(habit.iconCodePoint),
              color: accent,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (description == null || description.isEmpty)
                      ? 'No description'
                      : description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: (description == null || description.isEmpty)
                        ? Colors.white24
                        : Colors.white60,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _pill(_typeLabel(habit.type)),
                    if (goal != null && goal > 0)
                      _pill(
                        'Target ${_shortNumber(goal)}'
                        '${unit == null || unit.isEmpty ? '' : ' $unit'}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Month stepper on the left, "Today" on the right. The month name in the
  /// middle is tappable and opens the month picker.
  Widget _calendarHeader(Color accent) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _navArrow(
                  Icons.chevron_left,
                  _canGoPrev,
                  () => _stepMonth(-1),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pickMonth(accent),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _monthTitle.format(_displayMonth),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more,
                          size: 15,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                ),
                _navArrow(
                  Icons.chevron_right,
                  _canGoNext,
                  () => _stepMonth(1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectDate(today),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              'Today',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 38,
        height: 42,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }

  /// How the shown month is going: days logged, and — when the habit has a
  /// target — how many of them reached it.
  Widget _monthSummary(Habit habit, Color accent) {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final goal = habit.goalValue;
    final hasGoal = goal != null && goal > 0;

    var logged = 0;
    var met = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final key = dateKeyFor(DateTime(year, month, day));
      if (key.compareTo(todayDateKey) > 0) continue;
      final value = _entries[key];
      if (value == null || value <= 0) continue;
      logged++;
      if (hasGoal && value >= goal) met++;
    }

    final text = habit.type == HabitType.yesNo
        ? '$logged of $daysInMonth days marked'
        : hasGoal
        ? '$logged logged · $met met target'
        : '$logged days logged';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: daysInMonth == 0 ? 0 : (logged / daysInMonth).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }

  /// One figure in the record grid: small icon and label on top, the value
  /// underneath. The number is what the eye should land on.
  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// The habit's age, as the date it began plus the days it has covered.
  Widget _sinceTile(Habit habit, Color accent) {
    final days = daysBetween(habit.createdAt, today) + 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 15, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Since started',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(height: 4),
                Text(
                  _startLabel.format(habit.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$days',
                style: TextStyle(
                  fontSize: 19,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                days == 1 ? 'day' : 'days',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(Habit habit, Color accent) {
    final markedKeys = <String>{
      for (final entry in _entries.entries)
        if (entry.value > 0) entry.key,
    };
    // Every figure on this screen rests on one rule: a day counts when the
    // heatmap or the calendar shows it, i.e. a value above zero was logged.
    final markedSinceStart = markedKeys.toList()..sort();
    final completions = markedSinceStart.length;
    final missedDays = daysBetween(habit.createdAt, today) + 1 - completions;
    final currentStreak = _streakToToday(markedKeys);
    final bestStreak = _longestRun(markedSinceStart);
    final isMeasured = habit.type != HabitType.yesNo;
    void onSelectDate(DateTime date) => _tapDate(habit, date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _header(habit, accent),
        const SizedBox(height: 16),

        // History: a contribution heatmap for yes/no habits, a daily bar
        // chart for the measured ones.
        _card(
          accent: accent,
          child: habit.type == HabitType.yesNo
              ? HabitHeatmap(
                  habit: habit,
                  entries: _entries,
                  accent: accent,
                  selectedDateKey: _selectedDateKey,
                  onSelect: onSelectDate,
                )
              : DailyBarChart(
                  habit: habit,
                  entries: _entries,
                  accent: accent,
                  selectedDateKey: _selectedDateKey,
                  onSelect: onSelectDate,
                ),
        ),
        const SizedBox(height: 14),

        // Month view.
        _card(
          accent: accent,
          child: Column(
            children: [
              _calendarHeader(accent),
              const SizedBox(height: 14),
              MonthCalendar(
                displayMonth: _displayMonth,
                markedKeys: markedKeys,
                selectedDateKey: _selectedDateKey,
                accent: accent,
                onDayTap: onSelectDate,
                // Measured habits print each day's value against the target.
                entries: isMeasured ? _entries : null,
                goalValue: habit.goalValue,
              ),
              const SizedBox(height: 14),
              _monthSummary(habit, accent),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // All-time record.
        _card(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, size: 17, color: accent),
                  const SizedBox(width: 8),
                  const Text(
                    'All-time record',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                'A day counts when the chart or calendar marks it',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _statTile(
                      icon: Icons.whatshot,
                      label: 'Current streak',
                      value: '$currentStreak',
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      icon: Icons.emoji_events_outlined,
                      label: 'Longest streak',
                      value: '$bestStreak',
                      accent: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _statTile(
                      icon: Icons.check_circle_outline,
                      label: 'Completions',
                      value: '$completions',
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      icon: Icons.error_outline,
                      label: 'Missed days',
                      value: '$missedDays',
                      accent: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _sinceTile(habit, accent),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final habit = _habit;
    final accent = habit == null ? Colors.deepPurple : Color(habit.color);

    return Theme(
      data: _darkTheme(accent),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBarBackButton(),
          actions: [
            if (habit != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: AppBarShell.gap),
                child: AppBarShell(
                  tooltip: 'Edit habit',
                  onTap: () => _openEditor(habit),
                  child: const AppBarGlyph(Icons.edit_outlined),
                ),
              ),
              AppBarShell(
                tooltip: 'Delete habit',
                onTap: () => _confirmDelete(habit),
                child: const AppBarGlyph(Icons.delete_outline),
              ),
              const SizedBox(width: 15),
            ],
          ],
        ),
        body: Builder(
          builder: (context) {
            if (_missing) {
              return const Center(child: Text('This habit no longer exists.'));
            }
            if (habit == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _body(habit, accent);
          },
        ),
      ),
    );
  }
}
