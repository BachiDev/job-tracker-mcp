import 'package:mcp_dart/mcp_dart.dart';

/// Phase 0 "hello tool" — stdio entry point.
///
/// Run: `dart run bin/mcp_stdio.dart`
/// Verify: MCP Inspector / `npx @modelcontextprotocol/inspector dart run bin/mcp_stdio.dart`
/// Then connect once from OpenCode (PLAN Phase 0 DoD).
Future<void> main() async {
  final server = McpServer(
    Implementation(name: 'job-tracker-mcp', version: '0.1.0'),
    options: McpServerOptions(
      capabilities: ServerCapabilities(
        tools: ServerCapabilitiesTools(),
      ),
    ),
  );

  server.registerTool(
    'hello',
    description: 'Phase 0 smoke tool. Returns a greeting.',
    inputSchema: JsonSchema.object(
      properties: {
        'name': JsonSchema.string(description: 'Name to greet'),
      },
    ),
    callback: (args, extra) async {
      final name = (args['name'] as String?)?.trim();
      final who = (name == null || name.isEmpty) ? 'world' : name;
      return CallToolResult(
        content: [TextContent(text: 'Hello, $who! (job-tracker-mcp Phase 0)')],
      );
    },
  );

  final transport = StdioServerTransport();
  await server.connect(transport);
}
