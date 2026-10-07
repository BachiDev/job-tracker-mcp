import 'package:shelf/shelf.dart';

/// CORS for browser clients. The web app runs on a different origin
/// (localhost:PORT in dev, hosted domain in prod) and every API call carries
/// `Authorization` / JSON content-type, so browsers preflight.
///
/// Allowed: localhost/loopback (any port), our own domain, plus
/// `CORS_ORIGINS` env (comma-separated) for the prod frontend URL.
/// Everything else gets no ACAO headers (browser blocks, server unaffected).
Middleware cors({required List<String> extraOrigins}) {
  bool allowed(String? origin) {
    if (origin == null || origin.isEmpty) return false;
    if (extraOrigins.contains(origin)) return true;
    final uri = Uri.tryParse(origin);
    if (uri == null) return false;
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') return true;
    if (uri.host == 'bachi.dev' || uri.host.endsWith('.bachi.dev')) {
      return true;
    }
    return false;
  }

  return (Handler inner) {
    return (Request req) async {
      final origin = req.headers['origin'];
      if (req.method == 'OPTIONS') {
        return Response(
          204,
          headers: {
            if (allowed(origin)) ...{
              'access-control-allow-origin': origin!,
              // The app's web client sends credentials:include, which
              // requires this header (Bearer auth itself doesn't need it,
              // but the browser enforces the pair).
              'access-control-allow-credentials': 'true',
            },
            'access-control-allow-methods':
                'GET, POST, PATCH, DELETE, OPTIONS',
            'access-control-allow-headers': 'authorization, content-type',
            'access-control-max-age': '86400',
          },
        );
      }
      final res = await inner(req);
      if (!allowed(origin)) return res;
      return res.change(
        headers: {
          'access-control-allow-origin': origin!,
          'access-control-allow-credentials': 'true',
          'vary': 'Origin',
        },
      );
    };
  };
}

/// Parses `CORS_ORIGINS` (`https://a,https://b`) into a list.
List<String> parseExtraOrigins(String? raw) => (raw ?? '')
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();
