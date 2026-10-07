import 'package:http/http.dart' as http;

import 'http_client_stub.dart'
    if (dart.library.js_interop) 'http_client_web.dart';

/// App-wide HTTP client. On web this enables credentials (cookies) for the
/// cross-origin auth host — required for cookie session attach (PLAN §9.7).
/// Everywhere else it's a plain client.
http.Client createAppClient() => createPlatformClient();
