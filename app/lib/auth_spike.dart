import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Throwaway Phase 0 spike: Better Auth REST (magic link + Google),
/// session attach, JWT fetch. Every step appends raw status to [log] so
/// platform differences (cookies on web vs Android, CORS) surface here,
/// not in Phase 2. Not shipped: no persistence, no polish.
class SpikeApi {
  SpikeApi({required this.baseUrl, http.Client? client, this.onSend, this.onTrace})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Hook for logging the exact outgoing body (dev-only observability).
  final void Function(String body)? onSend;

  /// Hook for per-hop trace lines (status + header *names* only, no values).
  final void Function(String line)? onTrace;
  final Map<String, String> _cookies = {};

  /// Cookie names currently held (values never exposed).
  List<String> get cookieNames => _cookies.keys.toList();

  Future<SpikeResult> requestMagicLink(String email, String callbackUrl) {
    return _post('/sign-in/magic-link', {
      'email': email,
      'callbackURL': callbackUrl,
    });
  }

  /// Fetch the emailed verify link *inside the app* (paste it, don't open it
  /// in a browser) so the session cookie lands in this jar on every platform.
  ///
  /// Follows redirects *manually*: the 302 from verify carries the
  /// `Set-Cookie`, and auto-follow would swallow it, leaving `cookies: []`.
  Future<SpikeResult> verifyLink(String url) async {
    var uri = Uri.parse(url);
    for (var i = 0; i < 5; i++) {
      final req = http.Request('GET', uri)..followRedirects = false;
      req.headers.addAll(_headers());
      final res = await http.Response.fromStream(await _client.send(req));
      onTrace?.call(
        'hop: ${res.statusCode} headers=${res.headers.keys.toList()}',
      );
      _storeCookies(res);
      final loc = res.headers['location'];
      if (_isRedirect(res.statusCode) && loc != null) {
        uri = uri.resolve(loc);
        continue;
      }
      return SpikeResult(res.statusCode, _snip(res.body));
    }
    return const SpikeResult(-1, 'too many redirects');
  }

  Future<SpikeResult> googleSignIn(String callbackUrl) {
    return _post('/sign-in/social', {
      'provider': 'google',
      'callbackURL': callbackUrl,
    });
  }

  Future<SpikeResult> getSession() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/get-session'),
      headers: _headers(),
    );
    return SpikeResult(res.statusCode, _snip(res.body));
  }

  Future<SpikeResult> getToken() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/token'),
      headers: _headers(),
    );
    return SpikeResult(res.statusCode, _snip(res.body));
  }

  Future<SpikeResult> _post(String path, Map<String, String> json) async {
    final encoded = jsonEncode(json);
    onSend?.call(encoded);
    final res = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {..._headers(), 'content-type': 'application/json'},
      body: encoded,
    );
    _storeCookies(res);
    return SpikeResult(res.statusCode, _snip(res.body));
  }

  Map<String, String> _headers() {
    if (_cookies.isEmpty) return {};
    final value = _cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
    return {'cookie': value};
  }

  static const _attributes = {
    'expires',
    'max-age',
    'path',
    'domain',
    'samesite',
    'secure',
    'httponly',
    'partitioned',
  };

  void _storeCookies(http.Response res) {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    for (final m in RegExp(r'([A-Za-z0-9_.\-]+)=([^;,\s]+)').allMatches(raw)) {
      final name = m.group(1)!;
      if (_attributes.contains(name.toLowerCase())) continue;
      _cookies[name] = m.group(2)!;
    }
  }

  void close() => _client.close();
}

String _snip(String body) =>
    body.length > 500 ? '${body.substring(0, 500)}…(${body.length} chars)' : body;

/// One logged HTTP outcome. Bodies are truncated; cookie *values* are never
/// logged (only names, via [SpikeApi.cookieNames]).
class SpikeResult {
  const SpikeResult(this.status, this.body);
  final int status;
  final String body;

  @override
  String toString() => '→ $status $body';
}

bool _isRedirect(int status) =>
    status == 301 ||
    status == 302 ||
    status == 303 ||
    status == 307 ||
    status == 308;

const authBaseUrl = String.fromEnvironment(
  'AUTH_BASE_URL',
  defaultValue:
      'https://ep-polished-mouse-b15ihsmx.neonauth.c-5.eu-central-1.aws.neon.tech/neondb/auth',
);

class AuthSpikeScreen extends StatefulWidget {
  const AuthSpikeScreen({super.key});

  @override
  State<AuthSpikeScreen> createState() => _AuthSpikeScreenState();
}

class _AuthSpikeScreenState extends State<AuthSpikeScreen> {
  late final SpikeApi _api = SpikeApi(
    baseUrl: authBaseUrl,
    onSend: (body) => _say('  sent: $body'),
    onTrace: _say,
  );
  final _email = TextEditingController(text: 'fabian@bachi.dev');
  // Local web sends Origin: http://localhost:<port> and the server requires
  // callbackURL to match it — run with --web-port 5000 and keep this in sync.
  // Android sends no Origin header, so the https callback works there.
  final _callback = TextEditingController();
  final _verifyUrl = TextEditingController();
  final _log = <String>[];
  bool _busy = false;

  @override
  void dispose() {
    _api.close();
    _email.dispose();
    _callback.dispose();
    _verifyUrl.dispose();
    super.dispose();
  }

  void _say(String line) => setState(() => _log.add(line));

  Future<void> _run(String label, Future<SpikeResult> Function() call) async {
    setState(() => _busy = true);
    _say('… $label');
    try {
      final r = await call();
      _say('$label $r');
      _say('  cookies: ${_api.cookieNames}');
    } catch (e) {
      _say('$label FAILED: $e');
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth spike (Phase 0, dev-only)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _callback,
            decoration: const InputDecoration(
              labelText: 'Callback URL',
              hintText: 'web: http://localhost:5000 · android: https://bachi.dev/work',
            ),
          ),
          TextField(
            controller: _verifyUrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Verify link (paste from email, unclicked)',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        'magic-link',
                        () => _api.requestMagicLink(
                          _email.text.trim(),
                          _callback.text.trim(),
                        ),
                      ),
                child: const Text('1. Request magic link'),
              ),
              FilledButton(
                onPressed: _busy || _verifyUrl.text.trim().isEmpty
                    ? null
                    : () => _run(
                        'verify',
                        () => _api.verifyLink(_verifyUrl.text.trim()),
                      ),
                child: const Text('2. Verify link'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run('session', _api.getSession),
                child: const Text('3. Check session'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run('jwt', _api.getToken),
                child: const Text('4. Get JWT'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        'google',
                        () => _api.googleSignIn(_callback.text.trim()),
                      ),
                child: const Text('G. Google sign-in URL'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Google: open the returned url in a browser, sign in, then tap 3. '
            'Restart the app and tap 3 again to test refresh/persistence '
            '(expect logged-out: spike keeps cookies in memory only).',
          ),
          const Divider(height: 24),
          SelectableText(_log.join('\n')),
        ],
      ),
    );
  }
}
