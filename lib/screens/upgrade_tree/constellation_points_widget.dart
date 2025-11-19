// lib/widgets/constellation_points_widget.dart
import 'package:alchemons/screens/upgrade_tree/constellation_screen.dart';
import 'package:alchemons/widgets/animations/alchemy_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Widget that displays constellation points on the home screen (next to currency)
class ConstellationPointsWidget extends StatelessWidget {
  const ConstellationPointsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final constellationService = context.watch<ConstellationService>();

    return StreamBuilder<int>(
      stream: constellationService.watchPointBalance(),
      initialData: 0,
      builder: (context, snapshot) {
        final points = snapshot.data ?? 0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConstellationScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Your icon wrapped as before
                    FloatingAlchemyOrb(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ConstellationScreen(),
                          ),
                        );
                      },
                    ),
                    // Badge for points (top-right corner)
                    if (points > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.primary, // Solid color or gradient
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: Text(
                            '$points',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Expanded version showing detailed info (for profile or stats screen)
class ConstellationPointsDetailWidget extends StatelessWidget {
  const ConstellationPointsDetailWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final constellationService = context.watch<ConstellationService>();

    return FutureBuilder<({int balance, int totalEarned, int totalSpent})>(
      future: constellationService.getPointInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final info = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [theme.primary, theme.secondary],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CONSTELLATION POINTS',
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _StatRow(
                theme: theme,
                label: 'Available',
                value: '${info.balance}',
                valueColor: theme.primary,
              ),
              _StatRow(
                theme: theme,
                label: 'Total Earned',
                value: '${info.totalEarned}',
              ),
              _StatRow(
                theme: theme,
                label: 'Total Spent',
                value: '${info.totalSpent}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.theme,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
