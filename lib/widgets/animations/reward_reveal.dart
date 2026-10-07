// lib/widgets/animations/reward_reveal.dart
//
// REWARDS ARRIVING. Each reward's row opens as a faint slot, and the reward
// gathers into it out of drifting grains of its own colour: they come in
// from round the slot on a slow turn, trailing, settle where the item will
// be, and dim into it as the item's own art comes up. The name and amount
// follow. One after another, overlapping, eased at both ends — nothing
// bursts and nothing flashes.
//
// Shared by the end of a survival run (the results) and a loot box opened
// from the inventory, so a reward arrives the same way wherever it comes
// from. Points in batches, no blur; a row's grains paint only while it is
// arriving.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';

/// One reward: what it is, how many, and how to draw it.
class LootOpeningEntry {
  final IconData icon;
  final CoinKind? coin;
  final String label;
  final String? name;
  final Color color;
  final String? imagePath;
  final Widget Function(double size)? visualBuilder;

  const LootOpeningEntry({
    required this.icon,
    this.coin,
    required this.label,
    this.name,
    required this.color,
    this.imagePath,
    this.visualBuilder,
  });
}

/// A reward's own art, standing in a soft pool of its light — no disc, no
/// ring round it.
class RewardArt extends StatelessWidget {
  const RewardArt({super.key, required this.entry, required this.size});

  final LootOpeningEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget art;
    if (entry.visualBuilder != null) {
      art = entry.visualBuilder!(size);
    } else if (entry.imagePath != null) {
      art = Image.asset(
        entry.imagePath!,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    } else if (entry.coin != null) {
      art = CoinIcon(kind: entry.coin!, size: size * 0.72);
    } else {
      art = Icon(entry.icon, color: entry.color, size: size * 0.66);
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PoolPainter(entry.color),
        child: Center(child: art),
      ),
    );
  }
}

class _PoolPainter extends CustomPainter {
  const _PoolPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.78;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_PoolPainter old) => old.color != color;
}

/// The rewards, arriving one after another. Call [RewardRevealState.finish]
/// (through a GlobalKey) to have them all arrive at once.
class RewardReveal extends StatefulWidget {
  const RewardReveal({
    super.key,
    required this.entries,
    this.delay = Duration.zero,
    this.onTap,
    this.gap = 8,
  });

  final List<LootOpeningEntry> entries;

  /// Before the first starts to gather.
  final Duration delay;

  /// A row tapped: [showRewardDetail], usually.
  final ValueChanged<LootOpeningEntry>? onTap;
  final double gap;

  /// Between one reward starting to gather and the next.
  static const double stagger = 0.38;

  /// How long one takes to gather.
  static const double gather = 1.1;

  /// How long [n] rewards take to arrive, after [delay].
  static Duration lengthFor(int n) => Duration(
    milliseconds: (((math.max(n, 1) - 1) * stagger + gather) * 1000).round(),
  );

  @override
  State<RewardReveal> createState() => RewardRevealState();
}

class RewardRevealState extends State<RewardReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  late double _total;

  @override
  void initState() {
    super.initState();
    _total =
        widget.delay.inMilliseconds / 1000 +
        RewardReveal.lengthFor(widget.entries.length).inMilliseconds / 1000;
    _t = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).round()),
    )..forward();
  }

  /// Every reward in place now.
  void finish() {
    if (_t.isAnimating) _t.value = 1;
  }

  bool get arriving => _t.isAnimating;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.delay.inMilliseconds / 1000;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.entries.length; i++) ...[
          if (i > 0) SizedBox(height: widget.gap),
          _RevealRow(
            index: i,
            entry: widget.entries[i],
            arrival: _t.drive(
              CurveTween(
                curve: Interval(
                  ((start + i * RewardReveal.stagger) / _total).clamp(0, 1),
                  ((start + i * RewardReveal.stagger + RewardReveal.gather) /
                          _total)
                      .clamp(0, 1),
                ),
              ),
            ),
            onTap: widget.onTap,
          ),
        ],
      ],
    );
  }
}

class _RevealRow extends StatelessWidget {
  const _RevealRow({
    required this.index,
    required this.entry,
    required this.arrival,
    this.onTap,
  });

  final int index;
  final LootOpeningEntry entry;

  /// 0 → 1 over this row's arrival.
  final Animation<double> arrival;
  final ValueChanged<LootOpeningEntry>? onTap;

  @override
  Widget build(BuildContext context) {
    Animation<double> phase(double a, double b) =>
        arrival.drive(CurveTween(curve: Interval(a, b, curve: Curves.easeOut)));
    final slot = phase(0, 0.3);
    final art = phase(0.5, 0.95);
    final words = phase(0.6, 1);
    return FadeTransition(
      opacity: slot,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : context.soundAction(() => onTap!(entry)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: entry.color.withValues(alpha: 0.05),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: FadeTransition(
                        opacity: art,
                        child: RewardArt(entry: entry, size: 46),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _GatherPainter(
                            arrival,
                            entry.color,
                            seed: index,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FadeTransition(
                  opacity: words,
                  child: Text(
                    (entry.name ?? '').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FadeTransition(
                opacity: words,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: entry.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        AppIcons.chevron_right_rounded,
                        color: entry.color.withValues(alpha: 0.45),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reward gathering out of grains of its colour into the middle of its
/// slot. They start spread along the reward's own row — where its name and
/// amount will be — and drift in on a gentle arc, so the row fills from the
/// inside rather than being sprayed into from off the edge. Paints only
/// while it is arriving.
class _GatherPainter extends CustomPainter {
  _GatherPainter(this.arrival, this.color, {required int seed})
    : _g = _grains(seed),
      super(repaint: arrival);

  final Animation<double> arrival;
  final Color color;
  final List<_Grain> _g;

  static const int _count = 46;
  static final Map<int, List<_Grain>> _cache = {};

  /// Where each grain starts (along the row, from the slot's centre), where
  /// it settles, how far its path bows, when it sets off, and whether it is
  /// one of the lit ones. Eight layouts, shared round the rows.
  static List<_Grain> _grains(int seed) => _cache.putIfAbsent(seed % 8, () {
    final r = math.Random(31 + seed % 8 * 17);
    return [
      for (var i = 0; i < _count; i++)
        () {
          final settle = r.nextDouble() * 12;
          final at = r.nextDouble() * 2 * math.pi;
          return _Grain(
            sx: -14 + math.pow(r.nextDouble(), 0.85) * 250,
            sy: (r.nextDouble() - 0.5) * 40,
            ex: math.cos(at) * settle,
            ey: math.sin(at) * settle * 0.8,
            bow: (r.nextBool() ? 1 : -1) * (4 + r.nextDouble() * 12),
            delay: r.nextDouble() * 0.22,
            hot: i % 4 == 0,
          );
        }(),
    ];
  });

  // Buckets: (lit | plain) × trail (head, mid, tail) × fade-in (3 steps).
  static final List<Float32List> _buf = List.generate(
    18,
    (_) => Float32List(_count * 2),
  );
  static final List<int> _n = List.filled(18, 0);
  static final Paint _dot = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final p = arrival.value;
    if (p <= 0 || p >= 1) return;
    // Dimming into the art as it comes up.
    final dissolve = 1 - _ease(0.7, 1, p);
    if (dissolve <= 0.01) return;
    final c = size.center(Offset.zero);
    _n.fillRange(0, 18, 0);
    for (final g in _g) {
      // The arc's bow, square to the line it travels.
      final lx = g.ex - g.sx, ly = g.ey - g.sy;
      final len = math.max(1.0, math.sqrt(lx * lx + ly * ly));
      final nx = -ly / len, ny = lx / len;
      for (var k = 0; k < 3; k++) {
        final q = ((p - g.delay - k * 0.035) / 0.62).clamp(0.0, 1.0);
        if (q <= 0) continue;
        final e = q * q * q * (q * (q * 6 - 15) + 10);
        final bow = g.bow * math.sin(math.pi * e);
        final fade = q < 0.07 ? 0 : (q < 0.15 ? 1 : 2);
        final b = (g.hot ? 9 : 0) + k * 3 + fade;
        final i = _n[b] * 2;
        _buf[b][i] = c.dx + g.sx + lx * e + nx * bow;
        _buf[b][i + 1] = c.dy + g.sy + ly * e + ny * bow;
        _n[b]++;
      }
    }
    final lit = Color.lerp(color, Colors.white, 0.55)!;
    const trail = [1.0, 0.42, 0.18];
    const fadeIn = [0.3, 0.65, 1.0];
    for (var h = 0; h < 2; h++) {
      for (var k = 0; k < 3; k++) {
        for (var f = 0; f < 3; f++) {
          final b = h * 9 + k * 3 + f;
          if (_n[b] == 0) continue;
          _dot
            ..strokeWidth = (h == 1 ? 2.4 : 1.9) * (1 - 0.15 * k)
            ..color = (h == 1 ? lit : color).withValues(
              alpha: (0.9 * trail[k] * fadeIn[f] * dissolve).clamp(0.0, 1.0),
            );
          canvas.drawRawPoints(
            ui.PointMode.points,
            Float32List.sublistView(_buf[b], 0, _n[b] * 2),
            _dot,
          );
        }
      }
    }
  }

  static double _ease(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(_GatherPainter old) =>
      old.arrival != arrival || old.color != color;
}

class _Grain {
  const _Grain({
    required this.sx,
    required this.sy,
    required this.ex,
    required this.ey,
    required this.bow,
    required this.delay,
    required this.hot,
  });
  final double sx, sy, ex, ey, bow, delay;
  final bool hot;
}

/// One reward, close up: its art in its light, what it is and how many.
Future<void> showRewardDetail(BuildContext context, LootOpeningEntry entry) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: entry.color.withValues(alpha: 0.9),
          strokeWidth: 1.3,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          constraints: const BoxConstraints(maxWidth: 320),
          color: BracketPalette.dark.bg1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RewardArt(entry: entry, size: 84),
              const SizedBox(height: 16),
              if (entry.name != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    entry.name!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: BracketPalette.dark.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              Text(
                entry.label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: entry.color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: context.soundAction(() => Navigator.pop(dialogCtx)),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  alignment: Alignment.center,
                  color: entry.color.withValues(alpha: 0.1),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: entry.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
