import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../widgets/app_bar_shell.dart';
import '../widgets/compact_habit_row.dart';
import '../widgets/habit_card.dart';
import 'add_habit_screen.dart';
import 'analytics_screen.dart';
import 'habit_details_screen.dart';

/// Home screen: scrollable list of habit cards, app-bar filter row,
/// empty state and add FAB.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Shared by both view modes so switching card/compact list keeps the
  /// scroll position instead of jumping back to the top.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HabitController>();
    final theme = Theme.of(context);

    // One Obx for the whole scaffold: the app bar badge, the view toggle, the
    // filter row and the list all read the same observables.
    return Obx(() {
      // Snapshot the filtered list here, not inside the lazy itemBuilder.
      final visible = List<Habit>.from(controller.visibleHabits);
      final hasHabits = controller.habits.isNotEmpty;
      final compact = controller.compactView.value;

      return Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                  children: const [
                    TextSpan(text: 'Habit'),
                    TextSpan(
                      text: 'Box',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              Text(
                _todayLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          actions: hasHabits
              ? [
                  _AnalyticsButton(onPressed: _openAnalytics),
                  _FilterButton(controller: controller),
                  _ViewModeButton(
                    compact: compact,
                    onPick: controller.setViewMode,
                  ),
                  AddAppBarButton(
                    tooltip: 'Add habit',
                    onPressed: _openAddHabit,
                  ),
                  const SizedBox(width: 15),
                ]
              : [
                  AddAppBarButton(
                    tooltip: 'Add habit',
                    onPressed: _openAddHabit,
                  ),
                  const SizedBox(width: 8),
                ],
          bottom: hasHabits
              ? _AppBarBottom(
                  controller: controller,
                  showFilters: controller.filtersOpen.value,
                )
              : null,
        ),
        // Every observable this list needs is read above, inside the Obx.
        body: _Body(
          theme: theme,
          visible: visible,
          hasHabits: hasHabits,
          compact: compact,
          filtering: controller.hasActiveFilter,
          loading: controller.isLoading.value && controller.habits.isEmpty,
          errorText: controller.loadError.value,
          scrollController: _scrollController,
          onRetry: controller.loadHabits,
          onClearFilters: controller.clearFilters,
          onReorder: controller.reorderHabits,
        ),
      );
    });
  }

  /// Formatted on every build so a screen left open across midnight does not
  /// keep showing yesterday.
  static String _todayLabel() =>
      DateFormat('EEEE, d MMMM').format(DateTime.now());

  void _openAddHabit() => Get.to(() => const AddHabitScreen());

  void _openAnalytics() => Get.to(() => const AnalyticsScreen());
}

class _Body extends StatelessWidget {
  const _Body({
    required this.theme,
    required this.visible,
    required this.hasHabits,
    required this.compact,
    required this.filtering,
    required this.loading,
    required this.errorText,
    required this.scrollController,
    required this.onRetry,
    required this.onClearFilters,
    required this.onReorder,
  });

  final ThemeData theme;
  final List<Habit> visible;
  final bool hasHabits;
  final bool compact;
  final bool filtering;
  final bool loading;
  final String errorText;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorText.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 8),
            Text('Could not load habits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              errorText,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (!hasHabits) {
      return const _EmptyState();
    }
    if (visible.isEmpty) {
      return _FilteredEmptyState(onClearFilters: onClearFilters);
    }

    Widget tile(int index) {
      final habit = visible[index];
      final isLast = index == visible.length - 1;
      void openDetails() =>
          Get.to(() => HabitDetailsScreen(habitId: habit.id!));

      return Padding(
        key: ValueKey(habit.id),
        // Compact rows are segments of one grouped card and butt against each
        // other; cards keep their own gap.
        padding: EdgeInsets.only(bottom: compact || isLast ? 0 : 12),
        child: compact
            // The row already owns its tap target and splash.
            ? CompactHabitRow(habit: habit, onTap: openDetails, isLast: isLast)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openDetails,
                child: HabitCard(habit: habit),
              ),
      );
    }

    // The list ends below the floating bottom navigation pill.
    const padding = EdgeInsets.fromLTRB(14, 8, 14, 104);
    final header = compact ? CompactWeekHeader(count: visible.length) : null;
    // Drag-to-reorder writes absolute positions, so it is only safe while the
    // list is unfiltered.
    if (filtering) {
      return ListView.builder(
        controller: scrollController,
        padding: padding,
        // This list has no header slot, so the week header rides along as
        // item zero.
        itemCount: visible.length + (header == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (header != null) {
            return index == 0 ? header : tile(index - 1);
          }
          return tile(index);
        },
      );
    }
    return ReorderableListView.builder(
      scrollController: scrollController,
      padding: padding,
      header: header,
      itemCount: visible.length,
      onReorder: onReorder,
      itemBuilder: (context, index) => tile(index),
    );
  }
}

/// Card/compact-list switch, now an app-bar control: the bottom slot belongs to
/// the navigation pill, so it shares the shells' size instead of floating.
/// The icon shows the mode in use; tapping flips to the other one.
class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({required this.compact, required this.onPick});

  final bool compact;
  final void Function({required bool compact}) onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: AppBarShell.gap),
      child: AppBarShell(
        active: compact,
        tooltip: compact
            ? 'Compact list · tap for cards'
            : 'Cards · tap for compact list',
        onTap: () => onPick(compact: !compact),
        child: Icon(
          compact ? Icons.view_list : Icons.dashboard,
          size: AppBarShell.iconSize,
          color: compact ? scheme.primary : appBarIconColor(scheme),
        ),
      ),
    );
  }
}

/// App-bar entry point for the cross-habit analytics screen.
class _AnalyticsButton extends StatelessWidget {
  const _AnalyticsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: AppBarShell.gap),
      child: AppBarShell(
        tooltip: 'Analytics',
        onTap: onPressed,
        child: Icon(
          Icons.insights_outlined,
          size: AppBarShell.iconSize,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// App-bar toggle: fills in and badges while any filter is applied.

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final HabitController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = controller.activeFilterCount;
    final active = count > 0;

    return Padding(
      padding: const EdgeInsets.only(right: AppBarShell.gap),
      child: AppBarShell(
        active: active,
        tooltip: active ? 'Filters ($count active)' : 'Filter habits',
        onTap: controller.filtersOpen.toggle,
        child: Badge(
          isLabelVisible: active,
          backgroundColor: scheme.primary,
          smallSize: 7,
          child: Icon(
            active ? Icons.filter_alt : Icons.filter_alt_outlined,
            size: AppBarShell.iconSize,
            color: active ? scheme.primary : appBarIconColor(scheme),
          ),
        ),
      ),
    );
  }
}

/// Everything that hangs under the app bar title: today's meter, and the filter
/// chips while they are open.
class _AppBarBottom extends StatelessWidget implements PreferredSizeWidget {
  const _AppBarBottom({required this.controller, required this.showFilters});

  final HabitController controller;
  final bool showFilters;

  @override
  Size get preferredSize => Size.fromHeight(
    _DayProgressStrip.height + (showFilters ? _FilterBar._height : 0),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DayProgressStrip(controller: controller),
        if (showFilters) _FilterBar(controller: controller),
      ],
    );
  }
}

/// Today's meter: one slot per habit, and a slot takes that habit's own colour
/// the moment it is complete. Reading the day never needs a scroll, and every
/// habit keeps a slot however many there are.
class _DayProgressStrip extends StatelessWidget {
  const _DayProgressStrip({required this.controller});

  final HabitController controller;

  static const double height = 20;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      // Snapshot inside this Obx: marking a habit refreshes `entries`, and the
      // home scaffold's own Obx never reads it while no filter is active.
      final habits = controller.habits.toList();
      final states = <bool>[
        for (final habit in habits) controller.isCompleteToday(habit),
      ];
      final done = states.where((met) => met).length;

      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < habits.length; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Expanded(
                        child: _HabitSegment(habit: habits[i], done: states[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '$done / ${habits.length}',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _HabitSegment extends StatelessWidget {
  const _HabitSegment({required this.habit, required this.done});

  final Habit habit;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(habit.color);

    return Tooltip(
      message: '${habit.name} · ${done ? 'done' : 'not yet'}',
      child: Container(
        height: 7,
        // Untouched slots stay neutral: the habit colour only arrives with the
        // mark, so the bar never dresses up an unfinished day.
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: done ? constraints.maxWidth : 0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color.lerp(accent, Colors.white, 0.25)!, accent],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact filter row that slides in under the app bar.
class _FilterBar extends StatelessWidget implements PreferredSizeWidget {
  const _FilterBar({required this.controller});

  final HabitController controller;

  /// A 34px chip plus a 3px margin on each side: the row hugs the chips so no
  /// dead band opens between the filters and the first habit card.
  static const double _height = 40;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final selectedType = controller.filterType.value;
    final selectedState = controller.filterCompletedToday.value;

    // Tapping the selected chip again clears it.
    void pickType(HabitType type) =>
        controller.filterType.value = selectedType == type ? null : type;
    void pickState(bool done) => controller.filterCompletedToday.value =
        selectedState == done ? null : done;

    return Container(
      height: _height,
      // Transparent: the row is painted inside the app bar's own material, so
      // a solid colour here would show a seam. The chips centre in the leftover
      // 6px, which is the only gap between the filters and the first card.
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _Chip(
              label: 'All',
              icon: Icons.apps,
              selected: !controller.hasActiveFilter,
              onTap: controller.clearFilters,
            ),
            const _Separator(),
            _Chip(
              label: 'Open today',
              icon: Icons.radio_button_unchecked,
              selected: selectedState == false,
              onTap: () => pickState(false),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Yes / No',
              icon: Icons.check_circle_outline,
              selected: selectedType == HabitType.yesNo,
              onTap: () => pickType(HabitType.yesNo),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Count',
              icon: Icons.tag,
              selected: selectedType == HabitType.count,
              onTap: () => pickType(HabitType.count),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Measure',
              icon: Icons.straighten,
              selected: selectedType == HabitType.measure,
              onTap: () => pickType(HabitType.measure),
            ),
            const _Separator(),
            _Chip(
              label: 'Done today',
              icon: Icons.task_alt,
              selected: selectedState == true,
              onTap: () => pickState(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a filter hides every habit; offers a one-tap reset.
class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'No habit matches',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different filter.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt,
            size: 56,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No habits yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use Add in the top bar to create your first habit.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
