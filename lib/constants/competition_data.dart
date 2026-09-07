import 'package:alchemons/models/competition.dart';

class CompetitionData {
  static const Map<CompetitionBiome, List<CompetitionLevel>> levels = {
    CompetitionBiome.oceanic: [
      CompetitionLevel(
        level: 1,
        name: 'Tide Pool Trials',
        npcs: [
          NPCCompetitor(name: 'Splash', statValue: 3.4),
          NPCCompetitor(name: 'Ripple', statValue: 3.6),
          NPCCompetitor(name: 'Current', statValue: 3.8),
        ],
        rewardAmount: 50,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 2,
        name: 'Wave Runner Challenge',
        npcs: [
          NPCCompetitor(name: 'Breaker', statValue: 4.7),
          NPCCompetitor(name: 'Surge', statValue: 4.9),
          NPCCompetitor(name: 'Torrent', statValue: 5.1),
        ],
        rewardAmount: 100,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 3,
        name: 'Maelstrom Sprint',
        npcs: [
          NPCCompetitor(name: 'Typhoon', statValue: 6.0),
          NPCCompetitor(name: 'Cyclone', statValue: 6.2),
          NPCCompetitor(name: 'Tempest', statValue: 6.4),
        ],
        rewardAmount: 200,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 4,
        name: 'Deep Sea Velocity',
        npcs: [
          NPCCompetitor(name: 'Abyss', statValue: 7.2),
          NPCCompetitor(name: 'Leviathan', statValue: 7.5),
          NPCCompetitor(name: 'Kraken', statValue: 7.7),
        ],
        rewardAmount: 350,
        rewardResource: 'aqua_essence',
      ),
      CompetitionLevel(
        level: 5,
        name: 'Oceanic Champion',
        npcs: [
          NPCCompetitor(name: 'Poseidon', statValue: 8.1),
          NPCCompetitor(name: 'Neptune', statValue: 8.3),
          NPCCompetitor(name: 'Aquarius', statValue: 8.5),
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
          NPCCompetitor(name: 'Cinder', statValue: 3.4),
          NPCCompetitor(name: 'Ash', statValue: 3.6),
          NPCCompetitor(name: 'Char', statValue: 3.8),
        ],
        rewardAmount: 50,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 2,
        name: 'Lava Flow Gauntlet',
        npcs: [
          NPCCompetitor(name: 'Blaze', statValue: 4.7),
          NPCCompetitor(name: 'Scorch', statValue: 4.9),
          NPCCompetitor(name: 'Sear', statValue: 5.1),
        ],
        rewardAmount: 100,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 3,
        name: 'Inferno Crucible',
        npcs: [
          NPCCompetitor(name: 'Pyre', statValue: 6.0),
          NPCCompetitor(name: 'Furnace', statValue: 6.2),
          NPCCompetitor(name: 'Incinerator', statValue: 6.4),
        ],
        rewardAmount: 200,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 4,
        name: 'Caldera Clash',
        npcs: [
          NPCCompetitor(name: 'Volcano', statValue: 7.2),
          NPCCompetitor(name: 'Eruption', statValue: 7.5),
          NPCCompetitor(name: 'Magma', statValue: 7.7),
        ],
        rewardAmount: 350,
        rewardResource: 'magma_core',
      ),
      CompetitionLevel(
        level: 5,
        name: 'Volcanic Titan',
        npcs: [
          NPCCompetitor(name: 'Vulcan', statValue: 8.1),
          NPCCompetitor(name: 'Hephaestus', statValue: 8.3),
          NPCCompetitor(name: 'Ifrit', statValue: 8.5),
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
          NPCCompetitor(name: 'Mudmane', statValue: 3.7),
          NPCCompetitor(name: 'Dustmane', statValue: 4.1),
          NPCCompetitor(name: 'Earthwing', statValue: 4.3),
        ],
        rewardAmount: 60,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 2,
        name: 'Tunnel Tacticians',
        npcs: [
          NPCCompetitor(name: 'Shalefin', statValue: 4.8),
          NPCCompetitor(name: 'Dustseer', statValue: 5.0),
          NPCCompetitor(name: 'Gravelis', statValue: 5.3),
        ],
        rewardAmount: 120,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 3,
        name: 'Crystal Calculus',
        npcs: [
          NPCCompetitor(name: 'Quartzleaf', statValue: 5.8),
          NPCCompetitor(name: 'Silt Savant', statValue: 6.0),
          NPCCompetitor(name: 'Basaltis', statValue: 6.3),
        ],
        rewardAmount: 220,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 4,
        name: 'Catacomb Conundrum',
        npcs: [
          NPCCompetitor(name: 'Cairn', statValue: 6.9),
          NPCCompetitor(name: 'Feldspar', statValue: 7.2),
          NPCCompetitor(name: 'Dolomite', statValue: 7.5),
        ],
        rewardAmount: 360,
        rewardResource: 'terra_insight',
      ),
      CompetitionLevel(
        level: 5,
        name: 'Earthen Dean’s Trial',
        npcs: [
          NPCCompetitor(name: 'Gneissmind', statValue: 7.8),
          NPCCompetitor(name: 'Lodestone', statValue: 8.1),
          NPCCompetitor(name: 'Obsidian', statValue: 8.4),
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
