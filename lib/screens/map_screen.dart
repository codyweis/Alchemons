// lib/screens/map_screen.dart
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/trophy_slot.dart';
import 'package:alchemons/screens/scenes/scene_page.dart';
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
            title: 'Valley',
            icon: Icons.sunny,
            onTap: () {
              final gameState = context.read<GameStateNotifier>();
              final scene = _deriveSceneWithUnlocks(
                base: valleyScene,
                unlockedIds: gameState.discoveredCreatures
                    .map((e) => (e['creature']).id as String)
                    .toSet(),
                lockedPlaceholder: 'ui/wood_texture.jpg',
              );

              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ScenePage(scene: scene)),
              );
            },
          ),
        ],
      ),
    );
  }

  SceneDefinition _deriveSceneWithUnlocks({
    required SceneDefinition base,
    required Set<String> unlockedIds,
    required String lockedPlaceholder,
  }) {
    final updatedSlots = base.slots.map((s) {
      final unlocked = unlockedIds.contains(s.id);
      return s.copyWith(
        isUnlocked: unlocked,
        spritePath: unlocked ? s.spritePath : lockedPlaceholder,
      );
    }).toList();

    return base.copyWith(slots: updatedSlots);
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
