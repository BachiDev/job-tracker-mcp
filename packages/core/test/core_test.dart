import 'package:job_tracker_core/job_tracker_core.dart';
import 'package:test/test.dart';

void main() {
  group('stage machine (Phase 0 smoke)', () {
    test('has 8 fixed stages', () {
      expect(AppStage.values.length, 8);
    });

    test('parses known stages, rejects unknown', () {
      expect(parseStage('applied'), AppStage.applied);
      expect(parseStage('nope'), isNull);
    });

    test('stale computation follows PLAN defaults', () {
      final now = DateTime.utc(2026, 10, 7);
      expect(
        isStale(AppStage.applied, now.subtract(const Duration(days: 8)), now),
        isTrue,
      );
      expect(
        isStale(AppStage.applied, now.subtract(const Duration(days: 3)), now),
        isFalse,
      );
      expect(
        isStale(AppStage.saved, now.subtract(const Duration(days: 365)), now),
        isFalse,
      );
    });
  });

  group('validators (Phase 0 smoke)', () {
    test('company/role required', () {
      expect(Validators.company('  '), isNotNull);
      expect(Validators.company('Acme'), isNull);
      expect(Validators.role(''), isNotNull);
      expect(Validators.role('Engineer'), isNull);
    });
  });
}
