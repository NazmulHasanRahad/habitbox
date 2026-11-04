/// One step of a larger task. Stored independently so it survives edits of the
/// parent and can be completed in any order.
class Subtask {
  const Subtask({
    this.id,
    required this.taskId,
    required this.title,
    this.done = false,
    this.position = 0,
    this.completedAt,
  });

  final int? id;
  final int taskId;
  final String title;
  final bool done;

  /// Manual order inside the parent task (lower shows first).
  final int position;

  final DateTime? completedAt;

  static Subtask fromMap(Map<String, Object?> map) {
    return Subtask(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      title: map['title'] as String,
      done: ((map['done'] as int?) ?? 0) != 0,
      position: (map['position'] as int?) ?? 0,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['completed_at']! as int),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'task_id': taskId,
      'title': title,
      'done': done ? 1 : 0,
      'position': position,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  Subtask copyWith({
    int? id,
    int? taskId,
    String? title,
    bool? done,
    int? position,
    DateTime? completedAt,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      done: done ?? this.done,
      position: position ?? this.position,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
