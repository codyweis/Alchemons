// lib/games/shared/damage_numbers.dart
//
// Floating damage numbers, shared by every mode that has a boss fight.
//
// Deliberately NOT shown for ordinary trash. Dungeon rooms are puzzles and
// survival waves are crowd control; numbers over every contact tick would bury
// the thing the player is actually reading. They earn their screen space only
// in fights where "am I actually hurting this" is the open question — guardians,
// raid bosses, survival bosses.
//
// Cost: one short-lived struct per hit, a hard cap on the list, and a cached
// TextPainter per distinct label. Nothing lays out text per frame.

import 'package:flutter/material.dart';

/// One rising number.
class DamageNumber {
  DamageNumber({
    required this.position,
    required this.amount,
    required this.drift,
    this.isBig = false,
    this.life = 0.85,
    this.key,
  }) : maxLife = life;

  Offset position;

  /// What it shows. Grows while hits on the same [key] fold into it.
  double amount;
  final Offset drift;

  /// Heavy hits get a larger, brighter treatment.
  bool isBig;

  /// The body it rose from, when hits on that body fold together.
  final Object? key;

  double life;
  final double maxLife;

  double get t => (1.0 - life / maxLife).clamp(0.0, 1.0);

  /// Sub-1 chip damage would all render as "0", which reads as a bug.
  String get label =>
      amount >= 10 ? amount.round().toString() : amount.toStringAsFixed(1);
}

/// Owns a pool of numbers plus the painter cache. One per game instance.
class DamageNumberField {
  DamageNumberField({
    this.maxNumbers = 40,
    this.bigThreshold = 40,
    this.mergeWindow = 0.2,
  });

  /// Cap the list rather than the spawn rate: a big AoE tick should show every
  /// hit, but a sustained beam must not grow this without bound.
  final int maxNumbers;

  /// At or above this, a hit is rendered large.
  final double bigThreshold;

  /// Seconds a number keeps taking in hits on its body before it floats off
  /// alone. A raid's squad lands a hit on the guardian every few frames, and
  /// one number per hit piled into a block over its head that nobody could
  /// read; folded, the same damage rises as a few honest numbers a second.
  final double mergeWindow;

  final List<DamageNumber> numbers = [];
  final Map<String, TextPainter> _painters = {};

  /// Fade is quantised so a painter can be cached per opacity step. The
  /// alternative — one saveLayer per fading number — costs a render-target
  /// switch each, which is brutal on a tile-based mobile GPU and showed up as
  /// raster spikes in a raid.
  static const int _fadeSteps = 8;

  bool get isEmpty => numbers.isEmpty;
  int get length => numbers.length;

  void clear() => numbers.clear();

  /// [jitter] spreads simultaneous hits so they don't stack into one
  /// illegible blob; pass a per-call random offset. With a [key] (the body
  /// struck), a hit lands on that body's newest number while it is younger
  /// than [mergeWindow] instead of raising one of its own.
  void spawn(
    Offset at,
    double amount, {
    Offset jitter = Offset.zero,
    Object? key,
  }) {
    if (key != null) {
      for (var i = numbers.length - 1; i >= 0; i--) {
        final d = numbers[i];
        if (!identical(d.key, key)) continue;
        if (d.maxLife - d.life < mergeWindow) {
          d.amount += amount;
          d.isBig = d.amount >= bigThreshold;
          return;
        }
        break;
      }
    }
    if (amount < 1) return;
    if (numbers.length >= maxNumbers) {
      numbers.removeRange(0, numbers.length - maxNumbers + 1);
    }
    numbers.add(
      DamageNumber(
        position: at + jitter,
        amount: amount,
        drift: Offset(jitter.dx * 0.8, -46),
        isBig: amount >= bigThreshold,
        key: key,
      ),
    );
  }

  void update(double dt) {
    for (var i = numbers.length - 1; i >= 0; i--) {
      final d = numbers[i];
      d.life -= dt;
      if (d.life <= 0) {
        numbers.removeAt(i);
        continue;
      }
      d.position += d.drift * dt;
    }
  }

  /// Cached per label, size and opacity step, so a fading number costs a map
  /// lookup rather than a layer or a re-layout.
  TextPainter _painter(String text, bool big, int fadeStep) {
    final key = '${big ? 'b' : 's'}$fadeStep:$text';
    return _painters.putIfAbsent(key, () {
      final a = (fadeStep + 1) / _fadeSteps;
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: a),
            fontSize: big ? 20 : 14,
            fontWeight: big ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.4,
            // CRISP offsets, never a blur. A blurRadius on a text shadow is a
            // gaussian pass over the glyph mask on the raster thread, once
            // per shadow per number per frame — and these were two. It never
            // showed up in any Dart timing (recording a paragraph is cheap)
            // and it is why the cost tracked the HIT RATE rather than the
            // number count: a number in its 0.15s pop-in is drawn at a scale
            // that changes every frame, so the blur could not be cached
            // either. Four hard offsets read as an outline and cost four
            // glyph blits.
            shadows: [
              Shadow(
                color: Color(0xE6000000).withValues(alpha: 0.92 * a),
                offset: Offset(1, 1),
              ),
              Shadow(
                color: Color(0xE6000000).withValues(alpha: 0.92 * a),
                offset: Offset(-1, 1),
              ),
              Shadow(
                color: Color(0xE6000000).withValues(alpha: 0.92 * a),
                offset: Offset(1, -1),
              ),
              Shadow(
                color: Color(0x99000000).withValues(alpha: 0.70 * a),
                offset: Offset(-1, -1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Draws in whatever space the canvas is currently in — callers place this
  /// inside their world transform, above the things it annotates.
  void render(Canvas canvas) {
    if (numbers.isEmpty) return;
    for (final d in numbers) {
      final t = d.t;
      // Pop in fast, hold, fade out. A number that fades the whole way is
      // unreadable for most of its life.
      final alpha = t < 0.15 ? t / 0.15 : (1.0 - (t - 0.15) / 0.85);
      if (alpha <= 0.01) continue;
      // QUANTISED, for the same reason the fade is: a transform that changes
      // every frame is a transform nothing can cache, so a popping-in number
      // re-rasterises its glyphs from scratch on each of its first nine
      // frames. Eight steps is imperceptible in a 0.15s pop.
      final rawScale = t < 0.15 ? (0.7 + 0.4 * (t / 0.15)) : 1.0;
      final scale = t < 0.15
          ? (0.7 +
                0.4 *
                    ((rawScale - 0.7) / 0.4 * _fadeSteps).round() /
                    _fadeSteps)
          : 1.0;
      var step = (alpha * _fadeSteps).ceil() - 1;
      if (step < 0) step = 0;
      if (step >= _fadeSteps) step = _fadeSteps - 1;
      final tp = _painter(d.label, d.isBig, step);
      final offset = Offset(-tp.width / 2, -tp.height / 2);
      canvas.save();
      canvas.translate(d.position.dx, d.position.dy);
      if (scale != 1.0) canvas.scale(scale);
      tp.paint(canvas, offset);
      canvas.restore();
    }
  }
}
