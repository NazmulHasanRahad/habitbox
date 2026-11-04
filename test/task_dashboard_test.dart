import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/task_controller.dart';
import 'package:habitbox/models/subtask.dart';
import 'package:habitbox/models/task.dart';
import 'package:habitbox/models/task_completion.dart';
import 'package:habitbox/screens/task_screen.dart';
import 'package:habitbox/utils/date_key.dart';

import 'task_test_support.dart';

/// The dashboard is where the task data becomes a screen, so the risks are a
/// section that renders over nothing, a checkbox that paints without writing, a
/// folded step list that opens the wrong screen, and a card whose meta line
/// overflows the 423dp device.
void main() {
  List<Task> seedTasks() => [
    newTask(id: 1, title: 'Old report', dueDateKey: yesterdayKey),
    newTask(
      id: 2,
      title: 'Write tests',
      dueDateKey: todayDateKey,
      // Late in the evening on purpose: the day's own open task must stay out
      // of Overdue whenever the suite runs.
      dueMinutesOfDay: 23 * 60 + 30,
      reminderLeadMinutes: 30,
    ),
    newTask(id: 3, title: 'Trip plan', dueDateKey: inThreeDaysKey),
    newTask(id: 4, title: 'Send mail', dueDateKey: todayDateKey),
  ];

  List<TaskCompletion> seedCompletions() => [
    TaskCompletion(
      id: 9,
      taskId: 4,
      dateKey: todayDateKey,
      completedAt: DateTime.now(),
    ),
  ];

  List<Subtask> seedSubtasks() => const [
    Subtask(id: 11, taskId: 2, title: 'Design UI', done: true, position: 0),
    Subtask(id: 12, taskId: 2, title: 'Implement DB', position: 1),
  ];

  Future<FakeTaskRepository> pumpDashboard(
    WidgetTester tester, {
    List<Task> tasks = const [],
    List<Subtask> subtasks = const [],
    List<TaskCompletion> completions = const [],
    double width = 423,
  }) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Get.reset();
    final repository = FakeTaskRepository(
      tasks: tasks,
      subtasks: subtasks,
      completions: completions,
    );
    Get.put(TaskController(repository: repository));

    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const TaskScreen(),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Finder header(String title) => find.text(title.toUpperCase());

  Future<void> tapCheckbox(WidgetTester tester, String title) async {
    final card = find.ancestor(
      of: find.text(title),
      matching: find.descendant(
        of: find.byType(TaskScreen),
        matching: find.byType(InkWell),
      ),
    );
    // The mark box is keyed because its glyph changes with the state.
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('task-mark-box')),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The tabs are keyed in the widget tree, so a tap never depends on a label the
  /// rest of the screen might write too.
  Future<void> pickFilter(WidgetTester tester, TaskListFilter filter) async {
    await tester.tap(find.byKey(ValueKey(filter)));
    await tester.pumpAndSettle();
  }

  /// The day picker is its own screen now, so the test moves the day the two of
  /// them share rather than tapping a grid that is not on this page.
  Future<void> moveToTomorrow(WidgetTester tester) async {
    Get.find<TaskController>().selectDate(tomorrowKey);
    await tester.pumpAndSettle();
  }

  testWidgets('the list opens on the day the calendar is on', (tester) async {
    await pumpDashboard(
      tester,
      tasks: seedTasks(),
      subtasks: seedSubtasks(),
      completions: seedCompletions(),
    );

    expect(tester.takeException(), isNull);
    expect(header('Today'), findsOneWidget);
    expect(find.text('Write tests'), findsOneWidget);
    // The day's own completed task stays visible, with its mark.
    expect(find.text('Send mail'), findsOneWidget);
    expect(find.text('Old report'), findsNothing);
    expect(find.text('Trip plan'), findsNothing);

    // Card chrome: the subtask count and the reminder marker.
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byTooltip('Reminder 30 min before'), findsOneWidget);
    expect(find.byTooltip('Past due'), findsNothing);
  });

  testWidgets('Overdue takes what slipped, Pending keeps only today', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      tasks: seedTasks(),
      completions: seedCompletions(),
    );

    await pickFilter(tester, TaskListFilter.overdue);

    expect(header('Yesterday'), findsOneWidget);
    expect(find.text('Old report'), findsOneWidget);
    // Today's open work, a future day and a done task are none of them late.
    expect(find.text('Write tests'), findsNothing);
    expect(find.text('Trip plan'), findsNothing);
    expect(find.text('Send mail'), findsNothing);

    await pickFilter(tester, TaskListFilter.pending);

    expect(header('Today'), findsOneWidget);
    expect(find.text('Write tests'), findsOneWidget);
    expect(find.text('Old report'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Upcoming groups what is still ahead, date by date', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      tasks: [
        ...seedTasks(),
        newTask(id: 5, title: 'Renew passport', dueDateKey: inFiveDaysKey),
      ],
      completions: seedCompletions(),
    );

    await pickFilter(tester, TaskListFilter.upcoming);

    expect(find.text('Trip plan'), findsOneWidget);
    expect(find.text('Renew passport'), findsOneWidget);
    expect(find.text('Write tests'), findsNothing);
    expect(find.text('Old report'), findsNothing);
    // Two different days, so two sections.
    expect(
      find.descendant(
        of: find.byType(TaskScreen),
        matching: header('TOMORROW'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticking a box writes the ledger and repaints the list', (
    tester,
  ) async {
    final repository = await pumpDashboard(
      tester,
      tasks: seedTasks(),
      subtasks: seedSubtasks(),
      completions: seedCompletions(),
    );

    await tapCheckbox(tester, 'Write tests');

    expect(repository.writes, [(2, todayDateKey, true)]);
    expect(find.text('Write tests'), findsOneWidget);
    // It left Pending, where only open work shows.
    await pickFilter(tester, TaskListFilter.pending);
    expect(find.text('Write tests'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unticking a completed task reopens that day only', (
    tester,
  ) async {
    final repository = await pumpDashboard(
      tester,
      tasks: seedTasks(),
      completions: seedCompletions(),
    );

    await tapCheckbox(tester, 'Send mail');

    expect(repository.writes, [(4, todayDateKey, false)]);
    await pickFilter(tester, TaskListFilter.pending);
    expect(find.text('Send mail'), findsOneWidget);
  });

  testWidgets('another day in the calendar moves the whole dashboard', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      tasks: seedTasks(),
      completions: seedCompletions(),
    );

    await moveToTomorrow(tester);

    expect(tester.takeException(), isNull);
    // Tomorrow holds nothing, which is a note in the list, not a lost picker.
    expect(find.text('Nothing on Tomorrow'), findsOneWidget);
    expect(find.byTooltip('Calendar'), findsOneWidget);
    expect(find.text('Trip plan'), findsNothing);
    expect(find.text('Send mail'), findsNothing);
    expect(find.text('Write tests'), findsNothing);

    // Pending is measured from the real today, so it is unaffected by the day
    // the calendar is on.
    await pickFilter(tester, TaskListFilter.pending);
    expect(find.text('Write tests'), findsOneWidget);
    expect(find.text('Old report'), findsNothing);
    expect(find.text('Trip plan'), findsNothing);

    // The slipped day lives in its own view now.
    await pickFilter(tester, TaskListFilter.overdue);
    expect(find.text('Old report'), findsOneWidget);
    expect(find.text('Write tests'), findsNothing);
  });

  testWidgets('steps stay folded until the card is asked to open them', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      tasks: seedTasks(),
      subtasks: seedSubtasks(),
      completions: seedCompletions(),
    );

    expect(find.text('Design UI'), findsNothing);
    expect(find.text('Implement DB'), findsNothing);

    await tester.tap(find.byTooltip('Show 2 steps'));
    await tester.pumpAndSettle();

    expect(find.text('Design UI'), findsOneWidget);
    expect(find.text('Implement DB'), findsOneWidget);
    expect(find.byTooltip('Hide steps'), findsOneWidget);
    // Opening the steps is not opening the task.
    expect(find.text('Mark done'), findsNothing);

    await tester.tap(find.byTooltip('Hide steps'));
    await tester.pumpAndSettle();
    expect(find.text('Design UI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the card, but not its fold, opens the details', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      tasks: seedTasks(),
      subtasks: seedSubtasks(),
      completions: seedCompletions(),
    );

    await tester.tap(find.text('Write tests'));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
    expect(find.text('Design UI'), findsOneWidget);
  });

  testWidgets('an empty database still leaves the list chrome usable', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.byTooltip('Calendar'), findsOneWidget);
    expect(find.text('Add task'), findsWidgets);

    await pumpDashboard(
      tester,
      tasks: [newTask(id: 1, title: 'Hidden', archived: true)],
    );
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);
  });

  testWidgets('an empty filter leaves the calendar and the chips tappable', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      tasks: [newTask(id: 1, title: 'Later', dueDateKey: yesterdayKey)],
    );

    await pickFilter(tester, TaskListFilter.upcoming);

    expect(tester.takeException(), isNull);
    expect(find.text('Nothing upcoming'), findsOneWidget);
    expect(find.byTooltip('Calendar'), findsOneWidget);
    expect(find.text('Later'), findsNothing);

    // The Today chip means the real today, so it also brings the calendar back.
    await pickFilter(tester, TaskListFilter.today);

    expect(find.text('Nothing on Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an undated task is never lost: it waits under Anytime', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      tasks: [
        newTask(id: 1, title: 'Call the bank', createdAt: DateTime.now()),
      ],
    );

    // Undated, so its day is the day it was made: the day view can show it.
    expect(find.text('Call the bank'), findsOneWidget);

    await pickFilter(tester, TaskListFilter.pending);

    expect(header('Anytime'), findsOneWidget);
    expect(find.text('Call the bank'), findsOneWidget);

    await pickFilter(tester, TaskListFilter.upcoming);

    expect(find.text('Nothing upcoming'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every meta line fits the 423dp device', (tester) async {
    await pumpDashboard(
      tester,
      tasks: [
        newTask(
          id: 1,
          title: 'Reconcile the quarterly accounts for the finance review',
          dueDateKey: todayDateKey,
          dueMinutesOfDay: 23 * 60 + 59,
          reminderLeadMinutes: 120,
        ),
        newTask(id: 2, title: 'Short', dueDateKey: todayDateKey),
      ],
      subtasks: const [
        Subtask(id: 1, taskId: 1, title: 'a', done: true, position: 0),
        Subtask(id: 2, taskId: 1, title: 'b', position: 1),
        Subtask(id: 3, taskId: 1, title: 'c', position: 2),
      ],
    );

    // The widest card the list can be asked to draw, with its steps open.
    await tester.tap(find.byTooltip('Show 3 steps'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Reminder 2 h before'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    final card = tester.getRect(
      find.ancestor(
        of: find.text(
          'Reconcile the quarterly accounts for the finance review',
        ),
        matching: find.byType(InkWell),
      ),
    );
    expect(card.right, lessThanOrEqualTo(423 - 14 + 0.5));
    expect(card.left, greaterThanOrEqualTo(14 - 0.5));
  });
}
