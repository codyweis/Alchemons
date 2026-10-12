// lib/screens/athanor/athanor_reveal.dart
//
// A POUR, SEEN THROUGH. The furnace settles lower and its fire swells; the
// tincture (or gold) pours from the balance it was paid from into the flue
// at its crown, which takes the poured color; the fire roars, the stone
// warms through and the embers stir in the mouth; then the grains rise out
// of the flue, swirl round where the piece will stand and settle into it
// (the piece read into grains, gathered by [GrainAssembly]) as its own look
// comes up through them, and its name forms in grains under it. The last
// piece of a batch brings its capstone: the piece steps aside and a second
// rise settles into the capstone beside it.
//
// One unbroken eased motion, overlapping beats, nothing bursts. A tap runs
// time faster to the next resting place rather than cutting to it. Plain
// Dart stepped by the screen's ticker ([AthanorReveal.step]); the view only
// paints and lays out.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/screens/athanor/athanor_field.dart';
import 'package:alchemons/screens/athanor/athanor_furnace.dart';
import 'package:alchemons/screens/athanor/athanor_piece_art.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/services/athanor_service.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/fx/grain_assembly.dart';
import 'package:alchemons/widgets/fx/grain_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

/// The beats, in seconds from the tap that paid.
abstract final class AthanorBeats {
  static const double pour = 0.3;

  /// The pour has gone in: the fire roars and the stone warms.
  static const double roar = 1.25;

  /// Where the pour waits, roaring, until the result and its grains are in.
  static const double hold = 2.5;
  static const double rise = 2.5;
  static const double gather = 2.95;
  static const double gatherLen = 2.1;
  static const double settled = gather + gatherLen;
  static const double name = 4.65;
  static const double rest = 5.55;

  // The capstone, after.
  static const double shift = 5.75;
  static const double shiftLen = 0.9;
  static const double rise2 = 5.95;
  static const double gather2 = 6.4;
  static const double settled2 = gather2 + gatherLen;
  static const double name2 = 8.1;
  static const double rest2 = 8.9;

  static const double close = 0.6;
}

String athanorKindLabel(AthanorPieceKind kind) => switch (kind) {
  AthanorPieceKind.alchemyEffect => 'ALCHEMY EFFECT',
  AthanorPieceKind.homeDecor => 'HOME DECOR',
  AthanorPieceKind.title => 'TITLE',
  AthanorPieceKind.costume => 'COSTUME',
  AthanorPieceKind.dockSet => 'DOCK SET',
  AthanorPieceKind.caseStyle => 'SPECIMEN CASE',
  AthanorPieceKind.trail => 'TRAIL',
  AthanorPieceKind.fusionStyle => 'FUSION STYLE',
  AthanorPieceKind.ambience => 'HOME AMBIENCE',
  AthanorPieceKind.enhanceOrbs => 'SUPPLIES',
};

/// One pour from the tap to CONTINUE.
class AthanorReveal extends ChangeNotifier {
  AthanorReveal({
    required this.field,
    required this.layout,
    required this.source,
    required this.payment,
    this.onSound,
  }) : color = AthanorTone.pourColor(payment == AthanorPayment.gold);

  final AthanorField field;
  final AthanorLayout layout;

  /// Where the pour comes from: the balance that paid for it.
  final Offset source;
  final AthanorPayment payment;
  final Color color;
  final ValueChanged<SoundCue>? onSound;

  /// Seconds into the pour.
  double t = 0;

  AthanorPourResult? result;
  GrainAssembly? _piece, _cap;

  /// The pour came to nothing (it was not allowed after all).
  bool failed = false;

  /// The result and every grain it needs are in: it may pass the hold.
  bool get ready => _piece != null && (!_hasCap || _cap != null);
  bool get _hasCap => result?.capstone != null;
  bool get hasCapstone => _hasCap;

  /// Fading out after CONTINUE, 0..1, or null.
  double? closing;
  bool get done => (closing ?? 0) >= 1;

  /// Where a tap is running time to, if anywhere.
  double? _skipTo;

  bool _disposed = false;

  /// The pour's result can come in after the screen has gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  double get restAt => _hasCap ? AthanorBeats.rest2 : AthanorBeats.rest;
  bool get atRest => t >= restAt;

  /// Takes the pour's result as it comes and reads what it gives into
  /// grains.
  Future<void> attach(
    Future<AthanorPourResult?> pour, {
    required TextStyle titleStyle,
  }) async {
    final r = await pour;
    if (r == null) {
      failed = true;
      _wind();
      _notify();
      return;
    }
    result = r;
    final box = layout.pieceBox;
    final grains = await athanorPieceGrains(
      r.piece,
      box,
      titleStyle: titleStyle,
    );
    _piece = GrainAssembly(grains, accent: color);
    final cap = r.capstone;
    if (cap != null) {
      final cg = await athanorPieceGrains(cap, box, titleStyle: titleStyle);
      _cap = GrainAssembly(cg, accent: AthanorTone.brassGlow);
    }
    _notify();
  }

  /// Runs to the next resting place, quickly.
  void skip() {
    if (closing != null || failed) return;
    if (atRest) return;
    final stops = [
      AthanorBeats.settled,
      AthanorBeats.rest,
      if (_hasCap) ...[AthanorBeats.settled2, AthanorBeats.rest2],
    ];
    for (final s in stops) {
      if (s > t + 0.05) {
        _skipTo = s;
        field.speed = 5;
        return;
      }
    }
  }

  /// CONTINUE: the furnace banks and the page comes back.
  void close() {
    if (closing != null) return;
    closing = 0;
    _skipTo = null;
    field
      ..speed = 1
      ..focusTo(0, seconds: 1.0)
      ..heatTo(0, seconds: 1.4)
      ..tintTo(0, seconds: 1.6);
    _notify();
  }

  /// The pour failed: everything settles back without a piece.
  void _wind() {
    field
      ..speed = 1
      ..focusTo(0, seconds: 1.0)
      ..heatTo(0, seconds: 1.2)
      ..tintTo(0, seconds: 1.2);
    closing = 0;
  }

  /// [dt] is already the field's (sped up while skipping).
  void step(double dt) {
    final c = closing;
    if (c != null) {
      closing = math.min(1, c + dt / AthanorBeats.close);
      if (closing! >= 1 && c < 1) _notify();
      return;
    }
    final was = t;
    var next = t + dt;
    // The roar holds until there is something to settle into.
    if (!ready && next > AthanorBeats.hold) next = AthanorBeats.hold;
    next = math.min(next, restAt);
    final skipTo = _skipTo;
    if (skipTo != null && next >= skipTo) {
      next = skipTo;
      _skipTo = null;
      field.speed = 1;
    }
    t = next;
    _beats(was, t);
  }

  bool _crossed(double was, double now, double at) => was < at && now >= at;

  void _sound(SoundCue cue) {
    // Beats run through on a skip stay quiet; the place it lands on speaks.
    if (field.speed > 1) return;
    onSound?.call(cue);
  }

  void _beats(double was, double now) {
    final f = field;
    if (was == 0 && now > 0) {
      f
        ..focusTo(1, seconds: 1.0)
        ..fireTo(1.45, seconds: 1.4);
    }
    if (_crossed(was, now, AthanorBeats.pour)) {
      f
        ..pour(
          layout,
          from: source,
          color: color,
          over: 0.95,
          // The free pour comes down out of the dark, a wide fall that
          // narrows into the flue; a paid one leaves its balance.
          width: payment == AthanorPayment.daily ? 90 : 14,
          count: payment == AthanorPayment.daily ? 190 : 140,
        )
        // The crown takes the color as the pour reaches it.
        ..tintTo(1, gold: payment == AthanorPayment.gold, seconds: 1.4)
        ..heatTo(0.3, seconds: 1.2);
      HapticFeedback.lightImpact();
      _sound(SoundCue.fusionPour);
    }
    if (_crossed(was, now, AthanorBeats.roar)) {
      f
        ..fireTo(1.6, seconds: 0.9)
        ..heatTo(1, seconds: 1.1);
      _sound(SoundCue.fusionMerge);
    }
    if (_crossed(was, now, AthanorBeats.rise)) {
      f
        ..rise(
          layout,
          to: _at(false),
          spread: layout.pieceBox * 0.5,
          color: color,
          over: 0.85,
        )
        ..fireTo(1.35, seconds: 1.2)
        ..heatTo(0.7, seconds: 1.4);
    }
    if (_crossed(was, now, AthanorBeats.gather)) {
      HapticFeedback.mediumImpact();
      _sound(
        result?.piece.rarity == AthanorRarity.common
            ? SoundCue.extractionCreatureReveal
            : SoundCue.extractionRareReveal,
      );
    }
    if (_crossed(was, now, AthanorBeats.name)) {
      _sound(SoundCue.rewardCollect);
      _notify();
    }
    if (_crossed(was, now, AthanorBeats.rest) && !_hasCap) _rest();
    if (_hasCap) {
      if (_crossed(was, now, AthanorBeats.rise2)) {
        f
          ..rise(
            layout,
            to: _at(true),
            spread: layout.pieceBox * 0.4,
            color: AthanorTone.brassGlow,
            over: 0.8,
          )
          ..fireTo(1.6, seconds: 0.7)
          ..heatTo(1, seconds: 0.7);
      }
      if (_crossed(was, now, AthanorBeats.gather2)) {
        HapticFeedback.heavyImpact();
        _sound(SoundCue.extractionRareReveal);
      }
      if (_crossed(was, now, AthanorBeats.name2)) {
        _sound(SoundCue.rewardCollect);
        _notify();
      }
      if (_crossed(was, now, AthanorBeats.rest2)) _rest();
    }
  }

  void _rest() {
    field
      ..heatTo(0.2, seconds: 1.6)
      ..tintTo(0.3, seconds: 1.8)
      ..fireTo(1.1, seconds: 1.6);
    _notify();
  }

  // ── where things stand ────────────────────────────────────────────────

  static const double _pairScale = 0.74;

  /// How far the piece has stepped aside for the capstone, 0..1.
  double get shift => _hasCap
      ? _smooth(
          AthanorBeats.shift,
          AthanorBeats.shift + AthanorBeats.shiftLen,
          t,
        )
      : 0;

  Offset _at(bool cap) {
    final c = layout.pieceAt;
    final w = layout.size.width;
    if (cap) return Offset(w * 0.73, c.dy);
    return c;
  }

  /// The piece's centre and scale now.
  (Offset, double) get pieceStand {
    final k = shift;
    final c = layout.pieceAt;
    final w = layout.size.width;
    return (
      Offset.lerp(c, Offset(w * 0.27, c.dy), k)!,
      1 + (_pairScale - 1) * k,
    );
  }

  (Offset, double) get capStand => (_at(true), _pairScale);

  double get _u => _clamp01((t - AthanorBeats.gather) / AthanorBeats.gatherLen);
  double get _u2 =>
      _clamp01((t - AthanorBeats.gather2) / AthanorBeats.gatherLen);

  /// How much of the piece's own look shows over its grains.
  double get pieceShown =>
      _piece == null ? 0 : GrainAssembly.spriteOpacityGathering(_u);
  double get capShown => _cap == null || t < AthanorBeats.gather2
      ? 0
      : GrainAssembly.spriteOpacityGathering(_u2);

  bool get nameShown => t >= AthanorBeats.name && result != null;
  bool get capNameShown => _hasCap && t >= AthanorBeats.name2;

  /// The whole reveal's fade, for the close.
  double get alpha => 1 - _smooth(0, 1, closing ?? 0);

  void paint(Canvas canvas) {
    final a = alpha;
    if (a <= 0.01) return;
    if (a < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
    }
    final p = _piece;
    if (p != null && t >= AthanorBeats.gather) {
      final (at, sc) = pieceStand;
      // Its light on the dark round it, coming up as it settles.
      _halo(canvas, at, layout.pieceBox * 0.7 * sc, result!.piece.rarity, _u);
      _gather(canvas, p, at, _u, sc);
    }
    final c = _cap;
    if (c != null && t >= AthanorBeats.gather2) {
      final (at, sc) = capStand;
      _halo(canvas, at, layout.pieceBox * 0.7 * sc, null, _u2);
      _gather(canvas, c, at, _u2, sc);
    }
    if (a < 1) canvas.restore();
  }

  static final Paint _p = Paint();

  /// The gather, its far grains coming up out of the risen cloud rather
  /// than standing there all at once.
  void _gather(Canvas canvas, GrainAssembly g, Offset at, double u, double sc) {
    final k = _smooth(0, 0.45, u);
    if (k <= 0.01) return;
    if (k < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, k));
    }
    g.paintGather(canvas, at, u, scale: sc);
    if (k < 1) canvas.restore();
  }

  void _halo(
    Canvas canvas,
    Offset at,
    double r,
    AthanorRarity? rarity,
    double u,
  ) {
    final k = _smooth(0.2, 1, u);
    if (k <= 0.01) return;
    final col = rarity == null
        ? AthanorTone.capstone
        : AthanorTone.rarity(rarity);
    _p.shader = RadialGradient(
      colors: [
        col.withValues(alpha: 0.16 * k),
        col.withValues(alpha: 0.05 * k),
        col.withValues(alpha: 0),
      ],
      stops: const [0, 0.5, 1],
    ).createShader(Rect.fromCircle(center: at, radius: r));
    canvas.drawCircle(at, r, _p);
    _p.shader = null;
  }
}

/// The reveal over the screen: its grains, the piece's own look coming up
/// through them, the names, and CONTINUE.
class AthanorRevealView extends StatelessWidget {
  const AthanorRevealView({
    super.key,
    required this.reveal,
    required this.clock,
    required this.onContinue,
  });

  final AthanorReveal reveal;
  final ValueListenable<double> clock;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final layout = reveal.layout;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: reveal.skip,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _RevealPainter(reveal, clock)),
              ),
            ),
          ),
          // The pieces' own looks, and their names under them.
          ListenableBuilder(
            listenable: reveal,
            builder: (context, _) => Stack(
              children: [
                if (reveal.result != null) ..._stand(context, false),
                if (reveal.hasCapstone) ..._stand(context, true),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: layout.pad.bottom + 18,
            child: ListenableBuilder(
              listenable: reveal,
              builder: (context, _) => AnimatedOpacity(
                opacity: reveal.atRest && reveal.closing == null ? 1 : 0,
                duration: const Duration(milliseconds: 420),
                child: IgnorePointer(
                  ignoring: !reveal.atRest || reveal.closing != null,
                  child: BracketButton(
                    label: 'CONTINUE',
                    palette: AthanorTone.palette,
                    accent: AthanorTone.brass,
                    height: 48,
                    onTap: onContinue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _stand(BuildContext context, bool cap) {
    final r = reveal.result!;
    final piece = cap ? r.capstone! : r.piece;
    final layout = reveal.layout;
    final box = layout.pieceBox;
    final pair = reveal.hasCapstone;
    final nameShown = cap ? reveal.capNameShown : reveal.nameShown;
    final ink = cap ? AthanorTone.capstone : AthanorTone.rarity(piece.rarity);
    final columnW = pair ? layout.size.width * 0.46 : layout.size.width - 48;
    return [
      // The look, over its grains as they finish.
      AnimatedBuilder(
        animation: clock,
        builder: (context, child) {
          final (at, sc) = cap ? reveal.capStand : reveal.pieceStand;
          final shown =
              (cap ? reveal.capShown : reveal.pieceShown) * reveal.alpha;
          final side = box * sc;
          return Positioned(
            left: at.dx - side / 2,
            top: at.dy - side / 2,
            width: side,
            height: side,
            child: Opacity(opacity: shown.clamp(0.0, 1.0), child: child),
          );
        },
        child: IgnorePointer(
          child: AthanorPieceArt(piece: piece, animate: true),
        ),
      ),
      // Its name, forming in grains; what it is over it, plainly.
      if (nameShown)
        AnimatedBuilder(
          animation: clock,
          builder: (context, child) {
            final (at, sc) = cap ? reveal.capStand : reveal.pieceStand;
            return Positioned(
              left: at.dx - columnW / 2,
              width: columnW,
              top: at.dy + box * sc / 2 + 10,
              child: Opacity(opacity: reveal.alpha, child: child),
            );
          },
          child: IgnorePointer(
            child: _Caption(
              key: ValueKey('${piece.id}-$pair'),
              piece: piece,
              ink: ink,
              cap: cap,
              pair: pair,
            ),
          ),
        ),
    ];
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    super.key,
    required this.piece,
    required this.ink,
    required this.cap,
    required this.pair,
  });

  final AthanorPiece piece;
  final Color ink;
  final bool cap, pair;

  @override
  Widget build(BuildContext context) {
    final over = cap
        ? 'CAPSTONE'
        : pair
        ? piece.rarity.label
        : '${piece.rarity.label}  ·  ${athanorKindLabel(piece.kind)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FadeIn(
          child: Text(
            over,
            textAlign: TextAlign.center,
            style: athanorMono(pair ? 9.5 : 10.5, ink, spacing: 2.2),
          ),
        ),
        const SizedBox(height: 6),
        GrainText(
          piece.name,
          textAlign: TextAlign.center,
          style: athanorName(context, pair ? 19 : 26),
        ),
        if (!pair) ...[
          const SizedBox(height: 8),
          _FadeIn(
            delay: const Duration(milliseconds: 700),
            child: Text(
              piece.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: athanorBody(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Fades its child in once, after [delay].
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> {
  bool _on = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay + const Duration(milliseconds: 16), () {
      if (mounted) setState(() => _on = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _on ? 1 : 0,
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOut,
    child: widget.child,
  );
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.reveal, Listenable clock) : super(repaint: clock);

  final AthanorReveal reveal;

  @override
  void paint(Canvas canvas, Size size) => reveal.paint(canvas);

  @override
  bool shouldRepaint(_RevealPainter old) => old.reveal != reveal;
}
