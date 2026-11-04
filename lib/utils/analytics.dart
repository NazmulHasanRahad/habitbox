import '../models/habit.dart';
import 'date_key.dart';

/// Offline analytics over the habits and entries the controller already keeps
/// in memory. Pure read-only arithmetic: no database access, no writes.
///
/// The one rule every number rests on: a habit is *scheduled* on a day from the
/// day it was created onwards, and it is *completed* on that day when a yes/no
/// habit is marked, when a count/measure habit reaches its goal, or — with no
/// goal configured — when any value above zero was logged.

/// A day of the analytics window: how many habits were expected, how many were
/// actually met.
class DayStat {
  const DayStat({
    required this.date,
    required this.scheduled,
    required this.completed,
  });

  final DateTime date;
  final int scheduled;
  final int completed;

  /// False when nothing was tracked yet that day (all habits came later).
  bool get hasTarget => scheduled > 0;

  double get rate => scheduled == 0 ? 0 : completed / scheduled;
}

/// One habit's slice of the window.
class HabitStat {
  const HabitStat({
    required this.habit,
    required this.scheduled,
    required this.completed,
    required this.totalValue,
    required this.currentStreak,
    required this.bestStreak,
  });

  final Habit habit;
  final int scheduled;
  final int completed;

  /// Sum of logged values, so a count or measure habit can report real
  /// quantities. Always 0 for yes/no habits, where days are the meaningful unit.
  final double totalValue;

  final int currentStreak;
  final int bestStreak;

  double get rate => scheduled == 0 ? 0 : completed / scheduled;

  bool get hasGoal {
    final goal = habit.goalValue;
    return goal != null && goal > 0;
  }

  String get unit => habit.unit?.trim() ?? '';
}

/// The whole report for one period, ready for the UI to render without any
/// further counting.
class AnalyticsReport {
  const AnalyticsReport({
    required this.windowDays,
    required this.days,
    required this.habits,
    required this.perfectStreak,
    required this.activeStreak,
  });

  /// Builds the report from raw state. [entries] is habitId -> dateKey -> value.
  factory AnalyticsReport.build({
    required List<Habit> habits,
    required Map<int, Map<String, double>> entries,
    required int windowDays,
  }) {
    final days = lastNDays(windowDays);
    final scheduledByHabit = <List<bool>>[];
    final doneByHabit = <List<bool>>[];
    final habitStats = <HabitStat>[];

    for (final habit in habits) {
      final values = habit.id == null
          ? const <String, double>{}
          : entries[habit.id] ?? const <String, double>{};
      final createdKey = dateKeyFor(habit.createdAt);

      final scheduled = <bool>[];
      final done = <bool>[];
      var met = 0;
      var total = 0.0;

      for (final day in days) {
        final key = dateKeyFor(day);
        final expected = key.compareTo(createdKey) >= 0;
        final value = values[key];
        final completed = expected && _completed(habit, value);

        scheduled.add(expected);
        done.add(completed);
        if (completed) met++;
        if (value != null && habit.type != HabitType.yesNo) total += value;
      }

      scheduledByHabit.add(scheduled);
      doneByHabit.add(done);

      habitStats.add(
        HabitStat(
          habit: habit,
          scheduled: scheduled.where((expected) => expected).length,
          completed: met,
          totalValue: total,
          currentStreak: _currentStreak(done),
          bestStreak: _bestStreak(done),
        ),
      );
    }

    final dayStats = <DayStat>[];
    for (var i = 0; i < days.length; i++) {
      var expected = 0;
      var met = 0;
      for (final scheduled in scheduledByHabit) {
        if (scheduled[i]) expected++;
      }
      for (final done in doneByHabit) {
        if (done[i]) met++;
      }
      dayStats.add(DayStat(date: days[i], scheduled: expected, completed: met));
    }

    // The leaderboard reads better by consistency, with volume as the tie-break.
    habitStats.sort((a, b) {
      final byRate = b.rate.compareTo(a.rate);
      return byRate != 0 ? byRate : b.completed.compareTo(a.completed);
    });

    return AnalyticsReport(
      windowDays: windowDays,
      days: dayStats,
      habits: habitStats,
      perfectStreak: _streak(
        dayStats,
        (day) => day.hasTarget && day.completed >= day.scheduled,
      ),
      activeStreak: _streak(dayStats, (day) => day.completed > 0),
    );
  }

  final int windowDays;

  /// Oldest first, ending with today.
  final List<DayStat> days;

  /// Sorted by completion rate, best first.
  final List<HabitStat> habits;

  /// Consecutive days with every tracked habit met.
  final int perfectStreak;

  /// Consecutive days with at least one habit met.
  final int activeStreak;

  int get scheduled => days.fold(0, (sum, day) => sum + day.scheduled);

  int get completed => days.fold(0, (sum, day) => sum + day.completed);

  /// Fraction of the tracked day-habits that were met. Zero when nothing was
  /// scheduled yet, so the UI never divides by an empty window.
  double get rate => scheduled == 0 ? 0 : completed / scheduled;

  int get loggedDays => days.where((day) => day.completed > 0).length;

  /// Days inside the window where every habit that existed was met.
  int get perfectDays => days
      .where((day) => day.hasTarget && day.completed >= day.scheduled)
      .length;

  int get trackedDays => days.where((day) => day.hasTarget).length;

  HabitStat? get bestHabit => habits.isEmpty ? null : habits.first;

  HabitStat? get weakestHabit {
    if (habits.length < 2) return null;
    for (final stat in habits.reversed) {
      if (stat.scheduled > 0) return stat;
    }
    return null;
  }

  bool get hasData => habits.isNotEmpty;
}

bool _completed(Habit habit, double? value) {
  if (value == null) return false;
  if (habit.type == HabitType.yesNo) return value >= 0.5;
  final goal = habit.goalValue;
  if (goal == null || goal <= 0) return value > 0;
  return value >= goal;
}

/// Longest run of consecutive met days inside the window.
int _bestStreak(List<bool> done) {
  var best = 0;
  var run = 0;
  for (final met in done) {
    run = met ? run + 1 : 0;
    if (run > best) best = run;
  }
  return best;
}

/// Run ending today. Today itself only breaks the chain once it is over, so a
/// morning never shows a streak of zero.
int _currentStreak(List<bool> done) {
  var index = done.length - 1;
  if (index >= 0 && !done[index]) index--;
  var streak = 0;
  while (index >= 0 && done[index]) {
    streak++;
    index--;
  }
  return streak;
}

int _streak(List<DayStat> days, bool Function(DayStat day) met) {
  var index = days.length - 1;
  if (index >= 0 && !met(days[index])) index--;
  var streak = 0;
  while (index >= 0 && met(days[index])) {
    streak++;
    index--;
  }
  return streak;
}
