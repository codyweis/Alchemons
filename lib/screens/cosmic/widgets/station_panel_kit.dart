// lib/screens/cosmic/widgets/station_panel_kit.dart
//
// What the screens behind the space stations share, so they read as the
// same instrument as the ship console and the home window: a full-screen
// panel over the held world, the station itself turning on a stage at the
// top (drawn by the painter that draws it in space), the wallet in bracket
// readouts, and one dock at the foot for the thing to do.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'cosmic_overlay_chrome.dart';
import 'cosmic_panel_kit.dart';
import 'cosmic_screen_styles.dart';

/// Opens a station's screen over the world. The world holds still under it
/// (the cosmic screen pauses for any route pushed over it).
Future<T?> showStationPanel<T>(BuildContext context, Widget panel) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => panel,
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        child: child,
      ),
    ),
  );
}

/// A station's screen: its name, the station on a stage, [body] and the
/// [dock].
class StationPanel extends StatelessWidget {
  const StationPanel({
    super.key,
    required this.kind,
    required this.body,
    this.dock,
    this.caption,
    this.highlight,
    this.stageHeight = 170,
    this.headerTrailing,
  });

  final StationKind kind;
  final Widget body;
  final Widget? dock;

  /// A word under the station on its stage.
  final String? caption;

  /// Which docked thing on the station to light (a pod, a key, a berth).
  final int? highlight;
  final double stageHeight;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    void close() {
      HapticFeedback.lightImpact();
      Navigator.of(context).maybePop();
    }

    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: close,
        alpha: 0.96,
        safeArea: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: SafeArea(
            child: Column(
              children: [
                PanelHeader(
                  title: kind.title,
                  trailing: headerTrailing,
                  onClose: close,
                ),
                SizedBox(
                  height: stageHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: StationStage(kind: kind, highlight: highlight),
                      ),
                      if (caption != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 8,
                          child: Text(
                            caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: panelLabel(10.5, panelPalette.muted),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: body),
                if (dock != null)
                  StationDock(accent: kind.accent, child: dock!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The foot of a station's screen.
class StationDock extends StatelessWidget {
  const StationDock({super.key, required this.accent, required this.child});
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: BoxDecoration(
      color: CosmicScreenStyles.bg1,
      border: Border(
        top: BorderSide(color: accent.withValues(alpha: 0.45), width: 1.2),
      ),
    ),
    child: child,
  );
}

/// The station turning on a panel's stage.
class StationStage extends StatefulWidget {
  const StationStage({super.key, required this.kind, this.highlight, this.aim});

  final StationKind kind;
  final int? highlight;
  final double? aim;

  @override
  State<StationStage> createState() => _StationStageState();
}

class _StationStageState extends State<StationStage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (d) => _clock.value = 4 + d.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _StationStagePainter(
        clock: _clock,
        kind: widget.kind,
        highlight: widget.highlight,
        aim: widget.aim,
      ),
    ),
  );
}

class _StationStagePainter extends CustomPainter {
  _StationStagePainter({
    required this.clock,
    required this.kind,
    required this.highlight,
    required this.aim,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final StationKind kind;
  final int? highlight;
  final double? aim;

  static final List<Float32List> _stars = () {
    final r = Random(19);
    return [
      for (var k = 0; k < 2; k++)
        Float32List.fromList([for (var i = 0; i < 46; i++) r.nextDouble()]),
    ];
  }();
  static final Paint _starPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(rect.center, size.longestSide * 0.6, [
          kind.accent.withValues(alpha: 0.08),
          kind.accent.withValues(alpha: 0),
        ]),
    );
    for (var k = 0; k < 2; k++) {
      final unit = _stars[k];
      final pts = Float32List(unit.length);
      for (var i = 0; i < unit.length; i += 2) {
        pts[i] = unit[i] * size.width;
        pts[i + 1] = unit[i + 1] * size.height;
      }
      _starPaint.color = Colors.white.withValues(alpha: k == 0 ? 0.18 : 0.4);
      canvas.drawRawPoints(ui.PointMode.points, pts, _starPaint);
    }
    final scale = size.height * 0.47 / kind.reach;
    canvas.save();
    canvas.clipRect(rect);
    paintStation(
      canvas,
      kind,
      at: rect.center - Offset(0, size.height * 0.04),
      t: clock.value,
      scale: scale,
      wake: 0.6,
      aim: aim,
      highlight: highlight,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StationStagePainter old) =>
      old.kind != kind || old.highlight != highlight || old.aim != aim;
}

/// Gold, silver and the shards in the hold, in bracket readouts.
class StationWallet extends StatelessWidget {
  const StationWallet({
    super.key,
    required this.gold,
    required this.silver,
    required this.shards,
    this.shardCapacity,
  });

  final int gold, silver, shards;
  final int? shardCapacity;

  @override
  Widget build(BuildContext context) => PanelRow(
    children: [
      PanelReadout(
        label: 'GOLD',
        value: formatCoins(gold),
        color: coinColor(CoinKind.gold),
        leading: const CoinIcon(kind: CoinKind.gold, size: 15),
      ),
      PanelReadout(
        label: 'SILVER',
        value: formatCoins(silver),
        color: coinColor(CoinKind.silver),
        leading: const CoinIcon(kind: CoinKind.silver, size: 15),
      ),
      PanelReadout(
        label: 'SHARDS IN THE HOLD',
        value: shardCapacity == null
            ? formatCoins(shards)
            : '${formatCoins(shards)}/${formatCoins(shardCapacity!)}',
        color: CosmicScreenStyles.astralShardColor,
        leading: Icon(
          CosmicScreenStyles.astralShardIcon,
          size: 14,
          color: CosmicScreenStyles.astralShardColor,
        ),
      ),
    ],
  );
}

/// A price: any of gold, silver and shards, the old figure struck through
/// beside each when it has come down.
class StationPrice extends StatelessWidget {
  const StationPrice({
    super.key,
    required this.cost,
    this.was,
    this.short = const {},
    this.size = 12,
  });

  /// Currency ('gold', 'silver', 'shards') → amount.
  final Map<String, int> cost;
  final Map<String, int>? was;

  /// The currencies there is not enough of; drawn in the warning color.
  final Set<String> short;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final e in cost.entries) {
      final before = was?[e.key];
      final lacking = short.contains(e.key);
      final color = lacking
          ? CosmicScreenStyles.danger
          : switch (e.key) {
              'gold' => coinColor(CoinKind.gold),
              'silver' => coinColor(CoinKind.silver),
              _ => CosmicScreenStyles.astralShardColor,
            };
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (before != null && before != e.value) ...[
              Text(
                formatCoins(before),
                style: panelLabel(
                  size - 1.5,
                  panelPalette.muted.withValues(alpha: 0.7),
                  spacing: 0.3,
                ).copyWith(decoration: TextDecoration.lineThrough),
              ),
              SizedBox(width: size * 0.4),
            ],
            if (e.key == 'shards')
              Icon(CosmicScreenStyles.astralShardIcon, size: size, color: color)
            else
              CoinIcon(
                kind: e.key == 'gold' ? CoinKind.gold : CoinKind.silver,
                size: size * 1.1,
              ),
            SizedBox(width: size * 0.3),
            Text(
              formatCoins(e.value),
              style: panelLabel(size, color, spacing: 0.4),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          rows[i],
        ],
      ],
    );
  }
}

/// A row on a station's list: picked, it is framed in the station's light.
class StationRow extends StatelessWidget {
  const StationRow({
    super.key,
    required this.accent,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: CustomPaint(
        foregroundPainter: selected
            ? BracketFramePainter(color: accent, bracketSize: 8)
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          color: selected
              ? accent.withValues(alpha: 0.08)
              : panelPalette.bg1.withValues(alpha: 0.45),
          child: child,
        ),
      ),
    );
  }
}

/// A line of plain words under a section header.
class StationNote extends StatelessWidget {
  const StationNote(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: color ?? CosmicScreenStyles.textSecondary,
        fontSize: 12.5,
        height: 1.35,
      ),
    ),
  );
}

/// What shows when the ship comes alongside a station: its name, what it
/// is for, and the one thing to do there. Tapping anywhere on it does it.
class StationPrompt extends StatelessWidget {
  const StationPrompt({
    super.key,
    required this.title,
    required this.line,
    required this.action,
    required this.accent,
    required this.onTap,
    this.enabled = true,
    this.trailing,
    this.reward,
  });

  final String title;
  final String line;
  final String action;
  final Color accent;
  final VoidCallback onTap;
  final bool enabled;

  /// On the button: what the action costs.
  final Widget? trailing;

  /// Above the button, on its own line: what the action wins. Kept off the
  /// button so it never reads as a price.
  final Widget? reward;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.75),
            bracketSize: 10,
            strokeWidth: 1.2,
          ),
          child: Container(
            color: CosmicScreenStyles.bg1.withValues(alpha: 0.92),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: panelLabel(12, accent, spacing: 2.2)),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: TextStyle(
                    color: CosmicScreenStyles.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                if (reward case final reward?) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'WIN',
                        style: panelLabel(10, panelPalette.muted, spacing: 1.8),
                      ),
                      const SizedBox(width: 10),
                      reward,
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                BracketButton(
                  label: action,
                  onTap: onTap,
                  enabled: enabled,
                  height: 40,
                  palette: panelPalette,
                  accent: accent,
                  trailing: trailing,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
