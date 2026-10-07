// One-off helper: prints a structurally-valid but bogus EdDSA JWT
// (real kid from live JWKS, random signature) to exercise the JWKS
// fetch path of jwt_spike.dart. Not part of CI.
import 'dart:convert';

String b(Object o) =>
    base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

void main() {
  final h = b({
    'alg': 'EdDSA',
    'typ': 'JWT',
    'kid': '093a3055-54d8-4a0c-9dbb-665fff35ffe1',
  });
  final p = b({'sub': 'spike-test', 'exp': 9999999999});
  final s = 'A' * 86;
  // ignore: avoid_print
  print('$h.$p.$s');
}
