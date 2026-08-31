import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/nursery/cultivation_dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

class ExtractionDialog extends StatefulWidget {
  final IncubatorSlot slot;
  final Color primaryColor;
  final bool isUndiscovered;
  final VoidCallback onExtract;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;
  final bool isTutorial;

  const ExtractionDialog({
    super.key,
    required this.slot,
    required this.primaryColor,
    required this.isUndiscovered,
    required this.onExtract,
    required this.onDiscard,
    required this.onCancel,
    this.isTutorial = false,
  });

  @override
  State<ExtractionDialog> createState() => ExtractionDialogState();
}

class ExtractionDialogState extends State<ExtractionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;
  CinematicQuality _cinematicQuality = CinematicQuality.cinematic;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _slideAnim = Tween<double>(
      begin: 28,
      end: 0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
    _loadCinematicQuality();
    CinematicQualityService.qualityNotifier.addListener(
      _handleCinematicQualityChanged,
    );
  }

  void _handleCinematicQualityChanged() {
    if (!mounted) return;
    final next = CinematicQualityService.qualityNotifier.value;
    if (next != _cinematicQuality) {
      setState(() => _cinematicQuality = next);
    }
  }

  Future<void> _loadCinematicQuality() async {
    final q = await CinematicQualityService().getQuality();
    if (!mounted) return;
    setState(() => _cinematicQuality = q);
  }

  @override
  void dispose() {
    CinematicQualityService.qualityNotifier.removeListener(
      _handleCinematicQualityChanged,
    );
    _enterCtrl.dispose();
    super.dispose();
  }

  List<String>? _extractParentTypes() {
    try {
      final raw = widget.slot.payloadJson;
      if (raw == null || raw.isEmpty) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final types = extractParticleTypeIdsFromPayload(payload);
      return types.isEmpty ? null : types;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final palette = BracketPalette.fromTheme(theme);
    final rarity = (widget.slot.rarity ?? 'common').toLowerCase();
    final rarityColor = BreedConstants.getRarityColor(rarity);
    final parentTypes = _extractParentTypes();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: AnimatedBuilder(
        animation: _enterCtrl,
        builder: (context, child) => FadeTransition(
          opacity: _fadeAnim,
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: child,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                painter: BracketFramePainter(
                  color: rarityColor.withValues(alpha: 0.85),
                  bracketSize: 14,
                  strokeWidth: 1.4,
                ),
                child: Container(
                  color: palette.surfaceFill(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ParticleBanner(
                        parentTypes: parentTypes,
                        rarityColor: rarityColor,
                        rarity: rarity,
                        isUndiscovered: widget.isUndiscovered,
                        theme: theme,
                        quality: _cinematicQuality,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 3, height: 32, color: rarityColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Specimen ready',
                                    style: bracketText(
                                      context,
                                      18,
                                      palette.ink,
                                      weight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cultivation complete',
                                    style: bracketText(
                                      context,
                                      12.5,
                                      palette.muted,
                                      weight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  CultivationDialogActionArea(
                    tokens: t,
                    children: [
                      CultivationDialogButton(
                        tokens: t,
                        label: 'Extract specimen',
                        icon: AppIcons.biotech_rounded,
                        accentColor: rarityColor,
                        emphasis: CultivationDialogButtonEmphasis.primary,
                        useSolidBackground: true,
                        foregroundColor: Colors.white,
                        large: true,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          widget.onExtract();
                        },
                      ),
                      if (!widget.isTutorial) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: _DialogTextLink(
                            label: 'Discard specimen',
                            icon: AppIcons.delete_outline_rounded,
                            color: t.danger,
                            onTap: widget.onDiscard,
                          ),
                        ),
                      ],
                    ],
                  ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _DialogIconButton(
                  icon: AppIcons.close_rounded,
                  tooltip: 'Close',
                  palette: palette,
                  onTap: widget.onCancel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER ICON BUTTON + TEXT LINK
// ─────────────────────────────────────────────────────────────────────────────

class _DialogIconButton extends StatelessWidget {
  const _DialogIconButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final BracketPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: BracketFramePainter(
            color: palette.line.withValues(alpha: 0.7),
            bracketSize: 6,
            strokeWidth: 1,
          ),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            color: palette.surfaceMutedFill(),
            child: Icon(icon, size: 16, color: palette.muted),
          ),
        ),
      ),
    );
  }
}

class _DialogTextLink extends StatelessWidget {
  const _DialogTextLink({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Text(
              label,
              style: bracketText(
                context,
                12,
                color.withValues(alpha: 0.85),
                weight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICLE BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ParticleBanner extends StatelessWidget {
  const _ParticleBanner({
    required this.parentTypes,
    required this.rarityColor,
    required this.rarity,
    required this.isUndiscovered,
    required this.theme,
    required this.quality,
  });

  final List<String>? parentTypes;
  final Color rarityColor;
  final String rarity;
  final bool isUndiscovered;
  final FactionTheme theme;
  final CinematicQuality quality;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final deferEffects = Scrollable.recommendDeferredLoadingForContext(context);
    final shortestSide = media.size.shortestSide;
    final isLight = !theme.isDark;
    final overlayTint = isLight ? const Color(0xFF1B1D29) : Colors.black;
    final vignetteAlpha = isLight ? 0.0 : .5;
    final bottomFadeAlpha = isLight ? 0.0 : .65;

    // The "ready" banner is the payoff moment — push particles harder than
    // the in-cultivation dialog so completion reads as energetic.
    int particleCount;
    if (shortestSide < 380) {
      particleCount = 36;
    } else if (shortestSide < 430) {
      particleCount = 54;
    } else {
      particleCount = 72;
    }

    if (deferEffects) {
      particleCount = 18;
    }

    final qualityMultiplier = switch (quality) {
      CinematicQuality.cinematic => 1.0,
      CinematicQuality.performance => 0.4,
    };
    particleCount = (particleCount * qualityMultiplier).round().clamp(0, 110);

    final showParticles =
        TickerMode.valuesOf(context).enabled &&
        !media.disableAnimations &&
        particleCount > 0;

    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Particle background
          if (showParticles && parentTypes != null && parentTypes!.isNotEmpty)
            RepaintBoundary(
              child: AlchemyBrewingParticleSystem(
                parentATypeId: parentTypes![0],
                parentBTypeId: parentTypes!.length > 1 ? parentTypes![1] : null,
                particleCount: particleCount,
                speedMultiplier: 0.22,
                fusion: true,
                theme: theme,
              ),
            )
          else
            Container(color: theme.isDark ? theme.surface : Colors.white),

          // Vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [
                  Colors.transparent,
                  overlayTint.withValues(alpha: vignetteAlpha),
                ],
              ),
            ),
          ),

          // Bottom fade into panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    overlayTint.withValues(alpha: bottomFadeAlpha),
                  ],
                ),
              ),
            ),
          ),

          // Rarity-tinted hairline around the cultivation banner.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: rarityColor.withValues(alpha: isLight ? .55 : .45),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READY MEDALLION
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyMedallion extends StatefulWidget {
  const _ReadyMedallion({required this.rarityColor, required this.isLight});

  final Color rarityColor;
  final bool isLight;

  @override
  State<_ReadyMedallion> createState() => _ReadyMedallionState();
}

class _ReadyMedallionState extends State<_ReadyMedallion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discBg = widget.isLight
        ? const Color(0xFF1B1D29).withValues(alpha: .82)
        : Colors.black.withValues(alpha: .45);

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulseCtrl.value);
        final ringAlpha = 0.35 + (t * 0.45);
        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.rarityColor.withValues(alpha: ringAlpha),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: discBg,
                  border: Border.all(
                    color: widget.rarityColor.withValues(alpha: .55),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    AppIcons.check_rounded,
                    color: widget.rarityColor,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
