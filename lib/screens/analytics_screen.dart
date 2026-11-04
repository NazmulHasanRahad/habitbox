import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../utils/analytics.dart';
import '../utils/habit_icon.dart';
import '../widgets/app_bar_shell.dart';
import 'habit_details_screen.dart';

/// Offline analytics for every habit at once: a completion ring, four headline
/// stats, a daily consistency chart and a sortable per-habit leaderboard for a
/// 7, 30 or 90 day window. Every number comes from the controller's in-memory
/// state through [AnalyticsReport].
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

/// How the leaderboard is ordered.
enum _Sort {
  performance('Performance'),
  streak('Longest streak'),
  name('Name');

  const _Sort(this.label);

  final String label;
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const List<int> _windows = <int>[7, 30, 90];
  static const double _chartHeight = 132;
  static const double _axisWidth = 32;
  static const double _maxBarWidth = 14;

  /// The three bands a day is read in: fully done, half done, slipped. The
  /// green and the red are the very hues the task statistics wear, so 'done' and
  /// 'slipped' never change colour between the two screens — and `ColorScheme`
  /// is not used for them, because a dark theme's `error` is a pale pink that
  /// reads as nothing at all on a bar. Light mode pulls each band toward black,
  /// the way a colour that glows on a dark card thins out on a pale one.
  static const Color _metDark = Color(0xFF52CFA5);
  static const Color _onTrackDark = Color(0xFFFFC107);
  static const Color _behindDark = Color(0xFFEF747B);

  static Color _band(ColorScheme scheme, Color dark) =>
      scheme.brightness == Brightness.dark
      ? dark
      : Color.lerp(dark, Colors.black, 0.28)!;

  static final DateFormat _dayTooltip = DateFormat('EEE d MMM');
  static final DateFormat _rangeLabel = DateFormat('d MMM');

  int _window = 30;
  _Sort _sort = _Sort.performance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<HabitController>();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            Text(
              'Understand your progress',
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
        // Every observable is read here; the widgets below only ever see the
        // finished, plain [AnalyticsReport].
        final report = AnalyticsReport.build(
          habits: controller.habits.toList(),
          entries: {
            for (final entry in controller.entries.entries)
              entry.key: Map<String, double>.from(entry.value),
          },
          windowDays: _window,
        );
        if (!report.hasData) return const _EmptyState();
        return _body(report, theme);
      }),
    );
  }

  Widget _body(AnalyticsReport report, ThemeData theme) {
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
        _hero(report, scheme),
        const SizedBox(height: 12),
        _stats(report, scheme),
        const SizedBox(height: 12),
        _consistency(report, scheme),
        const SizedBox(height: 12),
        _performance(report, scheme),
        const SizedBox(height: 12),
        _insights(report, scheme),
        const SizedBox(height: 16),
        _footnote(scheme),
      ],
    );
  }

  // ----- Cards ---------------------------------------------------------------

  Widget _card(
    ColorScheme scheme,
    Widget child, {
    Gradient? gradient,
    Color? border,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? scheme.surfaceContainerHigh : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border ?? scheme.onSurface.withValues(alpha: 0.07),
        ),
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

  /// Ring, headline numbers and the exact date range the window covers.
  Widget _hero(AnalyticsReport report, ColorScheme scheme) {
    final percent = (report.rate * 100).round();
    final days = report.days;
    final range =
        '${_rangeLabel.format(days.first.date)} – ${_rangeLabel.format(days.last.date)}';

    return _card(
      scheme,
      Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      value: report.rate,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      // The green of a day fully done, so the headline rate and
                      // the chart underneath speak the same colour.
                      color: _band(scheme, _metDark),
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 62,
                      child: Text(
                        'Completion rate',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1.25,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${report.completed} of ${report.scheduled}',
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  'habit-days completed',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.date_range_outlined,
                      size: 14,
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

  /// Four tiles side by side. Monospace labels are wide, so they scale down to
  /// their tile instead of ellipsizing away a word.
  Widget _stats(AnalyticsReport report, ColorScheme scheme) {
    final best = report.bestHabit;
    final tiles = <_StatTileData>[
      _StatTileData(
        icon: Icons.star_border,
        tint: scheme.primary,
        value: '${report.perfectDays}',
        label: 'Perfect days',
        caption: 'every habit met',
      ),
      _StatTileData(
        icon: Icons.local_fire_department_outlined,
        tint: const Color(0xFFFF7A3D),
        value: '${report.activeStreak}',
        label: 'Active streak',
        caption: 'days in a row',
      ),
      _StatTileData(
        icon: Icons.event_available_outlined,
        tint: const Color(0xFF4FA3FF),
        value: '${report.loggedDays}',
        label: 'Days logged',
        caption: 'of ${report.trackedDays} tracked',
      ),
      _StatTileData(
        icon: Icons.emoji_events_outlined,
        tint: const Color(0xFF3DDC84),
        value: best == null ? '—' : best.habit.name,
        label: 'Most consistent',
        caption: best == null
            ? 'nothing tracked yet'
            : '${(best.rate * 100).round()}% completion',
        habitId: best?.habit.id,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              data: tiles[i],
              scheme: scheme,
              onTap: tiles[i].habitId == null
                  ? null
                  : () => Get.to(
                      () => HabitDetailsScreen(habitId: tiles[i].habitId!),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _consistency(AnalyticsReport report, ColorScheme scheme) {
    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(
            scheme,
            icon: Icons.show_chart,
            title: 'Daily consistency',
            subtitle: 'Completion rate over the last ${report.windowDays} days',
          ),
          const SizedBox(height: 12),
          _legend(scheme),
          const SizedBox(height: 12),
          _chart(report, scheme),
        ],
      ),
    );
  }

  Widget _legend(ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        _legendChip(scheme, _band(scheme, _behindDark), '< 50%'),
        _legendChip(scheme, _band(scheme, _onTrackDark), '50–99%'),
        _legendChip(scheme, _band(scheme, _metDark), '100%'),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

  /// Percentage gridlines behind bars that are as tall as that day's rate.
  Widget _chart(AnalyticsReport report, ColorScheme scheme) {
    final days = report.days;
    const fractions = <double>[1, 0.75, 0.5, 0.25, 0];
    final step = (days.length / 4).ceil();

    return Column(
      key: const ValueKey('analytics-chart'),
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
                    for (final fraction in fractions)
                      Text(
                        '${(fraction * 100).round()}%',
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
                    for (final fraction in fractions)
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
                          key: const ValueKey('analytics-bar-strip'),
                          children: [
                            for (final day in days)
                              Expanded(
                                child: Tooltip(
                                  message:
                                      '${_dayTooltip.format(day.date)} · '
                                      '${day.hasTarget ? '${day.completed} of ${day.scheduled}' : 'not tracked yet'}',
                                  child: LayoutBuilder(
                                    builder: (context, constraints) => Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: (constraints.maxWidth - 2.4)
                                            .clamp(2.0, _maxBarWidth),
                                        height: day.hasTarget
                                            ? 4 + day.rate * (_chartHeight - 8)
                                            : 3,
                                        decoration: BoxDecoration(
                                          color: day.hasTarget
                                              ? _tier(day.rate, scheme)
                                              : scheme.onSurface.withValues(
                                                  alpha: 0.06,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
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

  Widget _performance(AnalyticsReport report, ColorScheme scheme) {
    final stats = _sorted(report.habits);

    return _card(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardHeader(
                  scheme,
                  icon: Icons.leaderboard,
                  title: 'Habit performance',
                  subtitle: '${stats.length} habits in this period',
                ),
              ),
              _SortButton(
                sort: _sort,
                onPick: (value) => setState(() => _sort = value),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < stats.length; i++)
            _habitRow(stats[i], scheme, showDivider: i != stats.length - 1),
        ],
      ),
    );
  }

  List<HabitStat> _sorted(List<HabitStat> stats) {
    final sorted = List<HabitStat>.from(stats);
    if (_sort == _Sort.performance) {
      sorted.sort((a, b) {
        final byRate = b.rate.compareTo(a.rate);
        return byRate != 0 ? byRate : b.completed.compareTo(a.completed);
      });
    } else if (_sort == _Sort.streak) {
      sorted.sort((a, b) {
        final byStreak = b.currentStreak.compareTo(a.currentStreak);
        return byStreak != 0 ? byStreak : b.rate.compareTo(a.rate);
      });
    } else {
      sorted.sort(
        (a, b) =>
            a.habit.name.toLowerCase().compareTo(b.habit.name.toLowerCase()),
      );
    }
    return sorted;
  }

  Widget _habitRow(
    HabitStat stat,
    ColorScheme scheme, {
    required bool showDivider,
  }) {
    final habit = stat.habit;
    final accent = Color(habit.color);
    final id = habit.id;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: id == null
          ? null
          : () => Get.to(() => HabitDetailsScreen(habitId: id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: Icon(
                habitIconData(habit.iconCodePoint),
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _detail(stat),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: stat.rate,
                      minHeight: 5,
                      backgroundColor: accent.withValues(alpha: 0.13),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Text(
              '${(stat.rate * 100).round()}%',
              style: TextStyle(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insights(AnalyticsReport report, ColorScheme scheme) {
    final best = report.bestHabit;
    final weakest = report.weakestHabit;
    if (best == null) return const SizedBox.shrink();

    final cards = <Widget>[
      _insightCard(
        scheme,
        icon: Icons.trending_up,
        tint: const Color(0xFF3DDC84),
        label: 'Best habit',
        stat: best,
      ),
      if (weakest != null)
        _insightCard(
          scheme,
          icon: Icons.priority_high,
          tint: Color.lerp(scheme.error, Colors.white, 0.2)!,
          label: 'Needs attention',
          stat: weakest,
        ),
    ];

    if (cards.length < 2) return Column(children: cards);

    return Row(
      children: [
        Expanded(child: cards.first),
        const SizedBox(width: 10),
        Expanded(child: cards.last),
      ],
    );
  }

  Widget _insightCard(
    ColorScheme scheme, {
    required IconData icon,
    required Color tint,
    required String label,
    required HabitStat stat,
  }) {
    final id = stat.habit.id;
    return Material(
      color: tint.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: id == null
            ? null
            : () => Get.to(() => HabitDetailsScreen(habitId: id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tint.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: tint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(stat.rate * 100).round()}% completion rate',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
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
            'All calculations are done on this device, starting from the day '
            'each habit was created.',
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

  /// Which band a rate falls in. Compared against the raw rate, never a rounded
  /// percent, so 49.5% cannot read as a half-done day.
  Color _tier(double rate, ColorScheme scheme) {
    if (rate >= 1) return _band(scheme, _metDark);
    if (rate >= 0.5) return _band(scheme, _onTrackDark);
    return _band(scheme, _behindDark);
  }

  String _detail(HabitStat stat) {
    final parts = <String>['${stat.completed} of ${stat.scheduled} days'];
    if (stat.currentStreak >= 2) parts.add('${stat.currentStreak} day streak');
    if (stat.habit.type != HabitType.yesNo && stat.totalValue > 0) {
      parts.add(
        '${_format(stat.totalValue)}${stat.unit.isEmpty ? '' : ' ${stat.unit}'} logged',
      );
    }
    return parts.join(' · ');
  }

  static String _format(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
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

class _StatTileData {
  const _StatTileData({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    required this.caption,
    this.habitId,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final String caption;
  final int? habitId;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data, required this.scheme, this.onTap});

  final _StatTileData data;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
        ),
      ),
    );
  }

  /// One fixed-height text line: the four tiles stay the same height whatever
  /// the wording, and a label too wide for its tile shrinks instead of losing
  /// a word.
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

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onPick});

  final _Sort sort;
  final ValueChanged<_Sort> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<_Sort>(
      tooltip: 'Sort habits',
      initialValue: sort,
      onSelected: onPick,
      itemBuilder: (context) => [
        for (final option in _Sort.values)
          PopupMenuItem(
            value: option,
            child: Text(
              option.label,
              style: TextStyle(
                fontSize: 13,
                color: option == sort ? scheme.primary : scheme.onSurface,
                fontWeight: option == sort ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                sort.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
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
            Icons.insights_outlined,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'No habits to analyse',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a habit and your progress will show up here.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
