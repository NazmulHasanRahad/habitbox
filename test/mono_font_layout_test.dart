import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/habit_controller.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/utils/date_key.dart';
import 'package:habitbox/utils/habit_palette.dart';
import 'package:habitbox/widgets/count_habit_body.dart';
import 'package:habitbox/widgets/daily_bar_chart.dart';
import 'package:habitbox/widgets/habit_heatmap.dart';
import 'package:habitbox/widgets/month_calendar.dart';
import 'package:habitbox/widgets/yes_no_habit_body.dart';

/// Tests cannot load the bundled font (no FontLoader in this flutter_test),
/// but the default test font draws every glyph one em wide — much wider than
/// JetBrains Mono's 0.6em advance. So if a row fits at this narrow phone
/// width with the test font, it fits with the real font too.
Widget app(Widget child) => GetMaterialApp(
  theme: ThemeData(fontFamily: 'JetBrainsMono'),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

Habit habitOf(
  int id,
  String name, {
  HabitType type = HabitType.count,
  double? goal,
  String? unit,
  String? description,
}) => Habit(
  id: id,
  name: name,
  type: type,
  color: 0xFF9C27B0,
  iconCodePoint: 0xE87D,
  goalValue: goal,
  unit: unit,
  description: description,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  setUp(() {
    Get.reset();
    Get.put(HabitController());
  });

  testWidgets('count card keeps its goal text on a narrow screen', (
    tester,
  ) async {
    final habit = habitOf(1, 'Read 20 pages', goal: 20, unit: 'pages');
    Get.find<HabitController>().entries[1] = {todayDateKey: 12};

    await tester.pumpWidget(
      app(
        CountHabitBody(habit: habit, palette: HabitPalette(Color(habit.color))),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('12/20 pages'), findsOneWidget);
  });

  testWidgets('yes/no card header and mini heatmap do not overflow', (
    tester,
  ) async {
    final habit = habitOf(2, 'Meditate', type: HabitType.yesNo);
    Get.find<HabitController>().entries[2] = {todayDateKey: 1};

    await tester.pumpWidget(
      app(
        YesNoHabitBody(habit: habit, palette: HabitPalette(Color(habit.color))),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('yes/no and count cards stay the same height after resizing', (
    tester,
  ) async {
    final yesNo = habitOf(4, 'Stretch', type: HabitType.yesNo);
    final counted = habitOf(5, 'Read', goal: 20, unit: 'pages');
    Get.find<HabitController>().entries[4] = {todayDateKey: 1};
    Get.find<HabitController>().entries[5] = {todayDateKey: 12};

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(fontFamily: 'JetBrainsMono'),
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 320,
                child: YesNoHabitBody(
                  habit: yesNo,
                  palette: HabitPalette(Color(yesNo.color)),
                ),
              ),
              SizedBox(
                width: 320,
                child: CountHabitBody(
                  habit: counted,
                  palette: HabitPalette(Color(counted.color)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(YesNoHabitBody)).height,
      tester.getSize(find.byType(CountHabitBody)).height,
    );
  });

  testWidgets('month calendar weekday labels and two-digit days fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        MonthCalendar(
          displayMonth: DateTime(2026, 10),
          markedKeys: const {'2026-10-27', '2026-10-28'},
          selectedDateKey: '2026-10-28',
          accent: const Color(0xFF9C27B0),
          onDayTap: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Wed'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('details heatmap month and weekday labels do not overflow', (
    tester,
  ) async {
    final habit = habitOf(3, 'Push-ups', goal: 30, unit: 'reps');
    await tester.pumpWidget(
      app(
        HabitHeatmap(
          habit: habit,
          entries: {todayDateKey: 30},
          accent: const Color(0xFF9C27B0),
          selectedDateKey: todayDateKey,
          onSelect: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Tue'), findsOneWidget);
  });

  testWidgets('details bar chart prints values and days without overflow', (
    tester,
  ) async {
    final habit = habitOf(6, 'Push-ups', goal: 30, unit: 'reps');
    await tester.pumpWidget(
      app(
        DailyBarChart(
          habit: habit,
          entries: {
            todayDateKey: 45,
            dateKeyFor(shiftDays(today, -1)): 62,
            dateKeyFor(shiftDays(today, -2)): 450,
          },
          accent: const Color(0xFF9C27B0),
          selectedDateKey: todayDateKey,
          onSelect: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Values sit above their bar; none of them collide with a day number.
    for (final value in ['45', '62', '450']) {
      expect(find.text(value), findsOneWidget, reason: '\$value missing');
    }
    expect(find.text('28'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DailyBarChart)).height,
      DailyBarChart.valueLabelHeight +
          4 +
          DailyBarChart.chartHeight +
          4 +
          DailyBarChart.dayLabelHeight,
    );
  });

  testWidgets('both card types show a description under the name', (
    tester,
  ) async {
    final yesNo = habitOf(
      7,
      'Stretch',
      type: HabitType.yesNo,
      description: 'Morning, before work',
    );
    final counted = habitOf(
      8,
      'Read',
      goal: 20,
      unit: 'pages',
      description:
          'A long description that has to ellipsize instead of wrapping',
    );
    Get.find<HabitController>().entries[7] = {todayDateKey: 1};
    Get.find<HabitController>().entries[8] = {todayDateKey: 12};

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(fontFamily: 'JetBrainsMono'),
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 320,
                child: YesNoHabitBody(
                  habit: yesNo,
                  palette: HabitPalette(Color(yesNo.color)),
                ),
              ),
              SizedBox(
                width: 320,
                child: CountHabitBody(
                  habit: counted,
                  palette: HabitPalette(Color(counted.color)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Morning, before work'), findsOneWidget);
    // The long line must ellipsize, never wrap the header taller.
    final longText = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data?.startsWith('A long description') ?? false),
    );
    expect(longText, findsOneWidget);
    expect(tester.widget<Text>(longText).overflow, TextOverflow.ellipsis);
    // The extra line fits inside the 44px mark control, so both cards stay
    // the same height.
    expect(
      tester.getSize(find.byType(YesNoHabitBody)).height,
      tester.getSize(find.byType(CountHabitBody)).height,
    );
  });
}
