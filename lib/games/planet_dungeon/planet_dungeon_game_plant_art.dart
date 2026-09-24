// lib/games/planet_dungeon/planet_dungeon_game_plant_art.dart
//
// VERDANTHOS, IN GLASS (docs/dungeons.md §7.11) — Plant's glass, as a part of
// planet_dungeon_game.dart.
//
// The crypt already had its architecture (the wall course, loculi, columns)
// and a floor built to be read at two sizes, so the stone stays; its ledger
// stones — ~60 slabs, each clipped and stroked every frame — are now BAKED
// once per room at each size. Doors are garden glass in the stone. The glass:
//
//   · a grave-lamp burns in a chimney of leaded glass, smoked while dead;
//   · the growth altar's bowl is three panes — loam, seed, sun — each lit as
//     its step is laid, with a gold heart once the bloom wakes;
//   · and THE UNSEEN SHADE — the maxim — used to leave a run-state tree that
//     was gone next descent. What grew in the shade is now a tree of leaded
//     glass: the trunk rises, then the canopy opens pane by pane as the rite
//     binds, and it stands in the gallery on every later descent.

part of 'planet_dungeon_game.dart';

const GlassPalette _kVerdantGlass = kVerdantGlass;

final Map<String, ui.Picture> _cryptLedgerCache = {};

extension VerdantCryptArt on PlanetDungeonGame {
  void _updatePlantGlass(double dt) {
    final target =
        discoveredClouds.contains(kPlantUnseenShadeEggId) ||
            _ritePendingEgg == kPlantUnseenShadeEggId
        ? 1.0
        : 0.0;
    if (_shadeGrown < 0) {
      _shadeGrown = target;
    } else if (_shadeGrown < target) {
      _shadeGrown = min(target, _shadeGrown + dt / 2.6);
    } else if (_shadeGrown > target) {
      _shadeGrown = target;
    }
  }

  void _renderCryptLedger(
    Canvas canvas,
    DungeonRoom room,
    _CryptGround g,
    bool tiny,
  ) {
    final b = room.bounds;
    canvas.drawPicture(
      _cryptLedgerCache.putIfAbsent(
        '${room.id}|$tiny|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          _paintCryptLedger(c, g, tiny);
          _paintCryptMotif(c, room);
          return rec.endRecording();
        },
      ),
    );
  }

  /// A grave-lamp's chimney: two leaded panes round the flame.
  void _drawLampChimney(Canvas canvas, Offset at, double k, bool lit) {
    final top = at.dy - 40 * k, foot = at.dy - 6 * k;
    for (final side in const [-1.0, 1.0]) {
      final pane = Path()
        ..moveTo(at.dx, top)
        ..lineTo(at.dx + side * 11 * k, top + 4 * k)
        ..lineTo(at.dx + side * 14 * k, foot)
        ..lineTo(at.dx, foot)
        ..close();
      paintPane(
        canvas,
        pane,
        lit
            ? _kVerdantGlass.live.withValues(alpha: 0.3)
            : _kVerdantGlass.smoke.withValues(alpha: 0.7),
        _kVerdantGlass,
        lead: 1.6 * k.clamp(0.7, 1.0),
      );
    }
    if (lit) {
      paintStreak(
        canvas,
        Rect.fromLTRB(at.dx - 12 * k, top, at.dx, foot),
        opacity: 0.5,
      );
    }
  }

  /// The growth altar's bowl: loam, seed and sun, a pane each.
  void _drawAltarGlass(Canvas canvas, Offset c, Rect bowl) {
    const tones = [Color(0xFFB8864A), Color(0xFF8CC060), Color(0xFFF2D287)];
    final rx = bowl.width / 2, ry = bowl.height / 2;
    for (var i = 0; i < 3; i++) {
      final a0 = -pi / 2 + i * 2 * pi / 3 + 0.05;
      final pane = ellipseSectorPath(
        c,
        rx * 0.3,
        ry * 0.3,
        rx * 0.92,
        ry * 0.92,
        a0,
        a0 + 2 * pi / 3 - 0.1,
      );
      final laid = crypt.bloomStep > i;
      paintPane(
        canvas,
        pane,
        laid ? tones[i] : _kVerdantGlass.frostAt(i),
        _kVerdantGlass,
        lead: 2,
        opacity: laid ? 0.9 : 0.7,
      );
      if (laid) paintStreak(canvas, pane.getBounds().deflate(4), opacity: 0.35);
    }
    paintRondel(
      canvas,
      c,
      rx * 0.28,
      _kVerdantGlass,
      fill: crypt.bloomWoken ? _kVerdantGlass.liveCore : _kVerdantGlass.smoke,
      rim: crypt.bloomWoken ? 1 : 0.4,
      lead: 2,
    );
    if (crypt.bloomWoken && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        rx * 1.4,
        _kVerdantGlass.gold.withValues(alpha: 0.22),
      );
    }
  }

  /// THE UNSEEN SHADE: a tree of leaded glass, grown where the shade lay.
  void _drawShadeTree(Canvas canvas, Offset root) {
    // A found maxim stands even before this frame's easing has caught up.
    final o = _shadeGrown < 0 ? 1.0 : _shadeGrown.clamp(0.0, 1.0);
    if (o <= 0) return;
    final rise = (o / 0.35).clamp(0.0, 1.0);
    final crown = root - Offset(0, 150 * rise);
    // The trunk, carved bark, rising.
    paintContactShadow(canvas, root + const Offset(0, 6), 70, 18);
    final trunk = Path()
      ..moveTo(root.dx - 16, root.dy)
      ..quadraticBezierTo(
        root.dx - 8,
        root.dy - 70 * rise,
        crown.dx - 6,
        crown.dy + 40,
      )
      ..lineTo(crown.dx + 6, crown.dy + 40)
      ..quadraticBezierTo(
        root.dx + 8,
        root.dy - 70 * rise,
        root.dx + 16,
        root.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = VerdantCryptDungeon._kCryptBark);
    if (rise < 1) return;
    final open = ((o - 0.35) / 0.65).clamp(0.0, 1.0);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        crown,
        110,
        _kVerdantGlass.live.withValues(
          alpha: o < 1 ? 0.28 * open : 0.16 + 0.04 * sin(_time * 0.9),
        ),
      );
    }
    // The canopy: leaves of leaded glass fanned out from the crown — a back
    // layer of long dark ones, then a front layer of short bright ones —
    // opening in turn as the rite binds, the fruit last.
    const leaf = [
      Color(0xFF6FA84E),
      Color(0xFF4E8B4A),
      Color(0xFF8CC060),
      Color(0xFF3E7240),
    ];
    for (final (n, len, wide, spread, delay, shade) in const [
      (9, 78.0, 30.0, 1.25, 0.0, 0.25),
      (7, 52.0, 24.0, 1.05, 0.4, 0.0),
    ]) {
      for (var i = 0; i < n; i++) {
        final k = ((open - delay - i * 0.03) / 0.35).clamp(0.0, 1.0);
        if (k <= 0) continue;
        // Fanned over the top: from low-left, up, to low-right.
        final a = -pi / 2 + (i / (n - 1) - 0.5) * 2 * spread;
        final dir = Offset(cos(a), sin(a) * 0.85);
        final tip = crown + dir * (len * k);
        final base = crown + dir * 6;
        final side = Offset(-dir.dy, dir.dx) * (wide * 0.5 * k);
        final mid = Offset.lerp(base, tip, 0.5)!;
        final pane = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            mid.dx + side.dx,
            mid.dy + side.dy,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            mid.dx - side.dx,
            mid.dy - side.dy,
            base.dx,
            base.dy,
          )
          ..close();
        paintPane(
          canvas,
          pane,
          Color.lerp(leaf[(i * 3 + n) % leaf.length], Colors.black, shade)!,
          _kVerdantGlass,
          lead: 2,
        );
        // The midrib, in the lead.
        canvas.drawLine(
          base,
          Offset.lerp(base, tip, 0.85)!,
          Paint()
            ..strokeWidth = 1.1
            ..color = _kVerdantGlass.lead.withValues(alpha: 0.8),
        );
      }
    }
    final heart = ((open - 0.8) / 0.2).clamp(0.0, 1.0);
    if (heart > 0) {
      paintRondel(
        canvas,
        crown,
        12 * heart,
        _kVerdantGlass,
        fill: const Color(0xFFF2D287),
        lead: 2,
      );
    }
    paintStreak(
      canvas,
      Rect.fromCenter(
        center: crown - const Offset(0, 30),
        width: 90,
        height: 60,
      ),
      opacity: 0.4 * open,
    );
  }

  /// THE ROOM'S OWN CARVING (2026-09-24). With the paving quietened, half
  /// the crypt was one chamber: joints, vines, a fixture. Each room now has
  /// one thing cut into its floor that no other room has.
  void _paintCryptMotif(Canvas c, DungeonRoom room) {
    final r = room.bounds;
    Offset at(double fx, double fy) =>
        Offset(r.left + r.width * fx, r.top + r.height * fy);
    void groove(Path path, {double w = 3}) {
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.6 + 2
          ..strokeCap = StrokeCap.round
          ..color = VerdantCryptDungeon._kCryptSeam.withValues(alpha: 0.85),
      );
      c.drawPath(
        path.shift(const Offset(0, 2.2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, w * 0.4)
          ..strokeCap = StrokeCap.round
          ..color = VerdantCryptDungeon._kCryptBone.withValues(alpha: 0.32),
      );
    }

    void ring(Offset o, double rad, {double w = 3}) => groove(
      Path()..addOval(Rect.fromCircle(center: o, radius: rad)),
      w: w,
    );
    void petals(Offset o, int n, double r0, double r1, {double w = 2}) {
      for (var i = 0; i < n; i++) {
        final a = i / n * 2 * pi;
        final dir = Offset(cos(a), sin(a));
        final side = Offset(-dir.dy, dir.dx) * (r1 - r0) * 0.32;
        final base = o + dir * r0, tip = o + dir * r1;
        final mid = Offset.lerp(base, tip, 0.5)!;
        groove(
          Path()
            ..moveTo(base.dx, base.dy)
            ..quadraticBezierTo(
              mid.dx + side.dx,
              mid.dy + side.dy,
              tip.dx,
              tip.dy,
            )
            ..quadraticBezierTo(
              mid.dx - side.dx,
              mid.dy - side.dy,
              base.dx,
              base.dy,
            ),
          w: w,
        );
      }
    }

    switch (room.id) {
      case 'root_porch':
        // A root-boss: the knot the whole crypt's roots come out of.
        final o = at(0.64, 0.6);
        ring(o, 26, w: 4);
        ring(o, 44, w: 2);
        for (var i = 0; i < 7; i++) {
          final a = i / 7 * 2 * pi + 0.3;
          final bend = a + 0.5;
          groove(
            Path()
              ..moveTo(o.dx + cos(a) * 44, o.dy + sin(a) * 44)
              ..quadraticBezierTo(
                o.dx + cos(bend) * 80,
                o.dy + sin(bend) * 80,
                o.dx + cos(a + 0.9) * 120,
                o.dy + sin(a + 0.9) * 120,
              ),
            w: 2.4,
          );
        }
      case 'mosswalk':
        // The walk itself: a carved runner down the length of the room.
        final y0 = r.top + r.height * 0.44, y1 = r.top + r.height * 0.6;
        groove(
          Path()
            ..moveTo(r.left + 40, y0)
            ..lineTo(r.right - 40, y0),
          w: 2.6,
        );
        groove(
          Path()
            ..moveTo(r.left + 40, y1)
            ..lineTo(r.right - 40, y1),
          w: 2.6,
        );
        for (var x = r.left + 70; x < r.right - 60; x += 56) {
          final m = (y0 + y1) / 2;
          groove(
            Path()
              ..moveTo(x, y0 + 8)
              ..lineTo(x + 18, m)
              ..lineTo(x, y1 - 8),
            w: 1.6,
          );
        }
      case 'lantern_court':
        // A paved court: one great ring, jointed like a clock.
        final o = at(0.5, 0.56);
        ring(o, 180, w: 3.4);
        ring(o, 150, w: 1.6);
        for (var i = 0; i < 16; i++) {
          final a = i / 16 * 2 * pi;
          groove(
            Path()
              ..moveTo(o.dx + cos(a) * 150, o.dy + sin(a) * 150)
              ..lineTo(o.dx + cos(a) * 180, o.dy + sin(a) * 180),
            w: 1.6,
          );
        }
      case 'fern_gallery':
        // A gallery: two long kerbs, and fronds cut along them.
        for (final fy in const [0.24, 0.8]) {
          final y = r.top + r.height * fy;
          groove(
            Path()
              ..moveTo(r.left + 60, y)
              ..lineTo(r.right - 60, y),
            w: 2.4,
          );
          for (var x = r.left + 90; x < r.right - 80; x += 70) {
            for (final s in const [-1.0, 1.0]) {
              groove(
                Path()
                  ..moveTo(x, y)
                  ..quadraticBezierTo(x + 10, y + s * 8, x + 24, y + s * 14),
                w: 1.2,
              );
            }
          }
        }
      case 'crypt_niche':
        // A ledger slab with its effigy: a figure laid out in a leaf shroud.
        final o = at(0.5, 0.64);
        final slab = Rect.fromCenter(center: o, width: 170, height: 64);
        groove(Path()..addRect(slab), w: 3);
        groove(Path()..addRect(slab.deflate(8)), w: 1.2);
        groove(
          Path()
            ..addOval(Rect.fromCircle(center: o.translate(-58, 0), radius: 13)),
          w: 2,
        );
        groove(
          Path()
            ..moveTo(o.dx - 44, o.dy)
            ..quadraticBezierTo(o.dx + 10, o.dy - 22, o.dx + 70, o.dy)
            ..quadraticBezierTo(o.dx + 10, o.dy + 22, o.dx - 44, o.dy),
          w: 2,
        );
      case 'bloom_hall':
        // A flower cut into the hall's floor, eight petals and a double eye.
        final o = at(0.56, 0.52);
        petals(o, 8, 22, 96, w: 2.4);
        ring(o, 22, w: 3);
        ring(o, 10, w: 1.6);
      case 'botanica_heart':
        // The arena: a ring of petals round the flower's own floor.
        final o = at(0.5, 0.5);
        ring(o, 230, w: 3.4);
        petals(o, 16, 230, 290, w: 1.8);
    }
  }
}
