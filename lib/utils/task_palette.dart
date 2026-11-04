import 'package:flutter/material.dart';

/// The semantic colours the task feature needs, on top of the app's own
/// [ColorScheme].
///
/// The habit side of the app already carries its colour through each habit's
/// accent, so tasks only need meaning colours for outcome, how far a day got
/// and slippage. Each one is tuned per brightness: the same hex reads thin on a
/// light background, so light mode gets the same hue pulled toward black instead
/// of a recolour.
class TaskPalette {
  TaskPalette(this.scheme);

  final ColorScheme scheme;

  static const Color _successDark = Colors.green;
  static const Color _cautionDark = Color(0xFFF2C14E);
  static const Color _dangerDark = Color(0xFFEF747B);

  bool get _isDark => scheme.brightness == Brightness.dark;

  Color _adapt(Color dark) =>
      _isDark ? dark : Color.lerp(dark, Colors.black, 0.28)!;

  /// A task or step that is finished.
  Color get success => _adapt(_successDark);

  /// Halfway there: done, but not the whole day.
  Color get caution => _adapt(_cautionDark);

  /// Past due, or a day that got less than half done.
  Color get danger => _adapt(_dangerDark);
}
