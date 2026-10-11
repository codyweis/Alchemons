// Horn's parked zones wear Horn's own art in every game.
//
// Let's stationary catch-all once claimed "any parked thing with a snare, a
// taunt or a trail", so Horn's Fire, Water, Steam, Dust and Dark zones — and
// the geysers Steam leaves on kills — were drawn as Let fallout (flat legacy
// discs plus rotating taunt spokes) in survival, open space and dungeons,
// while the burning ground, whirlpool, geyser, cyclone and void horn_vfx.dart
// paints for them never drew. test/horn_vfx_preview_test.dart calls the horn
// painter directly, so it could not see that.
//
// This drives each game's REAL render pass with the zone on screen and
// records every canvas call the frame makes. The horn painter's own calls for
// that zone must appear in the frame, in order; Let fallout's must not.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every call a frame makes, its arguments summarised so two recordings of
/// the same painter at the same moment compare equal.
class _Recorder implements Canvas {
  final List<String> calls = [];

  static String _sig(Object? a) => switch (a) {
    final Paint p =>
      'P${p.color.toARGB32().toRadixString(16)}'
          '/${p.style.index}/${p.shader != null}/${p.blendMode.index}',
    final Offset o => '${o.dx.toStringAsFixed(1)},${o.dy.toStringAsFixed(1)}',
    final double d => d.toStringAsFixed(2),
    final Rect r =>
      'R${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)},'
          '${r.right.toStringAsFixed(1)},${r.bottom.toStringAsFixed(1)}',
    final Path p => 'Path${_sig(p.getBounds())}',
    null => 'null',
    _ => a.runtimeType.toString(),
  };

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    switch (key) {
      case 'getSaveCount':
        return 1;
      case 'getTransform':
        return Float64List.fromList([
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]);
      case 'getLocalClipBounds':
      case 'getDestinationClipBounds':
        return Rect.largest;
    }
    calls.add('$key(${i.positionalArguments.map(_sig).join(' ')})');
    return null;
  }
}

/// Whether [needle] appears in [hay] as one unbroken run.
bool _containsRun(List<String> hay, List<String> needle) {
  if (needle.isEmpty) return false;
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var k = 0;
    while (k < needle.length && hay[i + k] == needle[k]) {
      k++;
    }
    if (k == needle.length) return true;
  }
  return false;
}

const _zoneElements = ['Fire', 'Water', 'Steam', 'Dust', 'Dark'];

/// The parked zones a real Horn special lays, plus Steam's kill geyser.
Map<String, Projectile> _hornZones() {
  final zones = <String, Projectile>{};
  for (final element in _zoneElements) {
    final cast = createCosmicSpecialAbility(
      origin: Offset.zero,
      baseAngle: 0,
      family: 'horn',
      element: element,
      damage: 40,
      maxHp: 400,
      casterBeauty: 5,
      casterIntelligence: 5,
      casterStrength: 5,
      targetPos: const Offset(120, 0),
    );
    final zone = cast.projectiles.firstWhere(
      (p) =>
          p.stationary &&
          p.visualStyle == ProjectileVisualStyle.hornImpact &&
          (p.snareRadius > 0 || p.tauntRadius > 0 || p.trailInterval > 0),
      orElse: () => throw StateError('no parked Horn $element zone'),
    );
    zones[element] = zone;
  }
  zones['Steam kill geyser'] = hornSteamKillGeyser(
    position: Offset.zero,
    abilityAtk: 20,
    sizeScale: 1,
    durScale: 1,
    sourceSlot: 0,
  );
  return zones;
}

/// The horn painter's calls for [zone] at [time], and Let fallout's (the
/// zone tagged as a Let piece, which the catch-all still claims).
({List<String> horn, List<String> let}) _painters(
  Projectile zone,
  double time,
) {
  final color = elementColor(zone.element!);
  final horn = _Recorder();
  expect(
    drawHornElementalProjectileVisual(
      canvas: horn,
      projectile: zone,
      position: zone.position,
      color: color,
      time: time,
    ),
    isTrue,
  );
  final let = _Recorder();
  expect(
    drawLetElementalProjectileVisual(
      canvas: let,
      projectile: copyProjectile(zone, abilityFamily: 'let'),
      position: zone.position,
      color: color,
      time: time,
    ),
    isTrue,
    reason: 'the Let catch-all no longer claims its own parked pieces',
  );
  return (horn: horn.calls, let: let.calls);
}

void _expectHornArt(
  String mode,
  String label,
  List<String> frame,
  ({List<String> horn, List<String> let}) painters,
) {
  expect(
    _containsRun(frame, painters.horn),
    isTrue,
    reason: '$mode: Horn $label was not drawn by horn_vfx',
  );
  expect(
    _containsRun(frame, painters.let),
    isFalse,
    reason: '$mode: Horn $label was drawn as Let fallout',
  );
}

CosmicPartyMember _member(String family, String element, int slot) =>
    CosmicPartyMember(
      instanceId: 'claim-$family-$element-$slot',
      baseId: 'CLM0$slot',
      displayName: '$element $family',
      family: family,
      element: element,
      level: 10,
      slotIndex: slot,
      statSpeed: 4,
      statIntelligence: 4,
      statStrength: 4,
      statBeauty: 4,
      staminaBars: 3,
      staminaMax: 3,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Let catch-all claims only Let pieces', () {
    final canvas = Canvas(ui.PictureRecorder());
    for (final entry in _hornZones().entries) {
      final zone = entry.value;
      expect(
        drawLetElementalProjectileVisual(
          canvas: canvas,
          projectile: zone,
          position: zone.position,
          color: elementColor(zone.element!),
          time: 1,
        ),
        isFalse,
        reason: 'Let claimed Horn ${entry.key}',
      );
    }
  });

  test('survival draws Horn zones with horn_vfx', () async {
    final game = CosmicSurvivalGame(
      party: [_member('Horn', 'Fire', 0)],
      random: Random(7),
      onGameOver: () {},
      visualQuality: SurvivalVisualQuality.balanced,
    );
    game.onGameResize(Vector2(560, 420));
    await game.onLoad();
    game.startGame();
    for (var f = 0; f < 3; f++) {
      game.update(1 / 60);
    }
    final centre = Offset(
      game.camX + 280 / game.cameraZoom,
      game.camY + 210 / game.cameraZoom,
    );
    for (final entry in _hornZones().entries) {
      final zone = entry.value..position = centre;
      game.companionProjectiles.add(zone);
      final frame = _Recorder();
      game.render(frame);
      game.companionProjectiles.remove(zone);
      _expectHornArt(
        'survival',
        entry.key,
        frame.calls,
        _painters(zone, game.stats.timeElapsed),
      );
    }
  });

  test('open space draws Horn zones with horn_vfx', () async {
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 37),
      onMeterChanged: () {},
    );
    game.ship = ShipComponent(pos: Offset.zero);
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    final centre = Offset(
      game.camX + 450 / game.cameraZoom,
      game.camY + 350 / game.cameraZoom,
    );
    for (final entry in _hornZones().entries) {
      final zone = entry.value..position = centre;
      game.companionProjectiles.add(zone);
      final frame = _Recorder();
      game.render(frame);
      game.companionProjectiles.remove(zone);
      _expectHornArt(
        'open space',
        entry.key,
        frame.calls,
        _painters(zone, game.elapsedSeconds),
      );
    }
  });

  test('dungeons draw Horn zones with horn_vfx', () async {
    final party = [_member('Horn', 'Fire', 0)];
    final game = PlanetDungeonGame(
      element: 'Air',
      party: party,
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () {},
      onChanged: () {},
    );
    game.onGameResize(Vector2(900, 600));
    game.currentRoomId = game.layout.entranceRoomId;
    final spawn = game.layout.entranceSpawn;
    game.creatures.add(
      DungeonCreature(member: party.first)
        ..position = spawn
        ..lastSafe = spawn,
    );
    // Never updated, so the dungeon's clock still reads 0.
    for (final entry in _hornZones().entries) {
      final zone = entry.value..position = spawn + const Offset(40, 0);
      game.combatProjectiles.add(zone);
      final frame = _Recorder();
      game.render(frame);
      game.combatProjectiles.remove(zone);
      _expectHornArt('dungeon', entry.key, frame.calls, _painters(zone, 0));
    }
  });
}
