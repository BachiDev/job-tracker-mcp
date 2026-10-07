import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Web client with credentials enabled so the browser stores/sends auth
/// cookies for the cross-origin Neon Auth host. Requires the server to send
/// `Access-Control-Allow-Origin: <origin>` + `Allow-Credentials: true`;
/// failures here surface as the documented web-auth finding (PLAN §9.7).
http.Client createPlatformClient() {
  final c = BrowserClient()..withCredentials = true;
  return c;
}
