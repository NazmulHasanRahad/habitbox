import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/task_controller.dart';
import '../utils/task_analytics.dart';
import '../utils/task_palette.dart';
import '../widgets/app_bar_shell.dart';

/// The task record for a 7, 30 or 90 day window: what each day carried and what
/// got finished on it, how that compares with the window before it, and where
/// the open work sits right now.
///
/// [TaskController.taskStats] answers every number, so this screen only arranges
/// and words them. A day with no record draws a stub rather than empty space, a
/// tile with nothing behind it reads as '—', and the breakdown keeps all five of
/// its lines so the card never changes shape as the list changes.
class TaskStatsScreen extends StatefulWidget {
  const TaskStatsScreen({super.key});

  @override
  State<TaskStatsScreen> createState() => _TaskStatsScreenState();
}

class _TaskStatsScreenState extends State<TaskStatsScreen> {
  static const List<int> _windows = <int>[7, 30, 90];
  static const double _chartHeight = 128;
  static const double _axisWidth = 24;
  static const double _maxBarWidth = 15;

  static final DateFormat _dayTooltip = DateFormat('EEE d MMM');
  static final DateFormat _rangeLabel = DateFormat('d MMM');
  static final DateFormat _weekdayLabel = DateFormat('EEEE');

  int _window = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<TaskController>();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            Text(
              'Your task record, day by day',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.25,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
      body: Obx(() {
        // The report reads the controller's lists, and it does it right here:
        // an Obx only tracks the observables its own closure touches.
        final error = controller.loadError.value;
        if (error.isNotEmpty) {
          return _ErrorState(message: error, onRetry: controller.loadTasks);
        }
        final loading = controller.isLoading.value;
        final stats = controller.taskStats(windowDays: _window);
        if (!stats.hasData) {
          return loading
              ? const Center(child: CircularProgressIndicator())
              : const _EmptyState();
        }
        return _body(stats, theme);
      }),
    );
  }

  Widget _body(TaskStats stats, ThemeData theme) {
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _PeriodSelector(
          windows: _windows,
          selected: _window,
          onPick: (days) => setState(() => _window = days),
        ),
        const SizedBox(height: 14),
        _hero(stats, scheme),
        const SizedBox(height: 12),
        _tiles(stats, scheme),
        const SizedBox(height: 12),
        _record(stats, scheme),
        const SizedBox(height: 12),
        _standing(stats, scheme),
        const SizedBox(height: 16),
        _footnote(scheme),
      ],
    );
  }

  // ----- Cards ---------------------------------------------------------------

  Widget _card(ColorScheme scheme, Widget child, {Gradient? gradient}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? scheme.surfaceContainerHigh : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.07)),
      ),
      child: child,
    );
  }

  Widget _cardHeader(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The window's own total, the change against the window before it, and how
  /// today looks at the same moment.
  Widget _hero(TaskStats stats, ColorScheme scheme) {
    final palette = TaskPalette(scheme);
    final range =
        '${_rangeLabel.format(stats.days.first.date)}'
        ' – ${_rangeLabel.format(stats.days.last.date)}';
    final openNow =
        stats.countOf(TaskBucketKind.slipped) +
        stats.countOf(TaskBucketKind.dueToday) +
        stats.countOf(TaskBucketKind.later) +
        stats.countOf(TaskBucketKind.undated);
    final change = stats.change;
    final changeTint = change > 0
        ? palette.success
        : change < 0
        ? palette.danger
        : scheme.onSurfaceVariant;
    final changeLabel = change == 0
        ? 'Level with the ${stats.windowDays} before'
        : '${change > 0 ? '+' : '−'}${change.abs()}'
              ' vs the ${stats.windowDays} before';

    return _card(
      scheme,
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${stats.completed}',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'finished',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.2,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: changeTint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change > 0
                            ? Icons.trending_up
                            : change < 0
                            ? Icons.trending_down
                            : Icons.swap_horiz_rounded,
                        size: 13,
                        color: changeTint,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          changeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: changeTint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      Icons.date_range_outlined,
                      size: 13,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        range,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 68,
            color: scheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TODAY',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.2,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 7),
              _heroLine(scheme, palette.success, stats.today.completed, 'done'),
              const SizedBox(height: 5),
              _heroLine(scheme, scheme.primary, openNow, 'open'),
            ],
          ),
        ],
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.surfaceContainerHigh,
          Color.lerp(scheme.surfaceContainerHigh, scheme.primary, 0.16)!,
        ],
      ),
    );
  }

  Widget _heroLine(ColorScheme scheme, Color tint, int value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 15,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, height: 1.2, color: tint)),
      ],
    );
  }

  /// Four tiles side by side. Monospace labels are wide, so each line scales
  /// down inside its own fixed-height slot instead of losing a word.
  Widget _tiles(TaskStats stats, ColorScheme scheme) {
    final palette = TaskPalette(scheme);
    final best = stats.bestDay;
    final tiles = <_TileData>[
      _TileData(
        icon: Icons.local_fire_department_outlined,
        tint: const Color(0xFFFF7A3D),
        value: '${stats.streak}',
        label: 'Day streak',
        caption: stats.streak == 0
            ? 'no run yet'
            : stats.today.completed > 0
            ? 'today counts too'
            : 'today still open',
      ),
      _TileData(
        icon: Icons.emoji_events_outlined,
        tint: scheme.primary,
        value: best == null ? '—' : '${best.completed}',
        label: 'Best day',
        caption: best == null ? 'nothing yet' : _weekdayLabel.format(best.date),
      ),
      _TileData(
        icon: Icons.event_available_outlined,
        tint: const Color(0xFF4FA3FF),
        value: '${stats.activeDays}',
        label: 'Days active',
        caption: 'of ${stats.windowDays}',
      ),
      _TileData(
        icon: Icons.checklist_rounded,
        tint: palette.success,
        value: stats.stepsTotal == 0 ? '—' : '${stats.stepsDone}',
        label: 'Steps done',
        caption: stats.stepsTotal == 0
            ? 'no steps yet'
            : 'of ${stats.stepsTotal}',
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Tile(data: tiles[i], scheme: scheme),
          ),
        ],
      ],
    );
  }

  Widget _record(TaskStats stats, ColorScheme scheme) {
    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(
            scheme,
            icon: Icons.bar_chart_rounded,
            title: 'Daily record',
            subtitle: 'Due as the bar, done as the fill',
          ),
          const SizedBox(height: 12),
         // _legend(scheme),
          const SizedBox(height: 12),
          _chart(stats, scheme),
        ],
      ),
    );
  }

  Widget _legend(ColorScheme scheme) {
    final palette = TaskPalette(scheme);
    final isDark = scheme.brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        _legendChip(scheme, Colors.white, 'Today'),
        _legendChip(scheme, palette.danger, 'Under 50%'),
        _legendChip(scheme, palette.caution, '50-99%'),
        _legendChip(scheme, palette.success, 'All done'),
        _legendChip(scheme, _track(scheme, isDark), 'Not done'),
      ],
    );
  }

  Widget _legendChip(ColorScheme scheme, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            // Every swatch carries a hairline, or the palest of them — today's
            // white, an empty day's grey — would read as a hole in the chip.
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.16),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// One bar per day: as tall as the tasks that day carried, filled as far as
  /// the record got, against the busiest day of the window.
  Widget _chart(TaskStats stats, ColorScheme scheme) {
    final days = stats.days;
    final isDark = scheme.brightness == Brightness.dark;
    // A window with nothing in it still needs an axis, so the scale tops out at
    // one rather than dividing a bar by zero.
    final top = stats.peak == 0 ? 1 : stats.peak;
    final todayKey = days.last.dateKey;
    final step = (days.length / 4).ceil();

    return Column(
      key: const ValueKey('task-stats-chart'),
      children: [
        SizedBox(
          height: _chartHeight,
          child: Row(
            children: [
              SizedBox(
                width: _axisWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final value in <int>[top, (top / 2).ceil(), 0])
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  children: [
                    for (final fraction in const <double>[1, 0.5, 0])
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: fraction * (_chartHeight - 0.7),
                        child: Container(
                          height: 0.7,
                          color: scheme.onSurface.withValues(alpha: 0.07),
                        ),
                      ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          key: const ValueKey('task-stats-bar-strip'),
                          children: [
                            for (final day in days)
                              Expanded(
                                child: Tooltip(
                                  message: day.total == 0
                                      ? '${_dayTooltip.format(day.date)} · '
                                            'nothing due'
                                      : '${_dayTooltip.format(day.date)} · '
                                            '${day.completed}/${day.total} done · '
                                            '${day.percent}%',
                                  child: LayoutBuilder(
                                    builder: (context, constraints) => Align(
                                      alignment: Alignment.bottomCenter,
                                      child: _dayBar(
                                        day,
                                        constraints.maxWidth,
                                        top,
                                        scheme,
                                        isDark,
                                        day.dateKey == todayKey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Seven bars leave room for their own numbers under the strip; past that
        // the slots are too narrow for text, so the bar and its tooltip carry it.
        if (days.length <= 7) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(width: _axisWidth + 6),
              Expanded(
                child: Row(
                  children: [
                    for (final day in days)
                      Expanded(
                        child: Text(
                          '${day.completed}/${day.total}',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: day.total == 0
                                ? scheme.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  )
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(width: _axisWidth + 6),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < days.length; i += step)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _rangeLabel.format(days[i].date),
                          style: TextStyle(
                            fontSize: 8.5,
                            height: 1.2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The body of a bar: what the day carried and has yet to finish. Light and
  /// dark wear it at different strengths, because the alpha that reads as a soft
  /// groove on a dark card all but vanishes on a pale one.
  static Color _track(ColorScheme scheme, bool isDark) =>
      scheme.onSurface.withValues(alpha: isDark ? 0.14 : 0.10);

  /// One day of the strip. Height answers 'how many', the fill inside it answers
  /// 'how many of those', and its colour answers 'how the day ended': red under
  /// half, yellow up to 99%, green when the whole day is clear.
  Widget _dayBar(
    TaskStatDay day,
    double slot,
    int top,
    ColorScheme scheme,
    bool isDark,
    bool isToday,
  ) {
    final width = (slot - 2.2).clamp(2.0, _maxBarWidth);
    final track = _track(scheme, isDark);
    // A day that carried nothing still gets the shortest mark, so the strip
    // reads as a run of days rather than a row with holes in it.
    if (day.total == 0) {
      return Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    final height = 4 + (day.total / top) * (_chartHeight - 14);
    // A day owed and never touched is 0%, the reddest band there is, so it gets
    // the floor sliver instead of staying an empty groove.
    final fillHeight = height * day.ratio;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(3),
      ),
      foregroundDecoration: isToday ? _todayRing(scheme, isDark) : null,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          height: fillHeight < 3 ? 3.0 : fillHeight,
          child: ColoredBox(color: _fillFor(day, scheme)),
        ),
      ),
    );
  }

  Color _fillFor(TaskStatDay day, ColorScheme scheme) {
    final palette = TaskPalette(scheme);
    if (day.allDone) return palette.success;
    return day.ratio < 0.5 ? palette.danger : palette.caution;
  }

  /// Today wears no extra colour — a white edge picks it out without competing
  /// with the three the fill can wear. Pure white all but disappears on a pale
  /// card, so light mode gives it a hairline of ink to sit on.
  BoxDecoration _todayRing(ColorScheme scheme, bool isDark) => BoxDecoration(
    border: Border.all(color: Colors.white, width: 1.1),
    borderRadius: BorderRadius.circular(3.5),
    boxShadow: isDark
        ? null
        : [
            BoxShadow(
              color: scheme.onSurface.withValues(alpha: 0.35),
              blurRadius: 0,
              spreadRadius: 0.6,
            ),
          ],
  );

  /// The list as it stands at this moment: one segment per line, then the
  /// lines themselves.
  Widget _standing(TaskStats stats, ColorScheme scheme) {
    final total = stats.buckets.fold<int>(
      0,
      (sum, bucket) => sum + bucket.count,
    );
    final filled = stats.buckets.where((bucket) => bucket.count > 0).toList();

    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(
            scheme,
            icon: Icons.donut_large_outlined,
            title: 'Where things stand',
            subtitle: total == 0
                ? 'Nothing left on the list'
                : '$total tasks, counted just now',
          ),
          const SizedBox(height: 14),
          if (total == 0)
            Text(
              'Every task on your list is finished. New work shows up here as '
              'soon as you add it.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (var i = 0; i < filled.length; i++)
                    Expanded(
                      flex: filled[i].count,
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == filled.length - 1 ? 0 : 2,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _tint(scheme, filled[i].kind),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          for (final bucket in stats.buckets)
            _bucketRow(
              scheme,
              bucket,
              showDivider: bucket != stats.buckets.last,
            ),
        ],
      ),
    );
  }

  Color _tint(ColorScheme scheme, TaskBucketKind kind) {
    final palette = TaskPalette(scheme);
    return switch (kind) {
      TaskBucketKind.slipped => palette.danger,
      TaskBucketKind.dueToday => scheme.primary,
      TaskBucketKind.later => const Color(0xFF4FA3FF),
      TaskBucketKind.undated => scheme.onSurfaceVariant,
      TaskBucketKind.doneToday => palette.success,
    };
  }

  Widget _bucketRow(
    ColorScheme scheme,
    TaskBucket bucket, {
    required bool showDivider,
  }) {
    final tint = _tint(scheme, bucket.kind);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bucket.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: bucket.count == 0
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
              ),
            ),
          ),
          Text(
            '${bucket.count}',
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w700,
              // A line with nothing on it stays quiet; only a real pile asks
              // for its colour.
              color: bucket.count == 0
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                  : tint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footnote(ColorScheme scheme) {
    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 14,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Every figure is counted on this device from the days your own '
            'tasks were marked done.',
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

/// 7 / 30 / 90 day switch: one full-width segmented control, the selected
/// segment lit with the app's primary.
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.windows,
    required this.selected,
    required this.onPick,
  });

  final List<int> windows;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          for (final days in windows)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: days == selected
                        ? LinearGradient(
                            colors: [
                              Color.lerp(scheme.primary, Colors.white, 0.18)!,
                              scheme.primary,
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '$days Days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: days == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: days == selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TileData {
  const _TileData({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final String caption;
}

/// One headline figure. Nothing here is tappable: a tile has no screen to go
/// to, so it does not pretend to.
class _Tile extends StatelessWidget {
  const _Tile({required this.data, required this.scheme});

  final _TileData data;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: data.tint.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 14, color: data.tint),
          ),
          const SizedBox(height: 7),
          _line(
            data.value,
            TextStyle(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            22,
          ),
          const SizedBox(height: 1),
          _line(
            data.label,
            TextStyle(
              fontSize: 9.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            12,
          ),
          _line(
            data.caption,
            TextStyle(
              fontSize: 8.5,
              height: 1.2,
              color: scheme.onSurfaceVariant,
            ),
            11,
          ),
        ],
      ),
    );
  }

  /// One fixed-height text line, so the four tiles keep the same height
  /// whatever the wording and a label too wide for its tile shrinks instead of
  /// losing a word.
  Widget _line(String text, TextStyle style, double height) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'No tasks to measure',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a task and your record starts building from today.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not read your tasks',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
