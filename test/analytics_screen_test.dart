import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/habit_controller.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/models/habit_entry.dart';
import 'package:habitbox/repositories/habit_repository.dart';
import 'package:habitbox/screens/analytics_screen.dart';
import 'package:habitbox/utils/date_key.dart';

/// Fixed data: three habits created well before any window, so every day in a
/// 30 day period counts as scheduled.
///
/// * Water  (yes/no)     — all 30 days marked            -> 100%
/// * Run    (measure 5 km) — 15 of 30 days at the goal    -> 50%
/// * Read   (count 10)   — 3 of 30 days at the goal       -> 10%
/// Overall: 48 of 90 habit-days -> 53%.
void main() {
  final habits = <Habit>[
    Habit(
      id: 1,
      name: 'Water',
      type: HabitType.yesNo,
      color: 0xFF3B82F6,
      iconCodePoint: 0xE86D,
      createdAt: shiftDays(today, -40),
    ),
    Habit(
      id: 2,
      name: 'Run',
      type: HabitType.measure,
      color: 0xFF22C55E,
      iconCodePoint: 0xE86D,
      goalValue: 5,
      unit: 'km',
      createdAt: shiftDays(today, -40),
    ),
    Habit(
      id: 3,
      name: 'Read',
      type: HabitType.count,
      color: 0xFFF59E0B,
      iconCodePoint: 0xE86D,
      goalValue: 10,
      unit: 'pages',
      createdAt: shiftDays(today, -40),
    ),
  ];

  final entries = <HabitEntry>[
    for (var back = 0; back < 30; back++)
      HabitEntry(
        habitId: 1,
        dateKey: dateKeyFor(shiftDays(today, -back)),
        value: 1,
      ),
    for (var back = 0; back < 15; back++)
      HabitEntry(
        habitId: 2,
        dateKey: dateKeyFor(shiftDays(today, -back)),
        value: 5,
      ),
    for (var back = 0; back < 3; back++)
      HabitEntry(
        habitId: 3,
        dateKey: dateKeyFor(shiftDays(today, -back)),
        value: 10,
      ),
  ];

  Future<void> pumpAnalytics(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Get.reset();
    Get.put(
      HabitController(
        repository: _FakeRepository(habits: habits, stored: entries),
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
        home: const AnalyticsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the 30 day report reads the tracked numbers', (tester) async {
    await pumpAnalytics(tester, 423);

    expect(tester.takeException(), isNull);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Understand your progress'), findsOneWidget);
    // Completion ring and the exact habit-day counts behind it.
    expect(find.text('53%'), findsOneWidget);
    expect(find.text('48 of 90'), findsOneWidget);
    expect(find.text('habit-days completed'), findsOneWidget);
    expect(find.text('Completion rate over the last 30 days'), findsOneWidget);
    expect(find.text('Daily consistency'), findsOneWidget);
    expect(find.text('Habit performance'), findsOneWidget);
    expect(find.text('3 habits in this period'), findsOneWidget);
    // The four headline tiles.
    expect(find.text('Perfect days'), findsOneWidget);
    expect(find.text('Active streak'), findsOneWidget);
    expect(find.text('Days logged'), findsOneWidget);
    expect(find.text('Most consistent'), findsOneWidget);
    // One row, left to right, all sharing the same band.
    final firstTile = tester.getRect(find.byIcon(Icons.star_border));
    final lastTile = tester.getRect(find.byIcon(Icons.emoji_events_outlined));
    expect(firstTile.top, closeTo(lastTile.top, 0.5));
    expect(lastTile.left, greaterThan(firstTile.right));
    // Every habit is listed, none folded away.
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    expect(find.text('Water'), findsWidgets);
    expect(find.text('Run'), findsWidgets);
    expect(find.text('Read'), findsWidgets);
    // One row per habit: days met, current streak, then the logged amount.
    expect(find.text('30 of 30 days · 30 day streak'), findsOneWidget);
    expect(
      find.text('15 of 30 days · 15 day streak · 75 km logged'),
      findsOneWidget,
    );
    expect(
      find.text('3 of 30 days · 3 day streak · 30 pages logged'),
      findsOneWidget,
    );
    // The y axis is drawn in the three-tier scale's own units.
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    // The three tiers are explained under the chart.
    expect(find.text('< 50%'), findsOneWidget);
    expect(find.text('50–99%'), findsOneWidget);
  });

  testWidgets('switching the period recomputes the whole report', (
    tester,
  ) async {
    await pumpAnalytics(tester, 423);

    await tester.tap(find.text('90 Days'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Completion rate over the last 90 days'), findsOneWidget);
    // Both habits predate the 90 day window by 49 days, so each is scheduled
    // for 41 of them: 123 habit-days, still the same 48 marks.
    expect(find.text('48 of 123'), findsOneWidget);
    expect(find.text('39%'), findsOneWidget);
  });

  testWidgets(
    'a narrow screen fits the bars to their row, whatever the period',
    (tester) async {
      await pumpAnalytics(tester, 320);

      // Bars live inside the chart card, next to other LayoutBuilders.
      final bars = find.descendant(
        of: find.byKey(const ValueKey('analytics-chart')),
        matching: find.byType(LayoutBuilder),
      );

      // Longest window first: 90 bars have to share one tight row.
      await tester.tap(find.text('90 Days'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(bars, findsNWidgets(90));

      final strip = tester.getRect(
        find.byKey(const ValueKey('analytics-bar-strip')),
      );
      final chart = tester.getRect(
        find.byKey(const ValueKey('analytics-chart')),
      );
      // The bar strip and the axis under it both stay inside the page padding.
      expect(strip.left, greaterThanOrEqualTo(16));
      expect(strip.right, lessThanOrEqualTo(320 - 16));
      expect(chart.right, lessThanOrEqualTo(320 - 16));
      // Every bar sits in the strip, none spills out of it.
      final lastBar = tester.getRect(bars.last);
      expect(lastBar.right, lessThanOrEqualTo(strip.right + 0.5));

      // A short window must not fatten the bars into slabs: the bar is capped
      // even though its slot is wide.
      await tester.tap(find.text('7 Days'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(bars, findsNWidgets(7));

      final slot = tester.getRect(bars.first);
      final bar = tester.getRect(
        find.descendant(of: bars.first, matching: find.byType(Container)).first,
      );
      expect(slot.width, greaterThan(30));
      expect(bar.width, lessThan(15));
      // Bottom-aligned, so the bar starts at the strip's floor.
      expect(bar.bottom, closeTo(slot.bottom, 0.5));
      expect(bar.left, greaterThanOrEqualTo(slot.left));
      expect(bar.right, lessThanOrEqualTo(slot.right));
    },
  );
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
}
