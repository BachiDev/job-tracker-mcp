import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'agent.dart';
import 'endpoints.dart';
import 'http_client.dart';
import 'llm_keys.dart';
import 'session.dart';

/// Shared raw HTTP client (web: credentialed for the auth host).
final httpClientProvider = Provider<http.Client>((ref) {
  final c = createAppClient();
  ref.onDispose(c.close);
  return c;
});
/// Typed API client bound to the current session token + cookies. Rebuilt on
/// sign-in/out so credentials always match the session.
final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionProvider).value;
  return ApiClient(
    baseUrl: Endpoints.apiBaseUrl,
    authBaseUrl: Endpoints.authBaseUrl,
    httpClient: ref.watch(httpClientProvider),
    token: session?.token,
    cookies: session?.cookies,
  );
});

/// Injectable LLM stack for the agent (overridden in widget tests).
final llmClientProvider = Provider<OpenAiCompatLlm>(
  (ref) => OpenAiCompatLlm(ref.watch(httpClientProvider)),
);

final toolExecutorProvider = Provider<ToolExecutor>(
  (ref) => ToolExecutor(ref.watch(apiClientProvider)),
);

/// Resolved BYOK config (null = no key stored → settings gate).
final llmConfigProvider = FutureProvider<LlmConfig?>((ref) async {
  final preset = await selectedPreset();
  return loadLlmConfig(preset);
});
