import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:job_tracker_core/job_tracker_core.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';

final _contactsProvider = FutureProvider<List<Contact>>((ref) {
  return ref.watch(apiClientProvider).listContacts();
});

/// Contact list + add sheet.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(_contactsProvider);
    return AppShell(
      tab: AppTab.contacts,
      title: 'Contacts',
      fab: FloatingActionButton(
        onPressed: () => _addSheet(context, ref),
        tooltip: 'Add contact',
        child: const Icon(Icons.add),
      ),
      body: contacts.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              title: 'No contacts yet',
              hint: 'People you meet during applications live here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final c in items)
                Card(
                  child: ListTile(
                    title: Text(c.name),
                    subtitle: Text(
                      [
                        if (c.role != null) c.role!,
                        if (c.company != null) c.company!,
                      ].join(' · '),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(_contactsProvider),
        ),
      ),
    );
  }

  Future<void> _addSheet(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final email = TextEditingController();
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
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add contact'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      try {
        final mail = email.text.trim();
        await ref
            .read(apiClientProvider)
            .createContact(
              name: name.text.trim(),
              channels: mail.isEmpty ? {} : {'email': mail},
            );
        ref.invalidate(_contactsProvider);
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
