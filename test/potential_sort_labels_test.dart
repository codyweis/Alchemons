import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Potential sort labels keep only the prefix lowercase', () {
    expect(SortBy.potentialSpeed.shortLabel, 'pSPD');
    expect(SortBy.potentialIntelligence.shortLabel, 'pINT');
    expect(SortBy.potentialStrength.shortLabel, 'pSTR');
    expect(SortBy.potentialBeauty.shortLabel, 'pBEA');
  });
}
