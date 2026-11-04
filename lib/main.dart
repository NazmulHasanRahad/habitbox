
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/habit_controller.dart';
import 'controllers/task_controller.dart';
import 'screens/root_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Get.put(HabitController());
  Get.put(TaskController());

  runApp(const HabitBoxApp());
}

class HabitBoxApp extends StatelessWidget {
  const HabitBoxApp({super.key});

  // Global Primary Color
  static const Color primaryColor = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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

      // Default Theme Mode
      themeMode: ThemeMode.system,

      home: const RootScreen(),
    );
  }
}
