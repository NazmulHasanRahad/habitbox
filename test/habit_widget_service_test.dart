import 'package:flutter_test/flutter_test.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/services/habit_widget_service.dart';
import 'package:habitbox/utils/date_key.dart';

void main() {
  group('HabitWidgetService.buildWidgetData', () {
    test('includes 182 daily states for yes/no habits', () {
      final habit = Habit(
        id: 4,
        name: 'Read',
        type: HabitType.yesNo,
        color: 0xFF7C4DFF,
        iconCodePoint: 0,
        createdAt: today,
      );
      final entries = <int, Map<String, double>>{
        4: {dateKeyFor(today): 1, dateKeyFor(shiftDays(today, -2)): 1},
      };

      final data = HabitWidgetService.buildWidgetData([habit], entries);
      final days = data.single['completedByDate']! as Map<String, bool>;

      expect(data.single['id'], 4);
      expect(data.single['name'], 'Read');
      expect(days, hasLength(182));
      expect(days[dateKeyFor(shiftDays(today, -2))], isTrue);
      expect(days[dateKeyFor(shiftDays(today, -1))], isFalse);
      expect(days[dateKeyFor(today)], isTrue);
    });

    test('uses the habit goal to determine count and measure completion', () {
      final habit = Habit(
        id: 9,
        name: 'Pages',
        type: HabitType.count,
        color: 0xFF00BCD4,
        iconCodePoint: 0,
        goalValue: 10,
        createdAt: today,
      );
      final entries = <int, Map<String, double>>{
        9: {dateKeyFor(shiftDays(today, -1)): 10, dateKeyFor(today): 8},
      };

      final days =
          HabitWidgetService.buildWidgetData([
                habit,
              ], entries).single['completedByDate']!
              as Map<String, bool>;

      expect(days[dateKeyFor(shiftDays(today, -1))], isTrue);
      expect(days[dateKeyFor(today)], isFalse);
    });
  });
}
