import 'package:job_tracker_core/job_tracker_core.dart';
import 'package:test/test.dart';

void main() {
  group('validators (extended)', () {
    test('summary/source/contactName caps', () {
      expect(Validators.summary('x' * 5001), isNotNull);
      expect(Validators.summary('ok'), isNull);
      expect(Validators.source('x' * 101), isNotNull);
      expect(Validators.source(null), isNull);
      expect(Validators.contactName('  '), isNotNull);
      expect(Validators.contactName('Jane'), isNull);
    });

    test('interactionType fixed set', () {
      expect(Validators.interactionType('call'), isNull);
      expect(Validators.interactionType('telepathy'), isNotNull);
      expect(Validators.interactionType(null), isNotNull);
    });

    test('link must be absolute http(s)', () {
      expect(Validators.link(null), isNull);
      expect(Validators.link(''), isNull);
      expect(Validators.link('https://example.com/job'), isNull);
      expect(Validators.link('not a url'), isNotNull);
      expect(Validators.link('ftp://example.com'), isNotNull);
      expect(Validators.link('/relative/path'), isNotNull);
    });

    test('salary bounds', () {
      expect(Validators.salary(null, null), isNull);
      expect(Validators.salary(-1, null), isNotNull);
      expect(Validators.salary(null, -5), isNotNull);
      expect(Validators.salary(120000, 80000), isNotNull);
      expect(Validators.salary(80000, 120000), isNull);
      expect(Validators.salary(80000, 80000), isNull);
    });

    test('appliedAt not in future', () {
      final now = DateTime.utc(2026, 10, 7);
      expect(Validators.appliedAt(null, now), isNull);
      expect(
        Validators.appliedAt(DateTime.utc(2026, 10, 6), now),
        isNull,
      );
      expect(
        Validators.appliedAt(DateTime.utc(2026, 10, 8), now),
        isNotNull,
      );
    });

    test('followUpAt after happenedAt', () {
      final happened = DateTime.utc(2026, 10, 5);
      expect(Validators.followUpAt(null, happened), isNull);
      expect(
        Validators.followUpAt(DateTime.utc(2026, 10, 6), happened),
        isNull,
      );
      expect(
        Validators.followUpAt(happened, happened),
        isNotNull,
      );
    });

    test('channels caps', () {
      expect(Validators.channels(null), isNull);
      expect(Validators.channels({}), isNull);
      expect(
        Validators.channels({'email': 'a@b.c'}),
        isNull,
      );
      expect(
        Validators.channels({for (var i = 0; i < 21; i++) 'k$i': 'v'}),
        isNotNull,
      );
      expect(Validators.channels({'x' * 51: 'v'}), isNotNull);
      expect(Validators.channels({'k': 'v' * 501}), isNotNull);
    });
  });
}
