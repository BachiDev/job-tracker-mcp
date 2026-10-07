import 'package:test/test.dart';

import 'package:server/mcp_tools.dart';

void main() {
  group('confirm gating (pure)', () {
    test('confirmed:true passes', () {
      expect(missingConfirmation({'confirmed': true}), isNull);
    });

    test('missing/false confirmed refuses with guidance', () {
      expect(missingConfirmation({}), contains('confirmed:true'));
      expect(missingConfirmation({'confirmed': false}), contains('Refused'));
      expect(missingConfirmation({'confirmed': 'yes'}), isNotNull);
    });
  });
}
