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
import 'add_task_screen.dart';
import 'task_calendar_screen.dart';
import 'task_details_screen.dart';
import 'task_stats_screen.dart';

/// The Task destination: a dashboard over the real rows in the local database.
///
/// The day the list is on comes from the calendar in the app bar, and the Today
/// / Pending / Upcoming / Overdue filter and the day groups are all computed by
/// [TaskController], so nothing here decides what a task's state means.
class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Tasks',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            // The list can be left sitting on another day, so the line under
            // the title names the day it is really showing.
            Obx(
              () => Text(
                TaskScreen._daySubtitle(controller.selectedDateKey.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // The day picker lives here now: the strip it replaced took a row of
          // the list, and a month grid answers the same question better.
          Padding(
            padding: const EdgeInsets.only(right: AppBarShell.gap),
            child: Obx(() {
              final away = controller.selectedDateKey.value != todayDateKey;
              return AppBarShell(
                active: away,
                tooltip: 'Calendar',
                onTap: TaskScreen.openCalendar,
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: AppBarShell.iconSize,
                  color: away ? scheme.primary : appBarIconColor(scheme),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppBarShell.gap),
            child: AppBarShell(
              tooltip: 'Task statistics',
              onTap: TaskScreen.openStats,
              child: Icon(
                Icons.insights_outlined,
                size: AppBarShell.iconSize,
                color: appBarIconColor(scheme),
              ),
            ),
          ),
          AddAppBarButton(
            tooltip: 'Add task',
            onPressed: TaskScreen.openAddTask,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _TaskDashboard(controller: controller),
    );
  }

  static void openAddTask() => Get.to(() => const AddTaskScreen());

  static void openCalendar() => Get.to(() => const TaskCalendarScreen());

  static void openStats() => Get.to(() => const TaskStatsScreen());

  /// 'Monday, 2 November' when the list is on today, and the same words with
  /// the fact that it is not today stated once.
  static String _daySubtitle(String dateKey) {
    final label = DateFormat('EEEE, d MMMM').format(dateFromKey(dateKey));
    return dateKey == todayDateKey ? label : 'Viewing $label';
  }

  static void openDetails(Task task) {
    final id = task.id;
    if (id == null) return;
    Get.to(() => TaskDetailsScreen(taskId: id));
  }
}

class _TaskDashboard extends StatelessWidget {
  const _TaskDashboard({required this.controller});

  final TaskController controller;

  @override
  Widget build(BuildContext context) {
    // Every observable this screen draws is read inside the Obx closure: a read
    // that happens later, while a child widget builds, is not tracked here and
    // the dashboard would quietly stop repainting.
    return Obx(() {
      final error = controller.loadError.value;
      if (error.isNotEmpty) {
        return _MessageState(
          icon: Icons.cloud_off,
          title: 'Could not open your tasks',
          message: error,
          actionLabel: 'Try again',
          onAction: controller.loadTasks,
        );
      }

      final selected = controller.selectedDateKey.value;
      final filter = controller.listFilter.value;
      final subtaskGroups = controller.subtaskIndex;
      final sections = controller.sections;
      final completed = controller.completedTasks;
      final completedOpen = controller.completedOpen.value;
      final hasAny = controller.hasAnyTask;
      // Read here, not in the chips: an Obx only tracks what its own closure reads.
      final counts = controller.filterCounts;

      if (controller.isLoading.value && !hasAny) {
        return const Center(child: CircularProgressIndicator());
      }

      final scheme = Theme.of(context).colorScheme;
      final palette = TaskPalette(scheme);

      // The chips ride above the list as the drag list's own header, so they stay
      // put while a card is being moved. The day's bar is not here any more: it
      // belongs to the day, so it sits in that day's heading line.
      final chrome = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterRow(
            selected: filter,
            counts: counts,
            onPick: controller.setListFilter,
          ),
          const SizedBox(height: 14),
        ],
      );

      // One flat list, headings included: a drag can only carry a card between
      // the rows of the scroll view it lives in, and a day's cards are
      // consecutive rows, so a drop can only ever land inside its own group.
      final rows = <_Row>[
        for (final section in sections) ...[
          _Heading(
            // The heading names the day the group holds, so a Pending list
            // reads as the days that are still owed rather than a blur.
            dateKey: section.dateKey,
            title: section.dateKey == null
                ? 'Anytime'
                : _dayLabel(section.dateKey!),
            slices: _slicesFor(controller, section, completed),
            tint: section.past ? palette.danger : null,
          ),
          for (final task in section.tasks) _Card(task, section.dateKey),
        ],
        // What is already done leaves the day groups and sits below all of
        // them, behind a heading the user can fold away.
        if (completed.isNotEmpty) ...[
          _CompletedHeading(count: completed.length, open: completedOpen),
          if (completedOpen)
            for (final task in completed)
              _Card(task, controller.occurrenceKeyFor(task), done: true),
        ],
      ];

      // The chips and the meter stay on screen even when the filter has nothing:
      // an empty list is a note in place of the cards, not a panel to clear.
      if (rows.isEmpty) {
        final isEmpty = !hasAny;

        final (icon, title, message) = switch (filter) {
          TaskListFilter.today => (
          Icons.event_available_rounded,
          isEmpty ? 'Your day starts here' : 'All clear for today',
          isEmpty
              ? 'Create your first task and start organizing your day.'
              : 'Nothing scheduled for ${_dayLabel(selected)}. Enjoy your free time.',
          ),
          TaskListFilter.overdue => (
          Icons.check_circle_outline_rounded,
          'You’re all caught up',
          'No overdue tasks. Keep up the great work.',
          ),
          TaskListFilter.pending => (
          Icons.done_all_rounded,
          'Nothing left to do',
          'You have no pending tasks for today.',
          ),
          TaskListFilter.upcoming => (
          Icons.calendar_month_rounded,
          'Your schedule is open',
          'No upcoming tasks. Add something you want to accomplish.',
          ),
        };

        return ListView(
          padding: _padding,
          children: [
            chrome,
            const SizedBox(height: 100),

            Center(
              child: Column(
                children: [
                  // Icon container
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.09),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      icon,
                      size: 34,
                      color: const Color(0xFF52D6A4),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: Color(0xFFE9EDF4),
                    ),
                  ),

                  const SizedBox(height: 9),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF858D9C),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // CTA
                  Material(
                    color: const Color(0xFF19372E),
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      onTap: TaskScreen.openAddTask,
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.add_rounded,
                              size: 19,
                              color: Color(0xFF6DE0AE),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Create a task',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8BE5BD),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return ReorderableListView.builder(
        padding: _padding,
        header: chrome,
        // Only an open card asks for the drag, and only on long press, so a
        // plain swipe still scrolls the list: a heading and a card that is
        // already done have no way to move.
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) => _move(rows, oldIndex, newIndex),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return switch (row) {
            final _Heading heading => Padding(
              key: ValueKey('heading-${heading.dateKey ?? 'anytime'}'),
              padding: EdgeInsets.only(top: index == 0 ? 0 : 6, bottom: 8),
              child: _SectionHeader(
                title: heading.title,
                slices: heading.slices,
                tint: heading.tint,
              ),
            ),
            final _CompletedHeading group => Padding(
              key: const ValueKey('heading-completed'),
              padding: const EdgeInsets.only(top: 8),
              child: _SectionHeader.completed(
                count: group.count,
                open: group.open,
                onToggle: controller.toggleCompleted,
              ),
            ),
            final _Card card => _cardRow(card, index, subtaskGroups),
          };
        },
      );
    });
  }

  /// A task line of the list. An open card can be picked up with a long press,
  /// the way the habit list reorders; a done card belongs to the Completed group
  /// and never moves.
  Widget _cardRow(
    _Card card,
    int index,
    Map<int, List<Subtask>> subtaskGroups,
  ) {
    final task = card.task;
    final content = Padding(
      // A completed card keeps the mark box, so ticking it again reopens it and
      // takes it back up to its day.
      padding: const EdgeInsets.only(bottom: 8),
      child: TaskCard(
        task: task,
        isComplete: controller.isComplete(task),
        isOverdue: controller.isOverdue(task),
        subtasks: List<Subtask>.from(subtaskGroups[task.id] ?? const []),
        onToggle: () => controller.toggleComplete(task),
        onToggleSubtask: controller.toggleSubtask,
        onTap: () => TaskScreen.openDetails(task),
      ),
    );
    if (card.done) {
      return KeyedSubtree(key: ValueKey('done-${task.id}'), child: content);
    }
    return ReorderableDelayedDragStartListener(
      key: ValueKey(task.id),
      index: index,
      child: content,
    );
  }

  /// A drag hands over indices of the flat list, but a card only moves inside
  /// its own day, so the landing slot is counted among that group's other cards.
  /// A drop aimed at another group lands at the end of this one instead: the day
  /// a task belongs to comes from its due date, never from the list.
  void _move(List<_Row> rows, int oldIndex, int newIndex) {
    final moved = rows[oldIndex];
    if (moved is! _Card || moved.done) return;
    final others = <int>[
      for (var i = 0; i < rows.length; i++)
        if (i != oldIndex &&
            rows[i] is _Card &&
            !(rows[i] as _Card).done &&
            (rows[i] as _Card).dateKey == moved.dateKey)
          i,
    ];
    final slot = newIndex > oldIndex ? newIndex - 1 : newIndex;
    var to = 0;
    for (final i in others) {
      if ((i > oldIndex ? i - 1 : i) < slot) to++;
    }
    controller.moveTask(moved.task, moved.dateKey, to);
  }

  /// The group's own bar: its open cards first, then whatever of that day is
  /// already finished and sitting in the Completed group. A day group never
  /// shows a done card itself, so without those rows the bar could only ever
  /// read 0% done and the number beside it would not be the day's total.
  List<TaskDaySlice> _slicesFor(
    TaskController controller,
    TaskSection section,
    List<Task> completed,
  ) {
    final dateKey = section.dateKey;
    return [
      for (final task in section.tasks)
        TaskDaySlice(done: false, pastDue: controller.isOverdue(task)),
      if (dateKey != null)
        for (final task in completed)
          if (controller.occurrenceKeyFor(task) == dateKey)
            const TaskDaySlice(done: true, pastDue: false),
    ];
  }

  /// Room for the floating navigation pill, which the list scrolls under.
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(14, 8, 14, 104);

  /// 'Today', 'Tomorrow' or 'Fri, 6 Nov' for the day the dashboard is on.
  String _dayLabel(String dateKey) {
    if (dateKey == todayDateKey) return 'Today';
    if (dateKey == dateKeyFor(shiftDays(today, 1))) return 'Tomorrow';
    if (dateKey == dateKeyFor(shiftDays(today, -1))) return 'Yesterday';
    final date = dateFromKey(dateKey);
    return DateFormat(
      date.year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy',
    ).format(date);
  }
}

/// One line of the dashboard's flat list.
///
/// The list has to be one scroll view for a drag to work, so the headings are
/// rows of their own rather than something drawn between lists.
sealed class _Row {
  const _Row();
}

/// A day group's title line. [dateKey] is the day it names, null for 'Anytime'.
final class _Heading extends _Row {
  const _Heading({
    required this.title,
    required this.slices,
    required this.tint,
    this.dateKey,
  });

  final String title;

  /// The day's own tasks, done ones included — the heading's bar and number.
  final List<TaskDaySlice> slices;
  final Color? tint;
  final String? dateKey;
}

/// The Completed group's line, which folds the group away on tap.
final class _CompletedHeading extends _Row {
  const _CompletedHeading({required this.count, required this.open});

  final int count;
  final bool open;
}

/// A task card. [dateKey] is the group it is drawn under, and a card already
/// [done] belongs to the Completed group instead of a day.
final class _Card extends _Row {
  const _Card(this.task, this.dateKey, {this.done = false});

  final Task task;
  final String? dateKey;
  final bool done;
}

/// The four views of the same pile of tasks, as a tab bar: every view gets its
/// own glyph, its count rides on that glyph as a badge, and the choice is marked
/// three ways at once — a jewel chip that slides under it, its glyph and label
/// lifted to chip-white, and a short bar under the label.
///
/// A late count is the only number allowed to shout: Overdue keeps its red badge
/// and red glyph whether or not its tab is the one standing.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.counts,
    required this.onPick,
  });

  final TaskListFilter selected;
  final Map<TaskListFilter, int> counts;
  final ValueChanged<TaskListFilter> onPick;

  static const double height = 56;

  /// One gutter, not two: the shell's padding is the only space between it and
  /// the chip, so the choice fills its slot instead of floating in the middle of
  /// a wide margin.
  static const double _gap = 3;

  /// The two radii are concentric — the chip's corner is the shell's corner
  /// pulled in by the gutter — which is what makes the nesting read as cut from
  /// one piece.
  static const double _shellRadius = 20;
  static const double _thumbRadius = 17;

  /// The ink a standing tab's glyph, label and badge wear. The chip is dark
  /// enough in both themes that near-white is the only colour that stays legible
  /// on it.
  static const Color _onChip = Color(0xFFF6F3FF);

  /// The chip is a jewel, not a smear of the theme colour: the accent is driven
  /// into a deep plum body and only lifted at its top-left shoulder — far enough
  /// to catch light, not far enough to cost the near-white ink its contrast. One
  /// cut reads premium on a pale light-mode bar and on a dark one, and Overdue
  /// standing keeps it in danger.
  static List<Color> _chipStops(Color accent, bool isDark) {
    final body = Color.lerp(
      accent,
      const Color(0xFF231A55),
      isDark ? 0.6 : 0.46,
    )!;
    return [
      Color.lerp(
        body,
        Color.lerp(accent, Colors.white, isDark ? 0.3 : 0.4),
        isDark ? 0.32 : 0.45,
      )!,
      body,
    ];
  }

  /// Readable before the words are: the same glyphs the cards and the empty
  /// notes use for the same ideas.
  static IconData iconFor(TaskListFilter filter) => switch (filter) {
    TaskListFilter.today => Icons.today_outlined,
    TaskListFilter.overdue => Icons.error_outline,
    TaskListFilter.pending => Icons.hourglass_empty_rounded,
    TaskListFilter.upcoming => Icons.event_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = TaskPalette(scheme);
    final instant = (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final options = TaskListFilter.values;
    final index = options.indexOf(selected);
    final lateWork = (counts[TaskListFilter.overdue] ?? 0) > 0;
    final accent = selected == TaskListFilter.overdue && lateWork
        ? palette.danger
        : scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;

    // What each tab actually counts, so the words on it never have to be
    // guessed at.
    String explain(TaskListFilter filter) => switch (filter) {
      TaskListFilter.today => 'The day the calendar is on, done tasks too',
      TaskListFilter.overdue => 'Still open and past their due time',
      TaskListFilter.pending => 'Still open today, or with no date at all',
      TaskListFilter.upcoming => 'Still open on a day after today',
    };

    Color tintFor(TaskListFilter filter) {
      if (filter == TaskListFilter.overdue && lateWork) return palette.danger;
      if (filter == selected) return accent;
      return scheme.onSurfaceVariant;
    }

    return Container(
      height: _FilterRow.height,
      padding: const EdgeInsets.all(_gap),
      decoration: BoxDecoration(
        // A shell with its own light in it, so the tabs sit on a surface rather
        // than floating over the page. In light the fill stays pale and lets the
        // shadow do the work; in dark the top edge carries the sheen.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.9 : 0.7,
            ),
            scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.6 : 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(_FilterRow._shellRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.75 : 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.32 : 0.06),
            blurRadius: isDark ? 12 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / options.length;
          return Stack(
            // The thumb's glow is meant to spill into the shell's gutter.
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: instant,
                curve: Curves.easeOutCubic,
                left: index * slot,
                top: 0,
                bottom: 0,
                width: slot,
                child: AnimatedContainer(
                  duration: instant,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _FilterRow._chipStops(accent, isDark),
                    ),
                    borderRadius: BorderRadius.circular(
                      _FilterRow._thumbRadius,
                    ),
                    // The lit edge of the chip, so the shape has a shoulder to
                    // catch the light on rather than a coloured frame.
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.22 : 0.18,
                      ),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.42 : 0.3),
                        blurRadius: isDark ? 16 : 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final filter in options)
                    Expanded(
                      child: _FilterTab(
                        key: ValueKey(filter),
                        icon: _FilterRow.iconFor(filter),
                        label: filter.label,
                        tooltip: explain(filter),
                        count: counts[filter] ?? 0,
                        selected: filter == selected,
                        // A standing tab is inked in chip-white; one that is not
                        // keeps its own signal — danger for a late Overdue, muted
                        // for the rest.
                        ink: filter == selected
                            ? _FilterRow._onChip
                            : tintFor(filter),
                        instant: instant,
                        onTap: () => onPick(filter),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One tab of the filter bar: glyph, count badge, name and its own indicator
/// bar. It only wears the colour it is handed — chip-white when it stands, its
/// own signal otherwise — so the chip and the ink are decided in one place.
class _FilterTab extends StatelessWidget {
  const _FilterTab({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.count,
    required this.selected,
    required this.ink,
    required this.instant,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final int count;
  final bool selected;
  final Color ink;
  final Duration instant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The tab owns its tap: it sits on top of the page's own gestures.
        onTap: onTap,
        child: SizedBox(
          height: _FilterRow.height - _FilterRow._gap * 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 18, color: ink),
                  // The count is the visible proof that the tap did something,
                  // even when the list it controls is empty.
                  if (count > 0)
                    Positioned(
                      right: -9,
                      top: -6,
                      child: _CountBadge(
                        count: count,
                        selected: selected,
                        tint: ink,
                        instant: instant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  height: 1.1,
                  letterSpacing: 0.4,
                  color: ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              // The indicator bar. It collapses to nothing width rather than
              // fading, so the row never grows a ghost underline, and it fades
              // out at one end so it reads as a highlight, not a rule.
              AnimatedContainer(
                duration: instant,
                curve: Curves.easeOutCubic,
                width: selected ? 18 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [ink, ink.withValues(alpha: 0.45)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.selected,
    required this.tint,
    required this.instant,
  });

  final int count;
  final bool selected;
  final Color tint;
  final Duration instant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: instant,
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 3.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: selected ? 0.28 : 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: tint.withValues(alpha: selected ? 0.55 : 0.35),
          width: 1,
        ),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 8.5,
          height: 1.1,
          letterSpacing: 0,
          color: tint,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A group's title line: the day, the day's own bar stretched across the room the
/// name leaves, and 'done of total' at the right — the same shape the cards use
/// for their steps, so one reading works down the whole list.
///
/// The bar belongs to the day rather than to the list, so each group carries its
/// own. The Completed line is the exception: its cards come from more than one
/// day, so it keeps just the number, the divider above it and the fold handle.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.slices, this.tint})
    : count = null,
      open = null,
      onToggle = null,
      divided = false;

  const _SectionHeader.completed({
    required this.count,
    required this.open,
    required this.onToggle,
  }) : title = 'Completed',
       slices = const [],
       tint = null,
       divided = true;

  final String title;
  final List<TaskDaySlice> slices;

  /// Only on the Completed line, which has no bar to count from. Null on a day
  /// group, where the number is simply how many tasks the bar is drawn for.
  final int? count;
  final Color? tint;

  /// Only on the Completed line: whether its cards are showing, and the tap that
  /// changes it. Null leaves the heading plain text.
  final bool? open;
  final VoidCallback? onToggle;

  /// The hairline that separates the finished work from the day groups.
  final bool divided;

  /// A day's name is the only thing that competes with the bar for the line, and
  /// the longest form it takes ('WED, 31 DEC 2025') still fits this slot, so the
  /// bar is free to stretch across everything the name does not use.
  static const double _titleWidth = 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = tint ?? scheme.onSurfaceVariant;
    final total = count ?? slices.length;
    final done = slices.where((slice) => slice.done).length;
    final labelStyle = theme.textTheme.labelMedium;

    final name = Text(
      title.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: labelStyle?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );

    final line = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          if (count == null) ...[
            // The bar wears the whole space between the day and its number, so
            // the line reads as one instrument instead of a label with a chip
            // stranded at the right edge.
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _SectionHeader._titleWidth,
              ),
              child: name,
            ),
            const SizedBox(width: 12),
            Expanded(child: TaskProgressMeter(slices: slices)),
          ] else
            // The Completed line has no bar: its cards come from more than one
            // day, so only the name and how many of them there are.
            Expanded(child: name),
          const SizedBox(width: 10),
          // '1/3' is the same shape the cards use for their steps: finished of
          // what the day holds, the bar above it drawn from the same count.
          Text(
            count == null ? '$done/$total' : '$total',
            style: labelStyle?.copyWith(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onToggle != null) ...[
            const SizedBox(width: 8),
            // Same handle the cards use for their steps: point up when the
            // group is open, so one gesture reads the same all over the screen.
            AnimatedRotation(
              turns: open == true ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(Icons.expand_more, size: 20, color: color),
            ),
          ],
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divided) ...[
          Container(height: 1, color: scheme.onSurface.withValues(alpha: 0.09)),
          const SizedBox(height: 12),
        ],
        line,
      ],
    );

    final toggle = onToggle;
    if (toggle == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // The whole line answers the tap, not just the chevron.
        borderRadius: BorderRadius.circular(10),
        onTap: toggle,
        child: Tooltip(
          message: open == true ? 'Hide completed' : 'Show completed',
          child: content,
        ),
      ),
    );
  }
}

/// The quiet version of an empty list: a short note where the cards would be,
/// with the chips still above it.
class _NoDataNotice extends StatelessWidget {
  const _NoDataNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 11),
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
            ],
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 104),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            title,
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
