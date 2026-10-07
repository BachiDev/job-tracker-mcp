import 'dart:convert';

import 'package:job_tracker_core/job_tracker_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

import 'store.dart';

/// Missing/false `confirmed` on a gated write. Pure — unit-tested.
String? missingConfirmation(Map<String, dynamic> args) =>
    args['confirmed'] == true
        ? null
        : 'Refused: this write needs confirmed:true (confirm-gated tool).';

CallToolResult _ok(Object value) => CallToolResult(
  content: [TextContent(text: value is String ? value : jsonEncode(value))],
);

CallToolResult _err(String message) => CallToolResult(
  isError: true,
  content: [TextContent(text: message)],
);

/// Registers the full v1 tool surface ([toolDefs]) on [server].
/// [userId] is the verified caller identity (JWT `sub` remotely, local user
/// over stdio) — tools never accept a caller-supplied user id.
void registerJobTrackerTools(
  McpServer server,
  Store store,
  String userId,
) {
  for (final def in toolDefs) {
    server.registerTool(
      def.name,
      description: def.description,
      inputSchema: JsonObject.fromJson(def.inputSchema),
      annotations: ToolAnnotations(readOnlyHint: !def.requiresConfirmation),
      callback: (args, _) => _dispatch(def, store, userId, args),
    );
  }
}

Future<CallToolResult> _dispatch(
  McpToolDef def,
  Store store,
  String userId,
  Map<String, dynamic> args,
) async {
  try {
    if (def.requiresConfirmation) {
      final missing = missingConfirmation(args);
      if (missing != null) return _err(missing);
    }
    switch (def.name) {
      case 'list_applications':
        return _ok([
          for (final a in await store.listApplications(
            userId,
            stage: _s(args, 'stage'),
            includeArchived: args['archived'] == true,
            limit: _i(args, 'limit', 50),
          ))
            a.toJson(),
        ]);
      case 'get_application':
        return _ok(
          (await store.getApplication(userId, _req(args, 'id'))).toJson(),
        );
      case 'pipeline_summary':
      case 'stats':
        return _ok(await store.stats(userId));
      case 'stale_followups':
        return _ok(
          await store.staleFollowups(userId, limit: _i(args, 'limit', 50)),
        );
      case 'list_contacts':
        return _ok([
          for (final c in await store.listContacts(
            userId,
            applicationId: _s(args, 'application_id'),
            limit: _i(args, 'limit', 50),
          ))
            c.toJson(),
        ]);
      case 'get_interactions':
        return _ok([
          for (final i in await store.getInteractions(
            userId,
            _req(args, 'application_id'),
            limit: _i(args, 'limit', 50),
          ))
            i.toJson(),
        ]);
      case 'add_application':
        return _ok(
          (await store.createApplication(
            userId,
            company: _req(args, 'company'),
            role: _req(args, 'role'),
            source: _s(args, 'source'),
            stage: _s(args, 'stage') ?? 'saved',
            appliedAt: _d(args, 'applied_at'),
            salaryMin: _n(args, 'salary_min'),
            salaryMax: _n(args, 'salary_max'),
            link: _s(args, 'link'),
            notes: _s(args, 'notes'),
          )).toJson(),
        );
      case 'update_stage':
        return _ok(
          (await store.updateStage(
            userId,
            _req(args, 'id'),
            _req(args, 'stage'),
          )).toJson(),
        );
      case 'log_interaction':
        return _ok(
          (await store.logInteraction(
            userId,
            applicationId: _req(args, 'application_id'),
            type: _req(args, 'type'),
            happenedAt: _d(args, 'happened_at'),
            summary: _s(args, 'summary'),
            followUpAt: _d(args, 'follow_up_at'),
          )).toJson(),
        );
      case 'add_contact':
        final channels = args['channels'];
        return _ok(
          (await store.createContact(
            userId,
            name: _req(args, 'name'),
            applicationId: _s(args, 'application_id'),
            role: _s(args, 'role'),
            company: _s(args, 'company'),
            channels: channels == null
                ? {}
                : Map<String, String>.from(
                    (channels as Map).map((k, v) => MapEntry('$k', '$v')),
                  ),
          )).toJson(),
        );
      case 'schedule_followup':
        final fu = _d(args, 'follow_up_at');
        if (fu == null) return _err('follow_up_at is required');
        return _ok(
          (await store.setFollowUp(
            userId,
            _req(args, 'interaction_id'),
            fu,
          )).toJson(),
        );
      case 'archive_application':
        return _ok(
          (await store.archiveApplication(
            userId,
            _req(args, 'id'),
          )).toJson(),
        );
      case 'draft_followup':
        return _ok(
          await _draft(store, userId, _req(args, 'application_id'), _s(args, 'tone')),
        );
      default:
        return _err('Unknown tool: ${def.name}');
    }
  } on InputError catch (e) {
    return _err(e.message);
  } on NotFound {
    return _err('not found');
  } on CrossUserAccess {
    return _err('not found');
  }
}

/// Text-only draft (no send tool exists in v1). Template grounded in the
/// application's real context; the human sends.
Future<String> _draft(
  Store store,
  String userId,
  String applicationId,
  String? tone,
) async {
  final app = await store.getApplication(userId, applicationId);
  final interactions = await store.getInteractions(userId, applicationId, limit: 3);
  return buildDraft(app: app, recent: interactions, tone: tone);
}

String _req(Map<String, dynamic> args, String key) {
  final v = args[key];
  if (v is! String || v.isEmpty) throw InputError('$key is required');
  return v;
}

String? _s(Map<String, dynamic> args, String key) {
  final v = args[key];
  return v is String && v.isNotEmpty ? v : null;
}

int _i(Map<String, dynamic> args, String key, int fallback) {
  final v = args[key];
  return v is int ? v : fallback;
}

int? _n(Map<String, dynamic> args, String key) {
  final v = args[key];
  return v is int ? v : null;
}

DateTime? _d(Map<String, dynamic> args, String key) {
  final v = _s(args, key);
  if (v == null) return null;
  try {
    return DateTime.parse(v);
  } catch (_) {
    throw InputError('$key must be ISO-8601');
  }
}
