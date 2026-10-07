/// Data models: JSON-serializable, user-scoped rows.
library;

import 'stage.dart';

/// Interaction types (v1 fixed set).
const Set<String> interactionTypes = {
  'note',
  'call',
  'email',
  'meeting',
  'interview',
  'followup',
  'other',
};

/// A job application. Every row carries [userId] from the JWT `sub`.
class Application {
  Application({
    required this.id,
    required this.userId,
    required this.company,
    required this.role,
    required this.stage,
    this.source,
    this.appliedAt,
    this.salaryMin,
    this.salaryMax,
    this.link,
    this.notes,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String company;
  final String role;
  final AppStage stage;
  final String? source;
  final DateTime? appliedAt;
  final int? salaryMin;
  final int? salaryMax;
  final String? link;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get archived => archivedAt != null;

  factory Application.fromJson(Map<String, dynamic> json) => Application(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    company: json['company'] as String,
    role: json['role'] as String,
    stage: parseStage(json['stage'] as String) ?? AppStage.saved,
    source: json['source'] as String?,
    appliedAt: _dt(json['applied_at']),
    salaryMin: json['salary_min'] as int?,
    salaryMax: json['salary_max'] as int?,
    link: json['link'] as String?,
    notes: json['notes'] as String?,
    archivedAt: _dt(json['archived_at']),
    createdAt: _dt(json['created_at']),
    updatedAt: _dt(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'company': company,
    'role': role,
    'stage': stage.name,
    if (source != null) 'source': source,
    if (appliedAt != null) 'applied_at': appliedAt!.toIso8601String(),
    if (salaryMin != null) 'salary_min': salaryMin,
    if (salaryMax != null) 'salary_max': salaryMax,
    if (link != null) 'link': link,
    if (notes != null) 'notes': notes,
    if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}

/// A contact, optionally linked to an application.
class Contact {
  Contact({
    required this.id,
    required this.userId,
    required this.name,
    this.applicationId,
    this.role,
    this.company,
    this.channels = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? applicationId;
  final String? role;
  final String? company;

  /// e.g. `{"email": "a@b.c", "linkedin": "https://…"}`.
  final Map<String, String> channels;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    applicationId: json['application_id'] as String?,
    role: json['role'] as String?,
    company: json['company'] as String?,
    channels: ((json['channels'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
    createdAt: _dt(json['created_at']),
    updatedAt: _dt(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    if (applicationId != null) 'application_id': applicationId,
    if (role != null) 'role': role,
    if (company != null) 'company': company,
    'channels': channels,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}

/// A logged interaction on an application (call, email, …).
class Interaction {
  Interaction({
    required this.id,
    required this.userId,
    required this.applicationId,
    required this.type,
    required this.happenedAt,
    this.summary,
    this.followUpAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String applicationId;
  final String type;
  final DateTime happenedAt;
  final String? summary;
  final DateTime? followUpAt;
  final DateTime? createdAt;

  factory Interaction.fromJson(Map<String, dynamic> json) => Interaction(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    applicationId: json['application_id'] as String,
    type: json['type'] as String,
    happenedAt: DateTime.parse(json['happened_at'] as String),
    summary: json['summary'] as String?,
    followUpAt: _dt(json['follow_up_at']),
    createdAt: _dt(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'application_id': applicationId,
    'type': type,
    'happened_at': happenedAt.toIso8601String(),
    if (summary != null) 'summary': summary,
    if (followUpAt != null) 'follow_up_at': followUpAt!.toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}

DateTime? _dt(Object? v) =>
    v == null ? null : DateTime.parse(v as String);
