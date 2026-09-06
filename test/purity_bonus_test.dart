import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Purity lineage classification', () {
    test('elementally pure specimens are descriptive only', () {
      final purity = classifyPurityFromLineages(
        elementLineage: const {'Water': 3},
        speciesLineage: const {'Let': 2, 'Pip': 1},
      );

      expect(purity.label, 'Elementally Pure');
      expect(purity.description, contains('species line is mixed'));
    });

    test('species pure specimens are classified independently', () {
      final purity = classifyPurityFromLineages(
        elementLineage: const {'Water': 2, 'Fire': 1},
        speciesLineage: const {'Let': 4},
      );

      expect(purity.label, 'Species Pure');
      expect(purity.isPure, isFalse);
    });

    test(
      'fully pure specimens retain lineage identity without stat bonuses',
      () {
        final purity = classifyPurityFromLineages(
          elementLineage: const {'Water': 5},
          speciesLineage: const {'Let': 5},
        );

        expect(purity.label, 'Pure');
        expect(purity.isPure, isTrue);
        expect(purity.description, isNot(contains('stat')));
      },
    );
  });
}
