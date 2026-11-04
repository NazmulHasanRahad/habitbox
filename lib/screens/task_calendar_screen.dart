import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/task_controller.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../utils/date_key.dart';
import '../utils/task_palette.dart';
import '../widgets/app_bar_shell.dart';
import '../widgets/task_card.dart';
import '../widgets/task_progress_meter.dart';
import 'task_screen.dart';

/// The month view that replaced the day strip: every day the tasks really land
/// on, how many are scheduled there and how many of those are finished.
///
/// Recurring series are expanded day by day by [TaskController.occursOn], so a
/// daily task shows on every day it covers rather than only on the day the
/// series started. Picking a day moves the dashboard's own day selector and
/// opens that day's list right below the grid, using the same cards as the
/// dashboard.
class TaskCalendarScreen extends StatefulWidget {
  const TaskCalendarScreen({super.key});

  @override
  State<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

class _TaskCalendarScreenState extends State<TaskCalendarScreen> {
  static final DateFormat _monthLabel = DateFormat('MMMM yyyy');
  static final DateFormat _dayLabel = DateFormat('EEEE, d MMMM');
  static const List<String> _weekdayNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// The month the grid is showing, as its first day.
  late DateTime _month;

  /// Whether the panel below the grid shows the tasks that belong to no day.
  bool _showUndated = false;

  @override
  void initState() {
    super.initState();
    // The dashboard can be left sitting on another day, so the grid opens on the
    // month that day lives in rather than always on this one.
    final date = dateFromKey(Get.find<TaskController>().selectedDateKey.value);
    _month = DateTime(date.year, date.month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = Get.find<TaskController>();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            Text(
              'Which days hold your tasks',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.25,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
      body: Obx(() {
        final error = controller.loadError.value;
        if (error.isNotEmpty) {
          return _ErrorState(message: error, onRetry: controller.loadTasks);
        }

        // Both lists are read here rather than in the cells: an Obx only tracks
        // the observables its own closure touches, and the counts of a day come
        // from the tasks and the completion ledger together.
        final days = _countDays(controller);
        var scheduled = 0;
        var finished = 0;
        for (final day in days) {
          if (day.date.month != _month.month) continue;
          scheduled += day.total;
          finished += day.done;
        }

        final selected = controller.selectedDateKey.value;
        final undated = controller.undatedTasks;
        final listed = _showUndated ? undated : controller.tasksOn(selected);

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            _monthCard(days, selected, scheduled, finished, scheme),
            if (undated.isNotEmpty) ...[
              const SizedBox(height: 10),
              _undatedRow(undated.length, scheme),
            ],
            const SizedBox(height: 12),
            _dayPanel(listed, selected, scheme),
          ],
        );
      }),
    );
  }

  // ----- Counting -------------------------------------------------------------

  /// The visible grid: the whole month plus the leading and trailing days that
  /// keep the weeks rectangular.
  List<DateTime> _gridDates() {
    final first = DateTime(_month.year, _month.month);
    // DateTime.weekday runs 1..7 from Monday, which is the column a cell sits in.
    final start = shiftDays(first, -(first.weekday - 1));
    return [for (var i = 0; i < 42; i++) shiftDays(start, i)];
  }

  /// One pass over the tasks for the scheduled counts and one over the ledger for
  /// the finished ones, so the grid is worked out once per frame instead of every
  /// cell re-reading every task.
  List<_GridDay> _countDays(TaskController controller) {
    final dates = _gridDates();
    final keys = [for (final date in dates) dateKeyFor(date)];
    final column = <String, int>{
      for (var i = 0; i < keys.length; i++) keys[i]: i,
    };
    final totals = List<int>.filled(keys.length, 0);
    final done = List<int>.filled(keys.length, 0);
    final alive = <int>{};

    for (final stored in controller.tasks) {
      if (stored.archived) continue;
      final id = stored.id;
      if (id != null) alive.add(id);
      for (final entry in column.entries) {
        if (controller.occursOn(stored, entry.key)) totals[entry.value]++;
      }
    }
    for (final completion in controller.completions) {
      final at = column[completion.dateKey];
      if (at == null || !alive.contains(completion.taskId)) continue;
      // A ledger row can outlive the occurrence it answered for, so it is never
      // allowed to push a day past the tasks that day actually holds.
      if (done[at] < totals[at]) done[at]++;
    }

    return [
      for (var i = 0; i < keys.length; i++)
        _GridDay(
          date: dates[i],
          dateKey: keys[i],
          total: totals[i],
          done: done[i],
        ),
    ];
  }

  /// Whether the day's open work has already gone by. Asked of the day being
  /// drawn, not of the series: a recurring task's own due date names the first
  /// day of its run, which would make every later day look late.
  bool _slippedOn(Task task, String dateKey, {required bool done}) {
    if (done) return false;
    final compare = dateKey.compareTo(todayDateKey);
    if (compare != 0) return compare < 0;
    final minutes = task.dueMinutesOfDay;
    if (minutes == null) return false;
    final now = DateTime.now();
    return now.hour * 60 + now.minute > minutes;
  }

  /// A listed task with its own status worked out. The tasks of a day are marked
  /// against the day being opened; the undated ones keep belonging to the day
  /// they were made on, which is what their ledger rows are filed under.
  List<_PanelRow> _rows(List<Task> listed, String dateKey) {
    final controller = Get.find<TaskController>();
    final rows = <_PanelRow>[];
    for (final task in listed) {
      final statusKey = _showUndated
          ? controller.occurrenceKeyFor(task)
          : dateKey;
      final done = controller.isCompleteOn(task, statusKey);
      // A task with no date has no due moment that can pass it by.
      final slipped = !_showUndated && _slippedOn(task, statusKey, done: done);
      rows.add(
        _PanelRow(
          task: task,
          statusKey: statusKey,
          done: done,
          slipped: slipped,
        ),
      );
    }
    return rows;
  }

  // ----- Pieces ---------------------------------------------------------------

  Widget _monthCard(
    List<_GridDay> days,
    String selected,
    int scheduled,
    int finished,
    ColorScheme scheme,
  ) {
    final isCurrentMonth =
        _month.year == today.year && _month.month == today.month;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(scheme.surfaceContainerHigh, Colors.white, 0.12)!,
            scheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MonthButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous month',
                onTap: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  _monthLabel.format(_month),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              _MonthButton(
                icon: Icons.chevron_right,
                tooltip: 'Next month',
                onTap: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final name in _weekdayNames)
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.2,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var week = 0; week < 6; week++)
            Row(
              children: [
                for (final day in days.skip(week * 7).take(7))
                  Expanded(
                    child: _DayCell(
                      day: day,
                      inMonth: day.date.month == _month.month,
                      isToday: day.dateKey == todayDateKey,
                      selected: day.dateKey == selected,
                      onTap: () => _pickDay(day.dateKey),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Container(height: 1, color: scheme.onSurface.withValues(alpha: 0.07)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$scheduled scheduled · $finished done',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Only a month that is not this one can need the way back, so the
              // control never appears doing nothing.
              if (!isCurrentMonth)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _month = DateTime(today.year, today.month),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.today_outlined, size: 16),
                  label: const Text('This month'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _undatedRow(int count, ColorScheme scheme) {
    final open = _showUndated;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _showUndated = !open),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: open
                ? scheme.primary.withValues(alpha: 0.1)
                : scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: open
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 17,
                color: open ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No date set · $count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: open ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.expand_more,
                  size: 20,
                  color: open ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayPanel(List<Task> listed, String dateKey, ColorScheme scheme) {
    final controller = Get.find<TaskController>();
    final palette = TaskPalette(scheme);
    final theme = Theme.of(context);
    final rows = _rows(listed, dateKey);
    final done = rows.where((row) => row.done).length;
    final openCount = rows.length - done;
    final hasSlip = rows.any((row) => row.slipped);
    final title = _showUndated
        ? 'No date set'
        : _dayLabel.format(dateFromKey(dateKey));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _showUndated
                    ? '${rows.length} task${rows.length == 1 ? '' : 's'}'
                    : '$openCount open · $done done',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: hasSlip
                      ? palette.danger
                      : done == rows.length && done > 0
                      ? palette.success
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              _showUndated
                  ? 'Every task has a day. Add one without a date and it waits here.'
                  : 'Nothing scheduled on this day. Add a task for it with the + button.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else ...[
            TaskProgressMeter(
              slices: [
                for (final row in rows)
                  TaskDaySlice(done: row.done, pastDue: row.slipped),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskCard(
                  task: row.task,
                  isComplete: row.done,
                  isOverdue: row.slipped,
                  subtasks: List<Subtask>.from(
                    controller.subtasksFor(row.task),
                  ),
                  onToggle: () => controller.toggleComplete(
                    row.task,
                    dateKey: row.statusKey,
                  ),
                  onToggleSubtask: controller.toggleSubtask,
                  onTap: () => TaskScreen.openDetails(row.task),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// A tap means 'open that day': the dashboard's own selector moves, its filter
  /// follows it the way it did from the strip, and the panel below refills.
  void _pickDay(String dateKey) {
    Get.find<TaskController>().selectDate(dateKey);
    final date = dateFromKey(dateKey);
    setState(() {
      _showUndated = false;
      _month = DateTime(date.year, date.month);
    });
  }
}

/// One day of the grid with the counts its cell draws.
class _GridDay {
  const _GridDay({
    required this.date,
    required this.dateKey,
    required this.total,
    required this.done,
  });

  final DateTime date;
  final String dateKey;
  final int total;
  final int done;

  bool get allDone => total > 0 && done >= total;
}

/// A listed task, seen from the day its status is recorded on.
class _PanelRow {
  const _PanelRow({
    required this.task,
    required this.statusKey,
    required this.done,
    required this.slipped,
  });

  final Task task;
  final String statusKey;
  final bool done;
  final bool slipped;
}

/// One day of the grid: the number, and 'done of scheduled' under it whenever
/// the day holds work. Colour is spent once — the picked day wears the accent
/// fill, today borrows its ring, a finished day the success tone, a slipped one
/// the warning tone.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final _GridDay day;
  final bool inMonth;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  static final DateFormat _cellTooltip = DateFormat('EEE, d MMMM');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = TaskPalette(scheme);
    final slipped = !day.allDone && day.dateKey.compareTo(todayDateKey) < 0;

    final accent = selected
        ? scheme.onPrimary
        : isToday
        ? scheme.primary
        : day.allDone
        ? palette.success
        : slipped
        ? palette.danger
        : scheme.onSurface;
    final tint = accent.withValues(
      alpha: selected
          ? 0.82
          : inMonth
          ? 0.72
          : 0.4,
    );

    return Tooltip(
      message: day.total == 0
          ? '${_cellTooltip.format(day.date)} · nothing scheduled'
          : '${_cellTooltip.format(day.date)} · ${day.done} of ${day.total} done',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: AspectRatio(
              aspectRatio: 0.82,
              child: Container(
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(scheme.primary, Colors.white, 0.14)!,
                            scheme.primary,
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !selected && isToday
                        ? scheme.primary.withValues(alpha: 0.45)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.date.day}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: selected || isToday
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: tint,
                      ),
                    ),
                    // The line keeps its height whether or not the day has work,
                    // so every number in the grid sits on one row.
                    SizedBox(
                      height: 12,
                      child: day.total == 0
                          ? null
                          : Center(
                              child: Text(
                                '${day.done}/${day.total}',
                                style: TextStyle(
                                  fontSize: 9,
                                  height: 1.1,
                                  letterSpacing: 0.2,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? scheme.onPrimary.withValues(alpha: 0.9)
                                      : tint,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The month stepper, at the same weight as the icons it sits beside.
class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(icon, size: 19, color: appBarIconColor(scheme)),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 40,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Could not open your tasks',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
