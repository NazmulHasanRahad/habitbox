import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/task_controller.dart';
import 'package:habitbox/models/task.dart';
import 'package:habitbox/screens/add_task_screen.dart';
import 'package:habitbox/screens/task_screen.dart';
import 'package:habitbox/utils/date_key.dart';

import 'task_test_support.dart';

/// The form is the only place a task is written, so these tests watch what it
/// hands the controller: nothing saved without a title, nothing saved twice,
/// nothing lost that the form never showed.
void main() {
  Task recurring() => newTask(
    id: 1,
    title: 'Standup',
    dueDateKey: todayDateKey,
    recurrence: TaskRecurrence.daily,
    recurrenceStartKey: yesterdayKey,
    reminderLeadMinutes: 30,
  );

  Future<FakeTaskRepository> openEditor(
    WidgetTester tester, {
    required FakeTaskRepository repository,
    Task? initial,
    double height = 1600,
  }) async {
    tester.view.physicalSize = Size(423 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Get.reset();
    final controller = Get.put(TaskController(repository: repository));
    await controller.loadTasks();
    final target =
        initial ?? (controller.tasks.isEmpty ? null : controller.tasks.first);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: _darkTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Get.to(() => AddTaskScreen(initialTask: target)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return repository;
  }

  Future<FakeTaskRepository> openDashboard(
    WidgetTester tester,
    FakeTaskRepository repository,
  ) async {
    tester.view.physicalSize = Size(423 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Get.reset();
    Get.put(TaskController(repository: repository));
    await tester.pumpWidget(
      GetMaterialApp(theme: _darkTheme(), home: const TaskScreen()),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  /// `FilledButton.icon` builds a private subclass and `byType` matches only the
  /// exact type, so the save button is found by what it is instead.
  Finder saveButton({String label = 'Create task'}) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is FilledButton),
  );

  Future<void> typeTitle(WidgetTester tester, String title) =>
      tester.enterText(find.byType(TextField).first, title);

  Future<void> save(WidgetTester tester, {String label = 'Create task'}) async {
    await tester.tap(saveButton(label: label));
    await tester.pumpAndSettle();
  }

  Future<void> chooseScope(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// The 'Add a step' field, matched on its decoration because a hint is not
  /// something the standard finders reach.
  Finder addStepField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.hintText == 'Add a step',
  );

  testWidgets('the add action on the dashboard writes a task and the card is '
      'there when it comes back', (tester) async {
    final repository = await openDashboard(tester, FakeTaskRepository());

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    expect(find.text('PRIORITY'), findsOneWidget);
    expect(find.text('No tasks yet'), findsNothing);

    await typeTitle(tester, 'Plan the revision sheet');
    await tester.enterText(addStepField(), 'List weak topics');
    await tester.tap(find.byTooltip('Add step'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(repository.inserted.single.title, 'Plan the revision sheet');
    // A new task lands on the day the dashboard is looking at.
    expect(repository.inserted.single.dueDateKey, todayDateKey);
    expect(repository.subtasks.single.title, 'List weak topics');
    expect(find.text('Plan the revision sheet'), findsOneWidget);
    expect(find.text('No tasks yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty title holds the save shut and says why', (
    tester,
  ) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(),
    );

    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    expect(find.text('Enter a title.'), findsNothing);

    await typeTitle(tester, '   ');
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await typeTitle(tester, 'Write the summary');
    expect(find.text('Enter a title.'), findsNothing);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);

    await save(tester);
    expect(repository.inserted.single.title, 'Write the summary');
  });

  testWidgets('a second tap cannot save the same task twice', (tester) async {
    final repository = _GatedRepository();
    await openEditor(tester, repository: repository);

    await typeTitle(tester, 'One row only');
    repository.gate = Completer<void>();
    await tester.tap(saveButton());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await tester.tap(saveButton());
    await tester.pump();
    repository.gate!.complete();
    await tester.pumpAndSettle();

    expect(repository.inserted, hasLength(1));
  });

  testWidgets('editing starts with the task already filled in', (tester) async {
    await openEditor(
      tester,
      repository: FakeTaskRepository(
        tasks: [
          newTask(
            id: 1,
            title: 'Reconcile the accounts',
            description: 'Q3 folder on the shared drive',
            dueDateKey: tomorrowKey,
            dueMinutesOfDay: 9 * 60 + 30,
          ),
        ],
        subtasks: [newSubtask(id: 10, taskId: 1, title: 'Pull the ledger')],
      ),
    );

    final fields = find.byType(TextField);
    expect(
      tester.widget<TextField>(fields.first).controller?.text,
      'Reconcile the accounts',
    );
    expect(find.text('Q3 folder on the shared drive'), findsOneWidget);
    // The day and the moment on it share the one due-date line.
    expect(find.text('Tomorrow · 9:30 AM'), findsOneWidget);
    expect(find.text('Pull the ledger'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an edit keeps the values the form never shows', (tester) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(tasks: [recurring()]),
      initial: recurring(),
    );

    await typeTitle(tester, 'Standup with the client');
    await save(tester, label: 'Save changes');

    await chooseScope(tester, 'Entire series');

    final written = repository.updated.single;
    expect(written.title, 'Standup with the client');
    // Series fields the form does not carry are passed straight through.
    expect(written.recurrence, TaskRecurrence.daily);
    expect(written.recurrenceStartKey, yesterdayKey);
    expect(written.reminderLeadMinutes, 30);
    expect(written.createdAt, recurring().createdAt);
    // A series edit writes the row, not an override.
    expect(repository.editedOccurrences, isEmpty);
    expect(repository.splits, isEmpty);
  });

  testWidgets('only this occurrence stores the difference, not the row', (
    tester,
  ) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(tasks: [recurring()]),
      initial: recurring(),
    );

    await typeTitle(tester, 'Standup with the client');
    await save(tester, label: 'Save changes');
    await chooseScope(tester, 'Only this occurrence');

    final edit = repository.editedOccurrences.single;
    expect(edit.taskId, 1);
    expect(edit.dateKey, todayDateKey);
    expect(edit.title, 'Standup with the client');
    expect(repository.updated, isEmpty);
  });

  testWidgets('backing out of the scope choice writes nothing', (tester) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(tasks: [recurring()]),
      initial: recurring(),
    );

    await typeTitle(tester, 'Standup with the client');
    await save(tester, label: 'Save changes');
    expect(find.text('Apply this change to'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.updated, isEmpty);
    expect(repository.editedOccurrences, isEmpty);
    expect(repository.splits, isEmpty);
    // Still on the form, with what was typed intact.
    expect(find.text('Save changes'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'Standup with the client',
    );
  });

  testWidgets('a changed step list leaves only the whole series open', (
    tester,
  ) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(
        tasks: [recurring()],
        subtasks: [newSubtask(id: 10, taskId: 1, title: 'Check CI')],
      ),
      initial: recurring(),
    );

    await tester.enterText(addStepField(), 'Triage the queue');
    await tester.tap(find.byTooltip('Add step'));
    await tester.pumpAndSettle();
    await save(tester, label: 'Save changes');

    expect(
      find.text(
        'You changed the steps, so only the whole series can be updated.',
      ),
      findsOneWidget,
    );

    // The narrower scopes would drop the step, so tapping them does nothing.
    await tester.tap(find.text('Only this occurrence'));
    await tester.pumpAndSettle();
    expect(find.text('Apply this change to'), findsOneWidget);
    await tester.tap(find.text('This and future occurrences'));
    await tester.pumpAndSettle();
    expect(find.text('Apply this change to'), findsOneWidget);

    await chooseScope(tester, 'Entire series');

    expect(repository.updated, hasLength(1));
    expect(repository.editedOccurrences, isEmpty);
    expect(repository.splits, isEmpty);
    expect(repository.subtaskCalls.map((call) => call.$1), contains('added'));
  });

  testWidgets('clearing the due date clears the time with it', (tester) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(
        tasks: [
          newTask(
            id: 1,
            title: 'Renew the passport',
            dueDateKey: tomorrowKey,
            dueMinutesOfDay: 540,
          ),
        ],
      ),
      initial: newTask(
        id: 1,
        title: 'Renew the passport',
        dueDateKey: tomorrowKey,
        dueMinutesOfDay: 540,
      ),
    );

    await tester.tap(find.byTooltip('Clear').first);
    await tester.pumpAndSettle();

    expect(find.text('No due date'), findsOneWidget);
    expect(find.textContaining('9:00 AM'), findsNothing);
    expect(find.byTooltip('Clear'), findsNothing);
    // Picking a day leads straight into picking the time on it.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await save(tester, label: 'Save changes');
    expect(repository.updated.single.dueDateKey, isNull);
    expect(repository.updated.single.dueMinutesOfDay, isNull);
  });

  testWidgets('cancelling the date picker leaves the day alone', (
    tester,
  ) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(
        tasks: [
          newTask(id: 1, title: 'Renew the passport', dueDateKey: tomorrowKey),
        ],
      ),
      initial: newTask(
        id: 1,
        title: 'Renew the passport',
        dueDateKey: tomorrowKey,
      ),
    );

    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    expect(find.text('Select date'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Tomorrow'), findsOneWidget);
    await save(tester, label: 'Save changes');
    expect(repository.updated.single.dueDateKey, tomorrowKey);
  });

  testWidgets('the form offers no sorting and stores the title it shows', (
    tester,
  ) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(),
    );

    await typeTitle(tester, 'Revise lecture notes');
    expect(find.text('Sorting'), findsNothing);
    expect(find.text('MEDIUM'), findsNothing);
    await save(tester);

    expect(repository.inserted.single.title, 'Revise lecture notes');
    expect(find.text('Add a step'), findsNothing);
  });

  testWidgets('steps typed here are created with the task', (tester) async {
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(),
    );

    await typeTitle(tester, 'Prepare the presentation');
    for (final step in ['Outline slides', 'Draft script', 'Rehearse once']) {
      await tester.enterText(addStepField(), step);
      await tester.tap(find.byTooltip('Add step'));
      await tester.pumpAndSettle();
    }
    expect(find.text('3 steps.'), findsOneWidget);

    // The one dropped before saving never reaches the database.
    await tester.tap(find.byTooltip('Remove step').last);
    await tester.pumpAndSettle();
    await save(tester);

    expect(repository.subtasks.map((subtask) => subtask.title), [
      'Outline slides',
      'Draft script',
    ]);
    expect(repository.subtasks.single.taskId, repository.inserted.single.id);
  });

  testWidgets('renaming a step in the form keeps its done state', (
    tester,
  ) async {
    final stored = newSubtask(id: 10, taskId: 1, title: 'Check CI', done: true);
    final repository = await openEditor(
      tester,
      repository: FakeTaskRepository(
        tasks: [newTask(id: 1, title: 'Review pull requests')],
        subtasks: [stored],
      ),
      initial: newTask(id: 1, title: 'Review pull requests'),
    );

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), 'Check the CI run');
    await save(tester, label: 'Save changes');

    final renamed = repository.subtasks.single;
    expect(renamed.title, 'Check the CI run');
    expect(renamed.done, isTrue);
    expect(renamed.completedAt, isNotNull);
  });

  testWidgets('the whole form is reachable on a 423dp phone', (tester) async {
    await openEditor(
      tester,
      height: 900,
      repository: FakeTaskRepository(
        tasks: [recurring()],
        subtasks: [
          newSubtask(id: 10, taskId: 1, title: 'Check CI'),
          newSubtask(id: 11, taskId: 1, title: 'Read the diff', position: 1),
        ],
      ),
      initial: recurring(),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(addStepField(), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A repository that holds the first insert open, the way a slow write would,
/// so a double tap can be tested for real.
class _GatedRepository extends FakeTaskRepository {
  _GatedRepository();

  Completer<void>? gate;

  @override
  Future<int> insertTask(
    Task task, {
    List<String> subtaskTitles = const [],
  }) async {
    final wait = gate;
    if (wait != null) await wait.future;
    return super.insertTask(task, subtaskTitles: subtaskTitles);
  }
}

ThemeData _darkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  ),
);
