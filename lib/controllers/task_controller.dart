import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_completion.dart';
import '../models/task_occurrence_edit.dart';
import '../repositories/task_repository.dart';
import '../utils/date_key.dart';
import '../utils/task_analytics.dart';

/// Which slice of the list the dashboard is showing.
///
/// Only [today] follows the date selector; the other three are always measured
/// from the real today, so the words on the chips mean the same thing wherever
/// the selector has been left.
///
/// The three open-work filters cut the same pile by time and never overlap:
/// [overdue] is what has already passed its moment, [pending] is today's open
/// work, [upcoming] is what is still ahead.
enum TaskListFilter {
  /// One day at a time: the day the selector is on, done tasks included.
  today('Today'),

  /// Still open and already past its due time, oldest day first.
  overdue('Overdue'),

  /// Still open today — or with no date to be late about — nothing that slipped.
  pending('Pending'),

  /// Everything still open after today.
  upcoming('Upcoming');

  const TaskListFilter(this.label);

  final String label;
}

/// One date section of the dashboard: the day it stands for and its tasks.
class TaskSection {
  const TaskSection({
    required this.dateKey,
    required this.past,
    required this.tasks,
  });

  /// The day this group holds, or null for the tasks that have no due date.
  final String? dateKey;

  /// True when the day has already gone by, so the heading can be tinted.
  final bool past;

  final List<Task> tasks;
}

/// One slice of the day bar: how far one task of the day got.
class TaskDaySlice {
  const TaskDaySlice({required this.done, required this.pastDue});

  final bool done;

  /// Open, but already past its due moment.
  final bool pastDue;
}

/// Which part of a recurring series an edit is saved to.
enum TaskEditScope {
  /// Store the differences for one day only; the series definition is untouched.
  occurrence(
    'Only this occurrence',
    'Everything else in the series keeps its current values.',
  ),

  /// Close the series before that day and continue it with a new row.
  future(
    'This and future occurrences',
    'Past days keep the values and history they already have.',
  ),

  /// Change the one row that defines the series.
  series('Entire series', 'Applies to every day, including the past.');

  const TaskEditScope(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// One row of the subtask editor. [existing] is the stored row when the task
/// already has that step, so its done state and position survive an edit; a
/// draft without one is a step the user is adding.
class SubtaskDraft {
  const SubtaskDraft({this.existing, this.title = ''});

  final Subtask? existing;
  final String title;
}

/// Loads tasks and the completion ledger from SQLite and answers every question
/// the dashboard asks, so the screens hold no logic of their own.
class TaskController extends GetxController {
  TaskController({TaskRepository? repository})
    : _repository = repository ?? TaskRepository();

  final TaskRepository _repository;

  final tasks = <Task>[].obs;
  final subtasks = <Subtask>[].obs;

  /// Every completion row of every task that is not in the trash. A day window
  /// is not enough here: an open task from last month is still overdue, and a
  /// completed one must never come back.
  final completions = <TaskCompletion>[].obs;

  /// Per-day overrides saved with [TaskEditScope.occurrence].
  final occurrenceEdits = <TaskOccurrenceEdit>[].obs;

  final isLoading = false.obs;
  final loadError = ''.obs;

  /// The day the dashboard is looking at. Sections are relative to it, so
  /// 'today' in a section heading really means this day.
  final selectedDateKey = todayDateKey.obs;

  final listFilter = TaskListFilter.today.obs;

  Set<String>? _completionIndex;
  Map<String, TaskOccurrenceEdit>? _editIndex;

  @override
  void onInit() {
    super.onInit();
    loadTasks();
  }

  Future<void> loadTasks() async {
    isLoading.value = true;
    loadError.value = '';
    try {
      final taskList = await _repository.getTasks();
      final subtaskList = await _repository.getSubtasks();
      final completionList = await _repository.getActiveCompletions();
      // The whole override ledger, not a window: the dashboard can move to any
      // day, and an occurrence edit has to apply there the same way.
      final editList = await _repository.getOccurrenceEditsInRange(
        '0000-01-01',
        '9999-12-31',
      );

      tasks.assignAll(taskList);
      subtasks.assignAll(subtaskList);
      completions.assignAll(completionList);
      occurrenceEdits.assignAll(editList);
      _completionIndex = null;
      _editIndex = null;
    } catch (e) {
      loadError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ----- Occurrences -----

  /// The day a task's status is recorded on. Recurring series get one row per
  /// day they cover; a single task belongs to its due date, or to the day it
  /// was created when it has no due date at all.
  String occurrenceKeyFor(Task task) =>
      task.dueDateKey ?? dateKeyFor(task.createdAt);

  /// The task as it stands on [dateKey]: the stored row with that day's saved
  /// overrides on top. A day with no override shows the series unchanged, which
  /// is what makes "only this occurrence" edits behave like a difference rather
  /// than a copy.
  Task effective(Task task, {String? dateKey}) {
    final id = task.id;
    if (id == null) return task;
    final index = _editIndex ??= {
      for (final edit in occurrenceEdits)
        '${edit.taskId}|${edit.dateKey}': edit,
    };
    final edit = index['$id|${dateKey ?? occurrenceKeyFor(task)}'];
    return edit == null ? task : edit.applyTo(task);
  }

  /// The row [id] stands for, seen from the day the dashboard is on.
  Task? taskById(int id) {
    final selected = selectedDateKey.value;
    for (final task in tasks) {
      if (task.id == id) return effective(task, dateKey: selected);
    }
    return null;
  }

  bool isComplete(Task task) => isCompleteOn(task, occurrenceKeyFor(task));

  /// Whether [task] is marked done on [dateKey], which is not necessarily the
  /// day the dashboard is on. The calendar asks this for every day it draws.
  bool isCompleteOn(Task task, String dateKey) {
    final id = task.id;
    if (id == null) return false;
    final index = _completionIndex ??= {
      for (final completion in completions)
        '${completion.taskId}|${completion.dateKey}',
    };
    return index.contains('$id|$dateKey');
  }

  /// The first day a series applies to. A row with no explicit anchor starts
  /// where its own due date says, or on the day it was made when it has none.
  String seriesStartKey(Task task) =>
      task.recurrenceStartKey ?? task.dueDateKey ?? dateKeyFor(task.createdAt);

  /// Whether [task] has an occurrence on [dateKey].
  ///
  /// A recurring row describes a whole series, so a day-by-day view has to ask
  /// this rather than read `due_date_key`, which only ever names the first day
  /// of the run.
  bool occursOn(Task task, String dateKey) {
    final start = seriesStartKey(task);
    if (dateKey.compareTo(start) < 0) return false;
    final until = task.recurrenceUntilKey;
    if (until != null && dateKey.compareTo(until) > 0) return false;
    return switch (task.recurrence) {
      TaskRecurrence.none => dateKey == start,
      TaskRecurrence.daily => true,
      TaskRecurrence.weekly => _dayGap(start, dateKey) % 7 == 0,
      TaskRecurrence.custom => _occursEvery(
        start,
        dateKey,
        task.recurrenceInterval,
      ),
      // Same day of the month as the anchor. A month without that day — the
      // 31st in February — is skipped rather than moved, so nothing claims a
      // date the series never promised.
      TaskRecurrence.monthly =>
        dateFromKey(dateKey).day == dateFromKey(start).day,
    };
  }

  static bool _occursEvery(String start, String dateKey, int? interval) {
    final gap = interval ?? 1;
    if (gap <= 1) return true;
    return _dayGap(start, dateKey) % gap == 0;
  }

  static int _dayGap(String fromKey, String toKey) =>
      daysBetween(dateFromKey(fromKey), dateFromKey(toKey));

  /// Every task that has an occurrence on [dateKey], each one seen from that
  /// day so a saved per-day override shows there and nowhere else.
  List<Task> tasksOn(String dateKey) {
    final result = <Task>[
      for (final stored in tasks)
        if (!stored.archived && occursOn(stored, dateKey))
          effective(stored, dateKey: dateKey),
    ]..sort(_compareWithinDay);
    return result;
  }

  /// Tasks with no due date at all: they belong to no day on the calendar, so
  /// a day view has to hand them over separately.
  List<Task> get undatedTasks {
    final result = <Task>[
      for (final stored in tasks)
        if (!stored.archived &&
            stored.dueDateKey == null &&
            stored.deletedAt == null)
          effective(stored, dateKey: occurrenceKeyFor(stored)),
    ]..sort(_compareWithinDay);
    return result;
  }

  /// Past its due moment and still open. A task with no due date never is.
  bool isOverdue(Task task) =>
      !isComplete(task) && task.isOverdue(DateTime.now());

  bool hasReminder(Task task) => task.reminderLeadMinutes != null;

  // ----- Related rows -----

  Map<int, List<Subtask>> get subtaskIndex {
    final index = <int, List<Subtask>>{};
    for (final subtask in subtasks) {
      index.putIfAbsent(subtask.taskId, () => []).add(subtask);
    }
    for (final list in index.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }
    return index;
  }

  List<Subtask> subtasksFor(Task task) =>
      task.id == null ? const [] : subtaskIndex[task.id] ?? const [];

  int subtasksDone(Task task) =>
      subtasksFor(task).where((subtask) => subtask.done).length;

  // ----- What the dashboard shows -----

  /// The day groups to draw for the current filter, the day closest to today
  /// first.
  ///
  /// Overdue leads with yesterday and lets the older slips fall below it;
  /// Upcoming leads with tomorrow and lets the further days fall below it. The
  /// undated tasks always come last under 'Anytime', so no open task can hide
  /// from a filter. A task that is already marked done is not here at all —
  /// [completedTasks] collects those for the group at the bottom of the list.
  List<TaskSection> get sections {
    final selected = selectedDateKey.value;
    final today = todayDateKey;
    final filter = listFilter.value;
    final byDay = <String, List<Task>>{};
    final anytime = <Task>[];

    for (final task in _currentView) {
      if (isComplete(task)) continue;
      if (!_qualifies(task, filter, selected: selected, today: today)) continue;
      final due = task.dueDateKey;
      if (due == null && filter != TaskListFilter.today) {
        anytime.add(task);
      } else {
        byDay.putIfAbsent(occurrenceKeyFor(task), () => <Task>[]).add(task);
      }
    }

    final days = byDay.keys.toList()..sort(_compareDays);
    for (final list in byDay.values) {
      list.sort(_compareWithinDay);
    }
    anytime.sort(_compareWithinDay);
    return [
      for (final day in days)
        TaskSection(
          dateKey: day,
          past: day.compareTo(today) < 0,
          tasks: byDay[day]!,
        ),
      if (anytime.isNotEmpty)
        TaskSection(dateKey: null, past: false, tasks: anytime),
    ];
  }

  /// The tasks of the current filter that are already marked done.
  ///
  /// Only the day view can hold any: the other three are measured as open work,
  /// so this is empty there and the list shows no Completed group.
  List<Task> get completedTasks {
    final selected = selectedDateKey.value;
    final today = todayDateKey;
    final filter = listFilter.value;
    final result = <Task>[
      for (final task in _currentView)
        if (isComplete(task) &&
            _qualifies(task, filter, selected: selected, today: today))
          task,
    ]..sort(_compareDaysAcrossGroups);
    return result;
  }

  /// Whether the Completed group shows its cards. A view choice, so it lives
  /// here rather than in SQLite, and the dashboard keeps it while the user
  /// moves between the filters.
  final completedOpen = true.obs;

  void toggleCompleted() => completedOpen.value = !completedOpen.value;

  /// Every task the dashboard may show, read through the overrides saved for
  /// the day it belongs to. An override is that day's version of the series, so
  /// looking it up with whichever day the selector is on would show yesterday's
  /// edit on today's card.
  List<Task> get _currentView {
    final result = <Task>[];
    for (final stored in tasks) {
      if (stored.archived) continue;
      result.add(effective(stored, dateKey: occurrenceKeyFor(stored)));
    }
    return result;
  }

  /// The one rule that decides what a filter shows, so the counts on the chips
  /// and the list under them can never disagree.
  bool _qualifies(
    Task task,
    TaskListFilter filter, {
    required String selected,
    required String today,
  }) {
    final due = task.dueDateKey;
    return switch (filter) {
      TaskListFilter.today => occurrenceKeyFor(task) == selected,
      // isOverdue already means 'still open', so nothing done can settle here.
      TaskListFilter.overdue => isOverdue(task),
      TaskListFilter.pending =>
        !isComplete(task) &&
            !isOverdue(task) &&
            (due == null || due.compareTo(today) <= 0),
      TaskListFilter.upcoming =>
        !isComplete(task) && due != null && due.compareTo(today) > 0,
    };
  }

  /// How many tasks each chip holds right now, in one pass, so the numbers on
  /// the chips and the list under them can never disagree.
  Map<TaskListFilter, int> get filterCounts {
    final selected = selectedDateKey.value;
    final today = todayDateKey;
    final counts = {for (final f in TaskListFilter.values) f: 0};
    for (final task in _currentView) {
      for (final filter in TaskListFilter.values) {
        if (_qualifies(task, filter, selected: selected, today: today)) {
          counts[filter] = counts[filter]! + 1;
        }
      }
    }
    return counts;
  }

  /// The day nearest today leads, whichever side of today it sits on, so a
  /// filter opens with the work that is closest rather than with a month-old
  /// slip. Two days equidistant from today put the one already past first.
  int _compareDays(String a, String b) {
    final byCloseness = daysBetween(
      today,
      dateFromKey(a),
    ).abs().compareTo(daysBetween(today, dateFromKey(b)).abs());
    if (byCloseness != 0) return byCloseness;
    return a.compareTo(b);
  }

  /// Inside one day the user's own order leads: a drag is them saying where a
  /// task sits. Then the earliest due time, and an untimed task joins the end of
  /// the day. Two tasks nobody has ordered yet keep the time order they had.
  int _compareWithinDay(Task a, Task b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    final byTime = (a.dueMinutesOfDay ?? 1440).compareTo(
      b.dueMinutesOfDay ?? 1440,
    );
    if (byTime != 0) return byTime;
    return a.title.compareTo(b.title);
  }

  /// For the Completed group, whose cards can come from more than one day: the
  /// day closest to today first, then that day's own order.
  int _compareDaysAcrossGroups(Task a, Task b) {
    final byDay = _compareDays(occurrenceKeyFor(a), occurrenceKeyFor(b));
    if (byDay != 0) return byDay;
    return _compareWithinDay(a, b);
  }

  int get overdueCount => _currentView.where(isOverdue).length;

  bool get hasAnyTask => tasks.any((task) => !task.archived);

  // ----- Statistics -----

  /// Everything the statistics screen draws, counted over the last
  /// [windowDays] days.
  ///
  /// The record comes from the completion ledger rather than the day the
  /// dashboard happens to be on, so a finish is filed against the day it
  /// belongs to and an old slip stays where it fell. Rows of archived or
  /// trashed tasks are left out: a task the list no longer shows cannot add to
  /// a record.
  TaskStats taskStats({required int windowDays}) {
    final todayKey = todayDateKey;
    final view = _currentView;
    final alive = <int>{
      for (final task in view)
        if (task.id != null) task.id!,
    };

    final window = <String>[
      for (final date in lastNDays(windowDays)) dateKeyFor(date),
    ];
    final firstOfWindow = window.first;
    // The window of the same length that sits directly before this one, which
    // is what the 'change' line compares against.
    final before = shiftDays(today, -windowDays);
    final lastOfPrevious = dateKeyFor(before);
    final firstOfPrevious = dateKeyFor(shiftDays(before, -(windowDays - 1)));

    final perDay = <String, int>{};
    final doneDays = <String>{};
    var previousCompleted = 0;
    for (final completion in completions) {
      if (!alive.contains(completion.taskId)) continue;
      final key = completion.dateKey;
      doneDays.add(key);
      if (key.compareTo(firstOfWindow) >= 0 && key.compareTo(todayKey) <= 0) {
        perDay[key] = (perDay[key] ?? 0) + 1;
      } else if (key.compareTo(firstOfPrevious) >= 0 &&
          key.compareTo(lastOfPrevious) <= 0) {
        previousCompleted++;
      }
    }

    // What each day of the window promised. A series is asked day by day,
    // because `due_date_key` only ever names its first day.
    final carried = <String, int>{for (final key in window) key: 0};
    for (final task in view) {
      for (final key in window) {
        if (occursOn(task, key)) carried[key] = carried[key]! + 1;
      }
    }

    final days = <TaskStatDay>[];
    for (final key in window) {
      final done = perDay[key] ?? 0;
      final carriedCount = carried[key]!;
      days.add(
        TaskStatDay(
          dateKey: key,
          date: dateFromKey(key),
          // A finish can outlive the rule that put it there — the recurrence
          // edited afterwards, a day the series no longer visits — so the day
          // keeps the taller of the two. Otherwise the bar would be filled past
          // its own height.
          total: done > carriedCount ? done : carriedCount,
          completed: done,
        ),
      );
    }

    var completed = 0;
    TaskStatDay? bestDay;
    final byWeekday = <int, int>{};
    for (final day in days) {
      completed += day.completed;
      if (day.completed == 0) continue;
      byWeekday[day.date.weekday] =
          (byWeekday[day.date.weekday] ?? 0) + day.completed;
      if (bestDay == null || day.completed > bestDay.completed) bestDay = day;
    }

    var busiestWeekday = 0;
    var busiestCount = 0;
    for (final entry in byWeekday.entries) {
      if (entry.value > busiestCount) {
        busiestWeekday = entry.key;
        busiestCount = entry.value;
      }
    }

    // Today still being open does not end a run that carried on into it, so a
    // streak may start at yesterday; the walk stops at the first blank day.
    var streak = 0;
    var cursor = todayKey;
    if (!doneDays.contains(cursor)) {
      cursor = dateKeyFor(shiftDays(today, -1));
    }
    while (doneDays.contains(cursor)) {
      streak++;
      cursor = dateKeyFor(shiftDays(dateFromKey(cursor), -1));
    }

    var slipped = 0;
    var dueToday = 0;
    var later = 0;
    var undated = 0;
    var finishedToday = 0;
    for (final task in view) {
      final key = occurrenceKeyFor(task);
      if (isComplete(task)) {
        if (key == todayKey) finishedToday++;
        continue;
      }
      // isOverdue already means 'still open', so nothing finished can settle
      // in the past-due line.
      if (isOverdue(task)) {
        slipped++;
      } else if (task.dueDateKey == null) {
        undated++;
      } else if (key.compareTo(todayKey) > 0) {
        later++;
      } else {
        dueToday++;
      }
    }

    var stepsTotal = 0;
    var stepsDone = 0;
    for (final step in subtasks) {
      if (!alive.contains(step.taskId)) continue;
      stepsTotal++;
      if (step.done) stepsDone++;
    }

    return TaskStats(
      windowDays: windowDays,
      days: days,
      completed: completed,
      previousCompleted: previousCompleted,
      streak: streak,
      activeDays: perDay.length,
      bestDay: bestDay,
      busiestWeekday: busiestWeekday,
      busiestCount: busiestCount,
      buckets: [
        TaskBucket(
          kind: TaskBucketKind.slipped,
          label: 'Past due',
          count: slipped,
        ),
        TaskBucket(
          kind: TaskBucketKind.dueToday,
          label: 'Open today',
          count: dueToday,
        ),
        TaskBucket(
          kind: TaskBucketKind.later,
          label: 'Coming up',
          count: later,
        ),
        TaskBucket(
          kind: TaskBucketKind.undated,
          label: 'No date set',
          count: undated,
        ),
        TaskBucket(
          kind: TaskBucketKind.doneToday,
          label: 'Done today',
          count: finishedToday,
        ),
      ],
      stepsDone: stepsDone,
      stepsTotal: stepsTotal,
      taskCount: view.length,
    );
  }

  // ----- Navigation and filters -----

  /// A tap on the calendar means "show me that day", which is the day view — so
  /// it takes the filter along with it instead of moving a boundary the user
  /// cannot see, which is what made the list look like it was not responding.
  void selectDate(String dateKey) {
    selectedDateKey.value = dateKey;
    listFilter.value = TaskListFilter.today;
  }

  /// The Today chip always means the real today, so it moves the day the list is
  /// on back along with it.
  void setListFilter(TaskListFilter filter) {
    if (filter == TaskListFilter.today) selectedDateKey.value = todayDateKey;
    listFilter.value = filter;
  }

  // ----- Writes -----

  /// Marks the selected day's occurrence done, or reopens it. Only the ledger
  /// row changes, so other days of the same task keep their own status.
  Future<void> toggleComplete(Task task, {String? dateKey}) async {
    final id = task.id;
    if (id == null) return;
    // Every mark path funnels through here, so the confirmation buzz belongs at
    // this level (same as the habit controller).
    HapticFeedback.vibrate();
    final key = dateKey ?? occurrenceKeyFor(task);
    final done = isComplete(task);
    await _repository.setComplete(id, key, complete: !done);
    if (done) {
      completions.removeWhere(
        (completion) => completion.taskId == id && completion.dateKey == key,
      );
    } else {
      completions.add(
        TaskCompletion(taskId: id, dateKey: key, completedAt: DateTime.now()),
      );
    }
    _completionIndex = null;
    completions.refresh();
    tasks.refresh();
  }

  /// Moves [moved] within the day group it was drawn under and saves that order.
  ///
  /// [dateKey] is the group's day (null for 'Anytime') and [newIndex] counts the
  /// group's *other* cards, which is what a drag hands over: the slot the card
  /// was dropped into. The group is then re-ranked 0..n-1, so no other day moves
  /// and no card can leave its day — the day comes from the due date, not from
  /// the list, so a drop aimed at another group lands at the end of its own.
  Future<void> moveTask(Task moved, String? dateKey, int newIndex) async {
    final id = moved.id;
    if (id == null) return;
    final group = <Task>[
      for (final section in sections)
        if (section.dateKey == dateKey) ...section.tasks,
    ];
    final old = group.indexWhere((task) => task.id == id);
    if (old == -1 || group.length < 2) return;
    final ordered = List<Task>.from(group)..removeAt(old);
    final to = newIndex.clamp(0, ordered.length);
    // The slot the card already holds: a drop that changes nothing must not
    // rewrite the day or buzz.
    if (to == old) return;
    ordered.insert(to, moved);
    final changes = <int, int>{};
    for (var i = 0; i < ordered.length; i++) {
      final taskId = ordered[i].id;
      if (taskId != null && ordered[i].sortOrder != i) changes[taskId] = i;
    }
    if (changes.isEmpty) return;
    HapticFeedback.vibrate();
    await _repository.setTaskSortOrders(changes);
    // Repaint from the new order without asking SQLite again: only the position
    // changed.
    for (var i = 0; i < ordered.length; i++) {
      final index = tasks.indexWhere((task) => task.id == ordered[i].id);
      if (index == -1) continue;
      tasks[index] = tasks[index].copyWith(sortOrder: i);
    }
    tasks.refresh();
  }

  /// Adds a task together with the steps typed for it, then reloads so the
  /// meter, the calendar and the groups all pick it up.
  Future<void> createTask(
    Task draft, {
    List<String> subtaskTitles = const [],
  }) async {
    HapticFeedback.vibrate();
    await _repository.insertTask(
      draft,
      subtaskTitles: _cleanTitles(subtaskTitles),
    );
    await loadTasks();
  }

  /// Creates the same task on several days: one row per day, each with the
  /// notes, time and steps of [template].
  ///
  /// They are deliberately separate rows rather than one series — a date picked
  /// here is a date the user asked for, not a rule that repeats forever, and
  /// marking one of them done leaves the others untouched.
  Future<void> createTaskOnDays({
    required Task template,
    required List<String> dateKeys,
    List<String> subtaskTitles = const [],
  }) async {
    if (dateKeys.isEmpty) {
      await createTask(template, subtaskTitles: subtaskTitles);
      return;
    }
    HapticFeedback.vibrate();
    final titles = _cleanTitles(subtaskTitles);
    for (final dateKey in dateKeys) {
      await _repository.insertTask(
        template.copyWith(dueDateKey: dateKey),
        subtaskTitles: titles,
      );
    }
    await loadTasks();
  }

  /// Saves [draft] under [scope], which is how the editor tells the controller
  /// how much of a recurring series the change belongs to.
  ///
  /// These are the three scopes the schema can really honour: an occurrence
  /// stores only its differences, a future split closes the old series the day
  /// before and starts a new row, and the series scope rewrites the one row that
  /// defines it. Completions are keyed by (task, day), so no scope moves history.
  Future<void> saveTask(
    Task draft, {
    TaskEditScope scope = TaskEditScope.series,
    String? occurrenceKey,
    List<SubtaskDraft> subtasks = const [],
  }) async {
    final id = draft.id;
    if (id == null) {
      await createTask(
        draft,
        subtaskTitles: [for (final draftRow in subtasks) draftRow.title],
      );
      return;
    }
    HapticFeedback.vibrate();
    final day = occurrenceKey ?? occurrenceKeyFor(draft);
    switch (scope) {
      case TaskEditScope.series:
        await _repository.updateTask(draft);
        await _syncSubtasks(draft, subtasks);
      case TaskEditScope.occurrence:
        final edit = _differenceFor(draft, day);
        if (edit != null) await _repository.upsertOccurrenceEdit(edit);
      case TaskEditScope.future:
        await _repository.splitSeries(
          original: draft,
          fromDateKey: day,
          child: draft,
        );
    }
    await loadTasks();
  }

  /// The stored row [id] stands for, before any occurrence override.
  Task? storedTask(int id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// Only the fields the edit actually changed, so every other one keeps
  /// inheriting the series value. A field cleared to nothing cannot be stored
  /// as an override (null means "inherit"), so it falls back to the series.
  /// Returns null when the occurrence would override nothing.
  TaskOccurrenceEdit? _differenceFor(Task edited, String dateKey) {
    final base = edited.id == null ? null : storedTask(edited.id!);
    if (base == null) return null;
    String? changed(String? editedValue, String? baseValue) =>
        editedValue == baseValue ? null : editedValue;
    final edit = TaskOccurrenceEdit(
      taskId: base.id!,
      dateKey: dateKey,
      title: changed(edited.title, base.title),
      description: changed(
        _blankToNull(edited.description),
        _blankToNull(base.description),
      ),
      dueDateKey: changed(edited.dueDateKey, base.dueDateKey),
      dueMinutesOfDay: edited.dueMinutesOfDay == base.dueMinutesOfDay
          ? null
          : edited.dueMinutesOfDay,
      reminderLeadMinutes:
          edited.reminderLeadMinutes == base.reminderLeadMinutes
          ? null
          : edited.reminderLeadMinutes,
      editedAt: DateTime.now(),
    );
    final overridesAnything =
        edit.title != null ||
        edit.description != null ||
        edit.dueDateKey != null ||
        edit.dueMinutesOfDay != null ||
        edit.reminderLeadMinutes != null;
    return overridesAnything ? edit : null;
  }

  /// Makes the stored subtasks match the editor's rows without touching the
  /// ones that did not change, so a completed step keeps its done state.
  Future<void> _syncSubtasks(Task task, List<SubtaskDraft> drafts) async {
    final id = task.id;
    if (id == null) return;
    final orderedIds = <int>[];
    for (final draft in drafts) {
      final title = draft.title.trim();
      final existing = draft.existing;
      if (existing == null) {
        if (title.isEmpty) continue;
        final added = await _repository.addSubtask(id, title);
        final addedId = added.id;
        if (addedId != null) orderedIds.add(addedId);
        continue;
      }
      final existingId = existing.id;
      if (existingId == null || title.isEmpty) continue;
      if (existing.title != title) {
        await _repository.updateSubtask(existing, newTitle: title);
      }
      orderedIds.add(existingId);
    }
    for (final stored in subtasksFor(task)) {
      final storedId = stored.id;
      if (storedId != null && !orderedIds.contains(storedId)) {
        await _repository.deleteSubtask(stored);
      }
    }
    await _repository.reorderSubtasks(id, orderedIds);
  }

  static List<String> _cleanTitles(Iterable<String> titles) => [
    for (final title in titles)
      if (title.trim().isNotEmpty) title.trim(),
  ];

  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  // ----- Subtasks, from the details screen -----

  Future<void> addSubtask(Task task, String title) async {
    final id = task.id;
    final text = title.trim();
    if (id == null || text.isEmpty) return;
    HapticFeedback.vibrate();
    subtasks.add(await _repository.addSubtask(id, text));
    subtasks.refresh();
  }

  Future<void> renameSubtask(Subtask subtask, String title) async {
    final id = subtask.id;
    final text = title.trim();
    if (id == null || text.isEmpty || subtask.title == text) return;
    await _repository.updateSubtask(subtask, newTitle: text);
    _replaceSubtask(subtask.copyWith(title: text));
  }

  Future<void> toggleSubtask(Subtask subtask) async {
    final id = subtask.id;
    if (id == null) return;
    HapticFeedback.vibrate();
    final done = !subtask.done;
    await _repository.setSubtaskDone(subtask, done);
    _replaceSubtask(
      subtask.copyWith(done: done, completedAt: done ? DateTime.now() : null),
    );
  }

  Future<void> removeSubtask(Subtask subtask) async {
    if (subtask.id == null) return;
    await _repository.deleteSubtask(subtask);
    subtasks.removeWhere((row) => row.id == subtask.id);
    subtasks.refresh();
  }

  void _replaceSubtask(Subtask updated) {
    final index = subtasks.indexWhere((row) => row.id == updated.id);
    if (index == -1) return;
    subtasks[index] = updated;
    subtasks.refresh();
  }

  // ----- Deleting -----

  /// Moves the task to the trash. Its subtasks, completions and history stay in
  /// the database, so the recovery screen can bring the task back intact.
  Future<void> deleteTask(int id) async {
    HapticFeedback.vibrate();
    await _repository.softDeleteTask(id);
    await loadTasks();
  }

  /// Stops a recurring series the day before [fromDateKey] and keeps everything
  /// up to that day — the deletion scope that does not remove any history.
  Future<void> endSeriesBefore(int id, String fromDateKey) async {
    HapticFeedback.vibrate();
    await _repository.endSeriesBefore(id, fromDateKey);
    await loadTasks();
  }
}
