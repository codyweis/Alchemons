import 'dart:convert';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:provider/provider.dart';

class PartyHUD extends StatelessWidget {
  final List<PartyMember> party;
  final String? selectedInstanceId;
  final Function(String instanceId, Creature creature) onSelectCreature;
  final VoidCallback? onBreed;
  final bool breedEnabled;

  const PartyHUD({
    super.key,
    required this.party,
    required this.selectedInstanceId,
    required this.onSelectCreature,
    this.onBreed,
    this.breedEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AlchemonsDatabase>();
    final repo = context.watch<CreatureCatalog>();

    return SafeArea(
      child: Column(
        children: [
          // Party member selector
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.purple.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Party:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                ...party.map(
                  (member) => _PartySlot(
                    member: member,
                    db: db,
                    repo: repo,
                    isSelected: selectedInstanceId == member.instanceId,
                    onTap: onSelectCreature,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Breed button (shown when creature selected)
          if (breedEnabled && selectedInstanceId != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: onBreed,
                icon: const Icon(Icons.favorite, size: 24),
                label: const Text(
                  'BREED',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFFE91E63).withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PartySlot extends StatelessWidget {
  final PartyMember member;
  final AlchemonsDatabase db;
  final CreatureCatalog repo;
  final bool isSelected;
  final Function(String instanceId, Creature creature) onTap;

  const _PartySlot({
    required this.member,
    required this.db,
    required this.repo,
    required this.isSelected,
    required this.onTap,
  });

  Map<String, String> _geneticsFromJson(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CreatureInstance?>(
      future: db.creatureDao.getInstance(member.instanceId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        }

        final inst = snap.data!;
        final base = repo.getCreatureById(inst.baseId);
        final displayName = base?.name ?? inst.baseId;
        final geneticsMap = _geneticsFromJson(inst.geneticsJson);

        // Build a full Creature object for the callback
        // Uses base creature data + instance-specific customizations
        final creature =
            base?.copyWith(
              genetics: geneticsMap.isNotEmpty
                  ? Genetics(geneticsMap)
                  : base.genetics,
              // Note: natureId in instance is just a string ID, not the full NatureDef
              // The base creature already has the correct nature definition
              isPrismaticSkin: inst.isPrismaticSkin,
            ) ??
            Creature(
              // Fallback if base not found (shouldn't happen)
              id: inst.baseId,
              name: displayName,
              types: const ['Unknown'],
              rarity: 'Common',
              description: 'Creature data unavailable',
              image: 'creatures/placeholder.png',
            );

        return GestureDetector(
          onTap: () => onTap(member.instanceId, creature),
          child: Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.purple.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.white30,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Creature thumbnail/silhouette
                Center(
                  child: base?.spriteData != null
                      ? _CreatureThumbnail(
                          types: base!.types,
                          name: displayName,
                        )
                      : Icon(
                          Icons.pets,
                          color: Colors.white.withOpacity(0.7),
                          size: 32,
                        ),
                ),

                // Level badge
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'L${inst.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Stamina indicator
                if (inst.staminaBars < inst.staminaMax)
                  Positioned(
                    top: 2,
                    left: 2,
                    right: 2,
                    child: LinearProgressIndicator(
                      value: inst.staminaBars / inst.staminaMax,
                      backgroundColor: Colors.red.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation(Colors.green),
                      minHeight: 3,
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

// Simple thumbnail renderer
class _CreatureThumbnail extends StatelessWidget {
  final List<String> types;
  final String name;

  const _CreatureThumbnail({required this.types, required this.name});

  @override
  Widget build(BuildContext context) {
    // For now, just show a colored circle based on type
    // In a full implementation, you'd render the actual sprite
    final color = types.isNotEmpty
        ? BreedConstants.getTypeColor(types.first)
        : Colors.grey;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
