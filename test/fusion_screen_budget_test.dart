// The fusion chamber at rest: what one idle frame asks of the UI thread and
// of the GPU, with the chambers empty, with one specimen in, and with two.
//
// Budget tests, not golden tests. They do not care what it looks like; they
// care that nothing on this screen goes back to re-recording the whole stage
// every frame for the sake of the knot turning between the pair, or to
// drawing the background a circle per mote. Before 2026-10-01 an idle frame
// with both chambers filled re-recorded 120 render objects, rebuilt 11
// widgets and issued 158 draws (7 blurred); with them empty, 83, 4 and 133
// (4). The one-stage chamber of 2026-10-02 has no glows to blur at all.
//
// For a picture of the screen, see fusion_preview_test.dart: painting into
// the census below disturbs the layers a screenshot would be read from.
//
// Widget tests never rasterise, so the GPU side is counted rather than timed:
// the whole tree is painted once more into a canvas that tallies what it is
// asked to draw.
//
//   flutter test test/fusion_screen_budget_test.dart
//


import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Tallies what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurred = 0;

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (n, e) => n + e.value);

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && (a.maskFilter != null || a.imageFilter != null)) {
        blurred++;
      }
    }
    switch (key) {
      case 'getSaveCount':
        return 1;
      case 'getLocalClipBounds' || 'getDestinationClipBounds':
        return Rect.largest;
      case 'getTransform':
        return Matrix4.identity().storage;
    }
    return null;
  }
}

/// Paints a tree straight into a [_CensusCanvas]: every child, through every
/// repaint boundary, without touching the real layer tree.
class _CensusContext extends PaintingContext {
  _CensusContext(this.census, this.layers)
    : super(ContainerLayer(), Rect.largest);

  final _CensusCanvas census;
  final Map<String, int> layers;

  @override
  Canvas get canvas => census;

  @override
  void paintChild(RenderObject child, Offset offset) =>
      child.paint(this, offset);

  @override
  void addLayer(Layer layer) => _count(layer);

  @override
  void pushLayer(
    ContainerLayer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    _count(childLayer);
    painter(this, offset);
  }

  void _count(Layer l) {
    final k = l.runtimeType.toString();
    layers[k] = (layers[k] ?? 0) + 1;
  }
}

class _Frame {
  _Frame(this.painted, this.rebuilt, this.census, this.layers);

  /// Render objects re-recorded in one idle frame.
  final int painted;

  /// Widgets rebuilt in one idle frame.
  final int rebuilt;
  final _CensusCanvas census;
  final Map<String, int> layers;

  /// Layers the GPU draws into offscreen and composites back.
  int get offscreen =>
      (layers['OpacityLayer'] ?? 0) +
      (layers['ColorFilterLayer'] ?? 0) +
      (layers['ShaderMaskLayer'] ?? 0) +
      (layers['BackdropFilterLayer'] ?? 0) +
      (layers['ImageFilterLayer'] ?? 0) +
      (census.counts['saveLayer'] ?? 0);

  @override
  String toString() =>
      'painted $painted, rebuilt $rebuilt, draws ${census.draws}, '
      'blurred ${census.blurred}, offscreen $offscreen\n'
      '  ${census.counts}\n  $layers';
}

enum _Chambers {
  empty('both chambers empty'),
  one('one specimen in'),
  both('two specimens in');

  const _Chambers(this.label);
  final String label;
}

void main() {
  Creature horn(String id, String name, String type, String sheet) => Creature(
    id: id,
    name: name,
    types: [type],
    rarity: 'Rare',
    description: 'budget',
    image: 'test.png',
    mutationFamily: 'Horn',
    spriteData: SpriteData(
      frameWidth: 1200,
      frameHeight: 1200,
      totalFrames: 4,
      frameDurationMs: 90,
      rows: 1,
      spriteSheetPath: 'creatures/rare/$sheet',
    ),
  );

  Future<_Frame> measure(WidgetTester tester, _Chambers chambers) async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final catalog = CreatureCatalog.fromList([
      horn('HOR01', 'Firehorn', 'Fire', 'HOR01_firehorn_spritesheet.png'),
      horn('HOR02', 'Waterhorn', 'Water', 'HOR02_waterhorn_spritesheet.png'),
    ]);
    CreatureInstance? a, b;
    late ConstellationEffectsService constellations;
    await tester.runAsync(() async {
      // Most specimens carry a tint: a hue shift and a saturation change.
      await db.creatureDao.insertInstance(
        instanceId: 'a',
        baseId: 'HOR01',
        level: 9,
        genetics: const {'tinting': 'warm'},
      );
      await db.creatureDao.insertInstance(
        instanceId: 'b',
        baseId: 'HOR02',
        level: 9,
        genetics: const {'tinting': 'cool'},
      );
      a = await db.creatureDao.getInstance('a');
      b = await db.creatureDao.getInstance('b');
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<StaminaService>.value(value: StaminaService(db)),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: constellations,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: ParticleBackgroundScaffold(
            body: BreedingTab(
              discoveredCreatures: const [],
              onBreedingComplete: () {},
              debugParent1: chambers == _Chambers.empty ? null : a,
              debugParent2: chambers == _Chambers.both ? b : null,
            ),
          ),
        ),
      ),
    );
    // Sprite sheets load off the fake clock.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Past the chambers' own 800 ms settle.
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    var painted = 0, rebuilt = 0;
    debugOnProfilePaint = (_) => painted++;
    debugOnRebuildDirtyWidget = (_, _) => rebuilt++;
    await tester.pump(const Duration(milliseconds: 16));
    debugOnProfilePaint = null;
    debugOnRebuildDirtyWidget = null;

    final census = _CensusCanvas();
    final layers = <String, int>{};
    final ctx = _CensusContext(census, layers);
    debugDisableShadows = false;
    for (final view in tester.binding.renderViews) {
      view.paint(ctx, Offset.zero);
    }
    debugDisableShadows = true;

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    return _Frame(painted, rebuilt, census, layers);
  }

  for (final chambers in _Chambers.values) {
    testWidgets('an idle frame with ${chambers.label}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final f = await measure(tester, chambers);
      final reason = '$f';

      // Only what moves is re-recorded: the knot turning between a pair and
      // the background's motes, each on a layer of its own. Re-recording the
      // card for any of them was 83–120 render objects.
      expect(f.painted, lessThan(20), reason: reason);
      // Nothing rebuilds to animate. (The knot's portraits decode in real
      // time, and once in a while land in the measured frame: one rebuild.)
      expect(f.rebuilt, lessThanOrEqualTo(1), reason: reason);
      // The background's motes are batched by colour, size and strength, the
      // knot's grains by tone. A circle per mote was ~160.
      expect(f.census.counts['drawCircle'] ?? 0, lessThan(30), reason: reason);
      expect(f.census.draws, lessThan(100), reason: reason);
      // No glows to blur: the floor's light is gradients, and the buttons
      // are brackets, not shadows.
      expect(f.census.blurred, 0, reason: reason);
    });
  }
}
