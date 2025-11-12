import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreatureImage extends StatelessWidget {
  final Creature c;
  final bool discovered;
  final double rounded;
  final double? size;
  const CreatureImage({
    super.key,
    required this.c,
    required this.discovered,
    this.rounded = 10,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    if (!discovered) {
      return Icon(Icons.help_outline_rounded, color: theme.textMuted, size: 24);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(rounded),
      child: Image.asset(
        width: size,
        height: size,
        'assets/images/creatures/${c.rarity.toLowerCase()}/${c.id.toUpperCase()}_${c.name.toLowerCase()}.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            color: BreedConstants.getTypeColor(c.types.first).withOpacity(.12),
            borderRadius: BorderRadius.circular(rounded),
          ),
          child: Icon(
            BreedConstants.getTypeIcon(c.types.first),
            color: BreedConstants.getTypeColor(c.types.first),
          ),
        ),
      ),
    );
  }
}
