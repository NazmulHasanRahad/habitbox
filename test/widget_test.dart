import 'package:flutter_test/flutter_test.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/models/habit_entry.dart';
import 'package:habitbox/utils/date_key.dart';

void main() {
  test('Habit map round-trip preserves fields', () {
    final habit = Habit(
      id: 1,
      name: 'Read',
      type: HabitType.count,
      color: 0xFF112233,
      iconCodePoint: 0xE86D,
      goalValue: 20,
      unit: 'pages',
      createdAt: DateTime(2026, 10, 28, 9, 30),
      reminderMinutes: 9 * 60,
      reminderDays: 21,
    );

    final restored = Habit.fromMap(habit.toMap(includeId: true));

    expect(restored.id, 1);
    expect(restored.name, 'Read');
    expect(restored.type, HabitType.count);
    expect(restored.color, 0xFF112233);
    expect(restored.iconCodePoint, 0xE86D);
    expect(restored.goalValue, 20);
    expect(restored.unit, 'pages');
    expect(restored.createdAt, habit.createdAt);
    expect(restored.reminderMinutes, 9 * 60);
    expect(restored.reminderDays, 21);
  });

  test('HabitEntry map round-trip preserves fields', () {
    final entry = HabitEntry(
      id: 5,
      habitId: 2,
      dateKey: '2026-10-28',
      value: 7,
    );

    final restored = HabitEntry.fromMap(entry.toMap(includeId: true));

    expect(restored.id, 5);
    expect(restored.habitId, 2);
    expect(restored.dateKey, '2026-10-28');
    expect(restored.value, 7);
  });

  test('dateKeyFor formats as YYYY-MM-DD', () {
    expect(dateKeyFor(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
