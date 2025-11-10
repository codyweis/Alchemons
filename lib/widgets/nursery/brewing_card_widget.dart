// brewing_card_widget.dart (NurseryBrewingCard)

import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';

class NurseryBrewingCard extends StatefulWidget {
  final Egg egg;
  final VoidCallback onTap;
  final bool isReady;
  final Color statusColor;
  final bool useSimpleFusion;

  // NEW: optional progress (0..1)
  final double? progress;
  final FactionTheme? theme;

  const NurseryBrewingCard({
    super.key,
    required this.egg,
    required this.onTap,
    required this.isReady,
    required this.statusColor,
    this.progress, // NEW
    this.useSimpleFusion = false,
    this.theme,
  });

  @override
  State<NurseryBrewingCard> createState() => _NurseryBrewingCardState();
}

class _NurseryBrewingCardState extends State<NurseryBrewingCard> {
  List<String>? _parentTypes;

  @override
  void initState() {
    super.initState();
    _extractParentTypes();
  }

  void _extractParentTypes() {
    try {
      if (widget.egg.payloadJson == null || widget.egg.payloadJson!.isEmpty) {
        return;
      }
      final payload =
          jsonDecode(widget.egg.payloadJson!) as Map<String, dynamic>;
      final parentage = payload['parentage'] as Map<String, dynamic>?;

      if (parentage != null) {
        final parent1 = parentage['parentA'] as Map<String, dynamic>?;
        final parent2 = parentage['parentB'] as Map<String, dynamic>?;

        final types = <String>[];

        if (parent1 != null) {
          final p1Types = parent1['types'] as List<dynamic>?;
          if (p1Types != null && p1Types.isNotEmpty) {
            types.add(p1Types.first.toString());
          }
        }

        if (parent2 != null) {
          final p2Types = parent2['types'] as List<dynamic>?;
          if (p2Types != null && p2Types.isNotEmpty) {
            types.add(p2Types.first.toString());
          }
        }

        if (types.isNotEmpty) {
          _parentTypes = types;
        }
      }
    } catch (e) {
      // ignore parse errors; particles are cosmetic
    }
  }

  double _ease(double p, {double gamma = 2.0}) {
    final clamped = p.clamp(0.0, 1.0);
    return math.pow(clamped, gamma).toDouble(); // slow start → fast end
  }

  double get _speedFromProgress {
    if (widget.isReady) return 0.2;
    if (widget.progress != null) {
      // Map 0..1 progress to a 0.1..6.0 speed range with easing.
      const minSpeed = 0.1;
      const maxSpeed = 6.0;
      final eased = _ease(widget.progress!);
      return minSpeed + (maxSpeed - minSpeed) * eased;
    }

    // Fallback: original minutes-based buckets
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme!.brightness == Brightness.light
              ? const Color.fromARGB(255, 18, 18, 18)
              : Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme!.text, width: .2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              if (_parentTypes != null && _parentTypes!.isNotEmpty)
                Positioned.fill(
                  child: AlchemyBrewingParticleSystem(
                    parentATypeId: _parentTypes![0],
                    parentBTypeId: _parentTypes!.length > 1
                        ? _parentTypes![1]
                        : null,
                    particleCount: 80,
                    speedMultiplier: _speedFromProgress, // 👈 simplified
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
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
