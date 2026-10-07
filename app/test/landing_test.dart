import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:job_tracker/features/marketing/landing_screen.dart';
import 'package:job_tracker/main.dart';

import 'fakes.dart';
import 'package:job_tracker/core/providers.dart';
import 'package:job_tracker/core/session.dart';

void main() {
  testWidgets('landing reads like a website, not an app screen', (
    tester,
  ) async {
    // Tall surface: the whole page renders without scrolling.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: LandingScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('One pipeline for every application.'), findsOneWidget);
    expect(find.text('Try the live demo'), findsOneWidget);
    expect(find.text('AGENT SAFETY'), findsOneWidget);
    expect(find.text('BYOK inference'), findsOneWidget);
  });

  testWidgets('shell navigates between tabs', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => FakeSession(demoSession())),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const JobTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Pipeline is home; shell offers Contacts.
    expect(find.text('Acme'), findsWidgets);
    await tester.tap(find.text('Contacts').first);
    await tester.pumpAndSettle();
    expect(find.text('No contacts yet'), findsOneWidget);
  });
}
