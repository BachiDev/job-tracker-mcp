import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/agent.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Agent chat: streaming text, tool-call trail, confirm sheets for writes.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  bool _busy = false;
  String? _presetNote;

  @override
  void initState() {
    super.initState();
    final ctl = ref.read(agentProvider.notifier);
    ctl.llm = ref.read(llmClientProvider);
    ctl.executor = ref.read(toolExecutorProvider);
    ctl.onConfirm = _ask;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<bool> _ask(String tool, Map<String, dynamic> args) async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Kicker(text: 'confirm write'),
            Text(
              tool,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Exact arguments — nothing runs until you approve.',
            ),
            const SizedBox(height: 8),
            Mono(text: const JsonEncoder.withIndent('  ').convert(args)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
            // Bottom padding so the actions stay reachable on small screens.
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
    return approved == true;
  }

  Future<void> _send() async {
    final prompt = _input.text.trim();
    if (prompt.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _busy = true;
      _presetNote = null;
    });
    try {
      final config = await ref.read(llmConfigProvider.future);
      if (config == null) {
        setState(() {
          _presetNote =
              'No API key stored. Add one in Settings — keys stay on this device.';
        });
        return;
      }
      await ref.read(agentProvider.notifier).run(prompt, config);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trail = ref.watch(agentProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Provider & key',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_presetNote != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppTheme.error.withValues(alpha: 0.12),
              child: Text(_presetNote!),
            ),
          Expanded(
            child: trail.isEmpty
                ? const EmptyState(
                    title: 'Ask about your pipeline',
                    hint:
                        'Try "what needs my attention?" — reads are free, writes pause for approval.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [for (final e in trail) _event(e)],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      labelText: 'Message the agent',
                    ),
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _event(TrailEvent e) {
    switch (e.kind) {
      case TrailKind.user:
        return Align(
          alignment: Alignment.centerRight,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(e.text),
            ),
          ),
        );
      case TrailKind.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(e.text),
        );
      case TrailKind.toolCall:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker(text: 'tool call'),
                Mono(text: '${e.toolName}'),
                if (e.toolArgs != null) Mono(text: jsonEncode(e.toolArgs), size: 11),
              ],
            ),
          ),
        );
      case TrailKind.toolResult:
        return Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Text(
            e.text,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        );
      case TrailKind.confirm:
        return Card(
          color: AppTheme.raised,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(e.text),
          ),
        );
      case TrailKind.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(e.text, style: const TextStyle(color: AppTheme.error)),
        );
    }
  }
}
