import 'package:alchemons/models/trophy_slot.dart';
import 'package:alchemons/screens/scenes/volcano_scene.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('World Map'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          _BiomeCard(
            title: 'Volcano',
            icon: Icons.volcano_rounded,
            onTap: () async {
              // Pull unlocked creatures from your game state
              final gameState = context.read<GameStateNotifier>();

              // Build slots for this scene from your data model.
              // In a real game, these would come from content files.
              final slots = _buildVolcanoSlotsFromGame(gameState);

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VolcanoScenePage(slots: slots),
                ),
              );
            },
          ),
          // Add more biomes later…
        ],
      ),
    );
  }

  List<TrophySlot> _buildVolcanoSlotsFromGame(GameStateNotifier state) {
    // Example: fixed slot positions (normalized 0..1). Map to your real creatures.
    // Pick some IDs that exist in your data (adjust to match yours).
    final discovered = state.discoveredCreatures
        .map((e) => (e['creature']).id as String)
        .toSet();

    final content =
        <
          ({
            String id,
            double x,
            double y,
            String displayName,
            String rarity,
            AnchorLayer layer,
            double? frameWidth,
            double? frameHeight,
          })
        >[
          (
            id: 'CR045',
            x: 0.20,
            y: 0.7,
            displayName: 'LightMane',
            rarity: 'Rare',
            layer: AnchorLayer.layer2,
            frameWidth: 30,
            frameHeight: 30,
          ),
          (
            id: 'CR005',
            x: 0.58,
            y: 0.8,
            displayName: 'SteamMane',
            rarity: 'UnCommon',
            layer: AnchorLayer.layer1,
            frameWidth: 100,
            frameHeight: 100,
          ),
        ];

    return content.map((c) {
      final isUnlocked = discovered.contains(c.id);
      // Build your existing asset path shape:
      final spritePath =
          'creatures/${c.rarity.toLowerCase()}/${c.id}_${c.displayName.toLowerCase()}_spritesheet.png';
      return TrophySlot(
        id: c.id,
        normalizedPos: Offset(c.x, c.y),
        isUnlocked: isUnlocked,
        spritePath: isUnlocked ? spritePath : 'ui/wood_texture.jpg',
        displayName: c.displayName,
        rarity: c.rarity,
        sheetColumns: 2,
        anchor: c.layer,
        frameHeight: c.frameHeight,
        frameWidth: c.frameWidth,
        sheetRows: 2,
      );
    }).toList();
  }
}

class _BiomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _BiomeCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: const Color(0xFF6B46C1)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
