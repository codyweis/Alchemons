// models/element_resource.dart
import 'package:flutter/material.dart';

enum ElementId { volcanic, oceanic, earthen, verdant, arcane }

extension ElementIdX on ElementId {
  // key stored in Settings table / DB for this currency
  String get dbKey => switch (this) {
    ElementId.volcanic => 'res_volcanic',
    ElementId.oceanic => 'res_oceanic',
    ElementId.earthen => 'res_earthen',
    ElementId.verdant => 'res_verdant',
    ElementId.arcane => 'res_arcane',
  };

  // high-level category name shown in UI headers / chips
  String get label => switch (this) {
    ElementId.volcanic => 'Volcanic',
    ElementId.oceanic => 'Oceanic',
    ElementId.earthen => 'Earthen',
    ElementId.verdant => 'Verdant',
    ElementId.arcane => 'Arcane',
  };

  // "unit" name under that biome. You can keep these 1:1 with label
  // or give them flair like "Volcanic Essence", etc.
  // For now, keep same for clarity.
  String get unitName => switch (this) {
    ElementId.volcanic => 'Volcanic',
    ElementId.oceanic => 'Oceanic',
    ElementId.earthen => 'Earthen',
    ElementId.verdant => 'Verdant',
    ElementId.arcane => 'Arcane',
  };

  AssetImage get imageProvider => switch (this) {
    ElementId.volcanic => const AssetImage('assets/images/ui/volcanic.png'),
    ElementId.oceanic => const AssetImage('assets/images/ui/oceanic.png'),
    ElementId.earthen => const AssetImage('assets/images/ui/earthen.png'),
    ElementId.verdant => const AssetImage('assets/images/ui/verdant.png'),
    ElementId.arcane => const AssetImage('assets/images/ui/arcane.png'),
  };

  Color get color => switch (this) {
    ElementId.volcanic => const Color(0xFFFF6B35),
    ElementId.oceanic => const Color(0xFF4ECDC4),
    ElementId.earthen => const Color(0xFF8B6F47),
    ElementId.verdant => const Color(0xFF6BCF7F),
    ElementId.arcane => const Color(0xFFB388FF),
  };
}

class ElementResource {
  final ElementId id;
  final int amount;

  const ElementResource({required this.id, required this.amount});

  // For ResourceCollectionWidget pills:
  // Top line (big bold all-caps)
  String get resourceName => id.label; // "Volcanic"

  // Smaller subtitle line under it
  String get name => id
      .unitName; // "Volcanic" (or "Volcanic Essence" later if you want flavor)

  ImageProvider get icon => id.imageProvider;
  Color get color => id.color;

  factory ElementResource.fromDbMap(Map<String, int> db, ElementId id) {
    return ElementResource(id: id, amount: db[id.dbKey] ?? 0);
  }
}
