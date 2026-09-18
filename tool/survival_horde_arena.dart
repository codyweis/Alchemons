// Device profiling entry point for large Survival hordes. Not shipped.
// flutter run --profile -t tool/survival_horde_arena.dart -d <device>
import 'dart:math';
import 'dart:ui';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: HordeArena()),
);

/// (baseId, name, family, element). Five-member parties cover all eight
/// families between them, including a Mystic world in each.
const kHordeArenaParties = <String, List<(String, String, String, String)>>{
  'Solo mane': [('MAN06', 'Lavamane', 'Mane', 'Lava')],
  'Party A': [
    ('MAN06', 'Lavamane', 'Mane', 'Lava'),
    ('KIN12', 'Plantkin', 'Kin', 'Plant'),
    ('MYS15', 'Noctryos', 'Mystic', 'Dark'),
    ('WNG15', 'Darkwing', 'Wing', 'Dark'),
    ('MSK13', 'Poisonmask', 'Mask', 'Poison'),
  ],
  'Party B': [
    ('PIP07', 'Lightningpip', 'Pip', 'Lightning'),
    ('LET03', 'Earthlet', 'Let', 'Earth'),
    ('HOR01', 'Firehorn', 'Horn', 'Fire'),
    ('KIN14', 'Spiritkin', 'Kin', 'Spirit'),
    ('MYS06', 'Magmara', 'Mystic', 'Lava'),
  ],
};

class HordeArena extends StatefulWidget {
  const HordeArena({super.key});
  @override
  State<HordeArena> createState() => _HordeArenaState();
}

class _HordeArenaState extends State<HordeArena> {
  late HordeArenaGame game;
  final List<double> raster = [];
  final List<double> buildTimes = [];
  String partyName = 'Solo mane';
  int population = 1000;
  bool mixed = false;
  bool sustain = true;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    game = _makeGame();
    SchedulerBinding.instance.addTimingsCallback(_timings);
  }

  HordeArenaGame _makeGame() => HordeArenaGame(
    party: kHordeArenaParties[partyName]!,
    population: population,
    mixed: mixed,
    sustain: sustain,
  );

  void _clearTimings() {
    raster.clear();
    buildTimes.clear();
    game.updateTimes.clear();
  }

  void _timings(List<FrameTiming> values) {
    for (final f in values) {
      raster.add(f.rasterDuration.inMicroseconds / 1000);
      buildTimes.add(f.buildDuration.inMicroseconds / 1000);
    }
    if (raster.length > 120) raster.removeRange(0, raster.length - 120);
    if (buildTimes.length > 120) {
      buildTimes.removeRange(0, buildTimes.length - 120);
    }
    if (mounted) setState(() {});
  }

  double p95(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.of(values)..sort();
    return sorted[((sorted.length - 1) * 0.95).ceil()];
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }

  Widget _chip(String label, VoidCallback onTap, {bool on = false}) =>
      FilledButton.tonal(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: on ? const Color(0xFFE0B25A) : null,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080D19),
    body: SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF192334),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HORDE ARENA  $partyName  '
                    'companions ${game.activeCompanions.length}',
                  ),
                  Text(
                    'Alive ${game.aliveCount}  Kills ${game.stats.kills}  '
                    'proj ${game.companionProjectiles.length}  '
                    // ignore: invalid_use_of_visible_for_testing_member
                    'vfx ${game.vfxParticleCount}',
                  ),
                  Text(
                    'Update p95 ${p95(game.updateTimes).toStringAsFixed(1)} ms  '
                    'Build p95 ${p95(buildTimes).toStringAsFixed(1)} ms  '
                    'Raster p95 ${p95(raster).toStringAsFixed(1)} ms',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 2,
                    children: [
                      for (final n in [500, 1000, 2000, 3000])
                        _chip('$n', () {
                          population = n;
                          game.seed(n, mixed: mixed);
                          _clearTimings();
                        }, on: population == n),
                      _chip(mixed ? 'Mixed' : 'Slow', () {
                        mixed = !mixed;
                        game.seed(population, mixed: mixed);
                        _clearTimings();
                      }, on: mixed),
                      _chip('Sustain', () {
                        sustain = !sustain;
                        game.sustain = sustain;
                        _clearTimings();
                      }, on: sustain),
                      _chip('Kill half', game.massKill),
                      _chip('All specials', game.forceSpecials),
                    ],
                  ),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final name in kHordeArenaParties.keys)
                        _chip(name, () {
                          setState(() {
                            partyName = name;
                            generation++;
                            game = _makeGame();
                            _clearTimings();
                          });
                        }, on: partyName == name),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GameWidget(key: ValueKey(generation), game: game),
          ),
        ],
      ),
    ),
  );
}

class HordeArenaGame extends CosmicSurvivalGame {
  final List<double> updateTimes = [];
  int population;
  bool mixed;
  bool sustain;
  int _seedIndex = 0;
  final Random _rng = Random(314);

  HordeArenaGame({
    required List<(String, String, String, String)> party,
    required this.population,
    required this.mixed,
    required this.sustain,
  }) : super(
         random: Random(771),
         onGameOver: () {},
         party: [
           for (var i = 0; i < party.length; i++)
             CosmicPartyMember(
               instanceId: 'horde_$i',
               baseId: party[i].$1,
               displayName: party[i].$2,
               family: party[i].$3,
               element: party[i].$4,
               level: 10,
               slotIndex: i,
               statSpeed: 4,
               statIntelligence: 4,
               statStrength: 4,
               statBeauty: 4,
               staminaBars: 3,
               staminaMax: 3,
             ),
         ],
       );

  /// Counted once per update: the HUD and sustain both read it, and a
  /// per-read scan of 2,000 bodies showed up as ~10% of the profile.
  int aliveCount = 0;

  void _countAlive() {
    var n = 0;
    for (final e in enemies) {
      if (!e.isDead) n++;
    }
    aliveCount = n;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    startGame();
    final packLeader = kRarePerks.firstWhere((d) => d.id == 'pack_leader');
    for (var i = 1; i < party.length; i++) {
      powerUps.apply(packLeader);
    }
    for (final m in party) {
      summonCompanion(m.slotIndex);
    }
    seed(population, mixed: mixed);
  }

  CosmicSurvivalEnemy _body(int i, int count, {required bool rim}) {
    final a = i * 2.399963;
    final reach = max(size.x, size.y) * 0.72;
    final r = rim
        ? reach * (0.9 + _rng.nextDouble() * 0.2)
        : 100 + sqrt((i % count + 0.5) / count) * reach;
    final ranged = mixed && i % 20 == 0;
    return CosmicSurvivalEnemy(
      position: orb.position + Offset(cos(a) * r, sin(a) * r * 0.72),
      hp: 150,
      maxHp: 150,
      speed: ranged ? 35 : 14,
      damage: 0,
      radius: ranged ? 12 : 7,
      tier: ranged
          ? EnemyTier.sentinel
          : i % 4 == 0
          ? EnemyTier.drone
          : EnemyTier.wisp,
      element: i.isEven ? 'Earth' : 'Fire',
      conduct: ranged ? EnemyConduct.standoff : EnemyConduct.charge,
      target: CosmicEnemyTarget.orb,
      retargetTimer: _rng.nextDouble() * 2.6,
    );
  }

  void seed(int count, {bool mixed = false}) {
    population = count;
    this.mixed = mixed;
    if (!isLoaded) return;
    enemies.clear();
    companionProjectiles.clear();
    updateTimes.clear();
    for (var i = 0; i < count; i++) {
      enemies.add(_body(i, count, rim: false));
    }
    _seedIndex = count;
    _countAlive();
  }

  /// Every companion casts on the same frame: the worst case for projectiles,
  /// fields and the deaths they cause.
  void forceSpecials() {
    for (final c in activeCompanions.values) {
      c.specialCooldown = 0;
    }
  }

  void massKill() {
    // Intentionally run the real damage/reward/death path, not list.clear().
    final alive = enemies.where((e) => !e.isDead).toList();
    for (final e in alive.take(alive.length ~/ 2)) {
      // ignore: invalid_use_of_visible_for_testing_member
      debugShipAttackDamage(e, 1000000);
    }
  }

  @override
  void update(double dt) {
    if (isLoaded) {
      alchemicalMeter = 0;
      showingPowerUpSelection = false;
      gamePaused = false;
      ship.currentHp = ship.maxHp.toDouble();
      orb.currentHp = orb.maxHp.toDouble();
      for (final c in activeCompanions.values) {
        c.currentHp = c.maxHp;
      }
      // Replace the dead at the rim so the population holds while bodies
      // keep dying: steady-state death churn, not a draining crowd.
      _countAlive();
      if (sustain) {
        final missing = population - aliveCount;
        for (var n = 0; n < min(missing, 60); n++) {
          enemies.add(_body(_seedIndex++, population, rim: true));
        }
      }
    }
    final watch = Stopwatch()..start();
    super.update(dt);
    updateTimes.add(watch.elapsedMicroseconds / 1000);
    _countAlive();
    if (updateTimes.length > 120) updateTimes.removeAt(0);
  }
}
