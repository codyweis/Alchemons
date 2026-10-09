// lib/widgets/nav_emblems.dart
//
// The dock's icons, in the player's faction: every tab is that faction's Let
// — Firelet, Waterlet, Mudlet or Airlet — standing large on its pool of
// light. The Let carries the icon; each tab changes as little as it can.
//
//   inventory  a small coffer at its side, shut, its seam glowing
//   creatures  two of the other Lets, dimmed, standing behind it
//   home       in a warm, lit archway
//   fusion     Alchemized: all grains
//   shop       Transmuted: gold
//
// The Lets are their real idle sheets (the mutations are the real bakes). The
// open tab plays them; a closed tab is drawn once, at frame 0. Anything drawn
// is filled shapes and gradients, lit from the upper left — nothing stroked,
// no blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum NavEmblemKind { inventory, creatures, home, fusion, shop }

/// The faction's Let. No faction yet reads as Oceanic, as the home screen
/// does.
String navLetId(FactionId? faction) => switch (faction) {
  FactionId.volcanic => 'LET01',
  FactionId.oceanic || null => 'LET02',
  FactionId.earthen => 'LET08',
  FactionId.verdant => 'LET04',
};

/// The faction's element: the light its Let stands in.
String navLetElement(FactionId? faction) => switch (faction) {
  FactionId.volcanic => 'Fire',
  FactionId.oceanic || null => 'Water',
  FactionId.earthen => 'Mud',
  FactionId.verdant => 'Air',
};

/// The two Lets behind [faction]'s on the Creatures tab: the first two other
/// factions.
List<FactionId> navLetCompanions(FactionId? faction) => [
  for (final f in FactionId.values)
    if (f != (faction ?? FactionId.oceanic)) f,
].take(2).toList();

/// The sheets [kind] draws: [faction]'s Let first (Alchemized for Fusion,
/// Transmuted for Shop), then any Lets behind it. Empty until the catalog has
/// loaded.
List<SpriteSheetDef> navLetSheets(
  CreatureCatalog catalog,
  FactionId? faction,
  NavEmblemKind kind,
) {
  if (!catalog.isLoaded) return const [];
  SpriteSheetDef? plain(FactionId? f) {
    final c = catalog.getCreatureById(navLetId(f));
    return c?.spriteData == null ? null : sheetFromCreature(c!);
  }

  final own = plain(faction);
  if (own == null) return const [];
  return [
    switch (kind) {
      NavEmblemKind.fusion => mutatedSheet(
        own,
        mutation: AlchemonMutation.alchemized.id,
      ),
      NavEmblemKind.shop => mutatedSheet(
        own,
        mutation: AlchemonMutation.transmuted.id,
      ),
      _ => own,
    },
    if (kind == NavEmblemKind.creatures)
      for (final f in navLetCompanions(faction)) ?plain(f),
  ];
}

/// The dock's sheets that have finished loading, by path.
///
/// Flame's cache holds an entry from the moment a load starts, and
/// `fromCache` throws until it ends — so the dock asks this instead.
final Map<String, ui.Image> _loaded = {};

/// [path]'s image: loaded (and baked) once, then kept in [_loaded].
Future<ui.Image> _loadNavSheet(String path) async {
  final ready = _loaded[path];
  if (ready != null) return ready;
  return _loaded[path] = await loadCreatureSheet(Flame.images, path);
}

/// Loads (and bakes) every sheet [faction]'s dock draws, so it does not draw
/// its first frame empty.
Future<void> precacheNavLets(
  CreatureCatalog catalog,
  FactionId? faction,
) async {
  final paths = {
    for (final kind in NavEmblemKind.values)
      for (final sheet in navLetSheets(catalog, faction, kind)) sheet.path,
  };
  for (final path in paths) {
    try {
      await _loadNavSheet(path);
    } catch (e) {
      debugPrint('[NavEmblem] could not load $path: $e');
    }
  }
}

/// A sheet and its loaded image.
class NavLetSprite {
  const NavLetSprite(this.sheet, this.image);
  final SpriteSheetDef sheet;
  final ui.Image image;
}

class NavEmblem extends StatefulWidget {
  const NavEmblem({
    super.key,
    required this.kind,
    required this.faction,
    required this.size,
    this.animate = false,
  });

  final NavEmblemKind kind;
  final FactionId? faction;
  final double size;

  /// Whether it moves — true only for the open tab.
  final bool animate;

  @override
  State<NavEmblem> createState() => _NavEmblemState();
}

class _NavEmblemState extends State<NavEmblem> with GlyphClockLease {
  bool _visible = true;
  List<SpriteSheetDef> _sheets = const [];
  List<ui.Image?> _images = const [];

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
    _resolveSheets();
  }

  @override
  void didUpdateWidget(covariant NavEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
    if (oldWidget.kind != widget.kind || oldWidget.faction != widget.faction) {
      _resolveSheets();
    }
  }

  void _resolveSheets() {
    final sheets = navLetSheets(
      context.read<CreatureCatalog>(),
      widget.faction,
      widget.kind,
    );
    if (listEquals(
      [for (final s in sheets) s.path],
      [for (final s in _sheets) s.path],
    )) {
      return;
    }
    _sheets = sheets;
    _images = [for (final s in sheets) _loaded[s.path]];
    for (var i = 0; i < sheets.length; i++) {
      if (_images[i] != null) continue;
      final path = sheets[i].path;
      _loadNavSheet(path).then(
        (image) {
          if (!mounted || i >= _sheets.length || _sheets[i].path != path) {
            return;
          }
          setState(() => _images = [..._images]..[i] = image);
        },
        onError: (Object e) =>
            debugPrint('[NavEmblem] could not load $path: $e'),
      );
    }
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = glyphClock;
    final lets = [
      for (var i = 0; i < _sheets.length; i++)
        _images[i] == null ? null : NavLetSprite(_sheets[i], _images[i]!),
    ];
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        willChange: clock != null,
        painter: NavEmblemPainter(
          kind: widget.kind,
          element: navLetElement(widget.faction),
          let: lets.isEmpty ? null : lets.first,
          behind: lets.skip(1).toList(),
          clock: clock,
        ),
      ),
    );
  }
}

class NavEmblemPainter extends CustomPainter {
  NavEmblemPainter({
    required this.kind,
    required this.element,
    required this.let,
    this.behind = const [],
    this.clock,
    this.time,
  }) : super(repaint: clock);

  final NavEmblemKind kind;

  /// The Let's element: the color of the light it stands in.
  final String element;

  /// The Let; null (nothing drawn) until its sheet has loaded.
  final NavLetSprite? let;

  /// The Lets behind it (Creatures), left then right; null until loaded.
  final List<NavLetSprite?> behind;

  /// Null leaves the painter at its resting frame.
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  /// The time a closed tab is drawn at.
  static const double restTime = 1.1;

  /// Where the Lets' feet sit in their frames (measured: 0.912–0.922).
  static const double _feet = 0.915;

  static const Color _amber = Color(0xFFF0B254);
  static const Color _flare = Color(0xFFFFF4E0);
  static const List<Color> _brass = [
    Color(0xFFFFE08A),
    Color(0xFFC8841C),
    Color(0xFF5E3404),
  ];

  static final Paint _p = Paint();
  static final Paint _sprite = Paint()..filterQuality = FilterQuality.medium;

  /// The Lets behind, sunk toward the dock's ink.
  static final Paint _dimmed = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.mode(
      Color(0x99101014),
      BlendMode.srcATop,
    );

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// [inner] minus a copy of itself shifted by [by]: the rim on the side
  /// facing away from [by]. Used for a bevel's lit and shaded edges.
  static Path _rim(Path inner, Offset by) =>
      Path.combine(PathOperation.difference, inner, inner.shift(by));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final moving = time != null || clock != null;
    final t = time ?? clock?.value ?? restTime;
    _p
      ..shader = null
      ..color = const Color(0xFF000000);
    final r = s * 0.5;
    final c = size.center(Offset.zero);
    final light = elementOrbTint(EssenceElement.of(element));
    int frameOf(NavLetSprite sprite) => moving
        ? (t / sprite.sheet.stepTime).floor() % sprite.sheet.totalFrames
        : 0;
    final breathe = 0.5 + 0.5 * math.sin(t * 1.7);
    Offset q(double x, double y) => Offset(c.dx + x * r, c.dy + y * r);
    // The Let alone stands centred; Inventory's coffer sits at its side.
    void standing(NavLetSprite? sprite) {
      if (sprite != null) {
        _let(canvas, sprite, q(0, 0.86), r * 2.0, frameOf(sprite), _sprite);
      }
    }

    if (kind == NavEmblemKind.home) _arch(canvas, q, r, breathe);
    _pool(canvas, q(0, 0.88), r, light);
    switch (kind) {
      case NavEmblemKind.home:
      case NavEmblemKind.shop:
        standing(let);
      case NavEmblemKind.fusion:
        standing(let);
        _motes(
          canvas,
          q,
          r,
          t,
          from: const Offset(0, -0.1),
          spread: 1.0,
          rise: 0.8,
          tones: [light, mutationAccent(AlchemonMutation.alchemized), _flare],
          count: 7,
          salt: 31,
        );
      case NavEmblemKind.creatures:
        for (final (i, x) in const [(0, -0.52), (1, 0.52)]) {
          final b = i < behind.length ? behind[i] : null;
          if (b != null) {
            _let(canvas, b, q(x, 0.68), r * 1.3, frameOf(b), _dimmed);
          }
        }
        standing(let);
      case NavEmblemKind.inventory:
        final sprite = let;
        if (sprite != null) {
          _let(
            canvas,
            sprite,
            q(-0.16, 0.86),
            r * 1.9,
            frameOf(sprite),
            _sprite,
          );
        }
        _coffer(
          canvas,
          (x, y) => q(_cueAt.dx + x * _cue, _cueAt.dy + y * _cue),
          r * _cue,
          breathe,
        );
    }
  }

  /// Where the coffer sits (in the icon's half-widths), and its own
  /// half-width.
  static const Offset _cueAt = Offset(0.5, 0.56);
  static const double _cue = 0.36;

  /// The light it stands in.
  void _pool(Canvas canvas, Offset at, double r, Color col) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, 0.24);
    final pool = r * 0.72;
    canvas.drawCircle(
      Offset.zero,
      pool,
      _p
        ..shader = ui.Gradient.radial(Offset.zero, pool, [
          col.withValues(alpha: 0.42),
          col.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    canvas.restore();
  }

  /// [sprite]'s frame [frame], its feet at [feet], the frame [f] wide.
  void _let(
    Canvas canvas,
    NavLetSprite sprite,
    Offset feet,
    double f,
    int frame,
    Paint paint,
  ) {
    final def = sprite.sheet;
    final rows = math.max(1, def.rows);
    final cols = (def.totalFrames + rows - 1) ~/ rows;
    final fw = def.frameSize.x, fh = def.frameSize.y;
    canvas.drawImageRect(
      sprite.image,
      Rect.fromLTWH((frame % cols) * fw, (frame ~/ cols) * fh, fw, fh),
      Rect.fromLTWH(feet.dx - f / 2, feet.dy - _feet * f, f, f),
      paint,
    );
  }

  /// Grains rising from [from], spread [spread] wide, in [tones].
  void _motes(
    Canvas canvas,
    Offset Function(double, double) q,
    double r,
    double t, {
    required Offset from,
    required double spread,
    required double rise,
    required List<Color> tones,
    int count = 8,
    int salt = 1,
  }) {
    final dot = Paint();
    for (var i = 0; i < count; i++) {
      final ph = (t * 0.3 + _h(i, salt)) % 1.0;
      final at = q(
        from.dx +
            (_h(i, salt + 1) - 0.5) * spread +
            math.sin(ph * 5 + i) * 0.04,
        from.dy - ph * rise * (0.6 + 0.4 * _h(i, salt + 2)),
      );
      dot.color = tones[i % tones.length].withValues(
        alpha: math.sin(ph * math.pi) * (0.55 + 0.4 * _h(i, salt + 3)),
      );
      canvas.drawCircle(
        at,
        r * (0.024 + 0.02 * _h(i, salt + 4)) * (1 - ph * 0.4),
        dot,
      );
    }
  }

  // ── Home: a lit archway ─────────────────────────────────────────────────

  /// The warm room behind the Let: an arch of light, brightest at its heart.
  void _arch(
    Canvas canvas,
    Offset Function(double, double) q,
    double r,
    double breathe,
  ) {
    const hw = 0.62, spring = -0.25, sill = 0.82;
    final arch = Path()
      ..moveTo(q(-hw, sill).dx, q(-hw, sill).dy)
      ..lineTo(q(-hw, spring).dx, q(-hw, spring).dy)
      ..arcToPoint(q(hw, spring), radius: Radius.circular(hw * r))
      ..lineTo(q(hw, sill).dx, q(hw, sill).dy)
      ..close();
    final heart = q(0, -0.05);
    final glow = 0.9 + 0.1 * breathe;
    canvas.drawPath(
      arch,
      _p
        ..shader = ui.Gradient.radial(
          heart,
          r * 1.1,
          [
            _amber.withValues(alpha: 0.8 * glow),
            const Color(0xFFB06A1C).withValues(alpha: 0.33 * glow),
            const Color(0x00B06A1C),
          ],
          const [0.0, 0.6, 1.0],
        ),
    );
    _p.shader = null;
  }

  void _brassRect(Canvas canvas, Rect rect, {bool vertical = false}) {
    canvas.drawRect(
      rect,
      _p
        ..shader = ui.Gradient.linear(
          vertical ? rect.topCenter : rect.centerLeft,
          vertical ? rect.bottomCenter : rect.centerRight,
          vertical ? const [Color(0xFFFFE08A), Color(0xFF8A5410)] : _brass,
          vertical ? null : const [0.0, 0.45, 1.0],
        ),
    );
    _p.shader = null;
  }

  // ── Inventory: a small coffer ───────────────────────────────────────────

  /// [p] maps the coffer's own units (half-width 1) into the icon; [k] is
  /// that half-width in pixels.
  void _coffer(
    Canvas canvas,
    Offset Function(double, double) p,
    double k,
    double breathe,
  ) {
    final body = RRect.fromRectAndCorners(
      Rect.fromPoints(p(-1, -0.06), p(1, 0.86)),
      bottomLeft: Radius.circular(k * 0.14),
      bottomRight: Radius.circular(k * 0.14),
    );
    final bb = body.outerRect;
    canvas.drawRRect(
      body,
      _p
        ..shader = ui.Gradient.linear(
          bb.centerLeft,
          bb.centerRight,
          const [Color(0xFF5A402B), Color(0xFF2C1E14), Color(0xFF110B07)],
          const [0.0, 0.42, 1.0],
        ),
    );
    _p.shader = null;

    // The lid, a shallow barrel, shut on a seam of light.
    final lid = Path()
      ..moveTo(p(-1, -0.14).dx, p(-1, -0.14).dy)
      ..lineTo(p(-1, -0.42).dx, p(-1, -0.42).dy)
      ..cubicTo(
        p(-1, -1.0).dx,
        p(-1, -1.0).dy,
        p(1, -1.0).dx,
        p(1, -1.0).dy,
        p(1, -0.42).dx,
        p(1, -0.42).dy,
      )
      ..lineTo(p(1, -0.14).dx, p(1, -0.14).dy)
      ..close();
    final lb = lid.getBounds();
    canvas.drawPath(
      lid,
      _p
        ..shader = ui.Gradient.linear(
          lb.topLeft,
          lb.bottomRight,
          const [Color(0xFF6A4D35), Color(0xFF34241A), Color(0xFF150E09)],
          const [0.0, 0.5, 1.0],
        ),
    );
    _p.shader = null;
    canvas.drawPath(
      _rim(lid, Offset(k * 0.05, k * 0.1)),
      Paint()..color = const Color(0xFFFFE2B0).withValues(alpha: 0.3),
    );
    canvas.drawRect(
      Rect.fromPoints(p(-0.94, -0.14), p(0.94, -0.06)),
      Paint()
        ..color = Color.lerp(
          _amber,
          _flare,
          0.3 * breathe,
        )!.withValues(alpha: 0.85),
    );

    // Two straps over lid and body, a brass foot.
    for (final x in const [-0.66, 0.42]) {
      canvas.save();
      canvas.clipPath(lid);
      _brassRect(canvas, Rect.fromPoints(p(x, -1.0), p(x + 0.24, -0.14)));
      canvas.restore();
      _brassRect(canvas, Rect.fromPoints(p(x, -0.06), p(x + 0.24, 0.84)));
    }
    canvas.save();
    canvas.clipRRect(body);
    _brassRect(
      canvas,
      Rect.fromPoints(p(-1, 0.68), p(1, 0.86)),
      vertical: true,
    );
    canvas.restore();

    // The lock plate.
    final plate = RRect.fromRectAndRadius(
      Rect.fromPoints(p(-0.17, -0.02), p(0.17, 0.36)),
      Radius.circular(k * 0.06),
    );
    canvas.drawRRect(
      plate,
      _p
        ..shader = ui.Gradient.linear(
          plate.outerRect.topLeft,
          plate.outerRect.bottomRight,
          _brass,
          const [0.0, 0.5, 1.0],
        ),
    );
    _p.shader = null;
    canvas.drawCircle(
      p(0, 0.13),
      k * 0.06,
      Paint()..color = const Color(0xFF1A0F05),
    );
  }

  @override
  bool shouldRepaint(covariant NavEmblemPainter old) =>
      old.kind != kind ||
      old.element != element ||
      old.let?.image != let?.image ||
      !listEquals(
        [for (final b in behind) b?.image],
        [for (final b in old.behind) b?.image],
      ) ||
      old.clock != clock ||
      old.time != time;
}
