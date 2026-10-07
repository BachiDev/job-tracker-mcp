import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Stage pill: color-coded *with* a text label, never color-alone.
class StagePill extends StatelessWidget {
  const StagePill({super.key, required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: stageColor(stage).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stageColor(stage).withValues(alpha: 0.4)),
      ),
      child: Text(
        stage,
        semanticsLabel: 'Stage: $stage',
        style: TextStyle(
          color: stageColor(stage),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Mono kicker line (section eyebrow per bachi.dev language pattern).
class Kicker extends StatelessWidget {
  const Kicker({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: AppTheme.monoFont,
        color: AppTheme.violet,
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Mono text for stats, ids, tool trails.
class Mono extends StatelessWidget {
  const Mono({super.key, required this.text, this.size = 13});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: TextStyle(fontFamily: AppTheme.monoFont, fontSize: size),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.hint, this.action});

  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppTheme.muted),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
