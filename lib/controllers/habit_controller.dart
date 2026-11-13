import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/habit.dart';
import '../models/habit_entry.dart';
import '../repositories/habit_repository.dart';
import '../services/habit_widget_service.dart';
import '../services/notification_service.dart';
import '../services/view_preferences.dart';
import '../utils/date_key.dart';

/// Loads habits and their recent entries from SQLite and exposes
/// write operations used by the home screen cards.
class HabitController extends GetxController {
  HabitController({HabitRepository? repository})
    : _repository = repository ?? HabitRepository();

  /// Days of entry history kept in memory (matches the 52-week home card).
  static const int historyDays = 364;

  final HabitRepository _repository;

  final habits = <Habit>[].obs;

  /// habitId -> (dateKey -> stored value). A missing dateKey means the day
  /// has no entry at all (incomplete / zero).
  final entries = RxMap<int, Map<String, double>>();

  final isLoading = false.obs;
  final loadError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Reminders are re-armed from the stored habits once they are loaded, so
    // a schedule lost between launches comes back on its own.
    loadHabits().then((_) {
      if (loadError.isEmpty) {
        NotificationService.instance.syncAll(habits);
      }
    });
    ViewPreferences.read().then((value) {
      if (value != null) {
        compactView.value = value == ViewPreferences.viewCompact;
      }
    });
  }

  Future<void> loadHabits() async {
    isLoading.value = true;
    loadError.value = '';
    try {
      final habitList = await _repository.getHabits();
      final startKey = dateKeyFor(shiftDays(today, -(historyDays - 1)));
      final allEntries = await _repository.getAllEntriesInRange(
        startKey,
        todayDateKey,
      );
      final map = <int, Map<String, double>>{};
      for (final habit in habitList) {
        if (habit.id != null) map[habit.id!] = {};
      }
      for (final entry in allEntries) {
        map.putIfAbsent(entry.habitId, () => {})[entry.dateKey] = entry.value;
      }
      habits.assignAll(habitList);
      entries
        ..clear()
        ..addAll(map);
      unawaited(HabitWidgetService.sync(habits, entries));
    } catch (e) {
      loadError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  double? valueFor(Habit habit, String dateKey) =>
      entries[habit.id ?? -1]?[dateKey];

  bool isDone(Habit habit, String dateKey) =>
      (valueFor(habit, dateKey) ?? 0) >= 0.5;

  /// Whether today reads as "done" by the rules the cards use: yes/no needs a
  /// mark, count/measure need the goal reached (or any logged value without a
  /// goal).
  bool isCompleteToday(Habit habit) {
    if (habit.type == HabitType.yesNo) return isDone(habit, todayDateKey);
    final value = valueFor(habit, todayDateKey) ?? 0;
    final goal = habit.goalValue;
    if (goal == null || goal <= 0) return value > 0;
    return value >= goal;
  }

  // --- Home list view mode ---------------------------------------------------

  /// True shows the one-line compact rows, false the full chart cards.
  final compactView = false.obs;

  /// Switches the home list and remembers the choice. Nothing here touches
  /// habits, entries or order.
  void setViewMode({required bool compact}) {
    if (compactView.value == compact) return;
    compactView.value = compact;
    ViewPreferences.write(
      compact ? ViewPreferences.viewCompact : ViewPreferences.viewFull,
    );
  }

  // --- Home list filters -----------------------------------------------------

  /// null keeps every type.
  final filterType = Rx<HabitType?>(null);

  /// null = any, true = done today, false = still open today.
  final filterCompletedToday = Rx<bool?>(null);

  /// Whether the filter row under the app bar is expanded.
  final filtersOpen = false.obs;

  int get activeFilterCount =>
      (filterType.value == null ? 0 : 1) +
      (filterCompletedToday.value == null ? 0 : 1);

  bool get hasActiveFilter => activeFilterCount > 0;

  void clearFilters() {
    filterType.value = null;
    filterCompletedToday.value = null;
  }

  /// Habits the home list shows right now. Reads its observables synchronously
  /// so it can be snapshotted straight from an Obx builder.
  List<Habit> get visibleHabits {
    final type = filterType.value;
    final completed = filterCompletedToday.value;
    if (type == null && completed == null) return habits;
    return habits.where((habit) {
      if (type != null && habit.type != type) return false;
      if (completed != null && isCompleteToday(habit) != completed) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> addHabit(Habit habit) async {
    // New habits go to the bottom of the home list.
    final id = await _repository.insertHabit(
      habit.copyWith(sortOrder: habits.length),
    );
    await loadHabits();
    await NotificationService.instance.syncHabit(habit.copyWith(id: id));
  }

  /// Persists edits to a habit's settings. Entries are untouched.
  Future<void> updateHabit(Habit habit) async {
    await _repository.updateHabit(habit);
    await loadHabits();
    await NotificationService.instance.syncHabit(habit);
  }

  /// Permanently removes a habit; its entries are removed by ON DELETE CASCADE.
  Future<void> deleteHabit(int id) async {
    await _repository.deleteHabit(id);
    entries.remove(id);
    entries.refresh();
    await loadHabits();
    await NotificationService.instance.cancelHabit(id);
  }

  /// Moves a habit to a new position and persists the full order.
  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    var to = newIndex;
    if (oldIndex < to) to--;
    if (to == oldIndex || to < 0 || to >= habits.length) return;
    final list = List<Habit>.from(habits);
    final moved = list.removeAt(oldIndex);
    list.insert(to, moved);
    habits.assignAll(list);
    for (var i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i && list[i].id != null) {
        await _repository.updateHabitSortOrder(list[i].id!, i);
      }
    }
  }

  /// Marks/unmarks a yes_no day. Unmarking deletes the row so empty days
  /// stay absent from the database.
  Future<void> toggleYesNo(Habit habit, String dateKey) async {
    final id = habit.id;
    if (id == null || dateKey.compareTo(todayDateKey) > 0) return;
    // Every mark path (card button, compact cell, details calendar) funnels
    // through here, so the confirmation buzz belongs at this level.
    HapticFeedback.vibrate();
    if (isDone(habit, dateKey)) {
      await _repository.deleteEntry(id, dateKey);
      _writeLocal(id, dateKey, null);
    } else {
      await _repository.upsertEntry(
        HabitEntry(habitId: id, dateKey: dateKey, value: 1),
      );
      _writeLocal(id, dateKey, 1);
    }
  }

  /// Stores a count/measure value for a day, or removes the entry when
  /// [value] is null. Future dates are rejected.
  Future<void> saveValue(Habit habit, String dateKey, double? value) async {
    final id = habit.id;
    if (id == null || dateKey.compareTo(todayDateKey) > 0) return;
    if (value == null) {
      await _repository.deleteEntry(id, dateKey);
      _writeLocal(id, dateKey, null);
    } else {
      await _repository.upsertEntry(
        HabitEntry(habitId: id, dateKey: dateKey, value: value),
      );
      _writeLocal(id, dateKey, value);
    }
  }

  void _writeLocal(int habitId, String dateKey, double? value) {
    final map = entries[habitId] ??= {};
    if (value == null) {
      map.remove(dateKey);
    } else {
      map[dateKey] = value;
    }
    entries[habitId] = map;
    entries.refresh();
    unawaited(HabitWidgetService.sync(habits, entries));
  }
}
