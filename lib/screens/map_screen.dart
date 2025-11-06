import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/pulsing_hitbox_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/screens/party_picker.dart';
import 'package:alchemons/screens/scenes/scene_page.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_access_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/wilderness/countdown_badge.dart';
import '../providers/app_providers.dart'; // for FactionTheme

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return Scaffold(
      backgroundColor: theme.surfaceAlt,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HeaderBar(
              onBack: () => Navigator.pop(context),
              theme: theme,
              onInfo: () {
                showDialog(
                  context: context,
                  builder: (_) => _InfoDialog(theme: theme),
                );
              },
            ),

            const SizedBox(height: 12),

            _PartyStatusCard(
              theme: theme,
              onTap: () async {
                HapticFeedback.selectionClick();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PartyPickerPage()),
                );
              },
            ),

            const SizedBox(height: 16),

            // MAP AREA
            Expanded(
              child: _ExpeditionMap(
                theme: theme,
                onSelectRegion: (biomeId, scene) {
                  _handleRegionTap(context, biomeId, scene);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // TAP HANDLER FOR MAP MARKERS
  // --------------------------------------------------
  Future<void> _handleRegionTap(
    BuildContext context,
    String biomeId,
    SceneDefinition scene,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final access = WildernessAccessService(db);
    final factions = context.read<FactionService>();
    final spawnService = context.read<WildernessSpawnService>();

    if (spawnService.getSceneSpawnCount(biomeId) == 0) {
      _showToast(
        context,
        'No creatures detected in this area',
        Icons.search_off_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    // check access / refresh if earth faction perk
    var ok = await access.canEnter(biomeId);
    if (!ok && await factions.earthCanRefreshToday(biomeId)) {
      final useRefresh = await _showRefreshDialog(context);
      if (useRefresh == true) {
        await access.refreshWilderness(biomeId);
        await factions.earthMarkRefreshedToday(biomeId);

        if (!context.mounted) return;
        _showToast(
          context,
          'LandExplorer activated: breeding ground refreshed.',
          Icons.forest_rounded,
          Colors.green.shade400,
        );

        ok = true;
      }
    }

    if (!ok) {
      final left = access.timeUntilReset();
      final hh = left.inHours;
      final mm = left.inMinutes.remainder(60);
      final ss = left.inSeconds.remainder(60);

      if (!context.mounted) return;
      _showToast(
        context,
        'Breeding ground refreshes in ${hh}h ${mm}m ${ss}s',
        Icons.schedule_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    // choose party
    if (!context.mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PartyPickerPage()),
    );
    if (result == null) return;

    final selectedParty = (result as List).cast<PartyMember>();

    // consume entry
    await access.markEntered(biomeId);

    // go to biome scene
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScenePage(scene: scene, sceneId: biomeId, party: selectedParty),
      ),
    );
  }

  Future<bool?> _showRefreshDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const _RefreshDialog(),
    );
  }

  void _showToast(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// HEADER BAR
// =====================================================

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.theme,
    required this.onInfo,
    required this.onBack,
  });

  final FactionTheme theme;
  final VoidCallback onInfo;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          // top row: back + info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back), // Use a standard back icon
                onPressed: onBack,
              ),
              // center title/subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BREEDING EXPEDITIONS',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Discover wild creatures & attempt crossbreeds',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .4,
                    ),
                  ),
                ],
              ),

              // info
              GestureDetector(
                onTap: onInfo,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: theme.chipDecoration(rim: theme.accent),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: theme.text,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// PARTY STATUS CARD
// =====================================================

class _PartyStatusCard extends StatelessWidget {
  const _PartyStatusCard({required this.theme, required this.onTap});

  final FactionTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: theme.chipDecoration(rim: theme.accent),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Breeding Team',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose which party goes into the wild',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// MAP + MARKERS
// =====================================================
class _ExpeditionMap extends StatelessWidget {
  const _ExpeditionMap({required this.theme, required this.onSelectRegion});

  final FactionTheme theme;
  final void Function(String biomeId, SceneDefinition scene) onSelectRegion;

  @override
  Widget build(BuildContext context) {
    // We still grab access here if you want to later show “locked”
    // info in tooltips/etc. For now we’re not drawing those bubbles,
    // so we don’t actually need the futures.
    final db = context.read<AlchemonsDatabase>();
    final access = WildernessAccessService(db);

    return LayoutBuilder(
      builder: (context, constraints) {
        // This is the actual rendered size of the map stack.
        final mapW = constraints.maxWidth;
        final mapH = constraints.maxHeight;

        // Helper: create a positioned, invisible-but-tappable area.
        Widget hotspot({
          required double leftPct,
          required double topPct,
          required String biomeId,
          required SceneDefinition scene,
        }) {
          final dx = mapW * leftPct;
          final dy = mapH * topPct;

          // Check if this scene has any active spawns
          final spawnService = context.watch<WildernessSpawnService>();
          final hasSpawns = scene.spawnPoints.any(
            (sp) => spawnService.hasSpawnAt(biomeId, sp.id),
          );

          return Positioned(
            left: dx - 70,
            top: dy - 70,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectRegion(biomeId, scene),
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Only show pulse if spawns exist
                    if (hasSpawns)
                      PulsingDebugHitbox(
                        size: 125,
                        color: Colors.red,
                        clipOval: true,
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            ClipOval(
              child: Container(
                color: const Color.fromARGB(255, 48, 69, 82),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/images/ui/map.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // === HOTSPOTS =================================================
            hotspot(
              leftPct: 0.3,
              topPct: 0.2,
              biomeId: 'valley',
              scene: valleyScene,
            ),
            hotspot(
              leftPct: 0.72,
              topPct: 0.2,
              biomeId: 'sky',
              scene: skyScene,
            ),
            hotspot(
              leftPct: 0.25,
              topPct: 0.48,
              biomeId: 'volcano',
              scene: volcanoScene,
            ),
            hotspot(
              leftPct: 0.72,
              topPct: 0.48,
              biomeId: 'swamp',
              scene: swampScene,
            ),

            // Hint bar pinned to bottom
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _MapHintBar(theme: theme),
            ),
          ],
        );
      },
    );
  }
}

class _MarkerTapWrapper extends StatefulWidget {
  const _MarkerTapWrapper({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_MarkerTapWrapper> createState() => _MarkerTapWrapperState();
}

class _MarkerTapWrapperState extends State<_MarkerTapWrapper> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        scale: _down ? 0.94 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Touchable hotspot area for the biome icon itself.
            // (This is invisible but ensures the hit box is chunky.)
            SizedBox(
              width: 64,
              height: 64,
              // uncomment to debug tap zones:
              // child: ColoredBox(color: Colors.red.withOpacity(.2)),
            ),
            const SizedBox(height: 6),
            widget.child,
          ],
        ),
      ),
    );
  }
}

// hint / legend bar at bottom of the map
class _MapHintBar extends StatelessWidget {
  const _MapHintBar({required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.accent.withOpacity(.35), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: theme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Wild creatures detected here! Tap to explore.',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// INFO DIALOG
// =====================================================

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.theme});
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.accent, width: 1.4),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_rounded, color: theme.accent, size: 28),
            const SizedBox(height: 12),
            Text(
              'Breeding Expeditions',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wild areas will light up when a creature has been detected. Venture into diverse biomes to discover new creatures. Successful breeding or harvesting will create an offspring you can extract in the Incubator.',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.accent, width: 1.4),
                ),
                alignment: Alignment.center,
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: theme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// REFRESH DIALOG
// =====================================================

class _RefreshDialog extends StatelessWidget {
  const _RefreshDialog();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.greenAccent.withOpacity(.5),
            width: 1.4,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forest_rounded,
              color: Colors.greenAccent.withOpacity(.9),
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'LandExplorer',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Use today's instant refresh to reopen this ground?",
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(.14),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'NOT NOW',
                        style: TextStyle(
                          color: theme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // confirm
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(.6),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'REFRESH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: .5,
                        ),
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
  }
}
