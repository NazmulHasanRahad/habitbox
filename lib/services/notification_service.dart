import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';

/// Weekly habit reminders, one repeating notification per selected weekday.
///
/// Each habit reserves seven notification ids, one per weekday, so its
/// reminders can be rescheduled without disturbing another habit.
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
      await _initializeLocalTimezone();

      const settings = InitializationSettings(
        // The plugin expects the resource name, without an @drawable prefix.
        android: AndroidInitializationSettings('ic_notification'),
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
      if (!_ready) {
        debugPrint('Habit notification plugin did not initialize.');
      }
    } catch (error) {
      debugPrint('Habit reminders are unavailable: $error');
      _ready = false;
    }
  }

  /// A missing timezone plugin or a custom device timezone must not prevent
  /// notification setup. The fallback preserves the current local offset.
  Future<void> _initializeLocalTimezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      final now = DateTime.now();
      final offset = now.timeZoneOffset.inMilliseconds;
      tz.setLocalLocation(
        tz.Location('Local', const <int>[], const <int>[], <tz.TimeZone>[
          tz.TimeZone(offset, isDst: false, abbreviation: now.timeZoneName),
        ]),
      );
      debugPrint('Using local-offset timezone fallback: $error');
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
      for (var day = 0; day < 7; day++) {
        await _plugin.cancel(id: _notificationId(id, day));
      }
      final minutes = habit.reminderMinutes;
      if (minutes == null || habit.reminderDays == 0) return;
      for (var day = 0; day < 7; day++) {
        if ((habit.reminderDays & (1 << day)) != 0) {
          await _schedule(_notificationId(id, day), habit, minutes, day);
        }
      }
    } catch (error) {
      debugPrint('Could not schedule the reminder for habit $id: $error');
    }
  }

  /// Drops the reminder of a habit that no longer exists.
  Future<void> cancelHabit(int habitId) async {
    if (!_ready) return;
    try {
      for (var day = 0; day < 7; day++) {
        await _plugin.cancel(id: _notificationId(habitId, day));
      }
    } catch (error) {
      debugPrint('Could not cancel the reminder for habit $habitId: $error');
    }
  }

  /// Re-applies every reminder. Run once per launch so a reminder lost to a
  /// clock change or a restore comes back.
  Future<void> syncAll(Iterable<Habit> habits) async {
    if (!_ready) return;
    try {
      // Also clears daily reminder ids used by older app versions.
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not clear old habit reminders: $error');
    }
    for (final habit in habits) {
      await syncHabit(habit);
    }
  }

  Future<void> _schedule(
    int id,
    Habit habit,
    int minutes,
    int weekdayIndex,
  ) async {
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
      final goalStr = habit.goalValue! % 1 == 0
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
      scheduledDate: _nextOccurrence(minutes, weekdayIndex),
      notificationDetails: details,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    try {
      await scheduleAt(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Android 14+ withholds exact alarms by default; a slightly late
      // reminder still beats none.
      await scheduleAt(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  static int _notificationId(int habitId, int weekdayIndex) =>
      habitId * 8 + weekdayIndex + 1;

  /// Finds the next occurrence of [weekdayIndex] (Monday is 0) at [minutes].
  /// Calendar fields keep the wall-clock time stable across DST changes.
  static tz.TZDateTime _nextOccurrence(int minutes, int weekdayIndex) {
    final now = tz.TZDateTime.now(tz.local);
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final targetWeekday = weekdayIndex + 1;
    var daysAhead = (targetWeekday - now.weekday + 7) % 7;
    var occurrence = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysAhead,
      hour,
      minute,
    );
    if (!occurrence.isAfter(now)) {
      daysAhead += 7;
      occurrence = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + daysAhead,
        hour,
        minute,
      );
    }
    return occurrence;
  }
}
