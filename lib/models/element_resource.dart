// models/element_resource.dart
import 'package:flutter/material.dart';

enum ElementId { fire, water, air, earth }

extension ElementIdX on ElementId {
  String get dbKey => switch (this) {
    ElementId.fire => 'res_embers',
    ElementId.water => 'res_droplets',
    ElementId.air => 'res_breeze',
    ElementId.earth => 'res_shards',
  };

  String get label => switch (this) {
    ElementId.fire => 'Fire',
    ElementId.water => 'Water',
    ElementId.air => 'Air',
    ElementId.earth => 'Earth',
  };

  String get unitName => switch (this) {
    ElementId.fire => 'Embers',
    ElementId.water => 'Droplets',
    ElementId.air => 'Breeze',
    ElementId.earth => 'Shards',
  };

  IconData get icon => switch (this) {
    ElementId.fire => Icons.local_fire_department_outlined,
    ElementId.water => Icons.water_drop_outlined,
    ElementId.air => Icons.air,
    ElementId.earth => Icons.terrain,
  };

  Color get color => switch (this) {
    ElementId.fire => const Color(0xFFFFA726),
    ElementId.water => const Color(0xFF29B6F6),
    ElementId.air => const Color(0xFF26C6DA),
    ElementId.earth => const Color(0xFF8D6E63),
  };
}

class ElementResource {
  final ElementId id;
  final int amount;

  const ElementResource({required this.id, required this.amount});

  String get resourceName => id.label; // e.g., "Fire"
  String get name => id.unitName; // e.g., "Embers"
  IconData get icon => id.icon;
  Color get color => id.color;

  factory ElementResource.fromDbMap(Map<String, int> db, ElementId id) {
    return ElementResource(id: id, amount: db[id.dbKey] ?? 0);
  }
}
