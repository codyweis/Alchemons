import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  CinematicQuality _cinematicQuality = CinematicQuality.high;

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
      final parentage = payload['parentage'] as Map<String, dynamic>?;
      if (parentage == null) return null;
      final types = <String>[];
      for (final key in ['parentA', 'parentB']) {
        final p = parentage[key] as Map<String, dynamic>?;
        final t = p?['types'] as List<dynamic>?;
        if (t != null && t.isNotEmpty) types.add(t.first.toString());
      }
      return types.isEmpty ? null : types;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── PARTICLE BANNER ──────────────────────────────────
                _ParticleBanner(
                  parentTypes: parentTypes,
                  rarityColor: rarityColor,
                  rarity: rarity,
                  isUndiscovered: widget.isUndiscovered,
                  theme: theme,
                  quality: _cinematicQuality,
                ),

                // ── INFO + ACTIONS PANEL ──────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: t.bg1,
                    border: Border(
                      left: BorderSide(color: t.borderMid, width: 1),
                      right: BorderSide(color: t.borderMid, width: 1),
                      bottom: BorderSide(color: t.borderMid, width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Heading row
                      Row(
                        children: [
                          // Accent bar
                          Container(
                            width: 3,
                            height: 32,
                            decoration: BoxDecoration(
                              color: rarityColor,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: rarityColor.withValues(alpha: .5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SPECIMEN READY',
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cultivation complete',
                                  style: TextStyle(
                                    color: theme.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: .4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              rarityColor.withValues(alpha: .35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Primary – EXTRACT
                      _ActionButton(
                        label: 'EXTRACT SPECIMEN',
                        icon: Icons.biotech_rounded,
                        accentColor: rarityColor,
                        filled: true,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          widget.onExtract();
                        },
                      ),

                      const SizedBox(height: 10),

                      // Secondary row – CLOSE + DISCARD
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'CLOSE',
                              icon: Icons.close_rounded,
                              accentColor: theme.textMuted,
                              filled: false,
                              onTap: widget.onCancel,
                            ),
                          ),
                          if (!widget.isTutorial) ...[
                            const SizedBox(width: 10),
                            Tooltip(
                              message: 'Discard specimen',
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: widget.onDiscard,
                                  splashColor: t.danger.withValues(alpha: .18),
                                  highlightColor: t.danger.withValues(
                                    alpha: .08,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: t.danger.withValues(alpha: .08),
                                      border: Border.all(
                                        color: t.danger.withValues(alpha: .35),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(13),
                                      child: Icon(
                                        Icons.delete_forever_rounded,
                                        size: 18,
                                        color: t.danger,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

    int particleCount;
    if (shortestSide < 380) {
      particleCount = 12;
    } else if (shortestSide < 430) {
      particleCount = 18;
    } else {
      particleCount = 24;
    }

    if (deferEffects) {
      particleCount = 8;
    }

    final qualityMultiplier = switch (quality) {
      CinematicQuality.high => 2.0,
      CinematicQuality.balanced => 1.0,
    };
    particleCount = (particleCount * qualityMultiplier).round().clamp(0, 64);

    final showParticles =
        TickerMode.of(context) && !media.disableAnimations && particleCount > 0;

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
                speedMultiplier: 0.12,
                fusion: true,
                theme: theme,
              ),
            )
          else
            Container(color: theme.surface),

          // Vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .5),
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
                    Colors.black.withValues(alpha: .65),
                  ],
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
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(4);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: accentColor.withValues(alpha: .18),
        highlightColor: accentColor.withValues(alpha: .08),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: filled
                ? accentColor.withValues(alpha: .9)
                : accentColor.withValues(alpha: .08),
            border: Border.all(
              color: filled
                  ? accentColor.withValues(alpha: .3)
                  : accentColor.withValues(alpha: .35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: filled ? Colors.white : accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
