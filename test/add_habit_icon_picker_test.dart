import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/screens/add_habit_screen.dart';
import 'package:habitbox/screens/icon_picker_screen.dart';
import 'package:habitbox/utils/habit_icon.dart';

/// Set by [pushPicker] to the future the Add/Edit form would await on.
Future<int?>? pickerResult;

/// Opens the picker the same way the Add/Edit form does.
Future<void> pushPicker(WidgetTester tester, {int selected = 0xE87D}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () {
            pickerResult = Get.to<int>(
              () => IconPickerScreen(
                selectedCodePoint: selected,
                accent: const Color(0xFF4CAF50),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The form is a long ListView; give it enough height that every section is
/// actually built instead of being lazily skipped.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('picker preselects the incoming icon', (tester) async {
    await pushPicker(tester, selected: Icons.directions_run.codePoint);

    expect(find.text('Choose icon'), findsOneWidget);
    // Exactly one tile carries the check badge: the preselected one.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Tooltip),
        matching: find.byIcon(Icons.directions_run),
      ),
      findsWidgets,
    );
  });

  testWidgets('search filters immediately and shows an empty state', (
    tester,
  ) async {
    await pushPicker(tester);

    final allCategories = find.byIcon(Icons.check_circle);
    expect(allCategories, findsNothing); // 0xE87D is not in the catalog
    final tilesBefore = find.byType(Tooltip).evaluate().length;

    await tester.enterText(find.byType(TextField).first, 'running');
    await tester.pump();

    expect(find.byIcon(Icons.directions_run), findsOneWidget);
    expect(find.text('HEALTH & FITNESS'), findsOneWidget);
    expect(find.text('FINANCE'), findsNothing);
    expect(find.byType(Tooltip).evaluate().length, lessThan(tilesBefore));

    await tester.enterText(find.byType(TextField).first, 'zzznothing');
    await tester.pump();
    expect(find.text('No icons match "zzznothing"'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
  });

  testWidgets('tapping a tile returns its code point', (tester) async {
    await pushPicker(tester);
    await tester.tap(find.byIcon(Icons.directions_run).first);
    await tester.pumpAndSettle();

    expect(await pickerResult, Icons.directions_run.codePoint);
  });

  testWidgets('edit mode keeps a stored icon and a color outside the palette', (
    tester,
  ) async {
    useTallScreen(tester);
    final habit = Habit(
      id: 7,
      name: 'Sketch',
      type: HabitType.measure,
      color: 0xFF123456,
      iconCodePoint: Icons.menu_book.codePoint,
      goalValue: 30.5,
      unit: 'minutes',
      createdAt: DateTime(2026, 3, 4),
      sortOrder: 3,
      description: 'Daily drawing',
    );

    await tester.pumpWidget(
      GetMaterialApp(home: AddHabitScreen(initialHabit: habit)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit habit'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('30.5'), findsOneWidget);
    expect(find.text('GOAL SETTINGS'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    // The stored color is not in the palette, yet it still drives the accent.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.menu_book)).color,
      const Color(0xFF123456),
    );
  });

  testWidgets('edit mode supports selecting multiple reminder weekdays', (
    tester,
  ) async {
    useTallScreen(tester);
    final habit = Habit(
      id: 8,
      name: 'Walk',
      type: HabitType.yesNo,
      color: 0xFF4CAF50,
      iconCodePoint: Icons.directions_walk.codePoint,
      createdAt: DateTime(2026, 3, 4),
      reminderMinutes: 9 * 60,
      reminderDays: (1 << 0) | (1 << 2) | (1 << 4),
    );

    await tester.pumpWidget(
      GetMaterialApp(home: AddHabitScreen(initialHabit: habit)),
    );
    await tester.pumpAndSettle();

    FilterChip chip(String day) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, day));
    expect(chip('Mon').selected, isTrue);
    expect(chip('Wed').selected, isTrue);
    expect(chip('Fri').selected, isTrue);
    expect(chip('Tue').selected, isFalse);

    await tester.tap(find.widgetWithText(FilterChip, 'Tue'));
    await tester.pumpAndSettle();
    expect(chip('Tue').selected, isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'Mon'));
    await tester.pumpAndSettle();
    expect(chip('Mon').selected, isFalse);
    expect(chip('Tue').selected, isTrue);
  });

  testWidgets('a code point no longer in the catalog falls back safely', (
    tester,
  ) async {
    expect(habitIconData(0x0E001), Icons.apps);
    expect(habitIconData(Icons.menu_book.codePoint), Icons.menu_book);
  });

  testWidgets('new habit starts with the default icon centered', (
    tester,
  ) async {
    useTallScreen(tester); // 600 logical px wide
    await tester.pumpWidget(GetMaterialApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.monitor_heart), findsOneWidget);
    expect(tester.getRect(find.byIcon(Icons.monitor_heart)).center.dx, 300);
    // The "Habit Icon" heading was dropped in favour of the centered avatar.
    expect(find.text('HABIT ICON'), findsNothing);
  });

  testWidgets('goal settings follow the selected type', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(GetMaterialApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Create habit'), findsOneWidget);
    expect(find.text('GOAL SETTINGS'), findsNothing);
    // The description sits under the segmented control, not inside it.
    expect(find.text('Mark each day complete or incomplete'), findsOneWidget);

    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();
    expect(find.text('GOAL SETTINGS'), findsOneWidget);
    expect(find.text('Track a measurable value'), findsOneWidget);
    expect(find.text('Mark each day complete or incomplete'), findsNothing);

    await tester.tap(find.text('Yes / No'));
    await tester.pumpAndSettle();
    expect(find.text('GOAL SETTINGS'), findsNothing);
  });

  testWidgets('empty name shows an inline error instead of saving', (
    tester,
  ) async {
    await tester.pumpWidget(GetMaterialApp(home: const AddHabitScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create habit'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a habit name.'), findsOneWidget);
  });
}
