import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/pipeline/application_detail_screen.dart';
import 'features/pipeline/pipeline_screen.dart';
import 'features/settings/settings_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: JobTrackerApp()));
}

final _routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (session.isLoading) return null;
      final signedIn = session.value != null;
      final atSignIn = state.matchedLocation == '/signin';
      if (signedIn) return atSignIn ? '/' : null;
      if (state.uri.queryParameters['demo'] == '1') {
        return atSignIn ? null : '/signin?demo=1';
      }
      return atSignIn ? null : '/signin';
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, state) => SignInScreen(
          autoDemo: state.uri.queryParameters['demo'] == '1',
        ),
      ),
      GoRoute(path: '/', builder: (context, state) => const PipelineScreen()),
      GoRoute(
        path: '/app/:id',
        builder: (context, state) =>
            ApplicationDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class JobTrackerApp extends ConsumerWidget {
  const JobTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'Job Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
