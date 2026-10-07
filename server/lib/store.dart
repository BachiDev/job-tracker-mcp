import 'package:job_tracker_core/job_tracker_core.dart';
import 'package:postgres/postgres.dart';

import 'db.dart';

/// 400-class failure: caller input violates validation or state rules.
class InputError implements Exception {
  InputError(this.message);
  final String message;

  @override
  String toString() => 'InputError: $message';
}

/// 404-class failure: row missing or owned by someone else (never reveal
/// which — cross-user access looks identical to missing).
class NotFound implements Exception {
  NotFound(this.what);
  final String what;

  @override
  String toString() => 'NotFound: $what';
}

/// Data access. Every method takes the caller's `userId` (JWT `sub`) first
/// and scopes **every** query by it — no unscoped reads, no admin bypass.
/// Runs on a pooled [Pool] (lazy connections: constructing never touches
/// the network, so route tests can build one without a database).
class Store {
  Store(this._db);

  /// Production constructor: pooled connections over [databaseUrl].
  factory Store.pool(String databaseUrl) =>
      Store(Pool.withUrl(sanitizeDbUrl(databaseUrl)));

  final Pool _db;

  Future<void> close() async => _db.close();

  // -- applications -------------------------------------------------------

  Future<List<Application>> listApplications(
    String userId, {
    String? stage,
    bool includeArchived = false,
    int limit = 50,
  }) async {
    final st = stage == null ? null : parseStage(stage);
    if (stage != null && st == null) throw InputError('Unknown stage');
    final rows = await _db.execute(
      Sql.named(
        'SELECT * FROM applications WHERE user_id=@u'
        ' AND (@arch::boolean OR archived_at IS NULL)'
        ' AND (@st::text IS NULL OR stage=@st)'
        ' ORDER BY updated_at DESC LIMIT @lim::int',
      ),
      parameters: {
        'u': userId,
        'arch': includeArchived,
        'st': st?.name,
        'lim': _limit(limit),
      },
    );
    return [for (final r in rows) _app(r, userId)];
  }

  Future<Application> getApplication(String userId, String id) async {
    final rows = await _db.execute(
      Sql.named('SELECT * FROM applications WHERE id=@id AND user_id=@u'),
      parameters: {'id': id, 'u': userId},
    );
    if (rows.isEmpty) throw NotFound('application');
    return _app(rows.first, userId);
  }

  Future<Application> createApplication(
    String userId, {
    required String company,
    required String role,
    String? source,
    String stage = 'saved',
    DateTime? appliedAt,
    int? salaryMin,
    int? salaryMax,
    String? link,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    _check([
      Validators.company(company),
      Validators.role(role),
      Validators.source(source),
      Validators.stageName(stage),
      Validators.salary(salaryMin, salaryMax),
      Validators.link(link),
      Validators.notes(notes),
      Validators.appliedAt(appliedAt, now),
    ]);
    final rows = await _db.execute(
      Sql.named(
        'INSERT INTO applications (user_id, company, role, source, stage, '
        ' applied_at, salary_min, salary_max, link, notes)'
        ' VALUES (@u,@c,@r,@s,@st,@at,@smin,@smax,@l,@n)'
        ' RETURNING *',
      ),
      parameters: {
        'u': userId,
        'c': company.trim(),
        'r': role.trim(),
        's': source?.trim().isEmpty ?? true ? null : source!.trim(),
        'st': stage,
        'at': (appliedAt ?? now).toUtc(),
        'smin': salaryMin,
        'smax': salaryMax,
        'l': link?.trim().isEmpty ?? true ? null : link!.trim(),
        'n': notes,
      },
    );
    return _app(rows.first, userId);
  }

  Future<Application> updateStage(
    String userId,
    String id,
    String stage,
  ) async {
    _check([Validators.stageName(stage)]);
    final rows = await _db.execute(
      Sql.named(
        'UPDATE applications SET stage=@st, updated_at=now()'
        ' WHERE id=@id AND user_id=@u RETURNING *',
      ),
      parameters: {'st': stage, 'id': id, 'u': userId},
    );
    if (rows.isEmpty) throw NotFound('application');
    return _app(rows.first, userId);
  }

  Future<Application> archiveApplication(String userId, String id) async {
    final rows = await _db.execute(
      Sql.named(
        'UPDATE applications SET archived_at=now(), updated_at=now()'
        ' WHERE id=@id AND user_id=@u RETURNING *',
      ),
      parameters: {'id': id, 'u': userId},
    );
    if (rows.isEmpty) throw NotFound('application');
    return _app(rows.first, userId);
  }

  // -- contacts -----------------------------------------------------------

  Future<List<Contact>> listContacts(
    String userId, {
    String? applicationId,
    int limit = 50,
  }) async {
    final rows = await _db.execute(
      Sql.named(
        'SELECT * FROM contacts WHERE user_id=@u'
        ' AND (@app::uuid IS NULL OR application_id=@app)'
        ' ORDER BY updated_at DESC LIMIT @lim::int',
      ),
      parameters: {'u': userId, 'app': applicationId, 'lim': _limit(limit)},
    );
    return [for (final r in rows) _contact(r, userId)];
  }

  Future<Contact> createContact(
    String userId, {
    required String name,
    String? applicationId,
    String? role,
    String? company,
    Map<String, String> channels = const {},
  }) async {
    _check([
      Validators.contactName(name),
      Validators.channels(channels),
      if (role != null && role.trim().length > 200) 'Role too long (max 200)',
      if (company != null && company.trim().length > 200)
        'Company too long (max 200)',
    ]);
    if (applicationId != null) {
      await getApplication(userId, applicationId); // 404 unless mine
    }
    final rows = await _db.execute(
      Sql.named(
        'INSERT INTO contacts (user_id, application_id, name, role, company, channels)'
        ' VALUES (@u,@app,@n,@r,@c,@ch) RETURNING *',
      ),
      parameters: {
        'u': userId,
        'app': applicationId,
        'n': name.trim(),
        'r': role?.trim().isEmpty ?? true ? null : role!.trim(),
        'c': company?.trim().isEmpty ?? true ? null : company!.trim(),
        'ch': channels,
      },
    );
    return _contact(rows.first, userId);
  }

  // -- interactions -------------------------------------------------------

  Future<List<Interaction>> getInteractions(
    String userId,
    String applicationId, {
    int limit = 50,
  }) async {
    await getApplication(userId, applicationId); // 404 unless mine
    final rows = await _db.execute(
      Sql.named(
        'SELECT * FROM interactions WHERE application_id=@app AND user_id=@u'
        ' ORDER BY happened_at DESC LIMIT @lim::int',
      ),
      parameters: {'app': applicationId, 'u': userId, 'lim': _limit(limit)},
    );
    return [for (final r in rows) _interaction(r, userId)];
  }

  Future<Interaction> logInteraction(
    String userId, {
    required String applicationId,
    required String type,
    DateTime? happenedAt,
    String? summary,
    DateTime? followUpAt,
  }) async {
    final now = DateTime.now().toUtc();
    final at = (happenedAt ?? now).toUtc();
    _check([
      Validators.interactionType(type),
      Validators.summary(summary),
      Validators.followUpAt(followUpAt?.toUtc(), at),
    ]);
    await getApplication(userId, applicationId); // 404 unless mine
    final rows = await _db.execute(
      Sql.named(
        'INSERT INTO interactions (user_id, application_id, type, happened_at, summary, follow_up_at)'
        ' VALUES (@u,@app,@t,@at,@s,@fu) RETURNING *',
      ),
      parameters: {
        'u': userId,
        'app': applicationId,
        't': type,
        'at': at,
        's': summary,
        'fu': followUpAt?.toUtc(),
      },
    );
    final saved = _interaction(rows.first, userId);
    await _db.execute(
      Sql.named(
        'UPDATE applications SET updated_at=now()'
        ' WHERE id=@id AND user_id=@u',
      ),
      parameters: {'id': applicationId, 'u': userId},
    );
    return saved;
  }

  Future<Interaction> setFollowUp(
    String userId,
    String interactionId,
    DateTime followUpAt,
  ) async {
    final rows = await _db.execute(
      Sql.named(
        'SELECT * FROM interactions WHERE id=@id AND user_id=@u',
      ),
      parameters: {'id': interactionId, 'u': userId},
    );
    if (rows.isEmpty) throw NotFound('interaction');
    final current = _interaction(rows.first, userId);
    _check([
      Validators.followUpAt(followUpAt.toUtc(), current.happenedAt),
    ]);
    final updated = await _db.execute(
      Sql.named(
        'UPDATE interactions SET follow_up_at=@fu'
        ' WHERE id=@id AND user_id=@u RETURNING *',
      ),
      parameters: {
        'fu': followUpAt.toUtc(),
        'id': interactionId,
        'u': userId,
      },
    );
    return _interaction(updated.first, userId);
  }

  // -- derived ------------------------------------------------------------

  /// Applications needing attention: stale by stage threshold (touch =
  /// `updated_at`) plus ones with overdue follow-ups. Each entry carries the
  /// application JSON plus a `stale_reason`.
  Future<List<Map<String, dynamic>>> staleFollowups(
    String userId, {
    int limit = 50,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now().toUtc()).toUtc();
    final rows = await _db.execute(
      Sql.named(
        'SELECT * FROM applications WHERE user_id=@u AND archived_at IS NULL'
        ' AND ((stage=\'applied\' AND updated_at < @at::timestamptz - interval \'7 days\')'
        '  OR (stage=\'screening\' AND updated_at < @at::timestamptz - interval \'5 days\')'
        '  OR (stage=\'interview\' AND updated_at < @at::timestamptz - interval \'3 days\')'
        '  OR (stage=\'offer\' AND updated_at < @at::timestamptz - interval \'7 days\'))'
        ' ORDER BY updated_at ASC LIMIT @lim::int',
      ),
      parameters: {'u': userId, 'at': at, 'lim': _limit(limit)},
    );
    final out = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final app = _app(r, userId);
      final days = at.difference(app.updatedAt!).inDays;
      out[app.id] = {
        'application': app.toJson(),
        'stale_reason': 'stage:${app.stage.name}:${days}d without update',
      };
    }
    final overdue = await _db.execute(
      Sql.named(
        'SELECT a.* FROM applications a JOIN interactions i'
        ' ON i.application_id=a.id'
        ' WHERE a.user_id=@u AND a.archived_at IS NULL'
        ' AND i.user_id=@u AND i.follow_up_at IS NOT NULL'
        ' AND i.follow_up_at < @at'
        ' ORDER BY i.follow_up_at ASC LIMIT @lim::int',
      ),
      parameters: {'u': userId, 'at': at, 'lim': _limit(limit)},
    );
    for (final r in overdue) {
      final app = _app(r, userId);
      out.putIfAbsent(
        app.id,
        () => {
          'application': app.toJson(),
          'stale_reason': 'followup_overdue',
        },
      );
    }
    final list = out.values.toList();
    return list.length > _limit(limit)
        ? list.sublist(0, _limit(limit))
        : list;
  }

  /// Computed stats — every metric from the DB, never invented.
  Future<Map<String, dynamic>> stats(String userId, {DateTime? now}) async {
    final at = (now ?? DateTime.now().toUtc()).toUtc();
    final byStage = await _db.execute(
      Sql.named(
        'SELECT stage, count(*)::int AS n FROM applications'
        ' WHERE user_id=@u AND archived_at IS NULL GROUP BY stage',
      ),
      parameters: {'u': userId},
    );
    final counts = <String, int>{};
    var total = 0;
    for (final r in byStage) {
      final m = r.toColumnMap();
      counts[m['stage'] as String] = m['n'] as int;
      total += m['n'] as int;
    }
    final stale = await staleFollowups(userId, limit: 1000, now: at);
    final contacts = await _db.execute(
      Sql.named('SELECT count(*)::int AS n FROM contacts WHERE user_id=@u'),
      parameters: {'u': userId},
    );
    final upcoming = await _db.execute(
      Sql.named(
        'SELECT count(*)::int AS n FROM interactions'
        ' WHERE user_id=@u AND follow_up_at IS NOT NULL'
        ' AND follow_up_at >= @at::timestamptz AND follow_up_at < @at::timestamptz + interval \'14 days\'',
      ),
      parameters: {'u': userId, 'at': at},
    );
    return {
      'total_active': total,
      'by_stage': counts,
      'stale_count': stale.length,
      'total_contacts': (contacts.first.toColumnMap()['n'] as int),
      'upcoming_followups_14d': (upcoming.first.toColumnMap()['n'] as int),
    };
  }

  /// Deletes ALL rows of [userId] (interactions → contacts → applications).
  /// Auth-user removal itself is a Neon console step (documented in README).
  /// Table names are fixed literals (never user input) — one statement each
  /// so every query stays fully parameterized.
  Future<Map<String, int>> deleteAccount(String userId) async {    return _db.runTx((tx) async {
      final interactions = await tx.execute(
        Sql.named('DELETE FROM interactions WHERE user_id=@u'),
        parameters: {'u': userId},
      );
      final contacts = await tx.execute(
        Sql.named('DELETE FROM contacts WHERE user_id=@u'),
        parameters: {'u': userId},
      );
      final applications = await tx.execute(
        Sql.named('DELETE FROM applications WHERE user_id=@u'),
        parameters: {'u': userId},
      );
      return {
        'interactions': interactions.affectedRows,
        'contacts': contacts.affectedRows,
        'applications': applications.affectedRows,
      };
    });
  }

  // -- demo accounts (ephemeral, PLAN decision 14) ------------------------

  /// Seeds the V2 demo dataset for [userId] with fresh ids. Same content as
  /// db/migrations/V2__seed_demo.sql, parameterized for ephemeral users.
  Future<void> seedDemo(String userId) async {
    await _db.runTx((tx) async {
      Future<String> app(
        String company,
        String role,
        String source,
        String stage,
        int appliedDaysAgo, [
        int? smin,
        int? smax,
        String? notes,
      ]) async {
        final rows = await tx.execute(
          Sql.named(
            'INSERT INTO applications (user_id, company, role, source, stage,'
            ' applied_at, salary_min, salary_max, notes)'
            " VALUES (@u,@c,@r,@s,@st, now() - ((@ago::text) || ' days')::interval,"
            ' @smin,@smax,@n) RETURNING id',
          ),
          parameters: {
            'u': userId,
            'c': company,
            'r': role,
            's': source,
            'st': stage,
            'ago': appliedDaysAgo,
            'smin': smin,
            'smax': smax,
            'n': notes,
          },
        );
        return (rows.first.toColumnMap()['id'] as Object).toString();
      }

      Future<void> contact(
        String? appId,
        String name,
        String role,
        String company,
        Map<String, String> channels,
      ) => tx.execute(
        Sql.named(
          'INSERT INTO contacts (user_id, application_id, name, role, company, channels)'
          ' VALUES (@u,@app,@n,@r,@c,@ch)',
        ),
        parameters: {
          'u': userId,
          'app': appId,
          'n': name,
          'r': role,
          'c': company,
          'ch': channels,
        },
      );

      Future<void> interaction(
        String appId,
        String type,
        int happenedDaysAgo,
        String summary, [
        int? followUpInDays,
      ]) => tx.execute(
        Sql.named(
          'INSERT INTO interactions (user_id, application_id, type, happened_at, summary, follow_up_at)'
          " VALUES (@u,@app,@t, now() - ((@ago::text) || ' days')::interval, @s,"
          " CASE WHEN @fu::int IS NULL THEN NULL ELSE now() + (((@fu::text)) || ' days')::interval END)",
        ),
        parameters: {
          'u': userId,
          'app': appId,
          't': type,
          'ago': happenedDaysAgo,
          's': summary,
          'fu': followUpInDays,
        },
      );

      final acme = await app('Acme Corp', 'Backend Engineer', 'referral',
          'applied', 9, 80000, 110000, 'Demo data: met at meetup.');
      final globex = await app('Globex', 'Flutter Developer', 'job board',
          'interview', 4, 90000, 120000, 'Demo data: on-site next week.');
      final initech = await app('Initech', 'Full-stack Engineer',
          'company site', 'screening', 2, null, null, 'Demo data: recruiter call done.');
      final umbrella = await app('Umbrella', 'DevOps Engineer', 'linkedin',
          'offer', 1, 100000, 130000, 'Demo data: offer received.');
      await app('Stark Industries', 'Mobile Engineer', 'referral', 'saved',
          30, null, null, 'Demo data: interesting but not urgent.');
      await app('Wayne Enterprises', 'QA Engineer', 'job board', 'rejected',
          20, null, null, 'Demo data: rejected after screening.');

      await contact(acme, 'Ada Example', 'Hiring Manager', 'Acme Corp',
          {'email': 'ada@example.com'});
      await contact(globex, 'Bob Sample', 'Engineering Lead', 'Globex',
          {'email': 'bob@example.com'});
      await contact(null, 'Cara Demo', 'Recruiter', 'Tech Search',
          {'email': 'cara@example.com'});

      await interaction(acme, 'email', 9,
          'Demo data: application sent with referral.', -2);
      await interaction(globex, 'call', 4,
          'Demo data: screening call, positive signal.', 2);
      await interaction(initech, 'call', 2,
          'Demo data: recruiter screen done.');
      await interaction(umbrella, 'meeting', 1,
          'Demo data: final round, offer received.', 6);
    });
  }

  /// Stores a demo bearer (sha256 [tokenHash]) for [userId].
  Future<void> createDemoSession(
    String userId,
    String tokenHash,
    DateTime expiresAt,
  ) async {
    await _db.execute(
      Sql.named(
        'INSERT INTO demo_sessions (token_hash, user_id, expires_at)'
        ' VALUES (@h,@u,@e)',
      ),
      parameters: {'h': tokenHash, 'u': userId, 'e': expiresAt.toUtc()},
    );
  }

  /// Resolves a demo bearer to its user, or null (unknown/expired).
  /// Expired sessions are swept on every call (TTL cleanup).
  Future<String?> resolveDemoUser(String tokenHash) async {
    await _db.execute(
      Sql.named('DELETE FROM demo_sessions WHERE expires_at < now()'),
    );
    final rows = await _db.execute(
      Sql.named('SELECT user_id FROM demo_sessions WHERE token_hash=@h'),
      parameters: {'h': tokenHash},
    );
    if (rows.isEmpty) return null;
    return rows.first.toColumnMap()['user_id'] as String;
  }

  // -- mapping (defense-in-depth ownership check on every decode) ---------

  Application _app(ResultRow r, String userId) {
    final app = Application.fromJson(_json(r));
    requireOwner(callerSub: userId, rowUserId: app.userId);
    return app;
  }

  Contact _contact(ResultRow r, String userId) {
    final c = Contact.fromJson(_json(r));
    requireOwner(callerSub: userId, rowUserId: c.userId);
    return c;
  }

  Interaction _interaction(ResultRow r, String userId) {
    final i = Interaction.fromJson(_json(r));
    requireOwner(callerSub: userId, rowUserId: i.userId);
    return i;
  }

  Map<String, dynamic> _json(ResultRow r) =>
      Map<String, dynamic>.from(r.toColumnMap());
}

void _check(List<String?> violations) {
  final msgs = violations.whereType<String>().toList();
  if (msgs.isNotEmpty) throw InputError(msgs.join('; '));
}

int _limit(int v) => v < 1 ? 1 : (v > 100 ? 100 : v);
