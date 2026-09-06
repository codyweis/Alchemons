import 'dart:math';

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadNatures);

  test('wild Alchemons roll zero to two distinct compatible Natures', () {
    final rng = Random(71203);
    final counts = [0, 0, 0];
    var rareSlots = 0;
    var totalSlots = 0;

    for (var i = 0; i < 100000; i++) {
      final rolled = NatureCatalogWeighted.rollWildSlots(rng);
      counts[rolled.length]++;
      expect(rolled.map((n) => n.id).toSet().length, rolled.length);
      final ids = rolled.map((n) => n.id).toSet();
      expect(ids.containsAll({'Homotypic', 'Heterotypic'}), isFalse);
      expect(ids.containsAll({'Sympatric', 'Conspecific'}), isFalse);
      rareSlots += rolled.where((n) => n.tier == 'Rare').length;
      totalSlots += rolled.length;
    }

    expect(counts[0] / 100000, closeTo(.15, .01));
    expect(counts[1] / 100000, closeTo(.70, .01));
    expect(counts[2] / 100000, closeTo(.15, .01));
    expect(totalSlots / 100000, closeTo(1.0, .02));
    expect(rareSlots / totalSlots, closeTo(.10, .01));
  });

  test('elite rolls guarantee a Nature and favor two slots', () {
    final rng = Random(8891);
    var two = 0;
    for (var i = 0; i < 20000; i++) {
      final rolled = NatureCatalogWeighted.rollWildSlots(rng, elite: true);
      expect(rolled, isNotEmpty);
      if (rolled.length == 2) two++;
    }
    expect(two / 20000, closeTo(.30, .02));
  });

  test('two stat Natures combine additively without a rating cap', () {
    expect(
      AlchemonStatSystem.natureMultiplier('Hyperbolic', 'speed', 'Frenetic'),
      closeTo(1.25, .000001),
    );
    expect(
      AlchemonStatSystem.natureMultiplier(
        'Hyperbolic',
        'intelligence',
        'Frenetic',
      ),
      closeTo(.95, .000001),
    );
    expect(AlchemonStatSystem.displayRating(12.5), 1250);
    expect(
      AlchemonStatSystem.combatOvercapProgress(12),
      greaterThan(AlchemonStatSystem.combatOvercapProgress(9)),
    );
  });

  test('utility Natures each perform one job', () {
    final utilities = NatureCatalog.rollable.where((n) => n.tier == 'Utility');
    for (final nature in utilities) {
      expect(
        nature.effect.modifiers.length,
        1,
        reason: '${nature.id} should have one utility effect',
      );
    }
  });
}
