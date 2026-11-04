import '../utils/date_key.dart';

/// How a task repeats. Each day of a series keeps its own completion record,
/// so marking one occurrence never marks another.
enum TaskRecurrence {
  none('none'),

  /// Every calendar day.
  daily('daily'),

  /// Every 7 days from the series start.
  weekly('weekly'),

  /// Same day of the month from the series start.
  monthly('monthly'),

  /// Every `Task.recurrenceInterval` days.
  custom('custom');

  const TaskRecurrence(this.dbValue);

  /// Value stored in the `recurrence` column.
  final String dbValue;

  static TaskRecurrence fromDbValue(String? value) {
    return TaskRecurrence.values.firstWhere(
      (kind) => kind.dbValue == value,
      orElse: () => TaskRecurrence.none,
    );
  }
}

/// A single task. A recurring task is one row that describes the whole series;
/// per-day state lives in [TaskCompletion] and [TaskOccurrenceEdit].
///
/// Days are stored as `date_key` text (the same `yyyy-MM-dd` convention as
/// habit entries) and a time of day as minutes since midnight, so both stay
/// readable and sortable without a timezone.
class Task {
  const Task({
    this.id,
    required this.title,
    this.description,
    this.dueDateKey,
    this.dueMinutesOfDay,
    this.recurrence = TaskRecurrence.none,
    this.recurrenceInterval,
    this.recurrenceStartKey,
    this.recurrenceUntilKey,
    this.parentTaskId,
    this.reminderLeadMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.deletedAt,
    this.sortOrder = 0,
  });

  final int? id;
  final String title;
  final String? description;

  /// `yyyy-MM-dd` the task is due, or null when it has no due date.
  final String? dueDateKey;

  /// Minutes after local midnight; null means no specific due time.
  final int? dueMinutesOfDay;

  final TaskRecurrence recurrence;

  /// Only used by [TaskRecurrence.custom]: the gap in days between occurrences.
  final int? recurrenceInterval;

  /// First day the series applies to. Null for a non-recurring task.
  final String? recurrenceStartKey;

  /// Last day the series applies to; null means it never ends. Also how
  /// "this and future occurrences" closes the original series.
  final String? recurrenceUntilKey;

  /// Set when this row was split off a recurring series, holding the id of the
  /// series it continues. Kept so the chain is visible in the history.
  final int? parentTaskId;

  /// Notify this many minutes before the due time; null means no reminder.
  final int? reminderLeadMinutes;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Hidden from the dashboard but kept in the archive (§11).
  final bool archived;

  /// Non-null once the task is in the trash; hard delete is separate.
  final DateTime? deletedAt;

  /// Where the dashboard draws this task inside its own day. The number only
  /// has to be distinct within that day, so re-ranking one day never moves
  /// another; a new task gets the next value after every row, which puts it at
  /// the end of its own day.
  final int sortOrder;

  /// True when the due moment is already in the past relative to [now].
  /// A completed occurrence is never overdue, so callers pass [isComplete].
  bool isOverdue(DateTime now, {bool isComplete = false}) {
    if (isComplete) return false;
    final due = dueDateKey;
    if (due == null) return false;
    final todayKey = dateKeyFor(now);
    if (todayKey.compareTo(due) > 0) return true;
    final minutes = dueMinutesOfDay;
    if (minutes == null || todayKey.compareTo(due) < 0) return false;
    return now.hour * 60 + now.minute > minutes;
  }

  static Task fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDateKey: map['due_date_key'] as String?,
      dueMinutesOfDay: map['due_time_minutes'] as int?,
      recurrence: TaskRecurrence.fromDbValue(map['recurrence'] as String?),
      recurrenceInterval: map['recurrence_interval'] as int?,
      recurrenceStartKey: map['recurrence_start_key'] as String?,
      recurrenceUntilKey: map['recurrence_until_key'] as String?,
      parentTaskId: map['parent_task_id'] as int?,
      reminderLeadMinutes: map['reminder_lead_minutes'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int?) ?? 0,
      ),
      archived: ((map['archived'] as int?) ?? 0) != 0,
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['deleted_at']! as int),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  /// The `priority` and `category_id` columns stay in the schema but are left
  /// out on purpose: `priority` has a SQL default and `category_id` is
  /// nullable, so an insert without either is still valid.
  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'title': title,
      'description': description,
      'due_date_key': dueDateKey,
      'due_time_minutes': dueMinutesOfDay,
      'recurrence': recurrence.dbValue,
      'recurrence_interval': recurrenceInterval,
      'recurrence_start_key': recurrenceStartKey,
      'recurrence_until_key': recurrenceUntilKey,
      'parent_task_id': parentTaskId,
      'reminder_lead_minutes': reminderLeadMinutes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'archived': archived ? 1 : 0,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sort_order': sortOrder,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? dueDateKey,
    int? dueMinutesOfDay,
    TaskRecurrence? recurrence,
    int? recurrenceInterval,
    String? recurrenceStartKey,
    String? recurrenceUntilKey,
    int? parentTaskId,
    int? reminderLeadMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
    DateTime? deletedAt,
    int? sortOrder,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDateKey: dueDateKey ?? this.dueDateKey,
      dueMinutesOfDay: dueMinutesOfDay ?? this.dueMinutesOfDay,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceStartKey: recurrenceStartKey ?? this.recurrenceStartKey,
      recurrenceUntilKey: recurrenceUntilKey ?? this.recurrenceUntilKey,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
      deletedAt: deletedAt ?? this.deletedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
