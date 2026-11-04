import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/habit_controller.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/models/habit_entry.dart';
import 'package:habitbox/repositories/habit_repository.dart';
import 'package:habitbox/screens/home_screen.dart';
import 'package:habitbox/utils/date_key.dart';
import 'package:habitbox/widgets/compact_habit_row.dart';

/// The app bar's four controls are now fixed-size shells, so the risk is a
/// horizontal overflow (or a title squashed out of the bar) on a narrow phone.
///
/// The list underneath is forced into compact mode: the card view's chart
/// column overflows under the test placeholder font for reasons that have
/// nothing to do with the app bar, and that noise would hide a real chrome
/// break.
void main() {
  Future<void> pumpHome(WidgetTester tester, double width) async {
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
        stored: [HabitEntry(habitId: 1, dateKey: todayDateKey, value: 1)],
      ),
    );
    controller.compactView.value = true;
    Get.put(controller);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the app bar keeps title and all four actions on one line', (
    tester,
  ) async {
    await pumpHome(tester, 320);

    expect(tester.takeException(), isNull);
    // The brand title is a two-span RichText, so it is found by its plain text.
    final brand = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == 'HabitBox',
    );
    expect(brand, findsOneWidget);

    final analytics = tester.getRect(find.byTooltip('Analytics'));
    final filter = tester.getRect(find.byTooltip('Filter habits'));
    final view = tester.getRect(find.byTooltip('Compact list · tap for cards'));
    final add = tester.getRect(find.byTooltip('Add habit'));

    // Same vertical band, strictly left to right, nothing past the edge.
    expect(analytics.center.dy, closeTo(filter.center.dy, 1));
    expect(analytics.center.dy, closeTo(view.center.dy, 1));
    expect(analytics.center.dy, closeTo(add.center.dy, 1));
    expect(analytics.right, lessThanOrEqualTo(filter.left));
    expect(filter.right, lessThanOrEqualTo(view.left));
    expect(view.right, lessThanOrEqualTo(add.left));
    expect(add.right, lessThanOrEqualTo(320));
    // The title still owns the space before the actions.
    final title = tester.getRect(brand);
    expect(title.right, lessThanOrEqualTo(analytics.left));
    // All four controls are the same matched shell.
    expect(analytics.height, filter.height);
    expect(analytics.width, 40);
    expect(view.width, 40);
    expect(add.height, closeTo(analytics.height, 0.5));
  });

  testWidgets('an active filter lights its shell and badges it', (
    tester,
  ) async {
    await pumpHome(tester, 423);

    final controller = Get.find<HabitController>();
    controller.filterCompletedToday.value = false;

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The tooltip now reports the count, and the shell is the active one.
    expect(find.byTooltip('Filters (1 active)'), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    expect(
      find.byTooltip('Filter habits'),
      findsNothing,
      reason: 'the inactive tooltip is gone',
    );
  });

  testWidgets('opening the filters leaves no dead band over the list', (
    tester,
  ) async {
    await pumpHome(tester, 423);
    final controller = Get.find<HabitController>();

    controller.filtersOpen.value = true;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final chip = tester.getRect(
      find.ancestor(
        of: find.text('All'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final meter = tester.getRect(find.text('1 / 2'));
    final header = tester.getRect(find.byType(CompactWeekHeader));

    // The row hugs its own chips instead of carrying empty height.
    expect(chip.height, 34);
    // Nothing but the meter's own baseline sits above the chips...
    expect(chip.top - meter.bottom, lessThan(12));
    // ...and only the list's 8px of top padding separates them from the cards.
    expect(header.top - chip.bottom, greaterThan(0));
    expect(header.top - chip.bottom, lessThan(16));
  });

  testWidgets('the strip fills one habit-coloured slot per mark', (
    tester,
  ) async {
    await pumpHome(tester, 423);

    final controller = Get.find<HabitController>();
    // Water is marked, Read is not.
    expect(find.text('1 / 2'), findsOneWidget);

    final waterSlot = find.byTooltip('Water · done');
    final readSlot = find.byTooltip('Read · not yet');
    expect(waterSlot, findsOneWidget);
    expect(readSlot, findsOneWidget);

    AnimatedContainer fill(String tooltip) => tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byTooltip(tooltip),
        matching: find.byType(AnimatedContainer),
      ),
    );
    double fillWidth(String tooltip) => tester
        .getRect(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .width;

    final decoration = fill('Water · done').decoration! as BoxDecoration;
    expect(
      (decoration.gradient! as LinearGradient).colors.last,
      const Color(0xFF3B82F6),
      reason: 'the filled slot wears the habit own colour',
    );
    expect(fillWidth('Water · done'), greaterThan(30));
    expect(fillWidth('Read · not yet'), 0);

    // Unmarking Water drains its slot again.
    await controller.toggleYesNo(controller.habits.first, todayDateKey);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.byTooltip('Water · not yet'), findsOneWidget);
    expect(fillWidth('Water · not yet'), 0);

    // Logging Read to its goal lights the second slot in Read's colour.
    await controller.saveValue(controller.habits.last, todayDateKey, 20);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Read · done'), findsOneWidget);
    final lit = fill('Read · done').decoration! as BoxDecoration;
    expect(
      (lit.gradient! as LinearGradient).colors.last,
      const Color(0xFFF59E0B),
    );
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
