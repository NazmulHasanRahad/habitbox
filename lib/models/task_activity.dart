/// What happened in a task's history row.
enum TaskActivityKind {
  created('created'),
  edited('edited'),
  completed('completed'),
  reopened('reopened'),
  subtask('subtask'),
  reminder('reminder'),
  archived('archived'),
  restored('restored');

  const TaskActivityKind(this.dbValue);

  /// Value stored in the `kind` column.
  final String dbValue;

  static TaskActivityKind fromDbValue(String? value) {
    return TaskActivityKind.values.firstWhere(
      (kind) => kind.dbValue == value,
      orElse: () => TaskActivityKind.edited,
    );
  }
}

/// One line of the activity log shown on the details screen (§4, §11).
class TaskActivity {
  const TaskActivity({
    this.id,
    required this.taskId,
    required this.kind,
    this.dateKey,
    this.detail,
    required this.createdAt,
  });

  final int? id;
  final int taskId;
  final TaskActivityKind kind;

  /// The occurrence the action refers to, when it was about a specific day.
  final String? dateKey;

  /// Human-readable note, e.g. the title of a subtask.
  final String? detail;

  final DateTime createdAt;

  static TaskActivity fromMap(Map<String, Object?> map) {
    return TaskActivity(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      kind: TaskActivityKind.fromDbValue(map['kind'] as String?),
      dateKey: map['date_key'] as String?,
      detail: map['detail'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'task_id': taskId,
      'kind': kind.dbValue,
      'date_key': dateKey,
      'detail': detail,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  TaskActivity copyWith({
    int? id,
    int? taskId,
    TaskActivityKind? kind,
    String? dateKey,
    String? detail,
    DateTime? createdAt,
  }) {
    return TaskActivity(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      kind: kind ?? this.kind,
      dateKey: dateKey ?? this.dateKey,
      detail: detail ?? this.detail,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
