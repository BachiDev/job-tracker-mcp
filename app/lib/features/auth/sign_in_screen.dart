import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/endpoints.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

/// Sign-in: magic link (paste-link verify, works around the missing Dart SDK)
/// or one-tap ephemeral demo. `?demo=1` deep-link auto-bootstraps demo.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.autoDemo = false});

  final bool autoDemo;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _link = TextEditingController();
  final _log = <String>[];
  bool _busy = false;
  bool _linkSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _demo());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _link.dispose();
    super.dispose();
  }

  String get _callbackUrl =>
      kIsWeb ? Uri.base.origin : Endpoints.mobileCallbackUrl;

  void _say(String s) => setState(() => _log.add(s));

  Future<void> _requestLink() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _say('Enter your email first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .requestMagicLink(email, _callbackUrl);
      _say('Link sent to $email — paste it below (do not open it elsewhere).');
      setState(() => _linkSent = true);
    } on ApiException catch (e) {
      _say('Request failed: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final url = _link.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.verifyLink(url);
      _say('Verified. Cookies: ${api.cookieNames}');
      final jwt = await api.fetchJwt();
      api.token = jwt;
      final session = await api.getSession();
      final user = session?['user'] as Map<String, dynamic>?;
      final userId = user?['id'] as String?;
      if (userId == null) {
        _say('Signed in, but no user id came back — aborting.');
        return;
      }
      await ref
          .read(sessionProvider.notifier)
          .signIn(
            Session(
              token: jwt,
              userId: userId,
              email: _email.text.trim(),
              cookies: api.cookies,
            ),
          );
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      _say('Verify failed: ${e.message}');
      _say('Tip: links are single-use — request a fresh one and paste it within a minute.');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _demo() async {
    setState(() => _busy = true);
    try {
      final boot = await ref.read(apiClientProvider).bootstrapDemo();
      await ref
          .read(sessionProvider.notifier)
          .signIn(
            Session(
              token: boot.token,
              userId: boot.userId,
              isDemo: true,
              expiresAt: boot.expiresAt,
            ),
          );
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      _say('Demo failed: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Kicker(text: 'job tracker'),
          Text(
            'One pipeline for every application.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _requestLink,
            child: const Text('Email me a sign-in link'),
          ),
          if (_linkSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Paste the emailed link here',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: const Text('Verify & sign in'),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'No email handy? Explore with clearly-labeled demo data '
            '(ephemeral account, auto-expires).',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _demo,
            child: const Text('Try the demo'),
          ),
          const SizedBox(height: 24),
          SelectableText(_log.join('\n')),
        ],
      ),
    );
  }
}
