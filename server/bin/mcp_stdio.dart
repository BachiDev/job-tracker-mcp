import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

import 'package:server/env.dart';
import 'package:server/mcp_tools.dart';
import 'package:server/store.dart';

/// MCP stdio entry point: the full v1 tool surface over stdio.
///
/// Identity: local stdio trusts the local user only (documented). The caller
/// identity comes from `--user <sub>` or `JOB_TRACKER_USER_ID` (your own
/// Better Auth `sub` after sign-in). DB from `DATABASE_URL`.
///
/// Run: `dart run bin/mcp_stdio.dart --user <sub>`
/// Verify: `npx @modelcontextprotocol/inspector --cli dart run bin/mcp_stdio.dart --user <sub> --method tools/list`
Future<void> main(List<String> args) async {
  final env = loadEnv();
  String? userId = env['JOB_TRACKER_USER_ID'];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--user' && i + 1 < args.length) userId = args[++i];
  }
  final databaseUrl = env['DATABASE_URL'];
  if (userId == null || userId.isEmpty) {
    stderr.writeln('usage: dart run bin/mcp_stdio.dart --user <sub>');
    exit(2);
  }
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('missing DATABASE_URL');
    exit(2);
  }

  final store = Store.pool(databaseUrl);
  final server = McpServer(
    Implementation(name: 'job-tracker-mcp', version: '0.1.0'),
    options: McpServerOptions(
      capabilities: ServerCapabilities(
        tools: ServerCapabilitiesTools(),
      ),
    ),
  );
  registerJobTrackerTools(server, store, userId);

  final transport = StdioServerTransport();
  await server.connect(transport);
}
