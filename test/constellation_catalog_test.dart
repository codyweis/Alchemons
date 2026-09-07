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

    test('wild Potential scanner follows the owned Potential analyzer', () {
      expect(ConstellationCatalog.wildPotentialAnalyzer.prerequisites, [
        ConstellationCatalog.potentialAnalyzer.id,
      ]);
      expect(
        ConstellationCatalog.wildPotentialAnalyzer.canUnlock({
          ConstellationCatalog.geneAnalyzer.id,
        }),
        isFalse,
      );
      expect(
        ConstellationCatalog.wildPotentialAnalyzer.canUnlock({
          ConstellationCatalog.potentialAnalyzer.id,
        }),
        isTrue,
      );
    });
  });
}
