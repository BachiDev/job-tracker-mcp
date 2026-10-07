import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/agent.dart';
import '../../core/api_client.dart';
import '../../core/llm_keys.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Settings: BYOK provider presets + keys, demo info, privacy, danger zone.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _preset = 'openai';
  final _key = TextEditingController();
  final _model = TextEditingController();
  bool _hasKey = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preset = await selectedPreset();
    final config = await loadLlmConfig(preset);
    if (!mounted) return;
    setState(() {
      _preset = preset;
      _hasKey = config != null;
      _model.text = config?.model ?? _defModel(preset);
      _key.clear();
    });
  }

  String _defModel(String id) => providerPresets
      .firstWhere((p) => p.id == id, orElse: () => providerPresets.first)
      .defaultModel;

  Future<void> _saveKey() async {
    final key = _key.text.trim();
    if (key.isEmpty) return;
    await saveKey(_preset, key);
    _key.clear();
    await _load();
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Kicker(text: 'ai provider (byok)'),
          DropdownButton<String>(
            value: _preset,
            items: [
              for (final p in providerPresets)
                DropdownMenuItem(value: p.id, child: Text(p.label)),
            ],
            onChanged: (v) async {
              if (v == null) return;
              await savePreset(v);
              await _load();
            },
          ),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _hasKey ? 'Key stored — paste to replace' : 'API key',
            ),
          ),
          TextField(
            controller: _model,
            decoration: const InputDecoration(labelText: 'Model override'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: _saveKey,
                child: const Text('Save key'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final model = _model.text.trim();
                  if (model.isNotEmpty) await saveModel(_preset, model);
                  await _load();
                },
                child: const Text('Save model'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await clearKey(_preset);
                  await clearModel(_preset);
                  await _load();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Keys stay on this device (secure storage / browser storage) and go only to the selected provider endpoint. The app server never sees them.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Kicker(text: 'account'),
          if (session?.isDemo == true)
            const Text('Demo account — data is fake and auto-expires.'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) context.go('/signin');
            },
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 24),
          const Kicker(text: 'privacy'),
          const Text(
            'No tracking or analytics anywhere. Your pipeline lives in your '
            'own database rows; provider keys stay on-device. Delete everything '
            'below — rows are removed transactionally; remove the auth user in '
            'Neon console → Auth → Users.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: _busy ? null : () => _deleteAccount(context),
            child: const Text('Delete my data'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all my data?'),
        content: const Text(
          'Every application, contact and interaction is removed. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).deleteAccount();
      await ref.read(sessionProvider.notifier).signOut();
      if (context.mounted) context.go('/signin');
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
