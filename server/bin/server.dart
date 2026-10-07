import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

import 'package:server/api.dart';
import 'package:server/auth/jwt_verify.dart';
import 'package:server/store.dart';

/// REST API entry point: JWT-gated CRUD over the pipeline.
/// Env: DATABASE_URL (pooled), NEON_AUTH_JWKS_URL, PORT.
Future<void> main(List<String> args) async {
  final databaseUrl = Platform.environment['DATABASE_URL'];
  final jwksUrl = Platform.environment['NEON_AUTH_JWKS_URL'];
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('missing DATABASE_URL');
    exit(2);
  }
  if (jwksUrl == null || jwksUrl.isEmpty) {
    stderr.writeln('missing NEON_AUTH_JWKS_URL');
    exit(2);
  }

  final store = Store.pool(databaseUrl);
  final verifier = JwtVerifier(jwksUrl: jwksUrl);
  final verify = dualVerify(jwt: verifier.verify, store: store);
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildRouter(store: store, verify: verify).call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  // ignore: avoid_print
  print('Server listening on port ${server.port}');
}
