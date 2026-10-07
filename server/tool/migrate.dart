// Migration runner: plain db/migrations/*.sql + schema_migrations ledger.
//
// Usage:
//   dart run tool/migrate.dart --database-url <URL> [--seed] [--dir ../db/migrations]
//   DATABASE_URL env is used when --database-url is absent.
//
// V1__* always applies. V2__seed_demo only applies with --seed (demo/dev,
// never prod). Each file runs in its own transaction.
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:server/db.dart';

/// Splits SQL text into statements on `;` outside strings/comments.
/// V1/V2 use plain DDL + literals (no dollar-quoted bodies); the splitter
/// handles `--` comments and `'...'` (with `''` escapes) so a stray `;` in a
/// comment or literal can't break a migration.
List<String> splitStatements(String sql) {
  final out = <String>[];
  final buf = StringBuffer();
  var i = 0;
  while (i < sql.length) {
    final c = sql[i];
    if (c == '-' && i + 1 < sql.length && sql[i + 1] == '-') {
      while (i < sql.length && sql[i] != '\n') {
        buf.write(sql[i++]);
      }
      continue;
    }
    if (c == "'") {
      buf.write(c);
      i++;
      while (i < sql.length) {
        buf.write(sql[i]);
        if (sql[i] == "'") {
          if (i + 1 < sql.length && sql[i + 1] == "'") {
            buf.write(sql[++i]);
            i++;
            continue;
          }
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    if (c == ';') {
      final stmt = buf.toString().trim();
      if (stmt.isNotEmpty) out.add(stmt);
      buf.clear();
      i++;
      continue;
    }
    buf.write(c);
    i++;
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}

Future<void> main(List<String> args) async {
  String? databaseUrl = Platform.environment['DATABASE_URL'];
  var seed = false;
  var dir = '../db/migrations';

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--database-url' && i + 1 < args.length) {
      databaseUrl = args[++i];
    } else if (args[i] == '--seed') {
      seed = true;
    } else if (args[i] == '--dir' && i + 1 < args.length) {
      dir = args[++i];
    }
  }
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('missing database url (set DATABASE_URL)');
    exit(2);
  }

  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final conn = await openDb(databaseUrl);
  try {
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    ''');
    final applied = <String>{
      for (final row in await conn.execute('SELECT version FROM schema_migrations'))
        row[0] as String,
    };

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final isSeed = name.startsWith('V2__');
      if (isSeed && !seed) {
        stdout.writeln('SKIP $name (demo seed, pass --seed to apply)');
        continue;
      }
      if (applied.contains(name)) {
        stdout.writeln('SKIP $name (already applied)');
        continue;
      }
      final sql = await file.readAsString();
      await conn.runTx((tx) async {
        for (final stmt in splitStatements(sql)) {
          await tx.execute(stmt);
        }
        await tx.execute(
          Sql.named('INSERT INTO schema_migrations (version) VALUES (@v)'),
          parameters: {'v': name},
        );
      });
      stdout.writeln('OK $name');
    }
  } finally {
    await conn.close();
  }
}
