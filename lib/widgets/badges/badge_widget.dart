// lib/widgets/badges.dart
import 'package:flutter/material.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/constants/breed_constants.dart';

class TypeBadges extends StatelessWidget {
  final List<String> types;
  const TypeBadges({super.key, required this.types});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: types.map((type) {
        final c = CreatureFilterUtils.getTypeColor(type);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withOpacity(0.5)),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class RarityBadge extends StatelessWidget {
  final String rarity;
  const RarityBadge({super.key, required this.rarity});

  @override
  Widget build(BuildContext context) {
    final c = BreedConstants.getRarityColor(rarity.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border_outlined, color: c, size: 12),
          const SizedBox(width: 4),
          Text(
            rarity,
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}
