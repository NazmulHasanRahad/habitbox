import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/habit_controller.dart';
import '../widgets/app_bar_shell.dart';
import 'analytics_screen.dart';
import 'task_calendar_screen.dart';
import 'task_stats_screen.dart';

/// Top-level menu: the destinations that are not reachable from the habit and
/// task tabs themselves, plus the one home-list preference worth a switch.
///
/// Every entry pushes an existing screen — nothing here owns state or data.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<HabitController>();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(
          'Menu',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          const _SectionLabel('Insights'),
          _MenuTile(
            icon: Icons.insights_outlined,
            title: 'Habit analytics',
            subtitle: 'Completion over the last 7, 30 or 90 days',
            onTap: () => Get.to(() => const AnalyticsScreen()),
          ),
          _MenuTile(
            icon: Icons.insights,
            title: 'Task statistics',
            subtitle: 'Streaks, daily record and where things stand',
            onTap: () => Get.to(() => const TaskStatsScreen()),
          ),
          _MenuTile(
            icon: Icons.calendar_month_outlined,
            title: 'Calendar',
            subtitle: 'Browse tasks by day',
            onTap: () => Get.to(() => const TaskCalendarScreen()),
          ),
          const _SectionLabel('Appearance'),
          Obx(
            () => _MenuSwitchTile(
              icon: controller.compactView.value
                  ? Icons.view_list
                  : Icons.dashboard,
              title: 'Compact list',
              subtitle: controller.compactView.value
                  ? 'One-line rows on the habit list'
                  : 'Full chart cards on the habit list',
              value: controller.compactView.value,
              onChanged: (compact) =>
                  controller.setViewMode(compact: compact),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// A tappable menu row: icon, title, subtitle and a chevron.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                _TileIcon(icon: icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The same row, but the trailing control is a switch rather than a chevron.
class _MenuSwitchTile extends StatelessWidget {
  const _MenuSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _TileIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: scheme.primary),
    );
  }
}
