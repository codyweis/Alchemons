// lib/games/planet_dungeon/planet_dungeon_game_steam_art.dart
//
// VAPORIS, IN GLASS (docs/dungeons.md §7.11) — Steam's stone and the glass it
// signals with, as a part of planet_dungeon_game.dart.
//
// The boiler house kept its brickwork (firebrick courses, the ring-main sunk
// in the floor, the condensate grate — the 2026-09-02 pass, and it was right).
// What changes is that it is BAKED, it gets walls, and the working parts wear
// gauge glass, which is the one glass a boiler house really has:
//
//   · a junction's release wheel has a glass hub, lit when the main can pay;
//   · the firebox is seen through a sight-glass;
//   · a crucible corner's wanted elements are panes of that element's glass,
//     silver-capped once sealed;
//   · the entry vent's wheel carries a glass hub;
//   · and HIDDEN HARMONY — the maxim — used to leave only an empty socket.
//     Now the sigil you took sinks INTO the plinth as the rite binds and
//     stays there as an inlay of steam glass, condensation running on it.

part of 'planet_dungeon_game.dart';

const GlassPalette _kGaugeGlass = kVaporGlass;

final Map<String, ui.Picture> _vaporFabricCache = {};

extension MoltenLabyrinthArt on PlanetDungeonGame {
  void _updateSteamGlass(double dt) {
    final target =
        discoveredClouds.contains(kSteamHiddenHarmonyEggId) ||
            _ritePendingEgg == kSteamHiddenHarmonyEggId
        ? 1.0
        : 0.0;
    if (_harmonySet < 0) {
      _harmonySet = target;
    } else if (_harmonySet < target) {
      _harmonySet = min(target, _harmonySet + dt / 2.4);
    } else if (_harmonySet > target) {
      _harmonySet = target;
    }
  }

  /// The boiler house's floor and walls, baked once per room.
  void _renderVaporFabric(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final key = '${room.id}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _vaporFabricCache.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        _renderPlainFloor(c, b, false);
        _drawFoundryFloor(c, room);
        paintCarvedRoomShell(
          c,
          b,
          _kGaugeGlass,
          GlassRng(glassSeed(room.id, b)),
          doors: room.doors.map((d) => d.rect),
          arcade: false,
          flags: false,
        );
        return rec.endRecording();
      }),
    );
  }

  /// A wheel's glass hub: lit gauge-glass when it can act, smoked when not.
  void _drawGaugeHub(
    Canvas canvas,
    Offset p, {
    required bool lit,
    double r = 6,
  }) {
    paintRondel(
      canvas,
      p,
      r,
      _kGaugeGlass,
      fill: lit
          ? _kGaugeGlass.heat(0.78 + 0.1 * sin(_moltenPulse * 2.4))
          : _kGaugeGlass.smoke,
      rim: lit ? 1.0 : 0.5,
      lead: 1.8,
    );
  }

  /// The firebox, seen through its sight-glass: three panes of fire.
  void _drawFireboxGlass(Canvas canvas, Rect box, double pulse) {
    final win = box.deflate(8);
    for (var k = 0; k < 3; k++) {
      final pane = Rect.fromLTWH(
        win.left + win.width * k / 3,
        win.top,
        win.width / 3,
        win.height,
      );
      paintPane(
        canvas,
        Path()..addRect(pane),
        Color.lerp(
          const Color(0xFF7A2A0A),
          const Color(0xFFFFA24A),
          pulse * (0.7 + 0.3 * ((k + 1) % 2)),
        )!,
        _kGaugeGlass,
        lead: 2.2,
      );
    }
    paintLead(
      canvas,
      Path()..addRect(win),
      _kGaugeGlass,
      width: 2.6,
      light: _kGaugeGlass.gold,
    );
  }

  /// A crucible corner's wanted elements, as panes of their own glass in the
  /// socket's ring — silver-capped once the corner is sealed.
  void _drawCornerGlass(
    Canvas canvas,
    Offset c,
    List<String> wants,
    bool shut,
  ) {
    const r0 = 16.0, r1 = 28.0;
    final sweep = 2 * pi / wants.length;
    for (var i = 0; i < wants.length; i++) {
      final a0 = -pi / 2 + i * sweep + (wants.length > 1 ? 0.08 : 0.0);
      final a1 = a0 + sweep - (wants.length > 1 ? 0.16 : 0.0);
      final col = Color.lerp(elementColor(wants[i]), Colors.white, 0.34)!;
      paintPane(
        canvas,
        sectorPath(c, r0, r1, a0, a1),
        shut ? col : Color.lerp(_kGaugeGlass.frostAt(i), col, 0.55)!,
        _kGaugeGlass,
        lead: 2.2,
      );
    }
    paintRondel(
      canvas,
      c,
      r0 - 2,
      _kGaugeGlass,
      fill: shut ? _kGaugeGlass.silver : _kGaugeGlass.smoke,
      rim: shut ? 1.0 : 0.5,
    );
  }

  /// HIDDEN HARMONY, SET. The sigil sinks into the plinth as the rite binds —
  /// the ring shrinking down onto the stone, the triangle following — and
  /// then it is an inlay of steam glass for good, with condensation running
  /// down its panes. What you took leaves a mark, not a hole.
  void _drawHarmonyInlay(Canvas canvas, Offset cache) {
    final s = _harmonySet.clamp(0.0, 1.0);
    if (s <= 0) return;
    final seat = cache + const Offset(0, 16);
    final sink = Curves.easeInOutCubic.transform(s);
    // Descending: the sigil drops from where it hung to the plinth's top.
    final at = Offset.lerp(cache, seat, sink)!;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, 1 - 0.38 * sink); // lying down into the stone
    const r = 26.0;
    for (var k = 0; k < 3; k++) {
      final a0 = -pi / 2 + k * 2 * pi / 3;
      final a1 = a0 + 2 * pi / 3;
      final tri = Path()
        ..moveTo(0, 0)
        ..lineTo(cos(a0) * r, sin(a0) * r)
        ..lineTo(cos(a1) * r, sin(a1) * r)
        ..close();
      paintPane(
        canvas,
        tri,
        Color.lerp(
          _kGaugeGlass.live,
          _kGaugeGlass.liveCore,
          0.25 + 0.2 * k,
        )!.withValues(alpha: 0.4 + 0.5 * sink),
        _kGaugeGlass,
        lead: 2.2,
      );
    }
    paintLead(
      canvas,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
      _kGaugeGlass,
      width: 3,
      light: _kGaugeGlass.gold,
    );
    canvas.restore();
    if (s >= 1) {
      // Condensation: beads forming at the rim and running down the glass.
      for (var i = 0; i < 4; i++) {
        final t = ((_moltenPulse * 0.25 + i / 4) % 1.0);
        final x = seat.dx - 14 + i * 9.0;
        canvas.drawCircle(
          Offset(x, seat.dy - 8 + 14 * t),
          1.4,
          Paint()..color = Colors.white.withValues(alpha: 0.55 * (1 - t)),
        );
      }
    }
    if (_fx.ready) {
      // Found, it keeps a cool light of its own in a room the foundry forgot.
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        40 + 12 * s,
        _kGaugeGlass.live.withValues(
          alpha: s < 1
              ? 0.35 * (1 - s) + 0.12
              : 0.14 + 0.04 * sin(_moltenPulse),
        ),
      );
    }
  }
}
