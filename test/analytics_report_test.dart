import 'package:flutter_test/flutter_test.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/utils/analytics.dart';
import 'package:habitbox/utils/date_key.dart';

/// The report is pure arithmetic over the controller's in-memory state, so it
/// is tested without any widget or database.
void main() {
  Habit habit({
    required HabitType type,
    double? goal,
    int createdDaysAgo = 30,
    int id = 1,
  }) => Habit(
    id: id,
    name: 'Habit $id',
    type: type,
    color: 0xFF6750A4,
    iconCodePoint: 0xE86D,
    goalValue: goal,
    unit: type == HabitType.measure ? 'km' : null,
    createdAt: shiftDays(today, -createdDaysAgo),
  );

  Map<String, double> values(Map<int, double> byDaysBack) => {
    for (final entry in byDaysBack.entries)
      dateKeyFor(shiftDays(today, -entry.key)): entry.value,
  };

  group('completion rule', () {
    test('a yes/no day only counts when marked', () {
      final report = AnalyticsReport.build(
        habits: [habit(type: HabitType.yesNo)],
        entries: {
          1: values({2: 1, 1: 0.4}),
        },
        windowDays: 7,
      );

      // Seven days, all scheduled (the habit predates the window), one marked.
      expect(report.scheduled, 7);
      expect(report.completed, 1);
      expect(report.rate, closeTo(1 / 7, 1e-9));
    });

    test('count and measure need the goal, and never divide by zero', () {
      final withGoal = AnalyticsReport.build(
        habits: [habit(type: HabitType.count, goal: 20)],
        entries: {
          1: values({2: 25, 1: 12, 0: 0}),
        },
        windowDays: 7,
      );
      expect(withGoal.completed, 1, reason: 'only 25 reaches the goal of 20');

      final noGoal = AnalyticsReport.build(
        habits: [habit(type: HabitType.count, goal: null)],
        entries: {
          1: values({2: 3}),
        },
        windowDays: 7,
      );
      expect(
        noGoal.completed,
        1,
        reason: 'without a goal any logged day counts',
      );

      final empty = AnalyticsReport.build(
        habits: const [],
        entries: const {},
        windowDays: 30,
      );
      expect(empty.hasData, isFalse);
      expect(empty.scheduled, 0);
      expect(empty.rate, 0);
    });
  });

  test('a fresh habit is not counted as missed before it existed', () {
    final report = AnalyticsReport.build(
      habits: [habit(type: HabitType.yesNo, createdDaysAgo: 2)],
      entries: {
        1: values({2: 1, 1: 1}),
      },
      windowDays: 30,
    );

    expect(report.scheduled, 3, reason: 'creation day plus the two after it');
    expect(report.completed, 2);
    expect(report.days.last.scheduled, 1);
    expect(report.days.last.completed, 0);
    expect(report.days.last.hasTarget, isTrue);
    // The 27 days before the habit existed carry no target at all.
    expect(report.days.first.hasTarget, isFalse);
  });

  group('streaks', () {
    test('an unfinished today does not break the chain', () {
      final report = AnalyticsReport.build(
        habits: [habit(type: HabitType.yesNo, createdDaysAgo: 30)],
        entries: {
          1: values({4: 1, 3: 1, 2: 1, 1: 1}),
        },
        windowDays: 7,
      );

      expect(report.perfectStreak, 4);
      expect(report.activeStreak, 4);
    });

    test('a perfect day needs every tracked habit met', () {
      final report = AnalyticsReport.build(
        habits: [
          habit(type: HabitType.yesNo, createdDaysAgo: 30, id: 1),
          habit(type: HabitType.count, goal: 10, createdDaysAgo: 30, id: 2),
        ],
        entries: {
          1: values({0: 1, 1: 1, 2: 1}),
          2: values({1: 10, 2: 10}),
        },
        windowDays: 7,
      );

      // Today: habit 1 done, habit 2 missing, so today is active but not
      // perfect, and the chain starts from yesterday.
      expect(report.days.last.completed, 1);
      expect(report.days.last.scheduled, 2);
      expect(report.activeStreak, 3);
      expect(report.perfectStreak, 2);
      expect(report.perfectDays, 2);
    });

    test('best streak finds the longest run anywhere in the window', () {
      final report = AnalyticsReport.build(
        habits: [
          habit(type: HabitType.yesNo, createdDaysAgo: 30).copyWith(id: 1),
        ],
        entries: {
          1: values({10: 1, 9: 1, 8: 1, 3: 1}),
        },
        windowDays: 14,
      );

      expect(report.habits.single.bestStreak, 3);
      expect(report.habits.single.currentStreak, 0);
    });
  });

  test('totals, ordering and per-habit numbers', () {
    final report = AnalyticsReport.build(
      habits: [
        habit(type: HabitType.measure, goal: 5, createdDaysAgo: 30, id: 1),
        habit(type: HabitType.count, goal: 20, createdDaysAgo: 30, id: 2),
      ],
      entries: {
        1: values({2: 3.5, 1: 5, 0: 5}),
        2: values({2: 20}),
      },
      windowDays: 7,
    );

    // Habit 1 met twice of 7, habit 1's logged values sum to 13.5 km.
    expect(report.habits.first.habit.id, 1, reason: 'best rate leads the list');
    expect(report.habits.first.completed, 2);
    expect(report.habits.first.totalValue, closeTo(13.5, 1e-9));
    expect(report.habits.first.unit, 'km');
    expect(report.habits.last.completed, 1);
    expect(report.bestHabit?.habit.id, 1);
    expect(report.weakestHabit?.habit.id, 2);
    expect(report.loggedDays, 3);
    expect(report.trackedDays, 7);
    expect(report.perfectDays, 0, reason: 'no single day meets both habits');
  });
}
