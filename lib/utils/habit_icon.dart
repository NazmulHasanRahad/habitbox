import 'package:flutter/material.dart';

import '../screens/icon_picker_screen.dart';

/// Every icon the app can persist, indexed by its stored code point.
///
/// Glyphs must be reached through compile-time `Icons.*` constants: a release
/// build refuses to tree-shake the MaterialIcons font while any runtime
/// `IconData(...)` call exists, which fails `flutter build apk --release`.
final Map<int, IconData> _habitIconsByCodePoint = {
  for (final category in kHabitIconCategories)
    for (final option in category.options) option.icon.codePoint: option.icon,
};

/// The glyph for a stored [codePoint]; unknown values fall back to a generic
/// icon instead of drawing an arbitrary code point.
IconData habitIconData(int codePoint) =>
    _habitIconsByCodePoint[codePoint] ?? Icons.apps;
