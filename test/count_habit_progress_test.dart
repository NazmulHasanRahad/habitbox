import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/habit_controller.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/utils/date_key.dart';
import 'package:habitbox/utils/habit_palette.dart';
import 'package:habitbox/widgets/count_habit_body.dart';

void main() {
  final habit = Habit(
    id: 1,
    name: 'Reading',
    type: HabitType.count,
    color: 0xFF6750A4,
    iconCodePoint: 0xE86D,
    goalValue: 20,
    unit: 'pages',
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpCard(WidgetTester tester, double? todayValue) async {
    Get.reset();
    final controller = Get.put(HabitController());
    controller.entries[1] = {if (todayValue != null) todayDateKey: todayValue};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CountHabitBody(
                habit: habit,
                palette: HabitPalette(Color(habit.color)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('incomplete goal shows the progress ring with a + icon', (
    tester,
  ) async {
    await pumpCard(tester, 12);

    expect(find.text('12/20 pages'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(0.6, 0.001));
  });

  testWidgets('reaching the goal swaps the ring for the yes/no card check', (
    tester,
  ) async {
    await pumpCard(tester, 20);

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.text('20/20 pages'), findsOneWidget);
    // No progress ring; the button fills with the accent color.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a habit without a goal never shows completion', (tester) async {
    final noGoal = Habit(
      id: 2,
      name: 'Water',
      type: HabitType.measure,
      color: 0xFF009688,
      iconCodePoint: 0xE87D,
      unit: 'litre',
      createdAt: DateTime(2026, 1, 1),
    );
    Get.reset();
    final controller = Get.put(HabitController());
    controller.entries[2] = {todayDateKey: 1.5};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CountHabitBody(
                habit: noGoal,
                palette: HabitPalette(Color(noGoal.color)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.text('1.5 litre'), findsOneWidget);
    // No goal -> the ring stays empty but the + button remains.
    expect(find.byIcon(Icons.add), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0.0);
  });

  testWidgets('tapping the ring opens the value sheet, not Details', (
    tester,
  ) async {
    await pumpCard(tester, 12);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // The card keeps its own 'Reading' label behind the sheet.
    expect(find.text('Reading'), findsNWidgets(2));
    expect(find.text('Today · pages'), findsOneWidget);
    expect(find.text('Goal 20 pages'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Save 12 pages'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('ring tap does not trigger the card-level Details tap', (
    tester,
  ) async {
    var cardTaps = 0;
    Get.reset();
    final controller = Get.put(HabitController());
    controller.entries[1] = {todayDateKey: 12};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => cardTaps++,
                child: CountHabitBody(
                  habit: habit,
                  palette: HabitPalette(Color(habit.color)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(cardTaps, 0);
    expect(find.text('Today · pages'), findsOneWidget);

    // Tapping elsewhere on the card still navigates.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    expect(cardTaps, 1);
  });
}
