class HabitEntry {
  const HabitEntry({
    this.id,
    required this.habitId,
    required this.dateKey,
    required this.value,
  });

  final int? id;
  final int habitId;

  /// Day this entry belongs to, in YYYY-MM-DD format.
  final String dateKey;

  /// For yes_no habits 0/1 is expected; count/measure use the raw number.
  final double value;

  static HabitEntry fromMap(Map<String, Object?> map) {
    return HabitEntry(
      id: map['id'] as int?,
      habitId: map['habit_id'] as int,
      dateKey: map['date_key'] as String,
      value: (map['value'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'habit_id': habitId,
      'date_key': dateKey,
      'value': value,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  HabitEntry copyWith({
    int? id,
    int? habitId,
    String? dateKey,
    double? value,
  }) {
    return HabitEntry(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      dateKey: dateKey ?? this.dateKey,
      value: value ?? this.value,
    );
  }
}
