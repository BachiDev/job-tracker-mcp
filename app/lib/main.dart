import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/marketing/landing_screen.dart';
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
      final atRoot = state.matchedLocation == '/';
      if (signedIn) return atSignIn ? '/' : null;
      if (atSignIn || atRoot) return null;
      if (state.uri.queryParameters['demo'] == '1') {
        return '/signin?demo=1';
      }
      return '/signin';
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const RootScreen()),
      GoRoute(
        path: '/signin',
        builder: (context, state) => SignInScreen(
          autoDemo: state.uri.queryParameters['demo'] == '1',
        ),
      ),
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

/// Entry point: web visitors get the marketing site, mobile visitors go
/// straight to sign-in, signed-in users get the pipeline.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return session.when(
      data: (s) {
        if (s != null) return const PipelineScreen();
        if (kIsWeb) return const LandingScreen();
        return const SignInScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SignInScreen(),
    );
  }
}

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
