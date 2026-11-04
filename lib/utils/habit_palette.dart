import 'package:flutter/material.dart';

/// Card colors derived from a habit's base color:
/// deep card background, muted incomplete cells, bright completed ones.
class HabitPalette {
  HabitPalette(Color base)
      : card = Color.lerp(base, Colors.black, 0.42)!,
        muted = base.withValues(alpha: 0.22),
        bright = Colors.white.withOpacity(0.9), //Color.lerp(base, Colors.white, 0.62)!,
        foreground = Colors.white;

  final Color card;
  final Color muted;
  final Color bright;
  final Color foreground;

  Color get foregroundSoft => foreground.withValues(alpha: 0.72);
}
