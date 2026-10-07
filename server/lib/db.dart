import 'package:postgres/postgres.dart';

/// Strips connection params the `postgres` driver doesn't understand
/// (Neon adds `channel_binding=require`). SSL stays enforced via `sslmode`.
String sanitizeDbUrl(String url) {
  final uri = Uri.parse(url);
  final qp = Map<String, String>.of(uri.queryParameters)
    ..remove('channel_binding');
  return uri.replace(queryParameters: qp).toString();
}

/// Opens one connection (migrations, tests). Request-scoped code should use
/// a pool (see `DbPool` below) — this helper exists for scripts.
Future<Connection> openDb(String url) =>
    Connection.openFromUrl(sanitizeDbUrl(url));
