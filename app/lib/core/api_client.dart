import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:job_tracker_core/job_tracker_core.dart';

import 'cookie_jar.dart';

/// Server error envelope.
class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  bool get unauthorized => status == 401;
  bool get offline =>
      status == -1 && message.contains('Failed host lookup');

  @override
  String toString() => 'ApiException($status): $message';
}

/// Ephemeral demo session from POST /api/demo/bootstrap.
class DemoBootstrap {
  DemoBootstrap({
    required this.userId,
    required this.token,
    required this.expiresAt,
  });

  final String userId;
  final String token;
  final DateTime expiresAt;

  factory DemoBootstrap.fromJson(Map<String, dynamic> json) => DemoBootstrap(
    userId: json['user_id'] as String,
    token: json['token'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

/// Typed REST client (Bearer JWT or demo bearer). Throws [ApiException].
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.authBaseUrl,
    required http.Client httpClient,
    this.token,
    Map<String, String>? cookies,
  }) : _http = httpClient,
       _jar = CookieJar(cookies);

  final String baseUrl;
  final String authBaseUrl;
  final http.Client _http;
  final CookieJar _jar;
  String? token;

  /// Captured session cookies (paste-link flow). Persist alongside the token.
  Map<String, String> get cookies => _jar.toMap();
  List<String> get cookieNames => _jar.names;

  Map<String, String> get _headers => {
    if (token != null && token!.isNotEmpty)
      'authorization': 'Bearer $token',
    if (!_jar.isEmpty) 'cookie': _jar.header,
    'content-type': 'application/json',
  };

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    late final http.Response res;
    try {
      res = await _http.get(uri, headers: _headers);
    } catch (e) {
      throw ApiException(-1, _friendly(e));
    }
    return _decode(res);
  }

  Future<dynamic> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    late final http.Response res;
    try {
      final payload = body == null ? null : jsonEncode(body);
      res = switch (method) {
        'POST' => await _http.post(uri, headers: _headers, body: payload),
        'PATCH' => await _http.patch(uri, headers: _headers, body: payload),
        'DELETE' => await _http.delete(uri, headers: _headers),
        _ => throw StateError('bad method'),
      };
    } catch (e) {
      throw ApiException(-1, _friendly(e));
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body is Map && body['error'] is String
        ? body['error'] as String
        : 'request failed (${res.statusCode})';
    throw ApiException(res.statusCode, msg);
  }

  String _friendly(Object e) {
    final s = '$e';
    if (s.contains('Failed host lookup') || s.contains('SocketException')) {
      return 'You appear to be offline — check your connection and retry.';
    }
    return s;
  }

  /// Drops null-valued entries (query params / JSON bodies built from
  /// nullable locals). Statement form — collection-`if` on nullables has no
  /// null-aware equivalent for non-null keys.
  Map<String, String> _qs(Map<String, String?> entries) {
    final out = <String, String>{};
    entries.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

  Map<String, dynamic> _jb(Map<String, dynamic> entries) {
    final out = <String, dynamic>{};
    entries.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

  Future<List<Application>> listApplications({
    String? stage,
    bool archived = false,
    int limit = 50,
  }) async {
    final data = await _get('/api/applications', _qs({
      'stage': stage,
      'archived': '$archived',
      'limit': '$limit',
    })) as List;
    return [
      for (final j in data)
        Application.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }

  Future<Application> getApplication(String id) async =>
      Application.fromJson(
        Map<String, dynamic>.from(await _get('/api/applications/$id') as Map),
      );

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
    return Application.fromJson(
      Map<String, dynamic>.from(
        await _send('POST', '/api/applications', _jb({
          'company': company,
          'role': role,
          'source': source,
          'stage': stage,
          'applied_at': appliedAt?.toIso8601String(),
          'salary_min': salaryMin,
          'salary_max': salaryMax,
          'link': link,
          'notes': notes,
        })) as Map,
      ),
    );
  }

  Future<Application> updateStage(String id, String stage) async =>
      Application.fromJson(
        Map<String, dynamic>.from(
          await _send('PATCH', '/api/applications/$id', {'stage': stage}, ) as Map,
        ),
      );

  Future<Application> archive(String id) async => Application.fromJson(
    Map<String, dynamic>.from(
      await _send('POST', '/api/applications/$id/archive', null) as Map,
    ),
  );

  Future<List<Contact>> listContacts({String? applicationId}) async {
    final data = await _get('/api/contacts', _qs({
      'application_id': applicationId,
    })) as List;
    return [
      for (final j in data)
        Contact.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }

  Future<Contact> createContact({
    required String name,
    String? applicationId,
    String? role,
    String? company,
    Map<String, String> channels = const {},
  }) async {
    return Contact.fromJson(
      Map<String, dynamic>.from(
        await _send('POST', '/api/contacts', _jb({
          'name': name,
          'application_id': applicationId,
          'role': role,
          'company': company,
          'channels': channels,
        })) as Map,
      ),
    );
  }

  Future<List<Interaction>> getInteractions(String applicationId) async {
    final data = await _get('/api/interactions', {
      'application_id': applicationId,
    }) as List;
    return [
      for (final j in data)
        Interaction.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }

  Future<Interaction> logInteraction({
    required String applicationId,
    required String type,
    DateTime? happenedAt,
    String? summary,
    DateTime? followUpAt,
  }) async {
    return Interaction.fromJson(
      Map<String, dynamic>.from(
        await _send('POST', '/api/interactions', _jb({
          'application_id': applicationId,
          'type': type,
          'happened_at': happenedAt?.toIso8601String(),
          'summary': summary,
          'follow_up_at': followUpAt?.toIso8601String(),
        })) as Map,
      ),
    );
  }

  Future<Interaction> setFollowUp(String id, DateTime followUpAt) async =>
      Interaction.fromJson(
        Map<String, dynamic>.from(
          await _send('PATCH', '/api/interactions/$id', {
                'follow_up_at': followUpAt.toIso8601String(),
              }) as Map,
        ),
      );

  Future<List<Map<String, dynamic>>> staleFollowups({int limit = 50}) async {
    final data = await _get('/api/stale_followups', {
      'limit': '$limit',
    }) as List;
    return [
      for (final j in data) Map<String, dynamic>.from(j as Map),
    ];
  }

  Future<Map<String, dynamic>> stats() async =>
      Map<String, dynamic>.from(await _get('/api/stats') as Map);

  Future<DemoBootstrap> bootstrapDemo() async => DemoBootstrap.fromJson(
    Map<String, dynamic>.from(
      await _send('POST', '/api/demo/bootstrap', null) as Map,
    ),
  );

  Future<Map<String, dynamic>> deleteAccount() async =>
      Map<String, dynamic>.from(await _send('DELETE', '/api/account', null) as Map);

  // -- auth helpers (Better Auth REST, no Dart SDK exists) ------------------

  /// Step 1: request a magic link email.
  Future<void> requestMagicLink(String email, String callbackUrl) async {
    late final http.Response res;
    try {
      res = await _http.post(
        Uri.parse('$authBaseUrl/sign-in/magic-link'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'email': email, 'callbackURL': callbackUrl}),
      );
    } catch (e) {
      throw ApiException(-1, _friendly(e));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _errorBody(res));
    }
  }

  /// Step 2: fetch the emailed verify link in-app (paste, don't open in a
  /// browser) so `Set-Cookie` lands in [cookies]. Follows redirects manually
  /// — the session cookie rides the 302, which auto-follow would swallow.
  Future<void> verifyLink(String url) async {
    var uri = Uri.parse(url);
    for (var i = 0; i < 5; i++) {
      final req = http.Request('GET', uri)..followRedirects = false;
      final res = await http.Response.fromStream(await _http.send(req));
      _jar.store(res.headers['set-cookie']);
      final loc = res.headers['location'];
      if (_redirect(res.statusCode) && loc != null) {
        uri = uri.resolve(loc);
        continue;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException(res.statusCode, _errorBody(res));
      }
      return;
    }
    throw ApiException(-1, 'Too many redirects verifying the link.');
  }

  /// Step 3: mint a JWT from the captured session cookies.
  Future<String> fetchJwt() async {
    late final http.Response res;
    try {
      res = await _http.get(
        Uri.parse('$authBaseUrl/token'),
        headers: {
          if (!_jar.isEmpty) 'cookie': _jar.header,
          'content-type': 'application/json',
        },
      );
    } catch (e) {
      throw ApiException(-1, _friendly(e));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _errorBody(res));
    }
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['token'] is String) {
        return body['token'] as String;
      }
      if (body is String && body.isNotEmpty) return body;
    } catch (_) {}
    throw ApiException(-1, 'Unexpected /token response shape.');
  }

  /// Who am I (session check; null body = signed out).
  Future<Map<String, dynamic>?> getSession() async {
    late final http.Response res;
    try {
      res = await _http.get(
        Uri.parse('$authBaseUrl/get-session'),
        headers: {
          if (!_jar.isEmpty) 'cookie': _jar.header,
          if (token != null && token!.isNotEmpty)
            'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
      );
    } catch (e) {
      throw ApiException(-1, _friendly(e));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _errorBody(res));
    }
    if (res.body.trim() == 'null') return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      return null;
    }
  }

  bool _redirect(int status) =>
      status == 301 ||
      status == 303 ||
      status == 302 ||
      status == 307 ||
      status == 308;

  String _errorBody(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) return body['error'];
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
    } catch (_) {}
    return 'request failed (${res.statusCode})';
  }
}
