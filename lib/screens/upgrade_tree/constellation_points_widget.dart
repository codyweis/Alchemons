import 'package:alchemons/audio/audio.dart';
// lib/widgets/constellation_points_widget.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/screens/cosmic/cosmic_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_screen.dart';
import 'package:alchemons/widgets/cosmic_ship_emblem.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// The way into space on home: the player's own ship, in grains, flying a
/// figure of eight (widgets/cosmic_ship_emblem.dart). Touched, it carries
/// them in — the ship grows into the middle of the screen, cruises there
/// while the cosmos is built, and lands on the real ship as space comes up.
/// Shown once the ship is unlocked.
class CosmicOrbWidget extends StatefulWidget {
  const CosmicOrbWidget({super.key, this.animate = true});

  /// Whether the ship flies (home stills it in performance mode).
  final bool animate;

  @override
  State<CosmicOrbWidget> createState() => _CosmicOrbWidgetState();
}

class _CosmicOrbWidgetState extends State<CosmicOrbWidget> {
  final GlobalKey _emblem = GlobalKey();
  final ValueNotifier<bool> _lifted = ValueNotifier(false);
  late final Future<String?> _unlocked = context
      .read<AlchemonsDatabase>()
      .settingsDao
      .getSetting('cosmic_ship_unlocked');

  @override
  void dispose() {
    _lifted.dispose();
    super.dispose();
  }

  void _open() {
    HapticFeedback.lightImpact();
    // The passage is the loading screen: the ship cruises in the middle of
    // the screen until the cosmos is built behind it.
    final ready = ValueNotifier<bool>(false);
    final target = ValueNotifier<ShipPassageTarget?>(null);
    EmblemPassage.pushScene<void>(
      context,
      scene: CosmicShipPassage(target: target),
      from: _emblem,
      page: CosmicScreen(revealReady: ready, passageTarget: target),
      ready: ready,
      lifted: _lifted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _unlocked,
      builder: (context, snapshot) {
        if (snapshot.data != '1') return const SizedBox.shrink();
        return GestureDetector(
          onTap: context.soundAction(_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: CosmicShipEmblem(
              key: _emblem,
              size: 90,
              animate: widget.animate,
              lifted: _lifted,
            ),
          ),
        );
      },
    );
  }
}

/// UPGRADE on home: the constellation emblem, a points badge when there are
/// points to spend, and the way into the ConstellationScreen through it.
class ConstellationPointsWidget extends StatefulWidget {
  const ConstellationPointsWidget({super.key, this.animate = true});

  /// Whether the emblem moves (home stills it in performance mode).
  final bool animate;

  @override
  State<ConstellationPointsWidget> createState() =>
      _ConstellationPointsWidgetState();
}

class _ConstellationPointsWidgetState extends State<ConstellationPointsWidget> {
  final GlobalKey _emblem = GlobalKey();
  final ValueNotifier<bool> _lifted = ValueNotifier(false);

  @override
  void dispose() {
    _lifted.dispose();
    super.dispose();
  }

  void _open() {
    HapticFeedback.lightImpact();
    final ready = ValueNotifier<bool>(false);
    final revealed = ValueNotifier<bool>(false);
    EmblemPassage.push<void>(
      context,
      kind: HomeEmblemKind.constellation,
      from: _emblem,
      page: ConstellationScreen(revealReady: ready, revealed: revealed),
      ready: ready,
      lifted: _lifted,
      revealed: revealed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final constellationService = context.watch<ConstellationService>();
    final tokens = ForgeTokens(context.watch<FactionTheme>());

    return StreamBuilder<int>(
      stream: constellationService.watchPointBalance(),
      initialData: 0,
      builder: (context, snapshot) {
        final points = snapshot.data ?? 0;

        return GestureDetector(
          onTap: context.soundAction(_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                HomeEmblem(
                  key: _emblem,
                  kind: HomeEmblemKind.constellation,
                  size: 80,
                  animate: widget.animate,
                  lifted: _lifted,
                ),
                // Points to spend: a small ink seal, brass-ringed, that
                // leaves with the emblem.
                if (points > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _lifted,
                      builder: (_, away, child) =>
                          away ? const SizedBox.shrink() : child!,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.bg1,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: tokens.amberBright,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$points',
                          style: TextStyle(
                            color: tokens.amberGlow,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
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
                      AppIcons.auto_awesome,
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
