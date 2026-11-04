import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'task_screen.dart';

const double _navPillHeight = 52;

/// Hosts the two top-level destinations.
///
/// [IndexedStack] keeps both screens mounted, so the habit list keeps its
/// scroll offset, filters and in-progress state when the tab changes.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    // The pill floats above the Android navigation bar instead of hiding
    // behind it.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      // Back from a non-home tab lands on Habit; on Habit it exits the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: const [HomeScreen(), TaskScreen()],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 10,
              child: Center(
                child: _NavPill(index: _index, onSelect: _select),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Sizes to its two labels instead of stretching across the screen.
    return Container(
      key: const ValueKey('nav-pill'),
      height: _navPillHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(_navPillHeight / 2),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavTab(
            // grid_2x2 and list_checks are Lucide names; these are Flutter's
            // closest built-in icons.
            icon: Icons.grid_view,
            label: 'Habit',
            selected: index == 0,
            onTap: () => onSelect(0),
          ),
          _NavTab(
            icon: Icons.checklist,
            label: 'Task',
            selected: index == 1,
            onTap: () => onSelect(1),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular((_navPillHeight - 6) / 2);
    // AnimatedDefaultTextStyle replaces the inherited style outright, so the
    // label has to start from a themed style or it loses the app font.
    final labelStyle = theme.textTheme.labelMedium ?? const TextStyle();

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: _navPillHeight - 6,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: color.withValues(alpha: selected ? 1 : 0.75),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: labelStyle.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                  color: color.withValues(alpha: selected ? 1 : 0.75),
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
