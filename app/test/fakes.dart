import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_tracker_core/job_tracker_core.dart';

import 'package:job_tracker/core/agent.dart';
import 'package:job_tracker/core/api_client.dart';
import 'package:job_tracker/core/session.dart';

/// Nullable session stub (pass null for signed-out).
class FakeSession extends SessionController {
  FakeSession(this._s);

  final Session? _s;

  @override
  Future<Session?> build() async => _s;
}

Session demoSession() => Session(token: 't', userId: 'u1', isDemo: true);

/// Canned API with write call recording.
class FakeApi extends ApiClient {
  FakeApi()
    : super(
        baseUrl: 'http://localhost:1',
        authBaseUrl: 'http://localhost:1',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

  int creates = 0;
  final apps = [
    Application(
      id: 'a1',
      userId: 'u1',
      company: 'Acme',
      role: 'Engineer',
      stage: AppStage.applied,
    ),
    Application(
      id: 'a2',
      userId: 'u1',
      company: 'Globex',
      role: 'Designer',
      stage: AppStage.interview,
    ),
  ];

  @override
  Future<List<Application>> listApplications({
    String? stage,
    bool archived = false,
    int limit = 50,
  }) async => apps;

  @override
  Future<Map<String, dynamic>> stats() async => {
    'total_active': 2,
    'by_stage': {'applied': 1, 'interview': 1},
    'stale_count': 1,
    'total_contacts': 0,
    'upcoming_followups_14d': 0,
  };

  @override
  Future<List<Map<String, dynamic>>> staleFollowups({int limit = 50}) async =>
      [];

  @override
  Future<Application> getApplication(String id) async =>
      apps.firstWhere((a) => a.id == id);

  @override
  Future<List<Interaction>> getInteractions(String applicationId) async => [];

  @override
  Future<Application> createApplication({
    required String company,
    required String role,
    String? source,
    String stage = 'saved',
    DateTime? appliedAt,
    int? salaryMin,
    int? salaryMax,
    String? link,
    String? notes,
  }) async {
    creates++;
    return Application(
      id: 'new',
      userId: 'u1',
      company: company,
      role: role,
      stage: parseStage(stage) ?? AppStage.saved,
    );
  }
}

/// Single-shot LLM: one gated tool call, then text so the loop terminates
/// (otherwise approve-path tests would wait on a second confirm forever).
class FakeLlm extends OpenAiCompatLlm {
  FakeLlm() : super(MockClient((_) async => http.Response('', 200)));

  bool spent = false;

  @override
  Stream<LlmEvent> chat({
    required LlmConfig config,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async* {
    if (!spent) {
      spent = true;
      yield const LlmToolCall(
        id: 'c1',
        name: 'add_application',
        argsJson: '{"company":"Acme","role":"Eng"}',
      );
    } else {
      yield const LlmText('done');
    }
    yield const LlmDone();
  }
}
