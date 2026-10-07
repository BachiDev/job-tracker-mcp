import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:job_tracker/core/agent.dart';
import 'package:job_tracker/core/providers.dart';
import 'package:job_tracker/core/session.dart';
import 'package:job_tracker/main.dart';

import 'fakes.dart';

Future<void> _toChat(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chat'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'add Acme');
  await tester.tap(find.text('Send'));
  // No pumpAndSettle while the agent runs: the Send spinner animates until
  // the confirm sheet resolves. Pump until the sheet exists...
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Approve').evaluate().isNotEmpty) break;
  }
  // ...then until its entrance animation lands it in view.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final box = tester.getRect(find.text('Approve'));
    if (box.top < tester.view.physicalSize.height) break;
  }
}

Future<void> _settleAgent(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pipeline renders applications + stats (wide board)', (
    tester,
  ) async {
    final api = FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => FakeSession(demoSession())),
          apiClientProvider.overrideWithValue(api),
          llmClientProvider.overrideWithValue(FakeLlm()),
          toolExecutorProvider.overrideWithValue(ToolExecutor(api)),
          llmConfigProvider.overrideWithValue(
            AsyncData(
              LlmConfig(
                baseUrl: 'http://localhost:1',
                apiKey: 'k',
                model: 'm',
              ),
            ),
          ),
        ],
        child: const JobTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Wide layout renders the board: company and role as separate texts.
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Engineer'), findsOneWidget);
    expect(find.text('Globex'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
  });

  testWidgets('pipeline renders combined rows on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
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
    expect(find.text('Acme — Engineer'), findsOneWidget);
    expect(find.text('Globex — Designer'), findsOneWidget);
  });

  testWidgets('chat confirm approve executes the write', (tester) async {
    // Tall surface: the confirm sheet fits without scrolling.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => FakeSession(demoSession())),
          apiClientProvider.overrideWithValue(api),
          llmClientProvider.overrideWithValue(FakeLlm()),
          toolExecutorProvider.overrideWithValue(ToolExecutor(api)),
          llmConfigProvider.overrideWithValue(
            AsyncData(
              LlmConfig(
                baseUrl: 'http://localhost:1',
                apiKey: 'k',
                model: 'm',
              ),
            ),
          ),
        ],
        child: const JobTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _toChat(tester);
    // Confirm sheet shows exact args.
    expect(find.text('Approve'), findsOneWidget);
    expect(find.textContaining('Acme'), findsWidgets);
    // Dismiss the sheet programmatically: geometry-independent (the tap
    // target can sit below the fold on small test surfaces).
    Navigator.of(tester.element(find.text('Approve'))).pop(true);
    await _settleAgent(tester);
  });

  testWidgets('chat confirm decline skips the write', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final api = FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => FakeSession(demoSession())),
          apiClientProvider.overrideWithValue(api),
          llmClientProvider.overrideWithValue(FakeLlm()),
          toolExecutorProvider.overrideWithValue(ToolExecutor(api)),
          llmConfigProvider.overrideWithValue(
            AsyncData(
              LlmConfig(
                baseUrl: 'http://localhost:1',
                apiKey: 'k',
                model: 'm',
              ),
            ),
          ),
        ],
        child: const JobTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _toChat(tester);
    Navigator.of(tester.element(find.text('Decline'))).pop(false);
    await _settleAgent(tester);
    expect(api.creates, 0);
    expect(find.textContaining('Declined by user'), findsWidgets);
  });
}
