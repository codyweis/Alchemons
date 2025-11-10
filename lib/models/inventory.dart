// lib/constants/inventory_items.dart
import 'package:flutter/material.dart';
import 'package:alchemons/database/alchemons_db.dart';

class InventoryItemDef {
  final String key; // storage key
  final String name;
  final String description;
  final IconData icon;
  final bool stackable;
  final Future<bool> Function(AlchemonsDatabase db)?
  onUse; // optional use behavior

  const InventoryItemDef({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    this.stackable = true,
    this.onUse,
  });
}

// Keys
class InvKeys {
  static const instantHatch = 'item.instant_hatch';
  static const harvesterStdVolcanic = 'item.harvest_std_volcanic';
  static const harvesterStdOceanic = 'item.harvest_std_oceanic';
  static const harvesterStdVerdant = 'item.harvest_std_verdant';
  static const harvesterStdEarthen = 'item.harvest_std_earthen';
  static const harvesterStdArcane = 'item.harvest_std_arcane';
  static const harvesterGuaranteed = 'item.harvest_guaranteed';
}

Map<String, InventoryItemDef> buildInventoryRegistry(AlchemonsDatabase db) => {
  InvKeys.instantHatch: InventoryItemDef(
    key: InvKeys.instantHatch,
    name: 'Instant Fusion Extractor',
    description: 'Complete one active fusion vial instantly.',
    icon: Icons.access_alarms,
  ),
  InvKeys.harvesterStdVolcanic: InventoryItemDef(
    key: InvKeys.harvesterStdVolcanic,
    name: 'Wild Harvester – Volcanic',
    description: 'Chance-based capture device.',
    icon: Icons.local_fire_department_rounded,
  ),
  InvKeys.harvesterStdOceanic: InventoryItemDef(
    key: InvKeys.harvesterStdOceanic,
    name: 'Wild Harvester – Oceanic',
    description: 'Chance-based capture device.',
    icon: Icons.water_rounded,
  ),
  InvKeys.harvesterStdVerdant: InventoryItemDef(
    key: InvKeys.harvesterStdVerdant,
    name: 'Wild Harvester – Verdant',
    description: 'Chance-based capture device.',
    icon: Icons.eco_rounded,
  ),
  InvKeys.harvesterStdEarthen: InventoryItemDef(
    key: InvKeys.harvesterStdEarthen,
    name: 'Wild Harvester – Earthen',
    description: 'Chance-based capture device.',
    icon: Icons.terrain_rounded,
  ),
  InvKeys.harvesterStdArcane: InventoryItemDef(
    key: InvKeys.harvesterStdArcane,
    name: 'Wild Harvester – Arcane',
    description: 'Chance-based capture device.',
    icon: Icons.auto_awesome_rounded,
  ),
  InvKeys.harvesterGuaranteed: InventoryItemDef(
    key: InvKeys.harvesterGuaranteed,
    name: 'Stabilized Harvester',
    description: 'Guaranteed capture device.',
    icon: Icons.shield_rounded,
  ),
};
