import 'dart:ui';
import 'package:alchemons/games/volcano/volcano_game.dart';
import 'package:alchemons/models/trophy_slot.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class VolcanoScenePage extends StatefulWidget {
  final List<TrophySlot> slots;
  const VolcanoScenePage({super.key, required this.slots});

  @override
  State<VolcanoScenePage> createState() => _VolcanoScenePageState();
}

class _VolcanoScenePageState extends State<VolcanoScenePage> {
  late VolcanoGame _game;

  @override
  void initState() {
    super.initState();
    _game = VolcanoGame(slots: widget.slots);

    // Hook: when Flame asks to show details, use an overlay
    _game.onShowDetails = (slot) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _CreatureSheet(slot: slot),
      );
    };
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
              'assets/images/${slot.spritePath}',
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
