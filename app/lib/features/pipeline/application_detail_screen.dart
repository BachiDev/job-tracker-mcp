import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:job_tracker_core/job_tracker_core.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

final _appProvider = FutureProvider.family<Application, String>((ref, id) {
  return ref.watch(apiClientProvider).getApplication(id);
});

final _timelineProvider =
    FutureProvider.family<List<Interaction>, String>((ref, id) {
      return ref.watch(apiClientProvider).getInteractions(id);
    });

void refreshDetail(WidgetRef ref, String id) {
  ref.invalidate(_appProvider(id));
  ref.invalidate(_timelineProvider(id));
}

/// Application detail: stage control, archive, timeline, log interaction.
class ApplicationDetailScreen extends ConsumerWidget {
  const ApplicationDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(_appProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Application')),
      body: app.when(
        data: (a) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${a.company} — ${a.role}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                StagePill(stage: a.stage.name),
              ],
            ),
            if (a.source != null) Text('via ${a.source}'),
            if (a.notes != null) ...[
              const SizedBox(height: 8),
              Text(a.notes!),
            ],
            const SizedBox(height: 16),
            const Kicker(text: 'stage'),
            DropdownButton<AppStage>(
              value: a.stage,
              items: [
                for (final s in AppStage.values)
                  DropdownMenuItem(value: s, child: Text(s.name)),
              ],
              onChanged: (s) async {
                if (s == null) return;
                try {
                  await ref
                      .read(apiClientProvider)
                      .updateStage(id, s.name);
                  refreshDetail(ref, id);
                } on ApiException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            if (a.archivedAt == null)
              OutlinedButton(
                onPressed: () => _confirmArchive(context, ref),
                child: const Text('Archive application'),
              )
            else
              const Text(
                'Archived — reversible in a future release path.',
                style: TextStyle(color: AppTheme.muted),
              ),
            const SizedBox(height: 16),
            const Kicker(text: 'timeline'),
            _Timeline(id: id),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _logSheet(context, ref),
              child: const Text('Log interaction'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => refreshDetail(ref, id),
        ),
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive application?'),
        content: const Text(
          'It hides from the pipeline. There is no delete in v1.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(apiClientProvider).archive(id);
        refreshDetail(ref, id);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  Future<void> _logSheet(BuildContext context, WidgetRef ref) async {
    var type = 'note';
    final summary = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
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
            DropdownButton<String>(
              value: type,
              items: [
                for (final t in interactionTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) {
                if (v != null) type = v;
              },
            ),
            TextField(
              controller: summary,
              decoration: const InputDecoration(labelText: 'Summary'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await ref
            .read(apiClientProvider)
            .logInteraction(
              applicationId: id,
              type: type,
              summary: summary.text.trim().isEmpty
                  ? null
                  : summary.text.trim(),
            );
        refreshDetail(ref, id);
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

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(_timelineProvider(id));
    return timeline.when(
      data: (items) {
        if (items.isEmpty) {
          return const Text(
            'No interactions logged yet.',
            style: TextStyle(color: AppTheme.muted),
          );
        }
        return Column(
          children: [
            for (final i in items)
              Card(
                child: ListTile(
                  title: Text('${i.type} — ${_date(i.happenedAt)}'),
                  subtitle: i.summary != null ? Text(i.summary!) : null,
                  trailing: i.followUpAt != null
                      ? const Icon(Icons.alarm_outlined, size: 20)
                      : null,
                ),
              ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => refreshDetail(ref, id),
      ),
    );
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
