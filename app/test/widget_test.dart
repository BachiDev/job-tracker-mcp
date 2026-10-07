import 'package:flutter_test/flutter_test.dart';

import 'package:job_tracker/main.dart';

void main() {
  testWidgets('Phase 0 scaffold renders', (tester) async {
    await tester.pumpWidget(const JobTrackerApp());
    expect(find.textContaining('Phase 0 scaffold'), findsOneWidget);
  });
}
