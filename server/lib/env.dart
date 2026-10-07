import 'dart:io';

/// Env resolution: real environment wins, `.env.local` (Neon-managed,
/// gitignored) fills the gaps, so `dart run` and F5 work with zero setup.
/// Searches the current directory and its parent (run from `server/` or the
/// repo root). Never commit the file — it holds real credentials.
Map<String, String> loadEnv() {
  final merged = <String, String>{};
  for (final dir in [Directory.current, Directory.current.parent]) {
    for (final name in ['.env.local', '.env']) {
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      if (file.existsSync()) _parseInto(file.readAsStringSync(), merged);
    }
  }
  merged.addAll(Platform.environment);
  return merged;
}

void _parseInto(String text, Map<String, String> out) {
  for (final line in text.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final i = t.indexOf('=');
    if (i <= 0) continue;
    var value = t.substring(i + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    out[t.substring(0, i).trim()] = value;
  }
}
