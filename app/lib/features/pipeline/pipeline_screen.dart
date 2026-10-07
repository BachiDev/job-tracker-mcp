import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:job_tracker_core/job_tracker_core.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';

final _appsProvider = FutureProvider<List<Application>>((ref) {
  return ref.watch(apiClientProvider).listApplications();
});

final _statsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(apiClientProvider).stats();
});

final _staleProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).staleFollowups();
});

void _refresh(WidgetRef ref) {
  ref.invalidate(_appsProvider);
  ref.invalidate(_statsProvider);
  ref.invalidate(_staleProvider);
}

/// Pipeline: board on wide screens, list on narrow. Stats strip + stale
/// callouts on top.
class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    return AppShell(
      tab: AppTab.pipeline,
      title: session?.isDemo == true ? 'Pipeline (Demo data)' : 'Pipeline',
      fab: FloatingActionButton(
        onPressed: () => _addSheet(context, ref),
        tooltip: 'Add application',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Kicker(text: 'overview'),
            _StatsStrip(),
            SizedBox(height: 16),
            Kicker(text: 'needs attention'),
            _StaleSection(),
            SizedBox(height: 16),
            Kicker(text: 'pipeline'),
            _PipelineBody(),
          ],
        ),
      ),
    );
  }

  Future<void> _addSheet(BuildContext context, WidgetRef ref) async {
    final company = TextEditingController();
    final role = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: company,
              decoration: const InputDecoration(labelText: 'Company'),
            ),
            TextField(
              controller: role,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add application'),
            ),
          ],
        ),
      ),
    );
    if (created == true && context.mounted) {
      try {
        await ref
            .read(apiClientProvider)
            .createApplication(
              company: company.text.trim(),
              role: role.text.trim(),
            );
        _refresh(ref);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }
}

class _StatsStrip extends ConsumerWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_statsProvider);
    return stats.when(
      data: (s) {
        final byStage = Map<String, dynamic>.from(s['by_stage'] as Map);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(
              label: 'active',
              value: '${s['total_active']}',
            ),
            _StatChip(
              label: 'stale',
              value: '${s['stale_count']}',
              alert: (s['stale_count'] as int) > 0,
            ),
            _StatChip(
              label: 'contacts',
              value: '${s['total_contacts']}',
            ),
            for (final e in byStage.entries)
              _StatChip(label: e.key, value: '${e.value}'),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => _refresh(ref),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.alert = false,
  });

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mono(text: value),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      side: alert
          ? const BorderSide(color: AppTheme.error)
          : BorderSide(color: AppTheme.border),
    );
  }
}

class _StaleSection extends ConsumerWidget {
  const _StaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stale = ref.watch(_staleProvider);
    return stale.when(
      data: (items) {
        if (items.isEmpty) {
          return const Text(
            'Nothing stale. Nice.',
            style: TextStyle(color: AppTheme.muted),
          );
        }
        return Column(
          children: [
            for (final item in items)
              Builder(
                builder: (context) {
                  final app = Application.fromJson(
                    Map<String, dynamic>.from(
                      item['application'] as Map,
                    ),
                  );
                  return Card(
                    child: ListTile(
                      title: Text('${app.company} — ${app.role}'),
                      subtitle: Mono(
                        text: '${item['stale_reason']}',
                        size: 12,
                      ),
                      trailing: StagePill(stage: app.stage.name),
                      onTap: () => context.go('/app/${app.id}'),
                    ),
                  );
                },
              ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => _refresh(ref),
      ),
    );
  }
}

class _PipelineBody extends ConsumerWidget {
  const _PipelineBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(_appsProvider);
    return apps.when(
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            title: 'No applications yet',
            hint: 'Add your first one — or ask the chat to do it.',
            action: FilledButton(
              onPressed: () => context.go('/chat'),
              child: const Text('Open chat'),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 700) return _Board(items: items);
            return _AppList(items: items);
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => _refresh(ref),
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.items});

  final List<Application> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final app in items)
          Card(
            child: ListTile(
              title: Text('${app.company} — ${app.role}'),
              subtitle: app.archivedAt != null
                  ? const Text('archived')
                  : null,
              trailing: StagePill(stage: app.stage.name),
              onTap: () => context.go('/app/${app.id}'),
            ),
          ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.items});

  final List<Application> items;

  static const _columns = [
    'saved',
    'applied',
    'screening',
    'interview',
    'offer',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stage in _columns)
            Container(
              width: 260,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StagePill(stage: stage),
                  const SizedBox(height: 8),
                  for (final app in items.where((a) => a.stage.name == stage))
                    Card(
                      child: ListTile(
                        title: Text(app.company),
                        subtitle: Text(app.role),
                        onTap: () => context.go('/app/${app.id}'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
