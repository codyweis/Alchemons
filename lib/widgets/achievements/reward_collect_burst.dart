import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The reward leaving the card and going where rewards go.
///
/// Runs in the root [Overlay] rather than inside the list, so the coins can
/// cross the whole screen — a burst clipped to its own row reads as a fizzle,
/// and the point of the beat is that the reward *arrives* somewhere.
Future<void> playRewardCollect(
  BuildContext context, {
  required Rect from,
  required Offset to,
  required int gold,
  required int silver,
  Color? tint,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || (gold <= 0 && silver <= 0)) return;

  // The burst paints over the live screen, so the coins take their palette
  // from the current theme — the dark-mode gold and silver wash out to
  // nothing against a light surface.
  final tokens = ForgeTokens(context.read<FactionTheme>());
  final coinGold = tokens.rewardGold;
  final coinSilver = tokens.rewardSilver;

  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: _RewardBurst(
          from: from,
          to: to,
          gold: gold,
          silver: silver,
          tint: tint,
          coinGold: coinGold,
          coinSilver: coinSilver,
          onDone: () {
            entry.remove();
            if (!completer.isCompleted) completer.complete();
          },
        ),
      ),
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _RewardBurst extends StatefulWidget {
  const _RewardBurst({
    required this.from,
    required this.to,
    required this.gold,
    required this.silver,
    required this.onDone,
    required this.coinGold,
    required this.coinSilver,
    this.tint,
  });

  final Rect from;
  final Offset to;
  final int gold;
  final int silver;
  final VoidCallback onDone;

  /// Theme-resolved coin colours, used when [tint] does not override them.
  final Color coinGold;
  final Color coinSilver;

  /// Overrides the gold/silver palette — a harvest pays out in its element,
  /// not in coins.
  final Color? tint;

  @override
  State<_RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<_RewardBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Coin> _coins;

  @override
  void initState() {
    super.initState();

    // Count reads the size of the reward without ever becoming a swarm: a
    // 1000-Silver payout should feel bigger than 100, but not fifty times so.
    int countFor(int amount) =>
        amount <= 0 ? 0 : (3 + math.sqrt(amount) * 1.1).round().clamp(3, 16);

    final rng = math.Random(widget.gold * 131 + widget.silver);
    _coins = [
      for (var i = 0; i < countFor(widget.gold); i++)
        _Coin.seeded(rng, widget.from, isGold: true),
      for (var i = 0; i < countFor(widget.silver); i++)
        _Coin.seeded(rng, widget.from, isGold: false),
    ]..shuffle(rng);

    _ctrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 980),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BurstPainter(
        coins: _coins,
        from: widget.from,
        to: widget.to,
        progress: _ctrl,
        tint: widget.tint,
        coinGold: widget.coinGold,
        coinSilver: widget.coinSilver,
      ),
    );
  }
}

class _Coin {
  _Coin({
    required this.origin,
    required this.scatter,
    required this.delay,
    required this.spin,
    required this.isGold,
    required this.size,
  });

  factory _Coin.seeded(math.Random rng, Rect from, {required bool isGold}) {
    // Born anywhere across the card, so the burst belongs to the whole row
    // rather than squirting out of one corner.
    final origin = Offset(
      from.left + rng.nextDouble() * from.width,
      from.top + rng.nextDouble() * from.height,
    );
    final angle = rng.nextDouble() * math.pi * 2;
    final reach = 26 + rng.nextDouble() * 54;
    return _Coin(
      origin: origin,
      scatter: Offset(math.cos(angle), math.sin(angle) - 0.55) * reach,
      // Staggered departure, so they stream rather than teleport as a block.
      delay: rng.nextDouble() * 0.28,
      spin: 0.6 + rng.nextDouble() * 2.4,
      isGold: isGold,
      size: 3.0 + rng.nextDouble() * 2.6,
    );
  }

  final Offset origin;
  final Offset scatter;
  final double delay;
  final double spin;
  final bool isGold;
  final double size;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.coins,
    required this.from,
    required this.to,
    required this.progress,
    required this.coinGold,
    required this.coinSilver,
    this.tint,
  }) : super(repaint: progress);

  final List<_Coin> coins;
  final Rect from;
  final Offset to;
  final Animation<double> progress;
  final Color? tint;
  final Color coinGold;
  final Color coinSilver;

  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;

    // The card answers first: a ring pushing out of it as the reward leaves.
    final ring = (t / 0.30).clamp(0.0, 1.0);
    if (ring > 0 && ring < 1) {
      final e = Curves.easeOutCubic.transform(ring);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          from.inflate(4 + 22 * e),
          const Radius.circular(4),
        ),
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1 - e)
          ..color = (tint ?? coinGold).withValues(alpha: 0.55 * (1 - e)),
      );
      _p.style = PaintingStyle.fill;
    }

    for (final coin in coins) {
      final local = ((t - coin.delay) / (1 - coin.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Thrown out first, then drawn in — a coin that flies straight at the
      // wallet reads as a UI transition, not as something being collected.
      final scatterK = Curves.easeOutCubic.transform(
        (local / 0.34).clamp(0.0, 1.0),
      );
      final flyK = Curves.easeInCubic.transform(
        ((local - 0.22) / 0.78).clamp(0.0, 1.0),
      );

      final loose = coin.origin + coin.scatter * scatterK;
      final pos = Offset.lerp(loose, to, flyK)!;

      // Spun edge-on and back, so they read as coins rather than dots.
      final flip = math.cos(local * math.pi * 2 * coin.spin).abs();
      final w = coin.size * (0.25 + 0.75 * flip);
      final fade = (1 - flyK * flyK).clamp(0.0, 1.0);
      if (fade <= 0.02) continue;

      final base = tint ?? (coin.isGold ? coinGold : coinSilver);
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: w * 3.4, height: coin.size * 3.4),
        _p..color = base.withValues(alpha: 0.18 * fade),
      );
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: w * 2, height: coin.size * 2),
        _p..color = base.withValues(alpha: 0.95 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.coins != coins ||
      old.from != from ||
      old.to != to ||
      old.tint != tint ||
      old.coinGold != coinGold ||
      old.coinSilver != coinSilver;
}
