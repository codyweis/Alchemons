// brewing_card_widget.dart (NurseryBrewingCard)
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
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
    this.quality = CinematicQuality.high,
  });

  @override
  State<NurseryBrewingCard> createState() => _NurseryBrewingCardState();
}

class _NurseryBrewingCardState extends State<NurseryBrewingCard> {
  List<String>? _parentTypes;

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
  }

  double _ease(double p, {double gamma = 2.0}) {
    final clamped = p.clamp(0.0, 1.0);
    return math.pow(clamped, gamma).toDouble();
  }

  double get _speedFromProgress {
    if (widget.isReady) return 0.2;
    if (widget.progress != null) {
      const minSpeed = 0.1;
      const maxSpeed = 6.0;
      final eased = _ease(widget.progress!);
      return minSpeed + (maxSpeed - minSpeed) * eased;
    }

    final remaining = Duration(milliseconds: widget.egg.remainingMs);
    final totalMinutes = remaining.inMinutes;
    if (totalMinutes > 120) return 0.1;
    if (totalMinutes > 60) return 0.6;
    if (totalMinutes > 30) return 1.2;
    if (totalMinutes > 10) return 2.5;
    if (totalMinutes > 5) return 4.0;
    return 6.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final media = MediaQuery.of(context);
    final deferEffects = Scrollable.recommendDeferredLoadingForContext(context);
    final payload = parseEggPayload(widget.egg);
    final isBloodborn = isBloodbornPayload(payload);

    final shortestSide = media.size.shortestSide;
    int particleCount;
    if (shortestSide < 380) {
      particleCount = 18;
    } else if (shortestSide < 430) {
      particleCount = 24;
    } else {
      particleCount = 30;
    }

    // Apply quality multiplier first ...
    final qualityMultiplier = switch (widget.quality) {
      CinematicQuality.high => 2.0,
      CinematicQuality.balanced => 1.0,
    };
    particleCount = (particleCount * qualityMultiplier).round().clamp(0, 72);

    // FIX: ... then cap for deferred loading. Previously deferEffects ran
    // before the quality multiply, so high quality + defer gave 16 instead
    // of 8. Now the cap is applied to the already-scaled count.
    if (deferEffects) {
      particleCount = math.min(particleCount, 8);
    }

    final showParticles =
        TickerMode.valuesOf(context).enabled &&
        !media.disableAnimations &&
        particleCount > 0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme!.brightness == Brightness.light
                ? Colors.white
                : Colors.black,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.isReady
                  ? (isBloodborn
                        ? kBloodbornReadyBorder
                        : const Color(0xFFFFD700))
                  : (isBloodborn
                        ? kBloodbornSecondary.withValues(alpha: 0.75)
                        : theme.text.withValues(alpha: 0.5)),
              width: widget.isReady ? 1.0 : 0.5,
            ),
            boxShadow: widget.isReady
                ? [
                    BoxShadow(
                      color: (isBloodborn
                              ? kBloodbornSecondary
                              : const Color(0xFFFFD700))
                          .withValues(alpha: 0.18),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: (isBloodborn
                              ? kBloodbornPrimary
                              : const Color(0xFFFFD700))
                          .withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
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
                      useSimpleFusion: widget.useSimpleFusion,
                      theme: widget.theme,
                    ),
                  ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.1),
                        ],
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
}
