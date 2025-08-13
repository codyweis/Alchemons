import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:alchemons/models/trophy_slot.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/games/scene_game.dart';
import 'package:flutter/services.dart';

class ScenePage extends StatefulWidget {
  final SceneDefinition scene;

  const ScenePage({super.key, required this.scene});

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> {
  late SceneGame _game;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Create the generic SceneGame with the provided scene definition
    _game = SceneGame(scene: widget.scene);

    // Hook up the slot details overlay
    _game.onShowDetails = (slot) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _CreatureSheet(slot: slot),
      );
    };
    print("leaving initState in scene page");
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FloatingActionButton.small(
                  heroTag: 'back',
                  backgroundColor: const Color(0xFF6B46C1),
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatureSheet extends StatelessWidget {
  final TrophySlot slot;
  const _CreatureSheet({required this.slot});

  @override
  Widget build(BuildContext context) {
    final locked = !slot.isUnlocked;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(colors: [Colors.white, Colors.purple.shade50]),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            locked ? 'Unknown Trophy' : slot.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B46C1),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/${slot.imagePath}',
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locked
                ? 'Find and unlock this creature!'
                : 'Rarity: ${slot.rarity}',
            style: TextStyle(color: Colors.purple.shade700),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
