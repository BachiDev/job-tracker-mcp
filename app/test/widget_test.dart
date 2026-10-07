import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:job_tracker/core/session.dart';
import 'package:job_tracker/main.dart';

import 'fakes.dart';

void main() {
  testWidgets('boots to sign-in when signed out (auth gating)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => FakeSession(null))],
        child: const JobTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Try the demo'), findsOneWidget);
  });
}
