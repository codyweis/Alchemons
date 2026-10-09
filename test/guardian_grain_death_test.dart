import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/guardian_grain_death.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The guardian's death in grains of itself: the field on its own (no blur,
// no hoops, a draw per color, the crest), and in the dungeon (the body is
// read, the raid still waits for it, the relic still follows it).

GuardianGrainDeath _disc() => GuardianGrainDeath(color: const Color(0xFFE05030))
  ..useFallback()
  ..readyAt = 0;

_CountingCanvas _paintAt(GuardianGrainDeath d, double t) {
  final rec = ui.PictureRecorder();
  final canvas = _CountingCanvas(Canvas(rec));
  d.paint(canvas, const Offset(200, 200), t);
  rec.endRecording().dispose();
  return canvas;
}

CosmicPartyMember _member(int slot, String element) => CosmicPartyMember(
  instanceId: 'inst_$slot',
  baseId: 'base_$slot',
  displayName: 'Test $slot',
  element: element,
  family: const ['horn', 'wing', 'pip'][slot % 3],
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: slot,
  staminaBars: 3,
  staminaMax: 3,
);

PlanetDungeonGame _game({required bool raid, void Function()? onCleared}) {
  final party = [for (var i = 0; i < 3; i++) _member(i, 'Air')];
  final g = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: raid ? const RaidConfig() : null,
    onRaidCleared: onCleared,
    layoutOverride: raid ? buildRaidArenaLayout('Air') : null,
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final spawn = g.layout.entranceSpawn;
  for (var i = 0; i < party.length; i++) {
    g.creatures.add(
      DungeonCreature(member: party[i])
        ..position = spawn + Offset(i * 60.0, 0)
        ..lastSafe = spawn + Offset(i * 60.0, 0),
    );
  }
  if (!raid) g.debugSpawnGuardian();
  return g;
}

void _step(PlanetDungeonGame g, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    g.update(1 / 60);
  }
}

/// Steps past the arrival, fells the guardian, and runs the frame it dies.
void _fell(PlanetDungeonGame g) {
  _step(g, 2.6);
  final guardian = g.combatEnemies.firstWhere((e) => e.isElite);
  guardian
    ..hp = 0
    ..isDead = true;
  g.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuardianGrainDeath', () {
    test('nothing before it begins or once it is over', () {
      final d = _disc();
      expect(_paintAt(d, -0.1).draws, 0);
      expect(_paintAt(d, GuardianGrainDeath.duration).draws, 0);
      expect(_paintAt(d, 0.5).draws, greaterThan(0));
    });

    test('no blur and no stroked hoops anywhere in it', () {
      final d = _disc();
      for (var t = 0.0; t < GuardianGrainDeath.duration; t += 0.05) {
        final c = _paintAt(d, t);
        expect(c.blurred, 0, reason: 't=$t');
        expect(c.strokedShapes, 0, reason: 'a ring, at t=$t');
      }
    });

    test('a draw per color, not per grain', () {
      final d = _disc();
      expect(d.grains!.length, greaterThan(500));
      for (var t = 0.0; t < GuardianGrainDeath.duration; t += 0.1) {
        expect(_paintAt(d, t).draws, lessThan(48), reason: 't=$t');
      }
    });

    test('the crest runs down the body, then it is grains all the way', () {
      final d = _disc();
      expect(d.cutY(0.0), double.negativeInfinity);
      final a = d.cutY(0.15), b = d.cutY(0.35);
      expect(a.isFinite && b.isFinite, isTrue);
      expect(b, greaterThan(a), reason: 'it runs top to bottom');
      expect(d.cutY(0.7), double.infinity);
    });

    test('the beats keep the old death\'s length', () {
      expect(GuardianGrainDeath.duration, closeTo(3.6, 1e-9));
      expect(GuardianGrainDeath.relicAt, lessThan(GuardianGrainDeath.duration));
      expect(
        GuardianGrainDeath.relicAt,
        greaterThan(GuardianGrainDeath.burstAt),
      );
    });

    testWidgets('a painted body is read into grains of its own color', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const box = 120.0, ratio = 2.0;
        final rec = ui.PictureRecorder();
        Canvas(rec)
          ..scale(ratio)
          ..drawCircle(
            const Offset(box / 2, box / 2),
            34,
            Paint()..color = const Color(0xFF2050E0),
          );
        final image = rec.endRecording().toImageSync(
          (box * ratio).round(),
          (box * ratio).round(),
        );
        final d = GuardianGrainDeath(color: const Color(0xFF2050E0));
        await d.read(image, box: box, pixelRatio: ratio);
        expect(d.hasGrains, isTrue);
        final g = d.grains!;
        expect(g.length, greaterThan(500));
        for (var i = 0; i < g.length; i += 37) {
          final c = g.tones[g.tone[i]];
          expect(c.b, greaterThan(c.r), reason: 'grain $i keeps the blue');
          expect(Offset(g.hx[i], g.hy[i]).distance, lessThan(36));
        }
        d.dispose();
      });
    });
  });

  group('in the dungeon', () {
    test('a raid guardian is read into grains of itself', () async {
      final g = _game(raid: true);
      _fell(g);
      expect(g.isRaidDeathPlaying, isTrue);
      await g.debugGuardianDeathRead();
      final body = g.debugGuardianDeath!;
      expect(body.hasGrains, isTrue);
      expect(
        body.grains!.length,
        greaterThan(300),
        reason: 'its own body, not the fallback disc',
      );
      expect(body.readFailed, isFalse);
    });

    test('the raid still waits for the death, then hands over once', () {
      var cleared = 0;
      final g = _game(raid: true, onCleared: () => cleared++);
      _fell(g);
      _step(g, GuardianGrainDeath.duration - 0.2);
      expect(cleared, 0, reason: 'the reward screen waits for the death');
      expect(g.isRaidDeathPlaying, isTrue);
      _step(g, 0.4);
      expect(cleared, 1);
      expect(g.isRaidDeathPlaying, isFalse);
      expect(g.debugGuardianDeathPlaying, isFalse);
      _step(g, 1.0);
      expect(cleared, 1);
    });

    test('a felled dungeon guardian dies in grains; the relic rises after', () {
      final g = _game(raid: false);
      _fell(g);
      expect(g.hasStar(2), isTrue, reason: 'the star banks at once');
      expect(g.debugGuardianDeathPlaying, isTrue);
      expect(g.isRaidDeathPlaying, isFalse, reason: 'it holds no controls');
      expect(
        g.relicDropActive,
        isTrue,
        reason: 'the reward popup must already be waiting on the relic',
      );
      _step(g, GuardianGrainDeath.duration + 0.1);
      expect(g.debugGuardianDeathPlaying, isFalse);
      expect(g.relicDropActive, isTrue, reason: 'it rose out of the grains');
      _step(g, GuardianGrainDeath.relicAt + 3.6 - GuardianGrainDeath.duration);
      expect(g.relicDropActive, isFalse, reason: 'and was taken');
    });
  });
}

class _CountingCanvas implements Canvas {
  _CountingCanvas(this._inner);
  final Canvas _inner;
  int draws = 0, blurred = 0, strokedShapes = 0;

  void _count(Paint p) {
    draws++;
    if (p.maskFilter != null) blurred++;
  }

  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) {
    _count(paint);
    _inner.drawRawPoints(mode, points, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _count(paint);
    if (paint.style == PaintingStyle.stroke) strokedShapes++;
    _inner.drawCircle(c, radius, paint);
  }

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    _count(paint);
    _inner.drawImageRect(image, src, dst, paint);
  }

  @override
  void save() => _inner.save();

  @override
  void restore() => _inner.restore();

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
