import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_activity.dart';
import '../models/task_completion.dart';
import '../models/task_occurrence_edit.dart';
import '../utils/date_key.dart';

/// All SQLite reads/writes for tasks and their child tables.
///
/// Nothing here touches the habit tables. Multi-step writes run inside a
/// transaction or a batch (which sqflite commits transactionally), so a state
/// change and its history row can never be applied separately.
///
/// The `task_categories` table and the `priority` / `category_id` columns are
/// still created but no longer read or written — dropping them would mean a
/// migration, and the schema is deliberately left alone so existing data stays.
class TaskRepository {
  TaskRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<Database> get _db => _dbHelper.database;

  // ----- Tasks -----

  /// Everything not in the trash, soonest due first. Archived tasks are
  /// included so the controller can split them out without another query.
  Future<List<Task>> getTasks() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTasks,
      where: 'deleted_at IS NULL',
      orderBy:
          'due_date_key IS NULL, due_date_key ASC, due_time_minutes ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getTask(int id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTasks,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  /// Tasks due inside a day window — the calendar's per-date list.
  Future<List<Task>> getTasksDueBetween(
    String startDateKey,
    String endDateKey,
  ) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTasks,
      where:
          'deleted_at IS NULL AND due_date_key IS NOT NULL '
          'AND due_date_key BETWEEN ? AND ?',
      whereArgs: [startDateKey, endDateKey],
      orderBy: 'due_date_key ASC, due_time_minutes ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getTrashedTasks() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTasks,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  /// Creates the task together with its subtasks and its first history row.
  ///
  /// `sort_order` is stamped here rather than trusted from [task]: the next
  /// value after every row already stored, which lands the new task at the end
  /// of its own day.
  Future<int> insertTask(
    Task task, {
    List<String> subtaskTitles = const [],
  }) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await txn.insert(
        DatabaseHelper.tableTasks,
        task.copyWith(sortOrder: await _nextSortOrder(txn)).toMap(),
      );
      for (var i = 0; i < subtaskTitles.length; i++) {
        await txn.insert(
          DatabaseHelper.tableSubtasks,
          Subtask(taskId: id, title: subtaskTitles[i], position: i).toMap(),
        );
      }
      await txn.insert(
        DatabaseHelper.tableTaskActivities,
        TaskActivity(
          taskId: id,
          kind: TaskActivityKind.created,
          createdAt: DateTime.now(),
        ).toMap(),
      );
      return id;
    });
  }

  /// Writes the full row, so a field the user cleared really becomes NULL, and
  /// stamps `updated_at` regardless of what the caller passed.
  ///
  /// `sort_order` is left out on purpose: editing what a task *says* must never
  /// move where it sits in its day, and [setTaskSortOrders] is the only writer
  /// of the column.
  Future<void> updateTask(Task task, {String? activityDetail}) async {
    final id = task.id;
    if (id == null) {
      throw ArgumentError('Task must have an id to be updated.');
    }
    final db = await _db;
    final now = DateTime.now();
    final changes = task.copyWith(updatedAt: now).toMap()..remove('sort_order');
    final batch = db.batch();
    batch.update(
      DatabaseHelper.tableTasks,
      changes,
      where: 'id = ?',
      whereArgs: [id],
    );
    batch.insert(
      DatabaseHelper.tableTaskActivities,
      TaskActivity(
        taskId: id,
        kind: TaskActivityKind.edited,
        detail: activityDetail,
        createdAt: now,
      ).toMap(),
    );
    await batch.commit(noResult: true);
  }

  /// Saves a new order for the rows in [sortOrderById] (task id -> position).
  ///
  /// One batch, and no history row: where a card sits in a day is not a change
  /// to the task itself.
  Future<void> setTaskSortOrders(Map<int, int> sortOrderById) async {
    if (sortOrderById.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final entry in sortOrderById.entries) {
      batch.update(
        DatabaseHelper.tableTasks,
        {'sort_order': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
  }

  /// The value one above every task already stored, so a new row joins the end
  /// of its day. Reads through [txn] because both callers are inside a
  /// transaction and must see their own uncommitted writes.
  Future<int> _nextSortOrder(Transaction txn) async {
    final rows = await txn.query(
      DatabaseHelper.tableTasks,
      columns: ['MAX(sort_order) AS next_order'],
    );
    return ((rows.first['next_order'] as int?) ?? -1) + 1;
  }

  /// Closes a recurring series the day before [fromDateKey] and starts [child]
  /// from that day onwards, so an edit to "this and future occurrences" never
  /// rewrites history. Both rows are written in one transaction.
  ///
  /// Completions, subtasks and activity stay with the series they belong to:
  /// [original] keeps everything it earned up to the split and [child] starts
  /// clean.
  Future<int> splitSeries({
    required Task original,
    required String fromDateKey,
    required Task child,
  }) async {
    final originalId = original.id;
    if (originalId == null) {
      throw ArgumentError('Task must have an id to be split.');
    }
    final db = await _db;
    final now = DateTime.now();
    // recurrence_until_key is the last day the series applies to.
    final lastOldDay = dateKeyFor(shiftDays(dateFromKey(fromDateKey), -1));

    return db.transaction((txn) async {
      await txn.update(
        DatabaseHelper.tableTasks,
        {
          'recurrence_until_key': lastOldDay,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [originalId],
      );
      final childId = await txn.insert(
        DatabaseHelper.tableTasks,
        child
            .copyWith(
              parentTaskId: originalId,
              recurrenceStartKey: fromDateKey,
              createdAt: now,
              updatedAt: now,
              // Same rule as insertTask: a new row joins the end of its day.
              sortOrder: await _nextSortOrder(txn),
            )
            .toMap(),
      );
      await txn.insert(
        DatabaseHelper.tableTaskActivities,
        TaskActivity(
          taskId: originalId,
          kind: TaskActivityKind.edited,
          dateKey: lastOldDay,
          detail: 'Series continues from $fromDateKey',
          createdAt: now,
        ).toMap(),
      );
      await txn.insert(
        DatabaseHelper.tableTaskActivities,
        TaskActivity(
          taskId: childId,
          kind: TaskActivityKind.created,
          dateKey: fromDateKey,
          detail: 'Split from series $originalId',
          createdAt: now,
        ).toMap(),
      );
      return childId;
    });
  }

  /// Stops a recurring series the day before [fromDateKey]. Occurrences that
  /// already happened — and their completions — stay exactly as they were.
  Future<void> endSeriesBefore(int taskId, String fromDateKey) async {
    final lastDay = dateKeyFor(shiftDays(dateFromKey(fromDateKey), -1));
    await _setStatus(
      taskId,
      {'recurrence_until_key': lastDay},
      TaskActivityKind.edited,
      detail: 'Series ends after $lastDay',
    );
  }

  Future<void> setArchived(int id, bool archived) async {
    await _setStatus(id, {
      'archived': archived ? 1 : 0,
    }, archived ? TaskActivityKind.archived : TaskActivityKind.restored);
  }

  /// Moves the task to the trash; its rows stay, so it can be restored.
  Future<void> softDeleteTask(int id) async {
    await _setStatus(
      id,
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      TaskActivityKind.archived,
      detail: 'Moved to trash',
    );
  }

  Future<void> restoreTask(int id) async {
    await _setStatus(id, {'deleted_at': null}, TaskActivityKind.restored);
  }

  /// Permanent removal. ON DELETE CASCADE drops the subtasks, completions,
  /// occurrence edits and history rows that belong to it.
  Future<int> deleteTask(int id) async {
    final db = await _db;
    return db.delete(
      DatabaseHelper.tableTasks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _setStatus(
    int id,
    Map<String, Object?> changes,
    TaskActivityKind kind, {
    String? detail,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    changes['updated_at'] = now.millisecondsSinceEpoch;
    final batch = db.batch();
    batch.update(
      DatabaseHelper.tableTasks,
      changes,
      where: 'id = ?',
      whereArgs: [id],
    );
    batch.insert(
      DatabaseHelper.tableTaskActivities,
      TaskActivity(
        taskId: id,
        kind: kind,
        detail: detail,
        createdAt: now,
      ).toMap(),
    );
    await batch.commit(noResult: true);
  }

  // ----- Completions -----

  /// One row per (task, day), so a recurring series keeps a separate status for
  /// every occurrence it has had.
  Future<void> setComplete(
    int taskId,
    String dateKey, {
    required bool complete,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final batch = db.batch();
    if (complete) {
      batch.insert(
        DatabaseHelper.tableTaskCompletions,
        TaskCompletion(
          taskId: taskId,
          dateKey: dateKey,
          completedAt: now,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      batch.delete(
        DatabaseHelper.tableTaskCompletions,
        where: 'task_id = ? AND date_key = ?',
        whereArgs: [taskId, dateKey],
      );
    }
    batch.update(
      DatabaseHelper.tableTasks,
      {'updated_at': now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [taskId],
    );
    batch.insert(
      DatabaseHelper.tableTaskActivities,
      TaskActivity(
        taskId: taskId,
        kind: complete ? TaskActivityKind.completed : TaskActivityKind.reopened,
        dateKey: dateKey,
        createdAt: now,
      ).toMap(),
    );
    await batch.commit(noResult: true);
  }

  /// Completion rows of every task that is not in the trash. The dashboard
  /// needs the whole ledger rather than a day window, because an open task from
  /// months ago is still overdue and a completed one must not come back.
  Future<List<TaskCompletion>> getActiveCompletions() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT c.* FROM ${DatabaseHelper.tableTaskCompletions} c '
      'JOIN ${DatabaseHelper.tableTasks} t ON t.id = c.task_id '
      'WHERE t.deleted_at IS NULL',
    );
    return rows.map(TaskCompletion.fromMap).toList();
  }

  Future<List<TaskCompletion>> getCompletionsInRange(
    String startDateKey,
    String endDateKey,
  ) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTaskCompletions,
      where: 'date_key BETWEEN ? AND ?',
      whereArgs: [startDateKey, endDateKey],
    );
    return rows.map(TaskCompletion.fromMap).toList();
  }

  Future<List<TaskCompletion>> getCompletionsForTask(int taskId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTaskCompletions,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'date_key ASC',
    );
    return rows.map(TaskCompletion.fromMap).toList();
  }

  // ----- Subtasks -----

  /// Subtasks of every task that is not in the trash, in display order. Loaded
  /// in one query so the dashboard can show progress without an N+1 loop.
  Future<List<Subtask>> getSubtasks() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT s.* FROM ${DatabaseHelper.tableSubtasks} s '
      'JOIN ${DatabaseHelper.tableTasks} t ON t.id = s.task_id '
      'WHERE t.deleted_at IS NULL '
      'ORDER BY s.task_id ASC, s.position ASC',
    );
    return rows.map(Subtask.fromMap).toList();
  }

  Future<Subtask> addSubtask(int taskId, String title) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableSubtasks,
      columns: ['MAX(position) AS max_position'],
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    final position = ((rows.first['max_position'] as int?) ?? -1) + 1;
    final id = await db.insert(
      DatabaseHelper.tableSubtasks,
      Subtask(taskId: taskId, title: title, position: position).toMap(),
    );
    await db.insert(
      DatabaseHelper.tableTaskActivities,
      TaskActivity(
        taskId: taskId,
        kind: TaskActivityKind.subtask,
        detail: 'Added “$title”',
        createdAt: DateTime.now(),
      ).toMap(),
    );
    return Subtask(id: id, taskId: taskId, title: title, position: position);
  }

  Future<void> updateSubtask(Subtask subtask, {String? newTitle}) async {
    final id = subtask.id;
    if (id == null) {
      throw ArgumentError('Subtask must have an id to be updated.');
    }
    final db = await _db;
    final title = newTitle ?? subtask.title;
    final batch = db.batch();
    batch.update(
      DatabaseHelper.tableSubtasks,
      subtask.copyWith(title: title).toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    batch.insert(
      DatabaseHelper.tableTaskActivities,
      TaskActivity(
        taskId: subtask.taskId,
        kind: TaskActivityKind.subtask,
        detail: 'Renamed to “$title”',
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await batch.commit(noResult: true);
  }

  Future<void> setSubtaskDone(Subtask subtask, bool done) async {
    final id = subtask.id;
    if (id == null) {
      throw ArgumentError('Subtask must have an id to be updated.');
    }
    final db = await _db;
    final batch = db.batch();
    batch.update(
      DatabaseHelper.tableSubtasks,
      {
        'done': done ? 1 : 0,
        'completed_at': done ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    batch.update(
      DatabaseHelper.tableTasks,
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [subtask.taskId],
    );
    await batch.commit(noResult: true);
  }

  Future<void> deleteSubtask(Subtask subtask) async {
    final id = subtask.id;
    if (id == null) return;
    final db = await _db;
    final batch = db.batch();
    batch.delete(
      DatabaseHelper.tableSubtasks,
      where: 'id = ?',
      whereArgs: [id],
    );
    batch.insert(
      DatabaseHelper.tableTaskActivities,
      TaskActivity(
        taskId: subtask.taskId,
        kind: TaskActivityKind.subtask,
        detail: 'Removed “${subtask.title}”',
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await batch.commit(noResult: true);
  }

  Future<void> reorderSubtasks(int taskId, List<int> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        DatabaseHelper.tableSubtasks,
        {'position': i},
        where: 'id = ? AND task_id = ?',
        whereArgs: [orderedIds[i], taskId],
      );
    }
    await batch.commit(noResult: true);
  }

  // ----- Occurrence overrides -----

  /// Per-day overrides for the days in a window — the dashboard reads these
  /// alongside the tasks it already loaded.
  Future<List<TaskOccurrenceEdit>> getOccurrenceEditsInRange(
    String startDateKey,
    String endDateKey,
  ) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTaskOccurrenceEdits,
      where: 'date_key BETWEEN ? AND ?',
      whereArgs: [startDateKey, endDateKey],
    );
    return rows.map(TaskOccurrenceEdit.fromMap).toList();
  }

  Future<void> upsertOccurrenceEdit(TaskOccurrenceEdit edit) async {
    final db = await _db;
    final batch = db.batch();
    batch.insert(
      DatabaseHelper.tableTaskOccurrenceEdits,
      edit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      DatabaseHelper.tableTaskActivities,
      TaskActivity(
        taskId: edit.taskId,
        kind: TaskActivityKind.edited,
        dateKey: edit.dateKey,
        detail: 'This occurrence only',
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await batch.commit(noResult: true);
  }

  // ----- History -----

  Future<List<TaskActivity>> getActivitiesForTask(int taskId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTaskActivities,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at DESC',
      limit: 200,
    );
    return rows.map(TaskActivity.fromMap).toList();
  }
}
