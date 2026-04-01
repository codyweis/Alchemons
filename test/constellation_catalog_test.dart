import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConstellationCatalog breeder progression', () {
    test('gene analyzer requires lineage analyzer first', () {
      expect(
        ConstellationCatalog.geneAnalyzer.prerequisites,
        contains(ConstellationCatalog.lineageAnalyzer.id),
      );

      expect(
        ConstellationCatalog.geneAnalyzer.canUnlock({
          ConstellationCatalog.crossSpeciesLineage.id,
        }),
        isFalse,
      );

      expect(
        ConstellationCatalog.geneAnalyzer.canUnlock({
          ConstellationCatalog.crossSpeciesLineage.id,
          ConstellationCatalog.lineageAnalyzer.id,
        }),
        isTrue,
      );
    });
  });
}
