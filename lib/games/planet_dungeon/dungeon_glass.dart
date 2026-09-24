// lib/games/planet_dungeon/dungeon_glass.dart
//
// THE GLASS-INLAY KIT (docs/dungeons.md §7.11).
//
// Stone is the world, glass is the signal. A room is a carved diorama of its
// planet's stone, and leaded glass appears only on what the player acts on,
// reads, or changes. This file is the shared vocabulary every planet paints
// that with: a palette, panes held in lead, rondels, lancets, rose windows,
// and the carved stone they sit in.
//
// Nothing here knows about a game or a room. Everything is a pure paint call
// over a Canvas, so a planet can bake its static half into a `ui.Picture`
// once and draw only the live panes per frame. No MaskFilter anywhere — glow
// belongs to the baked sprites in planet_dungeon_fx.dart.

import 'dart:math';

import 'package:flutter/material.dart';

/// One planet's glass and stone.
class GlassPalette {
  const GlassPalette({
    required this.lead,
    required this.leadLight,
    required this.frost,
    required this.liveDeep,
    required this.live,
    required this.liveCore,
    required this.smoke,
    required this.silver,
    required this.gold,
    required this.goldDeep,
    required this.stoneTop,
    required this.stoneFace,
    required this.stoneFoot,
    required this.floor,
    required this.floorAlt,
    required this.joint,
  });

  /// The came the panes are held in, and the warm line it catches.
  final Color lead;
  final Color leadLight;

  /// Inert panes: dull, translucent, never bright. Picked from per pane so a
  /// field of them never reads as one flat sheet.
  final List<Color> frost;

  /// The planet's LIVE glass, from its deep edge to its white-hot heart —
  /// lit, rung, burning, powered.
  final Color liveDeep;
  final Color live;
  final Color liveCore;

  /// Sealed or hidden: opaque, smoked.
  final Color smoke;

  /// Solved or banked.
  final Color silver;

  /// The rim of anything you can act on.
  final Color gold;
  final Color goldDeep;

  /// Carved stone: the lit top of a block, its face, and its dark foot.
  final Color stoneTop;
  final Color stoneFace;
  final Color stoneFoot;

  /// The floor flags (two tints, alternated), and the joints between them.
  final Color floor;
  final Color floorAlt;
  final Color joint;

  Color frostAt(int i) => frost[i.abs() % frost.length];

  /// Live glass at [heat] 0..1: frost-dark → deep → live → core.
  Color heat(double heat, {Color? cold}) {
    final h = heat.clamp(0.0, 1.0);
    final c0 = cold ?? frost.first;
    if (h < 0.34) return Color.lerp(c0, liveDeep, h / 0.34)!;
    if (h < 0.78) return Color.lerp(liveDeep, live, (h - 0.34) / 0.44)!;
    return Color.lerp(live, liveCore, (h - 0.78) / 0.22)!;
  }
}

/// The Cinder Cathedral: ember glass in soot-dark lead, set in warm basalt.
const GlassPalette kCinderGlass = GlassPalette(
  lead: Color(0xFF070403),
  leadLight: Color(0xFFB08458),
  frost: [
    Color(0xFF3A1509),
    Color(0xFF4A1D0C),
    Color(0xFF2E1107),
    Color(0xFF451A0A),
    Color(0xFF361309),
  ],
  liveDeep: Color(0xFFB8300E),
  live: Color(0xFFFF8A2A),
  liveCore: Color(0xFFFFE2A6),
  smoke: Color(0xFF1C1715),
  silver: Color(0xFFD9DEE2),
  gold: Color(0xFFE4C16A),
  goldDeep: Color(0xFF8A6A34),
  stoneTop: Color(0xFF6E5646),
  stoneFace: Color(0xFF3B2C24),
  stoneFoot: Color(0xFF120B08),
  floor: Color(0xFF2C1F19),
  floorAlt: Color(0xFF231812),
  joint: Color(0xFF0B0706),
);

/// The Molten Reliquary: white-hot glass in iron came, set in cooled basalt.
/// Machinery, not a cathedral — the stone is cold and blue-black and the rims
/// are brass, so a Lava screenshot never reads as Fire's candlelight (§5.5).
const GlassPalette kBasaltGlass = GlassPalette(
  lead: Color(0xFF07080A),
  leadLight: Color(0xFF7C8B99),
  frost: [
    Color(0xFF2A1509),
    Color(0xFF331A0C),
    Color(0xFF241208),
    Color(0xFF2E170B),
    Color(0xFF281309),
  ],
  liveDeep: Color(0xFFB0360C),
  live: Color(0xFFFF7A22),
  liveCore: Color(0xFFFFF1CF),
  smoke: Color(0xFF15181B),
  silver: Color(0xFFBFD4E2),
  gold: Color(0xFFD9A25A),
  goldDeep: Color(0xFF7A5A34),
  stoneTop: Color(0xFF4A4642),
  stoneFace: Color(0xFF2A2724),
  stoneFoot: Color(0xFF0B0A09),
  floor: Color(0xFF15120F),
  floorAlt: Color(0xFF0E0C0A),
  joint: Color(0xFF060504),
);

/// The Wind-Crown Spire: sky glass in navy lead, set in pale cloud-slate.
/// Open air, not a building: the stone is light, the glass is the sky's own
/// colour, and the live pane runs cyan to white rather than ember.
const GlassPalette kZephyrGlass = GlassPalette(
  lead: Color(0xFF070A10),
  leadLight: Color(0xFFBFD2E6),
  frost: [
    Color(0xFF1B2A40),
    Color(0xFF22324A),
    Color(0xFF18263A),
    Color(0xFF26384F),
    Color(0xFF1D2C44),
  ],
  liveDeep: Color(0xFF2E7FA8),
  live: Color(0xFF7FD4F0),
  liveCore: Color(0xFFF2FBFF),
  smoke: Color(0xFF141A24),
  silver: Color(0xFFE6EEF6),
  gold: Color(0xFFE4C16A),
  goldDeep: Color(0xFF8A6A34),
  stoneTop: Color(0xFF9AA8B8),
  stoneFace: Color(0xFF4A5666),
  stoneFoot: Color(0xFF121822),
  floor: Color(0xFF34435A),
  floorAlt: Color(0xFF2A374B),
  joint: Color(0xFF1A222E),
);

/// The Storm Circuit: arc-blue glass in steel came, set in bolted iron plate.
/// Machinery like the Reliquary, but cold: the live pane runs electric blue
/// to white, and the rims are brass.
const GlassPalette kVoltGlass = GlassPalette(
  lead: Color(0xFF06080C),
  leadLight: Color(0xFF9FB8D0),
  frost: [
    Color(0xFF16202C),
    Color(0xFF1B2634),
    Color(0xFF141C27),
    Color(0xFF1E2A38),
    Color(0xFF182330),
  ],
  liveDeep: Color(0xFF2F5FB8),
  live: Color(0xFF9FD4FF),
  liveCore: Color(0xFFF4FAFF),
  smoke: Color(0xFF10151C),
  silver: Color(0xFFE6F0F8),
  gold: Color(0xFFE9D27A),
  goldDeep: Color(0xFF7A6A44),
  stoneTop: Color(0xFF4E5968),
  stoneFace: Color(0xFF28303B),
  stoneFoot: Color(0xFF0A0D12),
  floor: Color(0xFF141B25),
  floorAlt: Color(0xFF10161F),
  joint: Color(0xFF04070C),
);

/// The Buried Giant: sea-green crystal in bone-dark lead, set in the barrow's
/// earth and dolmen stone. Earth + Lightning makes Crystal — this planet's
/// glass is the thing its own alchemy grows.
const GlassPalette kBarrowGlass = GlassPalette(
  lead: Color(0xFF0A0805),
  leadLight: Color(0xFFD8B878),
  frost: [
    Color(0xFF221A10),
    Color(0xFF2A2014),
    Color(0xFF1E170E),
    Color(0xFF2E2416),
    Color(0xFF261D12),
  ],
  liveDeep: Color(0xFF2E5A56),
  live: Color(0xFF8FCFC4),
  liveCore: Color(0xFFE6FAF5),
  smoke: Color(0xFF15100A),
  silver: Color(0xFFE6F0EC),
  gold: Color(0xFFD8B878),
  goldDeep: Color(0xFF8A6E48),
  stoneTop: Color(0xFF6E5A3E),
  stoneFace: Color(0xFF3A2E1E),
  stoneFoot: Color(0xFF100C07),
  floor: Color(0xFF1E1812),
  floorAlt: Color(0xFF16110B),
  joint: Color(0xFF0A0805),
);

/// The Mirror-Tide Temple: sea glass in pewter came, set in pale sea-marble.
/// The moon is the temple's light, so its silver is the brightest glass it
/// keeps; live panes run from deep-water teal to foam.
const GlassPalette kTempleGlass = GlassPalette(
  lead: Color(0xFF060C10),
  leadLight: Color(0xFFB8D8E8),
  frost: [
    Color(0xFF10222A),
    Color(0xFF152A33),
    Color(0xFF0E1E25),
    Color(0xFF183038),
    Color(0xFF12262E),
  ],
  liveDeep: Color(0xFF1F6F86),
  live: Color(0xFF7FD6E6),
  liveCore: Color(0xFFEAFBFF),
  smoke: Color(0xFF0B161C),
  silver: Color(0xFFE6F2F6),
  gold: Color(0xFFD9C27A),
  goldDeep: Color(0xFF7A6A44),
  stoneTop: Color(0xFF5E7480),
  stoneFace: Color(0xFF2E3E48),
  stoneFoot: Color(0xFF0A1218),
  floor: Color(0xFF16262E),
  floorAlt: Color(0xFF122028),
  joint: Color(0xFF060C10),
);

/// Vaporis: gauge glass in iron came, set in firebrick. The live pane is the
/// white of live steam; the rims are the boiler house's brass.
const GlassPalette kVaporGlass = GlassPalette(
  lead: Color(0xFF08090B),
  leadLight: Color(0xFFBFD6DE),
  frost: [
    Color(0xFF1C2226),
    Color(0xFF22292E),
    Color(0xFF181D21),
    Color(0xFF262D32),
    Color(0xFF1E2428),
  ],
  liveDeep: Color(0xFF2E7A8A),
  live: Color(0xFF8FE0EC),
  liveCore: Color(0xFFF2FCFF),
  smoke: Color(0xFF14171A),
  silver: Color(0xFFE6EEF2),
  gold: Color(0xFFE0A24A),
  goldDeep: Color(0xFF8A6030),
  stoneTop: Color(0xFF5E4838),
  stoneFace: Color(0xFF3A2A20),
  stoneFoot: Color(0xFF110C09),
  floor: Color(0xFF2A2119),
  floorAlt: Color(0xFF221A14),
  joint: Color(0xFF0C0806),
);

/// The Venom Monastery: apothecary glass — bottle green and phial violet — in
/// black lead, set in the house's bone-grey stone.
const GlassPalette kVenomGlass = GlassPalette(
  lead: Color(0xFF07090A),
  leadLight: Color(0xFFC8C0A8),
  frost: [
    Color(0xFF16201A),
    Color(0xFF1B2620),
    Color(0xFF131C17),
    Color(0xFF1F2A22),
    Color(0xFF18221C),
  ],
  liveDeep: Color(0xFF2E5A2A),
  live: Color(0xFF8FCF6A),
  liveCore: Color(0xFFEFFBE0),
  smoke: Color(0xFF0E120F),
  silver: Color(0xFFF2E7A8),
  gold: Color(0xFFC8A860),
  goldDeep: Color(0xFF6E5A36),
  stoneTop: Color(0xFF5A5C50),
  stoneFace: Color(0xFF2E302A),
  stoneFoot: Color(0xFF0C0D0B),
  floor: Color(0xFF1A1E18),
  floorAlt: Color(0xFF151813),
  joint: Color(0xFF07090A),
);

/// Glacius: frost glass in pewter came, set in the observatory's blue stone.
/// The live pane is ice-light — pale blue to white — and the rims are the
/// instrument's brass.
const GlassPalette kFrostGlass = GlassPalette(
  lead: Color(0xFF050B10),
  leadLight: Color(0xFFBFE6FA),
  frost: [
    Color(0xFF1B3350),
    Color(0xFF20395A),
    Color(0xFF172C47),
    Color(0xFF243F60),
    Color(0xFF1A3048),
  ],
  liveDeep: Color(0xFF3A7FA8),
  live: Color(0xFFA9DCF5),
  liveCore: Color(0xFFF2FBFF),
  smoke: Color(0xFF0B1A24),
  silver: Color(0xFFEAF6FF),
  gold: Color(0xFFE4C16A),
  goldDeep: Color(0xFF8C6F36),
  stoneTop: Color(0xFF5C7080),
  stoneFace: Color(0xFF2C3A46),
  stoneFoot: Color(0xFF081119),
  floor: Color(0xFF1C2E3C),
  floorAlt: Color(0xFF16242F),
  joint: Color(0xFF050B10),
);

/// Hemavorn: garnet glass — crimson and the bone-white of a valve leaf — in
/// black lead, and a PORPHYRY that looks like the heart was cut from it.
const GlassPalette kSanguineGlass = GlassPalette(
  lead: Color(0xFF0C0406),
  leadLight: Color(0xFFF0D0C8),
  frost: [
    Color(0xFF3A1A20),
    Color(0xFF442028),
    Color(0xFF34161C),
    Color(0xFF4C2430),
    Color(0xFF3E1C24),
  ],
  liveDeep: Color(0xFF6A0E20),
  live: Color(0xFFD8334E),
  liveCore: Color(0xFFFFE4E8),
  smoke: Color(0xFF14080B),
  silver: Color(0xFFE6D9C8),
  gold: Color(0xFFE4C16A),
  goldDeep: Color(0xFF6E5228),
  stoneTop: Color(0xFF6A3A3C),
  stoneFace: Color(0xFF3A1C20),
  stoneFoot: Color(0xFF0E0406),
  floor: Color(0xFF2A1216),
  floorAlt: Color(0xFF240E12),
  joint: Color(0xFF0C0406),
);

/// Lumenhold: archive glass — lamp gold and vellum cream — in dark bronze
/// lead, and the archive's pale limestone gone grey with dust.
const GlassPalette kLumenGlass = GlassPalette(
  lead: Color(0xFF0C0A08),
  leadLight: Color(0xFFF2E6C0),
  frost: [
    Color(0xFF3A3C44),
    Color(0xFF42444C),
    Color(0xFF36383F),
    Color(0xFF4A4B52),
    Color(0xFF3E4048),
  ],
  liveDeep: Color(0xFF8A6420),
  live: Color(0xFFFFE082),
  liveCore: Color(0xFFFFF6DC),
  smoke: Color(0xFF13161F),
  silver: Color(0xFFEDE8DA),
  gold: Color(0xFFE4C16A),
  goldDeep: Color(0xFF6E5A30),
  stoneTop: Color(0xFF8A8474),
  stoneFace: Color(0xFF4A4840),
  stoneFoot: Color(0xFF12120E),
  floor: Color(0xFF2E2E30),
  floorAlt: Color(0xFF28282A),
  joint: Color(0xFF0C0C0A),
);

/// Nythralor: umbra glass — black glass with violet in it, and a lamp's
/// ember — in iron lead, and the vault's pewter-grey ashlar.
const GlassPalette kUmbraGlass = GlassPalette(
  lead: Color(0xFF050408),
  leadLight: Color(0xFFC8B8E8),
  frost: [
    Color(0xFF26222E),
    Color(0xFF2C2836),
    Color(0xFF221E2A),
    Color(0xFF322C3C),
    Color(0xFF2A2532),
  ],
  liveDeep: Color(0xFF3A2462),
  live: Color(0xFF9A74D8),
  liveCore: Color(0xFFF0E8FF),
  smoke: Color(0xFF0B0A12),
  silver: Color(0xFFE2DEEC),
  gold: Color(0xFFE0B15C),
  goldDeep: Color(0xFF6B5A2E),
  stoneTop: Color(0xFF5E5C6C),
  stoneFace: Color(0xFF302E3A),
  stoneFoot: Color(0xFF09080E),
  floor: Color(0xFF24222C),
  floorAlt: Color(0xFF1E1C26),
  joint: Color(0xFF050408),
);

/// Requia: grave glass — the cold blue-grey the dead see by, and a candle's
/// ember — in black lead, and churchyard stone gone green at the foot.
const GlassPalette kWraithGlass = GlassPalette(
  lead: Color(0xFF07090C),
  leadLight: Color(0xFFC8DCE4),
  frost: [
    Color(0xFF2E383E),
    Color(0xFF344048),
    Color(0xFF2A3238),
    Color(0xFF3A464E),
    Color(0xFF303A42),
  ],
  liveDeep: Color(0xFF2E4A58),
  live: Color(0xFF8FB6C4),
  liveCore: Color(0xFFEAF4F8),
  smoke: Color(0xFF101418),
  silver: Color(0xFFE2EAEE),
  gold: Color(0xFFD9A24C),
  goldDeep: Color(0xFF6E5228),
  stoneTop: Color(0xFF6B6857),
  stoneFace: Color(0xFF383A34),
  stoneFoot: Color(0xFF0C0E0C),
  floor: Color(0xFF26282A),
  floorAlt: Color(0xFF202224),
  joint: Color(0xFF08090A),
);

/// Verdanthos: garden glass — leaf green and lamp gold — in black lead, and
/// limestone being eaten by a garden.
const GlassPalette kVerdantGlass = GlassPalette(
  lead: Color(0xFF0A0C08),
  leadLight: Color(0xFFD8E4B8),
  frost: [
    Color(0xFF34402C),
    Color(0xFF3C4A32),
    Color(0xFF2E3A28),
    Color(0xFF445238),
    Color(0xFF384430),
  ],
  liveDeep: Color(0xFF2E5A2A),
  live: Color(0xFF9CCB6A),
  liveCore: Color(0xFFF2F8D8),
  smoke: Color(0xFF141A12),
  silver: Color(0xFFE4ECD8),
  gold: Color(0xFFD4B060),
  goldDeep: Color(0xFF6E5A30),
  stoneTop: Color(0xFF7A745E),
  stoneFace: Color(0xFF3E4234),
  stoneFoot: Color(0xFF0E120C),
  floor: Color(0xFF2A3024),
  floorAlt: Color(0xFF232A1E),
  joint: Color(0xFF0A0C08),
);

/// Vitrea: prism glass — violet, and whatever colour a chamber was cut in —
/// in black lead, and the keep's grey-violet dressed stone.
const GlassPalette kPrismGlass = GlassPalette(
  lead: Color(0xFF0A0810),
  leadLight: Color(0xFFD8C8F0),
  frost: [
    Color(0xFF3A3448),
    Color(0xFF423B52),
    Color(0xFF352F42),
    Color(0xFF4A4258),
    Color(0xFF3E3750),
  ],
  liveDeep: Color(0xFF4A2E7A),
  live: Color(0xFFB89CF0),
  liveCore: Color(0xFFF4ECFF),
  smoke: Color(0xFF16121E),
  silver: Color(0xFFE6E2F0),
  gold: Color(0xFFD4B060),
  goldDeep: Color(0xFF6E5A30),
  stoneTop: Color(0xFF5A5268),
  stoneFace: Color(0xFF352F42),
  stoneFoot: Color(0xFF0E0B14),
  floor: Color(0xFF2A2536),
  floorAlt: Color(0xFF231F2E),
  joint: Color(0xFF0A0810),
);

/// Sablis: sand glass — the amber of a lamp through a dusty pane — in dark
/// bronze-black lead, and sandstone worn soft by a wind that never stops.
const GlassPalette kSandGlass = GlassPalette(
  lead: Color(0xFF0E0A06),
  leadLight: Color(0xFFE8D2A0),
  frost: [
    Color(0xFF4A4030),
    Color(0xFF52473A),
    Color(0xFF443A2A),
    Color(0xFF5A4E3C),
    Color(0xFF4E4434),
  ],
  liveDeep: Color(0xFF7A4A12),
  live: Color(0xFFE8B048),
  liveCore: Color(0xFFFFF0C0),
  smoke: Color(0xFF1C150D),
  silver: Color(0xFFE8E0C8),
  gold: Color(0xFFC8A050),
  goldDeep: Color(0xFF6E5428),
  stoneTop: Color(0xFF7A6446),
  stoneFace: Color(0xFF4A3B26),
  stoneFoot: Color(0xFF140E08),
  floor: Color(0xFF4A3C28),
  floorAlt: Color(0xFF40331F),
  joint: Color(0xFF1A120A),
);

/// Palusia: fen glass — bog-water teal and lotus pink — in black lead, and a
/// "stone" that is banked PEAT, because a fen has banks, not walls.
const GlassPalette kPeatGlass = GlassPalette(
  lead: Color(0xFF080705),
  leadLight: Color(0xFFB8C8A8),
  frost: [
    Color(0xFF1C241E),
    Color(0xFF222C24),
    Color(0xFF18201A),
    Color(0xFF26302A),
    Color(0xFF1E2620),
  ],
  liveDeep: Color(0xFF2E4A4E),
  live: Color(0xFF8FC0B8),
  liveCore: Color(0xFFEAF6F0),
  smoke: Color(0xFF14120E),
  silver: Color(0xFFF2D7E6),
  gold: Color(0xFFC8A860),
  goldDeep: Color(0xFF6E5A36),
  stoneTop: Color(0xFF4A3E2C),
  stoneFace: Color(0xFF2A2218),
  stoneFoot: Color(0xFF0C0A07),
  floor: Color(0xFF221C14),
  floorAlt: Color(0xFF1C1710),
  joint: Color(0xFF080705),
);

/// A tiny LCG, so baked fabric is identical on every device and every run.
class GlassRng {
  GlassRng(int seed) : _s = (seed & 0x7fffffff) | 1;
  int _s;

  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }

  double range(double a, double b) => a + next() * (b - a);
  int pick(int n) => (next() * n).floor().clamp(0, n - 1);
}

/// A stable seed from a room id and its bounds.
int glassSeed(String id, Rect bounds) {
  var h = 17;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return (h * 31 + bounds.width.round() * 7 + bounds.height.round()) &
      0x3fffffff;
}

// ── Panes and lead ──────────────────────────────────────────

/// Fill one pane.
void paintPaneFill(Canvas canvas, Path pane, Color fill, {double opacity = 1}) {
  canvas.drawPath(
    pane,
    Paint()..color = fill.withValues(alpha: fill.a * opacity.clamp(0.0, 1.0)),
  );
}

/// The lead a pane is held in: the came, then the warm line it catches.
void paintLead(
  Canvas canvas,
  Path path,
  GlassPalette p, {
  double width = 3.0,
  double opacity = 1.0,
  Color? light,
}) {
  final o = opacity.clamp(0.0, 1.0);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = p.lead.withValues(alpha: o),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, width * 0.22)
      ..strokeJoin = StrokeJoin.round
      ..color = (light ?? p.leadLight).withValues(alpha: 0.32 * o),
  );
}

/// A pane, filled and leaded, in one call.
void paintPane(
  Canvas canvas,
  Path pane,
  Color fill,
  GlassPalette p, {
  double lead = 3.0,
  double opacity = 1.0,
}) {
  paintPaneFill(canvas, pane, fill, opacity: opacity);
  paintLead(canvas, pane, p, width: lead, opacity: opacity);
}

/// The white streak that says a pane is CLEAR — made or active.
void paintStreak(Canvas canvas, Rect r, {double opacity = 1}) {
  final o = opacity.clamp(0.0, 1.0);
  if (o <= 0.01) return;
  canvas.drawLine(
    Offset(r.left + r.width * 0.18, r.top + r.height * 0.80),
    Offset(r.left + r.width * 0.55, r.top + r.height * 0.22),
    Paint()
      ..strokeWidth = max(1.2, r.shortestSide * 0.07)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.62 * o),
  );
  canvas.drawLine(
    Offset(r.left + r.width * 0.42, r.top + r.height * 0.86),
    Offset(r.left + r.width * 0.70, r.top + r.height * 0.44),
    Paint()
      ..strokeWidth = max(0.8, r.shortestSide * 0.035)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.40 * o),
  );
}

// ── Shapes ──────────────────────────────────────────────────

/// An annular sector (a rose-window pane), as a closed path.
Path sectorPath(Offset c, double r0, double r1, double a0, double a1) {
  final outer = Rect.fromCircle(center: c, radius: r1);
  final path = Path()
    ..moveTo(c.dx + r0 * cos(a0), c.dy + r0 * sin(a0))
    ..lineTo(c.dx + r1 * cos(a0), c.dy + r1 * sin(a0))
    ..arcTo(outer, a0, a1 - a0, false);
  if (r0 <= 0.01) {
    path.lineTo(c.dx, c.dy);
  } else {
    path.arcTo(Rect.fromCircle(center: c, radius: r0), a1, a0 - a1, false);
  }
  return path..close();
}

/// The same sector squashed into an ellipse — a pane in a collar laid flat on
/// the floor under three-quarter view.
Path ellipseSectorPath(
  Offset c,
  double rx0,
  double ry0,
  double rx1,
  double ry1,
  double a0,
  double a1, {
  int steps = 14,
}) {
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final a = a0 + (a1 - a0) * i / steps;
    final pt = Offset(c.dx + rx1 * cos(a), c.dy + ry1 * sin(a));
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  for (var i = steps; i >= 0; i--) {
    final a = a0 + (a1 - a0) * i / steps;
    path.lineTo(c.dx + rx0 * cos(a), c.dy + ry0 * sin(a));
  }
  return path..close();
}

/// A pointed (lancet) arch filling [r], its point toward [toward].
Path lancetPath(Rect r, AxisDirection toward) {
  // Built pointing UP in a unit frame, then mapped onto [r].
  Offset map(double u, double v) {
    // u: 0..1 across, v: 0 at the point … 1 at the sill.
    return switch (toward) {
      AxisDirection.up => Offset(r.left + u * r.width, r.top + v * r.height),
      AxisDirection.down => Offset(
        r.left + u * r.width,
        r.bottom - v * r.height,
      ),
      AxisDirection.left => Offset(r.left + v * r.width, r.top + u * r.height),
      AxisDirection.right => Offset(
        r.right - v * r.width,
        r.top + u * r.height,
      ),
    };
  }

  const spring = 0.42; // where the arch springs from the jambs
  final path = Path();
  final a = map(0, 1);
  path.moveTo(a.dx, a.dy);
  final b = map(0, spring);
  path.lineTo(b.dx, b.dy);
  final c1 = map(0, spring * 0.30);
  final tip = map(0.5, 0);
  path.quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy);
  final c2 = map(1, spring * 0.30);
  final e = map(1, spring);
  path.quadraticBezierTo(c2.dx, c2.dy, e.dx, e.dy);
  final f = map(1, 1);
  path.lineTo(f.dx, f.dy);
  return path..close();
}

/// A square-headed window with a shallow segmental arch, its head toward
/// [toward] — the machine planets' doorway, where a lancet would be a church.
Path archedHeadPath(Rect r, AxisDirection toward) {
  Offset map(double u, double v) => switch (toward) {
    AxisDirection.up => Offset(r.left + u * r.width, r.top + v * r.height),
    AxisDirection.down => Offset(r.left + u * r.width, r.bottom - v * r.height),
    AxisDirection.left => Offset(r.left + v * r.width, r.top + u * r.height),
    AxisDirection.right => Offset(r.right - v * r.width, r.top + u * r.height),
  };
  const shoulder = 0.16; // where the segmental head meets the jambs
  final a = map(0, 1), b = map(0, shoulder), c = map(0.5, -0.02);
  final e = map(1, shoulder), f = map(1, 1);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..quadraticBezierTo(c.dx, c.dy, e.dx, e.dy)
    ..lineTo(f.dx, f.dy)
    ..close();
}

/// One pane of a rose window: its ring, its place in the ring, and its middle.
class RosePane {
  RosePane(this.ring, this.index, this.angle, this.path, this.mid);
  final int ring;
  final int index;

  /// The angle through the pane's middle, radians.
  final double angle;
  final Path path;
  final Offset mid;
}

/// A rose window's panes. [rings] run inside-out as (inner r, outer r, panes,
/// twist); the twist staggers the lead so no spoke runs straight through.
List<RosePane> buildRose(Offset c, List<(double, double, int, double)> rings) {
  final out = <RosePane>[];
  for (var ring = 0; ring < rings.length; ring++) {
    final (r0, r1, n, twist) = rings[ring];
    for (var i = 0; i < n; i++) {
      final a0 = twist + i * 2 * pi / n;
      final a1 = twist + (i + 1) * 2 * pi / n;
      final am = (a0 + a1) / 2;
      final rm = (r0 + r1) / 2;
      out.add(
        RosePane(
          ring,
          i,
          am,
          sectorPath(c, r0, r1, a0, a1),
          c + Offset(cos(am), sin(am)) * rm,
        ),
      );
    }
  }
  return out;
}

/// Shortest angular distance, 0..π.
double angleGap(double a, double b) {
  var d = (a - b) % (2 * pi);
  if (d < 0) d += 2 * pi;
  return d > pi ? 2 * pi - d : d;
}

// ── Rondels: the rim of anything you can act on ─────────────

/// A gold-rimmed glass rondel. [fill] is its pane; [rim] the gold's strength.
void paintRondel(
  Canvas canvas,
  Offset c,
  double r,
  GlassPalette p, {
  Color? fill,
  double rim = 1.0,
  double lead = 3.0,
}) {
  canvas.drawCircle(c, r + lead * 0.6, Paint()..color = p.lead);
  canvas.drawCircle(c, r, Paint()..color = fill ?? p.frostAt(0));
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = p.gold.withValues(alpha: 0.85 * rim.clamp(0.0, 1.0)),
  );
  canvas.drawCircle(
    c,
    max(1.0, r - 4),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = p.gold.withValues(alpha: 0.32 * rim.clamp(0.0, 1.0)),
  );
}

// ── Carved stone ────────────────────────────────────────────

/// The soft dark a thing standing on the floor leaves under itself.
void paintContactShadow(
  Canvas canvas,
  Offset c,
  double w,
  double h, {
  double opacity = 0.5,
}) {
  canvas.drawOval(
    Rect.fromCenter(center: c, width: w, height: h),
    Paint()..color = Colors.black.withValues(alpha: opacity),
  );
  canvas.drawOval(
    Rect.fromCenter(center: c, width: w * 0.7, height: h * 0.7),
    Paint()..color = Colors.black.withValues(alpha: opacity * 0.5),
  );
}

/// A carved block seen from three-quarters: [top] is its lit top face, and
/// the face drops [height] below it into a dark foot.
void paintCarvedBlock(
  Canvas canvas,
  Rect top,
  double height,
  GlassPalette p, {
  double radius = 3,
  Color? topColor,
}) {
  final foot = Rect.fromLTRB(
    top.left,
    top.bottom,
    top.right,
    top.bottom + height,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      foot.translate(0, 4).inflate(3),
      Radius.circular(radius + 2),
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.38),
  );
  canvas.drawRect(
    foot,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.stoneFace, p.stoneFoot],
      ).createShader(foot),
  );
  final t = RRect.fromRectAndRadius(top, Radius.circular(radius));
  canvas.drawRRect(t, Paint()..color = topColor ?? p.stoneTop);
  // The lit arris along the near edge: the cue that says this stands up.
  canvas.drawLine(
    Offset(top.left + radius, top.bottom - 0.5),
    Offset(top.right - radius, top.bottom - 0.5),
    Paint()
      ..strokeWidth = 1.2
      ..color = Color.lerp(
        topColor ?? p.stoneTop,
        Colors.white,
        0.35,
      )!.withValues(alpha: 0.55),
  );
}

/// A carved disc (plinth, kerb, basin rim) seen from three-quarters: an
/// ellipse top and [height] of face under it.
void paintCarvedDisc(
  Canvas canvas,
  Offset c,
  double rx,
  double ry,
  double height,
  GlassPalette p, {
  Color? topColor,
}) {
  paintContactShadow(
    canvas,
    c + Offset(0, height + 3),
    rx * 2.3,
    ry * 2.2,
    opacity: 0.42,
  );
  final face = Path()
    ..moveTo(c.dx - rx, c.dy)
    ..lineTo(c.dx - rx, c.dy + height)
    ..arcTo(
      Rect.fromCenter(
        center: c + Offset(0, height),
        width: rx * 2,
        height: ry * 2,
      ),
      pi,
      -pi,
      false,
    )
    ..lineTo(c.dx + rx, c.dy)
    ..close();
  canvas.drawPath(
    face,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.stoneFace, p.stoneFoot],
      ).createShader(Rect.fromLTRB(c.dx - rx, c.dy, c.dx + rx, c.dy + height)),
  );
  final top = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
  canvas.drawOval(top, Paint()..color = topColor ?? p.stoneTop);
  canvas.drawArc(
    top,
    0.15,
    pi - 0.3,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Color.lerp(
        topColor ?? p.stoneTop,
        Colors.white,
        0.3,
      )!.withValues(alpha: 0.5),
  );
}

/// Laid flags over [area], in offset courses, each its own tint — a floor with
/// a grain and no straight line the length of the room. Translucent at
/// [opacity] (§8). Clip first to lay them in any shape.
void paintFlagFloor(
  Canvas canvas,
  Rect area,
  GlassPalette p,
  GlassRng rng, {
  double opacity = 0.58,
  double course = 62.0,
  double jointOpacity = 0.55,
}) {
  canvas.drawRect(area, Paint()..color = p.floor.withValues(alpha: opacity));
  final alt = Paint()..color = p.floorAlt.withValues(alpha: opacity * 0.55);
  final joint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = p.joint.withValues(alpha: jointOpacity);
  final lip = Paint()
    ..strokeWidth = 1.0
    ..color = p.stoneTop.withValues(alpha: 0.10);
  var row = 0;
  for (var y = area.top; y < area.bottom; y += course, row++) {
    final y1 = min(y + course, area.bottom);
    var x = area.left - (row.isOdd ? course * 0.55 : 0);
    while (x < area.right) {
      final w = course * rng.range(0.9, 1.7);
      final flag = Rect.fromLTRB(
        max(x, area.left),
        y,
        min(x + w, area.right),
        y1,
      );
      if (rng.next() < 0.45) canvas.drawRect(flag.deflate(1), alt);
      canvas.drawRect(flag, joint);
      canvas.drawLine(
        flag.topLeft + const Offset(2, 1.5),
        flag.topRight + const Offset(-2, 1.5),
        lip,
      );
      x += w;
    }
  }
}

// ── The room shell ──────────────────────────────────────────

/// How deep the north wall's face shows under three-quarter view.
const double kGlassWallFace = 46.0;

/// How thick the east, west and south walls read from above.
const double kGlassWallTop = 10.0;

/// A carved room: flagstone floor (translucent, so the planet's shader glows
/// through — §8), the north wall's face with its lit cornice, and the tops of
/// the other three walls. [doors] are left open in the stone. [faceDepth]
/// makes a tall wall (a room with a window in it). [arcade] cuts blind arches
/// into the north face. [flags] false leaves the floor for the planet to lay.
void paintCarvedRoomShell(
  Canvas canvas,
  Rect b,
  GlassPalette p,
  GlassRng rng, {
  Iterable<Rect> doors = const [],
  double faceDepth = kGlassWallFace,
  bool arcade = true,
  double floorOpacity = 0.58,
  bool flags = true,
  double flagCourse = 62.0,
  double jointOpacity = 0.55,
}) {
  final gaps = doors.map((d) => d.inflate(6)).toList();
  bool blocked(Rect r) => gaps.any((g) => g.overlaps(r));

  // THE FLOOR. Offset courses of flags, each its own tint, so the ground has
  // a grain without a single straight line running the length of the room.
  final floorRect = Rect.fromLTRB(b.left, b.top + faceDepth, b.right, b.bottom);
  // [flags] false leaves the floor to the planet: a crust that has not
  // finished cooling is not a thing anyone laid.
  if (flags) {
    paintFlagFloor(
      canvas,
      floorRect,
      p,
      rng,
      opacity: floorOpacity,
      course: flagCourse,
      jointOpacity: jointOpacity,
    );
  }

  // THE NORTH FACE: cornice, face, dark foot.
  final face = Rect.fromLTRB(b.left, b.top, b.right, b.top + faceDepth);
  canvas.drawRect(
    face,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.stoneFace, Color.lerp(p.stoneFace, p.stoneFoot, 0.6)!],
      ).createShader(face),
  );
  // Ashlar courses across the face.
  final coursing = Paint()
    ..strokeWidth = 1.2
    ..color = p.joint.withValues(alpha: 0.45);
  for (var y = face.top + 18; y < face.bottom - 6; y += 18) {
    canvas.drawLine(Offset(face.left, y), Offset(face.right, y), coursing);
    final stagger = ((y - face.top) / 18).round().isOdd ? 34.0 : 0.0;
    for (var x = face.left + 20 + stagger; x < face.right; x += 68) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, min(y + 18, face.bottom)),
        coursing,
      );
    }
  }
  if (arcade) {
    // Blind arches: carved, dark, never glazed — decoration is stone.
    final archTop = face.bottom - min(40, faceDepth - 8);
    for (var x = b.left + 48; x < b.right - 40; x += 74) {
      final r = Rect.fromLTRB(x - 24, archTop, x + 24, face.bottom);
      if (blocked(r)) continue;
      final arch = lancetPath(r, AxisDirection.up);
      canvas.drawPath(
        arch,
        Paint()..color = p.stoneFoot.withValues(alpha: 0.9),
      );
      canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = p.stoneTop.withValues(alpha: 0.45),
      );
    }
  }
  // Cornice: the lit top of the wall.
  canvas.drawRect(
    Rect.fromLTRB(face.left, face.top, face.right, face.top + 7),
    Paint()..color = p.stoneTop,
  );
  canvas.drawLine(
    Offset(face.left, face.top + 7),
    Offset(face.right, face.top + 7),
    Paint()
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: 0.5),
  );
  // The shadow the wall throws onto the floor at its foot.
  canvas.drawRect(
    Rect.fromLTRB(face.left, face.bottom, face.right, face.bottom + 14),
    Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.42),
              Colors.black.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(face.left, face.bottom, face.right, face.bottom + 14),
          ),
  );

  // THE OTHER THREE WALLS: tops only, broken where a door goes through.
  final wallTop = Paint()..color = p.stoneTop.withValues(alpha: 0.92);
  final edge = Paint()
    ..strokeWidth = 1.4
    ..color = Colors.black.withValues(alpha: 0.55);
  // [inner] is the wall top's inside edge, where it drops to the floor.
  void run(Rect r, double inner) {
    final horizontal = r.width > r.height;
    final cuts = gaps.where((g) => g.overlaps(r)).toList()
      ..sort(
        (a, c) =>
            horizontal ? a.left.compareTo(c.left) : a.top.compareTo(c.top),
      );
    var start = horizontal ? r.left : r.top;
    final end = horizontal ? r.right : r.bottom;
    for (final g in [...cuts, null]) {
      final stop = g == null ? end : (horizontal ? g.left : g.top);
      if (stop > start) {
        if (horizontal) {
          canvas.drawRect(Rect.fromLTRB(start, r.top, stop, r.bottom), wallTop);
          canvas.drawLine(Offset(start, inner), Offset(stop, inner), edge);
        } else {
          canvas.drawRect(Rect.fromLTRB(r.left, start, r.right, stop), wallTop);
          canvas.drawLine(Offset(inner, start), Offset(inner, stop), edge);
        }
      }
      if (g != null) start = horizontal ? g.right : g.bottom;
    }
  }

  const wt = kGlassWallTop;
  final top = b.top + faceDepth;
  run(Rect.fromLTRB(b.left, top, b.left + wt, b.bottom), b.left + wt);
  run(Rect.fromLTRB(b.right - wt, top, b.right, b.bottom), b.right - wt);
  run(Rect.fromLTRB(b.left, b.bottom - wt, b.right, b.bottom), b.bottom - wt);
  // The slab's own front face, below the room — seen when the room is smaller
  // than the screen, which is what makes it a diorama rather than a tile.
  final front = Rect.fromLTRB(b.left, b.bottom, b.right, b.bottom + 18);
  canvas.drawRect(
    front,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.stoneFace, p.stoneFoot.withValues(alpha: 0.0)],
      ).createShader(front),
  );
}
