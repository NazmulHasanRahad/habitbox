import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';

/// Daily habit reminders, one repeating notification per habit.
///
/// The notification id is the habit's own row id, so a habit's reminder can be
/// rescheduled or cancelled without disturbing any other. Every method is a
/// no-op until [initialize] has succeeded — that keeps widget tests, which
/// have no platform channel, working without a mock.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'habit_reminders';
  static const String _channelName = 'Habit reminders';
  static const String _channelDescription =
      'The daily reminder set on a habit.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Whether the service is ready to schedule reminders.
  bool get isReady => _ready;

  /// Loads the timezone database and the plugin. Safe to call more than once;
  /// a failure (unsupported platform, missing plugin) leaves the service
  /// disabled instead of throwing.
  Future<void> initialize() async {
    if (_ready) return;
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        // Permission is asked for at the moment a reminder is switched on,
        // not on first launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      _ready = await _plugin.initialize(settings: settings) ?? false;
    } catch (error) {
      debugPrint('Habit reminders are unavailable: $error');
      _ready = false;
    }
  }

  /// Asks for everything a reminder needs. Returns false when the user (or the
  /// platform) refuses, so the form can say so rather than quietly scheduling
  /// an alert that will never appear.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    var granted = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        if (await android.requestNotificationsPermission() == false) {
          granted = false;
        }
        // Exact delivery is a separate special access from Android 12 up.
        // Declining it only costs precision, so it never fails the request.
        await android.requestExactAlarmsPermission();
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null &&
          await ios.requestPermissions(alert: true, badge: true, sound: true) ==
              false) {
        granted = false;
      }
    } catch (error) {
      debugPrint('Could not request notification permission: $error');
      return false;
    }
    return granted;
  }

  /// Brings the reminder of [habit] in line with its stored time: schedules it,
  /// moves it, or clears it when the habit has none.
  Future<void> syncHabit(Habit habit) async {
    final id = habit.id;
    if (!_ready || id == null) return;
    try {
      await _plugin.cancel(id: id);
      final minutes = habit.reminderMinutes;
      if (minutes == null) return;
      await _schedule(id, habit, minutes);
    } catch (error) {
      debugPrint('Could not schedule the reminder for habit $id: $error');
    }
  }

  /// Drops the reminder of a habit that no longer exists.
  Future<void> cancelHabit(int habitId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: habitId);
    } catch (error) {
      debugPrint('Could not cancel the reminder for habit $habitId: $error');
    }
  }

  /// Re-applies every reminder. Run once per launch so a reminder lost to a
  /// clock change or a restore comes back.
  Future<void> syncAll(Iterable<Habit> habits) async {
    for (final habit in habits) {
      await syncHabit(habit);
    }
  }

  Future<void> _schedule(int id, Habit habit, int minutes) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: Color(habit.color),
        showWhen: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final description = habit.description?.trim();
    String body = (description == null || description.isEmpty)
        ? 'Time for your habit.'
        : description;

    // Add goal information if it's a numeric habit.
    if (habit.type != HabitType.yesNo && habit.goalValue != null) {
      final goalStr =
          habit.goalValue! % 1 == 0
              ? habit.goalValue!.toInt().toString()
              : habit.goalValue!.toString();
      final unitStr = habit.unit?.trim() ?? '';
      final goalLine = 'Daily goal: $goalStr $unitStr'.trim();
      body = body == 'Time for your habit.' ? goalLine : '$body\n$goalLine';
    }

    Future<void> scheduleAt(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: id,
      title: habit.name,
      body: body,
      scheduledDate: _nextOccurrence(minutes),
      notificationDetails: details,
      androidScheduleMode: mode,
      // Fires again the same time every day.
      matchDateTimeComponents: DateTimeComponents.time,
    );

    try {
      await scheduleAt(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Android 14+ withholds exact alarms by default; a slightly late
      // reminder still beats none.
      await scheduleAt(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Today at [minutes] past midnight, or tomorrow once that moment has gone
  /// by. Rebuilt from calendar fields rather than by adding a day, so a DST
  /// change cannot move the wall-clock time the reminder is set for.
  static tz.TZDateTime _nextOccurrence(int minutes) {
    final now = tz.TZDateTime.now(tz.local);
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (today.isAfter(now)) return today;
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
}
