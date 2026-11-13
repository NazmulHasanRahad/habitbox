import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/view_preferences.dart';

/// App-wide preferences that are not habit data: the theme mode and which of
/// the two top-level tabs the app opens on.
///
/// Values live in [ViewPreferences]' key/value file, so a change survives a
/// restart without touching the database.
class SettingsController extends GetxController {
  static const String _keyTheme = 'theme';
  static const String _keyHomeTab = 'home_tab';
  static const String _keyTasks = 'tasks_enabled';

  /// The brightness the app asks for; [ThemeMode.system] follows the OS.
  final themeMode = ThemeMode.system.obs;

  /// The tab [RootScreen] opens on: 0 = Habit, 1 = Task.
  final homeTab = 0.obs;

  /// Whether the Task destination exists at all. Off hides the Task tab, the
  /// "open app on" choice and moves the compact-list switch into the pill.
  final tasksEnabled = true.obs;

  /// One shared load so `main()` can await it and [onInit] cannot race it.
  Future<void>? _loading;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final theme = await ViewPreferences.readSetting(_keyTheme);
    if (theme == 'light') {
      themeMode.value = ThemeMode.light;
    } else if (theme == 'dark') {
      themeMode.value = ThemeMode.dark;
    }
    if (await ViewPreferences.readSetting(_keyHomeTab) == 'task') {
      homeTab.value = 1;
    }
    if (await ViewPreferences.readSetting(_keyTasks) == 'off') {
      tasksEnabled.value = false;
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (themeMode.value == mode) return;
    themeMode.value = mode;
    ViewPreferences.writeSetting(_keyTheme, mode.name);
  }

  /// [index] is the nav pill's own numbering: 0 Habit, 1 Task.
  void setHomeTab(int index) {
    if (homeTab.value == index) return;
    homeTab.value = index;
    ViewPreferences.writeSetting(_keyHomeTab, index == 1 ? 'task' : 'habit');
  }

  void setTasksEnabled(bool enabled) {
    if (tasksEnabled.value == enabled) return;
    tasksEnabled.value = enabled;
    ViewPreferences.writeSetting(_keyTasks, enabled ? 'on' : 'off');
  }
}
