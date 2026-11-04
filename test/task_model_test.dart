import 'package:flutter_test/flutter_test.dart';
import 'package:habitbox/models/subtask.dart';
import 'package:habitbox/models/task.dart';
import 'package:habitbox/models/task_activity.dart';
import 'package:habitbox/models/task_occurrence_edit.dart';
import 'package:habitbox/utils/date_key.dart';

Task _task({String? dueDateKey = '2026-10-30', int? dueMinutesOfDay}) {
  final stamp = DateTime(2026, 10, 1, 9);
  return Task(
    id: 7,
    title: 'Ship the release',
    description: 'Then write the notes',
    dueDateKey: dueDateKey,
    dueMinutesOfDay: dueMinutesOfDay,
    reminderLeadMinutes: 30,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

void main() {
  group('task enums', () {
    test('an unknown stored value falls back to the default', () {
      expect(TaskRecurrence.fromDbValue('yearly'), TaskRecurrence.none);
      expect(TaskActivityKind.fromDbValue('shared'), TaskActivityKind.edited);
    });

    test('every db value round trips through its enum', () {
      for (final kind in TaskRecurrence.values) {
        expect(TaskRecurrence.fromDbValue(kind.dbValue), kind);
      }
      for (final kind in TaskActivityKind.values) {
        expect(TaskActivityKind.fromDbValue(kind.dbValue), kind);
      }
    });
  });

  group('task row mapping', () {
    test('a task survives a map round trip with every field', () {
      final task = _task(dueMinutesOfDay: 17 * 60 + 30);
      final restored = Task.fromMap(task.toMap(includeId: true));

      expect(restored.id, 7);
      expect(restored.title, 'Ship the release');
      expect(restored.description, 'Then write the notes');
      expect(restored.dueDateKey, '2026-10-30');
      expect(restored.dueMinutesOfDay, 1050);
      expect(restored.reminderLeadMinutes, 30);
      expect(restored.recurrence, TaskRecurrence.none);
      expect(restored.archived, isFalse);
      expect(restored.deletedAt, isNull);
      expect(restored.createdAt, task.createdAt);
      expect(restored.updatedAt, task.updatedAt);
    });

    test(
      'optional columns stay nullable and the id is left out for insert',
      () {
        final map = _task(dueDateKey: null).toMap();

        expect(map['id'], isNull, reason: 'insert must allocate the row id');
        expect(map['due_date_key'], isNull);
        expect(map['due_time_minutes'], isNull);
        expect(map['deleted_at'], isNull);
        expect(
          map.containsKey('priority'),
          isFalse,
          reason: 'the retired column is never written',
        );
        expect(
          map.containsKey('category_id'),
          isFalse,
          reason: 'the retired column is never written',
        );

        final restored = Task.fromMap(map);
        expect(restored.dueDateKey, isNull);
        expect(restored.dueMinutesOfDay, isNull);
      },
    );

    test('flags are stored as integers so SQLite can index them', () {
      final trashed = _task().copyWith(
        archived: true,
        deletedAt: DateTime(2026, 10, 29, 23),
      );
      final map = trashed.toMap();

      expect(map['archived'], 1);
      expect(map['deleted_at'], trashed.deletedAt!.millisecondsSinceEpoch);
      expect(Task.fromMap(map).archived, isTrue);
      expect(Task.fromMap(map).deletedAt, trashed.deletedAt);
    });

    test(
      'the day order round trips, and an old row without it starts at 0',
      () {
        final map = _task().copyWith(sortOrder: 3).toMap();

        expect(map['sort_order'], 3);
        expect(Task.fromMap(map).sortOrder, 3);
        expect(
          Task.fromMap(map..remove('sort_order')).sortOrder,
          0,
          reason: 'a row written before the column existed has no order',
        );
      },
    );

    test(
      'a recurring series keeps its anchor, interval and end in one row',
      () {
        final series = _task().copyWith(
          recurrence: TaskRecurrence.custom,
          recurrenceInterval: 10,
          recurrenceStartKey: '2026-10-05',
          recurrenceUntilKey: '2026-12-20',
          parentTaskId: 2,
        );
        final restored = Task.fromMap(series.toMap(includeId: true));

        expect(restored.recurrence, TaskRecurrence.custom);
        expect(restored.recurrenceInterval, 10);
        expect(restored.recurrenceStartKey, '2026-10-05');
        expect(restored.recurrenceUntilKey, '2026-12-20');
        expect(restored.parentTaskId, 2);
      },
    );
  });

  group('overdue rule', () {
    final now = DateTime(2026, 10, 30, 14);

    test('a later day is never overdue', () {
      expect(_task(dueDateKey: '2026-11-02').isOverdue(now), isFalse);
    });

    test('an earlier day is overdue', () {
      expect(_task(dueDateKey: '2026-10-29').isOverdue(now), isTrue);
    });

    test('today compares against the due time, not just the day', () {
      expect(_task(dueMinutesOfDay: 16 * 60).isOverdue(now), isFalse);
      expect(_task(dueMinutesOfDay: 13 * 60 + 59).isOverdue(now), isTrue);
      expect(_task(dueMinutesOfDay: 14 * 60).isOverdue(now), isFalse);
    });

    test(
      'a task without a due date and a completed occurrence are not overdue',
      () {
        expect(_task(dueDateKey: null).isOverdue(now), isFalse);
        expect(
          _task(dueDateKey: '2026-10-20').isOverdue(now, isComplete: true),
          isFalse,
        );
      },
    );

    test('the day key matches today under the shared helper', () {
      expect(dateKeyFor(DateTime(2026, 10, 5)), '2026-10-05');
      expect(_task(dueDateKey: todayDateKey).isOverdue(now), isFalse);
    });
  });

  group('per-occurrence overrides', () {
    test('only the fields actually changed replace the series value', () {
      final series = _task(dueDateKey: '2026-10-30');
      final edit = TaskOccurrenceEdit(
        taskId: 7,
        dateKey: '2026-10-30',
        title: 'Ship the release today',
        reminderLeadMinutes: 15,
        editedAt: DateTime(2026, 10, 30, 8),
      );

      final effective = edit.applyTo(series);

      expect(effective.title, 'Ship the release today');
      expect(effective.reminderLeadMinutes, 15);
      expect(
        effective.dueDateKey,
        '2026-10-30',
        reason: 'untouched fields inherit',
      );
      expect(effective.description, series.description);
      expect(effective.id, series.id);
    });

    test('an override row survives its own map round trip', () {
      final edit = TaskOccurrenceEdit(
        id: 4,
        taskId: 7,
        dateKey: '2026-10-31',
        dueMinutesOfDay: 9 * 60,
        recurrence: TaskRecurrence.none,
        editedAt: DateTime(2026, 10, 30, 8),
      );
      final restored = TaskOccurrenceEdit.fromMap(edit.toMap(includeId: true));

      expect(restored.id, 4);
      expect(restored.dateKey, '2026-10-31');
      expect(restored.dueMinutesOfDay, 540);
      expect(restored.recurrence, TaskRecurrence.none);
      expect(restored.title, isNull, reason: 'null means inherit, not empty');
      expect(restored.editedAt, edit.editedAt);
    });
  });

  group('subtasks', () {
    test('the done flag is stored as 0 or 1 and keeps its position', () {
      final subtask = Subtask(
        id: 9,
        taskId: 7,
        title: 'Design UI',
        done: true,
        position: 2,
        completedAt: DateTime(2026, 10, 30, 11),
      );
      final map = subtask.toMap(includeId: true);

      expect(map['done'], 1);
      expect(map['position'], 2);
      final restored = Subtask.fromMap(map);
      expect(restored.done, isTrue);
      expect(restored.taskId, 7);
      expect(restored.completedAt, subtask.completedAt);

      expect(subtask.toMap()['completed_at'], isNotNull);
      expect(
        Subtask(taskId: 7, title: 'Implement DB').toMap()['done'],
        0,
        reason: 'a new step starts open',
      );
    });
  });

  group('activity log', () {
    test('a history row maps its occurrence day and detail', () {
      final activity = TaskActivity(
        id: 1,
        taskId: 7,
        kind: TaskActivityKind.completed,
        dateKey: '2026-10-30',
        detail: 'Marked done',
        createdAt: DateTime(2026, 10, 30, 14, 5),
      );
      final restored = TaskActivity.fromMap(activity.toMap(includeId: true));

      expect(restored.kind, TaskActivityKind.completed);
      expect(restored.dateKey, '2026-10-30');
      expect(restored.detail, 'Marked done');
      expect(restored.createdAt, activity.createdAt);
    });
  });
}
