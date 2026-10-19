@Tags(['preview'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/screens/scenes/rift_threshold.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The rift threshold in landscape with real fonts: tearing open, at rest,
// the key half turned, the key flying in, the fall, and without a key —
// plus each faction at rest, and what a frame costs.
//
//   RIFT_OUT=/tmp/rift flutter test \
//     test/rift_threshold_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['RIFT_OUT'];

  Future<void> loadFont(String family, List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      return;
    }
  }

  setUpAll(() async {
    await loadFont('monospace', [
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    ]);
    await loadFont('Roboto', [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]);
  });

  testWidgets('rift threshold preview', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    final key = GlobalKey();

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 1000 ~/ 30));
      }
    }

    Future<void> mount(
      RiftFaction faction, {
      int keys = 3,
      int gold = 40,
      int? harvesters,
      int essence = 80,
      Size size = const Size(860, 360),
    }) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      var held = keys;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: RiftThreshold(
              faction: faction,
              closesIn: '7h 12m',
              loadKeys: () async => held,
              spendKey: () async {
                if (held <= 0) return false;
                held--;
                return true;
              },
              onEnter: () async {},
              loadGold: () async => gold,
              keyPrice: 5,
              buyKey: () async {
                held++;
                return true;
              },
              harvester: harvesters == null
                  ? null
                  : RiftHarvesterNeed(
                      fitting: const ['Volcanic', 'Stabilized'],
                      biome: 'volcanic',
                      load: () async => harvesters,
                      loadWallet: () async => {
                        'silver': 400,
                        'res_volcanic': essence,
                      },
                      price: const {'silver': 250, 'res_volcanic': 50},
                      buy: () async => true,
                    ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final size in const [Size(860, 360), Size(900, 680)]) {
      final tag = '${size.width.toInt()}';
      await mount(RiftFaction.volcanic, size: size);
      await frames(8);
      await shoot('${tag}_1_opening');
      await frames(40);
      await shoot('${tag}_2_rest');

      final hold = await tester.startGesture(
        tester.getCenter(find.text('HOLD TO TURN THE KEY')),
      );
      await frames(16);
      await shoot('${tag}_3_turning');
      await frames(14);
      await hold.up();
      await frames(9);
      await shoot('${tag}_4_key_flying');
      await frames(12);
      await shoot('${tag}_5_falling');
      await frames(14);
      await shoot('${tag}_6_fallen');

      await mount(RiftFaction.volcanic, keys: 0, size: size);
      await frames(40);
      await shoot('${tag}_7_no_key');
      await mount(RiftFaction.volcanic, keys: 0, gold: 2, size: size);
      await frames(40);
      await shoot('${tag}_8_no_gold');
      await mount(RiftFaction.volcanic, harvesters: 0, size: size);
      await frames(40);
      await shoot('${tag}_9_no_harvester');
    }

    // The Fold's cover screen held sideways: the shortest landscape phone.
    const fold = Size(882, 344);
    await mount(RiftFaction.volcanic, size: fold);
    await frames(40);
    await shoot('fold_rest');
    await mount(RiftFaction.volcanic, harvesters: 0, essence: 30, size: fold);
    await frames(40);
    await shoot('fold_no_harvester_short');

    for (final f in RiftFaction.values) {
      await mount(f);
      await frames(45);
      await shoot('faction_${f.name}');
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();

    // Cost: the field alone, at rest and turning.
    final field = RiftVortexField()..open = 1;
    final pal = RiftPalette(RiftFaction.arcane.primaryColor);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 240; i++) {
      field.charge = (i % 60) / 60;
      field.step(1 / 60);
      final rec = ui.PictureRecorder();
      field.paint(
        Canvas(rec),
        const Size(860, 360),
        const Offset(258, 180),
        151,
        pal,
      );
      rec.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'rift threshold: ${(sw.elapsedMicroseconds / 240).toStringAsFixed(0)} '
      'µs per frame (JIT)',
    );
  });

  testWidgets('wilderness rift over scene art', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    Future<ui.Image> load(String path) async {
      final codec = await ui.instantiateImageCodec(
        File(path).readAsBytesSync(),
        targetWidth: 900,
      );
      return (await codec.getNextFrame()).image;
    }

    // Only the Valley still has pictures; the other fields are drawn in
    // code, so their rifts open over black.
    const scenes = [
      ('valley', ['sky', 'backhills', 'hills'], RiftFaction.earthen),
      ('volcano', <String>[], RiftFaction.volcanic),
      ('sky', <String>[], RiftFaction.verdant),
      ('swamp', <String>[], RiftFaction.oceanic),
      ('arcane', <String>[], RiftFaction.arcane),
    ];
    for (final (scene, names, faction) in scenes) {
      final dir = 'assets/images/backgrounds/scenes/$scene';
      final images = <ui.Image>[];
      await tester.runAsync(() async {
        for (final n in names) {
          final f = File('$dir/$n.png');
          if (f.existsSync()) images.add(await load(f.path));
        }
      });
      final field = RiftVortexField(
        grains: 460,
        ringGrains: 110,
        motes: 26,
        core: 0.27,
      );
      for (var i = 0; i < 150; i++) {
        field.open = (field.open + 1 / 60 / 1.4).clamp(0.0, 1.0);
        field.step(1 / 60);
      }
      const size = Size(450, 220);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF000000),
      );
      for (final img in images) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height * 0.6);
        canvas.drawImageRect(img, src, Offset.zero & size, Paint());
      }
      field.paint(
        canvas,
        size,
        const Offset(300, 70),
        30 * 2.4,
        RiftPalette(faction.primaryColor),
        backdrop: false,
      );
      final image = rec.endRecording().toImageSync(
        size.width.toInt(),
        size.height.toInt(),
      );
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$outDir/world_$scene.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });

  // The way in and out over a stand-in scene: the threshold growing out
  // of the rift that was tapped, the key coming apart into grains, stepping
  // back into the rift, and the black the rift is left through opening on
  // where it was.
  testWidgets('rift passage preview', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    tester.view.physicalSize = const Size(860, 360) * 2;
    tester.view.devicePixelRatio = 2;

    late List<ui.Image> layers;
    await tester.runAsync(() async {
      layers = [];
      for (final n in ['sky', 'backhills', 'hills']) {
        final f = File('assets/images/backgrounds/scenes/valley/$n.png');
        if (!f.existsSync()) continue;
        final codec = await ui.instantiateImageCodec(
          f.readAsBytesSync(),
          targetWidth: 900,
        );
        layers.add((await codec.getNextFrame()).image);
      }
    });

    final shotKey = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
    final scene = _StandInScene(layers: layers);
    const at = Offset(600, 92);
    final from = RiftOrigin(
      centre: at,
      radius: 72,
      core: 0.27,
      density: 460 / RiftVortexField.defaultGrains,
      grain: 1.25,
      hide: (hidden) => scene.hidden.value = hidden,
    );

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$outDir/passage_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 1000 ~/ 30));
      }
    }

    var held = 2;
    Widget threshold() => RiftThreshold(
      faction: RiftFaction.earthen,
      from: from,
      closesIn: '7h 12m',
      loadKeys: () async => held,
      spendKey: () async {
        held--;
        return true;
      },
      onEnter: () async {},
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: MaterialApp(
          navigatorKey: nav,
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: scene,
        ),
      ),
    );
    await frames(20);
    await shoot('0_scene');

    // In: the threshold grows out of the rift.
    unawaited(
      nav.currentState!.push(
        riftThresholdRoute(from: from, builder: (_) => threshold()),
      ),
    );
    for (final (name, n) in const [
      ('1_grow_10', 3),
      ('2_grow_30', 6),
      ('3_grow_50', 6),
      ('4_grow_70', 6),
      ('5_grow_90', 6),
      ('6_grown', 10),
    ]) {
      await frames(n);
      await shoot(name);
    }

    // Back: it shrinks into the rift again.
    nav.currentState!.pop();
    for (final (name, n) in const [
      ('7_back_25', 5),
      ('8_back_60', 7),
      ('9_back_done', 12),
    ]) {
      await frames(n);
      await shoot(name);
    }

    // In again, and the key turned: it comes apart into grains.
    final again = riftThresholdRoute(from: from, builder: (_) => threshold());
    unawaited(nav.currentState!.push(again));
    await frames(40);
    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO TURN THE KEY')),
    );
    await frames(28);
    await hold.up();
    for (final (name, n) in const [
      ('k1_apart', 2),
      ('k2_loosen', 4),
      ('k3_stream', 6),
      ('k4_stream', 6),
      ('k5_swallow', 7),
      ('k6_swallow', 7),
      ('k7_fall', 8),
    ]) {
      await frames(n);
      await shoot(name);
    }
    await frames(40);

    // Out: the black the rift is left through, opening on where it was —
    // on the rift still there, and on the sky where a spent one was. (The
    // rift itself replaced the threshold; here it simply goes.)
    for (final spent in [false, true]) {
      final exit = RiftExitSheet()..cover(nav.currentState!);
      if (spent) {
        scene.hidden.value = true;
      } else {
        nav.currentState!.removeRoute(again);
      }
      await frames(3);
      await shoot('x${spent ? 'spent' : ''}0_black');
      unawaited(exit.open(at: at));
      for (var k = 1; k <= 5; k++) {
        await frames(6);
        await shoot('x${spent ? 'spent' : ''}${k}_open');
      }
      await frames(14);
      expect(exit.covering, isFalse);
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets('rift interior, portrait threshold, space rift', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    Future<void> save(ui.Image image, String name) async {
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // The inside: the vortex huge, an Alchemon standing in its core.
    late ui.Image creature;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File(
          'assets/images/creatures/rare/HOR01_firehorn.png',
        ).readAsBytesSync(),
        targetWidth: 340,
      );
      creature = (await codec.getNextFrame()).image;
    });
    for (final (w, h) in const [(860.0, 360.0), (900.0, 680.0)]) {
      for (final (f, coreR) in [
        (RiftFaction.volcanic, 70.0),
        (RiftFaction.volcanic, 95.0),
        (RiftFaction.arcane, 70.0),
      ]) {
        final field = RiftVortexField(
          grains: 2200,
          ringGrains: 300,
          motes: 90,
          core: 0.2,
          speed: 0.4,
          grainSize: 1.7,
        );
        for (var i = 0; i < 120; i++) {
          field.open = (field.open + 1 / 60 / 1.6).clamp(0.0, 1.0);
          field.step(1 / 60);
        }
        final size = Size(w, h);
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        field.paint(
          canvas,
          size,
          size.center(Offset.zero),
          coreR / field.core,
          RiftPalette(f.primaryColor),
        );
        const s = 170.0;
        canvas.drawImageRect(
          creature,
          Rect.fromLTWH(
            0,
            0,
            creature.width.toDouble(),
            creature.height.toDouble(),
          ),
          Rect.fromCenter(
            center: size.center(Offset.zero),
            width: s,
            height: s,
          ),
          Paint()..filterQuality = FilterQuality.medium,
        );
        await save(
          rec.endRecording().toImageSync(w.toInt(), h.toInt()),
          'inside_${w.toInt()}_${f.name}_${coreR.toInt()}',
        );
      }
    }

    // Space: the rift at world scale, over the dark.
    for (final f in RiftFaction.values) {
      final field = RiftVortexField(
        grains: 520,
        ringGrains: 120,
        motes: 30,
        core: 0.27,
        grainSize: 2.4,
      )..open = 1;
      for (var i = 0; i < 120; i++) {
        field.step(1 / 60);
      }
      const size = Size(300, 300);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF05060C),
      );
      final rng = Random(3);
      for (var i = 0; i < 60; i++) {
        canvas.drawCircle(
          Offset(rng.nextDouble() * 300, rng.nextDouble() * 300),
          0.6 + rng.nextDouble() * 0.8,
          Paint()..color = const Color(0x88FFFFFF),
        );
      }
      // The cosmic camera's usual zoom.
      canvas.translate(150, 150);
      canvas.scale(0.75);
      field.paint(
        canvas,
        Size.zero,
        Offset.zero,
        28 / field.core,
        RiftPalette(f.primaryColor),
        backdrop: false,
      );
      await save(rec.endRecording().toImageSync(300, 300), 'space_${f.name}');
    }
  });

  testWidgets('threshold in portrait (space)', (tester) async {
    if (outDir == null) return;
    final key = GlobalKey();
    tester.view.physicalSize = const Size(412 * 2, 880 * 2);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
          child: RiftThreshold(
            faction: RiftFaction.oceanic,
            partyEnters: false,
            loadKeys: () async => 1,
            spendKey: () async => true,
            onEnter: () async {},
          ),
        ),
      ),
    );
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$outDir/portrait_space.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}

/// A wilderness scene standing in for the real one: the valley's pictures
/// and a rift in its sky, hidden while its threshold stands in for it.
class _StandInScene extends StatefulWidget {
  _StandInScene({required this.layers});

  final List<ui.Image> layers;
  final ValueNotifier<bool> hidden = ValueNotifier(false);

  @override
  State<_StandInScene> createState() => _StandInSceneState();
}

class _StandInSceneState extends State<_StandInScene>
    with SingleTickerProviderStateMixin {
  final RiftVortexField field = RiftVortexField(
    grains: 460,
    ringGrains: 110,
    motes: 26,
    core: 0.27,
  )..open = 1;
  final ValueNotifier<double> clock = ValueNotifier(0);
  late final ticker = createTicker((_) {
    field.step(1 / 30);
    clock.value = field.time;
  })..start();

  @override
  void initState() {
    super.initState();
    ticker;
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _StandInPainter(this),
  );
}

class _StandInPainter extends CustomPainter {
  _StandInPainter(this.s)
    : super(repaint: Listenable.merge([s.clock, s.widget.hidden]));

  final _StandInSceneState s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B2433));
    for (final img in s.widget.layers) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height * 0.6),
        Offset.zero & size,
        Paint(),
      );
    }
    if (s.widget.hidden.value) return;
    s.field.paint(
      canvas,
      size,
      const Offset(600, 92),
      72,
      RiftPalette(RiftFaction.earthen.primaryColor),
      backdrop: false,
    );
  }

  @override
  bool shouldRepaint(_StandInPainter old) => false;
}
