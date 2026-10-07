// Manual spike: verify a real Neon Auth JWT against the live JWKS.
//
// Usage:
//   dart run tool/jwt_spike.dart --token <BETTER_AUTH_JWT>
//   NEON_AUTH_JWKS_URL env or --jwks-url overrides the default (from .env.local).
//
// Expected: prints `sub=<...>` on success, non-zero exit on 401-path.
// This is the Phase 0 JWT-verify spike (PLAN risk #2): fail here, not later.
import 'dart:io';

import 'package:server/auth/jwt_verify.dart';
import 'package:server/env.dart';

Future<void> main(List<String> args) async {
  final env = loadEnv();
  String? token;
  String? jwksUrl = env['NEON_AUTH_JWKS_URL'];

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--token' && i + 1 < args.length) token = args[++i];
    if (args[i] == '--jwks-url' && i + 1 < args.length) jwksUrl = args[++i];
  }
  token ??= env['SPIKE_JWT'];
  if (token == null || token.isEmpty) {
    stderr.writeln('usage: dart run tool/jwt_spike.dart --token <JWT>');
    exit(2);
  }
  if (jwksUrl == null || jwksUrl.isEmpty) {
    stderr.writeln('missing JWKS url (set NEON_AUTH_JWKS_URL)');
    exit(2);
  }

  try {
    final claims = await JwtVerifier(jwksUrl: jwksUrl).verify(token);
    stdout.writeln('OK sub=${claims.sub}');
  } catch (e) {
    stderr.writeln('VERIFY FAILED: $e');
    exit(1);
  }
}
