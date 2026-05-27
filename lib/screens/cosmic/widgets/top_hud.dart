import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'cosmic_screen_styles.dart';
import 'package:alchemons/widgets/app_icons.dart';

// Cosmic HUD always renders on the dark space backdrop.
const _palette = BracketPalette.dark;

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
            onTap: () => _setCollapsed(false),
            child: CustomPaint(
              painter: BracketFramePainter(
                color: _palette.line.withValues(alpha: 0.7),
                bracketSize: 7,
                strokeWidth: 1.05,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: _palette.bg0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.public_rounded, color: _palette.muted, size: 14),
                    const SizedBox(width: 7),
                    Text(
                      'Cosmos',
                      style: bracketText(
                        context,
                        12,
                        _palette.ink,
                        weight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 7),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: _palette.line.withValues(alpha: 0.7),
          bracketSize: 10,
          strokeWidth: 1.05,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          color: _palette.bg0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Settings button
                  _HudIconButton(
                    icon: AppIcons.settings_rounded,
                    onTap: widget.onSettings,
                  ),
                  const SizedBox(width: 10),
                  // Title + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Cosmos',
                          style: bracketText(
                            context,
                            15,
                            _palette.ink,
                            weight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${widget.planetsFound}/${widget.planetsTotal} planets  ·  ${(widget.discoveryPct * 100).toStringAsFixed(1)}% explored',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bracketText(
                            context,
                            11,
                            _palette.muted,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Resource chips
                  if (widget.wallet.shards > 0) ...[
                    _ResourceChip(
                      icon: CosmicScreenStyles.astralShardIcon,
                      iconColor: CosmicScreenStyles.astralShardColor,
                      label: '${widget.wallet.shards}',
                      labelColor: widget.wallet.shardsFull
                          ? Colors.redAccent
                          : CosmicScreenStyles.astralShardColor,
                      borderColor: widget.wallet.shardsFull
                          ? Colors.redAccent.withValues(alpha: 0.35)
                          : CosmicScreenStyles.astralShardColor.withValues(
                              alpha: 0.25,
                            ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Zoom button
                  if (widget.onZoomCycle != null) ...[
                    _HudIconButton(
                      icon: switch (widget.zoomLevel) {
                        0 => AppIcons.center_focus_strong_rounded,
                        1 => AppIcons.zoom_out_map_rounded,
                        _ => AppIcons.zoom_in_map_rounded,
                      },
                      iconColor: const Color(0xFF5BC8E8),
                      onTap: widget.onZoomCycle!,
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Collapse button
                  _HudIconButton(
                    icon: AppIcons.keyboard_arrow_up_rounded,
                    onTap: () => _setCollapsed(true),
                  ),
                ],
              ),

              // Alchemical meter
              if (widget.showMeter) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: widget.onMeterTap,
                  child: AnimatedBuilder(
                    animation: widget.meterPulse,
                    builder: (context, child) {
                      final full = widget.meter.isFull;
                      final glow = full ? widget.meterPulse.value : 0.0;
                      return CustomPaint(
                        painter: BracketFramePainter(
                          color: full
                              ? const Color(
                                  0xFFE4C16A,
                                ).withValues(alpha: 0.6 + glow * 0.4)
                              : _palette.line.withValues(alpha: 0.7),
                          bracketSize: 6,
                          strokeWidth: 1.05,
                        ),
                        child: SizedBox(height: 24, child: child),
                      );
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final breakdown = widget.meter.breakdown;
                        final total = widget.meter.total;
                        if (total <= 0) {
                          return ColoredBox(
                            color: _palette.bg1,
                            child: Center(
                              child: Text(
                                'Alchemical meter',
                                style: bracketText(
                                  context,
                                  10.5,
                                  _palette.muted,
                                  weight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          );
                        }

                        final sorted = breakdown.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(color: _palette.bg1),
                            ),
                            // Filled element segments — stretched to the full
                            // bar height so the colour actually shows.
                            Positioned.fill(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: sorted.map((e) {
                                  final pct =
                                      e.value / ElementMeter.maxCapacity;
                                  return Expanded(
                                    flex: (pct * 1000).round().clamp(1, 1000),
                                    child: ColoredBox(
                                      color: elementColor(e.key),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            Center(
                              child: Text(
                                widget.meter.isFull
                                    ? 'METER FULL — FLY TO A PLANET'
                                    : '${(widget.meter.fillPct * 100).toStringAsFixed(0)}% ALCHEMICAL',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
          child: Icon(icon, color: iconColor ?? _palette.muted, size: 16),
        ),
      ),
    );
  }
}

// ── Reusable resource chip ──────────────────────────────
class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: iconColor, width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: bracketText(
              context,
              11.5,
              labelColor,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// METER BREAKDOWN SHEET
// ─────────────────────────────────────────────────────────
