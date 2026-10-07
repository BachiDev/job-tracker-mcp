import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

Router buildRouter() {
  final router = Router()
    ..get('/', _rootHandler)
    ..get('/health', _healthHandler)
    ..get('/echo/<message>', _echoHandler);
  return router;
}

Response _rootHandler(Request req) =>
    Response.ok('job-tracker-mcp server (Phase 0)\n');

Response _healthHandler(Request req) => Response.ok(
  jsonEncode({'ok': true, 'phase': 0}),
  headers: {'content-type': 'application/json'},
);

Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

Future<void> main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(buildRouter().call);
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  // ignore: avoid_print
  print('Server listening on port ${server.port}');
}
