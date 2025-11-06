import 'package:alchemons/models/competition.dart';

class CompetitionData {
  static const Map<CompetitionBiome, List<CompetitionLevel>> levels = {
    CompetitionBiome.oceanic: [
      CompetitionLevel(
        level: 1,
        name: 'Tide Pool Trials',
        npcs: [
          NPCCompetitor(name: 'Splash', statValue: 4.0),
          NPCCompetitor(name: 'Ripple', statValue: 4.2),
          NPCCompetitor(name: 'Current', statValue: 4.5),
        ],
        rewardAmount: 50,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 2,
        name: 'Wave Runner Challenge',
        npcs: [
          NPCCompetitor(name: 'Breaker', statValue: 5.5),
          NPCCompetitor(name: 'Surge', statValue: 5.8),
          NPCCompetitor(name: 'Torrent', statValue: 6.0),
        ],
        rewardAmount: 100,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 3,
        name: 'Maelstrom Sprint',
        npcs: [
          NPCCompetitor(name: 'Typhoon', statValue: 7.0),
          NPCCompetitor(name: 'Cyclone', statValue: 7.3),
          NPCCompetitor(name: 'Tempest', statValue: 7.5),
        ],
        rewardAmount: 200,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 4,
        name: 'Deep Sea Velocity',
        npcs: [
          NPCCompetitor(name: 'Abyss', statValue: 8.5),
          NPCCompetitor(name: 'Leviathan', statValue: 8.8),
          NPCCompetitor(name: 'Kraken', statValue: 9.0),
        ],
        rewardAmount: 350,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 5,
        name: 'Oceanic Champion',
        npcs: [
          NPCCompetitor(name: 'Poseidon', statValue: 9.5),
          NPCCompetitor(name: 'Neptune', statValue: 9.7),
          NPCCompetitor(name: 'Aquarius', statValue: 10.0),
        ],
        rewardAmount: 500,
        rewardResource: 'aqua_essence',
      ),
    ],
    CompetitionBiome.volcanic: [
      CompetitionLevel(
        level: 1,
        name: 'Ember Pit Brawl',
        npcs: [
          NPCCompetitor(name: 'Cinder', statValue: 4.0),
          NPCCompetitor(name: 'Ash', statValue: 4.2),
          NPCCompetitor(name: 'Char', statValue: 4.5),
        ],
        rewardAmount: 50,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 2,
        name: 'Lava Flow Gauntlet',
        npcs: [
          NPCCompetitor(name: 'Blaze', statValue: 5.5),
          NPCCompetitor(name: 'Scorch', statValue: 5.8),
          NPCCompetitor(name: 'Sear', statValue: 6.0),
        ],
        rewardAmount: 100,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 3,
        name: 'Inferno Crucible',
        npcs: [
          NPCCompetitor(name: 'Pyre', statValue: 7.0),
          NPCCompetitor(name: 'Furnace', statValue: 7.3),
          NPCCompetitor(name: 'Incinerator', statValue: 7.5),
        ],
        rewardAmount: 200,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 4,
        name: 'Caldera Clash',
        npcs: [
          NPCCompetitor(name: 'Volcano', statValue: 8.5),
          NPCCompetitor(name: 'Eruption', statValue: 8.8),
          NPCCompetitor(name: 'Magma', statValue: 9.0),
        ],
        rewardAmount: 350,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 5,
        name: 'Volcanic Titan',
        npcs: [
          NPCCompetitor(name: 'Vulcan', statValue: 9.5),
          NPCCompetitor(name: 'Hephaestus', statValue: 9.7),
          NPCCompetitor(name: 'Ifrit', statValue: 10.0),
        ],
        rewardAmount: 500,
        rewardResource: 'magma_core',
      ),
    ],
    CompetitionBiome.earthen: [
      CompetitionLevel(
        level: 1,
        name: 'Burrowed Beginnings',
        npcs: [
          NPCCompetitor(name: 'Mudmane', statValue: 4.4),
          NPCCompetitor(name: 'Dustmane', statValue: 4.8),
          NPCCompetitor(name: 'Earthwing', statValue: 5.0),
        ],
        rewardAmount: 60,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 2,
        name: 'Tunnel Tacticians',
        npcs: [
          NPCCompetitor(name: 'Shalefin', statValue: 5.6),
          NPCCompetitor(name: 'Dustseer', statValue: 5.9),
          NPCCompetitor(name: 'Gravelis', statValue: 6.2),
        ],
        rewardAmount: 120,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 3,
        name: 'Crystal Calculus',
        npcs: [
          NPCCompetitor(name: 'Quartzleaf', statValue: 6.8),
          NPCCompetitor(name: 'Silt Savant', statValue: 7.1),
          NPCCompetitor(name: 'Basaltis', statValue: 7.4),
        ],
        rewardAmount: 220,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 4,
        name: 'Catacomb Conundrum',
        npcs: [
          NPCCompetitor(name: 'Cairn', statValue: 8.1),
          NPCCompetitor(name: 'Feldspar', statValue: 8.5),
          NPCCompetitor(name: 'Dolomite', statValue: 8.8),
        ],
        rewardAmount: 360,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 5,
        name: 'Earthen Dean’s Trial',
        npcs: [
          NPCCompetitor(name: 'Gneissmind', statValue: 9.2),
          NPCCompetitor(name: 'Lodestone', statValue: 9.5),
          NPCCompetitor(name: 'Obsidian', statValue: 9.9),
        ],
        rewardAmount: 540,
        rewardResource: 'terra_insight',
      ),
    ],
    // Add similar for earthen, verdant, and celestial...
  };

  static List<CompetitionLevel> getLevels(CompetitionBiome biome) {
    return levels[biome] ?? [];
  }

  static CompetitionLevel? getLevel(CompetitionBiome biome, int level) {
    final list = levels[biome] ?? [];
    return list.firstWhere((l) => l.level == level, orElse: () => list.first);
  }
}
