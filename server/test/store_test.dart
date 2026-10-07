import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import 'package:server/api.dart';
import 'package:server/auth/jwt_verify.dart';
import 'package:server/db.dart';
import 'package:server/store.dart';

/// Live-DB suite against the `ci` Neon branch (TEST_DATABASE_URL, falls back
/// to DATABASE_URL). Skipped without a URL — CI always provides one.
/// Every test uses a synthetic user and deletes it afterwards, so parallel or
/// repeated runs never collide. Counter suffix because Windows clock
/// granularity can repeat microsecondsSinceEpoch for back-to-back calls.
var _userN = 0;
String _user() =>
    'test-${DateTime.now().microsecondsSinceEpoch}-${_userN++}';

Future<JwtClaims> _ok(String _) async => JwtClaims(sub: 'u1', raw: {});
Future<JwtClaims> _boom(String _) => throw const FormatException('bad');

Future<Response> _call(
  Router router,
  String method,
  String path, {
  Map<String, dynamic>? body,
  String token = 'x',
}) {
  final req = Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {
      'authorization': 'Bearer $token',
      if (body != null) 'content-type': 'application/json',
    },
    body: body == null ? null : jsonEncode(body),
  );
  return router.call(req);
}

void main() {
  final url =
      Platform.environment['TEST_DATABASE_URL'] ??
      Platform.environment['DATABASE_URL'];

  group('store (live)', () {
    test('CRUD + stats + stale + deleteAccount', () async {
      if (url == null) {
        markTestSkipped('no TEST_DATABASE_URL/DATABASE_URL');
        return;
      }
      final store = Store.pool(url);
      final u = _user();
      try {
        // create + read back
        final app = await store.createApplication(
          u,
          company: 'Acme',
          role: 'Engineer',
          stage: 'applied',
          appliedAt: DateTime.now().toUtc().subtract(const Duration(days: 9)),
        );
        expect(app.company, 'Acme');
        expect((await store.listApplications(u)).length, 1);

        // validation rejects junk
        expect(
          () => store.createApplication(u, company: '', role: 'x'),
          throwsA(isA<InputError>()),
        );
        expect(
          () => store.createApplication(
            u,
            company: 'Acme',
            role: 'x',
            salaryMin: 5,
            salaryMax: 1,
          ),
          throwsA(isA<InputError>()),
        );

        // stage move + stale (applied 9d > 7d threshold). Touching the row
        // refreshes updated_at, so backdate it to simulate 9 days in stage.
        await store.updateStage(u, app.id, 'interview');
        var stale = await store.staleFollowups(u);
        expect(stale, isEmpty); // interview touched just now
        await store.updateStage(u, app.id, 'applied');
        final conn = await openDb(url);
        try {
          await conn.execute(
            Sql.named(
              "UPDATE applications SET updated_at = now() - interval '9 days'"
              ' WHERE id=@id',
            ),
            parameters: {'id': app.id},
          );
        } finally {
          await conn.close();
        }
        stale = await store.staleFollowups(u);
        expect(stale.length, 1);
        expect(stale.first['stale_reason'], contains('applied'));

        // contacts + interactions
        final contact = await store.createContact(
          u,
          name: 'Jane',
          applicationId: app.id,
          channels: {'email': 'j@example.com'},
        );
        expect(contact.name, 'Jane');
        expect((await store.listContacts(u)).length, 1);
        final inter = await store.logInteraction(
          u,
          applicationId: app.id,
          type: 'call',
          summary: 'screening',
          followUpAt: DateTime.now().toUtc().add(const Duration(days: 2)),
        );
        expect(inter.type, 'call');
        expect(
          (await store.getInteractions(u, app.id)).length,
          1,
        );
        final moved = await store.setFollowUp(
          u,
          inter.id,
          DateTime.now().toUtc().add(const Duration(days: 5)),
        );
        expect(moved.followUpAt, isNotNull);

        // stats computed from the same rows
        final stats = await store.stats(u);
        expect(stats['total_active'], 1);
        expect((stats['by_stage'] as Map)['applied'], 1);
        expect(stats['total_contacts'], 1);
        expect(stats['upcoming_followups_14d'], 1);

        // archive hides from default list
        await store.archiveApplication(u, app.id);
        expect(await store.listApplications(u), isEmpty);
        expect(
          (await store.listApplications(u, includeArchived: true)).length,
          1,
        );
      } finally {
        await store.deleteAccount(u);
        await store.close();
      }
      // rows gone
      final check = Store.pool(url);
      try {
        expect(await check.listApplications(u), isEmpty);
        expect(await check.listContacts(u), isEmpty);
      } finally {
        await check.close();
      }
    });

    test('cross-user isolation: foreign rows look missing', () async {
      if (url == null) {
        markTestSkipped('no TEST_DATABASE_URL/DATABASE_URL');
        return;
      }
      final store = Store.pool(url);
      final a = _user();
      final b = _user();
      try {
        final app = await store.createApplication(
          a,
          company: 'Acme',
          role: 'Engineer',
        );
        expect(await store.listApplications(b), isEmpty);
        expect(() => store.getApplication(b, app.id), throwsA(isA<NotFound>()));
        expect(
          () => store.logInteraction(b, applicationId: app.id, type: 'note'),
          throwsA(isA<NotFound>()),
        );
        expect(
          () => store.updateStage(b, app.id, 'offer'),
          throwsA(isA<NotFound>()),
        );
      } finally {
        await store.deleteAccount(a);
        await store.deleteAccount(b);
        await store.close();
      }
    });
  });

  group('demo accounts (live)', () {
    test('bootstrap → seed → bearer CRUD → expiry', () async {
      if (url == null) {
        markTestSkipped('no TEST_DATABASE_URL/DATABASE_URL');
        return;
      }
      final store = Store.pool(url);
      final router = buildRouter(
        store: store,
        verify: dualVerify(jwt: _boom, store: store),
      );
      try {
        // public bootstrap (no auth)
        final boot = await _call(router, 'POST', '/api/demo/bootstrap');
        expect(boot.statusCode, 201);
        final body =
            jsonDecode(await boot.readAsString()) as Map<String, dynamic>;
        final token = body['token'] as String;
        expect(token.length, 64);

        // bearer works through the dual-issuer gate
        final authed = dualVerify(jwt: _boom, store: store);
        final claims = await authed(token);
        expect(claims.sub, (body['user_id'] as String));

        // seeded dataset visible to the demo user (same pool: one Store
        // per test, mirroring the single-pool server process)
        final apps = await store.listApplications(claims.sub);
        expect(apps.length, 6);
        final stats = await store.stats(claims.sub);
        expect(stats['total_active'], greaterThanOrEqualTo(4));
        expect(stats['stale_count'], greaterThanOrEqualTo(1));

        // unknown bearer still 401s (through the real guard path)
        final denied = await _call(router, 'GET', '/api/stats', token: 'f' * 64);
        expect(denied.statusCode, 401);

        // cleanup demo rows
        await store.deleteAccount(claims.sub);
      } finally {
        await store.close();
      }
    });
  });

  group('REST (live)', () {
    test('stats + stale endpoints honor auth identity', () async {
      if (url == null) {
        markTestSkipped('no TEST_DATABASE_URL/DATABASE_URL');
        return;
      }
      final store = Store.pool(url);
      final router = buildRouter(store: store, verify: _ok);
      try {
        var res = await _call(router, 'GET', '/api/stats');
        expect(res.statusCode, 200);
        final stats =
            jsonDecode(await res.readAsString()) as Map<String, dynamic>;
        expect(stats['total_active'], 0);

        res = await _call(
          router,
          'POST',
          '/api/applications',
          body: {'company': 'Acme', 'role': 'Eng'},
        );
        expect(res.statusCode, 201);

        res = await _call(router, 'POST', '/api/applications', body: {});
        expect(res.statusCode, 400);

        res = await _call(router, 'GET', '/api/stale_followups');
        expect(res.statusCode, 200);
      } finally {
        await store.deleteAccount('u1');
        await store.close();
      }
    });

    test('param routes round-trip (regression: typed req.params)', () async {
      if (url == null) {
        markTestSkipped('no TEST_DATABASE_URL/DATABASE_URL');
        return;
      }
      final store = Store.pool(url);
      final router = buildRouter(store: store, verify: _ok);
      try {
        var res = await _call(
          router,
          'POST',
          '/api/applications',
          body: {'company': 'Acme', 'role': 'Eng'},
        );
        final id =
            (jsonDecode(await res.readAsString()) as Map)['id'] as String;

        res = await _call(router, 'GET', '/api/applications/$id');
        expect(res.statusCode, 200);

        res = await _call(
          router,
          'PATCH',
          '/api/applications/$id',
          body: {'stage': 'interview'},
        );
        expect(res.statusCode, 200);
        expect(
          (jsonDecode(await res.readAsString()) as Map)['stage'],
          'interview',
        );

        res = await _call(
          router,
          'POST',
          '/api/interactions',
          body: {'application_id': id, 'type': 'note'},
        );
        expect(res.statusCode, 201);
        final interId =
            (jsonDecode(await res.readAsString()) as Map)['id'] as String;

        res = await _call(
          router,
          'GET',
          '/api/interactions?application_id=$id',
        );
        expect(res.statusCode, 200);

        res = await _call(
          router,
          'PATCH',
          '/api/interactions/$interId',
          body: {'follow_up_at': '2030-01-01T00:00:00Z'},
        );
        expect(res.statusCode, 200);

        res = await _call(router, 'POST', '/api/applications/$id/archive');
        expect(res.statusCode, 200);

        res = await _call(router, 'GET', '/api/contacts');
        expect(res.statusCode, 200);

        res = await _call(
          router,
          'POST',
          '/api/contacts',
          body: {'name': 'Jane'},
        );
        expect(res.statusCode, 201);

        res = await _call(router, 'DELETE', '/api/account');
        expect(res.statusCode, 200);
      } finally {
        await store.deleteAccount('u1');
        await store.close();
      }
    });
  });
}
