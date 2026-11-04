/// The finished numbers behind the task statistics screen.
///
/// Every field is a count of rows the controller already holds — the completion
/// ledger, the task list and the step list — so a statistic can only ever state
/// something that happened. Nothing here estimates, projects or fills a gap
/// with a placeholder: a window with no record reads as zero, and a best day
/// that does not exist is null rather than a made-up date.
class TaskStats {
  const TaskStats({
    required this.windowDays,
    required this.days,
    required this.completed,
    required this.previousCompleted,
    required this.streak,
    required this.activeDays,
    required this.bestDay,
    required this.busiestWeekday,
    required this.busiestCount,
    required this.buckets,
    required this.stepsDone,
    required this.stepsTotal,
    required this.taskCount,
  });

  /// How many days the window covers.
  final int windowDays;

  /// One entry per day of the window, oldest first, so a chart can draw the
  /// list as it stands without sorting anything.
  final List<TaskStatDay> days;

  /// Occurrences finished inside the window.
  final int completed;

  /// The same count for the window of equal length immediately before this
  /// one, which is what makes [change] a comparison rather than a guess.
  final int previousCompleted;

  /// Days in a row, ending today or yesterday, with at least one occurrence
  /// finished. Measured over the whole ledger, so a 7-day window cannot cut a
  /// longer run short.
  final int streak;

  /// Days inside the window that carry at least one completion.
  final int activeDays;

  /// The busiest day of the window, or null when nothing was finished.
  final TaskStatDay? bestDay;

  /// The weekday with the most completions in the window, as a `DateTime`
  /// weekday (Monday is 1), or 0 when the window is empty.
  final int busiestWeekday;

  /// How many fell on [busiestWeekday].
  final int busiestCount;

  /// The open work as it stands at this moment, plus what today already did.
  final List<TaskBucket> buckets;

  final int stepsDone;
  final int stepsTotal;

  /// Tasks that are neither archived nor in the trash, so the screen knows the
  /// difference between an empty account and a quiet one.
  final int taskCount;

  /// Higher than [completed] means the window is going better than the one
  /// before it; a negative number means the opposite.
  int get change => completed - previousCompleted;

  /// The most any single day of the window carried, which is the height the
  /// chart scales itself against.
  int get peak {
    var highest = 0;
    for (final day in days) {
      if (day.total > highest) highest = day.total;
    }
    return highest;
  }

  /// Today's entry, which is always the last one in [days].
  TaskStatDay get today => days.last;

  /// The count a bucket holds, or 0 when the breakdown has no such line.
  int countOf(TaskBucketKind kind) {
    for (final bucket in buckets) {
      if (bucket.kind == kind) return bucket.count;
    }
    return 0;
  }

  bool get hasData => taskCount > 0;
}

/// One day of the window: what it carried and what finished on it.
class TaskStatDay {
  const TaskStatDay({
    required this.dateKey,
    required this.date,
    required this.total,
    required this.completed,
  });

  /// `yyyy-MM-dd` the completions are filed under.
  final String dateKey;

  /// The same day as a date, for labels and weekday arithmetic.
  final DateTime date;

  /// Occurrences the day carried, so the whole of a bar. It is never below
  /// [completed], which keeps [ratio] inside the bar it is drawn in.
  final int total;

  final int completed;

  /// The finished share of the day, 0 for a day that carried nothing.
  double get ratio =>
      total <= 0 ? 0 : (completed >= total ? 1 : completed / total);

  /// [ratio] rounded to whole percent, for a label.
  int get percent => (ratio * 100).round();

  /// The day carried something and every bit of it is finished.
  bool get allDone => total > 0 && completed >= total;
}

/// Which pile of the present one line of the breakdown stands for.
enum TaskBucketKind {
  /// Still open and already past its due moment.
  slipped,

  /// Still open on the day it belongs to.
  dueToday,

  /// Still open on a day that has not come yet.
  later,

  /// Still open with no due date at all.
  undated,

  /// Already finished on its own day, today.
  doneToday,
}

/// One line of the 'right now' breakdown.
class TaskBucket {
  const TaskBucket({
    required this.kind,
    required this.label,
    required this.count,
  });

  final TaskBucketKind kind;

  /// Plain words for [kind], spelled out where a filter's own label would be
  /// too terse to read alone.
  final String label;

  final int count;
}
