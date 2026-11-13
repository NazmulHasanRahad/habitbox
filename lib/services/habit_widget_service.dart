import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/habit.dart';
import '../utils/date_key.dart';

/// Publishes a compact habit snapshot for Android home-screen widgets.
class HabitWidgetService {
  HabitWidgetService._();

  static const MethodChannel _channel = MethodChannel('habitbox/widgets');
  static const int historyDays = 182;

  static List<Map<String, Object?>> buildWidgetData(
    Iterable<Habit> habits,
    Map<int, Map<String, double>> entries,
  ) {
    return [
      for (final habit in habits)
        if (habit.id != null)
          <String, Object?>{
            'id': habit.id,
            'name': habit.name,
            'description': habit.description ?? '',
            'color': habit.color,
            'type': habit.type.dbValue,
            'iconCodePoint': habit.iconCodePoint,
            'todayFraction': _todayFraction(habit, entries[habit.id!]),
            'completedByDate': {
              for (var ago = historyDays - 1; ago >= 0; ago--)
                dateKeyFor(shiftDays(today, -ago)): _isComplete(
                  habit,
                  entries[habit.id!]?[dateKeyFor(shiftDays(today, -ago))],
                ),
            },
          },
    ];
  }

  static Future<bool> requestPin() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPin') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Could not request an Android habit widget: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Android habit widget bridge is unavailable: $error');
    }
    return false;
  }

  /// Today's progress toward the goal as 0..1, for the widget's mark button.
  /// Yes/no habits report 1 once marked, 0 otherwise.
  static double _todayFraction(Habit habit, Map<String, double>? dayEntries) {
    final value = dayEntries?[todayDateKey] ?? 0;
    if (habit.type == HabitType.yesNo) return value >= 0.5 ? 1 : 0;
    final goal = habit.goalValue;
    if (goal == null || goal <= 0) return value > 0 ? 1 : 0;
    return (value / goal).clamp(0.0, 1.0);
  }

  /// Registers the handler the Android widget's mark button calls through.
  /// [onToggleToday] receives the habit id; returning without doing anything
  /// leaves non-toggleable habits untouched.
  static void setToggleHandler(
    Future<void> Function(int habitId) onToggleToday,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'toggleToday') return null;
      final id = call.arguments;
      if (id is int) await onToggleToday(id);
      return null;
    });
  }

  static bool _isComplete(Habit habit, double? value) {
    if (value == null) return false;
    if (habit.type == HabitType.yesNo) return value >= 0.5;
    final goal = habit.goalValue;
    if (goal == null || goal <= 0) return value > 0;
    return value >= goal;
  }

  static Future<void> sync(
    Iterable<Habit> habits,
    Map<int, Map<String, double>> entries,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(
        'syncData',
        jsonEncode(buildWidgetData(habits, entries)),
      );
    } on PlatformException catch (error) {
      debugPrint('Could not update Android habit widgets: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Android habit widget bridge is unavailable: $error');
    }
  }
}
