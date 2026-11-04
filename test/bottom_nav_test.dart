import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/habit_controller.dart';
import 'package:habitbox/controllers/task_controller.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/models/habit_entry.dart';
import 'package:habitbox/repositories/habit_repository.dart';
import 'package:habitbox/screens/root_screen.dart';
import 'package:habitbox/utils/date_key.dart';

import 'task_test_support.dart';

/// The bottom navigation is a floating pill over an IndexedStack, so the risks
/// are a tab that repaints the habit screen from scratch, a back press that
/// exits the app from the Task tab, and the relocated grid/list toggle landing
/// inside the nav pill.
///
/// The habit list is forced into compact mode: the card view's chart column
/// overflows under the test placeholder font for unrelated reasons.
void main() {
  Future<void> pumpShell(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Get.reset();
    final controller = HabitController(
      repository: _FakeRepository(
        habits: [
          Habit(
            id: 1,
            name: 'Water',
            type: HabitType.yesNo,
            color: 0xFF3B82F6,
            iconCodePoint: 0xE86D,
            createdAt: shiftDays(today, -5),
          ),
          Habit(
            id: 2,
            name: 'Read',
            type: HabitType.count,
            color: 0xFFF59E0B,
            iconCodePoint: 0xE86D,
            goalValue: 20,
            unit: 'pages',
            createdAt: shiftDays(today, -5),
          ),
        ],
        stored: <HabitEntry>[],
      ),
    );
    controller.compactView.value = true;
    Get.put(controller);
    // The Task destination is a live dashboard, so it needs its own controller
    // with rows to read before the shell can mount it.
    Get.put(
      TaskController(
        repository: FakeTaskRepository(
          tasks: [
            newTask(
              id: 1,
              title: 'Draft the thesis chapter',
              dueDateKey: todayDateKey,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const RootScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The shell's stack is the first one in the tree; habit cards have their own.
  int visibleTab(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack).first).index ?? -1;

  testWidgets('the pill starts on Habit and switches to the task dashboard', (
    tester,
  ) async {
    await pumpShell(tester, 423);

    expect(tester.takeException(), isNull);
    expect(visibleTab(tester), 0);
    // Habit chrome is live: both pill labels plus the analytics action.
    expect(find.text('Habit'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.byTooltip('Analytics'), findsOneWidget);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(visibleTab(tester), 1);
    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('Draft the thesis chapter'), findsOneWidget);

    await tester.tap(find.text('Habit'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(visibleTab(tester), 0);
  });

  testWidgets('the habit screen keeps its state across a tab round trip', (
    tester,
  ) async {
    await pumpShell(tester, 423);
    final controller = Get.find<HabitController>();

    await controller.toggleYesNo(controller.habits.first, todayDateKey);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Habit'));
    await tester.pumpAndSettle();

    // Same mounted screen: the meter still shows today's mark.
    expect(tester.takeException(), isNull);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Water · done'), findsOneWidget);
  });

  testWidgets('back returns to Habit instead of leaving the app', (
    tester,
  ) async {
    await pumpShell(tester, 423);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();

    // A real Android back press: the shell absorbs it and shows Habit.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(visibleTab(tester), 0);

    // On Habit the same press leaves the app; the tab must not move.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(visibleTab(tester), 0);
  });

  testWidgets('the view switch is an app-bar control and the pill is narrow', (
    tester,
  ) async {
    await pumpShell(tester, 423);

    // Compact mode is on, so the shell wears the list icon and offers cards.
    final toggle = find.byTooltip('Compact list · tap for cards');
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(of: toggle, matching: find.byIcon(Icons.view_list)),
      findsOneWidget,
    );

    final toggleRect = tester.getRect(toggle);
    final meterRect = tester.getRect(find.text('0 / 2'));
    final pillRect = tester.getRect(find.byKey(const ValueKey('nav-pill')));

    // It sits in the app bar's own band, above today's meter, rather than
    // floating over the list.
    expect(toggleRect.bottom, lessThanOrEqualTo(meterRect.top));
    expect(toggleRect.bottom, lessThan(pillRect.top));
    // The pill hugs its two labels instead of stretching edge to edge, and it
    // stays centred over the safe area.
    expect(pillRect.width, lessThan(423 * 0.6));
    expect(pillRect.center.dx, closeTo(423 / 2, 1));
    expect(pillRect.height, 52);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository extends HabitRepository {
  _FakeRepository({required this.habits, required this.stored});

  final List<Habit> habits;
  final List<HabitEntry> stored;

  @override
  Future<List<Habit>> getHabits() async => List<Habit>.from(habits);

  @override
  Future<List<HabitEntry>> getAllEntriesInRange(
    String startDateKey,
    String endDateKey,
  ) async => List<HabitEntry>.from(stored);

  @override
  Future<int> upsertEntry(HabitEntry entry) async {
    stored.removeWhere(
      (e) => e.habitId == entry.habitId && e.dateKey == entry.dateKey,
    );
    stored.add(entry);
    return 1;
  }

  @override
  Future<int> deleteEntry(int habitId, String dateKey) async {
    stored.removeWhere((e) => e.habitId == habitId && e.dateKey == dateKey);
    return 1;
  }
}
