/// The way a habit is tracked on a given day.
enum HabitType {
  yesNo('yes_no'),
  count('count'),
  measure('measure');

  const HabitType(this.dbValue);

  /// Value stored in the `type` column.
  final String dbValue;

  static HabitType fromDbValue(String? value) {
    return HabitType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => HabitType.yesNo,
    );
  }
}

class Habit {
  const Habit({
    this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.iconCodePoint,
    this.goalValue,
    this.unit,
    required this.createdAt,
    this.sortOrder = 0,
    this.description,
    this.reminderMinutes,
    this.reminderDays = 127,
  });

  final int? id;
  final String name;
  final HabitType type;

  /// ARGB color stored as an int.
  final int color;

  final int iconCodePoint;
  final double? goalValue;
  final String? unit;
  final DateTime createdAt;

  /// Manual position on the home screen (lower shows first).
  final int sortOrder;

  /// Optional free-text note about the habit.
  final String? description;

  /// Reminder time as minutes since midnight (0-1439); null means no reminder.
  /// When set, the reminder repeats on the selected [reminderDays].
  final int? reminderMinutes;

  /// Bitmask of reminder weekdays, with Monday as bit 0 and Sunday as bit 6.
  /// All seven days is the default for existing daily reminders.
  final int reminderDays;

  static Habit fromMap(Map<String, Object?> map) {
    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: HabitType.fromDbValue(map['type'] as String?),
      color: (map['color'] as int?) ?? 0xFF6750A4,
      iconCodePoint: (map['icon_code_point'] as int?) ?? 0xE87D,
      goalValue: (map['goal_value'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      sortOrder: (map['sort_order'] as int?) ?? 0,
      description: map['description'] as String?,
      reminderMinutes: map['reminder_minutes'] as int?,
      reminderDays: (map['reminder_days'] as int?) ?? 127,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'name': name,
      'type': type.dbValue,
      'color': color,
      'icon_code_point': iconCodePoint,
      'goal_value': goalValue,
      'unit': unit,
      'created_at': createdAt.millisecondsSinceEpoch,
      'sort_order': sortOrder,
      'description': description,
      'reminder_minutes': reminderMinutes,
      'reminder_days': reminderDays,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  Habit copyWith({
    int? id,
    String? name,
    HabitType? type,
    int? color,
    int? iconCodePoint,
    double? goalValue,
    String? unit,
    DateTime? createdAt,
    int? sortOrder,
    String? description,
    int? reminderMinutes,
    int? reminderDays,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      goalValue: goalValue ?? this.goalValue,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      description: description ?? this.description,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderDays: reminderDays ?? this.reminderDays,
    );
  }
}
