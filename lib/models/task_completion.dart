/// Marks one occurrence of a task as complete.
///
/// [dateKey] is the day the completion belongs to — the occurrence's own day,
/// not the day it happened — which is what keeps history when a task repeats.
class TaskCompletion {
  const TaskCompletion({
    this.id,
    required this.taskId,
    required this.dateKey,
    required this.completedAt,
  });

  final int? id;
  final int taskId;

  /// `yyyy-MM-dd` of the occurrence this row answers for.
  final String dateKey;

  final DateTime completedAt;

  static TaskCompletion fromMap(Map<String, Object?> map) {
    return TaskCompletion(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      dateKey: map['date_key'] as String,
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['completed_at'] as int?) ?? 0,
      ),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'task_id': taskId,
      'date_key': dateKey,
      'completed_at': completedAt.millisecondsSinceEpoch,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  TaskCompletion copyWith({
    int? id,
    int? taskId,
    String? dateKey,
    DateTime? completedAt,
  }) {
    return TaskCompletion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      dateKey: dateKey ?? this.dateKey,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
