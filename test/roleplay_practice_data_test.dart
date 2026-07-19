import 'package:flutter_test/flutter_test.dart';

import 'package:credit_calc/utils/roleplay_practice_data.dart';

void main() {
  group('RoleplayPracticeData.normalize', () {
    test('rinomina la seconda Rate da pagare in Rate totali', () {
      final out = RoleplayPracticeData.normalize([
        {'label': 'Rate da pagare', 'value': '1'},
        {'label': 'Rate pagate', 'value': '12'},
        {'label': 'Rate da pagare', 'value': '36'},
      ]);

      expect(out.map((e) => e['label']).toList(), [
        'Rate da pagare',
        'Rate pagate',
        'Rate totali',
      ]);
      expect(out.last['value'], '36');
    });

    test('non tocca etichette già corrette', () {
      final out = RoleplayPracticeData.normalize([
        {'label': 'Rate da pagare', 'value': '1'},
        {'label': 'Rate pagate', 'value': '12'},
        {'label': 'Rate totali', 'value': '36'},
      ]);

      expect(out.map((e) => e['label']).toList(), [
        'Rate da pagare',
        'Rate pagate',
        'Rate totali',
      ]);
    });
  });
}
