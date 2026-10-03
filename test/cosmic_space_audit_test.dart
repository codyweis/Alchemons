@Tags(['preview'])
library;

// COSMIC SPACE AUDIT. Flies the ship to every kind of thing the open world
// draws, and for each one records (a) what a frame asks of the GPU and
// (b) a picture of it, so the expensive features can be seen and judged.
//
//   AUDIT_OUT=/tmp/space_audit flutter test \
//     test/cosmic_space_audit_test.dart --tags preview
//
// Writes <scene>.png per scene and audit.json with, per scene:
//   draws        draw* calls in the frame
//   blurs        paints carrying a MaskFilter / ImageFilter (GPU filter pass)
//   layers       saveLayer calls (offscreen pass)
//   paths        drawPath calls (tessellated on the GPU / raster thread)
//   shaders      paints with a gradient/image shader
//   sprites      grains handed over in drawRawAtlas/drawPoints
//   overdraw     screen-covering fills, in screens (fill-rate proxy)
//   recordUs     time to record the frame into a real Picture (JIT, relative)
//   bySection    the same numbers split by the `// ── x ──` section of
//                CosmicGame.render that issued them (and the callee inside)
//
// A census, not a benchmark: widget tests never rasterise, so the GPU side
// is estimated from what was asked for. Read recordUs only relatively.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/planets/planet_art.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 915.0, _h = 412.0;

class _Affine {
  double a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0;
  _Affine clone() => _Affine()
    ..a = a
    ..b = b
    ..c = c
    ..d = d
    ..tx = tx
    ..ty = ty;
  void mul(double a2, double b2, double c2, double d2, double tx2, double ty2) {
    final na = a * a2 + c * b2;
    final nb = b * a2 + d * b2;
    final nc = a * c2 + c * d2;
    final nd = b * c2 + d * d2;
    final ntx = a * tx2 + c * ty2 + tx;
    final nty = b * tx2 + d * ty2 + ty;
    a = na;
    b = nb;
    c = nc;
    d = nd;
    tx = ntx;
    ty = nty;
  }

  Rect map(Rect r) {
    double mx(double x, double y) => a * x + c * y + tx;
    double my(double x, double y) => b * x + d * y + ty;
    final xs = [
      mx(r.left, r.top),
      mx(r.right, r.top),
      mx(r.left, r.bottom),
      mx(r.right, r.bottom),
    ];
    final ys = [
      my(r.left, r.top),
      my(r.right, r.top),
      my(r.left, r.bottom),
      my(r.right, r.bottom),
    ];
    return Rect.fromLTRB(xs.reduce(min), ys.reduce(min), xs.reduce(max),
        ys.reduce(max));
  }
}

class _Stat {
  int draws = 0, blurs = 0, layers = 0, paths = 0, shaders = 0, sprites = 0;
  int texts = 0, images = 0, clips = 0;
  double area = 0;
  Map<String, dynamic> toJson() => {
        'draws': draws,
        'blurs': blurs,
        'layers': layers,
        'paths': paths,
        'shaders': shaders,
        'sprites': sprites,
        'texts': texts,
        'images': images,
        'clips': clips,
        'overdraw': double.parse((area / (_w * _h)).toStringAsFixed(2)),
      };
}

final _sections = <(int, String)>[];

String _sectionFor(int line) {
  var name = 'render (preamble)';
  for (final (l, n) in _sections) {
    if (l > line) break;
    name = n;
  }
  return name;
}

final _frameRe = RegExp(r'^#\d+\s+(\S+) \((\S+?):(\d+):\d+\)$');

/// Records what a frame asks of the GPU, attributed to where it was asked.
class _Census implements Canvas {
  final total = _Stat();
  final bySection = <String, _Stat>{};
  final byCallee = <String, _Stat>{};
  final List<_Affine> _stack = [_Affine()];
  _Affine get _m => _stack.last;

  static const _screen = Rect.fromLTWH(0, 0, _w, _h);

  (String, String) _where() {
    final lines = StackTrace.current.toString().split('\n');
    String? prevFn, prevFile;
    for (final l in lines) {
      final m = _frameRe.firstMatch(l.trim());
      if (m == null) continue;
      final fn = m.group(1)!;
      final file = m.group(2)!;
      if (fn == 'CosmicGame.render' && file.endsWith('cosmic_game.dart')) {
        final section = _sectionFor(int.parse(m.group(3)!));
        final callee = prevFn == null || prevFile!.contains('cosmic_space_audit')
            ? section
            : '$prevFn  [${prevFile.split('/').last}]';
        return (section, callee);
      }
      if (!file.contains('dart:') && !fn.startsWith('_Census')) {
        prevFn = fn;
        prevFile = file;
      }
    }
    return ('flame/super.render', prevFn ?? '?');
  }

  double _area(Rect? local) {
    if (local == null) return _w * _h;
    final r = _m.map(local).intersect(_screen);
    if (r.width <= 0 || r.height <= 0) return 0;
    return r.width * r.height;
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    final args = i.positionalArguments;
    switch (key) {
      case 'save':
        _stack.add(_m.clone());
        return null;
      case 'saveLayer':
        _stack.add(_m.clone());
        _record(key, args, layer: true);
        return null;
      case 'restore':
        if (_stack.length > 1) _stack.removeLast();
        return null;
      case 'restoreToCount':
        final to = args[0] as int;
        while (_stack.length > max(1, to)) {
          _stack.removeLast();
        }
        return null;
      case 'getSaveCount':
        return _stack.length;
      case 'translate':
        _m.mul(1, 0, 0, 1, (args[0] as num).toDouble(),
            (args[1] as num).toDouble());
        return null;
      case 'scale':
        final sx = (args[0] as num).toDouble();
        final sy = args.length > 1 && args[1] != null
            ? (args[1] as num).toDouble()
            : sx;
        _m.mul(sx, 0, 0, sy, 0, 0);
        return null;
      case 'rotate':
        final r = (args[0] as num).toDouble();
        _m.mul(cos(r), sin(r), -sin(r), cos(r), 0, 0);
        return null;
      case 'transform':
        final m = args[0] as Float64List;
        _m.mul(m[0], m[1], m[4], m[5], m[12], m[13]);
        return null;
      case 'skew':
        return null;
    }
    if (key.startsWith('clip')) {
      _bump((s) => s.clips++);
      return null;
    }
    if (key.startsWith('draw')) _record(key, args);
    return null;
  }

  void _bump(void Function(_Stat) f) {
    final (section, callee) = _where();
    f(total);
    f(bySection.putIfAbsent(section, _Stat.new));
    f(byCallee.putIfAbsent(callee, _Stat.new));
  }

  void _record(String key, List<Object?> args, {bool layer = false}) {
    Paint? paint;
    for (final a in args) {
      if (a is Paint) paint = a;
    }
    final blur =
        paint != null && (paint.maskFilter != null || paint.imageFilter != null);
    final shader = paint?.shader != null;
    var sprites = 0;
    double area = 0;
    switch (key) {
      case 'drawCircle':
        final c = args[0] as Offset, r = (args[1] as num).toDouble();
        area = _area(Rect.fromCircle(center: c, radius: r)) * pi / 4;
      case 'drawOval':
      case 'drawRect':
      case 'drawArc':
        area = _area(args[0] as Rect) * (key == 'drawRect' ? 1 : pi / 4);
      case 'drawRRect':
        area = _area((args[0] as RRect).outerRect);
      case 'drawPath':
        area = paint?.style == PaintingStyle.stroke
            ? 0
            : _area((args[0] as Path).getBounds()) * 0.6;
      case 'drawPaint':
        area = _w * _h;
      case 'drawImageRect':
        area = _area(args[2] as Rect);
      case 'drawRawAtlas':
      case 'drawAtlas':
        final xf = args[1];
        sprites = xf is Float32List ? xf.length ~/ 4 : (xf as List).length;
      case 'drawRawPoints':
        sprites = (args[1] as Float32List).length ~/ 2;
      case 'drawPoints':
        sprites = (args[1] as List).length;
      case 'drawVertices':
        sprites = 1;
    }
    if (paint?.style == PaintingStyle.stroke && key != 'drawPath') area *= 0.15;
    _bump((s) {
      if (layer) {
        s.layers++;
        s.area += _w * _h;
        if (blur) s.blurs++;
        return;
      }
      s.draws++;
      if (blur) s.blurs++;
      if (shader) s.shaders++;
      if (key == 'drawPath') s.paths++;
      if (key == 'drawParagraph') s.texts++;
      if (key.startsWith('drawImage') || key.contains('Atlas')) s.images++;
      s.sprites += sprites;
      s.area += area;
    });
  }
}

CosmicPartyMember _member(String family, String element, int slot) =>
    CosmicPartyMember(
      instanceId: '$family-$element-$slot',
      baseId: '${family.substring(0, 3).toUpperCase()}01',
      displayName: '$element $family',
      family: family,
      element: element,
      level: 10,
      slotIndex: slot,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      staminaBars: 5,
      staminaMax: 5,
    );

void main() {
  final outDir = Platform.environment['AUDIT_OUT'];
  final only = Platform.environment['AUDIT_ONLY'];

  // The section headers of CosmicGame.render, by line.
  final src = File('lib/games/cosmic/cosmic_game.dart').readAsLinesSync();
  final start = src.indexWhere((l) => l.startsWith('  void render(Canvas'));
  final hdr = RegExp(r'^\s*// ── (.+?) ──');
  for (var i = start; i < src.length; i++) {
    final m = hdr.firstMatch(src[i]);
    if (m != null) _sections.add((i + 1, m.group(1)!));
  }

  testWidgets('cosmic space audit', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    final results = <String, dynamic>{};

    late CosmicGame game;
    Future<void> boot() async {
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(_w, _h));
      for (final p in game.world_.planets) {
        p.discovered = true;
      }
    }

    void settle(double seconds) {
      final n = (seconds * 30).round();
      for (var i = 0; i < n; i++) {
        game.update(1 / 30);
      }
    }

    Future<void> shoot(String name, {String? note}) async {
      if (only != null && !name.contains(only)) return;
      final c = _Census();
      game.render(c as Canvas);

      // Record time: a real Picture, median of several.
      final times = <int>[];
      for (var i = 0; i < 9; i++) {
        final rec = ui.PictureRecorder();
        final sw = Stopwatch()..start();
        game.render(Canvas(rec));
        final pic = rec.endRecording();
        times.add(sw.elapsedMicroseconds);
        pic.dispose();
      }
      times.sort();

      const dpr = 1.5;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _w * dpr, _h * dpr),
        Paint()..color = const Color(0xFF020010),
      );
      canvas.scale(dpr);
      game.render(canvas);
      final pic = rec.endRecording();
      final img = pic.toImageSync((_w * dpr).round(), (_h * dpr).round());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
      pic.dispose();

      Map<String, dynamic> top(Map<String, _Stat> m) {
        final e = m.entries.toList()
          ..sort((a, b) => b.value.draws.compareTo(a.value.draws));
        return {for (final x in e.take(14)) x.key: x.value.toJson()};
      }

      results[name] = {
        ...c.total.toJson(),
        'recordUs': times[times.length ~/ 2],
        'zoom': game.cameraZoom,
        'note': ?note,
        'bySection': top(c.bySection),
        'byCallee': top(c.byCallee),
      };
      // ignore: avoid_print
      print('$name: ${c.total.toJson()} rec=${times[times.length ~/ 2]}us');
    }

    void flyTo(Offset p, {Offset off = Offset.zero}) {
      game.teleportTo(p + off);
      game.enemies.clear();
      game.activeBoss = null;
    }

    await tester.runAsync(() async {
      await boot();
      final world = game.world_;

      // A quiet spot: farthest from every landmark.
      var quiet = Offset.zero;
      var best = -1.0;
      final marks = [
        ...world.planets.map((p) => p.position),
        ...game.spacePOIs.map((p) => p.position),
        ...game.galaxyWhirls.map((p) => p.position),
        ...world.riftPortals.map((p) => p.position),
        world.elementalNexus.position,
        world.bloodRing.position,
        game.asteroidBelt.center,
      ];
      for (var gx = 1; gx < 24; gx++) {
        for (var gy = 1; gy < 24; gy++) {
          final p = Offset(world.worldSize.width * gx / 24,
              world.worldSize.height * gy / 24);
          var nearest = double.infinity;
          for (final m in marks) {
            nearest = min(nearest, (m - p).distance);
          }
          if (nearest > best) {
            best = nearest;
            quiet = p;
          }
        }
      }

      // ── empty space at each zoom ──
      flyTo(quiet);
      settle(1);
      await shoot('00_deep_space_mid');
      game.cycleZoomLevel();
      settle(1);
      await shoot('00_deep_space_far');
      game.cycleZoomLevel();
      settle(1);
      await shoot('00_deep_space_close');
      game.cycleZoomLevel(); // back to mid
      settle(1);

      // ── every planet ──
      for (final p in world.planets) {
        flyTo(p.position, off: Offset(-p.radius * 1.4, p.radius * 0.3));
        settle(0.5);
        await shoot('10_planet_${p.element.toLowerCase()}');
      }

      // ── home planet, every customization on ──
      flyTo(quiet);
      game.restoreHomePlanet(HomePlanet(
        position: quiet + const Offset(260, 0),
        activeColor: 'Fire',
        sizeTierLevel: 3,
        activeSizeTier: 3,
      ));
      game.activeCustomizations = {...HomeEffectsArt.handled};
      game.customizationOptions = {
        'black_hole.density': 'Maximum',
        'black_hole.disk': 'Vast',
        'planetary_rings.count': '3',
      };
      settle(1);
      await shoot('20_home_all_customizations');
      game.activeCustomizations = {};
      settle(0.2);
      await shoot('20_home_plain');
      for (final id in HomeEffectsArt.handled) {
        game.activeCustomizations = {id};
        settle(0.4);
        game.homePlanet!.position = game.ship.pos + const Offset(230, 10);
        game.update(1 / 60);
        await shoot('21_home_$id');
      }
      game.activeCustomizations = {};
      game.homePlanet = null;

      // ── landmarks ──
      // The densest knot of rocks in the belt.
      final rocks = game.asteroidBelt.asteroids;
      var dense = rocks.first.position;
      var most = 0;
      for (final a in rocks) {
        final n = rocks
            .where((b) => (b.position - a.position).distance < 400)
            .length;
        if (n > most) {
          most = n;
          dense = a.position;
        }
      }
      flyTo(dense, off: const Offset(-120, 0));
      settle(1);
      await shoot('30_asteroid_belt');

      if (world.particleSwarms.isNotEmpty) {
        flyTo(world.particleSwarms.first.center);
        settle(1);
        await shoot('30_particle_swarm');
      }

      final whirl = game.galaxyWhirls.first;
      flyTo(whirl.position, off: const Offset(-180, 0));
      settle(1);
      await shoot('31_galaxy_whirl');
      // Close enough to wake it: let a wave come in.
      game.teleportTo(whirl.position);
      for (var i = 0; i < 30 * 6; i++) {
        game.update(1 / 30);
        game.shipHealth = CosmicBalance.shipMaxHealth;
      }
      await shoot('31_galaxy_whirl_wave', note: '${game.enemies.length} enemies');
      game.activeWhirl = null;

      flyTo(world.riftPortals.first.position, off: const Offset(-160, 0));
      settle(1);
      await shoot('32_rift_portal');

      flyTo(world.elementalNexus.position, off: const Offset(-260, 0));
      settle(1);
      await shoot('33_elemental_nexus');

      flyTo(world.bloodRing.position, off: const Offset(-220, 0));
      settle(1);
      await shoot('34_blood_ring');

      // The finale plays on the ring: thorns igniting, then the flood.
      for (final (at, name) in [(0.35, 'a'), (0.62, 'b'), (0.9, 'c')]) {
        game.bloodRitualProgress = at;
        settle(1.5);
        await shoot('34${name}_blood_ritual');
      }
      game.bloodRitualProgress = null;

      if (world.contestArenas.isNotEmpty) {
        flyTo(world.contestArenas.first.position, off: const Offset(-200, 0));
        settle(1);
        await shoot('35_contest_arena');
      }

      flyTo(world.prismaticField.position);
      settle(1);
      await shoot('36_prismatic_field');

      final cache = game.elementalCacheField.caches.first;
      flyTo(cache.position, off: const Offset(-160, 0));
      settle(1);
      await shoot('37_elemental_cache');

      final seen = <POIType>{};
      for (final poi in game.spacePOIs) {
        if (!seen.add(poi.type)) continue;
        poi.discovered = true;
        flyTo(poi.position, off: const Offset(-160, 0));
        settle(1);
        // Comets move: catch up with it.
        flyTo(poi.position, off: const Offset(-60, 0));
        game.update(1 / 30);
        await shoot('40_poi_${poi.type.name}');
      }

      if (game.bossLairs.isNotEmpty) {
        flyTo(game.bossLairs.first.position, off: const Offset(-420, 0));
        settle(0.3);
        await shoot('50_boss_lair_waiting');
      }

      // ── loot scattered after a fight ──
      flyTo(quiet);
      settle(0.2);
      final lr = Random(5);
      for (var i = 0; i < 18; i++) {
        final type = LootType.values[i % LootType.values.length];
        game.lootDrops.add(LootDrop(
          position: game.ship.pos +
              Offset(140 + lr.nextDouble() * 260, (lr.nextDouble() - 0.5) * 300),
          velocity: Offset.zero,
          type: type,
          amount: 5,
          element: type == LootType.elementParticle ? 'Fire' : null,
          color: const Color(0xFFFFD27A),
        ));
      }
      settle(0.3);
      await shoot('55_loot_drops_18');
      game.lootDrops.clear();

      // ── combat ──
      flyTo(quiet);
      settle(0.2);
      final rng = Random(3);
      final tiers = EnemyTier.values;
      for (var i = 0; i < 24; i++) {
        final a = rng.nextDouble() * pi * 2;
        final r = 120 + rng.nextDouble() * 260;
        game.enemies.add(CosmicEnemy(
          position: game.ship.pos + Offset(cos(a) * r, sin(a) * r * 0.5),
          element: kElementColors.keys.elementAt(i % kElementColors.length),
          tier: tiers[i % tiers.length],
          radius: 14,
          health: 1e6,
          speed: 0,
          behavior: EnemyBehavior.drifting,
        ));
      }
      settle(0.2);
      await shoot('60_enemy_pack_24');

      for (final t in kBossTemplates.where((t) => t.isTitanic).take(1)
          .followedBy(kBossTemplates.where((t) => !t.isTitanic).take(1))) {
        flyTo(quiet);
        game.activeBoss = CosmicBoss(
          position: game.ship.pos + const Offset(260, 0),
          name: t.name,
          element: t.element,
          level: 3,
          radius: t.radius,
          maxHealth: 1e9,
          speed: 0,
          forcedType: t.preferredType,
          isTitanic: t.isTitanic,
          colossalTrait: t.colossalTrait,
        );
        settle(0.5);
        await shoot(
          '61_boss_${t.isTitanic ? 'titanic' : 'normal'}_${t.element.toLowerCase()}',
          note: t.name,
        );
      }

      // ── the party, out and fighting ──
      flyTo(quiet);
      for (final m in [
        _member('Pip', 'Fire', 0),
        _member('Wing', 'Air', 1),
        _member('Horn', 'Earth', 2),
      ]) {
        game.summonCompanion(m, slotIndex: m.slotIndex);
      }
      for (var i = 0; i < 10; i++) {
        game.enemies.add(CosmicEnemy(
          position: game.ship.pos + Offset(200 + i * 18.0, (i - 5) * 22.0),
          element: 'Fire',
          tier: EnemyTier.sentinel,
          radius: 14,
          health: 1e6,
          speed: 0,
          behavior: EnemyBehavior.aggressive,
        ));
      }
      for (var i = 0; i < 90; i++) {
        game.update(1 / 30);
        // Keep the fight on without the enemies winning.
        for (final e in game.enemies) {
          e.health = 1e6;
        }
        game.shipHealth = CosmicBalance.shipMaxHealth;
      }
      await shoot('70_party_fighting', note: 'sprites not loaded headless');

      // ── the pocket dimension ──
      game.enemies.clear();
      game.enterNexusPocket();
      settle(1);
      await shoot('80_nexus_pocket');
      game.exitNexusPocket();

      // ── the sweep: 200 random spots at mid and far zoom ──
      for (final zoomName in ['mid', 'far']) {
        if (zoomName == 'far') game.cycleZoomLevel();
        settle(0.5);
        final r = Random(11);
        final draws = <int>[];
        final rec = <int>[];
        final sectionTotals = <String, int>{};
        var blurFrames = 0;
        for (var i = 0; i < 200; i++) {
          flyTo(Offset(r.nextDouble() * world.worldSize.width,
              r.nextDouble() * world.worldSize.height));
          game.update(1 / 30);
          final c = _Census();
          game.render(c as Canvas);
          draws.add(c.total.draws);
          if (c.total.blurs > 0) blurFrames++;
          for (final e in c.bySection.entries) {
            sectionTotals[e.key] = (sectionTotals[e.key] ?? 0) + e.value.draws;
          }
          final pr = ui.PictureRecorder();
          final sw = Stopwatch()..start();
          game.render(Canvas(pr));
          pr.endRecording().dispose();
          rec.add(sw.elapsedMicroseconds);
        }
        draws.sort();
        rec.sort();
        results['sweep_$zoomName'] = {
          'drawsMedian': draws[100],
          'drawsP95': draws[190],
          'drawsMax': draws.last,
          'recordUsMedian': rec[100],
          'recordUsP95': rec[190],
          'framesWithBlur': blurFrames,
          'avgDrawsBySection': {
            for (final e in (sectionTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value))))
              e.key: (e.value / 200).toStringAsFixed(1),
          },
        };
      }
    });

    File('$outDir/audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(results),
    );
  });
}
