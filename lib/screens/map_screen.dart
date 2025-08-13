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
        <({String id, double x, double y, String displayName, String rarity})>[
          (
            id: 'CR045',
            x: 0.20,
            y: 0.65,
            displayName: 'LightMane',
            rarity: 'Rare',
          ),
          (
            id: 'CR008',
            x: 0.58,
            y: 0.55,
            displayName: 'CrystalMane',
            rarity: 'Rare',
          ),
        ];

    return content.map((c) {
      final isUnlocked = discovered.contains(c.id);
      // Build your existing asset path shape:
      final spritePath =
          'creatures/${c.rarity.toLowerCase()}/${c.id}_${c.displayName.toLowerCase()}.png';
      return TrophySlot(
        id: c.id,
        normalizedPos: Offset(c.x, c.y),
        isUnlocked: isUnlocked,
        spritePath: isUnlocked ? spritePath : 'ui/wood_texture.jpg',
        displayName: c.displayName,
        rarity: c.rarity,
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
