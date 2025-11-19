// lib/models/faction.dart
enum FactionId { volcanic, oceanic, verdant, earthen }

class FactionPerk {
  final String code; // e.g. 'HellRaiser'
  final String title;
  final String description;
  const FactionPerk(this.code, this.title, this.description);
}

class FactionDef {
  final FactionId id;
  final String name;
  final String emoji; // quick icon for UI
  final List<FactionPerk> perks;
  const FactionDef(this.id, this.name, this.emoji, this.perks);
}

class Factions {
  static const volcanic = FactionDef(FactionId.volcanic, 'Volcanic', '🔥', [
    FactionPerk(
      'FireBreeder',
      'Fire Breeder',
      '50% chance to get half off extraction timers when using two fire specimens',
    ),
    FactionPerk(
      'VolcanicHarvester',
      'Volcanic Harvester',
      'Extreme discounts on volcanic harvesting devices',
    ),
  ]);

  static const oceanic = FactionDef(FactionId.oceanic, 'Oceanic', '🌊', [
    FactionPerk(
      'WaterBreeder',
      'Water Breeder',
      '50% chance Water specimens don\'t lose stamina when breeding together',
    ),
    FactionPerk(
      'OceanicHarvester',
      'Oceanic Harvester',
      'Extreme discounts on oceanic harvesting devices',
    ),
  ]);

  static const verdant = FactionDef(FactionId.verdant, 'Verdant', '💨', [
    FactionPerk('AirDrop', 'AirDrop', 'Unlock an extra extraction chamber'),
    FactionPerk(
      'VerdantHarvester',
      'Verdant Harvester',
      'Extreme discounts on verdant harvesting devices',
    ),
  ]);

  static const earthen = FactionDef(FactionId.earthen, 'Earthen', '🌍', [
    FactionPerk(
      'EarthenSale',
      'Earthen Sale',
      '50% increase in value to earthen specimens sold',
    ),
    FactionPerk(
      'EarthenHarvester',
      'Earthen Harvester',
      'Extreme discounts on earthen harvesting devices',
    ),
  ]);

  static const all = [volcanic, oceanic, verdant, earthen];

  static FactionDef byId(FactionId id) => all.firstWhere((f) => f.id == id);
}
