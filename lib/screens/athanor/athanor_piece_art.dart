// lib/screens/athanor/athanor_piece_art.dart
//
// A piece's look, for each kind it can be: an alchemy effect drawn on its
// own (as the shop shows one), a piece of home decor standing on the box's
// floor (as the shop's cards show it), a costume on its own (as its card
// shows it), a dock set's Let in its lit archway (as the dock's Home tab
// shows it), or a title's words. One painter, so
// the same look is a tile, an odds row, and the grains a pour settles into.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_view.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_previews.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:alchemons/widgets/nav_emblems.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The effect an alchemy-effect piece paints.
String _effectKeyOf(AthanorPiece piece) =>
    InvKeys.alchemyEffectFor(piece.grantRef) ?? piece.grantRef;

/// With no creature to wear it, an element effect shows one, as the shop's.
String? _effectElement(String key) => switch (key) {
  AlchemyEffectPaint.elementalAura => 'Fire',
  AlchemyEffectPaint.dustRing => 'Dust',
  _ => null,
};

final Map<String, KeepsakeArt?> _decorArt = {};
KeepsakeArt? _decor(String id) =>
    _decorArt.putIfAbsent(id, () => KeepsakeArt.of(id));

/// A dock set's Let, once its sheet has loaded (kept by nav_emblems.dart
/// as the dock keeps its own); until then its archway and light stand
/// empty. Loaded by the first [AthanorPieceArt] that shows the set, which
/// also leaves the catalog here for a pour's grains.
final Map<String, NavLetSprite> _dockLets = {};
final Map<String, Future<void>> _dockLoads = {};
CreatureCatalog? _dockCatalog;

Future<void> _loadDockLet(DockSet set) {
  final catalog = _dockCatalog;
  if (catalog == null || _dockLets.containsKey(set.id)) {
    return Future.value();
  }
  return _dockLoads[set.id] ??= loadNavLet(catalog, set).then((let) {
    if (let != null) _dockLets[set.id] = let;
  });
}

/// The words of a title, as a piece shows them.
TextStyle athanorTitleStyle(TextStyle base, double size) => base.copyWith(
  color: AthanorTone.brassGlow,
  fontSize: size,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.6,
  height: 1.1,
);

/// Paints [piece] into [rect] at [t] seconds. [titleStyle] sets a title's
/// words (the app's serif); its size is fitted to the box.
void paintAthanorPiece(
  Canvas canvas,
  AthanorPiece piece,
  Rect rect,
  double t, {
  TextStyle titleStyle = const TextStyle(),
}) {
  switch (piece.kind) {
    case AthanorPieceKind.alchemyEffect:
      final key = _effectKeyOf(piece);
      final r = rect.shortestSide / 2 * 0.8;
      for (final front in const [false, true]) {
        AlchemyEffectPaint.paint(
          canvas,
          key,
          rect.center,
          r,
          t,
          element: _effectElement(key),
          front: front,
        );
      }
    case AthanorPieceKind.homeDecor:
      final art = _decor(piece.grantRef);
      if (art == null) return;
      final b = art.box;
      final k = math.min(rect.width / b.width, rect.height / b.height) * 0.86;
      final time = KeepsakeTime(t: 3.2 + t, night: 0.6, daylight: 0.4);
      canvas
        ..save()
        ..translate(
          rect.center.dx - b.center.dx * k,
          rect.bottom - rect.height * 0.04 - b.bottom * k,
        )
        ..scale(k);
      art.paint(canvas, time);
      if (art.hasFront) art.front(canvas, time);
      canvas.restore();
    // A costume on its own, as the shop's and the inventory's cards show
    // it.
    case AthanorPieceKind.costume:
      final costume = FamilyCostume.ofItem(piece.grantRef);
      if (costume == null) return;
      CostumePaint.paintPreview(
        canvas,
        costume,
        rect.center,
        rect.shortestSide / 2 * 0.8,
        t,
      );
    // A dock set as the dock's open Home tab shows it: its Let in the lit
    // archway, standing in its element's light.
    case AthanorPieceKind.dockSet:
      final set = DockSet.byId(piece.grantRef);
      if (set == null) return;
      final side = rect.shortestSide * 0.9;
      canvas
        ..save()
        ..translate(rect.center.dx - side / 2, rect.center.dy - side / 2);
      NavEmblemPainter(
        kind: NavEmblemKind.home,
        element: set.element,
        let: _dockLets[set.id],
        time: t,
      ).paint(canvas, Size.square(side));
      canvas.restore();
    // A case style, a trail, a fusion style (a small fusion, looping), a
    // home ambience: as its chooser shows it
    // (lib/widgets/fx/cosmetics/cosmetic_previews.dart).
    case AthanorPieceKind.caseStyle:
    case AthanorPieceKind.trail:
    case AthanorPieceKind.fusionStyle:
    case AthanorPieceKind.ambience:
      paintCosmeticPreview(canvas, piece.kind, piece.grantRef, rect, t);
    // A title is its words.
    case AthanorPieceKind.title:
      // Smaller for a long word ("Silversmith"), so none breaks in two.
      final maxWidth = rect.width * 0.94;
      var size = rect.height * 0.2;
      for (final word in piece.name.split(' ')) {
        final w = (TextPainter(
          text: TextSpan(
            text: word,
            style: athanorTitleStyle(titleStyle, size),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout());
        if (w.width > maxWidth) size *= maxWidth / w.width * 0.97;
        w.dispose();
      }
      final tp = TextPainter(
        text: TextSpan(
          text: piece.name,
          style: athanorTitleStyle(titleStyle, size),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: maxWidth);
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
  }
}

/// How a piece stands on the screen.
enum AthanorPieceLook {
  /// Owned: in its own light.
  lit,

  /// Still to come: a dim ghost of itself.
  ghost,

  /// A capstone not yet given: shut in dark glass.
  sealed,
}

/// [piece] in a box of its own. Still unless [animate].
class AthanorPieceArt extends StatefulWidget {
  const AthanorPieceArt({
    super.key,
    required this.piece,
    this.look = AthanorPieceLook.lit,
    this.animate = false,
  });

  final AthanorPiece piece;
  final AthanorPieceLook look;
  final bool animate;

  @override
  State<AthanorPieceArt> createState() => _AthanorPieceArtState();
}

class _AthanorPieceArtState extends State<AthanorPieceArt>
    with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
    _loadLet();
  }

  @override
  void didUpdateWidget(covariant AthanorPieceArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
    if (oldWidget.piece != widget.piece) _loadLet();
  }

  /// A dock set's Let, loaded once; painted again when it lands.
  void _loadLet() {
    if (widget.piece.kind != AthanorPieceKind.dockSet) return;
    final set = DockSet.byId(widget.piece.grantRef);
    if (set == null || _dockLets.containsKey(set.id)) return;
    try {
      _dockCatalog ??= Provider.of<CreatureCatalog>(context, listen: false);
    } on ProviderNotFoundException {
      return;
    }
    _loadDockLet(set).then((_) {
      if (mounted && _dockLets.containsKey(set.id)) setState(() {});
    });
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final Widget art = CustomPaint(
      size: Size.infinite,
      willChange: glyphClock != null,
      painter: widget.look == AthanorPieceLook.sealed
          ? _SealedPainter(clock: glyphClock)
          : _PiecePainter(
              widget.piece,
              style,
              clock: glyphClock,
              letReady: _dockLets.containsKey(widget.piece.grantRef),
            ),
    );
    if (widget.look != AthanorPieceLook.ghost) {
      return RepaintBoundary(child: art);
    }
    // A ghost: its own shape, without its color, faint.
    return RepaintBoundary(
      child: Opacity(
        opacity: 0.5,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.3, 0.58, 0.12, 0, 14, //
            0.28, 0.55, 0.11, 0, 11,
            0.24, 0.48, 0.1, 0, 8,
            0, 0, 0, 1.2, 0,
          ]),
          child: art,
        ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.piece, this.style, {this.clock, this.letReady = false})
    : super(repaint: clock);

  final AthanorPiece piece;
  final TextStyle style;
  final ValueListenable<double>? clock;

  /// A dock set's Let has loaded since it was last painted.
  final bool letReady;

  @override
  void paint(Canvas canvas, Size size) => paintAthanorPiece(
    canvas,
    piece,
    Offset.zero & size,
    clock?.value ?? AlchemyEffectView.stillTime,
    titleStyle: style,
  );

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.piece != piece ||
      old.clock != clock ||
      old.style != style ||
      old.letReady != letReady;
}

/// A capstone not yet given: a bead of dark glass, its grains at rest.
class _SealedPainter extends CustomPainter {
  _SealedPainter({this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.3;
    GrainGlass.sphere(
      canvas,
      size.center(Offset.zero),
      r,
      clock?.value ?? 1.4,
      a: AthanorTone.brassDeep,
      spin: 0.12,
      density: 0.55,
      glow: 0.5,
      fade: 0.85,
      salt: 9,
    );
  }

  @override
  bool shouldRepaint(_SealedPainter old) => old.clock != clock;
}

final Map<String, SpecimenGrains> _grainCache = {};

/// [piece] read into grains, [box] logical px across, for a pour to settle
/// into. Faint light (an aura's) is lifted first so it reads as grains too.
/// Kept, so a second pour of the same look reads nothing.
Future<SpecimenGrains> athanorPieceGrains(
  AthanorPiece piece,
  double box, {
  TextStyle titleStyle = const TextStyle(),
}) async {
  final key = '${piece.id}|${box.round()}';
  final kept = _grainCache[key];
  if (kept != null) return kept;
  if (piece.kind == AthanorPieceKind.dockSet) {
    final set = DockSet.byId(piece.grantRef);
    if (set != null) await _loadDockLet(set);
  }
  const ratio = 2.0;
  final px = (box * ratio).ceil();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)..scale(ratio);
  paintAthanorPiece(
    canvas,
    piece,
    Offset.zero & Size.square(box),
    AlchemyEffectView.stillTime,
    titleStyle: titleStyle,
  );
  final picture = rec.endRecording();
  SpecimenGrains? grains;
  try {
    final image = await picture.toImage(px, px);
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data != null) {
        final rgba = Uint8List.fromList(data.buffer.asUint8List());
        // Faint light (an aura's, a trail's, an ambience's) is lifted
        // first.
        if (piece.kind == AthanorPieceKind.alchemyEffect ||
            piece.kind == AthanorPieceKind.trail ||
            piece.kind == AthanorPieceKind.ambience) {
          for (var o = 3; o < rgba.length; o += 4) {
            rgba[o] = math.min(255, rgba[o] * 2.4).round();
          }
        }
        grains = SpecimenGrains.fromRgba(
          rgba,
          px,
          px,
          pixelRatio: ratio,
          maxGrains: 2600,
          tones: 24,
        );
      }
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
  final g = (grains == null || grains.length < 60)
      ? SpecimenGrains.disc(AthanorTone.rarity(piece.rarity), radius: box * 0.3)
      : grains;
  return _grainCache[key] = g;
}
