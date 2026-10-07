import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:job_tracker_core/job_tracker_core.dart';

import 'api_client.dart';

/// BYOK provider presets (v1). Keys stay on-device; Anthropic's native API
/// differs in headers + tool format and is stretch (PLAN decision 6).
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.defaultModel,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String defaultModel;
}

const providerPresets = [
  ProviderPreset(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
  ),
  ProviderPreset(
    id: 'groq',
    label: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'llama-3.3-70b-versatile',
  ),
  ProviderPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'meta-llama/llama-3.3-70b-instruct:free',
  ),
  ProviderPreset(
    id: 'ollama',
    label: 'Ollama (local)',
    baseUrl: 'http://localhost:11434/v1',
    defaultModel: 'llama3.1',
  ),
  ProviderPreset(
    id: 'gemini',
    label: 'Gemini (compat endpoint)',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    defaultModel: 'gemini-2.0-flash',
  ),
];

/// Resolved LLM call config (preset + stored key + model override).
class LlmConfig {
  LlmConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
}

enum TrailKind { user, text, toolCall, toolResult, confirm, error }

/// One rendered trail event.
class TrailEvent {
  TrailEvent({
    required this.kind,
    required this.text,
    this.toolName,
    this.toolArgs,
    this.toolCallId,
  });

  final TrailKind kind;
  final String text;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final String? toolCallId;
}

/// Streaming LLM events.
abstract class LlmEvent {
  const LlmEvent();
}

class LlmText extends LlmEvent {
  const LlmText(this.delta);
  final String delta;
}

class LlmToolCall extends LlmEvent {
  const LlmToolCall({required this.id, required this.name, required this.argsJson});
  final String id;
  final String name;
  final String argsJson;
}

class LlmDone extends LlmEvent {
  const LlmDone();
}

/// Minimal OpenAI-protocol streaming client (BYOK key, never forwarded).
class OpenAiCompatLlm {
  OpenAiCompatLlm(this._http);
  final http.Client _http;

  Stream<LlmEvent> chat({
    required LlmConfig config,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async* {
    final req = http.Request(
      'POST',
      Uri.parse('${config.baseUrl}/chat/completions'),
    )
      ..headers['content-type'] = 'application/json'
      ..headers['authorization'] = 'Bearer ${config.apiKey}'
      ..body = jsonEncode({
        'model': config.model,
        'messages': messages,
        'tools': tools,
        'stream': true,
      });
    final res = await _http.send(req);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = await res.stream.bytesToString();
      throw ApiException(res.statusCode, _providerError(body));
    }
    final calls = <String, Map<String, dynamic>>{};
    final order = <String>[];
    await for (final line in res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final t = line.trim();
      if (!t.startsWith('data:')) continue;
      final data = t.substring(5).trim();
      if (data == '[DONE]') break;
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final delta =
          (choices.first as Map)['delta'] as Map<String, dynamic>?;
      if (delta == null) continue;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        yield LlmText(content);
      }
      final toolCalls = delta['tool_calls'] as List?;
      for (final c in toolCalls ?? []) {
        final m = c as Map<String, dynamic>;
        final index = '${m['index'] ?? order.length}';
        final entry = calls.putIfAbsent(index, () {
          order.add(index);
          return {'id': '', 'name': '', 'args': ''};
        });
        entry['id'] = '${entry['id']}${m['id'] ?? ''}';
        final fn = m['function'] as Map<String, dynamic>?;
        if (fn != null) {
          entry['name'] = '${entry['name']}${fn['name'] ?? ''}';
          entry['args'] = '${entry['args']}${fn['arguments'] ?? ''}';
        }
      }
    }
    for (final index in order) {
      final e = calls[index]!;
      yield LlmToolCall(
        id: (e['id'] as String).isEmpty ? 'call_$index' : e['id'] as String,
        name: e['name'] as String,
        argsJson: e['args'] as String,
      );
    }
    yield const LlmDone();
  }

  String _providerError(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final err = j['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
    } catch (_) {}
    return body.length > 300 ? '${body.substring(0, 300)}…' : body;
  }
}

/// Executes agent tool calls against the server REST API (same semantics as
/// the MCP tools; confirm-gating happens in the controller, before this).
class ToolExecutor {
  ToolExecutor(this._api);
  final ApiClient _api;

  Future<String> run(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'list_applications':
        return jsonEncode([
          for (final a in await _api.listApplications(
            stage: _s(args, 'stage'),
            archived: args['archived'] == true,
            limit: _i(args, 'limit', 50),
          ))
            a.toJson(),
        ]);
      case 'get_application':
        return jsonEncode(
          (await _api.getApplication(_req(args, 'id'))).toJson(),
        );
      case 'pipeline_summary':
      case 'stats':
        return jsonEncode(await _api.stats());
      case 'stale_followups':
        return jsonEncode(
          await _api.staleFollowups(limit: _i(args, 'limit', 50)),
        );
      case 'list_contacts':
        return jsonEncode([
          for (final c in await _api.listContacts(
            applicationId: _s(args, 'application_id'),
          ))
            c.toJson(),
        ]);
      case 'get_interactions':
        return jsonEncode([
          for (final i in await _api.getInteractions(
            _req(args, 'application_id'),
          ))
            i.toJson(),
        ]);
      case 'add_application':
        return jsonEncode(
          (await _api.createApplication(
            company: _req(args, 'company'),
            role: _req(args, 'role'),
            source: _s(args, 'source'),
            stage: _s(args, 'stage') ?? 'saved',
            link: _s(args, 'link'),
            notes: _s(args, 'notes'),
          )).toJson(),
        );
      case 'update_stage':
        return jsonEncode(
          (await _api.updateStage(_req(args, 'id'), _req(args, 'stage')))
              .toJson(),
        );
      case 'log_interaction':
        return jsonEncode(
          (await _api.logInteraction(
            applicationId: _req(args, 'application_id'),
            type: _req(args, 'type'),
            summary: _s(args, 'summary'),
          )).toJson(),
        );
      case 'add_contact':
        return jsonEncode(
          (await _api.createContact(
            name: _req(args, 'name'),
            applicationId: _s(args, 'application_id'),
            role: _s(args, 'role'),
            company: _s(args, 'company'),
          )).toJson(),
        );
      case 'schedule_followup':
        final fu = _s(args, 'follow_up_at');
        if (fu == null) throw ApiException(400, 'follow_up_at is required');
        return jsonEncode(
          (await _api.setFollowUp(
            _req(args, 'interaction_id'),
            DateTime.parse(fu),
          )).toJson(),
        );
      case 'archive_application':
        return jsonEncode(
          (await _api.archive(_req(args, 'id'))).toJson(),
        );
      case 'draft_followup':
        final app = await _api.getApplication(_req(args, 'application_id'));
        final recent = await _api.getInteractions(app.id);
        return buildDraft(
          app: app,
          recent: recent.take(3).toList(),
          tone: _s(args, 'tone'),
        );
      default:
        throw ApiException(400, 'Unknown tool: $name');
    }
  }
}

String _req(Map<String, dynamic> args, String key) {
  final v = args[key];
  if (v is! String || v.isEmpty) throw ApiException(400, '$key is required');
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

/// Client-side agent loop (PLAN decision 7): streams text, executes tools
/// against the server API, pauses writes on UI confirm sheets.
class AgentController extends Notifier<List<TrailEvent>> {
  OpenAiCompatLlm? llm;
  ToolExecutor? executor;

  /// Resolves a confirm sheet: true = user approved with exact args shown.
  Future<bool> Function(String tool, Map<String, dynamic> args)? onConfirm;

  @override
  List<TrailEvent> build() => [];

  static const _system = 'You operate the user\'s job-application pipeline. '
      'Reads are free; every write tool needs user confirmation and will be '
      'shown to the user before it runs. Answer concisely. '
      'Today is 2026-10-07. Never invent metrics — call stats tools.';

  static List<Map<String, dynamic>> openAiTools() => [
    for (final def in toolDefs)
      {
        'type': 'function',
        'function': {
          'name': def.name,
          'description': def.description,
          'parameters': def.inputSchema,
        },
      },
  ];

  Future<void> run(String prompt, LlmConfig config) async {
    final activeLlm = llm, activeExec = executor;
    if (activeLlm == null || activeExec == null) {
      _add(TrailKind.error, 'Agent not configured (missing provider key?).');
      return;
    }
    _add(TrailKind.user, prompt);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _system},
      ..._historyMessages(),
      {'role': 'user', 'content': prompt},
    ];
    for (var round = 0; round < 5; round++) {
      final textBuf = StringBuffer();
      TrailEvent? textEvent;
      final calls = <LlmToolCall>[];
      try {
        await for (final e in activeLlm.chat(
          config: config,
          messages: messages,
          tools: openAiTools(),
        )) {
          if (e is LlmText) {
            textBuf.write(e.delta);
            textEvent ??= _add(TrailKind.text, '');
            textEvent = _replaceLast(textEvent, textBuf.toString());
          } else if (e is LlmToolCall) {
            calls.add(e);
          }
        }
      } catch (e) {
        _add(TrailKind.error, '$e');
        return;
      }
      if (calls.isEmpty) return;
      messages.add({
        'role': 'assistant',
        'content': textBuf.toString(),
        'tool_calls': [
          for (final c in calls)
            {
              'id': c.id,
              'type': 'function',
              'function': {'name': c.name, 'arguments': c.argsJson},
            },
        ],
      });
      for (final call in calls) {
        Map<String, dynamic> args;
        try {
          args = Map<String, dynamic>.from(
            jsonDecode(call.argsJson.isEmpty ? '{}' : call.argsJson) as Map,
          );
        } catch (_) {
          args = {};
        }
        final def = findTool(call.name);
        if (def == null) {
          _add(
            TrailKind.toolResult,
            'Unknown tool: ${call.name}',
            toolName: call.name,
            toolCallId: call.id,
          );
          messages.add(_toolMessage(call.id, 'Unknown tool: ${call.name}'));
          continue;
        }
        _add(
          TrailKind.toolCall,
          '${call.name} ${jsonEncode(args)}',
          toolName: call.name,
          toolArgs: args,
          toolCallId: call.id,
        );
        if (def.requiresConfirmation) {
          final approved = await _confirm(call.name, args);
          if (!approved) {
            _add(
              TrailKind.toolResult,
              'Declined by user — not executed.',
              toolName: call.name,
              toolCallId: call.id,
            );
            messages.add(
              _toolMessage(call.id, 'Declined by user — not executed.'),
            );
            continue;
          }
        }
        try {
          final result = await activeExec.run(call.name, args);
          _add(
            TrailKind.toolResult,
            result.length > 500 ? '${result.substring(0, 500)}…' : result,
            toolName: call.name,
            toolCallId: call.id,
          );
          messages.add(_toolMessage(call.id, result));
        } catch (e) {
          _add(
            TrailKind.toolResult,
            'Error: $e',
            toolName: call.name,
            toolCallId: call.id,
          );
          messages.add(_toolMessage(call.id, 'Error: $e'));
        }
      }
    }
    _add(TrailKind.error, 'Stopped after 5 tool rounds.');
  }

  Future<bool> _confirm(String tool, Map<String, dynamic> args) async {
    final event = _add(
      TrailKind.confirm,
      'Approve $tool with ${jsonEncode(args)}?',
      toolName: tool,
      toolArgs: args,
    );
    final fn = onConfirm;
    if (fn == null) return false;
    final approved = await fn(tool, args);
    _replaceLast(event, approved ? 'Approved by user.' : 'Declined by user.');
    return approved;
  }

  List<Map<String, dynamic>> _historyMessages() {
    final out = <Map<String, dynamic>>[];
    for (final e in state.take(20)) {
      switch (e.kind) {
        case TrailKind.user:
          out.add({'role': 'user', 'content': e.text});
        case TrailKind.text:
          if (e.text.isNotEmpty) {
            out.add({'role': 'assistant', 'content': e.text});
          }
        case TrailKind.toolResult:
          if (e.toolCallId != null) {
            out.add(_toolMessage(e.toolCallId!, e.text));
          }
        case TrailKind.toolCall:
        case TrailKind.confirm:
        case TrailKind.error:
          break;
      }
    }
    return out;
  }

  Map<String, dynamic> _toolMessage(String id, String content) => {
    'role': 'tool',
    'tool_call_id': id,
    'content': content,
  };

  TrailEvent _add(
    TrailKind kind,
    String text, {
    String? toolName,
    Map<String, dynamic>? toolArgs,
    String? toolCallId,
  }) {
    final e = TrailEvent(
      kind: kind,
      text: text,
      toolName: toolName,
      toolArgs: toolArgs,
      toolCallId: toolCallId,
    );
    state = [...state, e];
    return e;
  }

  TrailEvent _replaceLast(TrailEvent old, String text) {
    final updated = TrailEvent(
      kind: old.kind,
      text: text,
      toolName: old.toolName,
      toolArgs: old.toolArgs,
      toolCallId: old.toolCallId,
    );
    state = [...state.sublist(0, state.length - 1), updated];
    return updated;
  }
}

final agentProvider =
    NotifierProvider<AgentController, List<TrailEvent>>(AgentController.new);
