import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Tiny local store for UI settings, so the app needs no preferences package.
/// One plain-text file sits next to the database and only ever holds a view
/// mode name — never habit data.
class ViewPreferences {
  static const String fileName = 'habitbox_view.txt';
  static const String settingsFileName = 'habitbox_settings.txt';

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

  // --- Key/value settings ----------------------------------------------------
  //
  // One `key=value` per line in a second plain-text file, so settings like the
  // theme mode never touch the view-mode file or the database.

  static Future<File> _settingsFile() async =>
      File(p.join(await getDatabasesPath(), settingsFileName));

  static Future<Map<String, String>> _readSettings() async {
    final map = <String, String>{};
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return map;
      for (final line in await file.readAsLines()) {
        final sep = line.indexOf('=');
        if (sep > 0) {
          map[line.substring(0, sep).trim()] = line.substring(sep + 1).trim();
        }
      }
    } catch (_) {
      // A missing or unreadable settings file just means defaults.
    }
    return map;
  }

  static Future<String?> readSetting(String key) async =>
      (await _readSettings())[key];

  static Future<void> writeSetting(String key, String value) async {
    try {
      final map = await _readSettings();
      map[key] = value;
      final file = await _settingsFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        map.entries.map((e) => '${e.key}=${e.value}').join('\n'),
      );
    } catch (_) {
      // Losing a setting is never worth an error dialog.
    }
  }
}
