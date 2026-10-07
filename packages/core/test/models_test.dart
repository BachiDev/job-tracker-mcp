import 'package:job_tracker_core/job_tracker_core.dart';
import 'package:test/test.dart';

void main() {
  group('Application model', () {
    test('json roundtrip preserves fields', () {
      final app = Application(
        id: 'a1',
        userId: 'u1',
        company: 'Acme',
        role: 'Engineer',
        stage: AppStage.interview,
        source: 'referral',
        appliedAt: DateTime.utc(2026, 9, 20),
        salaryMin: 80000,
        salaryMax: 120000,
        link: 'https://example.com/job',
        notes: 'nice team',
      );
      final back = Application.fromJson(app.toJson());
      expect(back.id, 'a1');
      expect(back.userId, 'u1');
      expect(back.stage, AppStage.interview);
      expect(back.salaryMin, 80000);
      expect(back.archived, isFalse);
    });

    test('archived flag follows archivedAt', () {
      final app = Application(
        id: 'a1',
        userId: 'u1',
        company: 'Acme',
        role: 'Engineer',
        stage: AppStage.rejected,
        archivedAt: DateTime.utc(2026, 10, 1),
      );
      expect(app.archived, isTrue);
      expect(Application.fromJson(app.toJson()).archived, isTrue);
    });

    test('unknown stage falls back to saved', () {
      final app = Application.fromJson({
        'id': 'a1',
        'user_id': 'u1',
        'company': 'Acme',
        'role': 'Engineer',
        'stage': 'nope',
      });
      expect(app.stage, AppStage.saved);
    });
  });

  group('draft template', () {
    test('grounded in real context, labeled unsent', () {
      final text = buildDraft(
        app: Application(
          id: 'a1',
          userId: 'u1',
          company: 'Acme',
          role: 'Engineer',
          stage: AppStage.interview,
        ),
        recent: [
          Interaction(
            id: 'i1',
            userId: 'u1',
            applicationId: 'a1',
            type: 'call',
            happenedAt: DateTime.utc(2026, 10, 5),
            summary: 'screening call',
          ),
        ],
        tone: 'short',
      );
      expect(text, contains('draft — nothing was sent'));
      expect(text, contains('Acme'));
      expect(text, contains('screening call'));
      expect(text, contains('short'));
    });

    test('works without history or tone', () {
      final text = buildDraft(
        app: Application(
          id: 'a1',
          userId: 'u1',
          company: 'Acme',
          role: 'Engineer',
          stage: AppStage.saved,
        ),
        recent: const [],
      );
      expect(text, contains('neutral'));
    });
  });

  group('Contact model', () {
    test('json roundtrip with channels', () {
      final c = Contact(
        id: 'c1',
        userId: 'u1',
        name: 'Jane',
        applicationId: 'a1',
        role: 'Hiring manager',
        channels: {'email': 'j@example.com'},
      );
      final back = Contact.fromJson(c.toJson());
      expect(back.channels, {'email': 'j@example.com'});
      expect(back.applicationId, 'a1');
    });

    test('missing channels default to empty', () {
      final c = Contact.fromJson({
        'id': 'c1',
        'user_id': 'u1',
        'name': 'Jane',
      });
      expect(c.channels, isEmpty);
    });

    test('accepts DateTime objects (postgres driver rows)', () {
      final at = DateTime.utc(2026, 9, 20);
      final app = Application.fromJson({
        'id': 'a1',
        'user_id': 'u1',
        'company': 'Acme',
        'role': 'Engineer',
        'stage': 'applied',
        'applied_at': at,
        'created_at': at,
      });
      expect(app.appliedAt, at);
      final i = Interaction.fromJson({
        'id': 'i1',
        'user_id': 'u1',
        'application_id': 'a1',
        'type': 'note',
        'happened_at': at,
      });
      expect(i.happenedAt, at);
    });
  });

  group('Interaction model', () {
    test('json roundtrip', () {
      final i = Interaction(
        id: 'i1',
        userId: 'u1',
        applicationId: 'a1',
        type: 'call',
        happenedAt: DateTime.utc(2026, 10, 5, 12),
        summary: 'screening call',
        followUpAt: DateTime.utc(2026, 10, 8),
      );
      final back = Interaction.fromJson(i.toJson());
      expect(back.type, 'call');
      expect(back.followUpAt, DateTime.utc(2026, 10, 8));
    });
  });
}
