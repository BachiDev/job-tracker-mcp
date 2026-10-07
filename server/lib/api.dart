import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:job_tracker_core/job_tracker_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth/jwt_verify.dart';
import 'store.dart';

/// Async JWT verification (live JWKS in prod, stub in tests).
typedef VerifyToken = Future<JwtClaims> Function(String token);

/// Demo bootstrap TTL, hours (matches `.env.example` DEMO_TTL_HOURS).
const demoTtlHours = 72;

/// Max demo bootstraps per IP per hour (abuse guard, in-memory).
const demoRateMax = 10;

/// Sliding-window check. Pure (clock injectable) — unit-tested.
bool demoAllowed(List<DateTime> hits, DateTime now) {
  final cutoff = now.subtract(const Duration(hours: 1));
  return hits.where((h) => h.isAfter(cutoff)).length < demoRateMax;
}

String _randomHex(int bytes) {
  final r = Random.secure();
  return [
    for (var i = 0; i < bytes; i++)
      r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

String _sha256hex(String s) => sha256.convert(utf8.encode(s)).toString();

/// Builds the full HTTP surface: public `/` + `/health` +
/// `POST /api/demo/bootstrap`, JWT-or-demo-bearer-gated `/api/*`.
Router buildRouter({required Store store, required VerifyToken verify}) {
  final demoHits = <String, List<DateTime>>{};
  final api = Router()
    ..post('/demo/bootstrap', (Request req) async {
      final ip =
          req.headers['x-forwarded-for']?.split(',').first.trim() ??
          'unknown';
      final now = DateTime.now().toUtc();
      final hits = demoHits[ip] ?? [];
      if (!demoAllowed(hits, now)) {
        return _json({'error': 'rate limited, try later'}, status: 429);
      }
      demoHits[ip] = [...hits, now];
      final userId = 'demo-${_randomHex(16)}';
      await store.seedDemo(userId);
      final token = _randomHex(32);
      final expiresAt = now.add(const Duration(hours: demoTtlHours));
      await store.createDemoSession(userId, _sha256hex(token), expiresAt);
      return _json({
        'user_id': userId,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
      }, status: 201);
    })
    ..get('/applications', (r) => _guard(r, verify, (sub, req) async {
      final q = req.url.queryParameters;
      final apps = await store.listApplications(
        sub,
        stage: q['stage'],
        includeArchived: q['archived'] == 'true',
        limit: _int(q['limit'], 50),
      );
      return _json([for (final a in apps) a.toJson()]);
    }))
    ..get('/applications/<id>', (r) => _guard(r, verify, (sub, req) async {
      final app = await store.getApplication(sub, r.params['id']!);
      return _json(app.toJson());
    }))
    ..post('/applications', (r) => _guard(r, verify, (sub, req) async {
      final b = await _body(req);
      final app = await store.createApplication(
        sub,
        company: _str(b, 'company'),
        role: _str(b, 'role'),
        source: _optStr(b, 'source'),
        stage: _optStr(b, 'stage') ?? 'saved',
        appliedAt: _optDt(b, 'applied_at'),
        salaryMin: _optInt(b, 'salary_min'),
        salaryMax: _optInt(b, 'salary_max'),
        link: _optStr(b, 'link'),
        notes: _optStr(b, 'notes'),
      );
      return _json(app.toJson(), status: 201);
    }))
    ..patch('/applications/<id>', (r) => _guard(r, verify, (sub, req) async {
      final b = await _body(req);
      final app = await store.updateStage(sub, r.params['id']!, _str(b, 'stage'));
      return _json(app.toJson());
    }))
    ..post('/applications/<id>/archive', (r) => _guard(r, verify, (sub, req) async {
      final app = await store.archiveApplication(sub, r.params['id']!);
      return _json(app.toJson());
    }))
    ..get('/contacts', (r) => _guard(r, verify, (sub, req) async {
      final q = req.url.queryParameters;
      final contacts = await store.listContacts(
        sub,
        applicationId: q['application_id'],
        limit: _int(q['limit'], 50),
      );
      return _json([for (final c in contacts) c.toJson()]);
    }))
    ..post('/contacts', (r) => _guard(r, verify, (sub, req) async {
      final b = await _body(req);
      final channels = b['channels'];
      final c = await store.createContact(
        sub,
        name: _str(b, 'name'),
        applicationId: _optStr(b, 'application_id'),
        role: _optStr(b, 'role'),
        company: _optStr(b, 'company'),
        channels: channels == null
            ? {}
            : Map<String, String>.from(
                (channels as Map).map((k, v) => MapEntry('$k', '$v')),
              ),
      );
      return _json(c.toJson(), status: 201);
    }))
    ..get('/interactions', (r) => _guard(r, verify, (sub, req) async {
      final q = req.url.queryParameters;
      final appId = q['application_id'];
      if (appId == null || appId.isEmpty) {
        throw InputError('application_id is required');
      }
      final items = await store.getInteractions(
        sub,
        appId,
        limit: _int(q['limit'], 50),
      );
      return _json([for (final i in items) i.toJson()]);
    }))
    ..post('/interactions', (r) => _guard(r, verify, (sub, req) async {
      final b = await _body(req);
      final i = await store.logInteraction(
        sub,
        applicationId: _str(b, 'application_id'),
        type: _str(b, 'type'),
        happenedAt: _optDt(b, 'happened_at'),
        summary: _optStr(b, 'summary'),
        followUpAt: _optDt(b, 'follow_up_at'),
      );
      return _json(i.toJson(), status: 201);
    }))
    ..patch('/interactions/<id>', (r) => _guard(r, verify, (sub, req) async {
      final b = await _body(req);
      final fu = _optDt(b, 'follow_up_at');
      if (fu == null) throw InputError('follow_up_at is required');
      final i = await store.setFollowUp(sub, r.params['id']!, fu);
      return _json(i.toJson());
    }))
    ..get('/stale_followups', (r) => _guard(r, verify, (sub, req) async {
      final stale = await store.staleFollowups(
        sub,
        limit: _int(req.url.queryParameters['limit'], 50),
      );
      return _json(stale);
    }))
    ..get('/stats', (r) => _guard(r, verify, (sub, req) async {
      return _json(await store.stats(sub));
    }))
    ..delete('/account', (r) => _guard(r, verify, (sub, req) async {
      final deleted = await store.deleteAccount(sub);
      return _json({
        'deleted_rows': deleted,
        'auth_user':
            'Remove the user in Neon console → Auth → Users (admin API is not exposed on Managed Auth).',
      });
    }));

  return Router()
    ..get('/', (_) => Response.ok('job-tracker-mcp server (Phase 1)\n'))
    ..get('/health', (_) => _json({'ok': true, 'phase': 1}))
    ..mount('/api/', Pipeline().addHandler(api.call));
}

/// Dual-issuer authentication: Better Auth JWT first, ephemeral demo bearer
/// second (256-bit hex; sha256 stored). Either yields the caller `sub`.
/// Non-hex tokens never touch the demo table.
VerifyToken dualVerify({
  required VerifyToken jwt,
  required Store store,
}) => (String token) async {
  try {
    return await jwt(token);
  } catch (_) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(token)) rethrow;
    final sub = await store.resolveDemoUser(_sha256hex(token));
    if (sub == null) rethrow;
    return JwtClaims(sub: sub, raw: const {'demo': true});
  }
};

/// Auth gate: Bearer token → `sub` → handler. Any failure is 401, no fallback.
Future<Response> _guard(
  Request req,
  VerifyToken verify,
  Future<Response> Function(String sub, Request req) run,
) async {
  final header = req.headers['authorization'];
  final token = header != null && header.startsWith('Bearer ')
      ? header.substring(7)
      : null;
  if (token == null || token.isEmpty) {
    return _json({'error': 'missing bearer token'}, status: 401);
  }
  late final String sub;
  try {
    sub = (await verify(token)).sub;
  } catch (_) {
    return _json({'error': 'invalid or expired token'}, status: 401);
  }
  try {
    return await run(sub, req);
  } on InputError catch (e) {
    return _json({'error': e.message}, status: 400);
  } on NotFound {
    return _json({'error': 'not found'}, status: 404);
  } on CrossUserAccess {
    // Never reveal whether a foreign row exists.
    return _json({'error': 'not found'}, status: 404);
  } catch (e) {
    return _json({'error': 'internal error: $e'}, status: 500);
  }
}

Response _json(Object value, {int status = 200}) => Response(
  status,
  body: jsonEncode(value),
  headers: {'content-type': 'application/json'},
);

Future<Map<String, dynamic>> _body(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  throw InputError('request body must be a JSON object');
}

String _str(Map<String, dynamic> b, String key) {
  final v = b[key];
  if (v is! String || v.trim().isEmpty) throw InputError('$key is required');
  return v;
}

String? _optStr(Map<String, dynamic> b, String key) {
  final v = b[key];
  if (v == null) return null;
  if (v is! String) throw InputError('$key must be a string');
  return v;
}

int? _optInt(Map<String, dynamic> b, String key) {
  final v = b[key];
  if (v == null) return null;
  if (v is int) return v;
  throw InputError('$key must be an integer');
}

DateTime? _optDt(Map<String, dynamic> b, String key) {
  final v = _optStr(b, key);
  if (v == null || v.trim().isEmpty) return null;
  try {
    return DateTime.parse(v);
  } catch (_) {
    throw InputError('$key must be ISO-8601');
  }
}

int _int(String? v, int fallback) {
  final n = int.tryParse(v ?? '');
  return n ?? fallback;
}
