import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// Result of a successful JWT verification.
class JwtClaims {
  JwtClaims({required this.sub, required this.raw});

  /// Better Auth user id (`sub` claim). Used as `user_id` scope.
  final String sub;

  /// Full decoded payload.
  final Map<String, dynamic> raw;
}

/// Verifies Neon Managed Better Auth JWTs (Ed25519 / EdDSA) against JWKS.
///
/// Phase 0 spike: fail here, not later (PLAN risk #2). Uses `cryptography`
/// for Ed25519 (fallback path from the plan) so we do not depend on
/// dart_jsonwebtoken EdDSA support.
class JwtVerifier {
  JwtVerifier({required this.jwksUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String jwksUrl;
  final http.Client _client;

  Map<String, Uint8List>? _keyCache;

  /// Verify [token] (`header.payload.signature`, base64url). Throws on any
  /// failure — callers map to 401 with no fallback paths.
  Future<JwtClaims> verify(String token) async {
    final parts = token.split('.');
    if (parts.length != 3) throw const FormatException('malformed JWT');

    final header = _decodeJson(parts[0]);
    if (header['alg'] != 'EdDSA') throw const FormatException('unexpected alg');

    final kid = header['kid'] as String?;
    final signingInput = utf8.encode('${parts[0]}.${parts[1]}');
    final signature = _b64u(parts[2]);

    final keys = _keyCache ??= await _fetchKeys();
    final candidates = kid == null
        ? keys.values.toList()
        : [keys[kid]].whereType<Uint8List>().toList();
    if (candidates.isEmpty) throw const FormatException('unknown kid');

    final algorithm = Ed25519();
    var valid = false;
    for (final pk in candidates) {
      final publicKey = SimplePublicKey(pk, type: KeyPairType.ed25519);
      final sig = Signature(signature, publicKey: publicKey);
      if (await algorithm.verify(signingInput, signature: sig)) {
        valid = true;
        break;
      }
    }
    if (!valid) throw const FormatException('bad signature');

    final payload = _decodeJson(parts[1]);
    final exp = payload['exp'];
    if (exp is int) {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (nowSec >= exp) throw const FormatException('expired');
    }
    final sub = payload['sub'] as String?;
    if (sub == null || sub.isEmpty) {
      throw const FormatException('missing sub');
    }
    return JwtClaims(sub: sub, raw: payload);
  }

  Future<Map<String, Uint8List>> _fetchKeys() async {
    final res = await _client.get(Uri.parse(jwksUrl));
    if (res.statusCode != 200) {
      throw StateError('JWKS fetch failed: ${res.statusCode}');
    }
    final doc = jsonDecode(res.body) as Map<String, dynamic>;
    final keys = doc['keys'] as List;
    final out = <String, Uint8List>{};
    for (final k in keys) {
      final m = k as Map<String, dynamic>;
      if (m['kty'] == 'OKP' && m['crv'] == 'Ed25519' && m['x'] is String) {
        final kid = m['kid'] as String? ?? m['x'] as String;
        out[kid] = _b64u(m['x'] as String);
      }
    }
    if (out.isEmpty) throw StateError('no Ed25519 keys in JWKS');
    return out;
  }

  static Map<String, dynamic> _decodeJson(String part) {
    return jsonDecode(utf8.decode(_b64u(part))) as Map<String, dynamic>;
  }

  static Uint8List _b64u(String s) {
    return Uint8List.fromList(base64Url.decode(base64Url.normalize(s)));
  }
}
