import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbox/widgets/month_calendar.dart';

void main() {
  testWidgets('MonthCalendar renders every week row of October 2026',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MonthCalendar(
                displayMonth: DateTime(2026, 10),
                markedKeys: const {},
                selectedDateKey: '2026-10-28',
                accent: Colors.orange,
                onDayTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    // October 2026 starts Thursday: leading 3 + 31 days = 5 week rows,
    // so 35 day cells render (Sep 28-30 and Nov 1-1 are adjacent-month days).
    expect(find.byType(GestureDetector), findsNWidgets(35));
    for (final d in ['12', '19', '26', '31']) {
      expect(find.text(d), findsOneWidget, reason: 'day $d missing');
    }

    // The last week row sits below the first four rows.
    final day1 = tester.getRect(find.text('1').first);
    final day26 = tester.getRect(find.text('26'));
    expect(day26.top, greaterThan(day1.top + 4 * 50));
  });

  testWidgets('MonthCalendar renders every row for November 2026',
      (tester) async {
    // November 2026 starts Sunday: leading 6 + 30 days = 36 -> 6 week rows.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MonthCalendar(
                displayMonth: DateTime(2026, 11),
                markedKeys: const {},
                selectedDateKey: '2026-11-15',
                accent: Colors.orange,
                onDayTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsNWidgets(42));
    // 30 Nov plus adjacent-month 30s -> at least two, last row visible.
    expect(find.text('30'), findsAtLeastNWidgets(2));
    expect(find.text('21'), findsOneWidget);
  });
}
