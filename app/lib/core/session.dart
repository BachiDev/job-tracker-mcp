import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Signed-in identity: Better Auth JWT or ephemeral demo bearer.
class Session {
  Session({
    required this.token,
    required this.userId,
    this.email,
    this.isDemo = false,
    this.expiresAt,
    this.cookies = const {},
  });

  final String token;
  final String userId;
  final String? email;
  final bool isDemo;
  final DateTime? expiresAt;

  /// Captured session cookies (paste-link flow; re-mint JWTs with them).
  final Map<String, String> cookies;

  bool get expired =>
      expiresAt != null &&
      DateTime.now().toUtc().isAfter(expiresAt!.toUtc());
}

const _kToken = 'jt_token';
const _kUser = 'jt_user';
const _kEmail = 'jt_email';
const _kDemo = 'jt_demo';
const _kExpires = 'jt_expires';
const _kCookies = 'jt_cookies';

/// Session state with secure-storage persistence (secure enclave on mobile,
/// browser storage on web; user-clearable on sign-out).
class SessionController extends AsyncNotifier<Session?> {
  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  @override
  Future<Session?> build() async {
    final token = await _storage.read(key: _kToken);
    final userId = await _storage.read(key: _kUser);
    if (token == null || userId == null) return null;
    final expires = await _storage.read(key: _kExpires);
    final cookiesRaw = await _storage.read(key: _kCookies);
    final s = Session(
      token: token,
      userId: userId,
      email: await _storage.read(key: _kEmail),
      isDemo: (await _storage.read(key: _kDemo)) == '1',
      expiresAt: expires == null ? null : DateTime.tryParse(expires),
      cookies: _decodeCookies(cookiesRaw),
    );
    if (s.expired) {
      await clear(silent: true);
      return null;
    }
    return s;
  }

  Future<void> signIn(Session s) async {
    await _storage.write(key: _kToken, value: s.token);
    await _storage.write(key: _kUser, value: s.userId);
    if (s.email != null) await _storage.write(key: _kEmail, value: s.email);
    await _storage.write(key: _kDemo, value: s.isDemo ? '1' : '0');
    if (s.expiresAt != null) {
      await _storage.write(
        key: _kExpires,
        value: s.expiresAt!.toIso8601String(),
      );
    } else {
      await _storage.delete(key: _kExpires);
    }
    if (s.cookies.isNotEmpty) {
      await _storage.write(
        key: _kCookies,
        value: s.cookies.entries.map((e) => '${e.key}=${e.value}').join(';'),
      );
    } else {
      await _storage.delete(key: _kCookies);
    }
    state = AsyncData(s);
  }

  Future<void> signOut() => clear();

  Future<void> clear({bool silent = false}) async {
    await _storage.deleteAll();
    if (!silent) state = const AsyncData(null);
  }
}

Map<String, String> _decodeCookies(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final out = <String, String>{};
  for (final part in raw.split(';')) {
    final i = part.indexOf('=');
    if (i > 0) out[part.substring(0, i).trim()] = part.substring(i + 1).trim();
  }
  return out;
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(
  SessionController.new,
);
