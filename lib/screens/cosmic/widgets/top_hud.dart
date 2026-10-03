import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/cosmic/poi_art.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'cosmic_panel_kit.dart' show panelLabel;
import 'cosmic_screen_styles.dart';
import 'star_chart_art.dart';
import 'package:alchemons/widgets/app_icons.dart';

// Cosmic HUD always renders on the dark space backdrop.
const _palette = BracketPalette.dark;

// ─────────────────────────────────────────────────────────
// METER / RECIPE ALIGNMENT
//
// The recipe's target notches are drawn onto the meter fill, so "matching the
// recipe" reads as "line your colours up with the marks". That only works if
// both are laid out in the SAME order — hence one function for each, used by
// both the fill and the painter, and a test that pins them together.
// ─────────────────────────────────────────────────────────

/// The meter's element segments in the order they are drawn, left to right.
List<MapEntry<String, double>> meterSegmentsInDrawOrder(ElementMeter meter) {
  return meter.breakdown.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
}

/// The recipe's target components in the order their notches are drawn.
/// Must match [meterSegmentsInDrawOrder]'s ordering rule.
List<MapEntry<String, double>> recipeTargetsInDrawOrder(PlanetRecipe recipe) {
  return recipe.components.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
}

class TopHud extends StatefulWidget {
  const TopHud({
    super.key,
    required this.theme,
    required this.meter,
    required this.meterPulse,
    required this.discoveryPct,
    required this.planetsFound,
    required this.planetsTotal,
    required this.wallet,
    required this.onSettings,
    required this.onMiniMap,
    required this.onMeterTap,
    this.showMeter = true,
    this.recipe,
    this.dustCollected = 0,
    this.dustTotal = 0,
    this.collapsed = false,
    this.onCollapsedChanged,
    this.zoomLevel = 0,
    this.onZoomCycle,
  });

  final FactionTheme theme;
  final ElementMeter meter;
  final AnimationController meterPulse;
  final double discoveryPct;
  final int planetsFound;
  final int planetsTotal;
  final ShipWallet wallet;
  final VoidCallback onSettings;
  final VoidCallback onMiniMap;
  final VoidCallback onMeterTap;
  final bool showMeter;

  /// Recipe of the planet the ship is standing at, if any. When set, its
  /// target percentages are drawn onto the meter as notches, so matching the
  /// recipe becomes "line your colours up with the marks" rather than reading
  /// a separate card.
  final PlanetRecipe? recipe;

  /// Star dust swept, and how much there is. Rendered as a resource chip
  /// inside the card — it used to float over the card as its own Positioned,
  /// which collided with the shard chip and ignored the collapse toggle.
  final int dustCollected;
  final int dustTotal;
  final bool collapsed;
  final ValueChanged<bool>? onCollapsedChanged;
  final int zoomLevel;
  final VoidCallback? onZoomCycle;

  @override
  State<TopHud> createState() => TopHudState();
}

class TopHudState extends State<TopHud> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapsed;
  }

  @override
  void didUpdateWidget(covariant TopHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != oldWidget.collapsed &&
        widget.collapsed != _collapsed) {
      _collapsed = widget.collapsed;
    }
  }

  void _setCollapsed(bool value) {
    if (_collapsed == value) return;
    setState(() => _collapsed = value);
    widget.onCollapsedChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
          child: GestureDetector(
            onTap: context.soundAction(() => _setCollapsed(false)),
            child: CustomPaint(
              painter: BracketFramePainter(
                color: _palette.line.withValues(alpha: 0.7),
                bracketSize: 7,
                strokeWidth: 1.05,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                color: _palette.bg0.withValues(alpha: 0.86),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'COSMOS',
                      style: panelLabel(11, _palette.ink, spacing: 2.4),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      AppIcons.keyboard_arrow_down_rounded,
                      color: _palette.muted,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final full = widget.meter.isFull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: _palette.line.withValues(alpha: 0.7),
          bracketSize: 10,
          strokeWidth: 1.05,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          color: _palette.bg0.withValues(alpha: 0.86),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HudIconButton(
                    icon: AppIcons.settings_rounded,
                    onTap: context.soundTap(widget.onSettings),
                  ),
                  const SizedBox(width: 10),
                  // Title + where the voyage stands. When the meter is full
                  // the second line says what to do about it.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'COSMOS',
                          style: panelLabel(13, _palette.ink, spacing: 2.6),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            full
                                ? 'FULL · FLY TO A PLANET'
                                : '${widget.planetsFound}/${widget.planetsTotal} '
                                      'PLANETS · '
                                      '${(widget.discoveryPct * 100).toStringAsFixed(0)}%',
                            maxLines: 1,
                            style: panelLabel(
                              9,
                              full ? kChartAmber : _palette.muted,
                              spacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.dustCollected > 0) ...[
                    _HudReading(
                      symbol: const ChartSymbolPainter(paintDustGlyph),
                      label:
                          '${widget.dustCollected}/'
                          '${widget.dustTotal <= 0 ? 50 : widget.dustTotal}',
                      color: CosmicScreenStyles.amberBright,
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (widget.wallet.shards > 0) ...[
                    _HudReading(
                      symbol: const ChartSymbolPainter(_paintShardGlyph),
                      label: '${widget.wallet.shards}',
                      color: widget.wallet.shardsFull
                          ? CosmicScreenStyles.danger
                          : const Color(0xFFCDB0FF),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (widget.onZoomCycle != null) ...[
                    _HudIconButton(
                      icon: switch (widget.zoomLevel) {
                        0 => AppIcons.center_focus_strong_rounded,
                        1 => AppIcons.zoom_out_map_rounded,
                        _ => AppIcons.zoom_in_map_rounded,
                      },
                      onTap: widget.onZoomCycle!,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _HudIconButton(
                    icon: AppIcons.keyboard_arrow_up_rounded,
                    onTap: context.soundTap(() => _setCollapsed(true)),
                  ),
                ],
              ),

              // Alchemical meter
              if (widget.showMeter) ...[
                const SizedBox(height: 9),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: context.soundAction(widget.onMeterTap),
                  child: Row(
                    children: [
                      Expanded(
                        // The full-meter breath repaints the tube's frame
                        // alone, not the whole HUD.
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: widget.meterPulse,
                            builder: (context, child) {
                              final glow = full ? widget.meterPulse.value : 0.0;
                              return CustomPaint(
                                foregroundPainter: BracketFramePainter(
                                  color: full
                                      ? kChartAmber.withValues(
                                          alpha: 0.55 + glow * 0.45,
                                        )
                                      : _palette.line.withValues(alpha: 0.7),
                                  bracketSize: 6,
                                  strokeWidth: 1.05,
                                ),
                                child: child,
                              );
                            },
                            child: SizedBox(
                              height: 20,
                              child: CustomPaint(
                                painter: _MeterTubePainter(
                                  segments: meterSegmentsInDrawOrder(
                                    widget.meter,
                                  ),
                                  recipe: widget.recipe,
                                ),
                                child: widget.meter.total <= 0
                                    ? Center(
                                        child: Text(
                                          'ALCHEMICAL METER',
                                          style: panelLabel(
                                            8.5,
                                            _palette.muted,
                                            spacing: 1.6,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          full
                              ? 'FULL'
                              : '${(widget.meter.fillPct * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: panelLabel(
                            11,
                            full ? kChartAmber : _palette.ink,
                            spacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _paintShardGlyph(Canvas c, Offset at, double s) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(s / 30);
  paintAstralShard(c, at: Offset.zero, t: 0.4);
  c.restore();
}

/// The alchemical meter as a tube of glass with the essences packed into it
/// in bands, lit from above, flecked with their grains. The active recipe's
/// targets sit on it as small notches above and below, with a dark cut
/// through the fill at each one: a band that stops short of its notch is
/// under, one that runs past it is over.
class _MeterTubePainter extends CustomPainter {
  _MeterTubePainter({required this.segments, this.recipe});

  final List<MapEntry<String, double>> segments;
  final PlanetRecipe? recipe;

  static final PointBatch _flecks = PointBatch(200);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // The empty glass.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [Color(0xFF181A24), Color(0xFF090A0F), Color(0xFF10111A)],
          const [0.0, 0.6, 1.0],
        ),
    );

    var x = 0.0;
    for (final e in segments) {
      final w = size.width * (e.value / ElementMeter.maxCapacity);
      if (w <= 0.2) continue;
      final band = Rect.fromLTWH(x, 0, w, size.height);
      // Muted toward the glass, so a band reads as matter in a tube rather
      // than a flat swatch.
      final col = Color.lerp(
        elementColor(e.key),
        const Color(0xFF16141E),
        0.18,
      )!;
      final hsl = HSLColor.fromColor(col);
      final lit = hsl
          .withLightness((hsl.lightness + 0.18).clamp(0.0, 0.85))
          .toColor();
      final deep = hsl
          .withLightness((hsl.lightness * 0.45).clamp(0.0, 1.0))
          .toColor();
      canvas.drawRect(
        band,
        Paint()
          ..shader = ui.Gradient.linear(
            band.topCenter,
            band.bottomCenter,
            [lit, col, deep],
            const [0.0, 0.42, 1.0],
          ),
      );
      // Its grains, settled through the band.
      _flecks.clear();
      final n = (w / 3).clamp(1, 60).toInt();
      final salt = e.key.codeUnitAt(0) * 7 + e.key.length;
      for (var i = 0; i < n; i++) {
        _flecks.add(
          x + hash01(i, salt) * w,
          size.height * (0.15 + 0.8 * hash01(i, salt + 3)),
        );
      }
      _flecks.draw(canvas, 1.3, lit.withValues(alpha: 0.75));
      x += w;
    }

    // The glass's own highlight along the top.
    canvas.drawRect(
      Rect.fromLTWH(0, 1, size.width, size.height * 0.28),
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          Offset(0, size.height * 0.3),
          const [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
        ),
    );

    final r = recipe;
    if (r != null) {
      var cumulative = 0.0;
      final cut = Paint()
        ..color = const Color(0xCC050507)
        ..strokeWidth = 1.6;
      for (final e in recipeTargetsInDrawOrder(r)) {
        cumulative += e.value;
        if (cumulative >= 100) break;
        final nx = size.width * (cumulative / 100);
        canvas.drawLine(Offset(nx, 0), Offset(nx, size.height), cut);
        final ink = Paint()..color = elementInk(e.key);
        // Notches outside the glass, pointing in, so the fill never hides
        // them.
        canvas.drawPath(
          Path()
            ..moveTo(nx, 0)
            ..lineTo(nx - 3.5, -5)
            ..lineTo(nx + 3.5, -5)
            ..close(),
          ink,
        );
        canvas.drawPath(
          Path()
            ..moveTo(nx, size.height)
            ..lineTo(nx - 3.5, size.height + 5)
            ..lineTo(nx + 3.5, size.height + 5)
            ..close(),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MeterTubePainter old) {
    if (old.recipe != recipe || old.segments.length != segments.length) {
      return true;
    }
    for (var i = 0; i < segments.length; i++) {
      if (old.segments[i].key != segments[i].key ||
          old.segments[i].value != segments[i].value) {
        return true;
      }
    }
    return false;
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: _palette.line.withValues(alpha: 0.7),
          bracketSize: 6,
          strokeWidth: 1,
        ),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          color: _palette.surfaceMutedFill(),
          child: Icon(icon, color: _palette.muted, size: 16),
        ),
      ),
    );
  }
}

/// A count with its symbol: the thing itself, drawn small, then the figure.
class _HudReading extends StatelessWidget {
  const _HudReading({
    required this.symbol,
    required this.label,
    required this.color,
  });

  final CustomPainter symbol;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 18, child: CustomPaint(painter: symbol)),
        const SizedBox(width: 4),
        Text(label, style: panelLabel(11.5, color, spacing: 0.4)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// METER BREAKDOWN SHEET
// ─────────────────────────────────────────────────────────
