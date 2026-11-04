import 'task.dart';

/// Field changes that apply to a single occurrence of a recurring task only.
///
/// A null field means "inherit the series value"; the row therefore never
/// copies the task, it only stores the difference the user asked for.
class TaskOccurrenceEdit {
  const TaskOccurrenceEdit({
    this.id,
    required this.taskId,
    required this.dateKey,
    this.title,
    this.description,
    this.dueDateKey,
    this.dueMinutesOfDay,
    this.recurrence,
    this.reminderLeadMinutes,
    required this.editedAt,
  });

  final int? id;
  final int taskId;

  /// The occurrence these overrides apply to.
  final String dateKey;

  final String? title;
  final String? description;
  final String? dueDateKey;
  final int? dueMinutesOfDay;
  final TaskRecurrence? recurrence;
  final int? reminderLeadMinutes;
  final DateTime editedAt;

  /// The series definition with this day's overrides on top of it.
  Task applyTo(Task base) {
    return base.copyWith(
      title: title,
      description: description,
      dueDateKey: dueDateKey,
      dueMinutesOfDay: dueMinutesOfDay,
      recurrence: recurrence,
      reminderLeadMinutes: reminderLeadMinutes,
    );
  }

  static TaskOccurrenceEdit fromMap(Map<String, Object?> map) {
    return TaskOccurrenceEdit(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      dateKey: map['date_key'] as String,
      title: map['title'] as String?,
      description: map['description'] as String?,
      dueDateKey: map['due_date_key'] as String?,
      dueMinutesOfDay: map['due_time_minutes'] as int?,
      recurrence: map['recurrence'] == null
          ? null
          : TaskRecurrence.fromDbValue(map['recurrence'] as String?),
      reminderLeadMinutes: map['reminder_lead_minutes'] as int?,
      editedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['edited_at'] as int?) ?? 0,
      ),
    );
  }

  /// `priority` and `category_id` are no longer written — both columns are
  /// nullable, so omitting them keeps the schema intact.
  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'task_id': taskId,
      'date_key': dateKey,
      'title': title,
      'description': description,
      'due_date_key': dueDateKey,
      'due_time_minutes': dueMinutesOfDay,
      'recurrence': recurrence?.dbValue,
      'reminder_lead_minutes': reminderLeadMinutes,
      'edited_at': editedAt.millisecondsSinceEpoch,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  TaskOccurrenceEdit copyWith({
    int? id,
    int? taskId,
    String? dateKey,
    String? title,
    String? description,
    String? dueDateKey,
    int? dueMinutesOfDay,
    TaskRecurrence? recurrence,
    int? reminderLeadMinutes,
    DateTime? editedAt,
  }) {
    return TaskOccurrenceEdit(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      dateKey: dateKey ?? this.dateKey,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDateKey: dueDateKey ?? this.dueDateKey,
      dueMinutesOfDay: dueMinutesOfDay ?? this.dueMinutesOfDay,
      recurrence: recurrence ?? this.recurrence,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}
