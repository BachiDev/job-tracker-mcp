import 'models.dart';
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

  /// Interaction summary cap: 5k chars.
  static String? summary(String? value) {
    if ((value ?? '').length > 5000) return 'Summary too long (max 5000)';
    return null;
  }

  /// Source cap: 100 chars.
  static String? source(String? value) {
    if ((value ?? '').length > 100) return 'Source too long (max 100)';
    return null;
  }

  /// Contact name must be 1..200 chars after trim.
  static String? contactName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Name is required';
    if (v.length > 200) return 'Name is too long (max 200)';
    return null;
  }

  /// Interaction type must be in the v1 fixed set.
  static String? interactionType(String? value) {
    if (!interactionTypes.contains(value)) return 'Unknown interaction type';
    return null;
  }

  /// Link must be an absolute http(s) URL when present.
  static String? link(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri == null ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Link must be an absolute http(s) URL';
    }
    if (v.length > 2000) return 'Link too long (max 2000)';
    return null;
  }

  /// Salary bounds: non-negative, min ≤ max.
  static String? salary(int? min, int? max) {
    if (min != null && min < 0) return 'Salary cannot be negative';
    if (max != null && max < 0) return 'Salary cannot be negative';
    if (min != null && max != null && min > max) {
      return 'salary_min cannot exceed salary_max';
    }
    return null;
  }

  /// applied_at cannot be in the future (compares instants).
  static String? appliedAt(DateTime? value, DateTime now) {
    if (value != null && value.isAfter(now)) {
      return 'applied_at cannot be in the future';
    }
    return null;
  }

  /// follow_up_at must be after happened_at when both present.
  static String? followUpAt(DateTime? followUp, DateTime happened) {
    if (followUp != null && !followUp.isAfter(happened)) {
      return 'follow_up_at must be after happened_at';
    }
    return null;
  }

  /// Contact channels: ≤20 entries, short keys/values.
  static String? channels(Map<String, String>? value) {
    final v = value ?? {};
    if (v.length > 20) return 'Too many channels (max 20)';
    for (final e in v.entries) {
      if (e.key.length > 50) return 'Channel name too long (max 50)';
      if (e.value.length > 500) return 'Channel value too long (max 500)';
    }
    return null;
  }
}
