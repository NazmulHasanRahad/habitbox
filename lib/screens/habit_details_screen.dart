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
  static final DateFormat _selectedTitle = DateFormat('EEEE, d MMMM yyyy');

  /// The day the habit began, shown once in the record card.
  static final DateFormat _startLabel = DateFormat('d MMM yyyy');

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
    final shownMonth = DateTime(_displayMonth.year, _displayMonth.month);
    final canGoNext = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
    ).isBefore(DateTime(today.year, today.month + 1));
    // Keep the dropdown's value inside its item list (24 months of history).
    final canGoPrev = shownMonth.isAfter(
      DateTime(today.year, today.month - 23),
    );
    void onSelectDate(DateTime date) => _tapDate(habit, date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                habitIconData(habit.iconCodePoint),
                color: accent,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (habit.description == null || habit.description!.isEmpty)
                        ? 'No Description'
                        : habit.description!,
                    style: const TextStyle(fontSize: 14, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
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
        _card(
          accent: accent,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: '${_displayMonth.year}-${_displayMonth.month}',
                        dropdownColor: Color.lerp(accent, Colors.black, 0.75),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _monthOptions(),
                        onChanged: (value) {
                          if (value == null) return;
                          final parts = value.split('-');
                          setState(() {
                            _displayMonth = DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                            );
                          });
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: canGoPrev
                        ? () => setState(() {
                            _displayMonth = DateTime(
                              _displayMonth.year,
                              _displayMonth.month - 1,
                            );
                          })
                        : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: canGoNext
                        ? () => setState(() {
                            _displayMonth = DateTime(
                              _displayMonth.year,
                              _displayMonth.month + 1,
                            );
                          })
                        : null,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(today),
                    child: const Text('Today'),
                  ),
                ],
              ),
              MonthCalendar(
                displayMonth: _displayMonth,
                markedKeys: markedKeys,
                selectedDateKey: _selectedDateKey,
                accent: accent,
                onDayTap: onSelectDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All-time record',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              const Text(
                'A day counts when the chart or calendar marks it',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(height: 6),
              _fact(
                icon: Icons.whatshot,
                label: 'Current streak',
                value: _days(currentStreak),
                showDivider: true,
              ),
              _fact(
                icon: Icons.calendar_today_outlined,
                label: 'Since start',
                value: _startLabel.format(habit.createdAt),
                showDivider: true,
              ),
              _fact(
                icon: Icons.check_circle_outline,
                label: 'Completions',
                value: '$completions times',
                showDivider: true,
              ),
              _fact(
                icon: Icons.error_outline,
                label: 'Missed days',
                value: _days(missedDays),
                showDivider: true,
              ),
              _fact(
                icon: Icons.emoji_events_outlined,
                label: 'Longest streak',
                value: _days(bestStreak),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One line of the record: the figure's name on the left, its size on the
  /// right. The values wear no colour — this card reports, it does not judge.
  Widget _fact({
    required IconData icon,
    required String label,
    required String value,
    required bool showDivider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.white54),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static String _days(int count) => '$count ${count == 1 ? 'day' : 'days'}';

  List<DropdownMenuItem<String>> _monthOptions() {
    // 24 months of history plus the current month.
    final items = <DropdownMenuItem<String>>[];
    for (var i = 23; i >= 0; i--) {
      final month = DateTime(
        today.year,
        today.month - i,
      ); // day-component arithmetic normalizes years
      final label = _monthTitle.format(month);
      items.add(
        DropdownMenuItem(
          value: '${month.year}-${month.month}',
          child: Text(label),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final habit = _habit;
    final accent = habit == null ? Colors.deepPurple : Color(habit.color);
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'JetBrainsMono',
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0D12),
    );

    return Theme(
      data: darkTheme,
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
