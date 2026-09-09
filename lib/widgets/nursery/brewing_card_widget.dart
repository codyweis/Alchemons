import 'package:alchemons/audio/audio.dart';
// brewing_card_widget.dart (NurseryBrewingCard)
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';

class NurseryBrewingCard extends StatefulWidget {
  final Egg egg;
  final VoidCallback onTap;
  final bool isReady;
  final Color statusColor;
  final bool useSimpleFusion;

  final double? progress;
  final FactionTheme? theme;
  final CinematicQuality quality;

  const NurseryBrewingCard({
    super.key,
    required this.egg,
    required this.onTap,
    required this.isReady,
    required this.statusColor,
    this.progress,
    this.useSimpleFusion = false,
    this.theme,
    this.quality = CinematicQuality.cinematic,
  });

  @override
  State<NurseryBrewingCard> createState() => _NurseryBrewingCardState();
}

class _NurseryBrewingCardState extends State<NurseryBrewingCard> {
  List<String>? _parentTypes;
  String? _pureElementTypeId;

  @override
  void initState() {
    super.initState();
    _extractParticleTypes();
  }

  @override
  void didUpdateWidget(covariant NurseryBrewingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.egg.payloadJson != widget.egg.payloadJson) {
      _extractParticleTypes();
    }
  }

  void _extractParticleTypes() {
    final payload = parseEggPayload(widget.egg);
    final types = isBloodbornPayload(payload)
        ? const ['blood', 'dark']
        : extractParticleTypeIdsFromPayload(payload);
    _parentTypes = types.isEmpty ? null : types;

    // Elementally pure line: that element choreographs the whole brew.
    var pure = pureElementFromPayload(payload);
    if (pure == null &&
        types.length == 1 &&
        isElementallyPurePayload(payload)) {
      // Verdict without an element map (e.g. vial eggs): infer from the
      // single particle type.
      pure = types.first;
    }
    _pureElementTypeId = pure;
  }

  double get _speedFromProgress => brewingSpeedForProgress(
    progress: widget.progress,
    remaining: Duration(milliseconds: widget.egg.remainingMs),
    isReady: widget.isReady,
  );

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isLight = theme!.brightness == Brightness.light;
    final media = MediaQuery.of(context);
    final deferEffects = Scrollable.recommendDeferredLoadingForContext(context);
    final payload = parseEggPayload(widget.egg);
    final isBloodborn = isBloodbornPayload(payload);

    final shortestSide = media.size.shortestSide;
    int particleCount;
    if (shortestSide < 380) {
      particleCount = 42;
    } else if (shortestSide < 430) {
      particleCount = 56;
    } else {
      particleCount = 72;
    }

    // Ready state gets a slight boost for a livelier finished look.
    if (widget.isReady) {
      particleCount += 12;
    }

    final qualityMultiplier = switch (widget.quality) {
      CinematicQuality.cinematic => 1.0,
      CinematicQuality.performance => 0.6,
    };
    // A quarter more than the tiers above. Applied here rather than folded
    // into them so the device tiers stay legible as device tiers, and the
    // performance multiplier still scales the whole thing down.
    const density = 1.25;
    particleCount = (particleCount * qualityMultiplier * density).round().clamp(
      0,
      160,
    );

    if (deferEffects) {
      particleCount = math.min(particleCount, 12);
    }

    final showParticles =
        TickerMode.valuesOf(context).enabled &&
        !media.disableAnimations &&
        particleCount > 0;

    final palette = BracketPalette.fromTheme(theme);
    final lightModeReady = widget.isReady && isLight && !isBloodborn;
    final readyOuterFrameColor = isBloodborn
        ? kBloodbornReadyBorder
        : (lightModeReady
              ? palette.ink.withValues(alpha: 0.92)
              : const Color(0xFFFFD700));
    final readyInnerBorderColor = isBloodborn
        ? readyOuterFrameColor.withValues(alpha: 0.55)
        : (lightModeReady
              ? ForgeTokens(theme)
                    .readableAccent(const Color(0xFFFFD700))
                    .withValues(alpha: 0.92)
              : readyOuterFrameColor.withValues(alpha: 0.55));
    final fillColor = isLight ? palette.bg1 : Colors.black;
    // In light-mode ready we draw a dark outer outline plus a thinner gold
    // inset line; other states keep a single border.
    final Color borderColor;
    final double borderWidth;
    final Color? insetAccentColor;
    if (lightModeReady) {
      borderColor = palette.ink.withValues(alpha: 0.92);
      borderWidth = 1.4;
      insetAccentColor = ForgeTokens(
        theme,
      ).readableAccent(const Color(0xFFFFD700)).withValues(alpha: 0.95);
    } else {
      borderColor = widget.isReady
          ? readyInnerBorderColor
          : palette.lineSoft.withValues(alpha: 0.55);
      borderWidth = 1;
      insetAccentColor = null;
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: context.soundAction(widget.onTap),
        // A chamber is a vessel, so it is round — and nothing square around
        // it. The corner brackets read as leftover scaffolding once the fill
        // stopped being a box.
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          foregroundDecoration: insetAccentColor != null
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: insetAccentColor, width: 1),
                )
              : null,
          child: ClipOval(
            child: Stack(
              children: [
                if (showParticles &&
                    _parentTypes != null &&
                    _parentTypes!.isNotEmpty)
                  Positioned.fill(
                    child: AlchemyBrewingParticleSystem(
                      parentATypeId: _parentTypes![0],
                      parentBTypeId: _parentTypes!.length > 1
                          ? _parentTypes![1]
                          : null,
                      particleCount: particleCount,
                      speedMultiplier: _speedFromProgress,
                      fusion: widget.isReady,
                      pureElementTypeId: _pureElementTypeId,
                      useSimpleFusion: widget.useSimpleFusion,
                      theme: widget.theme,
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
