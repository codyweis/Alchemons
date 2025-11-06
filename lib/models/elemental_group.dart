// lib/models/elemental_group.dart
import 'package:alchemons/models/creature.dart';
import 'package:flutter/material.dart';

enum ElementalGroup { volcanic, oceanic, earthen, verdant, arcane }

enum Elements {
  fire,
  water,
  earth,
  air,
  steam,
  lava,
  lightning,
  mud,
  ice,
  dust,
  crystal,
  plant,
  poison,
  spirit,
  dark,
  light,
  blood,
}

extension ElementalGroupX on ElementalGroup {
  String get displayName => switch (this) {
    ElementalGroup.volcanic => 'Volcanic',
    ElementalGroup.oceanic => 'Oceanic',
    ElementalGroup.earthen => 'Earthen',
    ElementalGroup.verdant => 'Verdant',
    ElementalGroup.arcane => 'Arcane',
  };

  String get description => switch (this) {
    ElementalGroup.volcanic =>
      'Creatures born of fire, lava, and storm — fierce and relentless.',
    ElementalGroup.oceanic =>
      'Masters of water, ice, and steam — fluid, adaptable, and serene.',
    ElementalGroup.earthen =>
      'Grounded in earth, crystal, and stone — sturdy and enduring.',
    ElementalGroup.verdant =>
      'Nature’s whisper — air, plant, and toxin intertwined.',
    ElementalGroup.arcane =>
      'Weavers of spirit, light, and shadow — mysterious and powerful.',
  };

  List<String> get elementTypes => switch (this) {
    ElementalGroup.volcanic => ['Fire', 'Lava', 'Lightning'],
    ElementalGroup.oceanic => ['Water', 'Ice', 'Steam'],
    ElementalGroup.earthen => ['Earth', 'Mud', 'Dust', 'Crystal'],
    ElementalGroup.verdant => ['Air', 'Plant', 'Poison'],
    ElementalGroup.arcane => ['Spirit', 'Light', 'Dark', 'Blood'],
  };

  Color get color => switch (this) {
    ElementalGroup.volcanic => const Color(0xFFEF5350),
    ElementalGroup.oceanic => const Color(0xFF42A5F5),
    ElementalGroup.earthen => const Color(0xFF8D6E63),
    ElementalGroup.verdant => const Color(0xFF66BB6A),
    ElementalGroup.arcane => const Color(0xFFAB47BC),
  };

  String get iconPath => 'assets/icons/groups/${name.toLowerCase()}.png';
}

/// map group → stable id string
String groupIdFrom(ElementalGroup g) => switch (g) {
  ElementalGroup.volcanic => 'volcanic',
  ElementalGroup.oceanic => 'oceanic',
  ElementalGroup.earthen => 'earthen',
  ElementalGroup.verdant => 'verdant',
  ElementalGroup.arcane => 'arcane',
};

/// membership helpers
bool creatureInGroup(Creature c, ElementalGroup group) {
  final lowered = group.elementTypes.map((e) => e.toLowerCase()).toSet();
  return c.types.any((t) => lowered.contains(t.toLowerCase()));
}

ElementalGroup? elementalGroupOf(Creature c) {
  if (c.types.isEmpty) return null;
  final primaryType = c.types.first.toLowerCase();
  for (final group in ElementalGroup.values) {
    for (final type in group.elementTypes) {
      if (type.toLowerCase() == primaryType) return group;
    }
  }
  return null;
}

String elementalGroupNameOf(Creature c) =>
    elementalGroupOf(c)?.displayName ?? 'Unknown';

/// ─────────────────────────────────────────────────────────
/// Families
/// ─────────────────────────────────────────────────────────
enum CreatureFamily { let, horn, kin, mane, mask, pip, wing, mystic }

extension CreatureFamilyX on CreatureFamily {
  String get displayName => switch (this) {
    CreatureFamily.let => 'Let',
    CreatureFamily.horn => 'Horn',
    CreatureFamily.kin => 'Kin',
    CreatureFamily.mane => 'Mane',
    CreatureFamily.mask => 'Mask',
    CreatureFamily.pip => 'Pip',
    CreatureFamily.wing => 'Wing',
    CreatureFamily.mystic => 'Mystic',
  };

  String get code => switch (this) {
    CreatureFamily.let => 'LET',
    CreatureFamily.horn => 'HOR',
    CreatureFamily.kin => 'KIN',
    CreatureFamily.mane => 'MAN',
    CreatureFamily.mask => 'MSK',
    CreatureFamily.pip => 'PIP',
    CreatureFamily.wing => 'WNG',
    CreatureFamily.mystic => 'MYS',
  };

  Color get color => switch (this) {
    CreatureFamily.pip => const Color(0xFFFFCA28),
    CreatureFamily.let => const Color(0xFF29B6F6),
    CreatureFamily.wing => const Color(0xFFA5D6A7),
    CreatureFamily.horn => const Color(0xFF8D6E63),
    CreatureFamily.kin => const Color(0xFFBA68C8),
    CreatureFamily.mane => const Color(0xFFFFA726),
    CreatureFamily.mask => const Color(0xFF90A4AE),
    CreatureFamily.mystic => const Color(0xFF7E57C2),
  };

  String get iconPath =>
      'assets/icons/families/${displayName.toLowerCase()}.png';
}

String familyOf(Creature c) => c.mutationFamily?.trim().isNotEmpty == true
    ? c.mutationFamily!.trim()
    : 'Unknown';

// Add at the end of lib/models/elemental_group.dart

/// UI-specific skin configuration for elemental groups
class ElementalGroupSkin {
  final Color frameStart;
  final Color frameEnd;
  final Color fill;
  final Color badge;

  const ElementalGroupSkin({
    required this.frameStart,
    required this.frameEnd,
    required this.fill,
    required this.badge,
  });
}

/// UI extensions for ElementalGroup
extension ElementalGroupUiExtension on ElementalGroup {
  /// Visual skin/theme for UI cards
  ElementalGroupSkin get skin {
    switch (this) {
      case ElementalGroup.volcanic:
        return const ElementalGroupSkin(
          frameStart: Color(0xFF3A0A0A),
          frameEnd: Color(0xFF9A3412),
          fill: Color(0x33FB923C),
          badge: Color(0xFFF97316),
        );
      case ElementalGroup.oceanic:
        return const ElementalGroupSkin(
          frameStart: Color(0xFF0C4A6E),
          frameEnd: Color(0xFF0891B2),
          fill: Color(0x3320B8E6),
          badge: Color(0xFF38BDF8),
        );
      case ElementalGroup.earthen:
        return const ElementalGroupSkin(
          frameStart: Color(0xFF3B2F2F),
          frameEnd: Color(0xFF8B5E34),
          fill: Color(0x33C1A37A),
          badge: Color(0xFFB45309),
        );
      case ElementalGroup.verdant:
        return const ElementalGroupSkin(
          frameStart: Color(0xFF14532D),
          frameEnd: Color(0xFF16A34A),
          fill: Color(0x3346E29D),
          badge: Color(0xFF22C55E),
        );
      case ElementalGroup.arcane:
        return const ElementalGroupSkin(
          frameStart: Color(0xFF312E81),
          frameEnd: Color(0xFF6D28D9),
          fill: Color(0x33C4B5FD),
          badge: Color(0xFFA78BFA),
        );
    }
  }

  /// Map to two elemental type IDs for particle system
  (String, String?) get particleTypes {
    switch (this) {
      case ElementalGroup.volcanic:
        return ('lava', 'fire');
      case ElementalGroup.oceanic:
        return ('water', 'ice');
      case ElementalGroup.earthen:
        return ('earth', 'crystal');
      case ElementalGroup.verdant:
        return ('plant', 'poison');
      case ElementalGroup.arcane:
        return ('light', 'spirit');
    }
  }
}

/// Helper to parse ElementalGroup from various string sources
ElementalGroup elementalGroupFromString(String value) {
  final normalized = value.toLowerCase();

  if (normalized.contains('volcanic') || normalized.contains('fire')) {
    return ElementalGroup.volcanic;
  } else if (normalized.contains('oceanic') || normalized.contains('water')) {
    return ElementalGroup.oceanic;
  } else if (normalized.contains('earthen') || normalized.contains('earth')) {
    return ElementalGroup.earthen;
  } else if (normalized.contains('verdant') ||
      normalized.contains('air') ||
      normalized.contains('plant')) {
    return ElementalGroup.verdant;
  } else if (normalized.contains('arcane') || normalized.contains('spirit')) {
    return ElementalGroup.arcane;
  }

  return ElementalGroup.volcanic; // Default
}

/// Map element type string to ElementalGroup
ElementalGroup elementalGroupFromElementType(String elementType) {
  final type = elementType.toLowerCase();

  // Volcanic group
  if (['fire', 'lava', 'lightning'].contains(type)) {
    return ElementalGroup.volcanic;
  }

  // Oceanic group
  if (['water', 'ice', 'steam'].contains(type)) {
    return ElementalGroup.oceanic;
  }

  // Earthen group
  if (['earth', 'mud', 'dust', 'crystal'].contains(type)) {
    return ElementalGroup.earthen;
  }

  // Verdant group
  if (['air', 'plant', 'poison'].contains(type)) {
    return ElementalGroup.verdant;
  }

  // Arcane group
  if (['spirit', 'light', 'dark', 'blood'].contains(type)) {
    return ElementalGroup.arcane;
  }

  return ElementalGroup.volcanic; // Default
}
