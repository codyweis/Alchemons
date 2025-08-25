// lib/models/faction.dart
enum FactionId { fire, water, air, earth }

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
  static const fire = FactionDef(FactionId.fire, 'Fire', '🔥', [
    FactionPerk(
      'HellRaiser',
      'HellRaiser',
      '5% increased XP to all creatures when leveling',
    ),
    FactionPerk(
      'FireBreeder',
      'FireBreeder',
      '50% off breed timers created when using a fire parent',
    ),
  ]);

  static const water = FactionDef(FactionId.water, 'Water', '🌊', [
    FactionPerk(
      'WaterBreeder',
      'WaterBreeder',
      'Water creatures don’t lose stamina when breeding together',
    ),
    FactionPerk(
      'AquaSanctuary',
      'Aqua Sanctuary',
      'After each expedition, Water creatures return fully rested',
    ),
  ]);

  static const air = FactionDef(FactionId.air, 'Air', '💨', [
    FactionPerk('AirDrop', 'AirDrop', 'Unlock an extra breeding slot'),
    FactionPerk(
      'AirSensory',
      'Air Sensory',
      'Predict if an egg is undiscovered',
    ),
  ]);

  static const earth = FactionDef(FactionId.earth, 'Earth', '🌍', [
    FactionPerk(
      'LandExplorer',
      'LandExplorer',
      'Refresh 1 wildlife encounter instantly once per day',
    ),
    FactionPerk(
      'Earther',
      'Earther',
      '25% increase success rate in wilderness',
    ),
  ]);

  static const all = [fire, water, air, earth];

  static FactionDef byId(FactionId id) => all.firstWhere((f) => f.id == id);
}
