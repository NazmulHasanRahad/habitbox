import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../utils/date_key.dart';
import '../utils/habit_icon.dart';
import 'habit_value_sheet.dart';

/// Shared geometry for the compact list's date header and its rows. Both are
/// laid out at the same width, so they derive the same cell size and the
/// columns always line up.
class CompactWeek {
  const CompactWeek._();

  static const int days = 7;

  /// A day owns [slotFor] pixels of width and this much height, which keeps
  /// the gutter between cells inside the tap target.
  static const double slotHeight = 40;

  static const double avatarSize = 34;
  static const double avatarGap = 10;
  static const double stripGap = 8;

  /// The name column gives way last, so long names survive narrow screens.
  static const double nameMin = 74;
  static const double cellMin = 15;
  static const double cellMax = 24;

  /// One slot is a cell plus a 28% gutter.
  static const double _slotRatio = 1.28;

  static const double radius = 18;

  static double cellSize(double contentWidth) {
    final room = contentWidth - avatarSize - avatarGap - stripGap - nameMin;
    return (room / (days * _slotRatio)).clamp(cellMin, cellMax).toDouble();
  }

  static double slotFor(double cell) => cell * _slotRatio;

  /// Oldest first, ending with today.
  static List<DateTime> dates() => lastNDays(days);
}

/// Top segment of the compact list: the habit count plus the weekday/day
/// columns every row underneath lines up with.
class CompactWeekHeader extends StatelessWidget {
  const CompactWeekHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(CompactWeek.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: _hairline(scheme),
            left: _hairline(scheme),
            right: _hairline(scheme),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = CompactWeek.slotFor(
              CompactWeek.cellSize(constraints.maxWidth),
            );
            final muted = scheme.onSurfaceVariant;

            return Row(
              children: [
                Text(
                  count == 1 ? '1 HABIT' : '$count HABITS',
                  style: TextStyle(
                    color: muted.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    height: 1.1,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                for (final day in CompactWeek.dates())
                  SizedBox(
                    width: slot,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weekdayLabel(day),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: muted.withValues(alpha: 0.75),
                            fontSize: 9,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${day.day}',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 11.5,
                            height: 1.25,
                            fontWeight: day.day == today.day
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Three letters, e.g. `Sun`.
  static String _weekdayLabel(DateTime day) => DateFormat('EEE').format(day);
}

/// One habit row of the compact list: icon, name, today's progress line and a
/// cell per day for the last week. Only today's cell reacts to a tap — the
/// older cells are history, exactly like the card view.
class CompactHabitRow extends StatelessWidget {
  const CompactHabitRow({
    super.key,
    required this.habit,
    required this.onTap,
    required this.isLast,
  });

  final Habit habit;
  final VoidCallback onTap;

  /// Closes the group with rounded corners.
  final bool isLast;

  static const double contentMinHeight = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = Get.find<HabitController>();
    final accent = _accent(context);
    final corners = isLast
        ? const BorderRadius.vertical(
            bottom: Radius.circular(CompactWeek.radius),
          )
        : BorderRadius.zero;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: corners,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: corners,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: _hairline(scheme),
              left: _hairline(scheme),
              right: _hairline(scheme),
              bottom: isLast ? _hairline(scheme) : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Obx(() {
            // Snapshot the entries inside the Obx so a saved value repaints
            // the cells; the row itself is built from this map.
            final values =
                controller.entries[habit.id] ?? const <String, double>{};

            return LayoutBuilder(
              builder: (context, constraints) =>
                  _row(context, values, accent, constraints.maxWidth),
            );
          }),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    Map<String, double> values,
    Color accent,
    double contentWidth,
  ) {
    final cell = CompactWeek.cellSize(contentWidth);
    final slot = CompactWeek.slotFor(cell);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: contentMinHeight),
      child: Row(
        children: [
          _avatar(accent),
          const SizedBox(width: CompactWeek.avatarGap),
          Expanded(child: _texts(context, values)),
          const SizedBox(width: CompactWeek.stripGap),
          for (final day in CompactWeek.dates())
            _dayCell(
              context: context,
              day: day,
              value: values[dateKeyFor(day)] ?? 0,
              cell: cell,
              slot: slot,
              accent: accent,
            ),
        ],
      ),
    );
  }

  /// The habit colour carries the row, so it is lifted on dark surfaces and
  /// softened on light ones instead of being used raw.
  Color _accent(BuildContext context) {
    final base = Color(habit.color);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Color.lerp(
      base,
      dark ? Colors.white : Colors.black,
      dark ? 0.45 : 0.1,
    )!;
  }

  Widget _avatar(Color accent) {
    return Container(
      width: CompactWeek.avatarSize,
      height: CompactWeek.avatarSize,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Icon(habitIconData(habit.iconCodePoint), size: 18, color: accent),
    );
  }

  Widget _texts(BuildContext context, Map<String, double> values) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      // A list gives its rows unbounded height, so the text column must not
      // stretch to the incoming maximum.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          habit.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 13.5,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _subtitle(values),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 10.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  /// Today's progress line. Count and measure put the unit here, which is the
  /// only place it appears in the row.
  String _subtitle(Map<String, double> values) {
    final value = values[todayDateKey] ?? 0;
    if (habit.type == HabitType.yesNo) {
      return value >= 0.5 ? 'Done today' : 'Not marked yet';
    }
    final unit = habit.unit?.trim();
    final suffix = unit == null || unit.isEmpty ? '' : ' $unit';
    final goal = habit.goalValue;
    if (goal != null && goal > 0) {
      return '${_format(value)} / ${_format(goal)}$suffix';
    }
    return value > 0 ? '${_format(value)}$suffix logged' : 'Nothing logged yet';
  }

  Widget _dayCell({
    required BuildContext context,
    required DateTime day,
    required double value,
    required double cell,
    required double slot,
    required Color accent,
  }) {
    final isToday = dateKeyFor(day) == todayDateKey;
    final scheme = Theme.of(context).colorScheme;
    final state = _stateFor(value);
    // A reached goal reads as a solid tile, an open day as a ring; yes/no is
    // always square so the three types stay distinguishable at a glance.
    final square = habit.type == HabitType.yesNo || state == _DayState.filled;

    final glyph = switch (state) {
      _DayState.filled => Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(cell * 0.32),
        ),
      ),
      _DayState.partial => SizedBox(
        width: cell,
        height: cell,
        child: CircularProgressIndicator(
          value: _progress(value),
          strokeWidth: 2.6,
          strokeCap: StrokeCap.round,
          color: accent,
          backgroundColor: accent.withValues(alpha: 0.18),
        ),
      ),
      _DayState.empty => Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          color: square ? accent.withValues(alpha: 0.10) : null,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(cell * 0.32) : null,
          border: Border.all(
            color: accent.withValues(alpha: square ? 0.26 : 0.22),
            width: 1.4,
          ),
        ),
      ),
    };

    // Today carries only a hairline ring, so the marker stays readable on
    // every state without covering the habit colour underneath it.
    final marked = !isToday
        ? glyph
        : Container(
            width: cell + 4,
            height: cell + 4,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cell * 0.32 + 2),
              border: Border.all(color: scheme.onSurfaceVariant, width: 1.4),
            ),
            child: glyph,
          );

    final slotBox = SizedBox(
      width: slot,
      height: CompactWeek.slotHeight,
      child: Center(child: marked),
    );
    if (!isToday) return slotBox;

    // The ring is decoration only, so the whole slot stays the touch target
    // instead of just the glyph inside it.
    return Tooltip(
      message: _todayTooltip(value),
      child: GestureDetector(
        // Opaque so a tap here never falls through to the row.
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTodayTap(context),
        child: slotBox,
      ),
    );
  }

  _DayState _stateFor(double value) {
    if (habit.type == HabitType.yesNo) {
      return value >= 0.5 ? _DayState.filled : _DayState.empty;
    }
    final goal = habit.goalValue;
    if (goal == null || goal <= 0) {
      return value > 0 ? _DayState.filled : _DayState.empty;
    }
    if (value >= goal) return _DayState.filled;
    return value > 0 ? _DayState.partial : _DayState.empty;
  }

  double _progress(double value) {
    final goal = habit.goalValue;
    if (goal == null || goal <= 0) return 0;
    return (value / goal).clamp(0.0, 1.0);
  }

  String _todayTooltip(double value) {
    if (habit.type == HabitType.yesNo) {
      return value >= 0.5 ? 'Unmark today' : 'Mark today';
    }
    return value > 0 ? 'Edit today' : 'Log today';
  }

  void _onTodayTap(BuildContext context) {
    if (habit.type == HabitType.yesNo) {
      Get.find<HabitController>().toggleYesNo(habit, todayDateKey);
    } else {
      HabitValueSheet.show(context, habit);
    }
  }

  static String _format(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
}

BorderSide _hairline(ColorScheme scheme) =>
    BorderSide(color: scheme.onSurface.withValues(alpha: 0.07));

enum _DayState { empty, partial, filled }
