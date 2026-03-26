import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Purity stat bonuses', () {
    test('elementally pure specimens gain beauty only', () {
      final purity = classifyPurityFromLineages(
        elementLineage: const {'Water': 3},
        speciesLineage: const {'Let': 2, 'Pip': 1},
      );
      final bonus = purityStatBonusForStatus(purity);

      expect(purity.label, 'Elementally Pure');
      expect(bonus.beauty, 0.25);
      expect(bonus.strength, 0.0);
      expect(bonus.intelligence, 0.0);
    });

    test('species pure specimens gain strength only', () {
      final purity = classifyPurityFromLineages(
        elementLineage: const {'Water': 2, 'Fire': 1},
        speciesLineage: const {'Let': 4},
      );
      final bonus = purityStatBonusForStatus(purity);

      expect(purity.label, 'Species Pure');
      expect(bonus.beauty, 0.0);
      expect(bonus.strength, 0.25);
      expect(bonus.intelligence, 0.0);
    });

    test('fully pure specimens gain beauty strength and intelligence', () {
      final purity = classifyPurityFromLineages(
        elementLineage: const {'Water': 5},
        speciesLineage: const {'Let': 5},
      );
      final bonus = purityStatBonusForStatus(purity);

      expect(purity.label, 'Pure');
      expect(bonus.beauty, 0.25);
      expect(bonus.strength, 0.25);
      expect(bonus.intelligence, 0.25);
    });
  });
}
