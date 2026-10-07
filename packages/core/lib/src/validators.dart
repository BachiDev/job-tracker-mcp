import 'stage.dart';

/// Server-side validation rules (mirrored in app forms). Keep in sync.
class Validators {
  /// Company must be 1..200 chars after trim.
  static String? company(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Company is required';
    if (v.length > 200) return 'Company is too long (max 200)';
    return null;
  }

  /// Role must be 1..200 chars after trim.
  static String? role(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Role is required';
    if (v.length > 200) return 'Role is too long (max 200)';
    return null;
  }

  /// Stage name must be a known enum value.
  static String? stageName(String? value) {
    if (parseStage(value ?? '') == null) return 'Unknown stage';
    return null;
  }

  /// Notes cap: 10k chars.
  static String? notes(String? value) {
    if ((value ?? '').length > 10000) return 'Notes too long (max 10000)';
    return null;
  }
}
