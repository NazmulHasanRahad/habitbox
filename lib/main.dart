
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/habit_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/task_controller.dart';
import 'models/habit.dart';
import 'screens/root_screen.dart';
import 'services/habit_widget_service.dart';
import 'services/notification_service.dart';
import 'utils/date_key.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Done before the controllers exist, so the first load of habits can hand
  // its reminders straight to a ready service.
  await NotificationService.instance.initialize();

  // Loaded before runApp so the first frame already wears the saved theme and
  // opens on the saved tab instead of flashing the defaults.
  final settings = Get.put(SettingsController());
  await settings.load();

  Get.put(HabitController());
  Get.put(TaskController());

  // The home-screen widget's mark button reaches Dart through this channel;
  // only yes/no habits can toggle natively, count/measure open the app instead.
  HabitWidgetService.setToggleHandler((habitId) async {
    final controller = Get.find<HabitController>();
    for (final habit in controller.habits) {
      if (habit.id == habitId && habit.type == HabitType.yesNo) {
        await controller.toggleYesNo(habit, todayDateKey);
        return;
      }
    }
  });

  runApp(const HabitBoxApp());
}

class HabitBoxApp extends StatelessWidget {
  const HabitBoxApp({super.key});

  // Global Primary Color
  static const Color primaryColor = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    // themeMode is read inside the Obx, so a settings change rebuilds the
    // whole app shell in the new brightness without losing navigation state.
    return Obx(() => GetMaterialApp(
      title: 'HabitBox',
      debugShowCheckedModeBanner: false,

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'JetBrainsMono',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'JetBrainsMono',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
      ),

      // Saved choice wins; ThemeMode.system follows the OS when unset. The
      // isRegistered guard keeps widget tests that skip main() working.
      themeMode: Get.isRegistered<SettingsController>()
          ? Get.find<SettingsController>().themeMode.value
          : ThemeMode.system,

      home: const RootScreen(),
    ));
  }
}
