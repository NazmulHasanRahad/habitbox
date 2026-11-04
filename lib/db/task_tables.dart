import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

/// DDL for the task feature, kept out of [DatabaseHelper] so the habit schema
/// stays readable.
///
/// Everything here is additive: no habit table is altered or dropped, and every
/// statement is idempotent (`IF NOT EXISTS`) so a partially applied migration
/// can be re-run safely — which is also what hot restarts after a version bump
/// rely on.
class TaskTables {
  /// Applied on a fresh install and on the v3 -> v4 upgrade.
  static Future<void> createAll(Database db) async {
    for (final statement in _ddl) {
      await db.execute(statement);
    }
  }

  static const List<String> _ddl = [
    _createCategories,
    _createTasks,
    _createSubtasks,
    _createCompletions,
    _createOccurrenceEdits,
    _createActivities,
    ..._indexes,
  ];

  static const String _createCategories =
      '''
CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableTaskCategories} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''';

  /// One row per recurring series; per-day state lives in the completion and
  /// occurrence-edit tables instead of being copied into new task rows.
  static const String _createTasks =
      '''
CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableTasks} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  due_date_key TEXT,
  due_time_minutes INTEGER CHECK (due_time_minutes BETWEEN 0 AND 1439),
  priority TEXT NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  category_id INTEGER REFERENCES ${DatabaseHelper.tableTaskCategories} (id)
    ON DELETE SET NULL,
  recurrence TEXT NOT NULL DEFAULT 'none'
    CHECK (recurrence IN ('none', 'daily', 'weekly', 'monthly', 'custom')),
  recurrence_interval INTEGER,
  recurrence_start_key TEXT,
  recurrence_until_key TEXT,
  parent_task_id INTEGER REFERENCES ${DatabaseHelper.tableTasks} (id)
    ON DELETE SET NULL,
  reminder_lead_minutes INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER,
  -- Last, so a freshly created table has the same column order as an old one
  -- that the v5 migration ALTERs.
  sort_order INTEGER NOT NULL DEFAULT 0
)''';

  static const String _createSubtasks =
      '''
CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableSubtasks} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES ${DatabaseHelper.tableTasks} (id)
    ON DELETE CASCADE,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER
)''';

  /// The completion ledger, shaped like habit_entries: one row per
  /// (task, day) so completing today never touches tomorrow.
  static const String _createCompletions =
      '''
CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableTaskCompletions} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES ${DatabaseHelper.tableTasks} (id)
    ON DELETE CASCADE,
  date_key TEXT NOT NULL,
  completed_at INTEGER NOT NULL,
  UNIQUE (task_id, date_key)
)''';

  static const String _createOccurrenceEdits =
      '''
CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableTaskOccurrenceEdits} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES ${DatabaseHelper.tableTasks} (id)
    ON DELETE CASCADE,
  date_key TEXT NOT NULL,
  title TEXT,
  description TEXT,
  due_date_key TEXT,
  due_time_minutes INTEGER,
  priority TEXT CHECK (priority IN ('low', 'medium', 'high')),
  category_id INTEGER REFERENCES ${DatabaseHelper.tableTaskCategories} (id)
    ON DELETE SET NULL,
  recurrence TEXT CHECK (recurrence IN ('none', 'daily', 'weekly', 'monthly', 'custom')),
  reminder_lead_minutes INTEGER,
  edited_at INTEGER NOT NULL,
  UNIQUE (task_id, date_key)
)''';

  static const String _createActivities =
      '''
CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableTaskActivities} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL REFERENCES ${DatabaseHelper.tableTasks} (id)
    ON DELETE CASCADE,
  date_key TEXT,
  kind TEXT NOT NULL,
  detail TEXT,
  created_at INTEGER NOT NULL
)''';

  /// Covers the dashboard's day window, category filters and the calendar's
  /// range queries. Child tables get their parent lookups from the FK index
  /// created with the UNIQUE constraints, plus these.
  static const List<String> _indexes = [
    '''
CREATE INDEX IF NOT EXISTS idx_tasks_due_date_key
  ON ${DatabaseHelper.tableTasks} (due_date_key)''',
    '''
CREATE INDEX IF NOT EXISTS idx_tasks_category_id
  ON ${DatabaseHelper.tableTasks} (category_id)''',
    '''
CREATE INDEX IF NOT EXISTS idx_task_completions_date_key
  ON ${DatabaseHelper.tableTaskCompletions} (date_key)''',
    '''
CREATE INDEX IF NOT EXISTS idx_subtasks_task_id
  ON ${DatabaseHelper.tableSubtasks} (task_id, position)''',
    '''
CREATE INDEX IF NOT EXISTS idx_task_activities_task_id
  ON ${DatabaseHelper.tableTaskActivities} (task_id, created_at DESC)''',
  ];
}
