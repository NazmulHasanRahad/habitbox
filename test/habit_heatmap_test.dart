import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbox/models/habit.dart';
import 'package:habitbox/utils/date_key.dart';
import 'package:habitbox/widgets/habit_heatmap.dart';

void main() {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final habit = Habit(
    id: 1,
    name: 'Run',
    type: HabitType.yesNo,
    color: 0xFF2196F3,
    iconCodePoint: 0xE87D,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpHeatmap(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: HabitHeatmap(
                habit: habit,
                entries: const {},
                accent: Colors.blue,
                selectedDateKey: todayDateKey,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('all seven weekday labels are rendered', (tester) async {
    await pumpHeatmap(tester);

    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: '$label missing');
    }
    // One cell slot (cell + gap) apart, so no label drifts off its row.
    final spacing = HabitHeatmap.cellSize + HabitHeatmap.cellGap;
    expect(
      tester.getRect(find.text('Sun')).center.dy -
          tester.getRect(find.text('Mon')).center.dy,
      6 * spacing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('month labels keep all three letters instead of clipping', (
    tester,
  ) async {
    await pumpHeatmap(tester);

    // A week column is only 16px wide; a 3-letter label must overflow it
    // rather than wrap to "Oc"/"Se".
    final monthLabels = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          !labels.contains(widget.data) &&
          RegExp(r'^[A-Z][a-z]{2}$').hasMatch(widget.data!),
    );
    expect(monthLabels, findsWidgets);
    final columnWidth = HabitHeatmap.cellSize + HabitHeatmap.cellGap;
    for (final label in tester.widgetList<Text>(monthLabels)) {
      final rect = tester.getRect(find.byWidget(label));
      expect(rect.width, greaterThan(columnWidth));
      expect(rect.height, lessThanOrEqualTo(16));
    }
  });

  testWidgets('today\'s cell lines up with its own weekday label', (
    tester,
  ) async {
    await pumpHeatmap(tester);

    // The only bordered cell is today (also the selected one).
    final bordered = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).border != null,
    );
    expect(bordered, findsOneWidget);

    final label = labels[today.weekday - 1];
    final delta =
        (tester.getRect(find.text(label)).center.dy -
                tester.getRect(bordered).center.dy)
            .abs();
    expect(delta, lessThan(0.6), reason: '$label is not on today\'s row');
  });
}
