// THE ATHANOR'S TRAILS, as the ground answering a creature. They were
// prints alone, gone in five seconds, and residents mostly stand, so a trail
// was hard to see at all. Now a still creature stands on a patch of its
// trail that spreads and stays, a print lasts long enough for a stroll to
// leave a path, and what is laid never outgrows the atlases sized for it.

import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:alchemons/widgets/fx/cosmetics/trail_art.dart';
import 'package:flutter_test/flutter_test.dart';

int _laid(TrailPrints t, double time, {bool onGrass = false}) {
  final ground = CosmeticAtlas(100000), light = CosmeticAtlas(100000);
  if (onGrass) {
    t.paintSurface(ground, light, time);
  } else {
    t.paint(ground, light, time);
  }
  return ground.length + light.length;
}

void main() {
  for (final style in TrailStyle.values) {
    group(style.title, () {
      test('standing still, the ground under it takes the trail', () {
        final t = TrailPrints(style);
        expect(t.isEmpty, isTrue);
        t.stand(100, 50, 10, size: 12);
        final early = _laid(t, 10.2);
        final full = _laid(t, 10 + TrailPrints.patchGrow);
        expect(full, greaterThan(early), reason: 'it spreads');
        // And it stays while it stands, however long.
        expect(t.aliveAt(10 + 600), isTrue);
        expect(_laid(t, 10 + 600), greaterThan(0));
      });

      test('walked off, the patch fades and is gone', () {
        final t = TrailPrints(style);
        t.stand(100, 50, 10, size: 12);
        t.leave(15);
        expect(t.aliveAt(15 + t.patchFade * 0.5), isTrue);
        expect(t.aliveAt(15 + t.patchFade + 0.1), isFalse);
        expect(_laid(t, 15 + t.patchFade + 0.1), 0);
      });

      test('shifting along begins a new patch and leaves the old', () {
        final t = TrailPrints(style);
        t.stand(100, 50, 10, size: 12);
        // A nudge is the same patch...
        t.stand(104, 50, 11, size: 12);
        expect(t.aliveAt(11 + 600), isTrue);
        // ...a move to new ground is a new one, the old one fading.
        t.stand(160, 50, 14, size: 12);
        expect(_laid(t, 14.5), greaterThan(_laid(TrailPrints(style), 14.5)));
      });

      test('a print lasts long enough for a stroll to leave a path', () {
        final t = TrailPrints(style);
        t.step(100, 50, 10, size: 12);
        expect(t.life, greaterThanOrEqualTo(10));
        expect(t.aliveAt(10 + t.life - 0.5), isTrue);
        expect(t.aliveAt(10 + t.life + 0.1), isFalse);
      });

      test('never lays more than the atlases are sized for', () {
        final t = TrailPrints(style);
        // A long walk filling every print slot, then a stand and a move:
        // two patches and a full ring of prints at once.
        // Born close together, so every print's grains are in the air at
        // once: the most light a trail can ask for.
        for (var i = 0; i < TrailPrints.defaultCapacity * 2; i++) {
          t.step(i * 4.0, 50, 19 + i * 0.02, size: 12);
        }
        t.stand(300, 50, 20, size: 12);
        t.stand(400, 50, 22, size: 12);
        var worstGround = 0, worstGrass = 0, worstLight = 0, worstGlint = 0;
        for (var time = 20.0; time < 30; time += 0.13) {
          final g = CosmeticAtlas(100000), l = CosmeticAtlas(100000);
          t.paint(g, l, time);
          if (g.length > worstGround) worstGround = g.length;
          if (l.length > worstLight) worstLight = l.length;
          final gg = CosmeticAtlas(100000), gl = CosmeticAtlas(100000);
          t.paintSurface(gg, gl, time);
          if (gg.length > worstGrass) worstGrass = gg.length;
          if (gl.length > worstGlint) worstGlint = gl.length;
        }
        expect(worstGround, lessThanOrEqualTo(TrailPrints.groundEntries));
        expect(worstLight, lessThanOrEqualTo(TrailPrints.lightEntries));
        expect(worstGrass, lessThanOrEqualTo(TrailPrints.grassEntries));
        expect(worstGlint, lessThanOrEqualTo(TrailPrints.grassLightEntries));
      });
    });
  }
}
