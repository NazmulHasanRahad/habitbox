import 'package:flutter/material.dart';

/// Card colors derived from a habit's base color.
/// The card itself is dark (near black with a faint accent tint), while the
/// accent color is used for the icon badge, completed cells, and the mark
/// button.
class HabitPalette {
  HabitPalette(Color base)
      : accent = base,
        card = Color.lerp(base, const Color(0xFF0E1110), 0.88)!,
        muted = base.withValues(alpha: 0.16),
        bright = base,
        foreground = Colors.white;

  /// The habit's base color, used for filled accents.
  final Color accent;

  /// Dark card background with a faint accent tint.
  final Color card;

  /// Muted accent color used for incomplete cells and empty bar tracks.
  final Color muted;

  /// Bright accent color used for completed cells and filled bars.
  final Color bright;

  /// Primary text color on the dark card.
  final Color foreground;

  /// Secondary text color on the dark card.
  Color get foregroundSoft => foreground.withValues(alpha: 0.6);
}
