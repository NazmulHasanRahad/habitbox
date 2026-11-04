import 'package:flutter/material.dart';

import '../utils/date_key.dart';

/// Thirty days behind, thirty ahead, as a row of day tiles.
///
/// Each tile is its own small card — the weekday on top, the number under it,
/// and a dot when the day holds work — so a whole fortnight reads at a glance
/// instead of as a line of numbers. The window is fixed, so scrolling never
/// runs out of road near the selected day, and the strip opens on that day
/// rather than on the edge of the range.
class TaskDateStrip extends StatefulWidget {
  const TaskDateStrip({
    super.key,
    required this.selectedDateKey,
    required this.onSelect,
    required this.hasTasksOn,
  });

  final String selectedDateKey;
  final ValueChanged<String> onSelect;

  /// Whether to put a dot inside a tile, so the strip doubles as a map of where
  /// the work actually is.
  final bool Function(String dateKey) hasTasksOn;

  static const double height = 70;

  /// The slot a tile lives in. The tile keeps 2dp of it on each side, which is
  /// the whole gap between two days.
  static const double _cellWidth = 46;
  static const double _tileRadius = 16;

  /// Days on either side of today the strip offers.
  static const int _window = 30;

  @override
  State<TaskDateStrip> createState() => _TaskDateStripState();
}

class _TaskDateStripState extends State<TaskDateStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // The strip is built before its scroll view has clients, so the opening
    // position has to wait for the first frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToSelected(animated: false),
    );
  }

  @override
  void didUpdateWidget(covariant TaskDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDateKey != widget.selectedDateKey) {
      _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final dates = _dates();
    final index = dates.indexWhere(
      (date) => dateKeyFor(date) == widget.selectedDateKey,
    );
    if (index < 0) return;
    // Centre the chosen tile, which is what keeps today in view when the strip
    // opens and when a day is picked at either edge.
    final target =
        (index * TaskDateStrip._cellWidth -
                (position.viewportDimension - TaskDateStrip._cellWidth) / 2)
            .clamp(0.0, position.maxScrollExtent);
    if (!animated) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  List<DateTime> _dates() => [
    for (var i = -TaskDateStrip._window; i <= TaskDateStrip._window; i++)
      shiftDays(today, i),
  ];

  @override
  Widget build(BuildContext context) {
    final dates = _dates();

    return SizedBox(
      height: TaskDateStrip.height,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemExtent: TaskDateStrip._cellWidth,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final key = dateKeyFor(date);
          return _DateTile(
            date: date,
            isToday: key == todayDateKey,
            selected: key == widget.selectedDateKey,
            hasTasks: widget.hasTasksOn(key),
            onTap: () => widget.onSelect(key),
          );
        },
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.isToday,
    required this.selected,
    required this.hasTasks,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool selected;
  final bool hasTasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // The number is the loud half of the tile and the weekday the quiet half,
    // on every state. The picked day wears the accent; today only borrows it,
    // so the strip still says which day it really is once the user scrolls off.
    final ink = selected
        ? scheme.onPrimary
        : isToday
        ? scheme.primary
        : scheme.onSurface;
    final label = selected
        ? scheme.onPrimary.withValues(alpha: 0.8)
        : isToday
        ? scheme.primary.withValues(alpha: 0.75)
        : scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: disableAnimations ? 0 : 180),
        curve: Curves.easeOutCubic,
        // Every tile is the same size; the selection is the fill and the
        // shadow, never a resize, so the row never shifts as days are picked.
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? null : scheme.onSurface.withValues(alpha: 0.06),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(scheme.primary, Colors.white, 0.14)!,
                    scheme.primary,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(TaskDateStrip._tileRadius),
          border: Border.all(
            color: !selected && isToday
                ? scheme.primary.withValues(alpha: 0.45)
                : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                _weekdayLabel(date),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: label,
                  fontSize: 10,
                  height: 1.1,
                  letterSpacing: 0.3,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${date.day}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: ink,
                fontSize: 18,
                height: 1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            // The dot holds its row whether the day has work or not, so the
            // numbers of every tile sit on one line.
            SizedBox(
              height: 12,
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasTasks
                        ? selected
                              ? scheme.onPrimary.withValues(alpha: 0.9)
                              : scheme.onSurfaceVariant
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 'Mon', 'Tue' … without pulling a locale-dependent formatter into a widget
/// that repaints on every filter change.
String _weekdayLabel(DateTime date) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
