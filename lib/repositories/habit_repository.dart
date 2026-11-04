import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';

/// All SQLite reads/writes for habits and their daily entries.
class HabitRepository {
  HabitRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<Database> get _db => _dbHelper.database;

  // ----- Habits -----

  Future<List<Habit>> getHabits() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableHabits,
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Habit.fromMap).toList();
  }

  Future<Habit?> getHabit(int id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableHabits,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Habit.fromMap(rows.first);
  }

  Future<int> insertHabit(Habit habit) async {
    final db = await _db;
    return db.insert(
      DatabaseHelper.tableHabits,
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) {
      throw ArgumentError('Habit must have an id to be updated.');
    }
    final db = await _db;
    return db.update(
      DatabaseHelper.tableHabits,
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateHabitSortOrder(int id, int sortOrder) async {
    final db = await _db;
    return db.update(
      DatabaseHelper.tableHabits,
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes the habit and, via ON DELETE CASCADE, its entries.
  Future<int> deleteHabit(int id) async {
    final db = await _db;
    return db.delete(
      DatabaseHelper.tableHabits,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ----- Daily entries -----

  Future<List<HabitEntry>> getEntriesForDate(String dateKey) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableHabitEntries,
      where: 'date_key = ?',
      whereArgs: [dateKey],
    );
    return rows.map(HabitEntry.fromMap).toList();
  }

  Future<List<HabitEntry>> getEntriesForRange(
    int habitId,
    String startDateKey,
    String endDateKey,
  ) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableHabitEntries,
      where: 'habit_id = ? AND date_key BETWEEN ? AND ?',
      whereArgs: [habitId, startDateKey, endDateKey],
      orderBy: 'date_key ASC',
    );
    return rows.map(HabitEntry.fromMap).toList();
  }

  /// All entries of every habit within a date window (for the home screen).
  Future<List<HabitEntry>> getAllEntriesInRange(
    String startDateKey,
    String endDateKey,
  ) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableHabitEntries,
      where: 'date_key BETWEEN ? AND ?',
      whereArgs: [startDateKey, endDateKey],
    );
    return rows.map(HabitEntry.fromMap).toList();
  }

  Future<HabitEntry?> getEntry(int habitId, String dateKey) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableHabitEntries,
      where: 'habit_id = ? AND date_key = ?',
      whereArgs: [habitId, dateKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HabitEntry.fromMap(rows.first);
  }

  /// Inserts the entry, replacing any existing one for the same
  /// (habit_id, date_key) pair enforced by the UNIQUE constraint.
  Future<int> upsertEntry(HabitEntry entry) async {
    final db = await _db;
    return db.insert(
      DatabaseHelper.tableHabitEntries,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteEntry(int habitId, String dateKey) async {
    final db = await _db;
    return db.delete(
      DatabaseHelper.tableHabitEntries,
      where: 'habit_id = ? AND date_key = ?',
      whereArgs: [habitId, dateKey],
    );
  }
}
