import 'package:flutter/material.dart';

/// One language for every app-bar control in the app, taken from the home
/// screen: a 40dp raised shell with a hairline edge and a soft drop, so the
/// actions read as a matched set instead of widgets from different kits.
///
/// [AppBarShell] is the general form — icon in, tap out — and lights up with the
/// primary when a control is [active]. [AddAppBarButton] and [AppBarBackButton]
/// are the two fixed roles wearing the same geometry, which is what lets a
/// pushed screen's back arrow sit at home next to an edit or delete action.
class AppBarShell extends StatelessWidget {
  const AppBarShell({
    super.key,
    this.active = false,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  /// The gap the home app bar leaves between two neighbouring shells.
  static const double gap = 6;

  static const double size = 40;
  static const double iconSize = 19;

  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = active
        ? Color.lerp(scheme.surfaceContainerHigh, scheme.primary, 0.18)!
        : scheme.surfaceContainerHigh;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(fill, Colors.white, 0.001)!, fill],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? scheme.primary.withValues(alpha: 0.45)
                    : scheme.onSurface.withValues(alpha: 0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.34 : 0.13,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (active)
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The icon colour every inactive app-bar control uses, so a filter, an edit
/// pencil and a back arrow all sit at the same weight inside their shells.
Color appBarIconColor(ColorScheme scheme) =>
    scheme.onSurfaceVariant.withValues(alpha: 0.85);

/// A single glyph sized and coloured for [AppBarShell], so a control that only
/// shows an icon does not have to repeat that recipe.
class AppBarGlyph extends StatelessWidget {
  const AppBarGlyph(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: AppBarShell.iconSize,
      color: appBarIconColor(Theme.of(context).colorScheme),
    );
  }
}

/// A screen's primary action: the same shell as the icons beside it, in the
/// blue the app reserves for 'add'.
class AddAppBarButton extends StatelessWidget {
  const AddAppBarButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = Color(0xFF10B981);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            width: AppBarShell.size,
            height: AppBarShell.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(base, Colors.white, 0.55)!, base],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(0xFF10B981)),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade400.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.40 : 0.22,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// The back arrow, in the shell its opposite actions already wear.
///
/// It has to be centred rather than handed over directly: an app bar lays its
/// leading out under tight 56x56 constraints, which would stretch the shell's
/// own 40 into that slot and leave the back button visibly bigger than the
/// actions beside it.
class AppBarBackButton extends StatelessWidget {
  const AppBarBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppBarShell(
        tooltip: 'Back',
        onTap: () => Navigator.of(context).maybePop(),
        child: Icon(
          Icons.arrow_back,
          size: AppBarShell.iconSize,
          color: appBarIconColor(Theme.of(context).colorScheme),
        ),
      ),
    );
  }
}
