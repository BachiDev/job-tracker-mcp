import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import 'package:server/api.dart';
import 'package:server/auth/jwt_verify.dart';
import 'package:server/store.dart';

Store _noDb() => Store.pool('postgresql://u:p@localhost:5432/db');

Future<Response> _get(Router router, String path, {String? token}) {
  final headers = token == null
      ? <String, String>{}
      : {'authorization': 'Bearer $token'};
  return router.call(
    Request('GET', Uri.parse('http://localhost$path'), headers: headers),
  );
}

Future<JwtClaims> _boom(String _) => throw const FormatException('bad');
Future<JwtClaims> _ok(String _) async => JwtClaims(sub: 'u1', raw: {});

void main() {
  group('public surface', () {
    test('GET /health needs no auth', () async {
      final router = buildRouter(store: _noDb(), verify: _boom);
      final res = await _get(router, '/health');
      expect(res.statusCode, 200);
      expect(await res.readAsString(), contains('"phase":1'));
    });

    test('unknown route 404s', () async {
      final router = buildRouter(store: _noDb(), verify: _boom);
      final res = await _get(router, '/nope');
      expect(res.statusCode, 404);
    });
  });

  group('demo accounts', () {
    test('demoAllowed sliding window (pure)', () {
      final now = DateTime.utc(2026, 10, 8);
      expect(demoAllowed([], now), isTrue);
      expect(
        demoAllowed(
          [for (var i = 0; i < 10; i++) now.subtract(Duration(minutes: i))],
          now,
        ),
        isFalse,
      );
      expect(
        demoAllowed(
          [for (var i = 0; i < 10; i++) now.subtract(const Duration(hours: 2))],
          now,
        ),
        isTrue,
      );
    });
  });

  group('auth gate', () {
    test('missing token is 401 without touching the verifier', () async {
      var called = false;
      final router = buildRouter(
        store: _noDb(),
        verify: (t) async {
          called = true;
          return JwtClaims(sub: 'u1', raw: {});
        },
      );
      final res = await _get(router, '/api/stats');
      expect(res.statusCode, 401);
      expect(called, isFalse);
    });

    test('malformed scheme is 401', () async {
      final router = buildRouter(store: _noDb(), verify: _ok);
      final res = await router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/api/stats'),
          headers: {'authorization': 'Token abc'},
        ),
      );
      expect(res.statusCode, 401);
    });

    test('verifier failure is 401', () async {
      final router = buildRouter(store: _noDb(), verify: _boom);
      final res = await _get(router, '/api/stats', token: 'bogus');
      expect(res.statusCode, 401);
      expect(await res.readAsString(), contains('invalid or expired'));
    });
  });
}
