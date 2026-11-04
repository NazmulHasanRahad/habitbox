import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/habit_controller.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/models/habit_entry.dart';
import 'package:habitbox/repositories/habit_repository.dart';
import 'package:habitbox/utils/date_key.dart';
import 'package:habitbox/widgets/compact_habit_row.dart';

/// In-memory repository so a tap on today's cell can be proven end to end
/// (upsert for the same habit+date, delete on undo) without a database.
class _FakeRepository extends HabitRepository {
  _FakeRepository({required this.habits, List<HabitEntry> entries = const []})
    : stored = List<HabitEntry>.from(entries);

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

void main() {
  Habit habit({
    required HabitType type,
    double? goal,
    String? unit,
    String name = 'Reading',
    int id = 1,
  }) => Habit(
    id: id,
    name: name,
    type: type,
    color: 0xFF6750A4,
    iconCodePoint: 0xE86D,
    goalValue: goal,
    unit: unit,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<_Harness> pumpList(
    WidgetTester tester, {
    required List<Habit> habits,
    Map<int, Map<int, double>> dayValues = const {},
    double width = 360,
  }) async {
    final repository = _FakeRepository(
      habits: habits,
      entries: [
        for (final habit in habits)
          for (final day
              in (dayValues[habit.id] ?? const <int, double>{}).entries)
            HabitEntry(
              habitId: habit.id!,
              dateKey: dateKeyFor(shiftDays(today, -day.key)),
              value: day.value,
            ),
      ],
    );
    Get.reset();
    Get.put(HabitController(repository: repository));

    var navigations = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    CompactWeekHeader(count: habits.length),
                    for (final habit in habits)
                      CompactHabitRow(
                        habit: habit,
                        isLast: habit == habits.last,
                        onTap: () => navigations++,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(repository, () => navigations);
  }

  testWidgets('the date header columns line up with the row cells', (
    tester,
  ) async {
    await pumpList(tester, habits: [habit(type: HabitType.yesNo)]);

    final headerColumn = tester.getRect(find.text('${today.day}'));
    final cell = tester.getRect(find.byTooltip('Mark today'));
    expect((headerColumn.center.dx - cell.center.dx).abs(), lessThan(0.6));
    expect(cell.top, greaterThan(headerColumn.top));
  });

  testWidgets('measure row paints one cell per day and keeps the unit', (
    tester,
  ) async {
    final harness = await pumpList(
      tester,
      habits: [habit(type: HabitType.measure, goal: 5, unit: 'km')],
      dayValues: {
        1: {0: 3.5, 1: 5, 3: 1.5, 5: 0.5},
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.text('3.5 / 5 km'), findsOneWidget);
    // Four logged days, one of which reached the goal, so three rings.
    expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
    final row = tester.getSize(find.byType(CompactHabitRow));
    expect(row.height, greaterThanOrEqualTo(64));
    expect(row.height, lessThanOrEqualTo(76));
    expect(harness.navigations, 0);
  });

  testWidgets('reaching the goal turns today into a solid tile', (
    tester,
  ) async {
    await pumpList(
      tester,
      habits: [habit(type: HabitType.count, goal: 20)],
      dayValues: {
        1: {0: 25},
      },
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Edit today'), findsOneWidget);
    expect(find.text('25 / 20'), findsOneWidget);
  });

  testWidgets('a habit with no goal never divides by zero', (tester) async {
    await pumpList(tester, habits: [habit(type: HabitType.count)]);

    expect(tester.takeException(), isNull);
    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Log today'), findsOneWidget);
  });

  testWidgets('yes/no marks today through the repository', (tester) async {
    final harness = await pumpList(
      tester,
      habits: [habit(type: HabitType.yesNo)],
      dayValues: {
        1: {1: 1, 2: 1},
      },
    );

    expect(find.text('Not marked yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip('Mark today'));
    await tester.pumpAndSettle();

    expect(find.text('Done today'), findsOneWidget);
    expect(find.byTooltip('Unmark today'), findsOneWidget);
    expect(harness.repository.stored, hasLength(3));
    expect(harness.navigations, 0);

    // Undoing removes today's row again, so an empty day stays absent.
    await tester.tap(find.byTooltip('Unmark today'));
    await tester.pumpAndSettle();

    expect(find.text('Not marked yet'), findsOneWidget);
    expect(harness.repository.stored, hasLength(2));
  });

  testWidgets('tapping a row opens details, tapping a cell does not', (
    tester,
  ) async {
    final harness = await pumpList(
      tester,
      habits: [habit(type: HabitType.count, goal: 20)],
      dayValues: {
        1: {0: 12},
      },
    );

    await tester.tap(find.text('Reading'));
    await tester.pumpAndSettle();
    expect(harness.navigations, 1);

    await tester.tap(find.byTooltip('Edit today'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(harness.navigations, 1);
  });

  testWidgets('a narrow screen squeezes the cells, never the layout', (
    tester,
  ) async {
    await pumpList(
      tester,
      width: 320,
      habits: [
        habit(
          type: HabitType.measure,
          goal: 5,
          unit: 'km',
          name: 'Morning run along the river road',
        ),
      ],
      dayValues: {
        1: {0: 3.5},
      },
    );

    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(CompactHabitRow));
    final name = tester.getRect(find.text('Morning run along the river road'));
    final cell = tester.getRect(find.byTooltip('Edit today'));
    // The name is truncated to its slot and never reaches into the week strip.
    expect(name.right, lessThanOrEqualTo(cell.left));
    expect(cell.right, lessThanOrEqualTo(row.right));
    // Column pitch, measured on the header labels the cells line up with.
    final oldest = tester.getRect(find.text('${shiftDays(today, -6).day}'));
    expect((cell.center.dx - oldest.center.dx) / 6, greaterThanOrEqualTo(18));
  });
}

class _Harness {
  _Harness(this.repository, this._navigations);

  final _FakeRepository repository;
  final int Function() _navigations;

  int get navigations => _navigations();
}
