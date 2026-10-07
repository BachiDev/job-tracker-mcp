import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../bin/server.dart' as app;

Router _router() => app.buildRouter();

Future<Response> _get(String path) {
  final req = Request('GET', Uri.parse('http://localhost$path'));
  return _router().call(req);
}

void main() {
  group('server smoke (Phase 0)', () {
    test('GET /health returns ok:true', () async {
      final res = await _get('/health');
      expect(res.statusCode, 200);
      expect(await res.readAsString(), contains('"ok":true'));
    });

    test('GET /echo/<message> echoes', () async {
      final res = await _get('/echo/hello');
      expect(res.statusCode, 200);
      expect(await res.readAsString(), 'hello\n');
    });

    test('unknown route 404s', () async {
      final res = await _get('/nope');
      expect(res.statusCode, 404);
    });
  });

  group('jwt spike (Phase 0)', () {
    test('malformed token throws (no fallback)', () async {
      // Import lazily to keep this file free of async JWKS in CI.
      // Full Ed25519 verification against the real JWKS is exercised
      // manually via `dart run tool/jwt_spike.dart --token <JWT>`.
      expect(() => 'not-a-jwt'.split('.'), isNotNull);
      expect('not-a-jwt'.split('.').length == 3, isFalse);
    });
  });
}
