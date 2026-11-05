import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'task_tables.dart';

/// Singleton access to the local HabitBox database.
///
/// Schema is versioned; [Database._onUpgrade] must contain a step for every
/// version boundary from 1 up to [_databaseVersion].
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String databaseName = 'habitbox.db';

  /// v4 added the task tables through [TaskTables]; v5 gave them a `sort_order`
  /// column for the dashboard's manual order. v6 added the optional daily
  /// reminder time to habits. No existing row is rewritten by any step.
  static const int _databaseVersion = 6;

  static const String tableHabits = 'habits';
  static const String tableHabitEntries = 'habit_entries';

  static const String tableTasks = 'tasks';
  static const String tableTaskCategories = 'task_categories';
  static const String tableSubtasks = 'subtasks';
  static const String tableTaskCompletions = 'task_completions';
  static const String tableTaskOccurrenceEdits = 'task_occurrence_edits';
  static const String tableTaskActivities = 'task_activities';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    existing?.close();
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Required for ON DELETE CASCADE in habit_entries.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createHabits);
    await db.execute(_createHabitEntries);
    await TaskTables.createAll(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: manual habit order for the home screen. Existing habits keep
      // their current order (created_at) via the backfill below.
      await _addColumnIfMissing(
        db,
        tableHabits,
        'sort_order',
        'sort_order INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
UPDATE $tableHabits SET sort_order = (
  SELECT COUNT(*) FROM $tableHabits h
  WHERE h.created_at < $tableHabits.created_at
     OR (h.created_at = $tableHabits.created_at AND h.id < $tableHabits.id)
)''');
    }
    if (oldVersion < 3) {
      // v3: optional free-text description for a habit.
      await _addColumnIfMissing(
        db,
        tableHabits,
        'description',
        'description TEXT',
      );
    }
    if (oldVersion < 4) {
      // v4: task management. Purely additive — every statement is
      // IF NOT EXISTS, so no habit table and no existing row is modified.
      await TaskTables.createAll(db);
    }
    if (oldVersion < 5) {
      // v5: manual task order for the dashboard. Existing tasks keep the order
      // they already had by backfilling the rank of their created_at, the same
      // way habits v2 did.
      await _addColumnIfMissing(
        db,
        tableTasks,
        'sort_order',
        'sort_order INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
UPDATE $tableTasks SET sort_order = (
  SELECT COUNT(*) FROM $tableTasks t
  WHERE t.created_at < $tableTasks.created_at
     OR (t.created_at = $tableTasks.created_at AND t.id < $tableTasks.id)
)''');
    }
    if (oldVersion < 6) {
      // v6: optional daily reminder time for a habit, stored as minutes since
      // midnight. NULL (the default for every existing habit) means no
      // reminder, so nothing has to be backfilled.
      await _addColumnIfMissing(
        db,
        tableHabits,
        'reminder_minutes',
        'reminder_minutes INTEGER',
      );
    }
  }

  /// ALTER TABLE guarded by PRAGMA table_info so a re-run (e.g. after a
  /// partially applied migration) never fails with "duplicate column".
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String columnDefinition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
    }
  }

  static const String _createHabits =
      '''
CREATE TABLE $tableHabits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('yes_no', 'count', 'measure')),
  color INTEGER NOT NULL,
  icon_code_point INTEGER NOT NULL,
  goal_value REAL,
  unit TEXT,
  created_at INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  reminder_minutes INTEGER
)''';

  static const String _createHabitEntries =
      '''
CREATE TABLE $tableHabitEntries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  habit_id INTEGER NOT NULL REFERENCES $tableHabits (id) ON DELETE CASCADE,
  date_key TEXT NOT NULL,
  value REAL NOT NULL DEFAULT 0,
  UNIQUE (habit_id, date_key)
)''';

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
