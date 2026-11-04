import 'package:intl/intl.dart';

final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');

/// Canonical key for a day, used by [HabitEntry] and the DB unique constraint.
String dateKeyFor(DateTime date) => _dateKeyFormat.format(date);

/// The day a stored key stands for, at local midnight.
DateTime dateFromKey(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length != 3) return today;
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// Today at local midnight.
DateTime get today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Key for today in the device's local timezone.
String get todayDateKey => dateKeyFor(today);

/// Shifts a date by whole calendar days, correctly crossing month and year
/// boundaries (day-component arithmetic, not fixed 24h durations).
DateTime shiftDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole-calendar-day distance from [from] to [to] (DST-safe).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The last [count] calendar days, oldest first, ending with today.
List<DateTime> lastNDays(int count) =>
    List.generate(count, (i) => shiftDays(today, i - (count - 1)));
