import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Public landing page (web, logged out): a real website, not an app screen.
/// Voice: direct, senior, honest — same as bachi.dev. No invented metrics.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const _maxWidth = 1080.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            children: [
              _Nav(onSignIn: () => context.go('/signin')),
              const SizedBox(height: 72),
              const Kicker(text: 'job application tracker'),
              const SizedBox(height: 12),
              Text(
                'One pipeline for every application.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Track applications, contacts, and follow-ups in one place — '
                'then let an agent operate on your pipeline while you approve '
                'every write. Your keys, your data, no tracking.',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.body),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/?demo=1'),
                    child: const Text('Try the live demo'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/signin'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Mono(
                text: 'free · byok · no tracking · open pipeline',
                size: 12,
              ),
              const SizedBox(height: 72),
              const Kicker(text: 'stack'),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Flutter')),
                  Chip(label: Text('Dart')),
                  Chip(label: Text('MCP')),
                  Chip(label: Text('Neon Postgres')),
                  Chip(label: Text('Better Auth')),
                ],
              ),
              const SizedBox(height: 72),
              const Kicker(text: 'what it does'),
              const SizedBox(height: 12),
              const _FeatureGrid(),
              const SizedBox(height: 72),
              const Kicker(text: 'how it works'),
              const SizedBox(height: 12),
              const _Steps(),
              const SizedBox(height: 72),
              const Kicker(text: 'agent safety'),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Reads are free. Every write pauses on a confirm sheet '
                    'showing the exact arguments — nothing mutates without '
                    'your approval. Follow-ups are drafts labeled as such; '
                    'there is no send tool, so the agent cannot act '
                    'externally. There is no delete tool either — archiving '
                    'is reversible.',
                  ),
                ),
              ),
              const SizedBox(height: 72),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 16),
              const Text(
                'Built by Fabian Bachmayer — bachi.dev. No tracking, no '
                'analytics. Provider keys stay on your device; the server '
                'never sees them.',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Mono(text: 'job-tracker', size: 14),
        const Spacer(),
        TextButton(onPressed: onSignIn, child: const Text('Sign in')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => context.go('/?demo=1'),
          child: const Text('Try demo'),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const features = [
      ('Pipeline board', 'Every application in a stage. Stale ones surface on their own.'),
      ('Agent chat', 'Ask "what needs my attention?" — the agent reads freely, writes only with approval.'),
      ('Follow-up drafts', 'Grounded in your real history. Labeled draft — you send.'),
      ('MCP server', 'The same tools your chat uses, exposed over MCP stdio + HTTP for Claude Desktop and OpenCode.'),
      ('BYOK inference', 'OpenAI, Groq, OpenRouter, Ollama, Gemini. Keys never leave your device.'),
      ('Privacy by construction', 'User-scoped rows, no tracking, one-tap data deletion.'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (title, body) in features)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? 320 : double.infinity,
                  minWidth: wide ? 280 : 0,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('1', 'Sign in with a magic link — or open the demo.'),
      ('2', 'Add applications yourself, or let the agent do it.'),
      ('3', 'Chat operates the pipeline. You approve every write.'),
    ];
    return Column(
      children: [
        for (final (n, body) in steps)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Mono(text: n, size: 16),
            title: Text(body),
          ),
      ],
    );
  }
}
