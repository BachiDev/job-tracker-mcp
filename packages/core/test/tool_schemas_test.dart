import 'package:job_tracker_core/job_tracker_core.dart';
import 'package:test/test.dart';

void main() {
  group('ownership', () {
    test('same user passes', () {
      expect(
        () => requireOwner(callerSub: 'u1', rowUserId: 'u1'),
        returnsNormally,
      );
    });

    test('cross-user access throws', () {
      expect(
        () => requireOwner(callerSub: 'attacker', rowUserId: 'victim'),
        throwsA(isA<CrossUserAccess>()),
      );
    });

    test('empty caller never matches a real row', () {
      expect(
        () => requireOwner(callerSub: '', rowUserId: 'u1'),
        throwsA(isA<CrossUserAccess>()),
      );
    });
  });

  group('tool surface', () {
    test('has 14 tools: 7 reads, 6 gated writes, 1 draft', () {
      expect(toolDefs.length, 14);
      final gated = toolDefs.where((t) => t.requiresConfirmation);
      expect(gated.length, 6);
      expect(findTool('draft_followup')?.requiresConfirmation, isFalse);
    });

    test('every write requires confirmed:true', () {
      for (final t in toolDefs.where((t) => t.requiresConfirmation)) {
        final props =
            t.inputSchema['properties'] as Map<String, dynamic>;
        expect(props.containsKey('confirmed'), isTrue, reason: t.name);
        final required =
            (t.inputSchema['required'] as List?) ?? [];
        expect(required, contains('confirmed'), reason: t.name);
      }
    });

    test('no delete tool, no send tool', () {
      final names = toolDefs.map((t) => t.name).toSet();
      expect(names.any((n) => n.contains('delete')), isFalse);
      expect(names.any((n) => n.contains('send')), isFalse);
      expect(names, contains('archive_application'));
      expect(names, contains('draft_followup'));
    });

    test('schemas are well-formed objects', () {
      for (final t in toolDefs) {
        expect(t.inputSchema['type'], 'object', reason: t.name);
        final props =
            t.inputSchema['properties'] as Map<String, dynamic>;
        for (final entry in props.entries) {
          expect(
            (entry.value as Map)['type'],
            isNotNull,
            reason: '${t.name}.${entry.key}',
          );
        }
      }
    });

    test('findTool resolves and misses', () {
      expect(findTool('stats')?.name, 'stats');
      expect(findTool('nope'), isNull);
    });

    test('toJson exposes gating flag', () {
      final j = findTool('add_application')!.toJson();
      expect(j['requiresConfirmation'], isTrue);
      expect(findTool('stats')!.toJson()['requiresConfirmation'], isFalse);
    });
  });
}
