import 'package:habitbox/models/subtask.dart';
import 'package:habitbox/models/task.dart';
import 'package:habitbox/models/task_completion.dart';
import 'package:habitbox/models/task_occurrence_edit.dart';
import 'package:habitbox/repositories/task_repository.dart';
import 'package:habitbox/utils/date_key.dart';

/// An in-memory [TaskRepository] so dashboard, editor and controller tests never
/// need a real database (and the app's habit data is never touched).
///
/// It behaves like a small store: writes change the rows the next read returns,
/// so a test can assert on what a screen left behind rather than only on the
/// call it made. Every write is also recorded in the `*Calls` lists.
class FakeTaskRepository extends TaskRepository {
  FakeTaskRepository({
    List<Task> tasks = const [],
    List<Subtask> subtasks = const [],
    List<TaskCompletion> completions = const [],
    List<TaskOccurrenceEdit> occurrenceEdits = const [],
  }) : tasks = List<Task>.from(tasks),
       subtasks = List<Subtask>.from(subtasks),
       completions = List<TaskCompletion>.from(completions),
       occurrenceEdits = List<TaskOccurrenceEdit>.from(occurrenceEdits);

  final List<Task> tasks;
  final List<Subtask> subtasks;

  /// Mutable, because the dashboard writes to it through [setComplete].
  final List<TaskCompletion> completions;
  final List<TaskOccurrenceEdit> occurrenceEdits;

  /// Every (task id, day, wanted state) the UI asked for, oldest first.
  final List<(int, String, bool)> writes = [];

  /// Task rows as they were handed to each write.
  final List<Task> inserted = [];
  final List<Task> updated = [];
  final List<TaskOccurrenceEdit> editedOccurrences = [];
  final List<({int taskId, String fromDateKey, String childTitle})> splits = [];
  final List<({int taskId, String fromDateKey})> endedSeries = [];
  final List<int> trashed = [];
  final List<(String action, int subtaskId, String title)> subtaskCalls = [];
  final List<List<int>> reorders = [];

  /// Each day group the dashboard re-ranked, in the order the drags landed.
  final List<Map<int, int>> sortOrders = [];

  int _nextId = 900;

  /// Reads only return what the real repository would hand back: the whole
  /// store is kept, trash and all, but nothing in the trash is readable.
  bool _alive(int taskId) =>
      tasks.any((task) => task.id == taskId && task.deletedAt == null);

  @override
  Future<List<Task>> getTasks() async =>
      tasks.where((task) => task.deletedAt == null).toList();

  @override
  Future<List<Subtask>> getSubtasks() async =>
      subtasks.where((subtask) => _alive(subtask.taskId)).toList();

  @override
  Future<List<TaskCompletion>> getActiveCompletions() async =>
      completions.where((completion) => _alive(completion.taskId)).toList();

  @override
  Future<List<TaskOccurrenceEdit>> getOccurrenceEditsInRange(
    String startDateKey,
    String endDateKey,
  ) async => List<TaskOccurrenceEdit>.from(occurrenceEdits);

  @override
  Future<void> setComplete(
    int taskId,
    String dateKey, {
    required bool complete,
  }) async {
    writes.add((taskId, dateKey, complete));
    completions.removeWhere(
      (row) => row.taskId == taskId && row.dateKey == dateKey,
    );
    if (complete) {
      completions.add(
        TaskCompletion(
          taskId: taskId,
          dateKey: dateKey,
          completedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<int> insertTask(
    Task task, {
    List<String> subtaskTitles = const [],
  }) async {
    inserted.add(task);
    final id = _nextId++;
    tasks.add(task.copyWith(id: id));
    for (var position = 0; position < subtaskTitles.length; position++) {
      final subtask = Subtask(
        id: _nextId++,
        taskId: id,
        title: subtaskTitles[position],
        position: position,
      );
      subtasks.add(subtask);
      subtaskCalls.add(('inserted', subtask.id!, subtask.title));
    }
    return id;
  }

  @override
  Future<void> updateTask(Task task, {String? activityDetail}) async {
    updated.add(task);
    _replaceTask(task);
  }

  @override
  Future<void> setTaskSortOrders(Map<int, int> sortOrderById) async {
    sortOrders.add(Map<int, int>.from(sortOrderById));
    for (final entry in sortOrderById.entries) {
      final index = tasks.indexWhere((task) => task.id == entry.key);
      if (index == -1) continue;
      tasks[index] = tasks[index].copyWith(sortOrder: entry.value);
    }
  }

  @override
  Future<int> splitSeries({
    required Task original,
    required String fromDateKey,
    required Task child,
  }) async {
    splits.add((
      taskId: original.id!,
      fromDateKey: fromDateKey,
      childTitle: child.title,
    ));
    _replaceTask(
      original.copyWith(recurrenceUntilKey: _dayBefore(fromDateKey)),
    );
    final id = _nextId++;
    tasks.add(
      child.copyWith(
        id: id,
        parentTaskId: original.id,
        recurrenceStartKey: fromDateKey,
      ),
    );
    return id;
  }

  @override
  Future<void> endSeriesBefore(int taskId, String fromDateKey) async {
    endedSeries.add((taskId: taskId, fromDateKey: fromDateKey));
    final stored = tasks.firstWhere((task) => task.id == taskId);
    _replaceTask(stored.copyWith(recurrenceUntilKey: _dayBefore(fromDateKey)));
  }

  @override
  Future<void> softDeleteTask(int id) async {
    trashed.add(id);
    final stored = tasks.firstWhere((task) => task.id == id);
    _replaceTask(stored.copyWith(deletedAt: DateTime.now()));
  }

  @override
  Future<Subtask> addSubtask(int taskId, String title) async {
    final position = subtasks
        .where((subtask) => subtask.taskId == taskId)
        .length;
    final subtask = Subtask(
      id: _nextId++,
      taskId: taskId,
      title: title,
      position: position,
    );
    subtasks.add(subtask);
    subtaskCalls.add(('added', subtask.id!, title));
    return subtask;
  }

  @override
  Future<void> updateSubtask(Subtask subtask, {String? newTitle}) async {
    final title = newTitle ?? subtask.title;
    _replaceSubtask(subtask.copyWith(title: title));
    subtaskCalls.add(('renamed', subtask.id!, title));
  }

  @override
  Future<void> setSubtaskDone(Subtask subtask, bool done) async {
    _replaceSubtask(
      subtask.copyWith(done: done, completedAt: done ? DateTime.now() : null),
    );
    subtaskCalls.add((done ? 'done' : 'reopened', subtask.id!, subtask.title));
  }

  @override
  Future<void> deleteSubtask(Subtask subtask) async {
    subtasks.removeWhere((row) => row.id == subtask.id);
    subtaskCalls.add(('removed', subtask.id!, subtask.title));
  }

  @override
  Future<void> reorderSubtasks(int taskId, List<int> orderedIds) async {
    reorders.add(List<int>.from(orderedIds));
    for (var position = 0; position < orderedIds.length; position++) {
      final stored = subtasks.firstWhere(
        (subtask) => subtask.id == orderedIds[position],
      );
      _replaceSubtask(stored.copyWith(position: position));
    }
  }

  @override
  Future<void> upsertOccurrenceEdit(TaskOccurrenceEdit edit) async {
    editedOccurrences.add(edit);
    occurrenceEdits.removeWhere(
      (row) => row.taskId == edit.taskId && row.dateKey == edit.dateKey,
    );
    occurrenceEdits.add(edit);
  }

  void _replaceTask(Task task) {
    final index = tasks.indexWhere((row) => row.id == task.id);
    if (index == -1) return;
    tasks[index] = task;
  }

  void _replaceSubtask(Subtask subtask) {
    final index = subtasks.indexWhere((row) => row.id == subtask.id);
    if (index == -1) return;
    subtasks[index] = subtask;
  }

  static String _dayBefore(String dateKey) =>
      dateKeyFor(shiftDays(dateFromKey(dateKey), -1));
}

/// A task with the boilerplate filled in; tests only state what they assert.
Task newTask({
  required int id,
  required String title,
  String? description,
  String? dueDateKey,
  int? dueMinutesOfDay,
  TaskRecurrence recurrence = TaskRecurrence.none,
  int? recurrenceInterval,
  String? recurrenceStartKey,
  String? recurrenceUntilKey,
  int? parentTaskId,
  int? reminderLeadMinutes,
  bool archived = false,
  int sortOrder = 0,
  DateTime? createdAt,
}) {
  final stamp = createdAt ?? DateTime(2026, 10, 20, 8);
  return Task(
    id: id,
    title: title,
    description: description,
    dueDateKey: dueDateKey,
    dueMinutesOfDay: dueMinutesOfDay,
    recurrence: recurrence,
    recurrenceInterval: recurrenceInterval,
    recurrenceStartKey: recurrenceStartKey,
    recurrenceUntilKey: recurrenceUntilKey,
    parentTaskId: parentTaskId,
    reminderLeadMinutes: reminderLeadMinutes,
    createdAt: stamp,
    updatedAt: stamp,
    archived: archived,
    sortOrder: sortOrder,
  );
}

/// A step that already exists in the store, for the screens that edit them.
Subtask newSubtask({
  required int id,
  required int taskId,
  required String title,
  bool done = false,
  int position = 0,
}) => Subtask(
  id: id,
  taskId: taskId,
  title: title,
  done: done,
  position: position,
  completedAt: done ? DateTime(2026, 10, 21, 9) : null,
);

String get yesterdayKey => dateKeyFor(shiftDays(today, -1));

String get tomorrowKey => dateKeyFor(shiftDays(today, 1));

String get inThreeDaysKey => dateKeyFor(shiftDays(today, 3));

String get inFiveDaysKey => dateKeyFor(shiftDays(today, 5));
