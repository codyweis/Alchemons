// The fusion chamber at rest: what one idle frame asks of the UI thread and
// of the GPU, with the chambers empty, with one specimen in, and with two.
//
// Budget tests, not golden tests. They do not care what it looks like; they
// care that nothing on this screen goes back to re-recording the whole card
// every frame for the sake of one spinning orb, or to drawing the background
// a circle per mote. Before 2026-10-01 an idle frame with both chambers
// filled re-recorded 120 render objects, rebuilt 11 widgets and issued 158
// draws (7 blurred); with them empty, 83, 4 and 133 (4).
//
// Widget tests never rasterise, so the GPU side is counted rather than timed:
// the whole tree is painted once more into a canvas that tallies what it is
// asked to draw.
//
//   flutter test test/fusion_screen_budget_test.dart
//
// With FUSION_SCREEN_OUT=/some/dir it also saves what it measured, as PNGs.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  final out = Platform.environment['FUSION_SCREEN_OUT'];

  setUpAll(() async {
    if (out == null) return;
    final arial = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (!arial.existsSync()) return;
    await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.view(arial.readAsBytesSync().buffer))))
        .load();
  });

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
    final shot = GlobalKey();
    // Tests turn box shadows off; the device draws them, so a picture of
    // the screen should too.
    if (out != null) debugDisableShadows = false;
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final catalog = CreatureCatalog.fromList([
      horn('HOR01', 'Firehorn', 'Fire', 'HOR01_firehorn_spritesheet.png'),
      horn('HOR02', 'Waterhorn', 'Water', 'HOR02_waterhorn_spritesheet.png'),
    ]);
    CreatureInstance? a, b;
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
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: shot, child: child),
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

    if (out != null) {
      await tester.runAsync(() async {
        final boundary =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File(
          '$out/${chambers.name}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
    }

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

      // Only what moves is re-recorded: the empty circles' motes, the orb,
      // the drifting motes and the pulsing button, each on its own layer.
      // Re-recording the card for any of them was 83–120 render objects.
      expect(f.painted, lessThan(30), reason: reason);
      // The button's glow and pulse; nothing else rebuilds to animate.
      expect(f.rebuilt, lessThanOrEqualTo(2), reason: reason);
      // The background's motes are batched by colour, size and strength,
      // the circles' ticks in one batch each. A circle per mote was ~160.
      expect(f.census.counts['drawCircle'] ?? 0, lessThan(30), reason: reason);
      expect(f.census.draws, lessThan(100), reason: reason);
      // The orb's glow and the empty circles' motes are gradients now. What
      // is left are still rectangles' and the close buttons' BoxShadows,
      // which do not animate: the card, the header bar, the close buttons
      // and the fusion button's two.
      expect(
        f.census.blurred,
        lessThanOrEqualTo(chambers == _Chambers.both ? 6 : 4),
        reason: reason,
      );
    });
  }
}
