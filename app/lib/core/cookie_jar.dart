/// Minimal cookie jar for the paste-link magic-link flow (mobile): capture
/// `Set-Cookie` from the verify response, replay as `Cookie`.
/// (Browser clients manage their own jar; this is for dart:io.)
class CookieJar {
  CookieJar([Map<String, String>? initial]) : _c = {...?initial};

  final Map<String, String> _c;

  static const _attributes = {
    'expires',
    'max-age',
    'path',
    'domain',
    'samesite',
    'secure',
    'httponly',
    'partitioned',
  };

  void store(String? setCookieHeader) {
    final raw = setCookieHeader;
    if (raw == null || raw.isEmpty) return;
    for (final m in RegExp(r'([A-Za-z0-9_.\-]+)=([^;,\s]+)').allMatches(raw)) {
      final name = m.group(1)!;
      if (_attributes.contains(name.toLowerCase())) continue;
      _c[name] = m.group(2)!;
    }
  }

  bool get isEmpty => _c.isEmpty;
  List<String> get names => _c.keys.toList();
  Map<String, String> toMap() => Map.of(_c);

  String get header =>
      _c.entries.map((e) => '${e.key}=${e.value}').join('; ');
}
