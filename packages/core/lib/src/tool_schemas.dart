/// MCP tool surface (PLAN §3): schemas + confirm-gating, shared by REST docs,
/// MCP stdio/HTTP wiring, and scripted evals. Pure data, no transport deps.
library;

import 'models.dart';

/// One tool in the MCP surface.
class McpToolDef {
  const McpToolDef({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.requiresConfirmation = false,
  });

  final String name;
  final String description;

  /// JSON Schema (draft 2020-12 subset) for the tool input.
  final Map<String, dynamic> inputSchema;

  /// Writes are confirm-gated: chat shows exact args on a confirm sheet, and
  /// over MCP the call must carry `confirmed: true`.
  final bool requiresConfirmation;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
    'requiresConfirmation': requiresConfirmation,
  };
}

Map<String, dynamic> _obj(
  Map<String, Map<String, dynamic>> props, {
  List<String> required = const [],
}) => {
  'type': 'object',
  'properties': props,
  if (required.isNotEmpty) 'required': required,
  'additionalProperties': false,
};

Map<String, dynamic> _typed(String type, [String? desc]) {
  final m = <String, dynamic>{'type': type};
  if (desc != null) m['description'] = desc;
  return m;
}

Map<String, dynamic> _str([String? desc]) => _typed('string', desc);

Map<String, dynamic> _int([String? desc]) => _typed('integer', desc);

Map<String, dynamic> _bool([String? desc]) => _typed('boolean', desc);

const _stageEnum = 'saved|applied|screening|interview|offer|accepted|rejected|withdrawn';

/// Full v1 tool surface: 7 reads, 6 confirm-gated writes, 1 text-only draft.
List<McpToolDef> get toolDefs => [
  McpToolDef(
    name: 'list_applications',
    description: 'List my applications with optional stage/archived filters.',
    inputSchema: _obj({
      'stage': {
        'type': 'string',
        'description': 'Filter by stage ($_stageEnum).',
      },
      'archived': _bool('Include archived only (default false).'),
      'limit': _int('Max rows (1..100, default 50).'),
    }),
  ),
  McpToolDef(
    name: 'get_application',
    description: 'Fetch one application by id (must be mine).',
    inputSchema: _obj({
      'id': _str('Application id.'),
    }, required: ['id']),
  ),
  McpToolDef(
    name: 'pipeline_summary',
    description: 'Count of my non-archived applications per stage.',
    inputSchema: _obj({}),
  ),
  McpToolDef(
    name: 'stale_followups',
    description:
        'Applications needing attention: past their stage stale threshold '
        '(applied 7d, screening 5d, interview 3d, offer 7d).',
    inputSchema: _obj({
      'limit': _int('Max rows (1..100, default 50).'),
    }),
  ),
  McpToolDef(
    name: 'list_contacts',
    description: 'List my contacts, optionally for one application.',
    inputSchema: _obj({
      'application_id': _str('Only contacts linked to this application.'),
      'limit': _int('Max rows (1..100, default 50).'),
    }),
  ),
  McpToolDef(
    name: 'get_interactions',
    description: 'List interactions for one of my applications, newest first.',
    inputSchema: _obj({
      'application_id': _str('Application id.'),
      'limit': _int('Max rows (1..100, default 50).'),
    }, required: ['application_id']),
  ),
  McpToolDef(
    name: 'stats',
    description:
        'Computed pipeline stats: totals, per-stage counts, stale count. '
        'Every metric is computed, never invented.',
    inputSchema: _obj({}),
  ),
  McpToolDef(
    name: 'add_application',
    description: 'Add an application to my pipeline.',
    requiresConfirmation: true,
    inputSchema: _obj({
      'company': _str('Company (1..200 chars).'),
      'role': _str('Role (1..200 chars).'),
      'source': _str('Where I found it (max 100).'),
      'stage': {
        'type': 'string',
        'description': 'Initial stage (default saved).',
      },
      'applied_at': _str('ISO date (default today).'),
      'salary_min': _int('Annual minimum.'),
      'salary_max': _int('Annual maximum.'),
      'link': _str('Absolute http(s) job posting URL.'),
      'notes': _str('Free text (max 10000).'),
      'confirmed': _bool('Must be true (confirm-gated write).'),
    }, required: ['company', 'role', 'confirmed']),
  ),
  McpToolDef(
    name: 'update_stage',
    description: 'Move one of my applications to a new stage.',
    requiresConfirmation: true,
    inputSchema: _obj({
      'id': _str('Application id.'),
      'stage': {
        'type': 'string',
        'description': 'New stage ($_stageEnum).',
      },
      'confirmed': _bool('Must be true (confirm-gated write).'),
    }, required: ['id', 'stage', 'confirmed']),
  ),
  McpToolDef(
    name: 'log_interaction',
    description: 'Log a call, email, meeting, … on my application.',
    requiresConfirmation: true,
    inputSchema: _obj({
      'application_id': _str('Application id.'),
      'type': {
        'type': 'string',
        'description': 'One of ${interactionTypes.join('|')}.',
      },
      'happened_at': _str('ISO datetime (default now).'),
      'summary': _str('What happened (max 5000).'),
      'follow_up_at': _str('ISO datetime for the next nudge.'),
      'confirmed': _bool('Must be true (confirm-gated write).'),
    }, required: ['application_id', 'type', 'confirmed']),
  ),
  McpToolDef(
    name: 'add_contact',
    description: 'Add a contact, optionally linked to my application.',
    requiresConfirmation: true,
    inputSchema: _obj({
      'name': _str('Contact name (1..200 chars).'),
      'application_id': _str('Link to this application.'),
      'role': _str('Their role.'),
      'company': _str('Their company.'),
      'channels': {
        'type': 'object',
        'description': 'e.g. {"email":"a@b.c"} (max 20 entries).',
      },
      'confirmed': _bool('Must be true (confirm-gated write).'),
    }, required: ['name', 'confirmed']),
  ),
  McpToolDef(
    name: 'schedule_followup',
    description: 'Set/refresh the follow-up nudge on an interaction.',
    requiresConfirmation: true,
    inputSchema: _obj({
      'interaction_id': _str('Interaction id.'),
      'follow_up_at': _str('ISO datetime, must be in the future.'),
      'confirmed': _bool('Must be true (confirm-gated write).'),
    }, required: ['interaction_id', 'follow_up_at', 'confirmed']),
  ),
  McpToolDef(
    name: 'archive_application',
    description:
        'Archive (soft-hide) one of my applications. Reversible semantics; '
        'there is no delete tool in v1.',
    requiresConfirmation: true,
    inputSchema: _obj({
      'id': _str('Application id.'),
      'confirmed': _bool('Must be true (confirm-gated write).'),
    }, required: ['id', 'confirmed']),
  ),
  McpToolDef(
    name: 'draft_followup',
    description:
        'Draft follow-up text only. Nothing is sent — there is no send tool '
        'in v1; the human sends.',
    inputSchema: _obj({
      'application_id': _str('Application id for context.'),
      'tone': _str('e.g. short/formal/friendly (free text).'),
    }, required: ['application_id']),
  ),
];

/// Lookup by name; null when unknown.
McpToolDef? findTool(String name) {
  for (final t in toolDefs) {
    if (t.name == name) return t;
  }
  return null;
}
