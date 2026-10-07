import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:job_tracker/auth_spike.dart';

void main() {
  testWidgets('Auth spike screen renders steps', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthSpikeScreen()));
    expect(find.text('1. Request magic link'), findsOneWidget);
    expect(find.text('3. Check session'), findsOneWidget);
    expect(find.text('4. Get JWT'), findsOneWidget);
    // No network calls on build; log starts empty.
    expect(find.text('G. Google sign-in URL'), findsOneWidget);
  });
}
