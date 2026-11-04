import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:habitbox/controllers/task_controller.dart';
import 'package:habitbox/models/task.dart';
import 'package:habitbox/models/task_completion.dart';
import 'package:habitbox/models/task_occurrence_edit.dart';
import 'package:habitbox/utils/date_key.dart';

import 'task_test_support.dart';

/// What the three edit scopes and the two delete scopes actually do to the
/// rows, checked against the in-memory store rather than a screen.
///
/// The rules these tests protect: a narrower scope never rewrites the series,
/// an override only stores what changed, a split leaves the completed days
/// where they were earned, and nothing here can erase history.
void main() {
  setUp(() => Get.reset());
  tearDown(() => Get.reset());

  Future<TaskController> open(FakeTaskRepository repository) async {
    final controller = Get.put(TaskController(repository: repository));
    await controller.loadTasks();
    return controller;
  }

  Task stored(TaskController controller, int id) =>
      controller.tasks.firstWhere((task) => task.id == id);

  group('the series scope', () {
    test(
      'writes the row and makes the steps match without resetting them',
      () async {
        final repository = FakeTaskRepository(
          tasks: [
            newTask(
              id: 1,
              title: 'Draft the chapter',
              dueDateKey: tomorrowKey,
              dueMinutesOfDay: 540,
              reminderLeadMinutes: 30,
            ),
          ],
          subtasks: [
            newSubtask(id: 10, taskId: 1, title: 'Read sources'),
            newSubtask(
              id: 11,
              taskId: 1,
              title: 'Write intro',
              done: true,
              position: 1,
            ),
          ],
        );
        final controller = await open(repository);
        final before = stored(controller, 1);

        await controller.saveTask(
          before.copyWith(title: 'Draft methodology'),
          subtasks: [
            SubtaskDraft(
              existing: repository.subtasks[1],
              title: 'Write intro',
            ),
            SubtaskDraft(
              existing: repository.subtasks[0],
              title: 'Read papers',
            ),
            const SubtaskDraft(title: 'Send to advisor'),
          ],
        );

        expect(repository.updated.single.title, 'Draft methodology');
        // Fields the form did not touch come through unchanged.
        final written = repository.updated.single;
        expect(written.dueDateKey, tomorrowKey);
        expect(written.dueMinutesOfDay, 540);
        expect(written.reminderLeadMinutes, 30);
        expect(written.createdAt, before.createdAt);

        expect(
          repository.subtaskCalls
              .where((call) => call.$1 == 'renamed')
              .map((call) => call.$3),
          contains('Read papers'),
        );
        expect(
          repository.subtaskCalls.map((call) => call.$1),
          contains('added'),
        );
        // The finished step keeps its completion stamp through the rename.
        final kept = repository.subtasks.firstWhere((step) => step.id == 11);
        expect(kept.done, isTrue);
        expect(kept.completedAt, isNotNull);
        // And the list order the editor showed is the order that was stored.
        expect(repository.reorders.last, [11, 10, 900]);
      },
    );
  });

  group('the occurrence scope', () {
    test('stores only the field that changed and inherits the rest', () async {
      final repository = FakeTaskRepository(
        tasks: [
          newTask(
            id: 1,
            title: 'Standup',
            dueDateKey: todayDateKey,
            recurrence: TaskRecurrence.daily,
            recurrenceStartKey: todayDateKey,
          ),
        ],
      );
      final controller = await open(repository);

      await controller.saveTask(
        stored(controller, 1).copyWith(title: 'Standup with the client'),
        scope: TaskEditScope.occurrence,
        occurrenceKey: todayDateKey,
      );

      final edit = repository.editedOccurrences.single;
      expect(edit.taskId, 1);
      expect(edit.title, 'Standup with the client');
      expect(edit.dueDateKey, isNull);
      expect(edit.dueMinutesOfDay, isNull);
      // The series row itself was not rewritten.
      expect(repository.updated, isEmpty);
      expect(stored(controller, 1).title, 'Standup');
    });

    test('shows the override on its own day only', () async {
      final repository = FakeTaskRepository(
        tasks: [
          newTask(
            id: 1,
            title: 'Standup',
            dueDateKey: todayDateKey,
            recurrence: TaskRecurrence.daily,
          ),
        ],
        occurrenceEdits: [
          TaskOccurrenceEdit(
            taskId: 1,
            dateKey: todayDateKey,
            title: 'Standup (with the client)',
            editedAt: DateTime(2026, 10, 30, 9),
          ),
        ],
      );
      final controller = await open(repository);

      expect(
        controller
            .effective(stored(controller, 1), dateKey: todayDateKey)
            .title,
        'Standup (with the client)',
      );
      expect(
        controller.effective(stored(controller, 1), dateKey: tomorrowKey).title,
        'Standup',
      );
    });

    test('writes nothing when the occurrence did not change', () async {
      final repository = FakeTaskRepository(
        tasks: [newTask(id: 1, title: 'Standup', dueDateKey: todayDateKey)],
      );
      final controller = await open(repository);

      await controller.saveTask(
        stored(controller, 1),
        scope: TaskEditScope.occurrence,
        occurrenceKey: todayDateKey,
      );

      expect(repository.editedOccurrences, isEmpty);
      expect(repository.updated, isEmpty);
    });
  });

  group('the future scope', () {
    test(
      'closes the series the day before and continues with a child row',
      () async {
        final repository = FakeTaskRepository(
          tasks: [
            newTask(
              id: 1,
              title: 'Review pull requests',
              dueDateKey: todayDateKey,
              recurrence: TaskRecurrence.daily,
              recurrenceStartKey: yesterdayKey,
            ),
          ],
          subtasks: [newSubtask(id: 10, taskId: 1, title: 'Check CI')],
          completions: [
            TaskCompletion(
              taskId: 1,
              dateKey: yesterdayKey,
              completedAt: DateTime(2026, 10, 29, 10),
            ),
          ],
        );
        final controller = await open(repository);
        final historyBefore = List.of(repository.completions);

        await controller.saveTask(
          stored(controller, 1).copyWith(dueMinutesOfDay: 600),
          scope: TaskEditScope.future,
          occurrenceKey: todayDateKey,
        );

        final split = repository.splits.single;
        expect(split.taskId, 1);
        expect(split.fromDateKey, todayDateKey);

        final closed = stored(controller, 1);
        expect(closed.recurrenceUntilKey, yesterdayKey);

        final child = controller.tasks.firstWhere(
          (task) => task.parentTaskId == 1,
        );
        expect(child.recurrenceStartKey, todayDateKey);
        expect(child.dueMinutesOfDay, 600);
        expect(child.title, 'Review pull requests');
        // The old series keeps its steps and its marks: nothing moved.
        expect(stored(controller, 1).id, 1);
        expect(repository.completions, historyBefore);
        expect(repository.subtasks.single.taskId, 1);
        expect(
          repository.subtaskCalls.where((c) => c.$1 == 'renamed'),
          isEmpty,
        );
      },
    );
  });

  group('deleting', () {
    test('sends the task to the trash instead of erasing it', () async {
      final repository = FakeTaskRepository(
        tasks: [newTask(id: 1, title: 'Old task', dueDateKey: todayDateKey)],
        subtasks: [newSubtask(id: 10, taskId: 1, title: 'Step')],
        completions: [
          TaskCompletion(
            taskId: 1,
            dateKey: todayDateKey,
            completedAt: DateTime(2026, 10, 30, 10),
          ),
        ],
      );
      final controller = await open(repository);

      await controller.deleteTask(1);

      expect(repository.trashed, [1]);
      expect(repository.subtaskCalls, isEmpty);
      expect(repository.completions, hasLength(1));
      // The reload drops it from the list the dashboard draws.
      expect(controller.tasks.where((task) => task.id == 1), isEmpty);
    });

    test('ending a series keeps the row and its past days', () async {
      final repository = FakeTaskRepository(
        tasks: [
          newTask(
            id: 1,
            title: 'Standup',
            dueDateKey: todayDateKey,
            recurrence: TaskRecurrence.daily,
          ),
        ],
      );
      final controller = await open(repository);

      await controller.endSeriesBefore(1, todayDateKey);

      expect(repository.endedSeries.single, (
        taskId: 1,
        fromDateKey: todayDateKey,
      ));
      expect(repository.trashed, isEmpty);
      expect(stored(controller, 1).recurrenceUntilKey, yesterdayKey);
    });
  });
}
