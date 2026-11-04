import 'package:flutter_test/flutter_test.dart';
import 'package:habitbox/controllers/habit_controller.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/utils/date_key.dart';

/// Pure filter logic: the controller is built directly (never through Get.put)
/// so onInit/loadHabits stay out of the test and no database is touched.
void main() {
  Habit habit({
    required int id,
    required String name,
    required HabitType type,
    double? goal,
  }) => Habit(
    id: id,
    name: name,
    type: type,
    color: 0xFF6750A4,
    iconCodePoint: 0xE87D,
    goalValue: goal,
    createdAt: DateTime(2026, 1, 1),
  );

  late HabitController controller;

  setUp(() {
    controller = HabitController();
    controller.habits.addAll([
      habit(id: 1, name: 'Meditate', type: HabitType.yesNo),
      habit(id: 2, name: 'Pages', type: HabitType.count, goal: 20),
      habit(id: 3, name: 'Run', type: HabitType.measure, goal: 5),
    ]);
    controller.entries.addAll({
      1: {todayDateKey: 1}, // marked done
      2: {todayDateKey: 12}, // logged, goal not reached
      3: {}, // nothing logged
    });
  });

  test('no filter keeps the whole list in order', () {
    expect(controller.hasActiveFilter, isFalse);
    expect(controller.activeFilterCount, 0);
    expect(controller.visibleHabits.map((h) => h.name), [
      'Meditate',
      'Pages',
      'Run',
    ]);
  });

  test('type filter narrows the list to the matching habits', () {
    controller.filterType.value = HabitType.measure;
    expect(controller.activeFilterCount, 1);
    expect(controller.visibleHabits.map((h) => h.name), ['Run']);

    controller.filterType.value = null;
    expect(controller.visibleHabits.length, 3);
  });

  test('type and status filters combine', () {
    controller.filterType.value = HabitType.count;
    controller.filterCompletedToday.value = true;
    expect(controller.activeFilterCount, 2);
    expect(controller.visibleHabits, isEmpty);

    controller.filterCompletedToday.value = false;
    expect(controller.visibleHabits.map((h) => h.name), ['Pages']);
  });

  test('done today means goal reached for count/measure, mark for yes/no', () {
    controller.filterCompletedToday.value = true;
    // Meditate is marked; Pages is 12/20 and Run is empty, so both are open.
    expect(controller.visibleHabits.map((h) => h.name), ['Meditate']);

    controller.entries[2]![todayDateKey] = 20;
    expect(controller.visibleHabits.map((h) => h.name), ['Meditate', 'Pages']);
  });

  test('a habit without a goal counts as done once anything is logged', () {
    controller.habits.add(habit(id: 4, name: 'Water', type: HabitType.measure));
    controller.entries[4] = {};
    controller.filterCompletedToday.value = true;
    expect(controller.visibleHabits.any((h) => h.name == 'Water'), isFalse);

    controller.entries[4] = {todayDateKey: 0.5};
    controller.entries.refresh();
    expect(controller.visibleHabits.map((h) => h.name), ['Meditate', 'Water']);
  });

  test('clearFilters resets both filters', () {
    controller.filterType.value = HabitType.yesNo;
    controller.filterCompletedToday.value = false;
    controller.clearFilters();
    expect(controller.hasActiveFilter, isFalse);
    expect(controller.visibleHabits.length, 3);
  });
}
