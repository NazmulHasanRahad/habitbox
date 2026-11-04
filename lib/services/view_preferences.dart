import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Tiny local store for UI settings, so the app needs no preferences package.
/// One plain-text file sits next to the database and only ever holds a view
/// mode name — never habit data.
class ViewPreferences {
  static const String fileName = 'habitbox_view.txt';

  static const String viewCompact = 'compact';
  static const String viewFull = 'full';

  static Future<File> _file() async =>
      File(p.join(await getDatabasesPath(), fileName));

  /// The stored value, or null when nothing was written yet or the platform
  /// has no databases path (unit tests).
  static Future<String?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String value) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(value);
    } catch (_) {
      // Losing a view preference is never worth an error dialog.
    }
  }
}
