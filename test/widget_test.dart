import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_run_tracker_app/main.dart';

void main() {
  testWidgets('shows the Run Tracker dashboard', (tester) async {
    await tester.pumpWidget(const RunTrackerApp());
    expect(find.text('สวัสดี, นักวิ่ง 👋'), findsOneWidget);
    expect(find.text('การวิ่งล่าสุด'), findsOneWidget);
  });
}
