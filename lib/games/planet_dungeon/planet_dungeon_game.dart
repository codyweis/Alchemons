// lib/games/planet_dungeon/planet_dungeon_game.dart
//
// PLANET DUNGEON — Flame scene (chassis).
//
// Top-down room crawler. The player swap-controls the creatures they brought
// (one active at a time); inactive creatures hold position. Manual camera /
// rendering (matching the cosmic_survival pattern), manual AABB collision,
// doorway room transitions, hazard→death→respawn, and instant star banking.
// Slice 3 layers the bespoke per-planet puzzles on top.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/companion_stance.dart';
import 'package:alchemons/games/shared/damage_numbers.dart';
import 'package:alchemons/games/planet_dungeon/burn_field.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_lava.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_mud.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_ice.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_crystal.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_spirit.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_fx.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_sky.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart' show Anchor;
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

part 'planet_dungeon_game_air.dart';
part 'planet_dungeon_game_fire.dart';
part 'planet_dungeon_game_water.dart';
part 'planet_dungeon_game_earth.dart';
part 'planet_dungeon_game_lightning.dart';
part 'planet_dungeon_game_steam.dart';
part 'planet_dungeon_game_lava.dart';
part 'planet_dungeon_game_mud.dart';
part 'planet_dungeon_game_poison.dart';
part 'planet_dungeon_game_ice.dart';
part 'planet_dungeon_game_dust.dart';
part 'planet_dungeon_game_crystal.dart';
part 'planet_dungeon_game_plant.dart';
part 'planet_dungeon_game_spirit.dart';
part 'planet_dungeon_game_dark.dart';
part 'planet_dungeon_game_light.dart';
part 'planet_dungeon_game_blood.dart';

/// The hint capsule's narrative channels (§5.6 "Hint & popup standard").
///
/// The capsule carries SPEECH ONLY — one line, never stacked — and every
/// emission declares which voice it speaks in. The resolver
/// ([PlanetDungeonGame._emitHint]) picks by PRIORITY, not by call order, so a
/// stray flavor line can no longer stomp a refusal or a hard-won insight
/// reading just because its `_update*` ran later in the frame.
///
/// State that is not speech (progress counters, control feedback) does not
/// belong here at all — see [DungeonProgressReadout] and the cooldown
/// affordances on the combat buttons.
enum DungeonHintChannel {
  /// Rare atmospheric flavor. Never mechanics, never stats, hard cooldown.
  ambient(0),

  /// What the room wants, on entry — the goal, never the method. Also the
  /// default for untagged legacy emissions (world-response speech).
  objective(1),

  /// Mask insight: the earned how-to. Priority-protected — nothing below
  /// BLOCKED may interrupt a reading mid-read.
  insight(2),

  /// A refused ATTEMPT, one short clause naming what's missing. Attempt-edged:
  /// it speaks once per attempt and remembers, so leaning on a sealed door
  /// states the refusal once instead of flickering it every frame.
  blocked(3);

  const DungeonHintChannel(this.priority);

  /// Higher wins. Equal-or-higher may evict a live line; lower never may.
  final int priority;
}

/// A persistent, glanceable progress counter shown beside the star tracker.
///
/// Progress is STATE the player checks at will ("Rings 2/5", "Stones 2 of 4
/// true", "Pressure 40") — not a sentence that fades after 2.4s. This is the
/// generalized form of the per-planet gauges (Steam's pressure head, Water's
/// tide stand); planets fill it from [PlanetDungeonGame.progressReadout].
class DungeonProgressReadout {
  const DungeonProgressReadout({
    required this.label,
    required this.value,
    this.fraction,
  });

  /// Short all-caps noun for the thing being counted ("RINGS").
  final String label;

  /// The count itself, already formatted ("2/5", "2 of 4 true", "40").
  final String value;

  /// Optional 0..1 completion, drawn as a hairline fill under the value.
  final double? fraction;
}

/// One controllable creature in the dungeon.
class DungeonCreature {
  DungeonCreature({required this.member});

  final CosmicPartyMember member;
  Offset position = Offset.zero;
  double angle = 0.0; // facing (radians); cos>0 ⇒ moving right

  /// TRUE aim direction (radians), updated from the full joystick vector —
  /// unlike [angle], which snaps to left/right for sprite flipping and can
  /// never point up/down. Cell-targeted verbs (the Steam molten grid) aim
  /// with this so the player can act on the square above or below them.
  double aimAngle = 0.0;
  double hp = 100.0;
  double maxHp = 100.0;

  SpriteAnimationTicker? ticker;
  double spriteScale = 1.0;

  /// Last position on solid ground (used to recover from a glide fall).
  Offset lastSafe = Offset.zero;

  /// True once this creature's knock-out has been announced (burst + hint),
  /// so the down reaction fires exactly once per fall.
  bool downHandled = false;

  /// Seconds until a downed creature revives (0 = not waiting). Set when it
  /// falls; counted down each frame; on zero it rejoins the party.
  double respawnTimer = 0;

  bool get alive => hp > 0;
  double get hpFraction => (maxHp <= 0) ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  DungeonAbility get ability => abilityForFamily(member.family);
}

class _IslandGeometry {
  const _IslandGeometry({
    required this.top,
    required this.underside,
    required this.debris,
    required this.runes,
  });

  final Path top;
  final Path underside;
  final List<Offset> debris;
  final List<Offset> runes;
}

enum _AirRoomTheme {
  entry,
  hub,
  ascent,
  crosswind,
  cloudPlatform,
  summit,
  wonderCloud,
  loom,
  relic,
  storm,
  guardian,
  generic,
}

class _DungeonWingBeam {
  _DungeonWingBeam({
    required this.descriptor,
    required this.sourceSlotIndex,
    required this.origin,
    required this.angle,
  }) : life = descriptor.duration,
       tickTimer = descriptor.tickInterval,
       chargeTimer = descriptor.chargeTime;

  final WingBeamEffect descriptor;
  final int sourceSlotIndex;
  Offset origin;
  double angle;
  double life;
  double tickTimer;
  double chargeTimer;

  bool get dead => life <= 0;
}

/// Transient kin charged-laser beam visual.
class _KinBeamFx {
  _KinBeamFx({required this.origin, required this.end, required this.color})
    : life = 0.34;

  final Offset origin;
  final Offset end;
  final Color color;
  double life;

  bool get dead => life <= 0;
}

/// One-shot "a door just unlocked" ring, shown in the door's room (on the
/// next visit if the player isn't there when it flips).
/// The guardian relic's victory ceremony: it drops from the fallen guardian,
/// hovers glinting for a breath, then expands and dissolves into the player's
/// keeping (the End Run popup re-presents it formally).
/// The raid guardian's death throes, played before the reward screen.
///
/// A raid is the longest fight in the game; ending it with a UI panel
/// appearing over a still-standing body gave the kill no weight. Four beats:
/// the body seizes and cracks, everything implodes to the core, it detonates,
/// then the light settles. Only then do rewards appear.
class _RaidDeathFx {
  _RaidDeathFx({
    required this.position,
    required this.radius,
    required this.color,
  });

  final Offset position;
  final double radius;
  final Color color;
  double t = 0;

  static const double seize = 1.25;
  static const double implode = 0.75;
  static const double burst = 0.45;
  static const double settle = 1.15;
  static const double duration = seize + implode + burst + settle;

  bool get done => t >= duration;

  /// 0→1 within each beat; 0 before it starts, 1 after it ends.
  double _beat(double start, double len) => ((t - start) / len).clamp(0.0, 1.0);

  double get seizeT => _beat(0, seize);
  double get implodeT => _beat(seize, implode);
  double get burstT => _beat(seize + implode, burst);
  double get settleT => _beat(seize + implode + burst, settle);
}

class _RelicDropFx {
  _RelicDropFx({required this.roomId, required this.position});
  final String roomId;
  final Offset position;
  double t = 0;
  static const double duration = 3.6;
  bool get done => t >= duration;
}

class _DoorRevealFx {
  _DoorRevealFx({required this.roomId, required this.position});

  final String roomId;
  final Offset position;
  double ttl = 2.2;
  bool burstFired = false;
}

class _AlchemyParticle {
  _AlchemyParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.maxLife,
    required this.size,
    this.arc = false,
  }) : life = maxLife;

  Offset position;
  Offset velocity;
  final Color color;
  final double maxLife;
  final double size;
  final bool arc;
  double life;

  bool get dead => life <= 0;
  double get t => maxLife <= 0 ? 1 : (1 - life / maxLife).clamp(0.0, 1.0);
}

class PlanetDungeonGame extends FlameGame {
  PlanetDungeonGame({
    required this.element,
    required this.party,
    required this.initialStarMask,
    Set<String> initialDiscoveredCloudIds = const {},
    required this.onStarEarned,
    this.onCloudDiscovered,
    this.onGuardianIntro,
    required this.onPlayerDown,
    required this.onChanged,
    this.raid,
    this.onRaidCleared,
    this.onRaidCreatureDown,
    this.onRaidExpired,
    this.onRaidWiped,
    this.clearedGuardianCount = 0,
    DungeonLayout? layoutOverride,
  }) : layout = layoutOverride ?? kPlanetDungeonLayouts[element]! {
    discoveredClouds.addAll(initialDiscoveredCloudIds);
    // Assigned HERE, not in onLoad: the HUD (minimap, action cluster) builds
    // the moment the game object exists — long before Flame finishes the
    // async asset load — and reads currentRoom immediately.
    currentRoomId = layout.entranceRoomId;
    // The zero-sum dynamo idles into its authored initial trunk from the
    // first frame (Lightning; null everywhere else).
    activeTrunk = layout.initialTrunkId;
    // The Buried Giant's scale answer is rolled fresh per run.
    _rollScaleSolution();
    // (The Mirror-Tide's canal network is STONE — authored, not rolled; its
    // solvability is proved once, in the layout test, by `solveLanternDrift`.)
    // The Cinder Cathedral's rite IS rolled, with the evidence that proves it.
    _rollRiteOrder();
    // …and the cloister's grooves, out of the assignments the garden solver
    // has proved solvable, wind-turn-requiring and honestly hard.
    _rollAshGarden();
    // The Wind-Crown Spire starts CALM, with its rods flat and its storm-cell
    // already on its authored mark — seeded here, not in onLoad, because the
    // HUD (and every headless sim) reads this state before Flame finishes.
    _resetSpireState();
    // The Frozen Observatory opens with every flue heaped in fresh snow and
    // its orrery blocks on their authored cells — seeded here for the same
    // reason as the spire: the HUD and every headless sim read this state
    // before Flame finishes loading.
    _resetShaftState();
    // The fen opens with every crossing quaking mire and the sarsen in the
    // gate's silt — seeded here for the same reason as the shaft.
    _resetBogState();
    _resetRuinsState();
    _resetKeepState();
    _resetGraveState();
    _resetCryptState();
    _resetVaultState();
    _resetArchiveState();
    _resetHeartState();
    // Raids skip the altar puzzle: the guardian is already rampaging.
    if (isRaid) guardianAwake = true;
  }

  final String element;
  final List<CosmicPartyMember> party;
  final int initialStarMask;
  final void Function(int starIndex) onStarEarned;
  final void Function(String cloudId)? onCloudDiscovered;

  /// The guardian-intro popup hook (§5.6 "four occasions, one chrome"): fires
  /// the moment the mystic's combat spawns, with its name and its one arrival
  /// line. When wired, the screen presents the chrome banner and the capsule
  /// stays quiet; unwired (headless tests), the line falls back to the capsule.
  final void Function(String mysticName, String line)? onGuardianIntro;
  final VoidCallback onPlayerDown;
  final VoidCallback onChanged;

  /// Non-null when this run is a raid: one open arena, an empowered guardian,
  /// phase adds, and [onRaidCleared] instead of a star on victory.
  final RaidConfig? raid;
  final VoidCallback? onRaidCleared;

  /// Fired once when the raid's fight timer runs out with the guardian alive.
  final VoidCallback? onRaidExpired;

  /// Fired once, with the instance id, when an Alchemon falls in a raid.
  ///
  /// A raid down is permanent for the run; the host also burns the
  /// Alchemon's stamina so the loss outlives the attempt.
  final void Function(String instanceId)? onRaidCreatureDown;

  /// A raid party wipe. Elsewhere a wipe resets the run to the entrance with
  /// everyone healed, which in a raid would hand the whole party back and make
  /// the no-revival rule meaningless.
  final VoidCallback? onRaidWiped;
  bool get isRaid => raid != null;
  int _raidPhaseIndex = 0;

  /// The campaign's difficulty clock: how many OTHER planets' guardians have
  /// already fallen (0..16). Creature stats run 0–5.0, so the curve must
  /// stretch from "first dungeon, mid-bred trio" to "seventeenth dungeon,
  /// near-perfect team": enemies and ESPECIALLY guardians scale with it.
  final int clearedGuardianCount;

  /// Guardian/wisp HP swells with progress (final guardian ≈ 3.9×). Was
  /// ×0.45·n (≈8.2× at the end) while the guardian pool was tiny and the
  /// lull-strike fraction decided every fight; now that [kGuardianBaseHp] is
  /// sized against real party damage, that slope stretched the last fights
  /// past two minutes. Measured at ×0.18·n: a near-perfect trio spends ~70s
  /// on the seventeenth mystic, and a mid one cannot finish it — which is
  /// the campaign statement the curve was always making.
  double get progressHpMul => 1.0 + 0.18 * clearedGuardianCount;

  /// Damage climbs more gently (final ≈ 2.9×) — lethality should come from
  /// the longer fight, not one-shots.
  double get progressDmgMul => 1.0 + 0.12 * clearedGuardianCount;

  /// Lull strikes needed to fell the guardian on a FRESH save.
  ///
  /// 2026-08-14, MEASURED (headless sim, ideal trio parked on the perch,
  /// attack + special mashed the frame they come up): a three-Alchemon party
  /// deals ~172 dmg/s at stat 2.0, ~393 at 3.0 and ~1005 at 4.5. The guardian
  /// pool was 341. The mystic was deleted inside a second — no cycle, no
  /// twist, no enrage, nothing the fight was built to show.
  ///
  /// The strike chunk is `maxHp / strikesNeeded`, so this number is also the
  /// fight's LENGTH CAP: at ~2 paced strikes per 3.0s lull in a 6s cycle, the
  /// strike path alone runs 3 × strikesNeeded seconds however fat the pool is.
  /// 14 puts that ceiling at 42s on a fresh save (78s by the last dungeon),
  /// and [kGuardianBaseHp] is then sized so a mid trio spends most of it.
  /// (Deliberately NOT tied to [maxGuardianHp], which is the HUD's pip count.)
  static const double kGuardianBaseStrikes = 14;

  /// The guardian's own pool before any scaling — sized against MEASURED
  /// party damage, not against a wisp. With the wave-7 curve (×1.3125) a
  /// fresh-save mystic stands at ~41k, which the sim plays out as ≈36s for a
  /// weak trio, ≈30s for a mid one and ≈21s for a near-perfect one: four to
  /// six full rage/lull cycles, the half-HP enrage, and room for the planet's
  /// own twist to turn several times.
  static const double kGuardianBaseHp = 6000;

  /// Lull strikes needed to fell the guardian: 14 on a fresh save, 26 by the
  /// last dungeon (the strike chunk is a fraction of max HP, so raw HP alone
  /// wouldn't lengthen the strike path).
  double get guardianStrikesNeeded =>
      kGuardianBaseStrikes + clearedGuardianCount * 0.75;

  /// Synthetic discovery id for the entry passage reveal. Stored alongside
  /// cloud ids so the one-time entry puzzle stays solved across runs
  /// (knowledge persists, like cloud echoes).
  static const String entryDoorDiscoveryId = 'rune:entry_door';

  final DungeonLayout layout;
  late String currentRoomId;
  int starMask = 0;

  final List<DungeonCreature> creatures = [];
  final List<CosmicSurvivalCompanion> combatCompanions = [];
  final List<CosmicSurvivalEnemy> combatEnemies = [];

  /// Floating damage numbers. Only spawned during guardian and raid fights —
  /// scattering numbers over ordinary trash would bury the puzzle the room is
  /// actually about. Shared with survival's boss fights.
  final DamageNumberField damageNumbers = DamageNumberField();

  /// Non-null while the raid guardian is dying. Combat is suspended and the
  /// reward screen is withheld until it finishes.
  _RaidDeathFx? _raidDeath;

  /// True while the death cinematic owns the screen.
  bool get isRaidDeathPlaying => _raidDeath != null;

  /// Seconds left to fell the raid guardian. Null outside a raid.
  double? _raidFightRemaining;
  bool _raidExpiredFired = false;

  Duration? get raidTimeRemaining => _raidFightRemaining == null
      ? null
      : Duration(milliseconds: (_raidFightRemaining! * 1000).round());

  // TEMPORARY probe: how much of the frame is the dungeon itself?
  static double _probeLastUpdateMs = 0;
  static double _pu = 0;
  static double _pr = 0;
  static int _pn = 0;
  static double _puWorst = 0;
  static double _prWorst = 0;

  void _probeAccum(double u, double r) {
    _pu += u;
    _pr += r;
    if (u > _puWorst) _puWorst = u;
    if (r > _prWorst) _prWorst = r;
    _pn++;
    if (_pn % 120 == 0) {
      debugPrint(
        'GAMEPROBE n=$_pn avgUpdate=${(_pu / _pn).toStringAsFixed(2)}ms '
        'avgRender=${(_pr / _pn).toStringAsFixed(2)}ms '
        'worstUpdate=${_puWorst.toStringAsFixed(2)} '
        'worstRender=${_prWorst.toStringAsFixed(2)} '
        'enemies=${combatEnemies.length} proj=${combatProjectiles.length} '
        'nums=${damageNumbers.length}',
      );
      _puWorst = 0;
      _prWorst = 0;
    }
  }

  void _updateRaidFightTimer(double dt) {
    if (!isRaid || _raidExpiredFired) return;
    // The clock stops the moment the guardian falls — the death sequence and
    // the loot that follows are not part of the check.
    if (_raidDeath != null) return;
    final g = _guardianEnemy;
    if (g != null && (g.isDead || g.hp <= 0)) return;

    _raidFightRemaining ??= kRaidFightLimit.inSeconds.toDouble();
    _raidFightRemaining = _raidFightRemaining! - dt;
    if (_raidFightRemaining! > 0) return;

    _raidFightRemaining = 0;
    _raidExpiredFired = true;
    _setHint('The storm outlasts you — the raid is lost', 4.0);
    onRaidExpired?.call();
  }

  final List<Projectile> combatProjectiles = [];
  final List<_DungeonWingBeam> _activeWingBeams = [];
  final List<_KinBeamFx> _kinBeams = [];
  final List<_AlchemyParticle> _alchemyParticles = [];

  /// Shared combat-ability particles (zone wisps, hit sparks, bursts). Kept
  /// separate from the alchemy/puzzle flavor pool above so abilities render
  /// identically to Cosmic Survival via the shared canonical renderer.
  final AbilityVfxPool _abilityVfx = AbilityVfxPool();

  /// Seconds a kin holds still charging before its laser fires (survival's
  /// `_kinChargeTime`).
  static const double _kinChargeTime = 1.5;
  int activeIndex = 0;

  /// Normalised movement input for the active creature (set by the screen).
  Offset joystickDirection = Offset.zero;

  double _time = 0;
  double _doorCooldown = 0;
  final Set<int> _earnedStars = {};

  // ── Verb / puzzle run-state ──
  bool flightActive = false;
  double flightMeter = 0; // seconds of flight remaining
  double flightMax = 1;

  /// True while the active WALKER is being carried by an updraft column
  /// (family = quality: wings glide the ascent, everyone else rides the
  /// thermals — clumsier, but the dungeon never hard-requires a Wing).
  bool updraftRiding = false;
  double _updraftCoyote = 0; // grace to steer onto a ledge after the column

  // ── Air (Wind-Crown Spire) run-state — §9.1 item 4 ──
  // Logic lives in planet_dungeon_game_air.dart; the fields sit here because
  // Dart extensions cannot declare them (same shape as the other five).
  bool get _isSpire => layout.element == 'Air';

  /// Gales WOKEN this run. Permanent until death — no timers (§6.11 REWORK).
  final Set<String> wokenGales = {};

  /// Per-gale eased build, 0 → 1. A wind swells; it never snaps on.
  final Map<String, double> galeRamp = {};

  /// How many gales the spire has in total. Cached at reset: `progressReadout`
  /// and the hub compass both read it every frame, and rebuilding the set each
  /// time would allocate in the render loop for no reason.
  int totalGales = 0;

  /// True while a gale is carrying the active WALKER (not a thermal).
  bool _galeRiding = false;

  bool summitOpen = false;
  bool entryDoorRevealed = false;

  /// Storm-rod ranks, by rod id (0..kStormRodMaxHeight).
  final Map<String, int> rodHeight = {};

  /// Eased visual rank per rod — rods grind, they do not teleport.
  final Map<String, double> _rodRaise = {};

  /// The live storm-cell's angle on its ring, and its discharge clock.
  double stormCellAngle = 0;
  double stormStrikeTimer = 0;

  /// The conductor ids the last leader climbed (rendering + tests).
  final List<String> lastLeaderPath = [];
  double _leaderFlash = 0;

  /// The ladder that WON, and where the bolt came down to start it. A conduit
  /// latches (§9.1) — so the chain that lit it latches with it and keeps
  /// burning instead of guttering out after one flash. The circuit the player
  /// built is a standing fact about the room, not a moment.
  final List<String> latchedLeaderPath = [];
  Offset? _latchedLeaderOrigin;

  /// The Roc's dragged leash — the centre its stolen storm-cell circles.
  Offset _rocLeash = Offset.zero;
  double _rocStunLeft = 0;

  final Set<String> discoveredClouds = {}; // cloud ids (kept across death)
  String? carriedCloudId;
  String? carriedCloudType;
  final Map<String, String> filledAnchors = {}; // anchorId -> deposited type

  // ── Wonder-cloud trials (one micro-puzzle per branch room) ──
  // Discovery is EARNED: each branch chamber seals its echo behind a small
  // themed trial (ride the gale / time the orbit / crack the shell / catch
  // the feathers / pin the shroud). Solving it IS the discovery.
  // ── Spiral trial (THE GALE EYE) run-state ──
  // §9.1: the Spiral is COMPOSED, not walked. The vent ring is authored
  // (`DungeonRoom.galeVents`); which way each vent breathes is rolled per run
  // and proved solvable (`_rollSpiralVents` / `solveSpiralVents`, Air file).
  /// This run's vent flows, by vent id. Rolled fresh every run/death.
  final Map<String, GaleVentFlow> spiralVentFlow = {};

  /// Jets opened this ATTEMPT — irreversible until the chamber is left.
  final Set<String> spiralOpenJets = {};

  /// How far each opened jet has swelled (0 = still, 1 = full). Eased, never
  /// snapped — same rule as a woken gale.
  final Map<String, double> spiralJetRamp = {};

  /// True once an incoherent jet has sheared the forming eye: the attempt is
  /// spent until the player leaves and comes back.
  bool spiralTorn = false;

  /// Fade on the tear animation (the failure you WATCH).
  double _spiralTearFlash = 0;

  /// The mouth whose jet did the shearing (drawn as the culprit).
  String? _spiralShearedVent;

  /// The room the trial logic last saw, so re-entering the chamber re-arms it.
  String? _spiralLastRoom;

  /// Shimmer-fold spots for the Veil trial, relative to the room centre.
  static const List<Offset> kVeilSpotOffsets = [
    Offset(-200, -130),
    Offset(180, -100),
    Offset(0, 160),
  ];

  /// Per-room trial progress (spiral eddies ridden / feathers caught).
  final Map<String, int> _wonderProgress = {};

  /// Veil spots already pinned this run.
  final Set<int> _veilPinned = {};

  /// The anvil's storm-shell defenders (wave must be cleared to wake it).
  final List<CosmicSurvivalEnemy> _anvilWave = [];
  bool _anvilShellStruck = false;

  /// Falling feathers currently drifting in the Feather chamber.
  final List<Offset> _feathers = [];
  final List<double> _featherPhases = [];
  double _featherSpawnTimer = 1.2;

  /// Veil trial: Fire's flare reveals all shimmer-folds for a few seconds.
  double veilFlareTimer = 0;

  int wonderProgress(String roomId) => switch (roomId) {
    'veil_cloud' => _veilPinned.length,
    'spiral_cloud' => spiralOpenJets.length,
    _ => _wonderProgress[roomId] ?? 0,
  };

  List<Offset> get fallingFeatherPositions => List.unmodifiable(_feathers);

  /// Veil shimmer-spot world positions for [room].
  List<Offset> veilSpots(DungeonRoom room) => [
    for (final o in kVeilSpotOffsets) room.bounds.center + o,
  ];

  double _ringMoteAngle(int i) => _time * (0.55 + i * 0.55) + pi / 2;

  double _angularGap(double a, double b) {
    var d = (a - b) % (pi * 2);
    if (d < 0) d += pi * 2;
    return min(d, pi * 2 - d);
  }

  /// True while the Ring trial's three orbit motes are gathered. The window is
  /// family-neutral — whoever stands in the ring reads the same rhythm.
  bool get ringMotesAligned {
    const tolerance = 0.6;
    final a0 = _ringMoteAngle(0);
    final a1 = _ringMoteAngle(1);
    final a2 = _ringMoteAngle(2);
    return _angularGap(a0, a1) < tolerance &&
        _angularGap(a1, a2) < tolerance &&
        _angularGap(a0, a2) < tolerance;
  }

  /// Which Veil shimmer-fold is breathing right now (null between breaths).
  /// Cycle: each spot takes a 2.5s turn, visible for the first 1.6s.
  int? get veilVisibleSpotIndex {
    final cycle = _time % 7.5;
    final idx = (cycle ~/ 2.5).clamp(0, 2);
    if (_veilPinned.contains(idx)) return null;
    return (cycle - idx * 2.5) < 1.6 ? idx : null;
  }

  /// The sealed wonder-cloud in [room], or null if none / already earned.
  HiddenCloud? _sealedWonderCloud(DungeonRoom room) {
    if (room.anchors.isNotEmpty || room.clouds.length != 1) return null;
    final cl = room.clouds.first;
    return discoveredClouds.contains(cl.id) ? null : cl;
  }

  // ── Fire (Cinder Cathedral) run-state ──
  /// Next brazier order to light in the choir rite (resets on a wrong flame).
  int ritualProgress = 0;

  /// Insight tier from reading the scriptorium's soot mural (-1 = unread).
  /// Knowledge, like cloud discoveries: it survives death within a session.
  int choirRevealTier = -1;

  /// Which of the scriptorium's four corner torches are burning, by index into
  /// the room's `muralTorches`. Light is a property of the ROOM, so unlike
  /// `choirRevealTier` this does not survive a restart — walk back in and the
  /// torches have gone out again.
  final Set<int> litMuralTorches = {};

  /// True once every corner torch in [room] is burning.
  bool muralLit(DungeonRoom room) =>
      room.muralTorches.isNotEmpty &&
      litMuralTorches.length >= room.muralTorches.length;

  /// THE RITE, ROLLED PER RUN (§6.1 REWORK): `riteOrder[rank]` = the index into
  /// the choir's `braziers` list that was lit at that rank. Never authored, so
  /// a wiki can never spoil it — and never noise either: [riteTestimony] is
  /// generated alongside it and PROVABLY pins it down (see
  /// `solveRiteOrder()`), so the whole sequence can be read off the iron.
  final List<int> riteOrder = [];

  /// The physical testimony each brazier carries, by brazier list index.
  final List<BrazierTestimony> riteTestimony = [];

  /// The rite's downwind: one quantised compass direction the ash has drifted,
  /// shared by every brazier and streaked across the choir floor.
  Offset riteAshDrift = Offset.zero;

  /// The two ranks the scriptorium mural CONFIRMS (never the order — §6.1).
  List<int> riteMuralRanks = const [];

  /// Insight's marking of the evidence, eased 0→1 (t1), and the single link
  /// t2 annotates (the rank whose step to rank+1 is drawn out). Knowledge:
  /// both survive death, like the mural reading.
  double _testimonyMark = 0;
  bool _testimonyMarked = false;
  int? _testimonyLinkRank;

  /// Per-brazier testimony fade (index → 1 fresh … 0 consumed): the rite's own
  /// fire eats the old wax and soot as each brazier takes flame.
  final Map<int, double> _testimonyFade = {};

  /// Star 3's DECISION (§6.1 REWORK): the declared censer run, and whether the
  /// vesper has begun (after which the run is committed for this attempt).
  String? vesperRouteId;
  bool vesperCommitted = false;

  /// Eased swap between the two censer runs (0 mid-swing … 1 settled).
  double _routeSwapT = 1.0;

  /// Simurgh's brazier telegraph (§7 retrofit): the rank it is re-lighting,
  /// the beat clock, and each live pillar's 0→1 wind-up/eruption progress.
  int _simurghRank = 0;
  double _simurghBeat = 0;
  final Map<int, double> _simurghPillars = {};

  /// THE ASH GARDEN (Star 2 rework — "the wind carries the reaction"). The
  /// whole garth is ONE packed base-5 board, `AshGardenRules.bedCount` digits
  /// wide, and it is the single source of truth shared by the interaction
  /// verbs, the renderer and `solveAshGarden()` — the puzzle the solver proves
  /// is literally the puzzle the player plays.
  int gardenBoard = 0;

  /// The crosswind's quarter (see `AshGardenRules`: 0 N · 1 E · 2 S · 3 W),
  /// the quarter it swung FROM, and the eased 0→1 swing (never a snap).
  int gardenWind = 1;
  int gardenWindFrom = 1;
  double gardenWindSwing = 1.0;

  /// The quarter the run's wind starts at (restored on death with the beds).
  int gardenWindStart = 1;

  /// What each groove is cut to receive, index-aligned with the cloister's
  /// `vineBeds`. ROLLED PER RUN out of the assignments the solver has proved
  /// solvable AND wind-turn-requiring AND inside the difficulty band. Like the
  /// rite's evidence this is the cathedral's stonework, not this run's
  /// progress: it survives death.
  final List<GrooveDemand> gardenDemands = [];

  /// Vine maturity per bed index, 0→1 (shoots must take before they will
  /// burn — the time price of regrowing a fouled bed).
  final Map<int, double> _bedGrowth = {};

  /// The one source→groove link a tier-2 reading has drawn out (null = none).
  ({int source, int groove})? _gardenLink;

  /// Ember bells rung this run (IncenseChain.id).
  final Set<String> bellsRung = {};

  /// Furthest censer index a chain's flame has reached (re-ignite checkpoint).
  final Map<String, int> _chainCheckpoints = {};

  /// Live vesper flames crawling their chains, by chain id.
  final Map<String, _VesperFlame> _vesperFlames = {};

  /// Recent grow/burn pulse per bed index (render accent).
  final Map<int, double> _bedFx = {};

  /// Live ash plumes crossing the garth (bed index → 0→1 flight), so the
  /// reaction's product is WATCHED onto the beds behind, never teleported.
  final Map<int, double> _bedPlume = {};
  double _bellTollFx = 0;

  /// Ember Epitaph easter egg (scriptorium): 0 hidden · 1 maxim written into
  /// the floor by insight (animated) + garden bared · 2 planted · 3 lit.
  /// [epitaphFans] = gusts fed to the flame (the third ignites the script).
  /// Stage 1 is knowledge (survives death); the growth resets like any other
  /// run-state. No hint popups: the floor-script IS the presentation.
  int epitaphStage = 0;
  int epitaphFans = 0;
  double epitaphWriteT = 0; // seconds since the ground-script began writing
  double epitaphBlazeT = 0; // seconds since the maxim caught fire
  List<TextPainter>? _epitaphGhostLines; // cached — never built per frame
  List<TextPainter>? _epitaphSootLines;
  List<TextPainter>? _epitaphFireLines;

  bool get _isCathedral => layout.element == 'Fire';

  // ── Water (Mirror Tide) run-state ──
  /// Settled/target tide stand (0 low · 1 mid · 2 high) and the ANIMATED
  /// visual water fraction (0..1 = level/2) easing toward it — floods and
  /// drains are watched, never teleported.
  int tideLevel = 0;
  double tideAnim = 0;

  /// Sluice seals opened this run (Star 1).
  final Set<String> openedSeals = {};

  // ── Star 2: the moon-lantern on the canals (docs §6.4 rework) ──
  /// The basin the lantern last passed (null = it has never been set this
  /// run). While [lanternChannel] is non-null the lantern is CROSSING that
  /// groove out of this basin; otherwise it turns in the basin itself.
  String? lanternNodeId;
  CanalChannel? lanternChannel;

  /// The basin BEFORE [lanternNodeId] — where the backwash hands the lantern
  /// back if it settles into a basin with no groove out of it at all.
  String? _lanternPrevNodeId;

  /// 0..1 along [lanternChannel], and how long the lantern has been turning
  /// in its basin (it only commits to a groove once the water is SETTLED).
  double lanternT = 0;
  double lanternDwell = 0;

  /// False = the lantern lies dark (grounded or sumped) and waits for a hand.
  bool lanternLit = false;

  /// Where the lantern actually IS — eased every frame, never teleported.
  Offset lanternPos = Offset.zero;

  /// One-shot flare (set / arrival / ground / sump) and the eased backwash
  /// that carries a lost lantern back to the last mouth it passed.
  double lanternFlare = 0;
  Offset? _lanternWashFrom;
  double _lanternWashT = 0;

  /// How many times the lantern has been lost this run (diagnostics + tests).
  int lanternLosses = 0;

  /// Basins an Ice hand has plugged into dams, with their eased ice caps.
  /// A dam only ever REMOVES a destination — nothing but the tide can make a
  /// dry groove run — so damming can never conjure a route the stone forbids.
  final Set<String> dammedNodes = {};
  final Map<String, double> _damAnim = {};

  /// Spirit's reading. Naming the deep cuts is PERMANENT for the run (a
  /// warning you cannot look at twice is only a memory test); the forecast
  /// tiers ride [canalRevealTimer], which Intelligence buys.
  bool sumpsRead = false;
  double canalRevealTimer = 0;
  int canalRevealTier = 0;

  /// Node id → node for the gallery's canal network, built once from the
  /// const layout: the drift, the render and the solver all ask for it many
  /// times a frame, and rebuilding the map each time would allocate for
  /// nothing.
  Map<String, CanalNode>? _canalNodeCache;

  /// Cached per-channel geometry (endpoints, unit vector, length) — pure
  /// functions of the const layout, so it is built once and never per frame.
  List<_CanalGeom>? _canalGeomCache;

  /// Leviathan's tide-turn (§7 retrofit): the direction the deep is hauling
  /// the water (+1 rising, -1 falling) and last frame's raw lull state, so
  /// the roar can fire exactly on the edge where the lull shuts.
  int _leviathanTideDir = 1;
  bool _leviathanLullPrev = true;
  int _leviathanRoars = 0;

  /// How many times Leviathan has turned the tide this fight (diagnostics).
  int get leviathanRoars => _leviathanRoars;

  /// Moon-pool states (Star 3): MoonPool.id → 0 liquid · 1 frozen bridge.
  final Map<String, int> poolStates = {};
  final Map<String, double> _poolFx = {}; // freeze/shatter pulses

  bool get _isTemple => layout.element == 'Water';
  bool get tideSettled => (tideAnim - tideLevel / 2).abs() < 0.04;

  /// Shared entry-rite reveal animation (ALL planets): 0 = unrevealed
  /// (lintel fallen / hearth cold / bowl dry / runes dark) → 1 = revealed.
  /// Eased up over ~1.6s when the entry rite is freshly performed; snapped to 1
  /// when loaded already-open. [_entryRevealPrev] is last frame's value so
  /// per-planet reveals can fire one-shot FX as the value crosses a threshold.
  double _entryReveal = 0;
  double _entryRevealPrev = 0;

  void _updateEntryReveal(double dt) {
    _entryRevealPrev = _entryReveal;
    if (entryDoorRevealed && _entryReveal < 1.0) {
      _entryReveal = (_entryReveal + dt / 1.6).clamp(0.0, 1.0);
    }
  }

  // ── Smoothed camera follow ──
  /// The point the camera is centred on (eased). Normal walking tracks tightly;
  /// a character SWAP / death-swap / teleport triggers a quick PAN instead of a
  /// snap; a room change snaps (different coordinate space).
  Offset? _camFocus;
  String? _camFocusRoom;
  int _camActiveIndex = 0;
  bool _camPanning = false;

  /// Seconds a downed creature waits before reviving.
  static const double respawnSeconds = 10.0;

  Offset get _cameraFocus =>
      _camFocus ?? (active?.position ?? currentRoom.bounds.center);

  void _updateCamera(double dt) {
    // The raid death is the shot — hold on the guardian, not the player.
    final target =
        _raidDeath?.position ?? active?.position ?? currentRoom.bounds.center;
    // Room change → snap (the new room is a different coordinate space).
    if (_camFocusRoom != currentRoomId || _camFocus == null) {
      _camFocus = target;
      _camFocusRoom = currentRoomId;
      _camActiveIndex = activeIndex;
      _camPanning = false;
      return;
    }
    // A discontinuity (swap / death-swap / teleport) is bigger than any single
    // frame of walking — pan to it; otherwise track tightly (no follow lag).
    final jumped =
        activeIndex != _camActiveIndex || (_camFocus! - target).distance > 90;
    _camActiveIndex = activeIndex;
    if (jumped) _camPanning = true;
    if (_camPanning) {
      _camFocus = Offset.lerp(_camFocus!, target, 1 - exp(-dt / 0.12))!;
      if ((_camFocus! - target).distance < 2) {
        _camFocus = target;
        _camPanning = false;
      }
    } else {
      _camFocus = target;
    }
  }

  /// Revive any downed creature whose timer has elapsed, back beside the party.
  void _updateRespawns(double dt) {
    if (isRaid) return; // a raid down is permanent
    for (final c in creatures) {
      if (c.alive || c.respawnTimer <= 0) continue;
      c.respawnTimer -= dt;
      if (c.respawnTimer <= 0) _reviveCreature(c);
    }
  }

  void _reviveCreature(DungeonCreature c) {
    c.respawnTimer = 0;
    c.downHandled = false;
    c.hp = c.maxHp;
    // Rejoin in the CURRENT room beside a living ally (their footing is safe).
    final ally = creatures.firstWhere(
      (o) => o.alive && !identical(o, c),
      orElse: () => c,
    );
    final spot = identical(ally, c) ? currentRoom.bounds.center : ally.position;
    c.position = spot;
    c.lastSafe = spot;
    _spawnAlchemyBurst(
      spot,
      producedElement: c.member.element,
      particleCount: 20,
      intensity: 0.9,
    );
    _setHint('${c.member.element} ${c.member.family} revives');
    onChanged();
  }

  // ── Earth (Buried Giant) run-state ──

  /// Settled notch per fossil rib (id → index; 0 = its starting notch).
  final Map<String, int> ribNotches = {};

  /// Live rib slides (track-notch shoves are ANIMATED grinds, never snaps).
  final Map<String, _RibSlide> _ribSlides = {};

  /// Crystal-locked pillar sockets (Star 2).
  final Set<String> lockedPillars = {};

  /// Per-pillar crystal-growth animation (id → 0..1): the lock shards GROW
  /// out of the socket over ~0.6s instead of popping in.
  final Map<String, double> _crystalGrow = {};

  /// Sockets mid-charge (Star 2): a socket draws the storm over a charge
  /// window — the consequence enemies spawn AT ONCE, so the player defends the
  /// charge until it completes and the crystal lights. id → elapsed seconds,
  /// and id → total charge duration (element-only: every Lightning is equal).
  final Map<String, double> _pillarCharge = {};
  final Map<String, double> _pillarChargeDur = {};

  /// Gaze-prism build animation: the stone core rises (0..1) then the crystal
  /// grows out of it (0..1), rather than each stage snapping into being.
  double _prismCoreRise = 0;
  double _prismGrow = 0;

  /// Stone-scale state (Star 3): weight id → sits on the RIGHT pan.
  final Map<String, bool> scalePanRight = {};
  int scaleToggles = 0;
  double _scaleTruthFlash = 0; // insight's glow on the true pans
  double _scaleTiltShown = 0; // the beam eases toward its loaded tilt

  /// The giant's eye pupil offset from the eye centre. While BLIND it tracks
  /// the active creature (the giant watches you); once the prism stands it
  /// locks onto the lens. Eased so the gaze glides rather than snaps.
  Offset _eyeLook = Offset.zero;

  /// The gaze prism in the eye's sightline: 0 bare plinth · 1 stone core
  /// raised (Earth) · 2 the crystal prism stands (Lightning's arc, or
  /// Crystal direct). The eye is BLIND — gives no readings — until it
  /// stands, and then only speaks when communed with at the prism.
  int prismStage = 0;

  /// The scale's PER-RUN solution (weight id → true pan is RIGHT): the eye
  /// remembers differently each burial, so deduction stays a puzzle forever
  /// (a wiki can never spoil it). Always mixed — both pans used.
  final Map<String, bool> scaleSolution = {};

  /// The eye's LAST spoken judgment ("n stones sit true"), shown in the
  /// progress readout. A SNAPSHOT, not a live count — the eye judges only
  /// when communed with at its prism, so moving stones stales the number
  /// rather than betraying the answer move by move.
  int? _scaleJudged;

  void _rollScaleSolution() {
    for (final room in layout.rooms.values) {
      final scale = room.stoneScale;
      if (scale == null) continue;
      final rng = Random();
      do {
        for (final w in scale.weights) {
          scaleSolution[w.id] = rng.nextBool();
        }
      } while (scaleSolution.values.toSet().length < 2);
      return;
    }
  }

  bool get _isBarrow => layout.element == 'Earth';

  // ── Lightning (Storm Circuit) run-state ──
  /// Source node id → seconds of charge left. A Lightning Horn channel sets a
  /// full window; the charge DECAYS (the persistence-grammar tension). Latching
  /// sources (storm-cell sockets) are parked at a huge value and never decay.
  final Map<String, double> circuitCharge = {};

  /// Source node id → its initial charge window (drives the drain-timer arc).
  final Map<String, double> _circuitChargeMax = {};

  /// Mirror node id → current orientation index (rotated on action, persists).
  final Map<String, int> mirrorOrient = {};

  /// Nodes the BFS found powered this frame (re-derived; never serialized).
  final Set<String> _poweredNodes = {};

  /// Read-only view of the live circuit nodes (for tests/diagnostics).
  Set<String> get poweredNodes => _poweredNodes;

  /// CellSocket ids fully energized this run (Star 2).
  final Set<String> energizedSockets = {};

  /// Anvil sockets that hold a cell but await a Fire creature's heat (Star 2).
  final Set<String> _anvilCellWaiting = {};

  /// The Thunderbolt egg's permanent over-charged glow once won.
  double _thunderboltGlow = 0;

  /// Storm-Spire beam puzzle: latched true once the lightning beam crowns the
  /// tower (the gate to the core then stays open for the run); a small clock
  /// that paces the conversion-arc sparks.
  bool _beamLatched = false;
  double _beamSparkT = 0;

  /// ZERO-SUM DYNAMO (rework §9.1): the trunk the dynamo currently feeds
  /// (null = grounded — every trunk dark). Selected at the hub breakers;
  /// Raikuma seizes it while feeding.
  String? activeTrunk;

  /// Eased per-room darkness (0 lit … 1 dark) for the zero-sum trunk wings.
  final Map<String, double> _trunkDark = {};

  /// The vault bolt's eased openness (0 shut … 1 fallen open in the dark).
  double _vaultBoltOpen = 0;

  /// Eased dynamo re-route swing (0 just thrown … 1 settled).
  double _dynamoSwing = 1.0;

  /// Fulminate vats: vat id → seconds the live bolt has been cooking it.
  final Map<String, double> _vatFuse = {};

  /// Dark dead segments: spark-wisp prowl clock + last-room edge detector.
  double _darkWispTimer = 0;
  String? _circuitPrevRoomId;

  /// Raikuma feeds on the powered core trunk (no lull while feeding); the
  /// grounding spike cuts the trunk and opens a timed vulnerability window.
  bool _raikumaFed = false;
  double _raikumaLullLeft = 0;

  bool get _isCircuit => layout.element == 'Lightning';

  // ── Steam (the Molten Labyrinth) run-state ──
  /// Mutable cell grid per room (roomId → rows of codes: 0 open · 1 wall ·
  /// 2 bedrock · 3 lava). Re-derived from the authored grid on reset; the trio
  /// melts/cools/dams it and the lava creeps each beat.
  final Map<String, List<List<int>>> moltenCells = {};

  /// Seconds until the next lava-creep beat.
  double moltenBeat = _kMoltenBeat;

  /// Rooms whose flood has WOKEN — the molten sleeps until Fire first breaks
  /// rock in that room; only woken rooms creep on the beat.
  final Set<String> wokeRooms = {};

  // ── Fire Star 2: THE BURN ──
  /// The live field per room, built from the authored garth on first entry.
  final Map<String, BurnField> burnFields = {};

  /// Seconds until the flame takes its next cell.
  double burnBeat = 0;

  /// Eased 0→1 fill of the ember pool, so it rises rather than stepping.
  double poolShown = 0;

  /// Flash when the flame just ate a cell (render only).
  double burnFlash = 0;

  // ── Steam Star 1: the geyser field ──
  /// Ids of mouths the party is holding shut with a body or the rock, plus the
  /// authored rubble. Recomputed every frame from the world, never stored as
  /// an intention — so stepping off a mouth releases it at once.
  final Set<String> cappedGeysers = {};

  /// Seconds into the field's shared eruption cycle.
  double geyserCycle = 0;

  /// The one rock an Earth hand can hold in the world at a time (null = none).
  Offset? earthRock;

  /// Eased 0→1 as the rock heaves up out of the floor; the shove only answers
  /// once it has fully risen.
  double earthRockRaise = 0;

  /// True once the capstone has burst (the star follows).
  bool capstoneBurst = false;

  /// Fire-blood too fresh to quench (roomId → cell indices), cleared on the
  /// next creep beat.
  ///
  /// THE POINT OF THE WHOLE PLANET (2026-08-14, playtest): "it's fire turn
  /// wall to lava, steam quickly puts it out, walk through." Melt and quench
  /// cancelled each other, so two presses turned a wall into floor and the
  /// creep the room is built on NEVER HAPPENED. A breach now RUNS: for its
  /// first beat the molten is too hot to take the breath, so breaking rock is
  /// a commitment you have to have prepared for — wall off where it will go,
  /// stand clear, and quench only once it has spent itself. (An earlier pass
  /// had this exactly backwards: it GUARANTEED a free beat to cork your own
  /// breach, which optimised the cancel instead of removing it.)
  final Map<String, Set<int>> freshLava = {};

  /// Steam's cooling-breath charges (max [kSteamBreathMax]); one is spent per
  /// cooled cell and one returns with each creep beat — so a wide flood can't
  /// be out-cooled, only dammed.
  int steamBreath = kSteamBreathMax;

  /// Times any creature's footing was swallowed by lava this run (scalds).
  /// Ending the rite with zero scalds earns the Hidden Harmony egg.
  int moltenScalds = 0;

  /// Set once the engine-room rite grid's pedestal is reached (wakes Boilrog).
  bool moltenRiteDone = false;

  /// A free-running clock for molten ember/pedestal pulses.
  double _moltenPulse = 0;

  /// The ring-main's boiler pressure head (Steam): the run's ONE budget.
  /// Junction seals spend it, cooling condenses some back, Fire stokes it,
  /// and the burst-disc vault demands most of it dumped at once.
  int boilerPressure = kSteamStartPressure;

  /// Paid junction seals, keyed by sorted room-pair ('a|b'). Per-run — a
  /// death re-clamps the ring (puzzle state, like every other rite).
  final Set<String> unclampedSeals = {};

  /// Whether the burst-disc has been blown this run (vault passage open).
  bool burstDiscBlown = false;

  bool get _isVapor => layout.element == 'Steam';

  // ── Mud (the Sinking Altar) run-state ──
  /// The whole fen run — the pure terraforming rules plus its live timers.
  /// One field, because everything this planet tracks lives inside it (see
  /// planet_dungeon_game_mud.dart).
  final SinkingFen bog = SinkingFen();

  // ── Lava (Molten Reliquary) run-state ──
  /// The whole foundry run — the line's pure rules plus its live timers. One
  /// field, because everything this planet tracks lives inside it (see
  /// planet_dungeon_game_lava.dart).
  final MoltenWorks works = MoltenWorks();

  // ── Poison (Venom Monastery) run-state ──
  /// The whole quarantine run — the triage rules plus the live strains. One
  /// field, because everything this planet tracks lives inside it (see
  /// planet_dungeon_game_poison.dart).
  final VenomMonastery monastery = VenomMonastery();
  bool get _isVenom => layout.element == 'Poison';
  // ── Ice · the Rime Shaft (planet_dungeon_game_ice.dart) ──
  // Per-run puzzle state. Extensions cannot carry fields, so — as with every
  // other planet — Ice's live state sits here behind the `_isShaft` guard.
  /// Every flue's drift/stair/scoured state, keyed by RimeFlue.id.
  final Map<String, RimeFlueState> flueState = {};

  /// Whether the sump's melt-fall stands as the climb home.
  bool rimefallFrozen = false;

  /// How many times THE THAW has run (the rimefall's price, and a readout).
  int shaftThaws = 0;

  /// Frames currently showing the chart, and each one's remaining hold.
  final Set<int> silveredMirrors = {};
  final Map<int, double> mirrorThaw = {};
  bool lodestoneLit = false;
  double mirrorSweep = 0; // Air-sweep cooldown

  /// The orrery: glazed cells, block positions and seated blocks, all as
  /// `row * cols + col` indices into the authored grid.
  final Set<int> orreryGlass = {};
  final Map<int, int> orreryBlocks = {};
  final Set<int> orrerySeated = {};

  /// Frowyrm's pillar, and the beat-edge its shatter is detected on.
  bool hoarfrostWhole = false;
  double _hoarfrostDown = 0;
  bool _frowyrmBitLastFrame = false;

  bool get _isShaft => layout.element == 'Ice';

  // ── Dust · the Ruins of Time (planet_dungeon_game_dust.dart) ──
  /// The whole buried city — the conservation ledger plus the live run state.
  /// ONE field, because [RuinsOfTime] is the only thing on this planet allowed
  /// to write a dust load (see planet_dungeon_layout_dust.dart).
  final RuinsOfTime ruins = RuinsOfTime();

  /// Seconds Ashdjinn's freshly filled cut stays unworkable, and the beat-edge
  /// its storm is detected on.
  double _hollowSettle = 0;
  bool _ashdjinnBitLastFrame = false;

  bool get _isRuins => layout.element == 'Dust';

  // ── Crystal · the Prism Labyrinth (planet_dungeon_game_crystal.dart) ──
  /// The whole sliding keep — the pure permutation rules plus the live slide
  /// and choir state. ONE field, because everything this planet tracks lives
  /// inside it (see planet_dungeon_layout_crystal.dart).
  final PrismLabyrinth prism = PrismLabyrinth();

  bool get _isKeep => layout.element == 'Crystal';

  // ── Spirit · the Echo Grave (planet_dungeon_game_spirit.dart) ──
  /// The whole grave-field — the pure two-world rules plus the live re-ink and
  /// Wraithord's phase. ONE field, because everything this planet tracks lives
  /// inside it (see planet_dungeon_layout_spirit.dart).
  final EchoGrave3D wake = EchoGrave3D();

  bool get _isWake => layout.element == 'Spirit';
  // ── Plant · the Verdant Crypt (planet_dungeon_game_plant.dart) ──
  /// The whole crypt: what size the party is walking in, and what every seed
  /// bed holds. ONE field, because on this planet those two things are the
  /// entire reachability question (see planet_dungeon_layout_plant.dart).
  final VerdantCrypt crypt = VerdantCrypt();

  /// The beat-edge Botanica's spore burst is detected on.
  bool _botanicaBitLastFrame = false;

  bool get _isCrypt => layout.element == 'Plant';

  // ── Dark · the Eclipse Vault (planet_dungeon_game_dark.dart) ──
  /// The whole vault: where each gnomon's shadow lies, and what that has
  /// opened. ONE field, because on this planet the shadow's position IS the
  /// map (see planet_dungeon_layout_dark.dart).
  final EclipseVault vault = EclipseVault();

  /// The beat-edge Noctryos throws the Deep's shadow on.
  bool _noctryosBitLastFrame = false;

  bool get _isVault => layout.element == 'Dark';

  // ── Light · the Beacon Archive (planet_dungeon_game_light.dart) ──
  /// The whole archive: what each rim beacon is set to, and what that has lit.
  /// ONE field, because on this planet the light IS the floor (see
  /// planet_dungeon_layout_light.dart).
  final BeaconArchive archive = BeaconArchive();

  bool get _isArchive => layout.element == 'Light';
  // ── Blood · the Sanguine Orrery (planet_dungeon_game_blood.dart) ──
  /// The whole orrery: where the beat is, and what that has opened. ONE
  /// field, because on this planet the CLOCK is the map — and it is the first
  /// planet in the set whose state the player cannot author at all (see
  /// planet_dungeon_layout_blood.dart).
  final SanguineHeart heart = SanguineHeart();

  /// The strike-beat edge Sanguorath throws the pulse forward on.
  bool _sanguorathBitLastFrame = false;

  bool get _isHeart => layout.element == 'Blood';

  final Map<String, double> conduitEnergy = {}; // conduitId -> seconds left
  /// Initial hold per conduit — drives the visible drain-timer arc.
  final Map<String, double> _conduitMaxEnergy = {};
  final List<_DoorRevealFx> _doorRevealFx = [];
  bool altarOpen = false;
  bool guardianAwake = false;
  bool guardianVulnerable = false;
  double _guardianCycle = 0;
  static const double maxGuardianHp = 4;
  double guardianHp = maxGuardianHp;
  double guardianHitFlash = 0;
  CosmicSurvivalEnemy? _guardianEnemy;

  /// THE ARRIVAL: a mystic does not blink into being on its perch. Entering
  /// its roused chamber drops the room into a short cinematic — the ground
  /// shakes, the thing falls out of the ceiling/sky, and only on IMPACT does
  /// the combat body exist. Nothing can be hit (either way) before then, so
  /// the fight always starts from a clean, readable beat.
  static const double kGuardianArrivalSeconds = 1.9;

  /// Seconds into the arrival, or -1 when no arrival is staged/playing.
  double _guardianArrival = -1;

  /// Whether the arrival cinematic owns the room right now.
  bool get guardianArriving =>
      _guardianArrival >= 0 && _guardianArrival < kGuardianArrivalSeconds;

  /// Camera shake, in pixels of amplitude. Decays every frame; the arrival
  /// (and its impact) is the only thing that drives it today.
  double _shake = 0;
  double get shakeAmplitude => _shake;

  /// Mid-fight escalation: fired once at half HP (screech, feather-wisps,
  /// shorter lull windows).
  bool _rocEnraged = false;

  /// The planet guardian renders with its real Mystic sprite (per mysticId);
  /// the procedural body stays as fallback when no sheet is authored/loaded.
  static final Map<String, SpriteSheetDef> _guardianSheets = {
    'Roc': SpriteSheetDef(
      path: 'creatures/mystic/MYS04_airmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS01 sheet verified 3072×512 — 6 frames of 512×512, one row.
    'Simurgh': SpriteSheetDef(
      path: 'creatures/mystic/MYS01_firemystic_spritesheet.png',
      totalFrames: 6,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS02 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Leviathan': SpriteSheetDef(
      path: 'creatures/mystic/MYS02_watermystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS03 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Terradon': SpriteSheetDef(
      path: 'creatures/mystic/MYS03_earthmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS06 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Magmara': SpriteSheetDef(
      path: 'creatures/mystic/MYS06_lavamystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS13 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Blightfang': SpriteSheetDef(
      path: 'creatures/mystic/MYS13_poisonmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS11 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Prismalith': SpriteSheetDef(
      path: 'creatures/mystic/MYS11_crystalmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS07 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Raikuma': SpriteSheetDef(
      path: 'creatures/mystic/MYS07_lightningmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS05 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Boilrog': SpriteSheetDef(
      path: 'creatures/mystic/MYS05_steammystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS09 sheet verified 2048x512 — 4 frames of 512x512, one row.
    'Frowyrm': SpriteSheetDef(
      path: 'creatures/mystic/MYS09_icemystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS14 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Wraithord': SpriteSheetDef(
      path: 'creatures/mystic/MYS14_spiritmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS16 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Solarin': SpriteSheetDef(
      path: 'creatures/mystic/MYS16_lightmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS08 sheet verified 2048×512 — 4 frames of 512×512, one row.
    'Bogdrya': SpriteSheetDef(
      path: 'creatures/mystic/MYS08_mudmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
    // MYS17 sheet verified 2048x512 — 4 frames of 512x512, one row.
    'Sanguorath': SpriteSheetDef(
      path: 'creatures/mystic/MYS17_bloodmystic_spritesheet.png',
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
    ),
  };

  /// Half-HP escalation copy, per mystic.
  static const Map<String, String> _guardianEnrageHints = {
    'Roc': 'The Roc screeches — the storm tightens!',
    'Simurgh': 'The Simurgh shrieks — its flame burns black!',
    'Leviathan': 'The Leviathan coils — the deep crushes inward!',
    'Terradon': 'Terradon heaves — the whole barrow shudders!',
    'Raikuma': 'Raikuma roars — the whole circuit overloads white!',
    'Boilrog': 'Boilrog bellows — the pressure spikes to a scream!',
    'Frowyrm': 'Frowyrm keens — the whole shaft cracks and runs!',
    'Bogdrya': 'Bogdrya swallows — the whole fen shudders and drops!',
    'Wraithord':
        'Wraithord thins — it is barely in either world now, and faster!',
    'Solarin': 'Solarin opens — it is looking at all of you at once now!',
    'Sanguorath': 'Sanguorath races — the whole orrery beats double!',
  };
  SpriteAnimationTicker? _guardianTicker;
  double _guardianSpriteScale = 1.0;

  /// The planet's relic artwork (`assets/images/relics/<el>relic.png`) for
  /// the victory drop; null = procedural star-glyph fallback.
  ui.Image? _relicImage;
  _RelicDropFx? _relicFx;
  bool get relicDropActive => _relicFx != null;

  // ── Hint capsule (§5.6) ─────────────────────────────────
  // One line, one channel, resolved by priority. See [DungeonHintChannel].

  String? hintText;
  double _hintTtl = 0;

  /// The channel the live capsule line is speaking in — the render side
  /// styles by this so a refusal never looks like flavor.
  DungeonHintChannel hintChannel = DungeonHintChannel.objective;

  /// Set while a scoped emitter owns the capsule (see [_inHintChannel]) so
  /// every `_setHint` inside a Mask reading is tagged insight without having
  /// to touch each per-planet reveal delegate.
  DungeonHintChannel? _hintChannelOverride;

  /// Attempt-edge memory for the BLOCKED channel: object key → the exact
  /// refusal already spoken for it. A refusal repeats only when the player
  /// leaves (key released) or the state changes (different refusal text).
  final Map<String, String> _blockedSpoken = {};

  double _ambientHintCooldown = 0;
  double _statHintCooldown = 0;
  double _loomRejectCooldown = 0;
  double _cloudPickupCooldown = 0; // brief grace after a drop (no re-grab)
  double _guardianStrikeCooldown = 0; // lull strikes are paced, not spammable
  bool _altarBlessingUsed = false; // the storm altar mends the party once
  bool _fallRecovering = false;
  Offset _fallStart = Offset.zero;
  Offset _fallTarget = Offset.zero;
  double _fallTimer = 0;
  double _fallDuration = 0.9;
  double revealFlash = 0; // visual pulse for the reveal verb
  int revealTier = 0; // hint detail from the last reveal (0/1/2)
  final Set<String> placedClouds = {}; // cloud ids deposited onto anchors

  // ── Atmospheric FX ──
  /// Smoothed sky mood (0 storm-dark … 1 dawn-bright, 0.5 baseline).
  double _skyMood = 0.5;
  final DungeonFxAssets _fx = DungeonFxAssets();
  final DungeonSky _sky = DungeonSky();
  late final AmbientWind _ambient = AmbientWind(
    palette: _isCathedral
        ? const [
            Color(0xFFFFB46B), // ember
            Color(0xFFE4C16A), // candle amber
            Color(0xFF8A5A48), // drifting ash
          ]
        : _isTemple
        ? const [
            Color(0xFF8FE0EC), // pearl shimmer
            Color(0xFF4A8AB8), // deep current
            Color(0xFFE4C16A), // sunken gold
          ]
        : _isBarrow
        ? const [
            Color(0xFFD8B878), // bone dust
            Color(0xFF8A6E48), // old earth
            Color(0xFFB8E0D8), // crystal glint
          ]
        : _isCircuit
        ? const [
            Color(0xFFBFE6FF), // arc-white spark
            Color(0xFF6BA8FF), // charged blue
            Color(0xFFE9D27A), // brass conductor
          ]
        : _isFoundry
        ? const [
            Color(0xFFFFF1CF), // white-hot metal
            Color(0xFF39424C), // cold iron
            Color(0xFF6C7A68), // slag
          ]
        : _isVenom
        ? const [
            Color(0xFF8FD14F), // live spore
            Color(0xFFB86FE0), // fed strain
            Color(0xFFD8CBA8), // old linen
          ]
        : _isVapor
        ? const [
            Color(0xFFCFE0E6), // steam white
            Color(0xFF8FA6B0), // iron grey
            Color(0xFFFFB46B), // furnace ember
          ]
        : null,
  );
  final List<Offset> _glideTrail = [];
  final List<Offset> _carryTrail = []; // wind wake behind a carried echo
  final Map<String, _IslandGeometry> _islandCache = {};
  final Random _combatRng = Random(0xA17);

  static const double _speed = 150.0;
  static const double _flightSpeedMul = 1.35;
  static const double _radius = 16.0;
  static const double _hazardDps = 60.0;
  static const double _guardianHazardDps = 28.0;

  DungeonRoom get currentRoom => layout.rooms[currentRoomId]!;
  DungeonCreature? get active => (creatures.isEmpty)
      ? null
      : creatures[activeIndex.clamp(0, creatures.length - 1)];
  CosmicSurvivalCompanion? get activeCombat => (combatCompanions.isEmpty)
      ? null
      : combatCompanions[activeIndex.clamp(0, combatCompanions.length - 1)];

  int get totalStars => layout.totalStars;
  int get starsEarnedCount => _earnedStars.length;
  bool hasStar(int i) => (starMask & (1 << i)) != 0;

  /// AUTHORING RULE: Star 3 is always the mystic guardian, and its rite only
  /// opens once the first two stars (any order) are banked. Raids skip it —
  /// their guardian is already rampaging — and a banked Star 3 keeps it open
  /// (saves from before this rule could beat the guardian early).
  bool get guardianRiteUnlocked =>
      isRaid || hasStar(2) || (hasStar(0) && hasStar(1));
  bool get hasCombatTargets => combatEnemies.any((e) => !e.isDead);
  double get autoCooldownFraction {
    final c = activeCombat;
    if (c == null) return 0;
    final total = max(0.001, c.effectiveBasicCooldown);
    return (c.basicCooldown / total).clamp(0.0, 1.0).toDouble();
  }

  double get abilityCooldownFraction {
    final c = activeCombat;
    if (c == null) return 0;
    final total = max(0.001, c.effectiveSpecialCooldown);
    return (c.specialCooldown / total).clamp(0.0, 1.0).toDouble();
  }

  String get abilityCooldownLabel {
    final c = activeCombat;
    if (c == null || c.specialCooldown <= 0.05) return 'ABILITY';
    return '${c.specialCooldown.ceil()}s';
  }

  String get autoCooldownLabel {
    final c = activeCombat;
    if (c == null || c.basicCooldown <= 0.05) return 'ATTACK';
    return '${c.basicCooldown.ceil()}s';
  }

  // ── Control feedback (§5.6: state lives on the control) ──
  // A refused press pulses its own button instead of writing prose into the
  // hint capsule. Both decay in [update].

  static const double _deniedFlashSeconds = 0.36;

  /// Seconds remaining on the auto-attack button's "refused" pulse.
  double autoDeniedFlash = 0;

  /// Seconds remaining on the special button's "refused" pulse.
  double abilityDeniedFlash = 0;

  double get autoDeniedPulse =>
      (autoDeniedFlash / _deniedFlashSeconds).clamp(0.0, 1.0);

  double get abilityDeniedPulse =>
      (abilityDeniedFlash / _deniedFlashSeconds).clamp(0.0, 1.0);

  /// True when the active specimen's special has no manual cast at all — the
  /// button says so permanently instead of a hint line saying it on each tap.
  bool get abilityIsPassive {
    final c = activeCombat;
    if (c == null) return false;
    return isPassiveOnlyCosmicAbility(c.member.family, c.member.element);
  }

  /// The auto-attack control is live only when something can actually fire.
  bool get autoAttackReady {
    final c = activeCombat;
    final a = active;
    return c != null && a != null && a.alive && c.basicCooldown <= 0;
  }

  /// The special control is live only when it is castable right now.
  bool get abilityReady {
    final c = activeCombat;
    if (c == null || abilityIsPassive) return false;
    return c.specialCooldown <= 0;
  }

  /// PROGRESS READOUT (§5.6) — the persistent, glanceable counter shown
  /// beside the star tracker, or null when this planet/room has nothing to
  /// count. Progress is state the player checks at will, never a fading line.
  ///
  /// Air's spire ascent is the reference implementation; Fire's braziers,
  /// Earth's judged stones, Air's loom anchors and Lightning's circuit
  /// counters follow it. The canvas gauges (Steam's pressure head, Water's
  /// tide stand) already render as their own HUDs and stay there.
  DungeonProgressReadout? get progressReadout {
    if (_isCathedral) return _cathedralProgressReadout;
    if (_isFoundry) return _foundryProgressReadout;
    if (_isVenom) return _monasteryProgressReadout;
    if (_isBarrow) return _barrowProgressReadout;
    // Lightning: terminal/socket counters + the dynamo's trunk state.
    if (_isCircuit) return _circuitProgressReadout();
    // Water: the sluice tally and the wade, out of the capsule at last. The
    // tide gauge is a canvas HUD of its own and stays there.
    if (_isTemple) return _templeProgressReadout();
    // Air: WINDS (the RINGS counter's replacement — the ring sequence retired
    // with the §9.1 rework), then the loom's anchors, then the conduits.
    if (_isSpire) return _spireProgressReadout();
    if (_isShaft) return _shaftProgressReadout();
    if (_isBog) return _bogProgressReadout();
    if (_isRuins) return _ruinsProgressReadout();
    if (_isKeep) return _keepProgressReadout();
    if (_isWake) return _graveProgressReadout();
    if (_isCrypt) return _cryptProgressReadout();
    if (_isVault) return _vaultProgressReadout();
    if (_isArchive) return _archiveProgressReadout();
    if (_isHeart) return _heartProgressReadout();
    return null;
  }

  /// The single star a room awards (spire/loom/altar/ritual/garden), or null
  /// for connective rooms.
  int? _roomStarIndex(DungeonRoom room) =>
      room.summit?.starIndex ??
      room.loomStarIndex ??
      room.brazierStarIndex ??
      room.vineStarIndex ??
      room.sealStarIndex ??
      room.canalStarIndex ??
      room.ribStarIndex ??
      room.pillarStarIndex ??
      room.circuitStarIndex ??
      room.molten?.starIndex ??
      room.foundryStar?.starIndex ??
      room.guardian?.starIndex;

  /// True once this room's star is earned — its objectives/obstacles are then
  /// hidden and inert (nothing here is shared between Air's stars).
  bool _roomCleared(DungeonRoom room) {
    final i = _roomStarIndex(room);
    return i != null && hasStar(i);
  }

  DungeonAbility get activeAbility => active?.ability ?? DungeonAbility.none;

  /// The utility button is enabled whenever there's an active creature — what it
  /// does is context-driven (element-based interactions don't need a family).
  bool get canAct => active != null && _raidDeath == null;

  /// The utility button is intentionally non-spoilery: the world response, not
  /// the label, teaches which specimen qualities and elements matter.
  String actionLabel() => 'UTILITY';

  double get flightFraction =>
      flightMax <= 0 ? 0 : (flightMeter / flightMax).clamp(0.0, 1.0);

  /// Energize a conduit. §9.1 REWORK: conduits LATCH. The decay timers are
  /// retired, and with them the whole race that made the altar a test of
  /// tempo rather than of understanding.
  void _energizeConduit(String id) {
    if (!guardianRiteUnlocked) {
      // A refused offering — the attempt is the edge (§5.6 BLOCKED).
      _setBlockedHint(
        'The pylon refuses the offering — it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return;
    }
    conduitEnergy[id] = double.infinity;
    _conduitMaxEnergy[id] = double.infinity;
  }

  void _queueDoorReveal(String roomId, String targetRoomId) {
    final room = layout.rooms[roomId];
    if (room == null) return;
    for (final d in room.doors) {
      if (d.targetRoomId == targetRoomId) {
        _doorRevealFx.add(
          _DoorRevealFx(roomId: roomId, position: d.rect.center),
        );
      }
    }
  }

  /// Legacy entry point — kept so the existing call sites keep working. An
  /// untagged line speaks on OBJECTIVE (world-response speech), unless a
  /// scope is active (see [_inHintChannel]), which is how Mask readings get
  /// their channel without editing every per-planet delegate.
  void _setHint(String msg, [double ttl = 2.4]) =>
      _emitHint(msg, _hintChannelOverride ?? DungeonHintChannel.objective, ttl);

  /// True only while [askForRoomHint] is running — the one moment the dungeon
  /// is allowed to speak.
  bool _hintAsked = false;

  /// The last EARNED line the world produced, kept but NOT shown.
  ///
  /// Two kinds of line survive being unasked-for, because both carry something
  /// a picture cannot:
  ///
  ///  • a REFUSAL — a shake tells you nothing happened, not WHICH of "too far"
  ///    / "wrong element" / "wrong family" / "not yet" it was;
  ///  • a READING — some verbs (Water's canal reveal, a Mask's old insight)
  ///    have information as their entire payload, and dropping the line would
  ///    make the verb do nothing at all.
  ///
  /// Narration and flavour are dropped outright; these are held and handed
  /// over the moment the player asks, which is exactly when they want them.
  String? _pendingAnswer;
  DungeonHintChannel _pendingChannel = DungeonHintChannel.blocked;

  /// Whether something is waiting to be asked about — drives the HINT
  /// button's pulse, so the affordance advertises itself at the moment it has
  /// something worth saying.
  bool get hintHasAnswer => _pendingAnswer != null;

  /// Set on a refusal so the world can flash at the point of contact. The
  /// renderer eases this to zero; nothing about it is text.
  double refusalFlash = 0;

  /// THE RESOLVER — and the whole speech policy (direction change).
  ///
  /// THE DUNGEON DOES NOT NARRATE. Text used to answer almost every tap: 382
  /// untagged world-response lines, 83 ambient flavour lines, a reading on
  /// every Mask press. Feedback that constant teaches the player to stop
  /// reading the capsule, which costs exactly the moments that matter. The
  /// animation and the world state are the feedback now; the capsule speaks
  /// only when the player presses HINT.
  ///
  /// Priority still decides between lines within an asked-for reading, so a
  /// refusal cannot be stomped by a lower channel mid-read.
  bool _emitHint(String msg, DungeonHintChannel channel, [double ttl = 2.4]) {
    if (!_hintAsked) {
      // Unasked. A refusal or a reading is REMEMBERED; narration and flavour
      // are dropped. A refusal also flashes at the creature, because being
      // turned away needs to be legible in the instant it happens.
      if (channel == DungeonHintChannel.blocked ||
          channel == DungeonHintChannel.insight) {
        _pendingAnswer = msg;
        _pendingChannel = channel;
        if (channel == DungeonHintChannel.blocked) refusalFlash = 1.0;
        // True so callers that treat "I answered them" as having consumed the
        // action keep working — it happened, it just did not speak.
        return true;
      }
      return false;
    }
    final live = hintText != null && _hintTtl > 0;
    if (live && channel.priority < hintChannel.priority) return false;
    hintText = msg;
    hintChannel = channel;
    _hintTtl = ttl;
    return true;
  }

  /// Room-entry goal line — WHAT, never HOW.
  void _setObjectiveHint(String msg, [double ttl = 4.5]) =>
      _emitHint(msg, DungeonHintChannel.objective, ttl);

  /// Run [body] with every hint it emits tagged [channel]. Used to make the
  /// whole Mask-insight call tree (`_doReveal` + the five per-planet
  /// `_*Reveal` delegates) speak on the protected insight channel.
  T _inHintChannel<T>(DungeonHintChannel channel, T Function() body) {
    final prev = _hintChannelOverride;
    _hintChannelOverride = channel;
    try {
      return body();
    } finally {
      _hintChannelOverride = prev;
    }
  }

  /// A refused attempt that is inherently edge-triggered (a button press, a
  /// one-shot interaction) — the input already happened once, so it speaks.
  bool _setBlockedHint(String msg, [double ttl = 3.0]) =>
      _emitHint(msg, DungeonHintChannel.blocked, ttl);

  /// A refused attempt driven by a CONTINUOUS condition (standing against a
  /// sealed door, overlapping a gate every frame). [key] identifies the
  /// object; the refusal text carries its state. It speaks once and then stays
  /// quiet until [_releaseBlockedExcept] drops the key (the player left) or the
  /// object hands it a different refusal (the state changed).
  bool _setBlockedHintOnce(String key, String msg, [double ttl = 3.0]) {
    if (_blockedSpoken[key] == msg) return false;
    _blockedSpoken[key] = msg;
    return _emitHint(msg, DungeonHintChannel.blocked, ttl);
  }

  /// Forget every attempt-edge in a family except the ones still live this
  /// frame — the generic "player left the object" reset.
  void _releaseBlockedExcept(String prefix, Set<String> keep) {
    _blockedSpoken.removeWhere(
      (k, _) => k.startsWith(prefix) && !keep.contains(k),
    );
  }

  /// Mask insight output, priority-protected against ambient/objective chatter.
  bool _setInsightHint(String msg, [double ttl = 3.6]) =>
      _emitHint(msg, DungeonHintChannel.insight, ttl);

  /// Wipe the capsule and all attempt memory (room reset, party wipe, debug).
  void _clearHints() {
    hintText = null;
    _hintTtl = 0;
    hintChannel = DungeonHintChannel.objective;
    _blockedSpoken.clear();
  }

  // ── Lifecycle ───────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await _fx.load();
    await _sky.load(element);
    starMask = initialStarMask & 0x7;
    for (var i = 0; i < 3; i++) {
      if ((starMask & (1 << i)) != 0) _earnedStars.add(i);
    }
    entryDoorRevealed = discoveredClouds.contains(entryDoorDiscoveryId);
    _entryReveal = entryDoorRevealed ? 1.0 : 0.0;
    _entryRevealPrev = _entryReveal;
    currentRoomId = layout.entranceRoomId;

    for (final m in party) {
      final c = DungeonCreature(member: m);
      await _loadSprite(c);
      creatures.add(c);
      combatCompanions.add(_createCombatCompanion(m, Offset.zero));
    }
    // Load the planet guardian's Mystic sprite (fallback: procedural body).
    for (final room in layout.rooms.values) {
      final mysticId = room.guardian?.encounter?.mysticId;
      final sheet = mysticId == null ? null : _guardianSheets[mysticId];
      if (sheet == null) continue;
      try {
        final image = await images.load(sheet.path);
        final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
        final anim = SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.sequenced(
            amount: sheet.totalFrames,
            amountPerRow: cols,
            textureSize: sheet.frameSize,
            stepTime: sheet.stepTime,
            loop: true,
          ),
        );
        _guardianTicker = anim.createTicker();
        const desired = 132.0; // wingspan presence worthy of a finale
        _guardianSpriteScale =
            desired / max(sheet.frameSize.x, sheet.frameSize.y);
      } catch (_) {
        _guardianTicker = null; // missing asset → procedural fallback
      }
      break;
    }
    // The guardian relic's artwork for the victory drop (optional asset).
    try {
      _relicImage = await images.load(
        'relics/${layout.element.toLowerCase()}relic.png',
      );
    } catch (_) {
      _relicImage = null; // missing art → procedural star-glyph fallback
    }
    _placeAtEntrance();
    _setHint(
      ' · '
      'three Alchemons enter, three stars to collect',
      5.5,
    );
  }

  Future<void> _loadSprite(DungeonCreature c) async {
    final sheet = c.member.spriteSheet;
    if (sheet == null) return;
    final image = await images.load(sheet.path);
    final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
    final anim = SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.sequenced(
        amount: sheet.totalFrames,
        amountPerRow: cols,
        textureSize: sheet.frameSize,
        stepTime: sheet.stepTime,
        loop: true,
      ),
    );
    c.ticker = anim.createTicker();
    const desired = 44.0;
    final s = desired / max(sheet.frameSize.x, sheet.frameSize.y);
    c.spriteScale = s * (c.member.spriteVisuals?.scale ?? 1.0);
  }

  CosmicSurvivalCompanion _createCombatCompanion(
    CosmicPartyMember member,
    Offset position,
  ) {
    final stats = deriveCosmicSurvivalCompanionStats(member: member);
    final companion = CosmicSurvivalCompanion(
      member: member,
      slotIndex: member.slotIndex,
      position: position,
      anchor: position,
      maxHp: stats.maxHp,
      currentHp: stats.maxHp,
      physAtk: stats.physAtk,
      elemAtk: stats.elemAtk,
      physDef: stats.physDef,
      elemDef: stats.elemDef,
      cooldownReduction: stats.cooldownReduction,
      critChance: stats.critChance,
      attackRange: stats.attackRange,
      specialAbilityRange: stats.specialAbilityRange,
      tethered: false,
      invincibleTimer: 0,
    );
    companion.primeSpecialCooldown(cooldownMultiplier: 0.25);
    return companion;
  }

  // ── Run / spawn management ──────────────────────────────

  void _placeAtEntrance() {
    currentRoomId = layout.entranceRoomId;
    _spreadCreaturesAround(layout.entranceSpawn);
    for (final c in creatures) {
      c.hp = c.maxHp;
      c.downHandled = false;
      c.respawnTimer = 0;
    }
    activeIndex = 0;
    _doorCooldown = 0.4;
    _camFocus = null; // snap the camera to the fresh spawn (no pan)
  }

  void _spreadCreaturesAround(Offset anchor) {
    final safeAnchor = _clampToBounds(anchor, currentRoom);
    for (var i = 0; i < creatures.length; i++) {
      final a = (i / max(1, creatures.length)) * pi * 2;
      final off = i == 0 ? Offset.zero : Offset(cos(a), sin(a)) * 34.0;
      var p = _clampToBounds(anchor + off, currentRoom);
      // Never strand a walker on open sky / over a gap — a non-Wing creature
      // can neither move nor launch a glide from there — and never post one
      // inside stone (see [regroup]: that is a teleport through every gate in
      // the game). The authored anchor is the always-valid fallback.
      if (!_canPlaceBody(p, safeAnchor, currentRoom)) p = safeAnchor;
      creatures[i].position = p;
      creatures[i].lastSafe = p;
      if (i < combatCompanions.length) {
        combatCompanions[i]
          ..position = p
          ..anchor = p
          ..currentHp = max(
            1,
            (combatCompanions[i].maxHp * creatures[i].hpFraction).round(),
          );
      }
    }
  }

  /// Reset puzzle progress (death or re-enter), but keep earned stars and
  /// discovered clouds (knowledge persists; per the design death only restarts).
  void _resetPuzzleState() {
    // A reset invalidates every attempt-edge (§5.6): the world the refusals
    // referred to no longer exists.
    _clearHints();
    flightActive = false;
    flightMeter = 0;
    _fallRecovering = false;
    _fallTimer = 0;
    // Knowledge persists across death: the entry passage stays revealed.
    entryDoorRevealed = discoveredClouds.contains(entryDoorDiscoveryId);
    _entryReveal = entryDoorRevealed ? 1.0 : 0.0;
    _entryRevealPrev = _entryReveal;
    carriedCloudId = null;
    carriedCloudType = null;
    filledAnchors.clear();
    placedClouds.clear();
    // Wonder trials restart (earned discoveries persist via discoveredClouds).
    _wonderProgress.clear();
    _veilPinned.clear();
    _anvilWave.clear();
    _anvilShellStruck = false;
    _feathers.clear();
    _featherPhases.clear();
    _featherSpawnTimer = 1.2;
    veilFlareTimer = 0;
    conduitEnergy.clear();
    _conduitMaxEnergy.clear();
    altarOpen = false;
    guardianAwake = isRaid;
    guardianVulnerable = false;
    _guardianCycle = 0;
    _raidPhaseIndex = 0;
    guardianHp = maxGuardianHp;
    guardianHitFlash = 0;
    _guardianStrikeCooldown = 0;
    _rocEnraged = false;
    _altarBlessingUsed = false;
    _guardianEnemy = null;
    _guardianArrival = -1; // a fresh run gets the whole arrival again
    _shake = 0;
    combatEnemies.clear();
    combatProjectiles.clear();
    _activeWingBeams.clear();
    _relicFx = null;
    _resetSpireState();
    _resetCathedralState();
    _resetTempleState();
    _resetBarrowState();
    _resetCircuitState();
    _resetPressureState();
    _resetFoundryState();
    _resetMonasteryState();
    _resetShaftState();
    _resetBogState();
    _resetRuinsState();
    _resetKeepState();
    _resetGraveState();
    _resetCryptState();
    _resetVaultState();
    _resetArchiveState();
    _resetHeartState();
  }

  void _resetRun() {
    _resetPuzzleState();
    _placeAtEntrance();
    onPlayerDown();
    onChanged();
  }

  // ── Input / UI hooks ────────────────────────────────────

  void setActive(int index) {
    if (index < 0 || index >= creatures.length) return;
    if (!creatures[index].alive) {
      final secs = creatures[index].respawnTimer.ceil();
      // A refused swap — attempt-edged by the tap itself.
      _setBlockedHint(
        secs > 0
            ? 'That creature is down — reviving in ${secs}s'
            : 'That creature is down',
        2.4,
      );
      onChanged();
      return;
    }
    activeIndex = index;
    onChanged();
  }

  void cycleActive() {
    final n = creatures.length;
    for (var step = 1; step <= n; step++) {
      final i = (activeIndex + step) % n;
      if (creatures[i].alive) {
        setActive(i);
        return;
      }
    }
  }

  /// Snap the inactive creatures next to the active one (QoL traversal aid).
  ///
  /// EXPLOIT FIX (2026-08-14, playtest): this used to check only the room
  /// bounds and open sky, so a regroup beside a wall posted the party INSIDE
  /// the stone — and since movement only forbids ENTERING something solid,
  /// never leaving it, they then walked out the far side. That teleported the
  /// party through walls, tide ledges, fossil ribs, powered barriers and
  /// pistons alike: every gate in the game, including straight into a star.
  /// Placement now has to be somewhere a body could actually stand, reached
  /// from the active creature without crossing anything solid.
  void regroup() {
    final a = active;
    if (a == null) return;
    var k = 0;
    final others = creatures.length - 1;
    for (var i = 0; i < creatures.length; i++) {
      if (i == activeIndex || !creatures[i].alive) continue;
      // Walk the ring for the first spot that is honestly reachable; the
      // active creature's own footing is the always-valid fallback (it is
      // standing there, so it cannot be inside anything).
      var p = a.position;
      for (var probe = 0; probe < 8; probe++) {
        final ang = (k / max(1, others)) * pi * 2 + probe * pi / 4;
        final c = _clampToBounds(
          a.position + Offset(cos(ang), sin(ang)) * 36.0,
          currentRoom,
        );
        if (_canPlaceBody(c, a.position, currentRoom)) {
          p = c;
          break;
        }
      }
      creatures[i].position = p;
      creatures[i].lastSafe = p;
      k++;
    }
    onChanged();
  }

  /// Is [p] somewhere a body can stand — no wall, no ledge, no rib, no
  /// barrier, no unextended piston, and not out over open sky? Mirrors
  /// [_hitsWall] minus its flight branch: placement is judged for a walker,
  /// because a walker is what gets stranded.
  bool _blocksPlacement(Offset p, DungeonRoom room) {
    if (_hitsWallRect(p, room)) return true;
    if (_isTemple && _templeLedgeBlocks(p, room)) return true;
    if (_isBarrow && _barrowBlocksAt(p, room)) return true;
    if (_isCircuit && _circuitBlocksAt(p, room)) return true;
    if (_isVapor && _steamBlocksAt(p, room)) return true;
    if (_isFoundry && _foundryBlocksAt(p, room)) return true;
    return !_onSolidGround(p, room);
  }

  /// Can a body be PLACED at [p] as seen from [from]? It must be standable,
  /// and the straight line from [from] must not pass through anything solid —
  /// otherwise a 36px snap could post a creature across a thin wall, which is
  /// the whole exploit this guards.
  bool _canPlaceBody(Offset p, Offset from, DungeonRoom room) {
    if (_blocksPlacement(p, room)) return false;
    const steps = 6;
    for (var i = 1; i < steps; i++) {
      if (_blocksPlacement(Offset.lerp(from, p, i / steps)!, room)) {
        return false;
      }
    }
    return true;
  }

  // ── Update ──────────────────────────────────────────────

  @override
  void update(double dt) {
    final swU = Stopwatch()..start();
    super.update(dt);
    _time += dt;
    if (_doorCooldown > 0) _doorCooldown -= dt;
    if (_hintTtl > 0) {
      _hintTtl -= dt;
      if (_hintTtl <= 0) hintText = null;
    }
    if (_ambientHintCooldown > 0) _ambientHintCooldown -= dt;
    if (_statHintCooldown > 0) _statHintCooldown -= dt;
    if (autoDeniedFlash > 0) autoDeniedFlash -= dt;
    if (abilityDeniedFlash > 0) abilityDeniedFlash -= dt;
    if (_loomRejectCooldown > 0) _loomRejectCooldown -= dt;
    if (_cloudPickupCooldown > 0) _cloudPickupCooldown -= dt;
    if (_guardianStrikeCooldown > 0) _guardianStrikeCooldown -= dt;
    if (revealFlash > 0) revealFlash -= dt;
    // The refusal pulse. Short — it is punctuation, not an animation.
    if (refusalFlash > 0) refusalFlash = max(0, refusalFlash - dt * 2.2);
    if (guardianHitFlash > 0) guardianHitFlash -= dt;
    final relicFx = _relicFx;
    if (relicFx != null) {
      relicFx.t += dt;
      if (relicFx.done) _relicFx = null;
    }
    _ambient.update(dt);
    _skyMood += (_skyMoodTarget - _skyMood) * min(1.0, dt * 1.1);
    _updateAlchemyParticles(dt);
    _abilityVfx.update(dt);
    for (final c in creatures) {
      c.ticker?.update(dt);
    }
    _guardianTicker?.update(dt);

    final room = currentRoom;
    // The arrival owns the room whether or not anyone is on their feet.
    _updateGuardianArrival(dt, room);
    final a = active;
    if (a == null) return;

    if (_updateFallRecovery(a, dt)) {
      _syncCombatFromCreatures();
      _updateCombat(dt);
      _syncCreaturesFromCombat();
      _handleDowns();
      return;
    }

    // Flight capacity tracks the active creature.
    flightMax = a.ability == DungeonAbility.aerialTraversal
        ? glideSeconds(a.member.statSpeed)
        : 0;
    if (a.ability != DungeonAbility.aerialTraversal) flightActive = false;

    // Updraft columns: rising winds carry walkers upward.
    final updraft = !flightActive ? _updraftAt(a, room) : null;
    updraftRiding = updraft != null;
    if (updraftRiding) _updraftCoyote = 0.35;

    // Movement (suspended while a cast sequence owns the body — horn
    // wind-up/dash/brew or a kin laser charge).
    final castLocked =
        activeCombat != null && _castLocksMovement(activeCombat!);
    // The raid death cinematic takes the controls away.
    final dir = _raidDeath != null ? Offset.zero : joystickDirection;
    // Swimming: flooded temple water slows everyone but Water itself.
    final moveSpeed =
        (flightActive ? _speed * _flightSpeedMul : _speed) *
        (_isTemple ? _templeSpeedMul(a) : 1.0);
    if (dir.distanceSquared > 0.0001 && !castLocked) {
      final airborneWalker =
          !flightActive &&
          (updraftRiding ||
              (_updraftCoyote > 0 && !_onSolidGround(a.position, room)));
      final beforeStep = a.position;
      if (airborneWalker) {
        // Steer while wind-borne: walls only, reduced authority.
        a.position = _moveDashing(a.position, dir * moveSpeed * 0.8 * dt, room);
      } else {
        a.position = _moveWithCollision(a.position, dir * moveSpeed * dt, room);
      }
      // Steam Star 1: walking into the raised stone SHOVES it (and walking
      // into a stone that cannot move stops you, like any other solid).
      if (_isVapor) _pushEarthRock(a, room, beforeStep);
      if (dir.dx.abs() > 0.01) a.angle = dir.dx >= 0 ? 0 : pi;
      a.aimAngle = atan2(dir.dy, dir.dx);
    }
    if (updraft != null) {
      final sway = sin(_time * 2.1) * 16 * dt;
      // A waking gale lifts with an eased swell — never a snap (§8).
      final swell = _isSpire ? _galeFactor(updraft) : 1.0;
      a.position = _moveDashing(
        a.position,
        Offset(sway, -updraft.strength * 0.95 * swell * dt),
        room,
      );
    } else if (!flightActive && _updraftCoyote > 0) {
      if (_onSolidGround(a.position, room)) {
        _updraftCoyote = 0; // landed — grace spent
      } else {
        _updraftCoyote -= dt;
        if (_updraftCoyote <= 0) {
          _beginFallRecovery(
            a,
            a.lastSafe,
            hint: 'The thermal lets go — drifting back to footing',
          );
        }
      }
    }

    _applyCurrents(a, room, dt);
    _updateEnvironmentalHints(a, room);
    // Carried-echo wake: the echo trails wind behind its carrier.
    if (carriedCloudId != null) {
      _carryTrail.add(a.position + const Offset(0, -30));
      if (_carryTrail.length > 10) _carryTrail.removeAt(0);
    } else if (_carryTrail.isNotEmpty) {
      _carryTrail.removeAt(0);
    }
    // Glide wind trail (also while riding a thermal, or carried by a gale).
    if (flightActive || updraftRiding || _galeRiding) {
      _glideTrail.add(a.position);
      if (_glideTrail.length > 16) _glideTrail.removeAt(0);
    } else if (_glideTrail.isNotEmpty) {
      _glideTrail.removeAt(0);
    }
    _updateEntryReveal(dt);
    _updateCamera(dt);
    _updateRespawns(dt);
    _updateFlight(a, room, dt);
    _updateWinds(a, room, dt);
    _updateWonderTrials(a, room, dt);
    _updateLoom(a, room);
    _updateAltar(a, room, dt);
    // AFTER the altar: the Roc's leash is settled there, and the cell hangs
    // from the leash.
    _updateStormCell(a, room, dt);
    _updateMercyShrine(a, room);
    _updateCathedral(a, room, dt);
    _updateBurn(room, dt);
    _updateTemple(a, room, dt);
    _updateBarrow(a, room, dt);
    _updateCircuit(a, room, dt);
    _updatePressure(a, room, dt);
    _updateGeyserField(a, room, dt);
    _updateFoundry(a, room, dt);
    _updateMonastery(a, room, dt);
    _updateShaft(a, room, dt);
    _updateBog(a, room, dt);
    _updateRuins(a, room, dt);
    _updateKeep(a, room, dt);
    _updateGrave(a, room, dt);
    _updateCrypt(a, room, dt);
    _updateVault(a, room, dt);
    _updateArchive(a, room, dt);
    _updateHeart(a, room, dt);
    _syncCombatFromCreatures();
    _updateCombat(dt);
    _syncCreaturesFromCombat();
    // The gale pushes friend AND FOE — applied AFTER the steering AI has had
    // its say, so the wind is something the wisps are carried by rather than
    // something their pathing quietly undoes.
    if (_isSpire) _applyGalesToEnemies(room, dt);

    _checkDoors(a);
    _checkHazards(a, dt);
    _checkStars(a);
    _checkVaultCache(a);
    // Door-reveal rings play out only while their room is on screen.
    for (final fx in _doorRevealFx) {
      if (fx.roomId != currentRoomId) continue;
      if (!fx.burstFired) {
        fx.burstFired = true;
        _spawnAlchemyBurst(
          fx.position,
          producedElement: 'Light',
          reagentElements: const ['Air'],
          particleCount: 18,
          intensity: 0.9,
        );
      }
      fx.ttl -= dt;
    }
    _doorRevealFx.removeWhere((fx) => fx.ttl <= 0);
    _handleDowns();
    _probeLastUpdateMs = swU.elapsedMicroseconds / 1000.0;
  }

  bool _overGap(Offset p, DungeonRoom room) {
    for (final g in room.gaps) {
      if (g.rect.contains(p)) return true;
    }
    return false;
  }

  /// Can a walking (non-gliding) creature stand here? Open-sky rooms restrict
  /// footing to their platforms; gap rooms block gaps; plain rooms are all
  /// solid.
  bool _onSolidGround(Offset p, DungeonRoom room) {
    if (room.platforms.isNotEmpty) {
      for (final pl in room.platforms) {
        if (pl.inflate(2).contains(p)) return true;
      }
      return false;
    }
    return !_overGap(p, room);
  }

  /// The upward current carrying [a], if any. Strong columns still respect
  /// the Speed stat gate (same rule gliders face).
  WindCurrent? _updraftAt(DungeonCreature a, DungeonRoom room) {
    final refusing = <String>{};
    WindCurrent? riding;
    for (var i = 0; i < room.currents.length; i++) {
      final cur = room.currents[i];
      if (cur.strength <= 0) continue;
      // A sleeping gale is not a wind yet (§6.11 REWORK).
      if (cur.galeId != null && !_currentLive(cur)) continue;
      final len = cur.dir.distance;
      if (len <= 0 || cur.dir.dy / len > -0.5) continue; // not an updraft
      if (!cur.rect.contains(a.position)) continue;
      if (cur.requiredSpeed > 0 && a.member.statSpeed < cur.requiredSpeed) {
        // The failure moment: the thermal rejects this creature. Refused
        // ONCE per attempt (§5.6 BLOCKED), re-armed when it steps out.
        final key = '$_updraftBlockPrefix${room.id}#$i';
        refusing.add(key);
        _setBlockedHintOnce(
          key,
          'The thermal casts you off — needs more Speed',
        );
        continue;
      }
      riding ??= cur;
    }
    _releaseBlockedExcept(_updraftBlockPrefix, refusing);
    return riding;
  }

  static const String _updraftBlockPrefix = 'updraft:';
  static const String _currentBlockPrefix = 'current:';

  void _applyCurrents(DungeonCreature a, DungeonRoom room, double dt) {
    final resisting = <String>{};
    if (flightActive) {
      for (var i = 0; i < room.currents.length; i++) {
        final cur = room.currents[i];
        if (cur.strength <= 0 || !cur.rect.contains(a.position)) continue;
        final swell = _isSpire ? _galeFactor(cur) : 1.0;
        if (swell <= 0.01) continue; // a sleeping gale is not a wind yet
        final len = cur.dir.distance;
        if (len <= 0) continue;
        var push = (cur.dir / len) * cur.strength * swell * dt;
        // Too slow to ride a strong current → it overpowers and shoves back.
        // The shove IS the failure moment: the refusal speaks once per
        // attempt (§5.6 BLOCKED) and re-arms when the flier leaves it.
        if (cur.requiredSpeed > 0 && a.member.statSpeed < cur.requiredSpeed) {
          push = -push * 1.2;
          final key = '$_currentBlockPrefix${room.id}#$i';
          resisting.add(key);
          _setBlockedHintOnce(
            key,
            'The current throws you back — needs more Speed',
          );
        }
        a.position = _moveWithCollision(a.position, push, room);
      }
    } else {
      // §6.11 REWORK: a woken gale pushes EVERYTHING — walkers included. This
      // is what makes a gale a ladder rather than a flier's shortcut, and it is
      // the same wind that scours the walkways it crosses.
      _applyGaleToWalker(a, room, dt);
    }
    _releaseBlockedExcept(_currentBlockPrefix, resisting);
  }

  void _updateEnvironmentalHints(DungeonCreature a, DungeonRoom room) {
    if (_ambientHintCooldown > 0 || _hintTtl > 0.45) return;

    for (final cur in room.currents) {
      if (!cur.rect.inflate(8).contains(a.position)) continue;
      // A sleeping gale is a hollow in the air, not a wind (§9.1 Air rework).
      if (_isSpire && cur.galeId != null && !_currentLive(cur)) {
        _setAmbientHint('Something long and cold is not moving here');
        return;
      }
      if (a.member.element == 'Fire') {
        _setAmbientHint('Your flame streams sideways, hungry for the wind');
      } else {
        _setAmbientHint('The wind here never rests');
      }
      return;
    }

    for (final c in room.conduits) {
      if ((a.position - c.position).distance > 54) continue;
      if (!guardianRiteUnlocked) {
        // Pure atmosphere — the gate itself states its keys on a refused
        // offering (see _energizeConduit), never on proximity.
        _setAmbientHint('The twin pylons sleep');
      } else if (c.requiredFamily == null) {
        _setAmbientHint('The air prickles around this conductor');
      } else {
        // Flavour only: under v2 a gated conduit answers one family, so any
        // "hold it longer" phrasing would be a lie to everyone else standing
        // here. What it takes is the gate's own refusal line and Mask insight.
        _setAmbientHint('${c.requireElement} gathers inside this pylon');
      }
      return;
    }

    final guardian = room.guardian;
    if (guardian != null &&
        guardianAwake &&
        (a.position - _guardianPosition(guardian)).distance <= 105) {
      _setAmbientHint(
        guardianVulnerable
            ? 'The storm about the guardian thins'
            : 'The guardian is all storm',
      );
      return;
    }

    for (final cl in room.clouds) {
      if ((a.position - cl.position).distance <= 58 &&
          !discoveredClouds.contains(cl.id)) {
        _setAmbientHint(
          room.anchors.isEmpty
              ? 'The echo sleeps, sealed'
              : 'A sleeping echo — it dreams of somewhere else',
        );
        return;
      }
    }

    if (_isSpire) _spireAmbientHint(a, room);
    if (_isCathedral) _cathedralAmbientHint(a, room);
    if (_isTemple) _templeAmbientHint(a, room);
    if (_isBarrow) _barrowAmbientHint(a, room);
    if (_isCircuit) _circuitAmbientHint(a, room);
    if (_isVapor) _steamAmbientHint(a, room);
    if (_isFoundry) _foundryAmbientHint(a, room);
    if (_isVenom) _monasteryAmbientHint(a, room);
    if (_isShaft) _shaftAmbientHint(a, room);
    if (_isBog) _bogAmbientHint(a, room);
    if (_isRuins) _ruinsAmbientHint(a, room);
    if (_isKeep) _keepAmbientHint(a, room);
    if (_isWake) _graveAmbientHint(a, room);
    if (_isCrypt) _cryptAmbientHint(a, room);
    if (_isVault) _vaultAmbientHint(a, room);
    if (_isArchive) _archiveAmbientHint(a, room);
    if (_isHeart) _heartAmbientHint(a, room);
  }

  /// Atmospheric flavor — the lowest channel. It can never take the capsule
  /// from a refusal, a reading or a live objective, and it burns its cooldown
  /// only when it actually spoke.
  void _setAmbientHint(String msg) {
    if (_emitHint(msg, DungeonHintChannel.ambient, 2.0)) {
      _ambientHintCooldown = 4.0;
    }
  }

  void _setStatHint(String msg) {
    if (_statHintCooldown > 0) return;
    _setHint(msg, 2.5);
    _statHintCooldown = 3.5;
  }

  void _discoverCloud(String cloudId) {
    if (!discoveredClouds.add(cloudId)) return;
    onCloudDiscovered?.call(cloudId);
    onChanged();
  }

  /// THE SEAL REMEMBERS (§4): a hard family gate refused the wrong family.
  /// Speaks the gate's one-clause refusal on the BLOCKED channel (a press is
  /// already edge-triggered — it happened exactly once), and — the FIRST time
  /// only, via [_discoverCloud]'s idempotent Set.add — permanently stamps the
  /// element+family requirement onto the planet's overworld descent panel.
  /// Rides the existing one-time discovery channel (`rune:entry_door`
  /// precedent), so nothing new is persisted.
  void _stampFamilyGate(DungeonFamilyGate gate) {
    _setBlockedHint(gate.hintLine);
    _discoverCloud(gate.discoveryId);
  }

  /// Put a carried echo down. The echo drifts back to its resting place in
  /// the loom (a charged Thundercloud loses its charge — it reverts to the
  /// authored Anvil). A short grace period stops an instant re-grab.
  void dropCarriedCloud() {
    final a = active;
    if (a == null || carriedCloudId == null) return;
    final wasCharged = carriedCloudType == 'Thundercloud';
    _spawnAlchemyBurst(
      a.position,
      producedElement: 'Air',
      reagentElements: wasCharged ? const ['Lightning'] : const [],
      particleCount: 12,
      intensity: 0.6,
    );
    carriedCloudId = null;
    carriedCloudType = null;
    _cloudPickupCooldown = 1.0;
    _setHint(
      wasCharged
          ? 'The thunder disperses — the echo drifts back to rest'
          : 'The echo drifts back to its resting place',
    );
    onChanged();
  }

  void _updateAlchemyParticles(double dt) {
    for (final p in _alchemyParticles) {
      p.life -= dt;
      p.position += p.velocity * dt;
      p.velocity *= 0.95;
    }
    _alchemyParticles.removeWhere((p) => p.dead);
  }

  void _spawnAlchemyBurst(
    Offset center, {
    required String producedElement,
    List<String> reagentElements = const [],
    bool unstable = false,
    int? particleCount,
    double intensity = 1.0,
  }) {
    final colors = <Color>[
      for (final e in reagentElements) elementColor(e),
      elementColor(producedElement),
      if (unstable) const Color(0xFFFFFFFF),
    ];
    final count = particleCount ?? (unstable ? 42 : 28);
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963 + _combatRng.nextDouble() * 0.7;
      final speed =
          (42 + _combatRng.nextDouble() * (unstable ? 138 : 92)) * intensity;
      final color = colors[i % colors.length];
      _alchemyParticles.add(
        _AlchemyParticle(
          position: center + Offset(cos(angle), sin(angle)) * (6 + i % 5),
          velocity: Offset(cos(angle), sin(angle)) * speed,
          color: Color.lerp(color, Colors.white, unstable ? 0.28 : 0.12)!,
          maxLife:
              (0.45 + _combatRng.nextDouble() * (unstable ? 0.65 : 0.45)) *
              intensity.clamp(0.55, 1.35),
          size:
              (2.0 + _combatRng.nextDouble() * (unstable ? 4.0 : 3.0)) *
              intensity.clamp(0.55, 1.25),
          arc: unstable || producedElement == 'Lightning',
        ),
      );
    }
    while (_alchemyParticles.length > 180) {
      _alchemyParticles.removeAt(0);
    }
  }

  /// Per-frame ambient zone wisps. Graphics are defined once in
  /// [emitZoneParticles] (Cosmic Survival is the source of truth); this just
  /// routes them into the dungeon's [_AlchemyParticle] pool. Caller gates on
  /// the pool cap.
  void _spawnZoneParticles(Projectile p) {
    emitZoneParticles(p, _combatRng, (
      x,
      y,
      vx,
      vy,
      size,
      life,
      color, {
      arc = false,
    }) {
      _abilityVfx.add(x, y, vx, vy, size, life, color);
    });
  }

  void _spawnUtilitySignature(DungeonCreature a) {
    final element = a.member.element;
    final unstable = element == 'Lightning' || element == 'Lava';
    _spawnAlchemyBurst(
      a.position,
      producedElement: element,
      reagentElements: const [],
      unstable: unstable,
      particleCount: 12,
      intensity: 0.62,
    );
  }

  bool _updateFallRecovery(DungeonCreature a, double dt) {
    if (!_fallRecovering) return false;
    _fallTimer += dt;
    final raw = (_fallTimer / max(0.001, _fallDuration))
        .clamp(0.0, 1.0)
        .toDouble();
    final eased = 1 - pow(1 - raw, 2).toDouble();
    final drift = Offset(0, sin(raw * pi) * 18);
    a.position = Offset.lerp(_fallStart, _fallTarget, eased)! + drift;
    if (raw >= 1) {
      a.position = _fallTarget;
      a.lastSafe = _fallTarget;
      flightMeter = flightMax;
      _fallRecovering = false;
    }
    return true;
  }

  void _beginFallRecovery(
    DungeonCreature a,
    Offset target, {
    String hint = 'Needs more Speed to glide farther',
  }) {
    _fallRecovering = true;
    _fallStart = a.position;
    _fallTarget = target;
    _fallTimer = 0;
    _fallDuration = ((a.position - target).distance / 240).clamp(0.55, 1.25);
    _setHint(hint);
    _spawnAlchemyBurst(
      a.position,
      producedElement: 'Air',
      reagentElements: [a.member.element],
      particleCount: 16,
      intensity: 0.52,
    );
  }

  void _updateFlight(DungeonCreature a, DungeonRoom room, double dt) {
    if (flightActive) {
      flightMeter -= dt;
      if (flightMeter <= 0) {
        flightMeter = 0;
        flightActive = false;
        if (!_onSolidGround(a.position, room)) {
          _beginFallRecovery(a, a.lastSafe);
          onChanged();
        }
      }
    } else if (_onSolidGround(a.position, room) &&
        !(_isTemple && _templeOverLedge(a.position, room)) &&
        !(_isSpire && _onScouredFooting(a.position, room))) {
      // On solid ground: remember it and refill the glide reserve. Swimming
      // over a submerged tide-ledge is NOT safe footing — when the water
      // falls away the ledge becomes a wall, so lastSafe must stay off it.
      // Neither is stone a live gale is sweeping: remembering it would drop a
      // blown-off walker straight back into the wind that just took them,
      // over and over. Being blown off costs one fall and one climb, not a
      // loop (§6.11 REWORK).
      a.lastSafe = a.position;
      flightMeter = flightMax;
    }
  }

  void _updateLoom(DungeonCreature a, DungeonRoom room) {
    if ((room.clouds.isEmpty && room.anchors.isEmpty) || _roomCleared(room)) {
      return;
    }
    // Wonder-cloud branch rooms are TRIAL spaces — discovery is earned by
    // solving each chamber's elemental micro-puzzle (_updateWonderTrials /
    // _tryWonderTrial), never by walking over the echo. The earned echoes
    // are then carried and slotted inside the Sky Loom chamber.
    if (room.anchors.isEmpty) return;
    if (carriedCloudId == null) {
      if (_cloudPickupCooldown > 0) return; // just dropped — don't re-grab
      for (final cl in room.clouds) {
        if (!discoveredClouds.contains(cl.id)) continue;
        if (placedClouds.contains(cl.id)) continue;
        if ((a.position - cl.position).distance < 26) {
          carriedCloudId = cl.id;
          carriedCloudType = cl.cloudType;
          _setHint('Carrying ${cl.cloudType} — DROP releases it');
          onChanged();
          break;
        }
      }
    } else {
      for (final an in room.anchors) {
        if (filledAnchors.containsKey(an.id)) continue;
        if ((a.position - an.position).distance > 30) continue;
        if (an.requiredCloudType == carriedCloudType) {
          filledAnchors[an.id] = carriedCloudType!;
          placedClouds.add(carriedCloudId!);
          carriedCloudId = null;
          carriedCloudType = null;
          _setHint('The cloud settles into place');
          _spawnAlchemyBurst(
            an.position,
            producedElement: 'Light',
            reagentElements: const ['Air', 'Spirit'],
          );
          onChanged();
          final star = room.loomStarIndex;
          if (star != null &&
              filledAnchors.length >= room.anchors.length &&
              !hasStar(star)) {
            earnStar(star);
          }
        } else if (_loomRejectCooldown <= 0) {
          // One rejection per approach, not per frame — without this the
          // loom sprays wisps at 60/sec while you stand on a wrong anchor.
          _loomRejectCooldown = 2.2;
          // A REFUSAL, so it belongs on the blocked channel — it was untagged,
          // which meant it spoke as ordinary world-response and could be
          // stomped by anything. Now that only refusals survive to be asked
          // about, an untagged one is lost entirely, so the mis-tag matters.
          _setBlockedHint(
            an.clue.isNotEmpty
                ? 'Incorrect placement — this anchor calls for “${an.clue}”'
                : 'Incorrect placement — this anchor calls for a different echo',
            3.2,
          );
          _spawnAlchemyBurst(
            an.position,
            producedElement: 'Air',
            reagentElements: const ['Spirit'],
            unstable: true,
          );
          spawnWispWave(
            element: 'Air',
            center: an.position,
            count: 2,
            announce: false, // keep the wrong-placement message on screen
          );
        }
        break;
      }
    }
  }

  // ── Wonder-cloud trials ─────────────────────────────────
  // Each branch chamber earns its echo through a themed micro-trial built
  // from the planet's element kit (Air rides, Fire ignites, Lightning
  // strikes, and Air+Fire→Lightning arcs — same language as the entry door
  // and conduit B).

  void _completeWonderTrial(HiddenCloud cl, String message) {
    _discoverCloud(cl.id);
    _setHint(message, 3.2);
    _spawnAlchemyBurst(
      cl.position,
      producedElement: 'Air',
      reagentElements: const ['Light'],
      particleCount: 30,
      intensity: 1.1,
    );
  }

  /// Per-frame trial logic (touch-driven trials: spiral eddies, falling
  /// feathers, anvil wave completion).
  void _updateWonderTrials(DungeonCreature a, DungeonRoom room, double dt) {
    if (veilFlareTimer > 0) veilFlareTimer -= dt;
    // The Gale Eye's jets swell and its re-arm edge live OUTSIDE the sealed
    // guard: leaving the chamber is what shuts the vents, and that has to be
    // seen even on the frame the player walks out.
    if (_isSpire) _updateSpiralChamber(room, dt);
    final sealed = _sealedWonderCloud(room);
    if (sealed == null) return;

    switch (room.id) {
      case 'feather_cloud':
        // Weightless: feathers drift down one at a time; catch three
        // before they land. Air draws nearby feathers toward itself.
        _featherSpawnTimer -= dt;
        if (_feathers.isEmpty && _featherSpawnTimer <= 0) {
          final b = room.bounds;
          _feathers.add(
            Offset(
              b.left + 120 + _combatRng.nextDouble() * (b.width - 240),
              b.top + 46,
            ),
          );
          _featherPhases.add(_combatRng.nextDouble() * pi * 2);
        }
        for (var i = _feathers.length - 1; i >= 0; i--) {
          var p = _feathers[i];
          final phase = _featherPhases[i];
          p += Offset(sin(_time * 1.6 + phase) * 36 * dt, 55 * dt);
          // The wind answers Air: feathers drift toward the nearest living
          // Air creature (active or idle).
          DungeonCreature? airDraw;
          var airDist = 110.0;
          for (final cr in creatures) {
            if (!cr.alive || cr.member.element != 'Air') continue;
            final d = (cr.position - p).distance;
            if (d < airDist) {
              airDist = d;
              airDraw = cr;
            }
          }
          if (airDraw != null && airDist > 1) {
            p += (airDraw.position - p) / airDist * 42 * dt;
          }
          _feathers[i] = p;
          // ANY living party member can catch — position your party as
          // catchers and swap between them.
          DungeonCreature? catcher;
          for (final cr in creatures) {
            if (cr.alive && (cr.position - p).distance < 36) {
              catcher = cr;
              break;
            }
          }
          if (catcher != null) {
            _feathers.removeAt(i);
            _featherPhases.removeAt(i);
            final caught = (_wonderProgress['feather_cloud'] ?? 0) + 1;
            _wonderProgress['feather_cloud'] = caught;
            _featherSpawnTimer = 0.9;
            _spawnAlchemyBurst(
              catcher.position,
              producedElement: 'Air',
              particleCount: 10,
              intensity: 0.6,
            );
            if (caught >= 3) {
              _completeWonderTrial(
                sealed,
                'Three plumes gathered — the Feather echo awakens',
              );
            } else {
              _setHint('Feather caught — $caught / 3');
            }
            onChanged();
          } else if (p.dy > room.bounds.bottom - 56) {
            _feathers.removeAt(i);
            _featherPhases.removeAt(i);
            _featherSpawnTimer = 1.4;
            _setStatHint('The feather settles into the void — another rises');
          }
        }
        break;

      case 'anvil_cloud':
        // Crack the shell: once struck, a trio of storm-sparks defends the
        // anvil. Clearing the wave hammers it awake.
        if (_anvilShellStruck &&
            _anvilWave.isNotEmpty &&
            _anvilWave.every(
              (e) => e.isDead || e.hp <= 0 || !combatEnemies.contains(e),
            )) {
          _anvilWave.clear();
          _completeWonderTrial(
            sealed,
            'The sparks disperse — their charge hammers the Anvil awake',
          );
        }
        break;
    }
  }

  /// Utility-driven trial interactions (returns true if consumed):
  /// ring conjunction seal, anvil shell crack, veil pinning / Fire flare.
  bool _tryWonderTrial(DungeonCreature a) {
    final room = currentRoom;
    final sealed = _sealedWonderCloud(room);
    if (sealed == null) return false;

    switch (room.id) {
      case 'spiral_cloud':
        // THE GALE EYE: commune with a vent to open its jet — for good. The
        // whole mechanic lives in the Air file with Star 1's shrines, whose
        // verb and irreversibility it borrows.
        return _trySpiralVent(a, sealed);

      case 'ring_cloud':
        // The Conjunction: Air, Fire and Lightning reagents circle the
        // orbit — seal the ring while the trio is gathered.
        if ((a.position - room.bounds.center).distance > 90) return false;
        if (ringMotesAligned) {
          _completeWonderTrial(
            sealed,
            'The three reagents braid as one — the Ring echo awakens',
          );
        } else {
          _setHint(
            'The reagents are scattered — seal the orbit when they gather',
          );
        }
        return true;

      case 'anvil_cloud':
        if (_anvilShellStruck) {
          if (_anvilWave.any((e) => !e.isDead && e.hp > 0)) {
            _setHint('The storm-sparks still guard the anvil');
            return true;
          }
          return false;
        }
        final nearShell = (a.position - sealed.position).distance < 64;
        final inCurrent = room.currents.any((c) => c.rect.contains(a.position));
        if (a.member.element == 'Lightning' && nearShell) {
          _crackAnvilShell(sealed, viaRecipe: false);
          return true;
        }
        if (a.member.element == 'Fire' && inCurrent) {
          // Air+Fire→Lightning: the braided arc leaps to the shell.
          _crackAnvilShell(sealed, viaRecipe: true);
          return true;
        }
        if (nearShell || inCurrent) {
          // A refused strike — the method itself is Mask-insight content
          // (see _wonderInsight), so the refusal only names what's missing.
          _setBlockedHint('The shell answers only storm-charge');
          return true;
        }
        return false;

      case 'veil_cloud':
        final spots = veilSpots(room);
        final visible = veilVisibleSpotIndex;
        final flare = veilFlareTimer > 0;
        // Which spots are currently pinnable?
        bool pinnable(int i) =>
            !_veilPinned.contains(i) && (flare || visible == i);
        // Lightning pins from range (a static arc leaps to the fold).
        final reach = a.member.element == 'Lightning' ? 160.0 : 46.0;
        for (var i = 0; i < spots.length; i++) {
          if (!pinnable(i)) continue;
          if ((a.position - spots[i]).distance > reach) continue;
          _veilPinned.add(i);
          _spawnAlchemyBurst(
            spots[i],
            producedElement: a.member.element == 'Lightning'
                ? 'Lightning'
                : 'Air',
            reagentElements: const ['Spirit'],
            particleCount: 14,
            intensity: 0.8,
          );
          if (_veilPinned.length >= spots.length) {
            _completeWonderTrial(
              sealed,
              'All three folds pinned — the Veil echo awakens',
            );
          } else {
            _setHint('The fold is pinned — ${_veilPinned.length} / 3');
          }
          onChanged();
          return true;
        }
        // Fire flare: reveal every fold for a few breaths.
        if (a.member.element == 'Fire') {
          veilFlareTimer = 3.0;
          _setHint('Firelight floods the chamber — the folds stand bare');
          _spawnAlchemyBurst(
            a.position,
            producedElement: 'Fire',
            particleCount: 16,
            intensity: 0.9,
          );
          return true;
        }
        _setHint('A fold breathes somewhere — pin it while it shows');
        return true;
    }
    return false;
  }

  void _crackAnvilShell(HiddenCloud sealed, {required bool viaRecipe}) {
    _anvilShellStruck = true;
    _setHint(
      viaRecipe
          ? 'Air and Fire braid into Lightning — the arc cracks the shell!'
          : 'The storm-charge splits the shell!',
      3.0,
    );
    _spawnAlchemyBurst(
      sealed.position,
      producedElement: 'Lightning',
      reagentElements: viaRecipe ? const ['Air', 'Fire'] : const ['Lightning'],
      unstable: true,
      particleCount: 28,
      intensity: 1.2,
    );
    // The trio guards the storm-heart: one spark of each entry element.
    _anvilWave.clear();
    final specs = [
      ('Lightning', EnemyConduct.stalk),
      ('Air', EnemyConduct.charge),
      ('Fire', EnemyConduct.charge),
    ];
    for (var i = 0; i < specs.length; i++) {
      final ang = i * pi * 2 / specs.length + _combatRng.nextDouble() * 0.4;
      final enemy = CosmicSurvivalEnemy(
        position: sealed.position + Offset(cos(ang), sin(ang)) * 110,
        hp: 30,
        maxHp: 30,
        speed: specs[i].$2 == EnemyConduct.stalk ? 96 : 80,
        damage: 11,
        radius: 13,
        tier: EnemyTier.wisp,
        element: specs[i].$1,
        conduct: specs[i].$2,
        target: CosmicEnemyTarget.companion,
      );
      _anvilWave.add(enemy);
      combatEnemies.add(enemy);
    }
    onChanged();
  }

  void _updateAltar(DungeonCreature a, DungeonRoom room, double dt) {
    if (room.conduits.isEmpty && room.guardian == null) return;
    if (_roomCleared(room)) return;
    // §9.1 REWORK: conduits LATCH. Nothing decays here any more — the altar is
    // a question about the storm's route, not about how fast you can run.
    final aLive = (conduitEnergy['A'] ?? 0) > 0;
    final bLive = (conduitEnergy['B'] ?? 0) > 0;
    if (aLive && bLive && !altarOpen) {
      altarOpen = true;
      guardianAwake = true;
      guardianHp = maxGuardianHp;
      _setHint('Both conduits sing — the altar wakes its guardian');
      _spawnAlchemyBurst(
        room.bounds.center,
        producedElement: 'Lightning',
        reagentElements: const ['Air', 'Fire'],
        unstable: true,
      );
      spawnWispWave(
        element: 'Lightning',
        center: room.bounds.center,
        count: 4,
        unstable: true,
        announce: false, // "Both conduits sing…" stays on screen
      );
      onChanged();
    }
    final g = room.guardian;
    if (guardianAwake && g != null) {
      _maybeSpawnGuardianCombat(room); // safe to call every frame (guarded)
      // Nothing turns while the mystic is still falling: no lull clock, no
      // hazard ring, no enrage. The fight starts when it lands.
      if (guardianArriving) return;
      _guardianCycle += dt;
      guardianVulnerable = (_guardianCycle % 6.0) < (_rocEnraged ? 2.2 : 3.0);
      // Raikuma feeds on the powered core trunk (§7): while it drinks there
      // is NO lull; grounding the trunk forces the window. Lightning-only
      // hook — every other guardian keeps the shared cycle untouched.
      if (_isCircuit) _applyRaikumaFeed(room, dt);
      // Leviathan turns the tide (§7): the arena floods and drains on its
      // roar, and the lull only opens on SETTLED water. Water-only hook —
      // every other guardian keeps the shared cycle untouched, and raids are
      // exempt (the generated arena has no tide zones).
      if (_isTemple) _applyLeviathanTide(room, dt);
      // Simurgh re-lights the rite braziers as it strikes (§7): the ORDER is
      // the bullet pattern. Reads the shared lull/strike cycle, never rewrites
      // it — and the generated raid arena has no braziers to re-light.
      if (_isCathedral) _applySimurghTelegraph(a, room, dt);
      // The Roc drags the storm-cell across its own rod field (§7): the shared
      // cycle still turns, but a bolt LED INTO the bird — up a staircase of
      // rods, Star 3's own vocabulary — forces a window the cycle never would.
      // Air-only, and raids have no rod field to rank.
      if (_isSpire) _applyRocDrag(room, dt);
      // Blightfang never opens a lull on a clock (§7): only the draught that
      // answers the strain it is WEARING forces the window, and it takes a
      // fresh habit the moment the window shuts. Poison-only; raids exempt.
      // Magmara rides the heart's own conveyor (§7): no clock ever bares it,
      // and the ring's two heads — the works' verb, in the fight — are what
      // beach it. Lava-only; raids have no ring to ride.
      if (_isFoundry) _applyMagmaraRide(room, dt);
      if (_isVenom) _applyBlightfangStrain(room, dt);
      final stormCenter = _guardianPosition(g);
      // Half-HP escalation: one screech — feather-wisps rise, lulls tighten.
      if (!_rocEnraged &&
          _guardianEnemy != null &&
          !_guardianEnemy!.isDead &&
          _guardianHpFraction < 0.5) {
        _rocEnraged = true;
        _setHint(
          _guardianEnrageHints[g.encounter?.mysticId] ??
              'The guardian\'s fury redoubles!',
          3.2,
        );
        _spawnAlchemyBurst(
          stormCenter,
          producedElement: layout.element,
          unstable: true,
          particleCount: 26,
          intensity: 1.2,
        );
        spawnWispWave(
          element: layout.element,
          center: stormCenter,
          count: 2,
          announce: false,
        );
      }
      if (!guardianVulnerable && (a.position - stormCenter).distance < 90) {
        a.hp = max(0, a.hp - _guardianHazardDps * progressDmgMul * dt);
      }
    }
  }

  /// The finale shrine's mercy: approaching it once per run fully mends the
  /// party — a breath before the guardian.
  void _updateMercyShrine(DungeonCreature a, DungeonRoom room) {
    if (room.id != layout.mercyShrineRoomId || _altarBlessingUsed) return;
    if ((a.position - room.bounds.center).distance > 70) return;
    if (!creatures.any((c) => c.alive && c.hp < c.maxHp - 0.5)) return;
    _altarBlessingUsed = true;
    for (final c in creatures) {
      if (c.alive) c.hp = c.maxHp;
    }
    _setHint('The altar\'s breath mends the party — once', 3.2);
    _spawnAlchemyBurst(
      room.bounds.center,
      producedElement: 'Light',
      reagentElements: [layout.element],
      particleCount: 24,
      intensity: 1.0,
    );
    onChanged();
  }

  /// Live guardian position: the swooping combat body once it has spawned,
  /// otherwise the authored altar perch.
  Offset _guardianPosition(GuardianNode g) {
    final e = _guardianEnemy;
    return (e != null && !e.isDead) ? e.position : g.position;
  }

  double get _guardianHpFraction {
    final e = _guardianEnemy;
    if (e == null) return guardianHp / maxGuardianHp;
    return (e.hp / max(1, e.maxHp)).clamp(0.0, 1.0).toDouble();
  }

  void _syncCombatFromCreatures() {
    for (var i = 0; i < creatures.length && i < combatCompanions.length; i++) {
      final creature = creatures[i];
      final comp = combatCompanions[i];
      comp
        ..position = creature.position
        ..anchor = creature.position
        ..angle = creature.angle
        ..isDead = !creature.alive
        ..currentHp = (comp.maxHp * creature.hpFraction).round().clamp(
          0,
          comp.maxHp,
        );
    }
  }

  void _syncCreaturesFromCombat() {
    for (var i = 0; i < creatures.length && i < combatCompanions.length; i++) {
      final creature = creatures[i];
      final comp = combatCompanions[i];
      creature.hp = (creature.maxHp * comp.hpPercent).clamp(
        0.0,
        creature.maxHp,
      );
    }
  }

  /// Down handling: a knocked-out creature stays down (announced once) and
  /// control auto-swaps to a living teammate. Only a full party wipe resets
  /// the run.
  void _handleDowns() {
    var anyAlive = false;
    for (final c in creatures) {
      if (c.alive) {
        c.downHandled = false;
        c.respawnTimer = 0;
        anyAlive = true;
      } else if (!c.downHandled) {
        c.downHandled = true;
        // A raid has no second chances. Elsewhere a down is a setback you
        // wait out; in a raid it is a loss you fight the rest of the fight
        // without, which is what makes the attempt worth anything.
        c.respawnTimer = isRaid ? 0 : respawnSeconds;
        if (isRaid) onRaidCreatureDown?.call(c.member.instanceId);
        _spawnAlchemyBurst(
          c.position,
          producedElement: c.member.element,
          particleCount: 18,
          intensity: 0.8,
        );
        _setHint(
          isRaid
              ? '${c.member.element} ${c.member.family} has fallen — '
                    'no revival in a raid'
              : '${c.member.element} ${c.member.family} is down — '
                    'reviving in ${respawnSeconds.round()}s',
        );
        onChanged();
      }
    }
    if (!anyAlive) {
      if (isRaid) {
        // No free reset: the attempt is over. The raid window itself stays
        // open for another try, same as retreating.
        _setHint('The party has fallen — the raid drives you out', 4.0);
        onRaidWiped?.call();
        return;
      }
      _resetRun();
      return;
    }
    final a = active;
    if (a != null && !a.alive) {
      final next = creatures.indexWhere((c) => c.alive);
      if (next >= 0) {
        activeIndex = next;
        flightActive = false;
        onChanged();
      }
    }
  }

  void _updateCombat(double dt) {
    for (var i = 0; i < combatCompanions.length; i++) {
      final comp = combatCompanions[i];
      comp.basicCooldown = (comp.basicCooldown - dt).clamp(0.0, 100.0);
      // Horn rule (per the authored spec): the special's cooldown does NOT
      // tick while the ability is mid-execution (wind-up, dash, brew) —
      // it starts counting only after the sequence fully finishes.
      final hornBusy =
          comp.windUpTimer > 0 ||
          comp.chargeTimer > 0 ||
          comp.hornPostDashWindUpTimer > 0;
      if (!hornBusy) {
        comp.specialCooldown = (comp.specialCooldown - dt).clamp(0.0, 100.0);
      }
      if (comp.hitFlash > 0) comp.hitFlash -= dt;
      if (comp.invincibleTimer > 0) comp.invincibleTimer -= dt;
      if (comp.basicHasteTimer > 0) comp.basicHasteTimer -= dt;
      if (comp.damageAmpTimer > 0) comp.damageAmpTimer -= dt;
      if (comp.pipSpiritEmpowerTimer > 0) comp.pipSpiritEmpowerTimer -= dt;
      if (comp.hornSpecialActiveWindow > 0) comp.hornSpecialActiveWindow -= dt;
      if (comp.kinLightningChargeTimer > 0) {
        comp.kinLightningChargeTimer -= dt;
      }
      if (comp.pipSteamWindowTimer > 0) {
        comp.pipSteamWindowTimer -= dt;
      }
      // Kin blessing regen (set by _applySpecialSupportEffects).
      if (comp.blessingTimer > 0) {
        comp.blessingTimer -= dt;
        if (i < creatures.length) {
          _healCreature(creatures[i], comp, comp.blessingHealPerTick * dt);
        }
      }
    }
    _updateHornCasts(dt);
    _updateKinAutoCharges(dt);
    for (final beam in _kinBeams) {
      beam.life -= dt;
    }
    _kinBeams.removeWhere((b) => b.dead);
    _updateCombatEnemies(dt);
    _updateCombatProjectiles(dt);
    _updateWingBeams(dt);
    _updateIdleCompanionAttacks();
    _updateIdleCompanionMovement(dt, currentRoom);
    damageNumbers.update(dt);
    _updateRaidFightTimer(dt);
    _updateRaidDeath(dt);
    _updateRaidPhases();
    final guardian = currentRoom.guardian;
    if (guardian != null &&
        _guardianEnemy != null &&
        (_guardianEnemy!.isDead || _guardianEnemy!.hp <= 0) &&
        !hasStar(guardian.starIndex)) {
      earnStar(guardian.starIndex);
      if (!isRaid) _setHint('The guardian is vanquished');
    }
    for (final e in combatEnemies) {
      if (!e.isDead && e.hp > 0) continue;
      final big = identical(e, _guardianEnemy) || e.isElite;
      _spawnAlchemyBurst(
        e.position,
        producedElement: e.element,
        unstable: big,
        particleCount: big ? 30 : 12,
        intensity: big ? 1.3 : 0.65,
      );
    }
    combatEnemies.removeWhere((e) => e.isDead || e.hp <= 0);
    _activeWingBeams.removeWhere((b) => b.dead);
  }

  int? _nearestLivingCreatureIndex(Offset from) {
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < creatures.length; i++) {
      if (!creatures[i].alive) continue;
      final d = (creatures[i].position - from).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Floaty hover-and-dive steering (shared module). Enemies orbit a hover
  /// ring around the nearest living party member, telegraph, then dive; on
  /// impact they drift back out instead of grinding on contact. The guardian
  /// uses the same machine with wider, slower arcs and a heavier dive.
  void _updateCombatEnemies(double dt) {
    if (creatures.isEmpty) return;
    // Snare fields (ice walls, vines, trap sigils): stationary projectiles
    // with a snareRadius slow enemies standing inside them — same rule as
    // survival's control buckets.
    final snares = <Projectile>[
      for (final p in combatProjectiles)
        if (p.stationary && p.snareRadius > 0) p,
    ];
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      if (enemy.hitFlash > 0) enemy.hitFlash -= dt;
      // Mask+Blood permanent drain: tagged enemies bleed every frame; the
      // drained HP heals the party (survival splits it the same way).
      if (enemy.maskBloodDrainSlot != null && !enemy.isDead) {
        final drainPerSec = max(2.0, enemy.maxHp * 0.06);
        final before = enemy.hp;
        _damageEnemyDirect(
          enemy,
          drainPerSec * dt,
          sourceSlot: enemy.maskBloodDrainSlot,
        );
        final drained = before - max(0.0, enemy.hp);
        if (drained > 0) _healAllCreatures(drained * 0.35);
        if (_combatRng.nextDouble() < dt * 2.0) {
          _spawnHitSpark(enemy.position, elementColor('Blood'));
        }
      }
      // Pip+Mud trail: tagged enemies drop a slowing puff every 0.42s.
      if (enemy.pipMudTrail) {
        enemy.pipMudTrailTimer -= dt;
        if (enemy.pipMudTrailTimer <= 0) {
          enemy.pipMudTrailTimer = 0.42;
          combatProjectiles.add(
            Projectile(
              position: enemy.position,
              angle: 0,
              element: 'Mud',
              damage: 0,
              life: 5.5,
              speedMultiplier: 0,
              stationary: true,
              piercing: true,
              radiusMultiplier: 1.1,
              visualScale: 1.0,
              visualStyle: ProjectileVisualStyle.sigil,
              abilityFamily: 'pip',
              tickEffect: AbilityEffectKind.slow,
              effectPower: 1.0,
              effectRadius: 38,
              effectDuration: 1.2,
            ),
          );
        }
      }
      for (final snare in snares) {
        if ((snare.position - enemy.position).distance <= snare.snareRadius) {
          enemy.slowTimer = max(enemy.slowTimer, 0.2);
          enemy.slowMultiplier = min(
            enemy.slowMultiplier,
            snare.snareMoveMultiplier.clamp(0.1, 1.0).toDouble(),
          );
        }
      }
      if (enemy.slowTimer > 0) enemy.slowTimer -= dt;
      if (enemy.maneRootTimer > 0) enemy.maneRootTimer -= dt;
      if (enemy.hornPlantRootTimer > 0) enemy.hornPlantRootTimer -= dt;
      if (enemy.knockbackVelocity.distanceSquared > 0.1) {
        enemy.position += enemy.knockbackVelocity * dt;
        enemy.knockbackVelocity *= 0.86;
      }
      enemy.attackCooldown = max(0, enemy.attackCooldown - dt);

      final isGuardian = identical(enemy, _guardianEnemy);
      // The guardian holds its arena: freeze it while the party is elsewhere.
      if (isGuardian && currentRoom.guardian == null) continue;
      // Spirit (§7): Wraithord is solid in one world at a time. Out of phase
      // it does not act at all — its blows pass through you.
      if (isGuardian && _isWake && !_wraithInPhase) continue;

      // Lull: the Roc LANDS. Steering pauses and it perches — touchdown is
      // the readable strike window, body language instead of color-reading.
      if (isGuardian && guardianVulnerable) {
        final perch = enemy.flightSteering;
        if (perch != null) {
          perch.diving = false;
          perch.windupTimer = 0;
          perch.velocity =
              perch.velocity * pow(0.05, dt).toDouble() + Offset(0, 26 * dt);
          enemy.position = _clampToBounds(
            enemy.position + perch.velocity * dt,
            currentRoom,
          );
        }
        continue;
      }

      final m = enemy.flightSteering ??= FlightSteeringState(_combatRng);
      m.retargetTimer -= dt;
      final clampedTarget = m.targetIndex.clamp(0, creatures.length - 1);
      if (m.retargetTimer <= 0 || !creatures[clampedTarget].alive) {
        m.retargetTimer = 1.1 + _combatRng.nextDouble() * 1.2;
        m.targetIndex =
            _nearestLivingCreatureIndex(enemy.position) ?? activeIndex;
      }
      final targetIndex = m.targetIndex.clamp(0, creatures.length - 1);
      final targetCreature = creatures[targetIndex];
      var toTarget = targetCreature.position - enemy.position;

      // Taunt beacons (pip Crystal shards, horn fire trails) hijack the
      // steering of enemies inside their pull radius — strongest pull wins.
      Projectile? taunt;
      var tauntScore = 0.0;
      for (final tp in combatProjectiles) {
        if (!tp.stationary || tp.tauntRadius <= 0 || tp.tauntStrength <= 0) {
          continue;
        }
        final d = (tp.position - enemy.position).distance;
        if (d > tp.tauntRadius) continue;
        final score = tp.tauntStrength * (1.0 - d / tp.tauntRadius);
        if (score > tauntScore) {
          tauntScore = score;
          taunt = tp;
        }
      }
      if (taunt != null) {
        toTarget = taunt.position - enemy.position;
        // Decoys soak contact: enemies grinding on the beacon burn its
        // pool down instead of attacking the party.
        if (taunt.decoy &&
            toTarget.distance <= enemy.radius + 26 &&
            enemy.attackCooldown <= 0) {
          enemy.attackCooldown = 0.8;
          taunt.decoyHp -= enemy.damage;
          _spawnHitSpark(taunt.position, elementColor(taunt.element ?? 'Air'));
          if (taunt.decoyHp <= 0) taunt.life = 0;
        }
      }

      final profile = isGuardian
          ? FlightSteeringProfile.dungeonGuardian
          : enemy.conduct == EnemyConduct.stalk
          ? FlightSteeringProfile.dungeonPouncer
          : FlightSteeringProfile.dungeonWisp;
      final tick = tickFlightSteering(
        state: m,
        profile: profile,
        toTarget: toTarget,
        speed: enemy.effectiveSpeed,
        contactRange: enemy.radius + _radius + 4,
        dt: dt,
        rng: _combatRng,
      );

      if (tick.impact &&
          targetIndex < combatCompanions.length &&
          enemy.attackCooldown <= 0) {
        final comp = combatCompanions[targetIndex];
        if (comp.invincibleTimer <= 0) {
          // Dive damage is a FRACTION of the victim's pool (survival enemy
          // damage numbers are sized for survival HP pools and round to
          // nothing against dungeon companions): a wisp dive takes ~9%,
          // the Roc ~17%. Horn shields soak it first.
          final fraction = (0.045 + enemy.damage * 0.005)
              .clamp(0.05, 0.2)
              .toDouble();
          var dmg = max(1, (comp.maxHp * fraction).round());
          if (comp.shieldHp > 0) {
            final absorbed = min(comp.shieldHp, dmg);
            comp.shieldHp -= absorbed;
            dmg -= absorbed;
          }
          if (dmg > 0) {
            comp.currentHp = (comp.currentHp - dmg).clamp(0, comp.maxHp);
            // Lightning horn reactive guard: damage taken during the dash
            // or storm brew is absorbed into the coming chain discharge.
            if (comp.member.family.toLowerCase() == 'horn' &&
                comp.member.element == 'Lightning' &&
                (comp.chargeTimer > 0 ||
                    comp.windUpTimer > 0 ||
                    comp.hornPostDashWindUpTimer > 0)) {
              comp.hornLightningAbsorbed += dmg.toDouble();
            }
            // A landed dive on the echo-carrier tears the echo loose — it
            // drifts back to its resting place (carrying is a commitment).
            if (targetIndex == activeIndex && carriedCloudId != null) {
              _spawnAlchemyBurst(
                creatures[targetIndex].position + const Offset(0, -30),
                producedElement: 'Air',
                reagentElements: const ['Spirit'],
                unstable: true,
                particleCount: 14,
                intensity: 0.8,
              );
              carriedCloudId = null;
              carriedCloudType = null;
              _cloudPickupCooldown = 1.2;
              _setHint(
                'The wisp tears the echo loose — it drifts back to rest!',
                2.8,
              );
            }
          }
          comp.hitFlash = 0.22;
        }
        enemy.attackCooldown = 0.45;
      }

      enemy.position += tick.velocity * dt;
      if (tick.velocity.distanceSquared > 16) {
        enemy.angle = atan2(tick.velocity.dy, tick.velocity.dx);
      } else {
        final d = toTarget.distance;
        if (d > 0.001) enemy.angle = atan2(toTarget.dy, toTarget.dx);
      }
      // The Roc sheds white feathers along its dives.
      if (isGuardian &&
          (enemy.flightSteering?.diving ?? false) &&
          _combatRng.nextDouble() < 0.5) {
        final jx = (_combatRng.nextDouble() - 0.5) * 40;
        final jy = (_combatRng.nextDouble() - 0.5) * 30;
        _alchemyParticles.add(
          _AlchemyParticle(
            position: enemy.position + Offset(jx, jy),
            velocity: Offset(
              (_combatRng.nextDouble() - 0.5) * 34,
              -18 - _combatRng.nextDouble() * 26,
            ),
            color: const Color(0xFFF4FAFF),
            maxLife: 0.6,
            size: 2.4,
          ),
        );
      }

      // Gentle separation so wisps don't stack into one blob.
      for (final other in combatEnemies) {
        if (identical(other, enemy) || other.isDead) continue;
        final away = enemy.position - other.position;
        final d = away.distance;
        final minD = enemy.radius + other.radius + 6;
        if (d > 0.001 && d < minD) {
          enemy.position += away / d * (minD - d) * min(1.0, dt * 9) * 0.5;
        }
      }

      if (!currentRoom.bounds.inflate(80).contains(enemy.position)) {
        enemy.position = _clampToBounds(enemy.position, currentRoom);
      }
    }
  }

  /// Mane+Lightning sigil orb in transit: flies to its scattered target,
  /// then blooms into a stationary shock field (ported from survival).
  bool _updateManeLightningOrbTransfer(Projectile p, double dt) {
    if (p.abilityFamily != 'mane' ||
        p.element != 'Lightning' ||
        p.effectStacks != 1) {
      return false;
    }
    final target = p.cachedHomingTarget;
    if (target == null) return false;
    final toTarget = target - p.position;
    final dist = toTarget.distance;
    final step = Projectile.speed * max(0.25, p.speedMultiplier) * dt;
    if (dist <= step || dist < 8) {
      combatProjectiles.add(
        Projectile(
          position: target,
          angle: 0,
          element: 'Lightning',
          damage: 0,
          life: 4.0,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: 0.95,
          visualScale: 1.05,
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: p.sourceSlotIndex,
          abilityFamily: 'mane',
          tickEffect: AbilityEffectKind.zoneDamage,
          effectPower: p.effectPower,
          effectRadius: p.effectRadius.clamp(36.0, 48.0).toDouble(),
          effectDuration: p.effectDuration,
          effectStacks: 2,
        ),
      );
      _spawnAlchemyBurst(
        target,
        producedElement: 'Lightning',
        unstable: true,
        particleCount: 10,
        intensity: 0.6,
      );
      p.life = 0;
      return true;
    }
    final dir = toTarget / dist;
    p.angle = atan2(dir.dy, dir.dx);
    p.position += dir * step;
    return true;
  }

  void _updateCombatProjectiles(double dt) {
    for (var i = combatProjectiles.length - 1; i >= 0; i--) {
      final p = combatProjectiles[i];
      // Sigil orbs own their motion until they bloom.
      if (_updateManeLightningOrbTransfer(p, dt)) {
        p.life -= dt;
        if (p.life <= 0) combatProjectiles.removeAt(i);
        continue;
      }
      if (p.abilityGrowthTimer > 0) p.abilityGrowthTimer -= dt;
      // Attached auras (mask dust shields) ride along with their ally.
      if (p.attachedToSlot != -2 && p.stationary) {
        final hostIndex = combatCompanions.indexWhere(
          (c) => c.slotIndex == p.attachedToSlot,
        );
        if (hostIndex >= 0 &&
            hostIndex < creatures.length &&
            creatures[hostIndex].alive) {
          p.position = creatures[hostIndex].position;
        } else {
          p.life = min(p.life, 0.4); // host down — the aura fades out
        }
      }
      if (p.homing) {
        final target = _nearestEnemyPosition(p.position);
        if (target != null) {
          final desired = atan2(
            target.dy - p.position.dy,
            target.dx - p.position.dx,
          );
          var diff = desired - p.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          final maxTurn = p.homingStrength * dt;
          p.angle += diff.clamp(-maxTurn, maxTurn);
        }
      }

      if (p.orbitCenter != null && (p.holdOrbit || p.orbitTime > 0)) {
        if (!p.holdOrbit) p.orbitTime -= dt;
        p.orbitAngle += p.orbitSpeed * dt;
        p.position =
            p.orbitCenter! +
            Offset(cos(p.orbitAngle), sin(p.orbitAngle)) * p.orbitRadius;
        if (!p.holdOrbit && p.orbitTime <= 0) {
          p.angle = p.orbitAngle;
          p.orbitCenter = null;
        }
      } else if (!p.stationary) {
        final speed = Projectile.speed * p.speedMultiplier;
        p.position += Offset(cos(p.angle), sin(p.angle)) * speed * dt;
      }

      if (p.trailInterval > 0 && !p.stationary && p.orbitCenter == null) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          combatProjectiles.add(
            Projectile(
              position: p.position,
              angle: 0,
              element: p.element,
              damage: p.trailDamage,
              life: p.trailLife,
              stationary: true,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.2,
              abilityFamily: p.abilityFamily,
              hitEffect: p.tickEffect == AbilityEffectKind.none
                  ? p.hitEffect
                  : p.tickEffect,
              tickEffect: p.tickEffect,
              effectPower: p.effectPower * 0.55,
              effectRadius: p.effectRadius,
              effectDuration: p.effectDuration,
            ),
          );
        }
      }

      if (p.tickEffect != AbilityEffectKind.none &&
          p.effectRadius > 0 &&
          p.stationary) {
        p.tickTimer += dt;
        if (p.tickTimer >= 0.35) {
          p.tickTimer -= 0.35;
          _applyProjectileAreaEffect(p, p.tickEffect);
        }
        // Ambient per-element wisps so the painted zone feels alive (embers,
        // bubbles, rain, etc.). Pool-capped so it never floods the frame.
        if (_abilityVfx.length < 130) {
          _spawnZoneParticles(p);
        }
      }

      if (p.clusterCount > 0 && !p.clustered && p.life < 0.75) {
        p.clustered = true;
        for (var ci = 0; ci < p.clusterCount; ci++) {
          final a = ci * pi * 2 / p.clusterCount;
          combatProjectiles.add(
            Projectile(
              position: p.position + Offset(cos(a), sin(a)) * 10,
              angle: a,
              element: p.element,
              damage: p.clusterDamage,
              life: 1.5,
              speedMultiplier: 0.7,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.0,
              visualStyle: p.visualStyle,
              sourceSlotIndex: p.sourceSlotIndex,
              abilityFamily: p.abilityFamily,
              hitEffect: p.hitEffect,
              killEffect: p.killEffect,
              pierceEffect: p.pierceEffect,
              tickEffect: p.tickEffect,
              effectPower: p.effectPower * 0.65,
              effectRadius: p.effectRadius,
              effectDuration: p.effectDuration,
              effectCount: p.effectCount,
            ),
          );
        }
      }

      p.life -= dt;
      if (p.life <= 0) {
        combatProjectiles.removeAt(i);
        continue;
      }

      final hitRadius = Projectile.radius * p.radiusMultiplier;
      var consumed = false;
      for (final enemy in combatEnemies) {
        if (enemy.isDead) continue;
        final hitR = enemy.radius + hitRadius;
        if ((p.position - enemy.position).distanceSquared >= hitR * hitR) {
          continue;
        }
        // Mane+Plant roots BEFORE damage so a one-shot still detonates the
        // rooted-kill AOE (survival's preRoot ordering).
        if (p.piercing && p.abilityFamily == 'mane' && p.element == 'Plant') {
          _resolveAbilityPierce(p, enemy);
        }
        final wasDead = enemy.isDead;
        final isPipSpecialDart =
            p.abilityFamily == 'pip' &&
            p.visualStyle == ProjectileVisualStyle.dart;
        _damageEnemyDirect(
          enemy,
          p.damage,
          sourceSlot: p.sourceSlotIndex,
          fromPipSpecial: isPipSpecialDart,
        );
        final killed = !wasDead && enemy.isDead;
        _resolveAbilityHit(p, enemy, killed: killed);
        if (p.piercing) _resolveAbilityPierce(p, enemy);

        // Pip+Water: a kill on the dart's final hit erupts a huge splash
        // scaled by the caster's Beauty.
        if (killed &&
            p.element == 'Water' &&
            p.bounceCount <= 0 &&
            p.sourceSlotIndex != null) {
          final src = _combatCompanionForSlot(p.sourceSlotIndex!);
          if (src != null && src.member.family.toLowerCase() == 'pip') {
            final splashScale =
                (1.0 + (src.member.statBeauty.clamp(0.5, 8.0) - 3.0) * 0.10)
                    .clamp(0.85, 1.35);
            _damageEnemiesNear(
              enemy.position,
              160 * splashScale,
              p.damage * 2.4 * splashScale,
              sourceSlot: p.sourceSlotIndex,
              exclude: enemy,
            );
            _spawnHitSpark(enemy.position, elementColor('Water'));
          }
        }
        // Pip+Mud: tag the enemy to drop slowing mud puffs as it moves.
        if (!killed &&
            p.abilityFamily.isEmpty &&
            p.element == 'Mud' &&
            p.sourceSlotIndex != null) {
          final src = _combatCompanionForSlot(p.sourceSlotIndex!);
          if (src != null && src.member.family.toLowerCase() == 'pip') {
            enemy.pipMudTrail = true;
          }
        }
        // Pip+Poison: special darts weave a poison-line web between
        // consecutive impact points.
        if (p.abilityFamily == 'pip' &&
            p.visualStyle == ProjectileVisualStyle.dart &&
            p.element == 'Poison' &&
            p.sourceSlotIndex != null) {
          final src = _combatCompanionForSlot(p.sourceSlotIndex!);
          if (src != null && src.member.family.toLowerCase() == 'pip') {
            final prev = src.lastPipPoisonHitPos;
            if (prev != null) {
              final dx = enemy.position.dx - prev.dx;
              final dy = enemy.position.dy - prev.dy;
              final dist = sqrt(dx * dx + dy * dy);
              if (dist < 600) {
                final segCount = (dist / 36).ceil().clamp(1, 18);
                for (var seg = 0; seg < segCount; seg++) {
                  final t = (seg + 0.5) / segCount;
                  combatProjectiles.add(
                    Projectile(
                      position: Offset(prev.dx + dx * t, prev.dy + dy * t),
                      angle: 0,
                      element: 'Poison',
                      damage: 0,
                      life: 6.5,
                      speedMultiplier: 0,
                      stationary: true,
                      piercing: true,
                      radiusMultiplier: 0.95,
                      visualScale: 0.85,
                      visualStyle: ProjectileVisualStyle.sigil,
                      sourceSlotIndex: p.sourceSlotIndex,
                      abilityFamily: 'pip',
                      tickEffect: AbilityEffectKind.poison,
                      effectPower: p.damage * 0.22,
                      effectRadius: 32,
                      effectDuration: 1.5,
                    ),
                  );
                }
              }
            }
            src.lastPipPoisonHitPos = enemy.position;
          }
        }
        // Mane+Mud: first hit splits into ten smaller fragments.
        if (p.abilityFamily == 'mane' &&
            p.element == 'Mud' &&
            !p.clustered &&
            p.effectStacks == 0) {
          p.clustered = true;
          for (var fi = 0; fi < 10; fi++) {
            combatProjectiles.add(
              Projectile(
                position: enemy.position,
                angle: fi * (pi * 2 / 10),
                element: 'Mud',
                damage: p.damage * 0.45,
                life: 1.0,
                speedMultiplier: 1.4,
                radiusMultiplier: max(p.radiusMultiplier * 0.55, 0.7),
                visualScale: max(p.visualScale * 0.55, 0.7),
                piercing: false,
                visualStyle: ProjectileVisualStyle.slash,
                sourceSlotIndex: p.sourceSlotIndex,
                abilityFamily: 'mane',
                hitEffect: AbilityEffectKind.slow,
                effectPower: p.effectPower * 0.6,
                effectRadius: 40,
                effectDuration: 1.5,
                effectStacks: 1,
              ),
            );
          }
          consumed = true;
        }
        _spawnProjectileHitSpark(p);
        if (_isAnyKinLightningChargeActive() && p.sourceSlotIndex != null) {
          _triggerChainLightning(
            sourceEnemy: enemy,
            baseDamage: p.damage,
            remainingChains: 2,
            sourceSlot: p.sourceSlotIndex,
          );
        }

        // Ricochet (pip): bounce to the nearest clustered target, shedding
        // damage per hop (Lightning sheds less — its ricochet identity).
        final isPipSpecialProjectile = p.abilityFamily == 'pip';
        if (p.bounceCount > 0) {
          p.bounceCount--;
          if (isPipSpecialProjectile) p.pierceCount++;
          CosmicSurvivalEnemy? next;
          var bestD = 110.0;
          for (final other in combatEnemies) {
            if (other.isDead || identical(other, enemy)) continue;
            final d = (other.position - enemy.position).distance;
            if (d < bestD) {
              bestD = d;
              next = other;
            }
          }
          if (next != null) {
            p.angle = atan2(
              next.position.dy - p.position.dy,
              next.position.dx - p.position.dx,
            );
            p.life = isPipSpecialProjectile
                ? min(max(p.life, 0.18), kPipRicochetPostHitLife)
                : max(p.life, 0.45);
            final falloff = (p.element == 'Lightning') ? 0.85 : 0.70;
            p.damage = p.damage * falloff;
            p.speedMultiplier = max(0.6, p.speedMultiplier * 0.92);
          } else {
            p.bounceCount = 0;
            if (isPipSpecialProjectile) consumed = true;
          }
        } else if (!p.piercing) {
          consumed = true;
        } else {
          p.pierceCount++;
          if (isPipSpecialProjectile && p.pierceCount >= kPipMaxPierceHits) {
            consumed = true;
          }
        }
        if (consumed) break;
      }
      if (consumed && i < combatProjectiles.length) {
        combatProjectiles.removeAt(i);
      }
    }
  }

  void _activateWingBeams(
    List<WingBeamEffect> beams, {
    required int sourceSlotIndex,
    required Offset origin,
    required double angle,
  }) {
    for (final descriptor in beams) {
      _activeWingBeams.add(
        _DungeonWingBeam(
          descriptor: descriptor,
          sourceSlotIndex: sourceSlotIndex,
          origin: origin,
          angle: angle,
        ),
      );
    }
  }

  void _updateWingBeams(double dt) {
    for (final beam in _activeWingBeams) {
      if (beam.dead) continue;
      final comp = _combatCompanionForSlot(beam.sourceSlotIndex);
      if (comp != null && !comp.isDead) {
        beam.origin = comp.position;
        beam.angle = comp.angle;
      }

      beam.life -= dt;
      if (beam.chargeTimer > 0) {
        beam.chargeTimer = max(0, beam.chargeTimer - dt);
        if (beam.chargeTimer > 0) continue;
        beam.tickTimer = 0;
      }

      beam.tickTimer -= dt;
      if (beam.tickTimer > 0) continue;
      beam.tickTimer += max(0.05, beam.descriptor.tickInterval);
      _resolveWingBeamTick(beam);
    }
  }

  void _resolveWingBeamTick(_DungeonWingBeam beam) {
    final descriptor = beam.descriptor;
    final pulseDamage = descriptor.tickEffect == AbilityEffectKind.chargeBlast
        ? descriptor.damagePerTick * 8.0
        : descriptor.damagePerTick;
    final effectProjectile = Projectile(
      position: beam.origin,
      angle: beam.angle,
      element: descriptor.element,
      damage: descriptor.effectPower,
      life: 0.1,
      sourceSlotIndex: beam.sourceSlotIndex,
      abilityFamily: 'wing',
      effectPower: descriptor.effectPower,
      effectRadius: max(descriptor.radius, descriptor.width * 8),
      effectDuration: descriptor.effectDuration,
      hitEffect: descriptor.tickEffect,
    );

    if (descriptor.targetPolicy == WingBeamTargetPolicy.ring &&
        descriptor.radius > 0) {
      for (final enemy in combatEnemies) {
        if (enemy.isDead) continue;
        if ((enemy.position - beam.origin).distance > descriptor.radius) {
          continue;
        }
        _damageEnemyFromBeam(enemy, pulseDamage);
        _applyProjectileEffect(effectProjectile, enemy, descriptor.tickEffect);
      }
      return;
    }

    final end = _wingBeamEnd(beam);
    final radius = max(10.0, descriptor.width * 1.35);
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      final distance = _distanceToSegment(enemy.position, beam.origin, end);
      if (distance > enemy.radius + radius) continue;
      _damageEnemyFromBeam(enemy, pulseDamage);
      _applyProjectileEffect(effectProjectile, enemy, descriptor.tickEffect);
    }

    if (descriptor.healPerTick > 0) {
      final comp = _combatCompanionForSlot(beam.sourceSlotIndex);
      if (comp != null) {
        comp.currentHp = min(
          comp.maxHp,
          comp.currentHp + descriptor.healPerTick.round(),
        );
      }
    }
  }

  void _damageEnemyFromBeam(CosmicSurvivalEnemy enemy, double damage) {
    final dealt = damage * _enemyDamageTakenScale(enemy);
    _spawnDamageNumber(enemy, dealt);
    enemy.hp -= dealt;
    enemy.hitFlash = 0.18;
    if (enemy.hp <= 0) enemy.isDead = true;
  }

  /// The Roc shrugs off most ranged damage while raging; the lull (the same
  /// window that allows utility strikes) is the burst window.
  double _enemyDamageTakenScale(CosmicSurvivalEnemy enemy) {
    // Spirit (§7): nothing reaches Wraithord while it is standing in the
    // other world — the fight is harmless in BOTH directions until you match
    // the body it is wearing.
    if (_isWake && identical(enemy, _guardianEnemy) && !_wraithInPhase) {
      return 0;
    }
    return identical(enemy, _guardianEnemy) && !guardianVulnerable ? 0.35 : 1.0;
  }

  Offset _wingBeamEnd(_DungeonWingBeam beam) {
    final descriptor = beam.descriptor;
    final target = switch (descriptor.targetPolicy) {
      WingBeamTargetPolicy.lowestHealthEnemy => _lowestHealthEnemyPosition(
        beam.origin,
        descriptor.range,
      ),
      WingBeamTargetPolicy.nearestEnemy => _nearestEnemyPosition(
        beam.origin,
        maxRange: descriptor.range,
      ),
      _ => null,
    };
    if (target != null) return target;
    return beam.origin +
        Offset(cos(beam.angle), sin(beam.angle)) * descriptor.range;
  }

  Offset? _lowestHealthEnemyPosition(Offset from, double maxRange) {
    CosmicSurvivalEnemy? best;
    var bestHealth = double.infinity;
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      if ((enemy.position - from).distance > maxRange) continue;
      if (enemy.hp < bestHealth) {
        bestHealth = enemy.hp;
        best = enemy;
      }
    }
    return best?.position;
  }

  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLen2 <= 0.0001) return (point - a).distance;
    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLen2)
        .clamp(0.0, 1.0)
        .toDouble();
    final closest = a + ab * t;
    return (point - closest).distance;
  }

  Offset? _nearestEnemyPosition(
    Offset from, {
    double maxRange = double.infinity,
  }) {
    CosmicSurvivalEnemy? best;
    var bestDist = maxRange;
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      final d = (enemy.position - from).distance;
      if (d < bestDist) {
        bestDist = d;
        best = enemy;
      }
    }
    return best?.position;
  }

  CosmicSurvivalEnemy? _nearestCombatEnemy(
    Offset from, {
    required double maxRange,
  }) {
    CosmicSurvivalEnemy? best;
    var bestDist = maxRange;
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      final d = (enemy.position - from).distance;
      if (d < bestDist) {
        bestDist = d;
        best = enemy;
      }
    }
    return best;
  }

  Offset _fallbackAimPoint(
    DungeonCreature creature,
    double range, {
    double minDistance = 110,
  }) {
    final distance = max(minDistance, range);
    final dir = Offset(cos(creature.angle), sin(creature.angle));
    return creature.position + dir * distance;
  }

  void _applyProjectileAreaEffect(
    Projectile projectile,
    AbilityEffectKind effect,
  ) {
    final radius = CosmicAbilityRuntime.projectileEffectRadius(projectile);
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      if ((enemy.position - projectile.position).distance <= radius) {
        _applyProjectileEffect(projectile, enemy, effect);
      }
    }
  }

  void _applyProjectileEffect(
    Projectile projectile,
    CosmicSurvivalEnemy enemy,
    AbilityEffectKind effect,
  ) {
    if (effect == AbilityEffectKind.none || enemy.isDead) return;
    // Survival's _applyAbilityEffectToEnemy, adapted: orb/ship heals become
    // creature heals; flowers (survival's resource) are inert here.
    final origin = projectile.position;
    final rawPower = CosmicAbilityRuntime.projectileEffectPower(projectile);
    final rawRadius = CosmicAbilityRuntime.projectileEffectRadius(projectile);
    final effectPower = rawPower > 0 ? rawPower : 4.0;
    final effectRadius = rawRadius > 0 ? rawRadius : 80.0;
    final effectDuration = projectile.effectDuration > 0
        ? projectile.effectDuration
        : 1.5;
    final slot = projectile.sourceSlotIndex;
    switch (effect) {
      case AbilityEffectKind.knockback:
        final dir = enemy.position - origin;
        final dist = dir.distance;
        if (dist > 0.01) {
          enemy.knockbackVelocity +=
              (dir / dist) * (160.0 + effectPower * 8.0).clamp(120.0, 520.0);
        }
        break;
      case AbilityEffectKind.slow:
      case AbilityEffectKind.freeze:
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.survivalCrowdControlDuration(
            effect,
            effectDuration,
          ),
        );
        enemy.slowMultiplier = min(
          enemy.slowMultiplier,
          CosmicAbilityRuntime.survivalSlowMultiplier(effect),
        );
        if (effect == AbilityEffectKind.freeze) {
          enemy.knockbackVelocity = Offset.zero;
        }
        break;
      case AbilityEffectKind.root:
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.survivalCrowdControlDuration(
            effect,
            effectDuration,
          ),
        );
        enemy.slowMultiplier = min(
          enemy.slowMultiplier,
          CosmicAbilityRuntime.survivalSlowMultiplier(effect),
        );
        enemy.maneRootTimer = max(enemy.maneRootTimer, enemy.slowTimer);
        _damageEnemyDirect(enemy, effectPower, sourceSlot: slot);
        enemy.knockbackVelocity = Offset.zero;
        break;
      case AbilityEffectKind.stun:
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.survivalCrowdControlDuration(
            effect,
            effectDuration,
          ),
        );
        enemy.slowMultiplier = min(
          enemy.slowMultiplier,
          CosmicAbilityRuntime.survivalSlowMultiplier(effect),
        );
        enemy.attackCooldown = max(enemy.attackCooldown, effectDuration);
        break;
      case AbilityEffectKind.suppressShooting:
        enemy.disorientTimer = max(enemy.disorientTimer, effectDuration);
        enemy.attackCooldown = max(enemy.attackCooldown, effectDuration * 0.4);
        break;
      case AbilityEffectKind.burn:
      case AbilityEffectKind.poison:
      case AbilityEffectKind.zoneDamage:
      case AbilityEffectKind.geyser:
        _damageEnemyDirect(enemy, effectPower, sourceSlot: slot);
        if (effect == AbilityEffectKind.geyser) {
          enemy.knockbackVelocity += const Offset(0, -140);
        }
        break;
      case AbilityEffectKind.execute:
      case AbilityEffectKind.refraction:
      case AbilityEffectKind.chargeBlast:
        _damageEnemyDirect(
          enemy,
          CosmicAbilityRuntime.directDamageForEffect(
            effect,
            power: effectPower,
            targetHp: enemy.hp,
            targetHpFraction: enemy.hpFraction,
          ),
          sourceSlot: slot,
        );
        break;
      case AbilityEffectKind.splash:
      case AbilityEffectKind.split:
      case AbilityEffectKind.chain:
        _damageEnemiesNear(
          enemy.position,
          effectRadius,
          effectPower * CosmicAbilityRuntime.splashMultiplier(effect),
          sourceSlot: slot,
          exclude: enemy,
        );
        break;
      case AbilityEffectKind.pull:
      case AbilityEffectKind.blackHole:
        for (final other in combatEnemies) {
          if (other.isDead) continue;
          final dir = origin - other.position;
          final dist = dir.distance;
          if (dist <= 0.01 || dist > effectRadius) continue;
          other.position += (dir / dist) * min(28.0, 720.0 / dist);
          other.slowTimer = max(other.slowTimer, effectDuration);
          other.slowMultiplier = min(other.slowMultiplier, 0.25);
          if (effect == AbilityEffectKind.blackHole &&
              other.hpFraction <= 0.18) {
            _damageEnemyDirect(other, other.hp + 1, sourceSlot: slot);
          }
        }
        break;
      case AbilityEffectKind.leech:
      case AbilityEffectKind.zoneHeal:
        _healSourceCreature(slot, effectPower.toDouble());
        if (slot == null) {
          final comp = activeCombat;
          final creature = active;
          if (comp != null && creature != null) {
            _healCreature(creature, comp, effectPower.toDouble());
          }
        }
        break;
      case AbilityEffectKind.buff:
      case AbilityEffectKind.cooldownRefund:
        final comp = _combatCompanionForSlot(slot);
        if (comp != null) {
          comp.basicHasteTimer = max(comp.basicHasteTimer, effectDuration);
          comp.basicHasteMultiplier = min(comp.basicHasteMultiplier, 0.72);
          if (effect == AbilityEffectKind.cooldownRefund) {
            comp.specialCooldown = max(0, comp.specialCooldown - 0.45);
          }
          // Mask+Ice pillar passive: broadcast a damage amp to allies in
          // range of the trap.
          if (comp.member.family.toLowerCase() == 'mask' &&
              comp.member.element == 'Ice') {
            for (final ally in combatCompanions) {
              if (ally.isDead) continue;
              if ((ally.position - origin).distance > effectRadius * 1.4) {
                continue;
              }
              ally.damageAmpTimer = max(ally.damageAmpTimer, effectDuration);
              ally.damageAmpMultiplier = max(ally.damageAmpMultiplier, 2.4);
            }
          }
        }
        break;
      case AbilityEffectKind.taunt:
        enemy.slowTimer = max(enemy.slowTimer, effectDuration * 0.5);
        break;
      case AbilityEffectKind.carry:
        final dir = enemy.position - origin;
        final dist = dir.distance;
        if (dist > 0.01) {
          enemy.position = _clampToBounds(
            enemy.position + (dir / dist) * 18.0,
            currentRoom,
          );
        }
        break;
      case AbilityEffectKind.alchemyBonus:
      case AbilityEffectKind.flower:
        // Survival-only resource pickups — inert in dungeons.
        break;
      case AbilityEffectKind.none:
        break;
    }
  }

  bool _isAnyKinLightningChargeActive() {
    for (final comp in combatCompanions) {
      if (comp.kinLightningChargeTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Lightning') {
        return true;
      }
    }
    return false;
  }

  CosmicSurvivalCompanion? _combatCompanionForSlot(int? slotIndex) {
    if (slotIndex == null) return null;
    for (final comp in combatCompanions) {
      if (comp.slotIndex == slotIndex) return comp;
    }
    return null;
  }

  void spawnWispWave({
    required String element,
    required Offset center,
    int count = 3,
    bool unstable = false,
    bool announce = true, // false = the caller's own hint explains the wave
  }) {
    // Hard cap: the consequence layer harasses, it never floods the room.
    final liveWisps = combatEnemies
        .where((e) => !e.isDead && !identical(e, _guardianEnemy))
        .length;
    count = min(count, 10 - liveWisps);
    if (count <= 0) return;
    final wave = unstable ? 5 : 3;
    // Wisps ride the campaign clock too, a touch gentler than guardians.
    final hpScale =
        CosmicSurvivalBalance.enemyWaveHpScale(wave) *
        (1.0 + 0.22 * clearedGuardianCount);
    final damageScale =
        CosmicSurvivalBalance.enemyWaveDamageScale(wave) *
        (1.0 + 0.07 * clearedGuardianCount);
    final speedScale = CosmicSurvivalBalance.enemyWaveSpeedScale(wave);
    for (var i = 0; i < count; i++) {
      final a = i * pi * 2 / max(1, count) + _combatRng.nextDouble() * 0.45;
      final r = 70 + _combatRng.nextDouble() * 46;
      combatEnemies.add(
        CosmicSurvivalEnemy(
          position: center + Offset(cos(a), sin(a)) * r,
          hp: (unstable ? 34 : 24) * hpScale,
          maxHp: (unstable ? 34 : 24) * hpScale,
          speed: (unstable ? 92 : 76) * speedScale,
          damage: (unstable ? 13 : 9) * damageScale,
          radius: unstable ? 15 : 12,
          tier: EnemyTier.wisp,
          element: element,
          conduct: unstable ? EnemyConduct.stalk : EnemyConduct.charge,
          target: CosmicEnemyTarget.companion,
        ),
      );
    }
    if (announce) _setHint('${unstable ? 'Unstable' : element} wisps gather');
    onChanged();
  }

  /// Stage the guardian's ARRIVAL. The combat body is NOT created here — the
  /// cinematic runs first (see [_updateGuardianArrival]) and the thing exists
  /// only once it has landed. Safe to call every frame; guarded throughout.
  void _maybeSpawnGuardianCombat(DungeonRoom room) {
    final g = room.guardian;
    if (g == null || !guardianAwake || hasStar(g.starIndex)) return;
    if (_guardianEnemy != null) return; // live, or downed and awaiting its bank
    if (_guardianArrival >= 0) return; // already falling
    _guardianArrival = 0;
    _shake = _kArrivalShake;
    final mysticName = g.encounter?.mysticId ?? 'The guardian';
    final line = isRaid
        ? 'The raid-maddened guardian descends — bring it down!'
        : '$mysticName descends — use Auto Attack and Ability';
    // A mystic's arrival deserves more than a status line: the screen shows
    // the chrome intro banner (§5.6). The capsule fallback keeps headless
    // runs (and any unwired host) speaking exactly as before.
    final intro = onGuardianIntro;
    if (intro != null) {
      intro(mysticName, line);
    } else {
      _setHint(line);
    }
    onChanged();
  }

  /// Shake while it falls, and a hard spike when it lands.
  static const double _kArrivalShake = 5.0;
  static const double _kImpactShake = 16.0;

  /// The arrival cinematic: the room shakes harder as the mystic drops, and
  /// on IMPACT the combat body spawns under a burst. Runs from the shared
  /// update so it keeps ticking wherever the party is standing.
  void _updateGuardianArrival(double dt, DungeonRoom room) {
    // Shake always decays, arrival or not.
    if (_shake > 0) _shake = max(0, _shake - dt * 26);
    if (_guardianArrival < 0) return;
    final g = room.guardian;
    if (g == null || hasStar(g.starIndex)) {
      // Walked out mid-fall (or it died to something else): forget the beat,
      // so re-entering the chamber plays a whole arrival again.
      if (_guardianEnemy == null) _guardianArrival = -1;
      return;
    }
    if (_guardianArrival >= kGuardianArrivalSeconds) return;
    final was = _guardianArrival;
    _guardianArrival += dt;
    // Ground-shudder ramps through the fall — the thing is getting closer.
    _shake = max(_shake, _kArrivalShake * (was / kGuardianArrivalSeconds));
    if (_guardianArrival < kGuardianArrivalSeconds) return;

    // IMPACT.
    _shake = _kImpactShake;
    _spawnGuardianBody(g);
    // Raikuma takes the grid as it lands (§7): the seize belongs to the
    // arrival, not to the distant beam latch that woke it.
    if (_isCircuit) _seizeCoreTrunk(room);
    _spawnAlchemyBurst(
      g.position,
      producedElement: g.encounter?.element ?? layout.element,
      reagentElements: [layout.element],
      unstable: true,
      particleCount: 30,
      intensity: 1.3,
    );
    onChanged();
  }

  void _spawnGuardianBody(GuardianNode g) {
    final hpScale =
        CosmicSurvivalBalance.enemyWaveHpScale(7) *
        (raid?.hpMul ?? 1.0) *
        progressHpMul;
    final damageScale =
        CosmicSurvivalBalance.enemyWaveDamageScale(7) *
        (raid?.dmgMul ?? 1.0) *
        progressDmgMul;
    // 2026-08-14 balance pass: the pool is [kGuardianBaseHp] (measured
    // against real party DPS — see there) and contact damage 20 → 24. The
    // early guardians read as set-pieces and died like wisps; the strike
    // count caps the fight's length, the pool decides how much of that cap a
    // given team actually spends, and the damage makes those windows cost.
    _guardianEnemy = CosmicSurvivalEnemy(
      position: g.position,
      hp: kGuardianBaseHp * hpScale,
      maxHp: kGuardianBaseHp * hpScale,
      speed: 58,
      damage: 24 * damageScale,
      radius: 38,
      tier: EnemyTier.phantom,
      element: g.encounter?.element ?? 'Air',
      conduct: EnemyConduct.charge,
      target: CosmicEnemyTarget.companion,
      isElite: true,
    );
    combatEnemies.add(_guardianEnemy!);
  }

  /// Raid escalation: each time the guardian's HP crosses a configured
  /// threshold, a wave of lesser storm-spawn joins the fight.
  void _updateRaidPhases() {
    final cfg = raid;
    final g = _guardianEnemy;
    if (cfg == null || g == null || g.isDead) return;
    if (_raidPhaseIndex >= cfg.addPhaseThresholds.length) return;
    final frac = g.maxHp <= 0 ? 0.0 : (g.hp / g.maxHp).clamp(0.0, 1.0);
    if (frac > cfg.addPhaseThresholds[_raidPhaseIndex]) return;
    _raidPhaseIndex++;
    final hpScale =
        CosmicSurvivalBalance.enemyWaveHpScale(7) *
        (1.0 + 0.22 * clearedGuardianCount);
    final damageScale =
        CosmicSurvivalBalance.enemyWaveDamageScale(7) *
        (1.0 + 0.07 * clearedGuardianCount);
    final rng = Random(combatEnemies.length * 31 + _raidPhaseIndex);
    for (var i = 0; i < 4; i++) {
      final angle = (i / 4) * pi * 2 + rng.nextDouble() * 0.8;
      final pos = g.position + Offset(cos(angle), sin(angle)) * 240;
      final b = currentRoom.bounds.deflate(40);
      final spawn = Offset(
        pos.dx.clamp(b.left, b.right),
        pos.dy.clamp(b.top, b.bottom),
      );
      final add = CosmicSurvivalEnemy(
        position: spawn,
        hp: 55 * hpScale,
        maxHp: 55 * hpScale,
        speed: 90,
        damage: 8 * damageScale,
        radius: 13,
        tier: i.isEven ? EnemyTier.wisp : EnemyTier.drone,
        element: g.element,
        conduct: EnemyConduct.stalk,
        target: CosmicEnemyTarget.companion,
      );
      add.flightSteering = FlightSteeringState(rng);
      combatEnemies.add(add);
    }
    _spawnAlchemyBurst(
      g.position,
      producedElement: g.element,
      unstable: true,
      particleCount: 22,
      intensity: 1.1,
    );
    _setHint('The guardian shrieks — storm-spawn answer the call!', 3.0);
  }

  bool activateAutoAttack() {
    final comp = activeCombat;
    final creature = active;
    if (comp == null || creature == null || !creature.alive) return false;
    if (comp.basicCooldown > 0) {
      // CONTROL FEEDBACK, not speech (§5.6): the button answers for itself
      // with its cooldown ring and a refusal pulse — the capsule keeps
      // whatever the room was saying.
      autoDeniedFlash = _deniedFlashSeconds;
      onChanged();
      return false;
    }
    _fireBasicAttack(activeIndex, allowFallbackAim: true);
    onChanged();
    return true;
  }

  /// Fire one basic attack for party slot [index] at the nearest enemy.
  /// Manual taps ([allowFallbackAim]) fire even with no target; idle
  /// companions only shoot when something is actually in range.
  bool _fireBasicAttack(
    int index, {
    bool allowFallbackAim = false,
    double cooldownScale = 1.0,
  }) {
    if (index < 0 ||
        index >= creatures.length ||
        index >= combatCompanions.length) {
      return false;
    }
    final creature = creatures[index];
    final comp = combatCompanions[index];
    if (!creature.alive || comp.isDead || comp.basicCooldown > 0) return false;
    // Manual presses auto-target the nearest enemy ANYWHERE in the room
    // (never fire into empty air while something is on screen); idle
    // companions keep their range gate so they don't snipe across the map.
    final target = _nearestCombatEnemy(
      creature.position,
      maxRange: allowFallbackAim ? double.infinity : comp.attackRange,
    );
    if (target == null && !allowFallbackAim) return false;
    final targetPoint =
        target?.position ?? _fallbackAimPoint(creature, comp.attackRange);
    // Kin auto-attack: charged thin laser instead of regular basics (same
    // as survival). The charge holds the kin still; _updateKinAutoCharges
    // fires the beam when it completes.
    if (comp.member.family.toLowerCase() == 'kin') {
      if (comp.kinAutoChargeTimer > 0) return false; // already charging
      if (target == null) return false; // lasers need a real mark
      comp.kinAutoChargeTimer = 0.001;
      comp.kinAutoChargeTarget = targetPoint;
      comp.kinAutoChargeEnemy = target;
      final toKinTarget = targetPoint - creature.position;
      if (toKinTarget.distance > 0.01) {
        creature.angle = atan2(toKinTarget.dy, toKinTarget.dx);
        comp.angle = creature.angle;
      }
      return true;
    }
    final toTarget = targetPoint - creature.position;
    final angle = toTarget.distance > 0.01
        ? atan2(toTarget.dy, toTarget.dx)
        : creature.angle;
    creature.angle = angle;
    comp.angle = angle;
    comp.basicCooldown = comp.effectiveBasicCooldown * cooldownScale;
    final basics = createFamilyBasicAttack(
      origin: creature.position,
      angle: angle,
      element: comp.member.element,
      family: comp.member.family,
      damage: comp.physAtk.toDouble() * comp.damageAmp,
    );
    for (final projectile in basics) {
      projectile.sourceSlotIndex = comp.slotIndex;
    }
    combatProjectiles.addAll(basics);
    if (comp.member.family.toLowerCase() == 'pip' &&
        comp.member.element == 'Earth') {
      comp.specialCooldown = max(0, comp.specialCooldown - 0.4);
    }
    return true;
  }

  /// Idle party members defend themselves: whenever an enemy drifts into
  /// range they fire their family basic on a slightly relaxed cooldown, so
  /// swap-control puzzling doesn't leave the rest of the team decorative.
  void _updateIdleCompanionAttacks() {
    if (combatEnemies.isEmpty) return;
    for (var i = 0; i < creatures.length && i < combatCompanions.length; i++) {
      if (i == activeIndex) continue;
      _fireBasicAttack(i, cooldownScale: 1.35);
    }
  }

  /// Reach at which a body can smother a geyser mouth. Mirrors the Steam
  /// module's own constant; kept here so the base class can refuse to move a
  /// creature that might be capping.
  static const double _capReach = 48.0;

  bool _isBodyPossiblyCapping(Offset pos, DungeonRoom room) {
    for (final gy in room.geysers) {
      if ((pos - gy.position).distance <= _capReach) return true;
    }
    return false;
  }

  /// How close an idle ally will get to what it is shooting, as a fraction of
  /// its own attack range. Short of the edge so it keeps firing when the

  /// Idle allies must not stray further than this from whoever you are
  /// driving, or they wander off and fight their own war.
  static const double _idleLeash = 320.0;

  /// Personal space, so the party does not collapse into one stack of sprites.
  static const double _idleSpacing = 46.0;

  /// Movement for the party members you are NOT driving.
  ///
  /// They already returned fire (above) — but only when something wandered
  /// into range, and nothing ever moved them, so in a boss fight they stood
  /// wherever you parked them and did nothing at all. This walks them into
  /// their own effective range, keeps them near you, and keeps them apart.
  ///
  /// Deliberately simple: seek, leash, separate. No pathfinding — they use the
  /// same collision the player walks with, so they behave sanely against
  /// walls, and a stuck ally is a cosmetic problem rather than a broken one.
  void _updateIdleCompanionMovement(double dt, DungeonRoom room) {
    // FIGHTS ONLY. Outside combat a party member's position is frequently the
    // puzzle state — Steam recomputes which geyser mouths are capped from body
    // positions every frame — so wandering off a mouth would silently drop the
    // player's pressure. Repositioning is for boss and raid fights, which is
    // also the only place it was asked for.
    if (!hasCombatTargets) return;

    final leader = active;
    if (leader == null) return;

    for (var i = 0; i < creatures.length && i < combatCompanions.length; i++) {
      if (i == activeIndex) continue;
      final c = creatures[i];
      final comp = combatCompanions[i];
      if (!c.alive || comp.isDead) continue;
      // A creature mid-charge is being driven by its own ability.
      if (comp.chargeTimer > 0 || comp.kinAutoChargeTimer > 0) continue;
      // A body sitting on a geyser mouth is load-bearing even during a fight:
      // it may be the cap holding the room's pressure up. Leave it planted.
      if (_isBodyPossiblyCapping(c.position, room)) continue;

      var desired = Offset.zero;

      // 1. Take up the family's stance on the nearest enemy. Horns close,
      //    wings circle, manes/lets/pips hold back, kin sits as far off as
      //    its range allows — see companion_stance.dart. Everyone used to
      //    stand on the same ring regardless of family.
      final enemy = _nearestCombatEnemy(c.position, maxRange: double.infinity);
      if (enemy != null) {
        final toEnemy = enemy.position - c.position;
        if (toEnemy.distance > 1) {
          desired += stanceMove(
            self: c.position,
            target: enemy.position,
            attackRange: comp.attackRange,
            stance: stanceForFamily(comp.member.family),
            // Stable per slot, so two wings orbit the same way instead of
            // grinding against each other.
            orbitSign: i.isEven ? 1 : -1,
          );
          c.aimAngle = atan2(toEnemy.dy, toEnemy.dx);
          if (toEnemy.dx.abs() > 0.01) c.angle = toEnemy.dx >= 0 ? 0 : pi;
        }
      }

      // 2. Leash: never lose the party.
      final toLeader = leader.position - c.position;
      if (toLeader.distance > _idleLeash) {
        desired += toLeader / toLeader.distance * 1.6;
      }

      // 3. Separate: from the leader and from each other.
      for (var j = 0; j < creatures.length; j++) {
        if (j == i) continue;
        final other = creatures[j];
        if (!other.alive) continue;
        final away = c.position - other.position;
        final d = away.distance;
        if (d > 0.01 && d < _idleSpacing) {
          desired += away / d * (1.0 - d / _idleSpacing);
        }
      }

      if (desired.distanceSquared < 0.0001) continue;
      // Scale by magnitude rather than normalising: a stance at its preferred
      // distance contributes only its small orbit term, and normalising would
      // turn that into full-speed sideways drift for every family.
      final mag = min(1.0, desired.distance);
      final unit = desired / desired.distance;
      // Slightly slower than the player: the one you drive should feel like
      // the one you drive.
      c.position = _moveWithCollision(
        c.position,
        unit * _speed * 0.82 * mag * dt,
        room,
      );
    }
  }

  bool activateCombatAbility() {
    final comp = activeCombat;
    final creature = active;
    if (comp == null || creature == null) return false;
    // CONTROL FEEDBACK, not speech (§5.6). A passive special reads as a
    // permanently-passive button; a cooling one as its ring plus a refusal
    // pulse. Neither evicts the room's line.
    if (isPassiveOnlyCosmicAbility(comp.member.family, comp.member.element)) {
      abilityDeniedFlash = _deniedFlashSeconds;
      onChanged();
      return false;
    }
    if (comp.specialCooldown > 0) {
      abilityDeniedFlash = _deniedFlashSeconds;
      onChanged();
      return false;
    }
    // Specials auto-target the nearest enemy anywhere in the room; the
    // fallback aim point is only for genuinely empty rooms.
    final target = _nearestCombatEnemy(
      creature.position,
      maxRange: double.infinity,
    );
    final targetPoint =
        target?.position ??
        _fallbackAimPoint(creature, comp.specialAbilityRange, minDistance: 150);
    final toTarget = targetPoint - creature.position;
    final angle = toTarget.distance > 0.01
        ? atan2(toTarget.dy, toTarget.dx)
        : creature.angle;
    creature.angle = angle;
    comp.angle = angle;
    comp.specialCooldown =
        comp.effectiveSpecialCooldown *
        cosmicSurvivalSpecialCooldownMultiplier(comp.member.family);
    if (comp.member.family.toLowerCase() == 'pip' &&
        comp.member.element == 'Poison') {
      for (final existing in combatProjectiles) {
        if (existing.sourceSlotIndex == comp.slotIndex &&
            existing.abilityFamily == 'pip' &&
            existing.element == 'Poison' &&
            existing.stationary) {
          existing.life = 0;
        }
      }
      comp.lastPipPoisonHitPos = null;
    }
    final result = createCosmicSpecialAbility(
      origin: creature.position,
      baseAngle: angle,
      family: comp.member.family,
      element: comp.member.element,
      damage: comp.elemAtk * 1.15 * comp.damageAmp,
      maxHp: comp.maxHp,
      casterPower: comp.member.statIntelligence,
      casterBeauty: comp.member.statBeauty,
      casterIntelligence: comp.member.statIntelligence,
      casterStrength: comp.member.statStrength,
      targetPos: targetPoint,
    );
    for (final projectile in result.projectiles) {
      projectile.sourceSlotIndex = comp.slotIndex;
    }
    _activateWingBeams(
      result.beams,
      sourceSlotIndex: comp.slotIndex,
      origin: creature.position,
      angle: angle,
    );

    // Companion-side support effects (shields / heals / blessing regen /
    // attack haste) — same as survival's post-cast applier. Without this,
    // support-flavoured specials (horn shields, kin blessings, the haste
    // surge baked into manes like Fire) silently do nothing in dungeons.
    _applySpecialSupportEffects(comp, creature, result);

    // Mane+Spirit: each cast adds another shot to a tight machine-gun
    // stream up to 10, then resets (ported from survival; abilityKillStacks
    // doubles as the cast counter).
    var specialProjectiles = result.projectiles;
    if (comp.member.family.toLowerCase() == 'mane' &&
        comp.member.element == 'Spirit' &&
        specialProjectiles.isNotEmpty) {
      final stacks = comp.abilityKillStacks.clamp(0, 9);
      final shotCount = 1 + stacks;
      final base = specialProjectiles.first;
      final dir = Offset(cos(angle), sin(angle));
      final perp = Offset(-dir.dy, dir.dx);
      final soulSlashes = <Projectile>[];
      for (var i = 0; i < shotCount; i++) {
        final laneOffset = ((i % 3) - 1) * 2.5;
        soulSlashes.add(
          Projectile(
            position: base.position - dir * (i * 9.0) + perp * laneOffset,
            angle: angle + (i.isEven ? -0.018 : 0.018),
            element: base.element,
            damage: base.damage,
            life: base.life + i * 0.025,
            speedMultiplier: min(base.speedMultiplier + i * 0.012, 0.74),
            radiusMultiplier: max(base.radiusMultiplier * 0.88, 0.72),
            visualScale: max(base.visualScale * 0.86, 0.72),
            piercing: base.piercing,
            homing: base.homing,
            homingStrength: base.homingStrength,
            visualStyle: base.visualStyle,
            sourceSlotIndex: comp.slotIndex,
            abilityFamily: base.abilityFamily,
            hitEffect: base.hitEffect,
            killEffect: base.killEffect,
            pierceEffect: base.pierceEffect,
            effectPower: base.effectPower,
            effectRadius: base.effectRadius,
            effectDuration: base.effectDuration,
          ),
        );
      }
      specialProjectiles = soulSlashes;
      comp.abilityKillStacks = comp.abilityKillStacks >= 9
          ? 0
          : comp.abilityKillStacks + 1;
    }
    // Mane+Lightning: fire 5–10 small sigil orbs toward scattered positions;
    // each blooms into a shock field on arrival (ported from survival,
    // scattered within the current room instead of the arena).
    if (comp.member.family.toLowerCase() == 'mane' &&
        comp.member.element == 'Lightning' &&
        specialProjectiles.isNotEmpty) {
      final base = specialProjectiles.first;
      final orbCount = 5 + _combatRng.nextInt(6);
      final scatterCenter = creature.position;
      final scatterRadius = min(
        420.0,
        min(currentRoom.bounds.width, currentRoom.bounds.height) * 0.4,
      );
      final orbs = <Projectile>[];
      for (var i = 0; i < orbCount; i++) {
        final a = angle + i * 2.399963 + (_combatRng.nextDouble() - 0.5) * 0.42;
        final dist = 120.0 + _combatRng.nextDouble() * scatterRadius;
        final orbTarget = _clampToBounds(
          scatterCenter + Offset(cos(a), sin(a)) * dist,
          currentRoom,
        );
        final launchAngle = atan2(
          orbTarget.dy - creature.position.dy,
          orbTarget.dx - creature.position.dx,
        );
        final orb = Projectile(
          position: Offset(
            creature.position.dx + cos(launchAngle) * 24,
            creature.position.dy + sin(launchAngle) * 24,
          ),
          angle: launchAngle,
          element: 'Lightning',
          damage: 0,
          life: 2.9,
          speedMultiplier: 0.82 + (i % 3) * 0.05,
          piercing: true,
          radiusMultiplier: 0.58,
          visualScale: 0.62,
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: comp.slotIndex,
          abilityFamily: 'mane',
          effectPower: base.damage * 0.30,
          effectRadius: 44,
          effectDuration: 1.0,
          effectStacks: 1,
        );
        orb.cachedHomingTarget = orbTarget;
        orbs.add(orb);
      }
      specialProjectiles = orbs;
    }

    final isHornCharge =
        comp.member.family.toLowerCase() == 'horn' && result.chargeTimer > 0;
    if (comp.member.family.toLowerCase() == 'horn') {
      // On-kill payoff window (Steam chain-cast, Lava seekers, Blood heal).
      comp.hornSpecialActiveWindow = 5.0 + result.windUpTime;
    }
    if (comp.member.family.toLowerCase() == 'kin' &&
        comp.member.element == 'Lightning') {
      // Tesla charge window: while live, every party hit chains lightning
      // (the trigger in the hit loop reads this timer). Survival locks the
      // AI kin in place; dungeon creatures are player-driven, so movement
      // stays free.
      comp.kinLightningChargeTimer =
          10.0 *
          _effStatScale(
            comp.member.statIntelligence,
            perPoint: 0.10,
            min: 0.85,
            max: 1.40,
          );
      _setHint('The kin hums with storm-charge — strikes now chain', 3.0);
    }
    if (isHornCharge) {
      // Real horn flow (identical to survival): wind-up lock → dash with
      // sweep damage → pending burst released at the impact point. Field
      // caps keep impacts from dropping oversized bowls in a small room.
      for (final p in specialProjectiles) {
        if (p.snareRadius > 100) p.snareRadius = 100;
        if (p.tauntRadius > 180) p.tauntRadius = 180;
        if (p.effectRadius > 110) p.effectRadius = 110;
        if (p.stationary && p.life < 2.5) p.life = 2.5;
      }
      comp.pendingChargeBurst = specialProjectiles;
      comp.pendingChargeOrigin = creature.position;
      comp.pendingChargeAngle = angle;
      comp.chargeDamage = result.chargeDamage;
      comp.chargeSpeedMultiplier = result.chargeSpeedMultiplier;
      comp.chargeSweepRadius = min(result.chargeSweepRadius, 70);
      comp.chargeOvershootDistance = result.chargeOvershootDistance;
      comp.chargeFinalSweepRadius = min(result.chargeFinalSweepRadius, 80);
      comp.chargeHitIds = <int>{};
      comp.hornLightningAbsorbed = 0;
      // Horn+Blood: HP sacrifice on cast — 18% of current HP banked into
      // the impact damage (the creature pool is authoritative).
      if (comp.member.element == 'Blood') {
        final sac = (comp.currentHp * 0.18).round();
        if (sac > 0 && comp.currentHp - sac > 1) {
          creature.hp = (creature.hp - creature.maxHp * (sac / comp.maxHp))
              .clamp(1.0, creature.maxHp);
          comp.hitFlash = 1.0;
          comp.chargeDamage += sac * 0.25;
        }
      }
      if (result.windUpTime > 0) {
        // Dark / Crystal / Spirit wind-up: hold in place, run the element
        // tick (Dark pulls enemies into the brew), THEN dash.
        comp.windUpTimer = result.windUpTime;
        comp.windUpElement = result.windUpElement;
        comp.windUpDashTarget = targetPoint;
        comp.windUpFireAngle = angle;
      } else if (comp.member.element == 'Water') {
        // Curved circular charge sweeping around the cast point.
        const circleDuration = 1.0;
        comp.chargePathType = 'circle';
        comp.chargeCircleCenter = creature.position;
        comp.chargeCircleRadius = comp.chargeOvershootDistance
            .clamp(90.0, 200.0)
            .toDouble();
        comp.chargeCircleAngle = angle - pi / 2;
        comp.chargeCircleAngularSpeed = 2 * pi / circleDuration;
        comp.chargeTimer = circleDuration;
        comp.chargeTarget = null;
      } else if (comp.member.element == 'Ice') {
        // Dash sideways, painting an ice wall along the path.
        const wallLength = 240.0;
        final unit = toTarget.distance > 1
            ? toTarget / toTarget.distance
            : Offset(cos(angle), sin(angle));
        final perp = Offset(-unit.dy, unit.dx);
        comp.chargeTarget = _clampToBounds(
          creature.position + perp * wallLength,
          currentRoom,
        );
        comp.chargePathType = 'ice-wall';
        comp.iceWallTrailTimer = 0;
        final travelTime =
            wallLength /
            (CosmicSurvivalCompanion.chargeSpeed * comp.chargeSpeedMultiplier);
        comp.chargeTimer = (travelTime + 0.10).clamp(0.3, 3.0);
      } else {
        _startDungeonHornCharge(
          comp,
          creature,
          targetPoint,
          result.chargeTimer,
        );
      }
    } else {
      final family = comp.member.family.toLowerCase();
      if (family == 'mask' && comp.member.element == 'Plant') {
        // Persistent feedable vine (identical to survival). Mask+Spirit is
        // the deliberate exception — its wisps are ship-collected pickups,
        // so it falls back to plain projectiles down here.
        _feedOrSpawnMaskPlantVine(comp.slotIndex, specialProjectiles);
      } else if (family == 'mask' && comp.member.element == 'Dust') {
        _spawnMaskDustShields(comp.slotIndex, specialProjectiles);
      } else {
        combatProjectiles.addAll(specialProjectiles);
      }
    }
    onChanged();
    return true;
  }

  static const int _maskPlantMaxFeeds = 100;

  /// Mask+Plant: one persistent vine per caster. First cast plants the
  /// seed; every later cast feeds it (+1 stack), growing its snare/aura and
  /// per-tick damage, gently re-anchoring toward the new cast spot.
  void _feedOrSpawnMaskPlantVine(
    int slotIndex,
    List<Projectile> specialProjectiles,
  ) {
    if (specialProjectiles.isEmpty) return;
    Projectile? existing;
    for (final p in combatProjectiles) {
      if (p.sourceSlotIndex == slotIndex &&
          p.abilityFamily == 'mask' &&
          p.element == 'Plant' &&
          p.stationary) {
        existing = p;
        break;
      }
    }
    if (existing == null) {
      final seed = specialProjectiles.first;
      seed.effectStacks = 1;
      _applyMaskPlantVineFeed(seed, 1);
      seed.abilityGrowthTimer = 2.0;
      _spawnAlchemyBurst(
        seed.position,
        producedElement: 'Plant',
        particleCount: 18,
        intensity: 0.9,
      );
      combatProjectiles.add(seed);
      return;
    }
    final newSeed = specialProjectiles.first;
    final prevFeeds = existing.effectStacks;
    final feeds = (prevFeeds + 1).clamp(1, _maskPlantMaxFeeds);
    final newTendril = (feeds ~/ 10) != (prevFeeds ~/ 10);
    existing.effectStacks = feeds;
    existing.life = max(existing.life, newSeed.life);
    final delta = newSeed.position - existing.position;
    final dist = delta.distance;
    if (dist > 0.01) {
      existing.position += delta * (min(60.0, dist) / dist);
    }
    _applyMaskPlantVineFeed(existing, feeds);
    existing.abilityGrowthTimer = newTendril ? 2.0 : 1.0;
    _spawnAlchemyBurst(
      existing.position,
      producedElement: 'Plant',
      particleCount: newTendril ? 18 : 9,
      intensity: newTendril ? 1.0 : 0.6,
    );
  }

  void _applyMaskPlantVineFeed(Projectile vine, int feeds) {
    final t = (feeds / _maskPlantMaxFeeds).clamp(0.0, 1.0);
    const baseSnare = 90.0;
    const maxSnare = 300.0;
    const baseEffect = 90.0;
    const maxEffect = 320.0;
    const baseVisual = 2.4;
    const maxVisual = 6.5;
    const baseRadius = 2.4;
    const maxRadius = 6.5;
    vine.snareRadius = baseSnare + (maxSnare - baseSnare) * t;
    vine.snareMoveMultiplier = (0.5 - 0.40 * t).clamp(0.10, 0.50);
    vine.effectRadius = baseEffect + (maxEffect - baseEffect) * t;
    vine.visualScale = baseVisual + (maxVisual - baseVisual) * t;
    vine.radiusMultiplier = baseRadius + (maxRadius - baseRadius) * t;
    vine.effectPower = vine.effectPower == 0
        ? 1.0 + 5.0 * t
        : max(vine.effectPower, 1.0 + 5.0 * t);
  }

  /// Mask+Dust: a protective dust aura attached to every living party
  /// member (the ship shield maps to "everyone" — no ship down here).
  /// Refreshing casts top up life/charges instead of stacking.
  void _spawnMaskDustShields(
    int slotIndex,
    List<Projectile> specialProjectiles,
  ) {
    if (specialProjectiles.isEmpty) return;
    final seed = specialProjectiles.first;
    final existing = <int, Projectile>{};
    for (final p in combatProjectiles) {
      if (p.sourceSlotIndex == slotIndex &&
          p.abilityFamily == 'mask' &&
          p.element == 'Dust' &&
          p.attachedToSlot != -2) {
        existing[p.attachedToSlot] = p;
      }
    }
    void upsertShield(int targetSlot, Offset position) {
      final prev = existing.remove(targetSlot);
      if (prev != null) {
        prev.life = max(prev.life, seed.life);
        prev.interceptCharges = max(prev.interceptCharges, 5);
        prev.abilityGrowthTimer = max(prev.abilityGrowthTimer, 0.8);
        return;
      }
      combatProjectiles.add(
        Projectile(
          position: position,
          angle: 0,
          element: 'Dust',
          damage: 0,
          life: max(8.0, seed.life),
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: max(1.4, seed.radiusMultiplier),
          visualScale: max(1.6, seed.visualScale),
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: slotIndex,
          attachedToSlot: targetSlot,
          abilityFamily: 'mask',
          tickEffect: AbilityEffectKind.zoneDamage,
          effectPower: max(seed.effectPower, 1.0),
          effectRadius: max(72.0, seed.effectRadius),
          effectDuration: seed.effectDuration,
          interceptRadius: max(72.0, seed.effectRadius),
          interceptCharges: 5,
        ),
      );
    }

    for (var i = 0; i < creatures.length && i < combatCompanions.length; i++) {
      if (!creatures[i].alive) continue;
      upsertShield(combatCompanions[i].slotIndex, creatures[i].position);
    }
  }

  void _startDungeonHornCharge(
    CosmicSurvivalCompanion comp,
    DungeonCreature creature,
    Offset attackTarget,
    double requestedChargeTimer,
  ) {
    final dir = attackTarget - creature.position;
    final dist = dir.distance;
    if (dist > 1) {
      final overshoot = _clampToBounds(
        attackTarget + (dir / dist) * comp.chargeOvershootDistance,
        currentRoom,
      );
      comp.chargeTarget = overshoot;
      final travelTime =
          (overshoot - creature.position).distance /
          (CosmicSurvivalCompanion.chargeSpeed * comp.chargeSpeedMultiplier);
      comp.chargeTimer = (travelTime + 0.15).clamp(0.3, 3.0);
    } else {
      comp.chargeTarget = attackTarget;
      comp.chargeTimer = requestedChargeTimer.clamp(0.3, 3.0);
    }
    comp.chargeHitIds = <int>{};
  }

  /// Per-frame kin laser charges: tick up while the kin holds still, then
  /// fire a piercing line beam (physAtk × 4 — survival's cadence trade).
  void _updateKinAutoCharges(double dt) {
    for (var i = 0; i < combatCompanions.length && i < creatures.length; i++) {
      final comp = combatCompanions[i];
      final creature = creatures[i];
      if (comp.kinAutoChargeTimer <= 0) continue;
      if (!creature.alive) {
        comp.kinAutoChargeTimer = 0;
        comp.kinAutoChargeEnemy = null;
        comp.kinAutoChargeTarget = null;
        continue;
      }
      comp.kinAutoChargeTimer += dt;
      if (comp.kinAutoChargeTimer < _kinChargeTime) continue;

      // Fire: prefer the locked enemy if still alive, else nearest.
      final locked = comp.kinAutoChargeEnemy;
      final fireAt = (locked != null && !locked.isDead)
          ? locked.position
          : (_nearestCombatEnemy(
                  creature.position,
                  maxRange: comp.attackRange + 80,
                )?.position ??
                comp.kinAutoChargeTarget ??
                creature.position + Offset(cos(creature.angle), 0) * 120);
      final dir = fireAt - creature.position;
      final dist = dir.distance;
      comp.kinAutoChargeTimer = 0;
      comp.kinAutoChargeTarget = null;
      comp.kinAutoChargeEnemy = null;
      comp.basicCooldown = comp.effectiveBasicCooldown;
      if (dist < 0.01) continue;
      final norm = dir / dist;
      final beamLength = (dist + 60.0).clamp(120.0, 720.0).toDouble();
      final beamEnd = creature.position + norm * beamLength;
      final dmg = comp.physAtk.toDouble() * 4.0 * comp.damageAmp;
      const lateral = 14.0;
      for (final enemy in combatEnemies) {
        if (enemy.isDead) continue;
        final d = _distanceToSegment(
          enemy.position,
          creature.position,
          beamEnd,
        );
        if (d <= enemy.radius + lateral) {
          enemy.hp -= dmg * _enemyDamageTakenScale(enemy);
          enemy.hitFlash = 0.18;
          if (enemy.hp <= 0) enemy.isDead = true;
        }
      }
      creature.angle = atan2(norm.dy, norm.dx);
      comp.angle = creature.angle;
      if (_kinBeams.length >= 12) _kinBeams.removeAt(0);
      _kinBeams.add(
        _KinBeamFx(
          origin: creature.position,
          end: beamEnd,
          color: elementColor(comp.member.element),
        ),
      );
    }
  }

  /// True while a cast sequence owns this companion's body (wind-up lock,
  /// dash, post-dash storm brew, or kin laser charge) — joystick movement
  /// is suspended for the active creature during these.
  bool _castLocksMovement(CosmicSurvivalCompanion comp) =>
      comp.windUpTimer > 0 ||
      comp.chargeTimer > 0 ||
      comp.hornPostDashWindUpTimer > 0 ||
      comp.kinAutoChargeTimer > 0;

  /// Per-frame horn cast machine — the survival flow driving the CREATURE
  /// body: wind-up (locked, Dark pulls enemies in) → dash with sweep damage
  /// and element trails → final sweep → pending burst released at impact
  /// (Lightning brews 3s first).
  void _updateHornCasts(double dt) {
    for (var i = 0; i < combatCompanions.length && i < creatures.length; i++) {
      final comp = combatCompanions[i];
      final creature = creatures[i];
      if (!creature.alive) {
        comp.windUpTimer = 0;
        comp.chargeTimer = 0;
        comp.hornPostDashWindUpTimer = 0;
        comp.pendingChargeBurst = null;
        continue;
      }

      // ── Wind-up phase ──
      if (comp.windUpTimer > 0) {
        comp.windUpTimer -= dt;
        if (comp.windUpElement == 'Dark') {
          // Void-suck: drag enemies into the brew.
          for (final e in combatEnemies) {
            if (e.isDead) continue;
            final toCaster = creature.position - e.position;
            final d = toCaster.distance;
            if (d > 1 && d < 200) {
              e.position += toCaster / d * 95 * dt;
            }
          }
        }
        if (comp.windUpTimer <= 0) {
          if (comp.windUpElement == 'Dark') {
            // Capture the gathered cluster; the dash delivers them.
            comp.hornDarkCaptured = [
              for (final e in combatEnemies)
                if (!e.isDead &&
                    (e.position - creature.position).distance < 200 &&
                    !identical(e, _guardianEnemy))
                  e,
            ];
            final dir = Offset(
              cos(comp.windUpFireAngle),
              sin(comp.windUpFireAngle),
            );
            final dashTarget = _clampToBounds(
              creature.position + dir * (comp.chargeOvershootDistance + 200),
              currentRoom,
            );
            comp.chargeTarget = dashTarget;
            comp.chargeHitIds = <int>{};
            final travelTime =
                (dashTarget - creature.position).distance /
                (CosmicSurvivalCompanion.chargeSpeed *
                    comp.chargeSpeedMultiplier);
            comp.chargeTimer = (travelTime + 0.15).clamp(0.3, 3.0);
          } else {
            _startDungeonHornCharge(
              comp,
              creature,
              comp.windUpDashTarget ?? creature.position,
              1.0,
            );
          }
        }
        continue;
      }

      // ── Post-dash storm brew (Lightning) ──
      if (comp.hornPostDashWindUpTimer > 0) {
        comp.hornPostDashWindUpTimer -= dt;
        // Visible storm: crackling particles swirl around the rooted horn
        // (iceWallTrailTimer is idle outside dashes — reuse it as the FX
        // cadence so no new field is needed).
        comp.iceWallTrailTimer -= dt;
        if (comp.iceWallTrailTimer <= 0) {
          comp.iceWallTrailTimer = 0.16;
          _spawnAlchemyBurst(
            creature.position +
                Offset(
                  (_combatRng.nextDouble() - 0.5) * 44,
                  (_combatRng.nextDouble() - 0.5) * 44,
                ),
            producedElement: 'Lightning',
            unstable: true,
            particleCount: 6,
            intensity: 0.7,
          );
        }
        if (comp.hornPostDashWindUpTimer <= 0) {
          _releasePendingChargeBurst(comp, creature);
        }
        continue;
      }

      // ── Dash phase ──
      if (comp.chargeTimer > 0) {
        comp.chargeTimer -= dt;
        // Horn+Lava: molten ember telegraph that brightens as the slam
        // nears (survival's charge-time visual).
        if (comp.member.element == 'Lava' &&
            _alchemyParticles.length < 130 &&
            _combatRng.nextDouble() < 0.55) {
          final a = _combatRng.nextDouble() * 2 * pi;
          final r = 18.0 + _combatRng.nextDouble() * 14.0;
          _alchemyParticles.add(
            _AlchemyParticle(
              position: creature.position + Offset(cos(a), sin(a)) * r,
              velocity: Offset(0, -30 - _combatRng.nextDouble() * 40),
              color: _combatRng.nextBool()
                  ? elementColor('Lava')
                  : const Color(0xFFFFB050),
              maxLife: 0.3 + _combatRng.nextDouble() * 0.25,
              size: 1.4 + _combatRng.nextDouble() * 1.6,
            ),
          );
        }
        if (comp.chargePathType == 'circle' &&
            comp.chargeCircleCenter != null) {
          comp.chargeCircleAngle += comp.chargeCircleAngularSpeed * dt;
          final center = comp.chargeCircleCenter!;
          final desired = Offset(
            center.dx + cos(comp.chargeCircleAngle) * comp.chargeCircleRadius,
            center.dy + sin(comp.chargeCircleAngle) * comp.chargeCircleRadius,
          );
          creature.position = _moveDashing(
            creature.position,
            desired - creature.position,
            currentRoom,
          );
          creature.angle = comp.chargeCircleAngle + pi / 2;
          _hornSweepDamage(comp, creature, comp.chargeSweepRadius);
        } else if (comp.chargeTarget != null) {
          final dir = comp.chargeTarget! - creature.position;
          final dist = dir.distance;
          if (dist > 5) {
            final step =
                CosmicSurvivalCompanion.chargeSpeed *
                comp.chargeSpeedMultiplier *
                dt;
            final before = creature.position;
            // Airborne ram: crosses gaps/open sky; only walls stop it.
            creature.position = _moveDashing(
              creature.position,
              (dir / dist) * min(step, dist),
              currentRoom,
            );
            creature.angle = atan2(dir.dy, dir.dx);
            // A wall stops the ram — impact happens there.
            if ((creature.position - before).distance < step * 0.2) {
              comp.chargeTimer = 0;
            }
            _hornSweepDamage(comp, creature, comp.chargeSweepRadius);
            // Element trails along the dash path.
            final element = comp.member.element;
            if (comp.chargePathType == 'ice-wall' || element == 'Fire') {
              comp.iceWallTrailTimer -= dt;
              if (comp.iceWallTrailTimer <= 0) {
                comp.iceWallTrailTimer = element == 'Fire' ? 0.12 : 0.05;
                _spawnHornTrailSegment(comp, creature, element);
              }
            }
          } else {
            comp.chargeTimer = 0;
          }
        }
        if (comp.chargeTimer <= 0) {
          _finishHornCharge(comp, creature);
        }
      }
    }
  }

  void _hornSweepDamage(
    CosmicSurvivalCompanion comp,
    DungeonCreature creature,
    double sweepRadius,
  ) {
    final element = comp.member.family.toLowerCase() == 'horn'
        ? comp.member.element
        : null;
    for (final e in combatEnemies) {
      if (e.isDead) continue;
      final d = (e.position - creature.position).distance;
      if (d < e.radius + sweepRadius &&
          !(comp.chargeHitIds?.contains(e.hashCode) ?? false)) {
        comp.chargeHitIds?.add(e.hashCode);
        e.hp -= comp.chargeDamage * _enemyDamageTakenScale(e);
        e.hitFlash = 0.18;
        if (e.hp <= 0) e.isDead = true;
        // Horn+Plant: root survivors in place.
        if (element == 'Plant' && !e.isDead) {
          final rootScale = (0.80 + (comp.member.statIntelligence - 1) * 0.20)
              .clamp(0.80, 1.80);
          final dur = 3.0 * rootScale;
          e.hornPlantRootTimer = max(e.hornPlantRootTimer, dur);
          e.slowTimer = max(e.slowTimer, dur);
          e.slowMultiplier = 0;
        }
        // Horn+Poison: heavy DoT on each swept enemy.
        if (element == 'Poison' && !e.isDead) {
          e.hp -= CosmicAbilityRuntime.directDamageForEffect(
            AbilityEffectKind.poison,
            power: comp.elemAtk * 0.40,
            targetHp: e.hp,
            targetHpFraction: e.hpFraction,
          );
          if (e.hp <= 0) e.isDead = true;
        }
      }
    }
  }

  void _spawnHornTrailSegment(
    CosmicSurvivalCompanion comp,
    DungeonCreature creature,
    String element,
  ) {
    final isFire = element == 'Fire';
    combatProjectiles.add(
      Projectile(
        position: creature.position,
        angle: 0,
        element: element,
        damage: 0,
        life: isFire ? 2.4 : 3.2,
        stationary: true,
        piercing: true,
        radiusMultiplier: 1.2,
        visualScale: isFire ? 1.0 : 1.15,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: comp.slotIndex,
        abilityFamily: 'horn',
        tickEffect: isFire ? AbilityEffectKind.burn : AbilityEffectKind.slow,
        effectPower: isFire ? comp.elemAtk * 0.30 : 0,
        effectRadius: isFire ? 30 : 26,
        effectDuration: isFire ? 1.2 : 1.6,
        snareRadius: isFire ? 0 : 26,
        snareMoveMultiplier: isFire ? 1.0 : 0.35,
      ),
    );
  }

  void _finishHornCharge(
    CosmicSurvivalCompanion comp,
    DungeonCreature creature,
  ) {
    _hornSweepDamage(comp, creature, comp.chargeFinalSweepRadius);
    // Horn+Lightning: brew the storm for 3s, then discharge.
    if (comp.member.family.toLowerCase() == 'horn' &&
        comp.member.element == 'Lightning' &&
        comp.pendingChargeBurst != null) {
      comp.hornPostDashWindUpTimer = 3.0;
      comp.iceWallTrailTimer = 0;
      comp.chargeTarget = null;
      comp.chargePathType = '';
      comp.chargeCircleCenter = null;
      _setHint('The storm brews — hits taken feed the discharge', 2.8);
      return;
    }
    _releasePendingChargeBurst(comp, creature);
  }

  /// Survival's universal impact feedback: a small burst of element-colored
  /// darts at every projectile hit. Capped so dense fights stay cheap.
  void _spawnHitSpark(Offset pos, Color color) {
    if (_alchemyParticles.length >= 150) return;
    for (var i = 0; i < 6; i++) {
      final a = _combatRng.nextDouble() * 2 * pi;
      final spd = 40 + _combatRng.nextDouble() * 80;
      _alchemyParticles.add(
        _AlchemyParticle(
          position: pos,
          velocity: Offset(cos(a), sin(a)) * spd,
          color: color,
          maxLife: 0.3 + _combatRng.nextDouble() * 0.3,
          size: 1.5 + _combatRng.nextDouble() * 2,
        ),
      );
    }
  }

  void _spawnProjectileHitSpark(Projectile projectile) {
    final color = elementColor(projectile.element ?? 'Fire');
    if (projectile.visualStyle != ProjectileVisualStyle.mysticOrbital) {
      _spawnHitSpark(projectile.position, color);
      return;
    }
    if (_alchemyParticles.length >= 150) return;
    for (var i = 0; i < 2; i++) {
      final a = projectile.angle + pi + (_combatRng.nextDouble() - 0.5) * 1.2;
      final spd = 26 + _combatRng.nextDouble() * 42;
      _alchemyParticles.add(
        _AlchemyParticle(
          position: projectile.position,
          velocity: Offset(cos(a), sin(a)) * spd,
          color: color.withValues(alpha: 0.72),
          maxLife: 0.16 + _combatRng.nextDouble() * 0.14,
          size: 1.0 + _combatRng.nextDouble() * 1.2,
        ),
      );
    }
  }

  /// Survival's per-element mane pierce verbs (resolveAbilityPierce),
  /// adapted: orb heals become creature heals, arena clamps become room
  /// clamps. Dedupe via effectHitIds so each enemy is verbed once per shot.
  void _resolveAbilityPierce(Projectile projectile, CosmicSurvivalEnemy enemy) {
    final id = identityHashCode(enemy);
    if (!projectile.effectHitIds.add(id)) return;
    if (projectile.abilityFamily == 'mane' && projectile.element == 'Air') {
      final dir = Offset(cos(projectile.angle), sin(projectile.angle));
      final pushDistance = max(
        95.0,
        projectile.effectPower * 0.72,
      ).clamp(95.0, 180.0).toDouble();
      enemy.position = _clampToBounds(
        enemy.position + dir * pushDistance,
        currentRoom,
      );
      enemy.knockbackVelocity += dir * 170;
      enemy.slowTimer = max(
        enemy.slowTimer,
        max(0.45, projectile.effectDuration * 0.35),
      );
      enemy.slowMultiplier = min(enemy.slowMultiplier, 0.68);
      _spawnHitSpark(enemy.position, elementColor('Air'));
      return;
    }
    // "Carry": dragged along the projectile's path instead of pushed back.
    if (projectile.pierceEffect == AbilityEffectKind.carry) {
      final isManeWaterWall =
          projectile.abilityFamily == 'mane' && projectile.element == 'Water';
      final dragDistance = isManeWaterWall
          ? max(
              120.0,
              projectile.effectPower * 0.85,
            ).clamp(120.0, 190.0).toDouble()
          : CosmicAbilityRuntime.maneCarryDistance(projectile.effectPower);
      enemy.position = _clampToBounds(
        enemy.position +
            Offset(
              cos(projectile.angle) * dragDistance,
              sin(projectile.angle) * dragDistance,
            ),
        currentRoom,
      );
      enemy.slowTimer = max(
        enemy.slowTimer,
        projectile.effectDuration + (isManeWaterWall ? 0.8 : 0.0),
      );
      enemy.slowMultiplier = min(
        enemy.slowMultiplier,
        isManeWaterWall ? 0.38 : 0.55,
      );
      if (isManeWaterWall) {
        _spawnHitSpark(enemy.position, elementColor('Water'));
      }
      return;
    }
    if (projectile.abilityFamily == 'mane') {
      switch (projectile.element) {
        case 'Plant':
          // Tag so a kill-while-rooted detonates AOE.
          enemy.maneRootSlot = projectile.sourceSlotIndex;
          enemy.maneRootTimer = max(enemy.maneRootTimer, 2.6);
          enemy.slowTimer = max(enemy.slowTimer, 2.6);
          enemy.slowMultiplier = 0;
          _spawnHitSpark(enemy.position, elementColor('Plant'));
          break;
        case 'Light':
          // Ball gets bigger and hits harder per pierce.
          const maxLightManeRadius = 28.0;
          const maxLightManeVisual = 24.0;
          if (projectile.radiusMultiplier < maxLightManeRadius) {
            projectile.damage *= 2.0;
            projectile.radiusMultiplier = min(
              projectile.radiusMultiplier * 2.0,
              maxLightManeRadius,
            );
            projectile.visualScale = min(
              projectile.visualScale * 2.0,
              maxLightManeVisual,
            );
            projectile.effectRadius = min(projectile.effectRadius * 2.0, 360);
          }
          _spawnHitSpark(enemy.position, elementColor('Light'));
          break;
        case 'Lava':
          // Drop a lava blob (DoT zone) at the pierce point.
          combatProjectiles.add(
            Projectile(
              position: enemy.position,
              angle: 0,
              element: 'Lava',
              damage: 0,
              life: 3.6,
              speedMultiplier: 0,
              stationary: true,
              piercing: true,
              radiusMultiplier: 1.4,
              visualScale: 1.3,
              visualStyle: ProjectileVisualStyle.sigil,
              sourceSlotIndex: projectile.sourceSlotIndex,
              abilityFamily: 'mane',
              tickEffect: AbilityEffectKind.burn,
              effectPower: projectile.damage * 0.18,
              effectRadius: 50,
              effectDuration: 3.6,
            ),
          );
          break;
        case 'Blood':
          // Every pierce restores HP — here the caster's creature instead
          // of survival's orb.
          final srcSlot = projectile.sourceSlotIndex;
          if (srcSlot != null) {
            final idx = combatCompanions.indexWhere(
              (c) => c.slotIndex == srcSlot,
            );
            if (idx >= 0 && idx < creatures.length) {
              _healCreature(
                creatures[idx],
                combatCompanions[idx],
                max(2, (projectile.damage * 0.10).round()).toDouble(),
              );
            }
          }
          _spawnHitSpark(enemy.position, elementColor('Blood'));
          break;
        case 'Poison':
          // Each pierce stacks poison; later hits sting harder per stack.
          enemy.manePoisonStacks = (enemy.manePoisonStacks + 1).clamp(0, 8);
          final stackMul = 1.0 + (enemy.manePoisonStacks - 1) * 0.20;
          _damageEnemyDirect(
            enemy,
            CosmicAbilityRuntime.projectileEffectPower(projectile) * stackMul,
            sourceSlot: projectile.sourceSlotIndex,
          );
          _spawnHitSpark(enemy.position, elementColor('Poison'));
          return;
        case 'Dark':
          // Execute low-HP enemies caught in the slow void bolt's path.
          if (enemy.hpFraction <= 0.18) {
            _damageEnemyDirect(
              enemy,
              enemy.hp + 1,
              sourceSlot: projectile.sourceSlotIndex,
            );
            _spawnHitSpark(enemy.position, elementColor('Dark'));
          }
          break;
      }
    }
    _applyProjectileEffect(projectile, enemy, projectile.pierceEffect);
  }

  /// Survival's `_hornStatScale`: stat-driven multiplier around the 3.0
  /// baseline.
  double _effStatScale(
    double stat, {
    double perPoint = 0.12,
    double min = 0.82,
    double max = 1.22,
  }) {
    final clamped = stat.clamp(0.5, 8.0);
    return (1.0 + (clamped - 3.0) * perPoint).clamp(min, max).toDouble();
  }

  /// Central damage funnel for player-sourced damage: applies the dungeon's
  /// boss-scaling, flashes, and fires the kill-verb hook on a lethal blow.

  /// Whether this room's fight is important enough to be worth annotating.
  ///
  /// Guardians and raids only. Ordinary rooms are puzzles first — floating
  /// numbers over trash mobs would clutter the thing the player is reading.
  bool get _showsDamageNumbers => isRaid || guardianAwake;

  // ---------------------------------------------------------------------
  // Raid death sequence
  // ---------------------------------------------------------------------

  void _beginRaidDeath() {
    if (_raidDeath != null) return;
    final g = _guardianEnemy;
    final at = g?.position ?? lastStarEarnPosition;
    _raidDeath = _RaidDeathFx(
      position: at,
      radius: g?.radius ?? 60,
      color: g != null ? elementColor(g.element) : elementColor(layout.element),
    );
    // The arena goes quiet: surviving adds are consumed by the collapse so
    // nothing shoots the party during the cinematic.
    for (final e in combatEnemies) {
      if (identical(e, _guardianEnemy)) continue;
      e.isDead = true;
      _spawnAlchemyBurst(
        e.position,
        producedElement: e.element,
        particleCount: 8,
        intensity: 0.5,
      );
    }
    damageNumbers.clear();
  }

  void _updateRaidDeath(double dt) {
    final fx = _raidDeath;
    if (fx == null) return;
    final before = fx.t;
    fx.t += dt;

    // One burst at the detonation frame, not every frame of it.
    const detonateAt = _RaidDeathFx.seize + _RaidDeathFx.implode;
    if (before < detonateAt && fx.t >= detonateAt) {
      _spawnAlchemyBurst(
        fx.position,
        producedElement: 'Light',
        reagentElements: [layout.element],
        particleCount: 40,
        intensity: 1.6,
        unstable: true,
      );
    }

    if (fx.done) {
      _raidDeath = null;
      onRaidCleared?.call();
      onChanged();
    }
  }

  void _renderRaidDeath(Canvas canvas) {
    final fx = _raidDeath;
    if (fx == null) return;
    final c = fx.position;
    final r = fx.radius;

    // Beat 1 — the body seizes: it shudders in place while seams of light
    // tear open across it.
    if (fx.seizeT < 1.0) {
      final s = fx.seizeT;
      // Shudder grows as it loses the fight.
      final shake = 3.0 * s;
      final jitter = Offset(sin(fx.t * 47) * shake, cos(fx.t * 39) * shake);
      final body = c + jitter;
      canvas.drawCircle(
        body,
        r * (1.0 + 0.05 * sin(fx.t * 18)),
        Paint()..color = fx.color.withValues(alpha: 0.30 + 0.25 * s),
      );
      // Cracks: fixed spokes that brighten and lengthen.
      final crack = Paint()
        ..color = Color.lerp(
          fx.color,
          Colors.white,
          0.7,
        )!.withValues(alpha: 0.25 + 0.75 * s)
        ..strokeWidth = 1.5 + 2.5 * s
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 7; i++) {
        final a = (i / 7) * pi * 2 + 0.4;
        final len = r * (0.35 + 0.75 * s);
        canvas.drawLine(
          body + Offset(cos(a), sin(a)) * (r * 0.12),
          body + Offset(cos(a), sin(a)) * len,
          crack,
        );
      }
      // Escaping light, pulled outward and up.
      final vent = Paint()
        ..color = Colors.white.withValues(alpha: 0.10 + 0.35 * s)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 14 * s);
      canvas.drawCircle(body, r * (0.6 + 0.5 * s), vent);
    }

    // Beat 2 — implosion: rings race inward and the core whitens.
    if (fx.implodeT > 0 && fx.implodeT < 1.0) {
      final s = fx.implodeT;
      final ease = s * s;
      for (var i = 0; i < 3; i++) {
        final phase = (ease + i / 3.0) % 1.0;
        final ring = r * 5.0 * (1.0 - phase);
        canvas.drawCircle(
          c,
          ring,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + 4 * phase
            ..color = fx.color.withValues(alpha: 0.55 * (1.0 - phase)),
        );
      }
      canvas.drawCircle(
        c,
        r * (1.0 - 0.75 * ease),
        Paint()
          ..color = Color.lerp(
            fx.color,
            Colors.white,
            ease,
          )!.withValues(alpha: 0.9),
      );
    }

    // Beat 3 — detonation: a hard flash and one fast shockwave.
    if (fx.burstT > 0 && fx.burstT < 1.0) {
      final s = fx.burstT;
      final out = Curves.easeOutQuart.transform(s);
      canvas.drawCircle(
        c,
        r * (0.5 + 9.0 * out),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 * (1.0 - out) + 1
          ..color = Colors.white.withValues(alpha: 0.85 * (1.0 - out)),
      );
      canvas.drawCircle(
        c,
        r * (0.4 + 5.0 * out),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26 * (1.0 - out) + 1
          ..color = fx.color.withValues(alpha: 0.5 * (1.0 - out)),
      );
      canvas.drawCircle(
        c,
        r * 2.4 * (1.0 - out),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * (1.0 - out))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }

    // Beat 4 — settling: embers rise off the empty space where it stood.
    if (fx.settleT > 0) {
      final s = fx.settleT;
      final fade = 1.0 - s;
      final ember = Paint()..color = fx.color.withValues(alpha: 0.55 * fade);
      for (var i = 0; i < 14; i++) {
        final a = (i / 14) * pi * 2 + 1.1;
        final spread = r * (0.6 + 1.8 * ((i * 37) % 11) / 11.0);
        final rise = 40 + 70 * s + ((i * 53) % 9) * 6.0;
        canvas.drawCircle(
          c + Offset(cos(a) * spread, sin(a) * spread * 0.5 - rise * s),
          1.6 + 1.4 * fade,
          ember,
        );
      }
      canvas.drawCircle(
        c,
        r * (1.2 + 2.0 * s),
        Paint()
          ..color = fx.color.withValues(alpha: 0.16 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
  }

  void _spawnDamageNumber(CosmicSurvivalEnemy enemy, double dealt) {
    if (!_showsDamageNumbers) return;
    damageNumbers.spawn(
      enemy.position,
      dealt,
      jitter: Offset(
        (_combatRng.nextDouble() - 0.5) * enemy.radius * 1.2,
        -enemy.radius * 0.7 - _combatRng.nextDouble() * 6,
      ),
    );
  }

  void _damageEnemyDirect(
    CosmicSurvivalEnemy enemy,
    double amount, {
    int? sourceSlot,
    bool fromPipSpecial = false,
  }) {
    if (enemy.isDead || amount <= 0) return;
    final dealt = amount * _enemyDamageTakenScale(enemy);
    enemy.hp -= dealt;
    enemy.hitFlash = max(enemy.hitFlash, 0.14);
    _spawnDamageNumber(enemy, dealt);
    if (enemy.hp <= 0) {
      enemy.isDead = true;
      _onEnemyKilledByPlayer(enemy, sourceSlot, fromPipSpecial: fromPipSpecial);
    }
  }

  void _damageEnemiesNear(
    Offset center,
    double radius,
    double damage, {
    int? sourceSlot,
    CosmicSurvivalEnemy? exclude,
  }) {
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      if (exclude != null && identical(enemy, exclude)) continue;
      if ((enemy.position - center).distance > radius) continue;
      _damageEnemyDirect(enemy, damage, sourceSlot: sourceSlot);
    }
  }

  /// Survival's `_healAllCompanionsAndShip`, minus the ship.
  void _healAllCreatures(double amount) {
    for (var i = 0; i < creatures.length && i < combatCompanions.length; i++) {
      if (!creatures[i].alive) continue;
      _healCreature(creatures[i], combatCompanions[i], amount);
    }
  }

  void _healSourceCreature(int? slot, double amount) {
    if (slot == null) return;
    final idx = combatCompanions.indexWhere((c) => c.slotIndex == slot);
    if (idx < 0 || idx >= creatures.length) return;
    _healCreature(creatures[idx], combatCompanions[idx], amount);
  }

  /// Survival's `_killEnemy` player-facing verbs: rooted-plant detonation,
  /// horn on-kill payoffs, pip kill placements, Pip/Mask Spirit streaks.
  void _onEnemyKilledByPlayer(
    CosmicSurvivalEnemy enemy,
    int? sourceSlot, {
    bool fromPipSpecial = false,
  }) {
    if (sourceSlot == null) return;
    final idx = combatCompanions.indexWhere((c) => c.slotIndex == sourceSlot);
    final companion = idx >= 0 ? combatCompanions[idx] : null;

    // Mane+Plant rooted explosion — root tags spread to the splashed.
    if (enemy.maneRootSlot != null && enemy.maneRootTimer > 0) {
      const explodeRadius = 165.0;
      final explodeDamage = (companion?.elemAtk ?? 4) * 2.1;
      for (final other in combatEnemies) {
        if (other.isDead || identical(other, enemy)) continue;
        if ((other.position - enemy.position).distance > explodeRadius) {
          continue;
        }
        _damageEnemyDirect(
          other,
          explodeDamage,
          sourceSlot: enemy.maneRootSlot,
        );
        other.maneRootSlot = enemy.maneRootSlot;
        other.maneRootTimer = max(other.maneRootTimer, 1.4);
        other.slowTimer = max(other.slowTimer, 1.4);
        other.slowMultiplier = 0;
      }
      _spawnHitSpark(enemy.position, elementColor('Plant'));
    }

    if (companion == null) return;
    final family = companion.member.family.toLowerCase();

    // Horn special on-kill effects, gated by the cast's active window.
    if (family == 'horn' && companion.hornSpecialActiveWindow > 0) {
      _applyHornSpecialKillEffect(companion, enemy, sourceSlot);
    }

    _spawnPipKillPlacement(
      sourceSlot,
      companion,
      enemy.position,
      fromPipSpecial: fromPipSpecial,
    );

    // Pip+Spirit: kill streak charges an empower window.
    if (family == 'pip' && companion.member.element == 'Spirit') {
      companion.abilityKillStacks++;
      final intel = companion.member.statIntelligence;
      final spiritThreshold =
          (8 * _effStatScale(intel, perPoint: -0.10, min: 0.55, max: 1.20))
              .round()
              .clamp(4, 10);
      if (companion.abilityKillStacks >= spiritThreshold) {
        companion.abilityKillStacks = 0;
        companion.pipSpiritEmpowerTimer = max(
          companion.pipSpiritEmpowerTimer,
          6.0 * _effStatScale(intel, perPoint: 0.12, min: 0.85, max: 1.50),
        );
        _spawnHitSpark(companion.position, elementColor('Spirit'));
      }
    }

    // Mask+Spirit: kills gather wisps; at the threshold they erupt.
    if (family == 'mask' && companion.member.element == 'Spirit') {
      companion.abilityKillStacks++;
      const wispThreshold = 6;
      if (companion.abilityKillStacks >= wispThreshold) {
        companion.abilityKillStacks = 0;
        final burstDamage = companion.elemAtk * 1.6;
        const burstRadius = 220.0;
        _damageEnemiesNear(
          companion.position,
          burstRadius,
          burstDamage,
          sourceSlot: sourceSlot,
          exclude: enemy,
        );
        _spawnDetonationBurst(
          companion.position,
          elementColor('Spirit'),
          burstRadius * 0.6,
        );
      }
    }
  }

  /// Horn per-element on-kill payoffs (Steam chain-cast geyser, Lava seeker
  /// flames, Blood self-heal) — survival's dispatcher, creature-pool heals.
  void _applyHornSpecialKillEffect(
    CosmicSurvivalCompanion comp,
    CosmicSurvivalEnemy enemy,
    int? sourceSlot,
  ) {
    switch (comp.member.element) {
      case 'Steam':
        comp.specialCooldown = 0;
        final sizeScale = _effStatScale(
          comp.member.statBeauty,
          perPoint: 0.10,
          min: 0.85,
          max: 1.25,
        );
        final durScale = _effStatScale(
          comp.member.statIntelligence,
          perPoint: 0.08,
          min: 0.88,
          max: 1.20,
        );
        combatProjectiles.add(
          Projectile(
            position: enemy.position,
            angle: 0,
            element: 'Steam',
            damage: 0,
            life: 2.6 * durScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.6 * sizeScale,
            visualScale: 1.6 * sizeScale,
            visualStyle: ProjectileVisualStyle.hornImpact,
            sourceSlotIndex: sourceSlot,
            abilityFamily: 'horn',
            tauntRadius: 100.0 * sizeScale,
            tauntStrength: 1.0,
            tickEffect: AbilityEffectKind.geyser,
            effectPower: max(1.0, comp.elemAtk * 0.5),
            effectRadius: 60.0 * sizeScale,
            effectDuration: 2.6 * durScale,
          ),
        );
        break;
      case 'Lava':
        _spawnDetonationBurst(enemy.position, elementColor('Lava'), 150);
        final lavaScale = _effStatScale(
          comp.member.statBeauty,
          perPoint: 0.10,
          min: 0.85,
          max: 1.30,
        );
        final seekRadius = 280.0 * lavaScale;
        final nearbyTargets = <CosmicSurvivalEnemy>[
          for (final other in combatEnemies)
            if (!other.isDead &&
                !identical(other, enemy) &&
                (other.position - enemy.position).distance <= seekRadius)
              other,
        ];
        if (nearbyTargets.isEmpty) break;
        final flameCount = min(
          (4 * lavaScale).round().clamp(3, 6),
          nearbyTargets.length,
        );
        for (var i = 0; i < flameCount; i++) {
          final tgt = nearbyTargets[i % nearbyTargets.length];
          final dir = tgt.position - enemy.position;
          combatProjectiles.add(
            Projectile(
              position: enemy.position,
              angle: atan2(dir.dy, dir.dx),
              element: 'Fire',
              damage: max(1.0, comp.elemAtk * 0.50),
              life: 1.4,
              speedMultiplier: 1.5,
              homing: true,
              homingStrength: 4.0,
              piercing: false,
              radiusMultiplier: 0.9,
              visualScale: 0.95,
              visualStyle: ProjectileVisualStyle.standard,
              sourceSlotIndex: sourceSlot,
              abilityFamily: 'horn',
            ),
          );
        }
        break;
      case 'Blood':
        final bloodScale = _effStatScale(
          comp.member.statBeauty,
          perPoint: 0.10,
          min: 0.85,
          max: 1.40,
        );
        _healSourceCreature(
          sourceSlot,
          max(2, (comp.maxHp * 0.05 * bloodScale).round()).toDouble(),
        );
        break;
    }
  }

  /// Pip element-on-kill placements (Fire/Dust/Crystal pools from SPECIAL
  /// kills, Dark black hole from AUTO kills) — survival's dispatcher.
  void _spawnPipKillPlacement(
    int? slot,
    CosmicSurvivalCompanion? companion,
    Offset position, {
    bool fromPipSpecial = false,
  }) {
    if (companion == null) return;
    if (companion.member.family.toLowerCase() != 'pip') return;
    final element = companion.member.element;
    final allowedBySource = switch (element) {
      'Dark' => !fromPipSpecial,
      'Fire' || 'Dust' || 'Crystal' => fromPipSpecial,
      _ => true,
    };
    if (!allowedBySource) return;
    final scale = companion.elemAtk * 0.20 + 4.0;
    final sizeScale = _effStatScale(
      companion.member.statBeauty,
      perPoint: 0.10,
      min: 0.85,
      max: 1.30,
    );
    final durScale = _effStatScale(
      companion.member.statIntelligence,
      perPoint: 0.08,
      min: 0.88,
      max: 1.25,
    );
    switch (element) {
      case 'Fire':
        combatProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Fire',
            damage: 0,
            life: 4.5 * durScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.6 * sizeScale,
            visualScale: 1.4 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slot,
            abilityFamily: 'pip',
            tickEffect: AbilityEffectKind.burn,
            effectPower: scale * 0.45,
            effectRadius: 60 * sizeScale,
            effectDuration: 4.5 * durScale,
          ),
        );
        break;
      case 'Dust':
        combatProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Dust',
            damage: 0,
            life: 3.5 * durScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.4 * sizeScale,
            visualScale: 1.3 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slot,
            abilityFamily: 'pip',
            tickEffect: AbilityEffectKind.slow,
            effectPower: scale * 0.18,
            effectRadius: 70 * sizeScale,
            effectDuration: 1.6 * durScale,
          ),
        );
        break;
      case 'Crystal':
        combatProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Crystal',
            damage: 0,
            life: 9.0 * durScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            decoy: true,
            decoyHp: (18.0 + companion.elemAtk * 0.6) * sizeScale,
            tauntRadius: 130 * sizeScale,
            tauntStrength: 3.6,
            effectRadius: 38 * sizeScale,
            radiusMultiplier: 0.7 * sizeScale,
            visualScale: 0.75 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slot,
            abilityFamily: 'pip',
          ),
        );
        break;
      case 'Dark':
        combatProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Dark',
            damage: 0,
            life: 3.6,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.5 * sizeScale,
            visualScale: 1.4 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slot,
            abilityFamily: 'pip',
            tickEffect: AbilityEffectKind.blackHole,
            effectPower: scale * 0.32,
            effectRadius: 120 * sizeScale,
            effectDuration: 3.6 * durScale,
          ),
        );
        break;
    }
  }

  /// Survival's `resolveAbilityHit`: let meteors and mask traps run their
  /// per-element on-contact dispatchers before the generic effect.
  void _resolveAbilityHit(
    Projectile projectile,
    CosmicSurvivalEnemy enemy, {
    required bool killed,
  }) {
    if (projectile.abilityFamily == 'let') {
      _resolveLetMeteorHit(projectile, enemy);
      return;
    }
    if (projectile.abilityFamily == 'mask') {
      final consumed = _resolveMaskTrapHit(projectile, enemy);
      if (consumed) {
        if (killed) _resolveAbilityKill(projectile, enemy);
        return;
      }
    }
    _applyProjectileEffect(projectile, enemy, projectile.hitEffect);
    if (killed) _resolveAbilityKill(projectile, enemy);
  }

  void _resolveAbilityKill(Projectile projectile, CosmicSurvivalEnemy enemy) {
    if (projectile.abilityFamily == 'let') {
      _resolveLetMeteorImpactAftermath(
        projectile,
        enemy.position,
        primary: enemy,
      );
      return;
    }
    _applyProjectileEffect(projectile, enemy, projectile.killEffect);
  }

  /// Mask-family on-contact dispatcher (survival's `_resolveMaskTrapHit`).
  /// Returns true when the element fully handles the hit.
  bool _resolveMaskTrapHit(Projectile projectile, CosmicSurvivalEnemy enemy) {
    switch (projectile.element ?? '') {
      case 'Air':
        projectile.abilityGrowthTimer = 1.0; // activation flash
        return false;
      case 'Light':
        // The void is always lethal; bright collapse, then expire.
        _damageEnemyDirect(
          enemy,
          enemy.hp + 1,
          sourceSlot: projectile.sourceSlotIndex,
        );
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.4);
        return true;
      case 'Dark':
        // Yeet: sling the enemy hard away from the void hole.
        final dir = enemy.position - projectile.position;
        final dist = dir.distance;
        if (dist > 0.01) {
          final norm = dir / dist;
          enemy.knockbackVelocity += norm * 820.0;
          enemy.position = _clampToBounds(
            enemy.position + norm * 48.0,
            currentRoom,
          );
        }
        enemy.slowTimer = max(enemy.slowTimer, 0.9);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.55);
        return true;
      case 'Crystal':
        _damageEnemyDirect(
          enemy,
          projectile.damage,
          sourceSlot: projectile.sourceSlotIndex,
        );
        _spawnMaskCrystalShards(projectile, enemy.position);
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.3);
        return true;
      case 'Fire':
        _damageEnemyDirect(
          enemy,
          projectile.damage,
          sourceSlot: projectile.sourceSlotIndex,
        );
        _spawnMaskFirePool(projectile, projectile.position);
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.35);
        return true;
      case 'Lightning':
        // Field grows on each hit; damage ticks via the generic chain.
        projectile.effectRadius = min(260.0, projectile.effectRadius + 14.0);
        projectile.life = min(projectile.life + 0.6, 18.0);
        return false;
      case 'Blood':
        // Tag for the permanent per-frame drain (consumed in the enemy
        // update loop; drained HP heals the party).
        enemy.maskBloodDrainSlot =
            projectile.sourceSlotIndex ?? enemy.maskBloodDrainSlot;
        return false;
      default:
        return false;
    }
  }

  void _spawnMaskCrystalShards(Projectile parent, Offset at) {
    final baseAngle = _combatRng.nextDouble() * pi * 2;
    for (var i = 0; i < 3; i++) {
      final a = baseAngle + i * (pi * 2 / 3);
      combatProjectiles.add(
        Projectile(
          position: at + Offset(cos(a), sin(a)) * 18.0,
          angle: 0,
          element: parent.element,
          damage: parent.damage * 0.55,
          life: 4.0,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: max(0.9, parent.radiusMultiplier * 0.55),
          visualScale: max(1.0, parent.visualScale * 0.55),
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: parent.sourceSlotIndex,
          abilityFamily: 'mask',
          hitEffect: AbilityEffectKind.splash,
          effectPower: parent.effectPower * 0.55,
          effectRadius: max(60.0, parent.effectRadius * 0.65),
          effectDuration: 0,
        ),
      );
    }
  }

  void _spawnMaskFirePool(Projectile parent, Offset at) {
    combatProjectiles.add(
      Projectile(
        position: at,
        angle: 0,
        element: 'Fire',
        damage: 0,
        life: max(4.0, parent.effectDuration),
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: max(1.2, parent.radiusMultiplier * 1.2),
        visualScale: max(1.6, parent.visualScale * 1.2),
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: parent.sourceSlotIndex,
        abilityFamily: 'mask',
        tickEffect: AbilityEffectKind.burn,
        effectPower: parent.effectPower,
        effectRadius: max(80.0, parent.effectRadius),
        effectDuration: max(4.0, parent.effectDuration),
      ),
    );
  }

  /// Let meteor per-element ON-HIT verbs (survival's dispatcher).
  void _resolveLetMeteorHit(Projectile projectile, CosmicSurvivalEnemy enemy) {
    final element = projectile.element ?? '';
    final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
    switch (element) {
      case 'Dust':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.slow,
            radius: 130,
            duration: 4.5,
            power: projectile.effectPower * 0.25,
          );
        }
        break;
      case 'Lava':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.burn,
            radius: 145,
            duration: 4.2,
            power: projectile.damage * 0.13,
          );
        }
        break;
      case 'Poison':
        enemy.slowTimer = max(enemy.slowTimer, 2.2);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.72);
        enemy.attackCooldown = max(enemy.attackCooldown, 1.4);
        _damageEnemyDirect(
          enemy,
          projectile.damage * 0.20,
          sourceSlot: projectile.sourceSlotIndex,
        );
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.poison,
            radius: 116,
            duration: 3.8,
            power: projectile.damage * 0.08,
            visualScale: 1.9,
          );
        }
        break;
      case 'Earth':
        _healAllCreatures(projectile.damage * 0.26 * 0.4);
        _damageEnemiesNear(
          enemy.position,
          max(150, projectile.effectRadius),
          projectile.damage * 0.38,
          sourceSlot: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.stun,
            radius: 128,
            duration: 3.2,
            power: projectile.damage * 0.10,
            visualScale: 1.55,
          );
        }
        break;
      case 'Spirit':
        if (!enemy.isDead &&
            (enemy.hpFraction <= 0.35 ||
                _combatRng.nextDouble() <= projectile.effectChance)) {
          _damageEnemyDirect(
            enemy,
            enemy.hp + 1,
            sourceSlot: projectile.sourceSlotIndex,
          );
        } else if (!enemy.isDead) {
          _damageEnemyDirect(
            enemy,
            projectile.damage * 0.35,
            sourceSlot: projectile.sourceSlotIndex,
          );
        }
        break;
      case 'Crystal':
        enemy.slowTimer = max(enemy.slowTimer, 3.5);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.10);
        enemy.knockbackVelocity = Offset.zero;
        _damageEnemyDirect(
          enemy,
          projectile.damage * 0.25,
          sourceSlot: projectile.sourceSlotIndex,
        );
        _damageEnemiesNear(
          enemy.position,
          max(140, projectile.effectRadius),
          projectile.damage * 0.32,
          sourceSlot: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        break;
      case 'Lightning':
        _triggerChainLightning(
          sourceEnemy: enemy,
          baseDamage: projectile.damage * 0.72,
          sourceSlot: projectile.sourceSlotIndex,
          remainingChains: max(2, projectile.effectCount),
        );
        _damageEnemyDirect(
          enemy,
          projectile.damage * 0.18,
          sourceSlot: projectile.sourceSlotIndex,
        );
        break;
      case 'Ice':
        enemy.slowTimer = max(enemy.slowTimer, 3.2);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.05);
        enemy.knockbackVelocity = Offset.zero;
        break;
      case 'Water':
        _damageEnemiesNear(
          enemy.position,
          max(125, projectile.effectRadius),
          projectile.damage * 0.42,
          sourceSlot: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        break;
      default:
        break;
    }
    _resolveLetMeteorImpactAftermath(
      projectile,
      enemy.position,
      primary: enemy,
    );
  }

  /// Let meteor per-element AFTERMATH (zones, follow-ups, drains).
  void _resolveLetMeteorImpactAftermath(
    Projectile projectile,
    Offset center, {
    CosmicSurvivalEnemy? primary,
  }) {
    final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
    switch (projectile.element) {
      case 'Air':
        final radius = max(180.0, projectile.effectRadius);
        for (final enemy in combatEnemies) {
          if (enemy.isDead) continue;
          if ((enemy.position - center).distance > radius) continue;
          final dir = enemy.position - center;
          final dist = dir.distance;
          if (dist > 0.01) {
            enemy.knockbackVelocity +=
                (dir / dist) * (340 + projectile.damage * 5.0).clamp(120, 760);
          }
        }
        break;
      case 'Plant':
        if (isMeteorCore) {
          for (var i = 0; i < 4; i++) {
            final a = projectile.angle + (i - 1.5) * 0.75;
            _spawnLetZone(
              projectile,
              _clampToBounds(
                center + Offset(cos(a), sin(a)) * (28 + i * 8),
                currentRoom,
              ),
              element: 'Plant',
              tickEffect: AbilityEffectKind.zoneDamage,
              radius: 64,
              duration: 30.0,
              power: projectile.damage * 0.22,
              visualScale: 1.2,
            );
          }
        }
        break;
      case 'Blood':
        final drain = projectile.damage * 0.22;
        final radius = max(170.0, projectile.effectRadius);
        for (final enemy in combatEnemies) {
          if (enemy.isDead) continue;
          if (primary != null && identical(enemy, primary)) continue;
          if ((enemy.position - center).distance > radius) continue;
          _damageEnemyDirect(
            enemy,
            drain,
            sourceSlot: projectile.sourceSlotIndex,
          );
          _kinBeams.add(
            _KinBeamFx(
              origin: enemy.position,
              end: center,
              color: elementColor('Blood'),
            ),
          );
        }
        _healAllCreatures(drain * 0.18);
        break;
      case 'Light':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            center,
            element: 'Light',
            tickEffect: AbilityEffectKind.zoneHeal,
            radius: 130,
            duration: 5.5,
            power: projectile.damage * 0.16,
            visualScale: 1.7,
          );
        }
        break;
      case 'Fire':
        _damageEnemiesNear(
          center,
          max(555, projectile.effectRadius * 3.0),
          projectile.damage * 0.72,
          sourceSlot: projectile.sourceSlotIndex,
          exclude: primary,
        );
        _spawnDetonationBurst(
          center,
          elementColor('Fire'),
          max(240, projectile.effectRadius * 3.0),
        );
        break;
      case 'Dark':
        if (projectile.effectStacks == 0) {
          _spawnDarkLetKillMeteors(projectile, center);
        } else {
          final radius = max(120.0, projectile.effectRadius);
          for (final enemy in combatEnemies) {
            if (enemy.isDead) continue;
            final dir = center - enemy.position;
            final dist = dir.distance;
            if (dist <= 0.01 || dist > radius) continue;
            enemy.position += (dir / dist) * min(28.0, 720.0 / dist);
            enemy.slowTimer = max(enemy.slowTimer, projectile.effectDuration);
            enemy.slowMultiplier = min(enemy.slowMultiplier, 0.25);
          }
        }
        break;
      case 'Steam':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            center,
            element: 'Steam',
            tickEffect: AbilityEffectKind.geyser,
            radius: 115,
            duration: 12.0,
            power: projectile.damage * 0.12,
            visualScale: 1.6,
          );
        }
        break;
      case 'Mud':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            center,
            element: 'Mud',
            tickEffect: AbilityEffectKind.stun,
            radius: 130,
            duration: 4.8,
            power: projectile.damage * 0.08,
            visualScale: 1.5,
          );
        }
        break;
      default:
        break;
    }
  }

  void _spawnLetZone(
    Projectile source,
    Offset center, {
    required String element,
    required AbilityEffectKind tickEffect,
    required double radius,
    required double duration,
    required double power,
    double visualScale = 1.35,
  }) {
    combatProjectiles.add(
      Projectile(
        position: center,
        angle: 0,
        element: element,
        damage: 0,
        life: duration,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: max(1.0, radius / 28.0),
        visualScale: visualScale,
        visualStyle: ProjectileVisualStyle.letShard,
        sourceSlotIndex: source.sourceSlotIndex,
        abilityFamily: 'let',
        tickEffect: tickEffect,
        effectPower: power,
        effectRadius: radius,
        effectDuration: duration,
      ),
    );
  }

  void _spawnDarkLetKillMeteors(Projectile source, Offset center) {
    final count = CosmicAbilityRuntime.darkLetFollowupCount(
      source.letCasterIntelligence,
    );
    final seekRadius = max(420.0, source.effectRadius * 3.0);
    final targets = <CosmicSurvivalEnemy>[
      for (final enemy in combatEnemies)
        if (!enemy.isDead && (enemy.position - center).distance <= seekRadius)
          enemy,
    ];
    for (var i = 0; i < count; i++) {
      final target = i < targets.length ? targets[i].position : null;
      final a = target != null
          ? atan2(target.dy - center.dy, target.dx - center.dx)
          : source.angle + (i - 2) * 0.42;
      combatProjectiles.add(
        Projectile(
          position: center - Offset(cos(a), sin(a)) * (46.0 + i * 8.0),
          angle: a,
          element: 'Dark',
          damage: source.damage * 0.7,
          life: 1.8,
          speedMultiplier: 0.82,
          radiusMultiplier: max(3.5, source.radiusMultiplier * 2.0),
          visualScale: max(3.5, source.visualScale * 2.0),
          visualStyle: ProjectileVisualStyle.meteor,
          homing: target != null,
          homingStrength: 2.4,
          sourceSlotIndex: source.sourceSlotIndex,
          abilityFamily: 'let',
          hitEffect: AbilityEffectKind.pull,
          effectPower: source.effectPower * 0.85,
          effectRadius: max(140.0, source.effectRadius),
          effectDuration: source.effectDuration,
          effectStacks: 1, // children never chain again
        ),
      );
    }
  }

  void _triggerChainLightning({
    required CosmicSurvivalEnemy sourceEnemy,
    required double baseDamage,
    required int remainingChains,
    int? sourceSlot,
  }) {
    if (remainingChains <= 0 || sourceSlot == null) return;
    var current = sourceEnemy;
    for (var i = 0; i < remainingChains; i++) {
      CosmicSurvivalEnemy? next;
      var bestD = 135.0;
      for (final other in combatEnemies) {
        if (other.isDead || identical(other, current)) continue;
        final d = (other.position - current.position).distance;
        if (d < bestD) {
          bestD = d;
          next = other;
        }
      }
      if (next == null) break;
      final bounceDamage = baseDamage * (0.55 - i * 0.10).clamp(0.25, 0.55);
      _spawnHitSpark(next.position, elementColor('Lightning'));
      _kinBeams.add(
        _KinBeamFx(
          origin: current.position,
          end: next.position,
          color: elementColor('Lightning'),
        ),
      );
      _damageEnemyDirect(next, bounceDamage, sourceSlot: sourceSlot);
      current = next;
    }
  }

  void _spawnDetonationBurst(Offset center, Color color, double radius) {
    if (_alchemyParticles.length >= 150) return;
    final burstCount = max(10, (radius / 10).round()).clamp(10, 26);
    for (var i = 0; i < burstCount; i++) {
      final angle = (i / burstCount) * pi * 2;
      final speed = radius * (1.4 + _combatRng.nextDouble() * 0.6);
      _alchemyParticles.add(
        _AlchemyParticle(
          position: center,
          velocity: Offset(cos(angle), sin(angle)) * speed,
          color: color.withValues(alpha: 0.92),
          maxLife: 0.24 + _combatRng.nextDouble() * 0.22,
          size: 3.0 + _combatRng.nextDouble() * 3.2,
        ),
      );
    }
  }

  void _releasePendingChargeBurst(
    CosmicSurvivalCompanion comp,
    DungeonCreature creature,
  ) {
    final pending = comp.pendingChargeBurst;
    if (pending != null && pending.isNotEmpty) {
      final originDelta =
          creature.position - (comp.pendingChargeOrigin ?? creature.position);
      // Absorb-to-blast conversion scales with Beauty (survival's brew
      // formula): 1.4 × statScale(0.85..1.40).
      final absorbMul =
          1.4 * (1.0 + (comp.member.statBeauty - 3.0) * 0.10).clamp(0.85, 1.40);
      for (final p in pending) {
        p.position = p.position + originDelta;
        // Lightning discharge: absorbed damage pumps the chain zone.
        if (p.tickEffect == AbilityEffectKind.chain &&
            comp.hornLightningAbsorbed > 0) {
          p.effectPower += comp.hornLightningAbsorbed * absorbMul;
        }
      }
      comp.hornLightningAbsorbed = 0;
      combatProjectiles.addAll(pending);
      _spawnHitSpark(creature.position, elementColor(comp.member.element));
      final isStorm = comp.member.element == 'Lightning';
      _spawnAlchemyBurst(
        creature.position,
        producedElement: comp.member.element,
        unstable: isStorm,
        particleCount: isStorm ? 36 : 22,
        intensity: isStorm ? 1.35 : 1.0,
      );
    }
    // Horn+Dark: slam the captured cluster down at the arrival point.
    final captured = comp.hornDarkCaptured;
    if (captured != null && captured.isNotEmpty) {
      for (final e in captured) {
        if (e.isDead) continue;
        final a = _combatRng.nextDouble() * 2 * pi;
        final r = 20.0 + _combatRng.nextDouble() * 50.0;
        e.position = _clampToBounds(
          creature.position + Offset(cos(a) * r, sin(a) * r),
          currentRoom,
        );
        e.hp -= comp.chargeDamage * 1.2 * _enemyDamageTakenScale(e);
        e.hitFlash = 0.2;
        if (e.hp <= 0) e.isDead = true;
      }
      comp.hornDarkCaptured = null;
    }
    comp.pendingChargeBurst = null;
    comp.pendingChargeOrigin = null;
    comp.chargeTarget = null;
    comp.chargeHitIds = null;
    comp.chargePathType = '';
    comp.chargeCircleCenter = null;
    // The airborne ram may end over open sky — settle back to footing
    // (fall recovery for the player's body, snap for anything else).
    if (!_onSolidGround(creature.position, currentRoom)) {
      if (identical(creature, active) && !flightActive) {
        _beginFallRecovery(
          creature,
          creature.lastSafe,
          hint: 'The ram carried you over the void — drifting back',
        );
      } else {
        creature.position = creature.lastSafe;
      }
    } else {
      creature.lastSafe = creature.position;
    }
  }

  /// Mirror survival's companion-side support effects. Heals are applied to
  /// the CREATURE pool — it is authoritative (comp.currentHp is re-derived
  /// from creature hp every frame by _syncCombatFromCreatures).
  void _applySpecialSupportEffects(
    CosmicSurvivalCompanion comp,
    DungeonCreature creature,
    CosmicSpecialResult result,
  ) {
    if (result.shieldHp > 0) {
      comp.shieldHp = max(comp.shieldHp, result.shieldHp);
    }
    if (result.selfHeal > 0) {
      _healCreature(creature, comp, result.selfHeal.toDouble());
      _spawnAlchemyBurst(
        creature.position,
        producedElement: 'Light',
        reagentElements: [creature.member.element],
        particleCount: 12,
        intensity: 0.6,
      );
    }
    if (result.shipHeal > 0) {
      // No ship down here — the party is the vessel: share it out.
      for (
        var i = 0;
        i < creatures.length && i < combatCompanions.length;
        i++
      ) {
        if (!creatures[i].alive) continue;
        _healCreature(creatures[i], combatCompanions[i], result.shipHeal * 0.5);
      }
    }
    if (result.blessingTimer > 0) {
      comp.blessingTimer = max(comp.blessingTimer, result.blessingTimer);
      comp.blessingHealPerTick = max(
        comp.blessingHealPerTick,
        result.blessingHealPerTick,
      );
    }
    if (result.basicHasteTimer > 0) {
      comp.basicHasteTimer = result.basicHasteTimer;
      comp.basicHasteMultiplier = result.basicHasteMultiplier;
    }
  }

  /// Heal a creature by an amount expressed in COMPANION hp units.
  void _healCreature(
    DungeonCreature creature,
    CosmicSurvivalCompanion comp,
    double compAmount,
  ) {
    if (!creature.alive || comp.maxHp <= 0) return;
    creature.hp = (creature.hp + creature.maxHp * (compAmount / comp.maxHp))
        .clamp(0.0, creature.maxHp);
  }

  // ── Utility activation ──────────────────────────────────

  void activateAbility() {
    final a = active;
    if (a == null) return;
    _spawnUtilitySignature(a);
    // Object-driven interactions first, so any creature near a conduit can
    // attempt it — the object itself decides whether it answers.
    if (_tryChannel(a)) {
      onChanged();
      return;
    }
    // Wind-Crown Spire: wake a gust shrine (Star 1), crank a storm-rod or
    // shove the storm-cell (Star 3 and the Roc's own fight). The rods sit
    // inside the guardian's radius, so — like Lightning's grounding spike —
    // they are checked BEFORE the guardian's catch.
    if (_isSpire && (_tryGustShrine(a) || _tryStormRod(a) || _tryHerdCell(a))) {
      onChanged();
      return;
    }
    // Storm Circuit: the grounding spike outranks the guardian's own catch —
    // the spike IS the fight's verb (§7: Raikuma feeds on powered trunks),
    // and it sits inside the guardian's interaction radius.
    if (_isCircuit && _tryCoreBreaker(a)) {
      onChanged();
      return;
    }
    // Molten Reliquary: the ring's heads outrank the guardian's own catch —
    // they sit inside its radius and they ARE the fight's verb (§7).
    if (_isFoundry && _tryHeartHead(a)) {
      onChanged();
      return;
    }
    // Venom Monastery: a phial in hand outranks the guardian's own catch —
    // the dose IS the fight's verb (§7: Blightfang's lull answers physic, not
    // a clock). Empty-handed this declines and the strike path runs.
    if (_isVenom && _tryDoseBlightfang(a)) {
      onChanged();
      return;
    }
    // The Frozen Observatory: freezing a flue, the rimefall, the orrery's
    // glaze/shove, the mirror ring, the font and Frowyrm's pillar all ride
    // one dispatcher — and the pillar, like Lightning's spike, must outrank
    // the guardian's own catch.
    if (_isShaft && _tryShaftVerb(a)) {
      onChanged();
      return;
    }
    // The Sinking Altar: the drag, the haul, the basins, the sough, the
    // sink-pit and Bogdrya's mire anchor all ride one dispatcher — and the
    // anchor, like Ice's pillar, must outrank the guardian's own catch.
    if (_isBog && _tryBogVerb(a)) {
      onChanged();
      return;
    }
    // The Ruins of Time: the spade, the vanes, the yard, the armillary, the
    // glass and Ashdjinn's cut all ride one dispatcher — and the cut, like
    // Lightning's spike, must outrank the guardian's own catch.
    if (_isRuins && _tryRuinsVerb(a)) {
      onChanged();
      return;
    }
    // The Prism Labyrinth: the glass face, the lamp, the hearth shard, the
    // font, the berth chain, the anneal, the choir floor and the shunt itself
    // all ride one dispatcher — and the choir plate, like Ice's pillar, must
    // outrank the guardian's own catch.
    if (_isKeep && _tryKeepVerb(a)) {
      onChanged();
      return;
    }
    // The Echo Grave: the mouth, the lych-stones, the telling, the drowned
    // brink, the sigil, the lamp and the hollow's mark all ride one
    // dispatcher — and the arena's stone, like Ice's pillar, must outrank the
    // guardian's own catch, because passing over IS the fight.
    if (_isWake && _tryGraveVerb(a)) {
      onChanged();
      return;
    }
    // The Verdant Crypt: the briar, the galls, the mulch pits, the lamps, the
    // growth altar, the sepulchre, the hidden seed and the seed beds all ride
    // one dispatcher — and the arena's root-gall, like Ice's pillar, must
    // outrank the guardian's own catch.
    if (_isCrypt && _tryCryptVerb(a)) {
      onChanged();
      return;
    }
    // The Eclipse Vault: the pall, the gnomons, the arena's vane, the
    // analemma's stones, the shadow-anchors and the nave's snuffer all ride
    // one dispatcher — and the vane, like Plant's root-gall, must outrank the
    // guardian's own catch.
    if (_isVault && _tryVaultVerb(a)) {
      onChanged();
      return;
    }
    // The Beacon Archive: the door-shutter, the beacons, the court's effigies,
    // the slips behind the shelves and the reading floor's shutter-ring all
    // ride one dispatcher.
    if (_isArchive && _tryArchiveVerb(a)) {
      onChanged();
      return;
    }
    // The Sanguine Orrery: the pericardium, the arena's vagal node, the four
    // mouths, the collateral cocks, the rite's balance, the heart-drum and
    // the Kin's steadying all ride one dispatcher — and the vagal node, like
    // Dark's shadow-vane, must outrank the guardian's own catch.
    if (_isHeart && _tryHeartVerb(a)) {
      onChanged();
      return;
    }
    // An awake guardian nearby: calm (Kin) or strike (anyone) in the lull.
    if (_tryGuardian(a)) {
      onChanged();
      return;
    }
    // Cinder Cathedral interactions (hearth, braziers, garden, vesper).
    if (_tryCathedral(a)) {
      onChanged();
      return;
    }
    // Mirror-Tide Temple interactions (fountain, valves, seals, currents,
    // moon-pools, the frozen moon).
    if (_tryTemple(a)) {
      onChanged();
      return;
    }
    // Buried Giant interactions (lintel, ribs, sockets, the stone scale,
    // the open palm).
    if (_tryBarrow(a)) {
      onChanged();
      return;
    }
    // Storm Circuit interactions (charge pylons, rotate conductor mirrors,
    // herd/heat storm-cells, the breaker maze, the Thunderbolt egg).
    if (_tryCircuit(a)) {
      onChanged();
      return;
    }
    // Fire Star 2: the garth's three verbs answer before anything else in
    // the cathedral — the room IS the burn now.
    if (_tryBurn(a)) {
      onChanged();
      return;
    }
    // Steam Star 1: Earth's stone is the room's own verb, so it answers
    // before the ring-main's fixtures.
    if (_tryEarthRock(a)) {
      onChanged();
      return;
    }
    // Pressure Cathedral interactions (vents/seals steer the clock, boiler
    // pack+ignite, the escapement, the entry vent).
    if (_tryPressure(a)) {
      onChanged();
      return;
    }
    // Molten Reliquary interactions (the crucible and its font, the points,
    // the accumulator, a hand chill, melting a casting out, keys and wards).
    if (_tryFoundry(a)) {
      onChanged();
      return;
    }
    // Venom Monastery interactions (the wax seals, the still's four taps, a
    // ward's censer, the prior's cross, the oubliette, the sick wisp).
    if (_tryMonastery(a)) {
      onChanged();
      return;
    }
    // Wonder-cloud trials (ring conjunction, anvil shell, veil pinning) —
    // checked before the generic Fire ignite so trial-specific recipe uses
    // (Fire arcing the anvil shell) win over the flavour spark.
    if (_tryWonderTrial(a)) {
      onChanged();
      return;
    }
    // The secret: with all three stars, commune at the compass's heart.
    // Air's lost maxim — finding it pays out once (screen-side, 20 gold).
    if (currentRoomId == 'hub' &&
        starsEarnedCount >= 3 &&
        (a.position - currentRoom.bounds.center).distance < 34) {
      _discoverCloud(kAirFirstWindEggId);
      _setHint(
        'The compass stills. Long before the storm, the Roc wove the first '
        'wind through this loom — the planet remembers, and now it rests.',
        7.5,
      );
      _spawnAlchemyBurst(
        currentRoom.bounds.center,
        producedElement: 'Light',
        reagentElements: const ['Air', 'Spirit'],
        particleCount: 20,
        intensity: 0.8,
      );
      onChanged();
      return;
    }
    // Fire-element contextual ignition (the Air+Fire→Lightning recipe).
    if (a.member.element == 'Fire' && _tryFireIgnite(a)) {
      onChanged();
      return;
    }
    // Lightning answers its own: everything the braid electrifies, the
    // storm-born arc directly (entry rune, conduit B, a carried Anvil).
    if (a.member.element == 'Lightning' && _tryLightningArc(a)) {
      onChanged();
      return;
    }
    // Otherwise fall back to the creature's family ability.
    // Nothing here TALKS any more. A press with no object in reach used to
    // answer with a sentence — "force ripples outward", "energy answers, but
    // nothing nearby takes" — which is the game narrating a tap the player
    // just watched. It shows instead: a pulse of the creature's own element,
    // at the creature, going nowhere. That reads as "I did something and
    // nothing here took it" without a word.
    switch (a.ability) {
      case DungeonAbility.aerialTraversal:
        _toggleGlide(a);
        break;
      case DungeonAbility.insight:
      // A Mask no longer reads the room on its own — the HINT button does,
      // for everybody. Insight was the one family verb that dispensed
      // INFORMATION, and information should never depend on who you brought.
      case DungeonAbility.heavyForce:
      case DungeonAbility.ancientStabilize:
      case DungeonAbility.smallAccess:
      case DungeonAbility.terrainTrail:
      case DungeonAbility.guardianRelic:
      case DungeonAbility.none:
        _spawnAlchemyBurst(
          a.position,
          producedElement: a.member.element,
          particleCount: 8,
          unstable: true,
        );
        break;
    }
    onChanged();
  }

  void _toggleGlide(DungeonCreature a) {
    if (flightActive) {
      flightActive = false;
      // Folding wings over open sky must never strand the creature — drift
      // back to the last solid footing (same recovery as meter exhaustion).
      if (!_onSolidGround(a.position, currentRoom)) {
        _beginFallRecovery(
          a,
          a.lastSafe,
          hint: 'Wings folded mid-air — drifting back to footing',
        );
      }
      return;
    }
    if (!_onSolidGround(a.position, currentRoom)) {
      // A refused launch — the press is the attempt edge.
      _setBlockedHint('Launch from solid ground', 2.4);
      return;
    }
    flightMax = glideSeconds(a.member.statSpeed);
    flightMeter = flightMax;
    flightActive = true;
  }

  /// The room's reading, ASKED FOR rather than carried in.
  ///
  /// This is the same per-planet reveal a Mask used to perform, reachable by
  /// anyone from the HUD. Insight was the one family verb that dispensed
  /// INFORMATION, and information is the worst thing to lock behind party
  /// composition: a player without a Mask was not having a harder time, they
  /// had no route to the knowledge at all and no way to know one existed.
  ///
  /// Everything else about the reading is unchanged — same content, same
  /// priority-protected channel, same intelligence-scaled radius taken from
  /// whoever is currently active — so a smarter creature still reads further.
  void askForRoomHint() {
    final a = active;
    if (a == null) return;
    _hintAsked = true;
    try {
      // Whatever the world last had to say outranks the room's general
      // reading: they pressed this because something just refused them or
      // just told them something, and answering with the mural instead would
      // be a non-sequitur.
      final pending = _pendingAnswer;
      if (pending != null) {
        _pendingAnswer = null;
        _emitHint(pending, _pendingChannel, 3.4);
      } else {
        _inHintChannel(DungeonHintChannel.insight, () => _doReveal(a));
      }
    } finally {
      _hintAsked = false;
    }
    onChanged();
  }

  void _doReveal(DungeonCreature a) {
    final room = currentRoom;
    if (_isCathedral) {
      _cathedralReveal(a, room);
      return;
    }
    if (_isTemple) {
      _templeReveal(a, room);
      return;
    }
    if (_isBarrow) {
      _barrowReveal(a, room);
      return;
    }
    if (_isCircuit) {
      _circuitReveal(a, room);
      return;
    }
    if (_isVapor) {
      _steamReveal(a, room);
      return;
    }
    if (_isFoundry) {
      _foundryReveal(a, room);
      return;
    }
    if (_isVenom) {
      _monasteryReveal(a, room);
      return;
    }
    if (_isShaft) {
      _shaftReveal(a, room);
      return;
    }
    if (_isBog) {
      _bogReveal(a, room);
      return;
    }
    if (_isRuins) {
      _ruinsReveal(a, room);
      return;
    }
    if (_isKeep) {
      _keepReveal(a, room);
      return;
    }
    if (_isWake) {
      _graveReveal(a, room);
      return;
    }
    if (_isCrypt) {
      _cryptReveal(a, room);
      return;
    }
    if (_isVault) {
      _vaultReveal(a, room);
      return;
    }
    if (_isArchive) {
      _archiveReveal(a, room);
      return;
    }
    if (_isHeart) {
      _heartReveal(a, room);
      return;
    }
    if (room.clouds.isEmpty && room.anchors.isEmpty) {
      // Star 1: the shrines' own reading — WHICH walks a sleeping wind will
      // scour is the whole planning layer, and it is EARNED here (§5.6).
      if (room.gustShrines.isNotEmpty || room.windRoutes.isNotEmpty) {
        revealFlash = 0.6;
        revealTier = revealHintTier(a.member.statIntelligence);
        _setInsightHint(_spireWindInsight(room, revealTier));
        return;
      }
      // The rune hall: insight completes the mural's diagram.
      if (room.id == 'storm_rune_hall') {
        revealFlash = 0.6;
        revealTier = revealHintTier(a.member.statIntelligence);
        _setInsightHint(
          'The mural completes — one pylon is HELD, the other is STRUCK',
        );
        return;
      }
      // At the altar, a Mask reads how the storm picks its iron — tiered.
      if (room.conduits.isNotEmpty || room.stormRods.isNotEmpty) {
        revealFlash = 0.6;
        revealTier = revealHintTier(a.member.statIntelligence);
        _setInsightHint(_spireStormInsight(room, revealTier));
      } else {
        _setInsightHint('Nothing hidden stirs here', 2.4);
      }
      return;
    }
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    // In a trial chamber, insight reads the TRIAL (it never bypasses it).
    final sealed = _sealedWonderCloud(room);
    if (sealed != null) {
      _setInsightHint(_wonderInsight(room.id, revealTier));
      return;
    }
    _setInsightHint(
      revealTier >= 2
          ? 'The anchors show ghost outlines'
          : revealTier >= 1
          ? 'The anchors hint at cloud types; more Intelligence would clarify them'
          : 'Needs more Intelligence to read the hidden pattern clearly',
    );
  }

  /// Mask insight, tiered by Intelligence, for each wonder trial.
  String _wonderInsight(String roomId, int tier) => switch (roomId) {
    'spiral_cloud' => _spiralInsight(tier),
    'ring_cloud' =>
      tier >= 1
          ? 'Air, Fire and Lightning circle the orbit — seal it the moment '
                'all three gather'
          : 'Three reagents wander the orbit — their meeting matters',
    'anvil_cloud' =>
      tier >= 1
          ? 'Only storm-charge cracks the shell — Lightning\'s touch, or '
                'Fire braided through the wind'
          : 'The shell is deaf to all but the storm',
    'feather_cloud' =>
      tier >= 1
          ? 'Catch three falling plumes before they settle — the wind '
                'favours Air'
          : 'What falls here must be caught, not found',
    'veil_cloud' =>
      tier >= 1
          ? 'The folds breathe one at a time — pin each while it shows. '
                'Firelight bares them; Lightning pins from afar'
          : 'The shroud hides in plain sight, breathing',
    _ => 'Something here waits to be earned',
  };

  /// Try to channel a conduit the active creature is standing on. Returns true
  /// if a conduit was nearby (action consumed). Conduit A is a HARD GATE
  /// (Lightning + Horn) and the hold now LATCHES — the decay it used to race
  /// retired with the timers (§9.1). Everyone else is refused cleanly.
  ///
  /// (`_tryStabilize`, the Wing-only conduit refresh, retired with those same
  /// timers: it existed solely to make a decaying two-conduit sync solvable
  /// solo, and there is nothing left for it to hold up. §4's "intentional
  /// family exclusives" entry is superseded — see docs/dungeons.md §4.)
  bool _tryChannel(DungeonCreature a) {
    for (final c in currentRoom.conduits) {
      if (c.requiredFamily == null) continue; // storm-struck conduits (e.g. B)
      if ((a.position - c.position).distance > 34) continue;
      final r = evaluateInteraction(a.member, c.requirement);
      switch (r) {
        case InteractionResult.passed:
        case InteractionResult.passedViaRecipe:
          _energizeConduit(c.id);
          _setHint('Conduit ${c.id} takes the charge and holds it');
          _spawnAlchemyBurst(
            c.position,
            producedElement: c.requireElement,
            reagentElements: [a.member.element],
          );
          break;
        case InteractionResult.blockedFamily:
          // The refusal stamps the gate's chip onto the descent panel — once,
          // forever ("the seal remembers", §4).
          final gate = layout.familyGateFor(c.id);
          if (gate != null) {
            _stampFamilyGate(gate);
          } else {
            _setBlockedHint(
              'Only a ${c.requireElement} horn\'s grip holds this current',
            );
          }
          _spawnAlchemyBurst(
            c.position,
            producedElement: c.requireElement,
            reagentElements: [a.member.element],
            unstable: true,
          );
          break;
        case InteractionResult.blockedElement:
        case InteractionResult.blockedStat:
          _setHint('Conduit ${c.id} answers ${c.requireElement} alone');
          _spawnAlchemyBurst(
            c.position,
            producedElement: c.requireElement,
            reagentElements: [a.member.element],
            unstable: true,
          );
          break;
      }
      return true;
    }
    return false;
  }

  bool _tryFireIgnite(DungeonCreature a) {
    final room = currentRoom;
    for (final cur in room.currents) {
      if (!cur.rect.contains(a.position)) continue;
      if (room.id == 'entry' && !entryDoorRevealed) {
        entryDoorRevealed = true;
        _discoverCloud(entryDoorDiscoveryId); // persist the reveal
        final doorCenter = room.doors.isNotEmpty
            ? room.doors.first.rect.center
            : a.position;
        _setHint('Air and Fire flare — the right passage reveals');
        _spawnAlchemyBurst(
          cur.rect.center,
          producedElement: 'Lightning',
          reagentElements: const ['Air', 'Fire'],
          unstable: true,
          particleCount: 34,
          intensity: 1.35,
        );
        _spawnAlchemyBurst(
          doorCenter,
          producedElement: 'Lightning',
          reagentElements: const ['Air', 'Fire'],
          unstable: true,
          particleCount: 26,
          intensity: 1.15,
        );
        return true;
      }
      // Loom: charge a carried Anvil into a Thundercloud.
      if (carriedCloudType == 'Anvil') {
        carriedCloudType = 'Thundercloud';
        _setHint('Air and Fire braid through the cloud — thunder wakes inside');
        _spawnAlchemyBurst(
          a.position,
          producedElement: 'Lightning',
          reagentElements: const ['Air', 'Fire'],
          unstable: true,
        );
        spawnWispWave(
          element: 'Lightning',
          center: a.position,
          count: 2,
          unstable: true,
          announce: false, // "thunder wakes inside" stays on screen
        );
        return true;
      }
      _setHint('Air and Fire braid into a brief Lightning spark');
      _spawnAlchemyBurst(
        a.position,
        producedElement: 'Lightning',
        reagentElements: const ['Air', 'Fire'],
        unstable: true,
      );
      return true;
    }
    return false;
  }

  /// Lightning answers its own: anywhere the Air+Fire braid would electrify
  /// something, a Lightning creature arcs it DIRECTLY — the entry rune (from
  /// inside the gust), conduit B (by touch), or a carried Anvil
  /// ("electrifying the cloud"). Returns true if the arc was consumed.
  bool _tryLightningArc(DungeonCreature a) {
    final room = currentRoom;
    // Entry passage: the gust carries the arc to the hidden door.
    if (room.id == 'entry' && !entryDoorRevealed) {
      for (final cur in room.currents) {
        if (!cur.rect.contains(a.position)) continue;
        entryDoorRevealed = true;
        _discoverCloud(entryDoorDiscoveryId); // persist the reveal
        final doorCenter = room.doors.isNotEmpty
            ? room.doors.first.rect.center
            : a.position;
        _setHint('Lightning answers its own — the passage reveals');
        _spawnAlchemyBurst(
          cur.rect.center,
          producedElement: 'Lightning',
          unstable: true,
          particleCount: 34,
          intensity: 1.35,
        );
        _spawnAlchemyBurst(
          doorCenter,
          producedElement: 'Lightning',
          unstable: true,
          particleCount: 26,
          intensity: 1.15,
        );
        return true;
      }
    }
    // Conduit B no longer answers a hand at all — the storm strikes it, up a
    // staircase of rods, or nothing does (§6.11 REWORK). A Lightning creature
    // standing on it says so plainly.
    for (final c in room.conduits) {
      if (!c.struckByStorm) continue;
      if ((a.position - c.position).distance > 34) continue;
      _setBlockedHint('This pylon answers the storm, not a hand');
      return true;
    }
    // A carried Anvil: electrify the cloud directly, no wind needed.
    if (carriedCloudType == 'Anvil') {
      carriedCloudType = 'Thundercloud';
      _setHint('The arc sinks into the anvil-cloud — thunder wakes inside');
      _spawnAlchemyBurst(
        a.position,
        producedElement: 'Lightning',
        unstable: true,
      );
      spawnWispWave(
        element: 'Lightning',
        center: a.position,
        count: 2,
        unstable: true,
        announce: false, // "thunder wakes inside" stays on screen
      );
      return true;
    }
    return false;
  }

  /// Interact with an awake guardian nearby. Returns true if handled (consumed
  /// the action). Two paths: a Kin with enough Beauty CALMS it instantly; any
  /// other creature STRIKES it during the vulnerable lull (defeat over a few
  /// hits). Either way → Star 3.
  bool _tryGuardian(DungeonCreature a) {
    final g = currentRoom.guardian;
    if (g == null || !guardianAwake) return false;
    if ((a.position - _guardianPosition(g)).distance > 90) return false;
    // Standing under a mystic in mid-fall: nothing to strike or calm yet. Only
    // the ground beneath it is refused — the room's own verbs (ranking rods,
    // herding the cell) stay live everywhere else while it comes down.
    if (guardianArriving) {
      // Also a refusal: the ground under a falling mystic answers nothing yet.
      _setBlockedHint('It is still coming down — brace');
      return true;
    }
    final enc = g.encounter;
    final canCalm = enc?.canCalm ?? true;
    final canDefeat = enc?.canDefeat ?? true;
    if (!guardianVulnerable) {
      _setHint('The guardian rages — act during the lull');
      return true;
    }
    // Elegant path: a high-Beauty Kin calms it at once.
    if (canCalm &&
        a.ability == DungeonAbility.ancientStabilize &&
        charmOk(a.member.statBeauty)) {
      if (!hasStar(g.starIndex)) earnStar(g.starIndex);
      _guardianEnemy?.isDead = true;
      _setHint('The guardian is calmed');
      _spawnAlchemyBurst(
        _guardianPosition(g),
        producedElement: 'Light',
        reagentElements: [a.member.element],
      );
      return true;
    }
    // Defeat path: strike during the lull. The strike and the party's
    // projectiles drain the SAME pool (the combat body's hp) — a lull strike
    // just takes a big fixed chunk of it.
    if (!canDefeat) {
      _setHint('This guardian can only be calmed — more Beauty may be needed');
      return true;
    }
    // Pace the lull strikes (2 per lull window at 1.5s apart in a 3.0s lull)
    // so the rage/lull rhythm stays the fight instead of instant taps
    // deleting it. With kGuardianBaseStrikes = 6 a first mystic costs three
    // clean windows; the last one costs nine.
    if (_guardianStrikeCooldown > 0) {
      _setHint('The guardian reels — let the strike land');
      return true;
    }
    _guardianStrikeCooldown = 1.5;
    final e = _guardianEnemy;
    if (e != null && !e.isDead) {
      e.hp -= e.maxHp / guardianStrikesNeeded;
      e.hitFlash = 0.3;
      if (e.hp <= 0) e.isDead = true; // _updateCombat banks the star
    } else {
      // Fallback pool if the combat body never spawned — same strike count.
      guardianHp -= maxGuardianHp / guardianStrikesNeeded;
    }
    guardianHitFlash = 0.3;
    if (_guardianHpFraction <= 0 || guardianHp <= 0) {
      if (!hasStar(g.starIndex)) earnStar(g.starIndex);
      _guardianEnemy?.isDead = true;
      _setHint('The guardian is vanquished');
      _spawnAlchemyBurst(
        _guardianPosition(g),
        producedElement: g.encounter?.element ?? 'Air',
        reagentElements: [a.member.element],
        unstable: true,
      );
    } else {
      _setHint('You strike the guardian — its storm thins');
    }
    return true;
  }

  Offset _moveWithCollision(Offset from, Offset delta, DungeonRoom room) {
    var pos = Offset(from.dx + delta.dx, from.dy);
    if (_hitsWall(pos, room)) pos = Offset(from.dx, from.dy);
    var pos2 = Offset(pos.dx, pos.dy + delta.dy);
    if (_hitsWall(pos2, room)) pos2 = Offset(pos.dx, pos.dy);
    return _clampToBounds(pos2, room);
  }

  bool _hitsWallRect(Offset center, DungeonRoom room) {
    for (final w in room.walls) {
      if (center.dx > w.left - _radius &&
          center.dx < w.right + _radius &&
          center.dy > w.top - _radius &&
          center.dy < w.bottom + _radius) {
        return true;
      }
    }
    return false;
  }

  bool _hitsWall(Offset center, DungeonRoom room) {
    if (_hitsWallRect(center, room)) return true;
    // Tide ledges: solid stone until the water climbs high enough to swim
    // over them.
    if (_isTemple && _templeLedgeBlocks(center, room)) return true;
    // Fossil ribs (solid except settled in the chasm groove) + the marrow
    // chasm itself (impassable until bridged).
    if (_isBarrow && _barrowBlocksAt(center, room)) return true;
    // Powered barriers: solid while their node is UNPOWERED (the overload
    // maze — powered doors open, unpowered close).
    if (_isCircuit && _circuitBlocksAt(center, room)) return true;
    // Pistons: footing only where a piston is extended in the current phase.
    if (_isVapor && _steamBlocksAt(center, room)) return true;
    // Lava: a channel is not a floor — running metal blocks walkers AND
    // gliders until something is cast across it.
    if (_isFoundry && _foundryBlocksAt(center, room)) return true;
    // When walking, you can't leave solid ground (gaps / open sky block you).
    if (!flightActive && !_onSolidGround(center, room)) return true;
    return false;
  }

  /// Horn-dash movement: the ram is airborne, so it crosses gaps and open
  /// sky freely — only walls and the room bounds stop it. The caller settles
  /// any over-the-void landing afterwards (fall recovery to last footing).
  Offset _moveDashing(Offset from, Offset delta, DungeonRoom room) {
    var pos = Offset(from.dx + delta.dx, from.dy);
    if (_hitsWallRect(pos, room)) pos = Offset(from.dx, from.dy);
    var pos2 = Offset(pos.dx, pos.dy + delta.dy);
    if (_hitsWallRect(pos2, room)) pos2 = Offset(pos.dx, pos.dy);
    return _clampToBounds(pos2, room);
  }

  Offset _clampToBounds(Offset c, DungeonRoom room) {
    final b = room.bounds;
    return Offset(
      c.dx.clamp(b.left + _radius, b.right - _radius),
      c.dy.clamp(b.top + _radius, b.bottom - _radius),
    );
  }

  void _checkDoors(DungeonCreature a) {
    if (_doorCooldown > 0) return;
    // Doors the player is leaning on THIS frame; everything else forgets it
    // was refused, so walking away and coming back speaks again.
    final leaning = <String>{};
    for (final d in currentRoom.doors) {
      if (isDoorHidden(currentRoom, d)) continue;
      if (isDoorLocked(currentRoom, d)) {
        // Sealed: the door refuses passage and names its key — ONCE per
        // attempt (§5.6 BLOCKED is attempt-edged). The refusal text doubles
        // as the state signature: re-key the lock and it speaks again.
        if (d.rect.inflate(14).contains(a.position)) {
          final key = _doorBlockKey(currentRoom, d);
          leaning.add(key);
          _setBlockedHintOnce(key, _lockedDoorHint(currentRoom, d));
        }
        continue;
      }
      if (d.rect.contains(a.position)) {
        // Ice: the ride SCOURS the flue and the rimefall THAWS the shaft —
        // bookkeeping that has to happen on the transit itself.
        if (_isShaft) _onShaftTransit(currentRoom, d);
        // Mud: climbing a risen wallow HEAVES the fen back to its opening
        // state — bookkeeping that has to happen on the transit itself.
        if (_isBog) _onBogTransit(currentRoom, d);
        currentRoomId = d.targetRoomId;
        _spreadCreaturesAround(d.targetSpawn);
        _carryPursuersThroughDoor(d.targetSpawn);
        // Don't carry loom clouds out of the loom.
        carriedCloudId = null;
        carriedCloudType = null;
        _doorCooldown = 0.5;
        // A new room is a new subject: the previous room's line (and every
        // attempt edge that referred to its objects) is void, so the entry
        // objective is never swallowed by a refusal you already walked away
        // from.
        _clearHints();
        final hint = _roomObjectiveHint(currentRoomId);
        if (hint != null) _setObjectiveHint(hint);
        _maybeSpawnGuardianCombat(currentRoom);
        onChanged();
        return;
      }
    }
    _releaseBlockedExcept(_doorBlockPrefix, leaning);
  }

  static const String _doorBlockPrefix = 'door:';

  String _doorBlockKey(DungeonRoom room, DungeonDoor d) =>
      '$_doorBlockPrefix${room.id}>${d.targetRoomId}';

  /// Hidden doors don't exist yet — no render, no transition, no map mark.
  /// The layout declares them:
  ///  • [DungeonLayout.entranceRevealDoor] hides until the entry puzzle.
  ///  • Each star spec's `revealDoors` hide until that star is claimed
  ///    (e.g. Air's summit↔loom shortcut is a reward EXIT from the climb,
  ///    never a way to stroll to the top of it).
  bool isDoorHidden(DungeonRoom room, DungeonDoor door) {
    final entryRef = layout.entranceRevealDoor;
    if (entryRef != null &&
        entryRef.matches(room, door) &&
        !entryDoorRevealed) {
      return true;
    }
    for (var i = 0; i < layout.stars.length; i++) {
      if (hasStar(i)) continue;
      for (final ref in layout.stars[i].revealDoors) {
        if (ref.matches(room, door)) return true;
      }
    }
    // Poison: the oubliette exists only in the ward that was surrendered.
    if (_isVenom && _monasteryDoorHidden(room, door)) return true;
    if (_isShaft && _iceDoorHidden(room, door)) return true;
    if (_isBog && _bogDoorHidden(room, door)) return true;
    if (_isRuins && _ruinsDoorHidden(room, door)) return true;
    if (_isWake && _graveDoorHidden(room, door)) return true;
    if (_isCrypt && _cryptDoorHidden(room, door)) return true;
    if (_isVault && _vaultDoorHidden(room, door)) return true;
    if (_isArchive && _archiveDoorHidden(room, door)) return true;
    if (_isHeart && _heartDoorHidden(room, door)) return true;
    // The Steam vault shaft stays hidden until the burst-disc is blown.
    if (_isVapor &&
        !burstDiscBlown &&
        room.burstDisc != null &&
        door.targetRoomId == room.burstDisc!.targetRoomId) {
      return true;
    }
    return false;
  }

  /// Star-gated doors: the layout's finale wing stays sealed until both of
  /// the first two stars are banked, so the guardian reads as a true finale.
  /// Stars 1 and 2 remain freely interleavable. The Mirror Tide adds
  /// tide-gated passages (drowned or dry until the water stands right).
  bool isDoorLocked(DungeonRoom room, DungeonDoor door) {
    final ref = layout.finaleDoor;
    if (ref != null && ref.matches(room, door) && !guardianRiteUnlocked) {
      return true;
    }
    if (_guardianDoorSealed(door)) return true;
    if (_isVapor && _sealBlocked(room, door)) return true;
    if (_isFoundry && _foundryDoorLocked(room, door)) return true;
    if (_isVenom && _monasteryDoorLocked(room, door)) return true;
    if (_isShaft && _iceDoorBlocked(room, door)) return true;
    if (_isBog && _bogDoorBlocked(room, door)) return true;
    if (_isRuins && _ruinsDoorBlocked(room, door)) return true;
    if (_isKeep && _keepDoorBlocked(room, door)) return true;
    if (_isWake && _graveDoorBlocked(room, door)) return true;
    if (_isCrypt && _cryptDoorBlocked(room, door)) return true;
    if (_isVault && _vaultDoorBlocked(room, door)) return true;
    if (_isArchive && _archiveDoorBlocked(room, door)) return true;
    if (_isHeart && _heartDoorBlocked(room, door)) return true;
    return _isTemple && _tideDoorBlocked(room, door);
  }

  /// The mystic's chamber is SEALED until the planet's own rite has ROUSED it
  /// (conduits sung, bells tolled, moon-pools frozen, scale hung true, beam
  /// latched, crucible sunk). A boss is walked into on purpose: no wandering
  /// into a sleeping arena, and no fight that starts before its arrival can.
  /// Once its star is banked the chamber stays open for good — solved is
  /// solved — and raids skip this entirely (their guardian is already loose).
  bool _guardianDoorSealed(DungeonDoor door) {
    if (isRaid) return false;
    final g = layout.rooms[door.targetRoomId]?.guardian;
    if (g == null) return false;
    if (hasStar(g.starIndex)) return false;
    return !guardianAwake;
  }

  /// What a locked door says when touched. The finale hint is PROGRESS-AWARE:
  /// the full thematic line while both keys are missing, narrowing to name
  /// only the star still owed once the first of the pair is banked.
  String _lockedDoorHint(DungeonRoom room, DungeonDoor door) {
    if (_isTemple && _tideDoorBlocked(room, door)) {
      return _tideDoorHint(room, door);
    }
    if (_isVapor && _sealBlocked(room, door)) {
      return _sealDoorHint(room, door);
    }
    if (_isFoundry && _foundryDoorLocked(room, door)) {
      return _foundryDoorHint(room, door);
    }
    if (_isVenom && _monasteryDoorLocked(room, door)) {
      return _monasteryDoorHint(room, door);
    }
    if (_isShaft && _iceDoorBlocked(room, door)) {
      return _iceDoorHint(room, door);
    }
    if (_isBog && _bogDoorBlocked(room, door)) {
      return _bogDoorHint(room, door);
    }
    if (_isRuins && _ruinsDoorBlocked(room, door)) {
      return _ruinsDoorHint(room, door);
    }
    if (_isKeep && _keepDoorBlocked(room, door)) {
      return _keepDoorHint(room, door);
    }
    if (_isWake && _graveDoorBlocked(room, door)) {
      return _graveDoorHint(room, door);
    }
    if (_isCrypt && _cryptDoorBlocked(room, door)) {
      return _cryptDoorHint(room, door);
    }
    if (_isVault && _vaultDoorBlocked(room, door)) {
      return _vaultDoorHint(room, door);
    }
    if (_isArchive && _archiveDoorBlocked(room, door)) {
      return _archiveDoorHint(room, door);
    }
    if (_isHeart && _heartDoorBlocked(room, door)) {
      return _heartDoorHint(room, door);
    }
    if (_guardianDoorSealed(door)) {
      return layout.guardianSealedHint ??
          'The chamber is sealed — nothing in there wakes until this '
              'planet\'s rite is done';
    }
    final need0 = !hasStar(0);
    final need1 = !hasStar(1);
    if (need0 && need1) {
      return layout.finaleSealedHint ??
          'The door is sealed — it parts only for both the '
              '${layout.starName(0)} and ${layout.starName(1)}';
    }
    final remaining = need0 ? layout.starName(0) : layout.starName(1);
    return 'The seal holds — it wants only the $remaining now';
  }

  /// Wisps pursue the party through doors: re-place them in a loose ring
  /// around the arrival point (in the NEW room's coordinates) so they swoop
  /// back in rather than getting clamped against a wall in stale coordinates.
  /// The guardian never leaves its arena.
  void _carryPursuersThroughDoor(Offset arrival) {
    var k = 0;
    for (final e in combatEnemies) {
      if (e.isDead || identical(e, _guardianEnemy)) continue;
      final a = k * 1.7 + _combatRng.nextDouble() * 0.6;
      final r = 170.0 + _combatRng.nextDouble() * 70.0;
      e.position = _clampToBounds(
        arrival + Offset(cos(a), sin(a)) * r,
        currentRoom,
      );
      e.flightSteering?.velocity = Offset.zero;
      k++;
    }
  }

  /// One-line "what to do here" on room entry (null once that room's
  /// business is finished — no stale or pointless prompts).
  String? _roomObjectiveHint(String roomId) {
    final room = layout.rooms[roomId];
    if (room == null || _roomCleared(room)) return null;
    if (_isCathedral) return _cathedralObjectiveHint(room);
    if (_isTemple) return _templeObjectiveHint(room);
    if (_isBarrow) return _barrowObjectiveHint(room);
    if (_isCircuit) return _circuitObjectiveHint(room);
    if (_isVapor) return _steamObjectiveHint(room);
    if (_isFoundry) return _foundryObjectiveHint(room);
    if (_isVenom) return _monasteryObjectiveHint(room);
    if (_isShaft) return _shaftObjectiveHint(room);
    if (_isBog) return _bogObjectiveHint(room);
    if (_isRuins) return _ruinsObjectiveHint(room);
    if (_isKeep) return _keepObjectiveHint(room);
    if (_isWake) return _graveObjectiveHint(room);
    if (_isCrypt) return _cryptObjectiveHint(room);
    if (_isVault) return _vaultObjectiveHint(room);
    if (_isArchive) return _archiveObjectiveHint(room);
    if (_isHeart) return _heartObjectiveHint(room);
    // Air (§5.6): GOAL only. How a wind is woken, what it will scour, and how
    // the storm chooses its iron are all Mask-insight content.
    if (_isSpire) {
      final spire = _spireObjectiveHint(room);
      if (spire != null) return spire;
    }
    if (room.loomStarIndex != null) {
      return 'Sky Loom — each anchor whispers a riddle up close; '
          'match it with the echo it describes';
    }
    // Wonder trial chambers (until their echo is earned).
    if (_sealedWonderCloud(room) != null) {
      return switch (roomId) {
        // WHAT, never HOW (§5.6): what the eye will accept, and the
        // storm-charge braid, are Mask-insight content (_wonderInsight), not
        // room-entry copy.
        'spiral_cloud' => 'Gale Eye — a still eye, and the vents are shut',
        'ring_cloud' =>
          'The Conjunction — seal the orbit when the three reagents gather',
        'anvil_cloud' => 'Storm Forge — a shell nothing plain can mark',
        'feather_cloud' =>
          'The Moult — catch three falling plumes before they settle',
        'veil_cloud' => 'The Shroud — pin each fold while it breathes',
        _ => null,
      };
    }
    // Storm-path connective rooms keep a pointer while Star 3 is open.
    if (!hasStar(2)) {
      return switch (roomId) {
        'storm_rune_hall' =>
          'The rune hall murmurs — a Mask can read the storm\'s order ahead',
        // Goal only — which element wakes which conduit is the runes'
        // earned reading (_doReveal), never free room-entry copy.
        'twin_conduit' => 'The twin conduits sleep',
        'storm_altar' => 'The altar sleeps until its twin conduits sing',
        _ => null,
      };
    }
    return null;
  }

  void _checkHazards(DungeonCreature a, double dt) {
    for (final h in currentRoom.hazards) {
      if (h.contains(a.position)) {
        a.hp = max(0, a.hp - _hazardDps * dt); // _handleDowns resolves a KO
        return;
      }
    }
  }

  void _checkStars(DungeonCreature a) {
    for (final s in currentRoom.stars) {
      if (_earnedStars.contains(s.starIndex)) continue;
      if ((a.position - s.position).distance < 28) {
        earnStar(s.starIndex);
      }
    }
  }

  /// The vault cache discovery id for this planet ('cache:' rides the same
  /// persistence channel as the entry rune and the lost maxims).
  String get _vaultCacheId => 'cache:${layout.element.toLowerCase()}_vault';

  /// Every dungeon's treasure room holds the planet's bottled essence:
  /// reaching it once makes it FIZZLE into the air and grants 5 gold
  /// (granted screen-side, once ever — a persisted discovery never refires).
  void _checkVaultCache(DungeonCreature a) {
    final pos = currentRoom.vaultCache;
    if (pos == null) return;
    // Crystal: the essence rides in the WAITING FACET, so the mouth cell only
    // holds it while the facet is standing there (§5.5 vault trick).
    if (_isKeep && !_keepVaultLive) return;
    // Spirit: the hollow grave is a room the living world does not contain.
    if (_isWake && !_graveVaultLive) return;
    if (discoveredClouds.contains(_vaultCacheId)) return;
    // Reach matches the bigger beacon visual.
    if ((a.position - pos).distance > 52) return;
    _discoverCloud(_vaultCacheId); // the screen pays the gold
    _spawnFizzleBurst(pos, layout.element);
    _setHint(
      'The vault\'s essence fizzles into the air — an offering for its '
      'finder',
      3.2,
    );
  }

  /// A mystical fizzle: the element's motes drift UP and fade — no blast,
  /// just essence escaping into the air. Reuses the alchemy particle pool.
  void _spawnFizzleBurst(Offset center, String element) {
    final color = elementColor(element);
    for (var i = 0; i < 26; i++) {
      final spread = (_combatRng.nextDouble() - 0.5) * 56;
      _alchemyParticles.add(
        _AlchemyParticle(
          position: center + Offset(spread, _combatRng.nextDouble() * 14 - 4),
          velocity: Offset(
            (_combatRng.nextDouble() - 0.5) * 26,
            -55 - _combatRng.nextDouble() * 90,
          ),
          color: Color.lerp(color, Colors.white, 0.2 + i % 3 * 0.12)!,
          maxLife: 0.7 + _combatRng.nextDouble() * 0.9,
          size: 1.8 + _combatRng.nextDouble() * 2.6,
          arc: false,
        ),
      );
    }
    while (_alchemyParticles.length > 180) {
      _alchemyParticles.removeAt(0);
    }
  }

  /// World position of the most recently earned star (the player is always
  /// at/near it when it banks) — the screen uses it to launch the fly-up
  /// animation from where the star was actually won.
  Offset lastStarEarnPosition = Offset.zero;

  /// Map a world position to screen coordinates (GameWidget fills the screen,
  /// so screen space == viewport space).
  Offset worldToScreen(Offset world) {
    final cam = _cameraTopLeft(currentRoom, _cameraFocus);
    return world - cam;
  }

  /// Debug helper: wipe ALL banked progress for this dungeon — stars, cloud
  /// discoveries, the entry reveal — and restart the run from the entrance,
  /// as if entering the planet for the first time. (The screen clears the
  /// persisted copy; this clears the live run.)
  void debugResetDungeon() {
    starMask = 0;
    _earnedStars.clear();
    discoveredClouds.clear();
    _resetPuzzleState(); // re-derives entryDoorRevealed=false from cleared set
    _placeAtEntrance();
    _setHint('Dungeon progress reset (debug)');
    onChanged();
  }

  /// Bank a star instantly (idempotent). Slice-2 persistence handles the save.
  void earnStar(int starIndex) {
    if (starIndex < 0 || starIndex > 2) return;
    if (_earnedStars.contains(starIndex)) return;
    _earnedStars.add(starIndex);
    starMask |= (1 << starIndex);
    lastStarEarnPosition = active?.position ?? currentRoom.bounds.center;
    if (isRaid) {
      // A raid has no stars to bank — the guardian falling IS the win.
      // Rewards wait for the death sequence; see [_updateRaidDeath].
      _setHint('The raid is broken — the storm releases the planet', 4.2);
      _beginRaidDeath();
      onChanged();
      return;
    }
    _spawnAlchemyBurst(
      lastStarEarnPosition,
      producedElement: 'Light',
      reagentElements: [layout.element],
      particleCount: 26,
      intensity: 1.1,
    );
    onStarEarned(starIndex);
    // Star 3: the guardian relic drops on the spot — hovers, then expands
    // away into the player's keeping (End Run re-presents it formally).
    if (starIndex == 2) {
      final g = currentRoom.guardian;
      _relicFx = _RelicDropFx(
        roomId: currentRoomId,
        position: g != null ? g.position : lastStarEarnPosition,
      );
    }
    // Unlock announcements + door reveals come from the layout's star specs.
    final spec = starIndex < layout.stars.length
        ? layout.stars[starIndex]
        : null;
    if (spec != null) {
      if (spec.earnAnnouncement != null) {
        _setHint(spec.earnAnnouncement!, 4.2);
      }
      for (final ref in spec.revealDoors) {
        _queueDoorReveal(ref.roomId, ref.targetRoomId);
      }
    }
    // The finale wing opens when the SECOND of the first two stars lands —
    // either order.
    if (starIndex <= 1 && guardianRiteUnlocked && !hasStar(2)) {
      if (layout.riteAnnouncement != null) {
        _setHint(layout.riteAnnouncement!, 4.2);
      }
      final finale = layout.finaleDoor;
      if (finale != null) {
        _queueDoorReveal(finale.roomId, finale.targetRoomId);
      }
    }
    onChanged();
  }

  // ── Render ──────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final swR = Stopwatch()..start();
    super.render(canvas);
    final vp = Size(size.x, size.y);
    final room = currentRoom;
    // The shake moves the WORLD under a fixed sky — cheaper than shaking
    // everything, and it reads as the ground moving, which is the point.
    final cam = _cameraTopLeft(room, _cameraFocus) + _shakeOffset();

    // Screen-space atmosphere. Background = elemental shader, else gradient.
    if (_sky.ready) {
      _sky.paint(canvas, vp, _time, mood: _skyMood);
    } else if (_isCathedral) {
      _drawCathedralFallbackSky(canvas, vp); // warm gradient fallback
    } else if (_isTemple) {
      _drawTempleFallbackSky(canvas, vp); // deep-sea gradient fallback
    } else if (_isBarrow) {
      _drawBarrowFallbackSky(canvas, vp); // buried-strata gradient fallback
    } else {
      drawSky(canvas, vp); // gradient fallback
    }
    if (_isCathedral) {
      // Incense smoke instead of sky clouds; embers instead of wind streaks.
      drawDriftingClouds(
        canvas,
        vp,
        _time,
        primary: const Color(0xFF4A3A32),
        secondary: const Color(0xFF6E4A38),
        count: 6,
        maxAlpha: 0.11,
        puff: _fx.puff,
      );
      _drawEmberDrift(canvas, vp);
    } else if (_isTemple) {
      // Silt veils instead of sky clouds; rising bubbles instead of wind.
      drawDriftingClouds(
        canvas,
        vp,
        _time,
        primary: const Color(0xFF2A4A58),
        secondary: const Color(0xFF3A6070),
        count: 6,
        maxAlpha: 0.10,
        puff: _fx.puff,
      );
      _drawBubbleDrift(canvas, vp);
    } else if (_isBarrow) {
      // Dust veils instead of sky clouds; sifting grave-dust instead of wind.
      drawDriftingClouds(
        canvas,
        vp,
        _time,
        primary: const Color(0xFF4A3A28),
        secondary: const Color(0xFF5E4C34),
        count: 6,
        maxAlpha: 0.10,
        puff: _fx.puff,
      );
      _drawDustSift(canvas, vp);
    } else {
      drawDriftingClouds(
        canvas,
        vp,
        _time,
        puff: _fx.puff,
      ); // soft faction-style clouds
      _drawWindStreaks(canvas, vp); // the air itself, always moving
    }
    _ambient.ensure(vp);
    if (_fx.ready) {
      _ambient.render(canvas, _fx.mote!, _time);
    }

    canvas.save();
    canvas.translate(-cam.dx, -cam.dy);

    _renderIslandAndVoid(canvas, room);
    if (_isCathedral) _renderCathedral(canvas, room);
    if (_isTemple) _renderTemple(canvas, room);
    if (_isBarrow) _renderBarrow(canvas, room);
    if (_isCircuit) _renderCircuit(canvas, room);
    if (_isVapor) _renderSteam(canvas, room);
    if (_isFoundry) _renderFoundry(canvas, room);
    if (_isVenom) _renderMonastery(canvas, room);
    if (_isShaft) _renderShaft(canvas, room);
    if (_isBog) _renderBog(canvas, room);
    if (_isRuins) _renderRuins(canvas, room);
    if (_isKeep) _renderKeep(canvas, room);
    if (_isWake) _renderGrave(canvas, room);
    if (_isCrypt) _renderCrypt(canvas, room);
    if (_isVault) _renderVault(canvas, room);
    if (_isArchive) _renderArchive(canvas, room);
    if (_isHeart) _renderHeart(canvas, room);
    _renderRoomLandmarks(canvas, room);
    _renderCurrents(canvas, room);
    _renderAlchemyParticles(canvas);
    _abilityVfx.render(canvas);
    _renderHazards(canvas, room);
    _renderWalls(canvas, room);
    _renderDoors(canvas, room);
    // Zero-sum darkness: dead trunk wings dim under a cheap eased tint —
    // drawn over the room fabric but UNDER every living thing, so the party,
    // the wisps and the glows stay readable in the dark.
    if (_isCircuit) _renderCircuitDarkness(canvas, room);
    _renderDoorRevealFx(canvas);
    if (_isSpire) _renderSpireWinds(canvas, room);
    _renderClouds(canvas, room);
    _renderAnchors(canvas, room);
    _renderConduitsAndGuardian(canvas, room);
    _renderStars(canvas, room);
    _renderGlideTrail(canvas);
    _renderWingBeams(canvas);
    _renderKinBeams(canvas);
    _renderCombatProjectiles(canvas);
    _renderCombatEnemies(canvas);
    _renderRefusalPulse(canvas);
    _renderCreatures(canvas);
    _renderCarriedCloud(canvas);
    _renderRelicDrop(canvas);
    _renderVaultCacheGlow(canvas, room);
    _renderRaidDeath(canvas);
    // Numbers sit above everything they annotate.
    damageNumbers.render(canvas);

    canvas.restore();

    // Screen-space framing.
    if (_isTemple) _drawTideGauge(canvas, vp);
    if (_isVapor) _drawSteamPhaseHud(canvas, vp);
    drawVignette(canvas, vp);
    _probeAccum(_probeLastUpdateMs, swR.elapsedMicroseconds / 1000.0);
  }

  /// The guardian relic's victory ceremony: drops from the fallen guardian,
  /// hovers glinting, then expands and dissolves. Real relic art when the
  /// asset loaded; procedural star-glyph otherwise.
  void _renderRelicDrop(Canvas canvas) {
    final fx = _relicFx;
    if (fx == null || fx.roomId != currentRoomId) return;
    final t = fx.t;
    double rise, scale, alpha;
    if (t < 0.7) {
      // Drop: falls in from above, easing to a halt.
      final u = t / 0.7;
      final e = 1 - pow(1 - u, 3).toDouble();
      rise = -70 * (1 - e);
      scale = 0.75 + 0.25 * e;
      alpha = (u * 2).clamp(0.0, 1.0);
    } else if (t < 2.6) {
      // Hover: a gentle bob with a breathing glint.
      rise = sin((t - 0.7) * 2.6) * 6;
      scale = 1.0 + 0.04 * sin(t * 3.4);
      alpha = 1;
    } else {
      // Claim: expands away and dissolves.
      final u = ((t - 2.6) / 1.0).clamp(0.0, 1.0);
      rise = -34 * u;
      scale = 1.0 + 2.4 * Curves.easeIn.transform(u);
      alpha = 1 - u;
    }
    final c = fx.position + Offset(0, rise - 26);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        62 * scale,
        elementColor(layout.element).withValues(alpha: 0.30 * alpha),
      );
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        36 * scale,
        const Color(0xFFE4C16A).withValues(alpha: 0.38 * alpha),
      );
    }
    final img = _relicImage;
    if (img != null) {
      final sz = 58.0 * scale;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: c, width: sz, height: sz),
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)),
      );
    } else {
      _drawStarGlyph(
        canvas,
        c,
        16 * scale,
        const Color(0xFFE4C16A).withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }
    // Hovering glints orbiting the relic.
    if (t >= 0.7 && t < 2.6 && _fx.ready) {
      for (var i = 0; i < 3; i++) {
        final a = _time * 1.8 + i * 2.094;
        drawGlow(
          canvas,
          _fx.mote!,
          c + Offset(cos(a), sin(a) * 0.5) * 34,
          4,
          const Color(
            0xFFFFE9B0,
          ).withValues(alpha: 0.4 + 0.2 * sin(_time * 5 + i)),
        );
      }
    }
  }

  /// The unclaimed vault essence: a soft element-tinted shimmer breathing
  /// over the shrine, with three slow orbit-motes — gone for good once
  /// claimed. 4 glow blits per frame, vault rooms only.
  /// The bottled essence as a proper TREASURE BEACON: a light pillar you can
  /// read from across the room, a levitating white-hot essence orb, expanding
  /// ground rings and a bright mote orbit. All baked-glow blits + plain
  /// draws — no per-frame shader allocations.
  void _renderVaultCacheGlow(Canvas canvas, DungeonRoom room) {
    final pos = room.vaultCache;
    if (pos == null) return;
    if (_isKeep && !_keepVaultLive) return;
    if (_isWake && !_graveVaultLive) return;
    if (discoveredClouds.contains(_vaultCacheId)) return;
    final color = elementColor(layout.element);
    final bright = Color.lerp(color, Colors.white, 0.45)!;
    final pulse = 0.5 + 0.5 * sin(_time * 2.4);
    final bob = sin(_time * 1.6) * 5.0;
    final core = pos + Offset(0, -20 + bob);

    // Beacon pillar: stacked glow blits climbing and fading upward — the
    // "come collect me" call, visible from the room's far side.
    if (_fx.ready) {
      for (var i = 0; i < 5; i++) {
        drawGlow(
          canvas,
          _fx.glow!,
          pos + Offset(0, -26.0 - i * 34),
          30 - i * 3.5,
          color.withValues(alpha: (0.22 + 0.08 * pulse) * (1.0 - i / 5.5)),
        );
      }
    }

    // Expanding ground rings: the floor itself announces the shrine.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (var k = 0; k < 2; k++) {
      final ringT = ((_time * 0.7) + k * 0.5) % 1.0;
      ringPaint.color = bright.withValues(
        alpha: (1.0 - ringT) * (0.38 - 0.1 * k),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: pos + const Offset(0, 8),
          width: 30 + ringT * 66,
          height: 13 + ringT * 26,
        ),
        ringPaint,
      );
    }

    // The essence orb: big halo, hot core, white heart.
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        core,
        74,
        color.withValues(alpha: 0.30 + 0.14 * pulse),
      );
      drawGlow(
        canvas,
        _fx.glow!,
        core,
        40,
        bright.withValues(alpha: 0.45 + 0.15 * pulse),
      );
    }
    canvas.drawCircle(
      core,
      11.5 + pulse * 1.5,
      Paint()..color = bright.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      core,
      5.5,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // A slow four-point glint over the core.
    final glint = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.5 + 0.3 * pulse);
    final ga = _time * 0.6;
    for (var k = 0; k < 2; k++) {
      final a = ga + k * pi / 2;
      canvas.drawLine(
        core - Offset(cos(a), sin(a)) * (16 + 3 * pulse),
        core + Offset(cos(a), sin(a)) * (16 + 3 * pulse),
        glint,
      );
    }

    // Bright mote orbit — doubled and enlarged from the old whisper.
    for (var i = 0; i < 6; i++) {
      final a = _time * 1.3 + i * 1.047;
      final mote = pos + Offset(cos(a) * 30, sin(a) * 13 - 14);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          mote,
          6.5,
          Color.lerp(
            color,
            Colors.white,
            0.35,
          )!.withValues(alpha: 0.5 + 0.3 * sin(_time * 4 + i)),
        );
      }
    }

    // Wisps of essence rising off the orb — a taste of the fizzle to come.
    if (_fx.ready) {
      for (var i = 0; i < 3; i++) {
        final riseT = ((_time * 0.55) + i / 3) % 1.0;
        drawGlow(
          canvas,
          _fx.mote!,
          core + Offset(sin(_time * 2 + i * 2.1) * 9, -14 - riseT * 34),
          4.5,
          bright.withValues(alpha: (1.0 - riseT) * 0.5),
        );
      }
    }
  }

  /// Ambient wind: a handful of thin streaks sliding across the viewport on
  /// staggered loops — the Air planet's air, visible in every chamber.
  /// 3 stroked paths per frame; negligible cost.
  void _drawWindStreaks(Canvas canvas, Size vp) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final speed = 60.0 + i * 26;
      final span = vp.width + 260;
      final t = ((_time * speed + i * 467) % span) - 130;
      final y = vp.height * (0.18 + 0.27 * i) + sin(_time * 0.7 + i * 2.1) * 26;
      final len = 90.0 + i * 34;
      final bow = 10.0 + i * 4;
      final path = Path()
        ..moveTo(t, y)
        ..quadraticBezierTo(t + len * 0.5, y - bow, t + len, y + bow * 0.3);
      paint.color = const Color(
        0xFFBFD2E6,
      ).withValues(alpha: 0.05 + 0.02 * i + 0.02 * _skyMood);
      canvas.drawPath(path, paint);
    }
  }

  _AirRoomTheme _themeFor(DungeonRoom room) {
    switch (room.id) {
      case 'entry':
        return _AirRoomTheme.entry;
      case 'hub':
        return _AirRoomTheme.hub;
      case 'lower_spire':
        return _AirRoomTheme.ascent;
      case 'crosswind_hall':
        return _AirRoomTheme.crosswind;
      case 'cloud_platforms':
        return _AirRoomTheme.cloudPlatform;
      case 'spire_summit':
        return _AirRoomTheme.summit;
      case 'spiral_cloud':
      case 'ring_cloud':
      case 'anvil_cloud':
      case 'feather_cloud':
      case 'veil_cloud':
        return _AirRoomTheme.wonderCloud;
      case 'sky_loom':
        return _AirRoomTheme.loom;
      case 'relic_chamber':
        return _AirRoomTheme.relic;
      case 'storm_rune_hall':
      case 'twin_conduit':
      case 'storm_altar':
        return _AirRoomTheme.storm;
      case 'guardian_summit':
        return _AirRoomTheme.guardian;
    }
    return _AirRoomTheme.generic;
  }

  bool _isStormRoom(DungeonRoom room) =>
      _themeFor(room) == _AirRoomTheme.storm ||
      _themeFor(room) == _AirRoomTheme.guardian;

  /// Per-room sky mood: bright thin air at the summit, bruised storm-dark
  /// in the storm wing — and permanent dawn once the planet is pacified
  /// (all three stars).
  double get _skyMoodTarget {
    if (starsEarnedCount >= 3) return 0.95;
    if (_isCathedral) return _cathedralMoodTarget;
    if (_isTemple) return _templeMoodTarget;
    if (_isBarrow) return _barrowMoodTarget;
    if (_isCircuit) return _circuitMoodTarget;
    if (_isVapor) return _steamMoodTarget;
    if (_isFoundry) return _foundryMoodTarget;
    if (_isVenom) return _monasteryMoodTarget;
    if (_isShaft) return _shaftMoodTarget;
    if (_isBog) return _bogMoodTarget;
    if (_isRuins) return _ruinsMoodTarget;
    if (_isKeep) return _keepMoodTarget;
    if (_isWake) return _graveMoodTarget;
    if (_isCrypt) return _cryptMoodTarget;
    if (_isVault) return _vaultMoodTarget;
    if (_isArchive) return _archiveMoodTarget;
    if (_isHeart) return _heartMoodTarget;
    return switch (_themeFor(currentRoom)) {
      _AirRoomTheme.summit => 0.78,
      _AirRoomTheme.ascent ||
      _AirRoomTheme.crosswind ||
      _AirRoomTheme.cloudPlatform => 0.62,
      _AirRoomTheme.loom || _AirRoomTheme.relic => 0.56,
      _AirRoomTheme.storm => 0.3,
      _AirRoomTheme.guardian => 0.22,
      _ => 0.5,
    };
  }

  void _renderRoomLandmarks(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    switch (_themeFor(room)) {
      case _AirRoomTheme.entry:
        _drawEntryIgnitionPuzzle(canvas, room);
        _drawDistantSpireSilhouette(canvas, b);
        break;
      case _AirRoomTheme.hub:
        _drawHubProgressCompass(canvas, room);
        // Once the First Wind wakes, even the rune pillars ride it — a slow
        // perpetual orbit of the hub.
        _drawRunePillars(
          canvas,
          b.center,
          235,
          4,
          drift: _firstWindWoken ? _time * 0.05 : 0,
        );
        break;
      case _AirRoomTheme.ascent:
        _drawVerticalSpireGhost(canvas, b);
        _drawHangingChains(canvas, room.platforms);
        break;
      case _AirRoomTheme.crosswind:
        _drawBrokenBridgeLines(canvas, room.platforms);
        _drawWindBanners(canvas, b);
        break;
      case _AirRoomTheme.cloudPlatform:
        _drawMoonbeam(canvas, Offset(b.center.dx, 130), 120, 780);
        _drawAmbientStarAnchors(canvas, const [
          Offset(150, 350),
          Offset(575, 510),
          Offset(350, 710),
        ]);
        break;
      case _AirRoomTheme.summit:
        _drawWindSpireSummitEndpoint(canvas, room);
        break;
      case _AirRoomTheme.wonderCloud:
        _drawWonderRoomLandmark(canvas, room);
        break;
      case _AirRoomTheme.loom:
        _drawSkyLoomMechanism(canvas, b.center, 210, room);
        break;
      case _AirRoomTheme.relic:
        _drawRelicShrine(canvas, b.center);
        break;
      case _AirRoomTheme.storm:
        _drawStormFloor(canvas, b);
        if (room.id == 'storm_altar') {
          _drawStormAltar(canvas, b.center, active: guardianAwake);
        }
        if (room.id == 'storm_rune_hall') {
          _drawStormMural(canvas, room);
        }
        break;
      case _AirRoomTheme.guardian:
        _drawStormFloor(canvas, b);
        _drawCrownRuins(
          canvas,
          const Offset(410, 305),
          270,
          stormVariant: true,
        );
        break;
      case _AirRoomTheme.generic:
        break;
    }
  }

  void _drawRuneCircle(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(
      c,
      r * 0.58,
      p..color = color.withValues(alpha: color.a * 0.7),
    );
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6 + _time * 0.03;
      final p1 = c + Offset(cos(a), sin(a)) * r * 0.78;
      final p2 = c + Offset(cos(a), sin(a)) * r * 0.92;
      canvas.drawLine(p1, p2, p);
    }
  }

  void _drawRouteLine(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(
        (from.dx + to.dx) / 2,
        (from.dy + to.dy) / 2 - 34,
        to.dx,
        to.dy,
      );
    canvas.drawPath(path, p);
  }

  /// True once Air's lost maxim (First Wind) has been found — persisted with
  /// the discovery, so the hub stays alive forever after.
  bool get _firstWindWoken =>
      layout.element == 'Air' && discoveredClouds.contains(kAirFirstWindEggId);

  /// The First Wind made visible: three gust-heads endlessly circling the
  /// compass, each trailing a short arc streak — the hub's permanent proof
  /// the maxim was found. 3 arcs + 3 glow blits per frame.
  void _drawFirstWindRibbon(Canvas canvas, Offset c) {
    final streak = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = _time * 0.55 + i * pi * 2 / 3;
      final r = 206.0 + 6 * sin(_time * 1.3 + i * 2.1);
      const sweep = 0.6;
      streak.color = const Color(
        0xFF8FE6FF,
      ).withValues(alpha: 0.16 + 0.06 * sin(_time * 2.4 + i));
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a - sweep,
        sweep,
        false,
        streak,
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          c + Offset(cos(a), sin(a)) * r,
          5,
          const Color(0xFFBFD2E6).withValues(alpha: 0.5),
        );
      }
    }
  }

  void _drawHubProgressCompass(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    final windProgress = hasStar(0)
        ? 1.0
        : summitOpen
        ? 0.82
        : (wokenGales.length / max(1, totalGales)).clamp(0.0, 0.72).toDouble();
    // Only true cloud echoes count toward loom progress (synthetic discovery
    // ids — 'rune:' reveals and 'egg:' maxims — share the persistence
    // channel).
    final discoveredCloudCount = discoveredClouds
        .where((id) => !id.contains(':'))
        .length
        .clamp(0, 5);
    final loomAnchorCount = layout.rooms['sky_loom']?.anchors.length ?? 1;
    final loomProgress = hasStar(1)
        ? 1.0
        : max(
            discoveredCloudCount / 5 * 0.55,
            filledAnchors.length / max(1, loomAnchorCount) * 0.9,
          ).clamp(0.0, 0.92).toDouble();
    final stormProgress = hasStar(2)
        ? 1.0
        : guardianAwake
        ? 0.86
        : altarOpen
        ? 0.72
        : conduitEnergy.isNotEmpty
        ? 0.38
        : 0.0;

    _drawCelestialCompass(
      canvas,
      c,
      170,
      windProgress: windProgress,
      loomProgress: loomProgress,
      stormProgress: stormProgress,
      // First Wind found: the compass turns for good — the whole mechanism
      // breathes again, permanently (persisted with the maxim discovery).
      spin: _firstWindWoken ? _time * 0.18 : 0,
    );
    if (_firstWindWoken) _drawFirstWindRibbon(canvas, c);
    // Pacified planet: the compass projects a slow constellation — the
    // dungeon's quiet acknowledgement of a 3-star clear.
    if (starsEarnedCount >= 3) {
      _drawCelebrationConstellation(canvas, c);
    }

    for (final d in room.doors) {
      final target = d.targetRoomId;
      if (target == 'entry') {
        // Way-back marker, not a progress route — no travelling motes.
        _drawHubRouteLine(
          canvas,
          c,
          d.rect.center,
          const Color(0xFF74613A),
          0.18,
          motes: false,
        );
        continue;
      }

      if (target == 'lower_spire') {
        _drawHubRouteLine(
          canvas,
          c,
          d.rect.center,
          const Color(0xFF5BC8E8),
          windProgress,
        );
        continue;
      }

      if (target == 'spiral_cloud' || target == 'ring_cloud') {
        final branchClouds = layout.rooms[target]?.clouds ?? const [];
        final branchDiscovered = branchClouds.any(
          (cloud) => discoveredClouds.contains(cloud.id),
        );
        if (!branchDiscovered) continue;
        // Active marks while the discovered echo still needs carrying to the
        // loom; once placed (or the loom star is earned) the route settles
        // into a quiet "completed" line.
        final branchDone =
            hasStar(1) ||
            branchClouds.every(
              (cloud) =>
                  placedClouds.contains(cloud.id) ||
                  filledAnchors.values.contains(cloud.cloudType),
            );
        _drawHubRouteLine(
          canvas,
          c,
          d.rect.center,
          const Color(0xFFB9C7D6),
          branchDone ? 0.4 : 0.7,
          motes: !branchDone,
        );
        continue;
      }

      if (target == 'sky_loom') {
        // Mere cloud discoveries only brighten this route quietly; the
        // travelling progress motes start once the loom itself is engaged
        // (an echo placed) — otherwise discovering a branch cloud sprays
        // animated marks toward BOTH that branch and the loom at once.
        final loomEngaged = filledAnchors.isNotEmpty || hasStar(1);
        _drawHubRouteLine(
          canvas,
          c,
          d.rect.center,
          const Color(0xFFE4C16A),
          loomProgress,
          motes: loomEngaged,
        );
        if (stormProgress > 0) {
          _drawHubRouteMotes(
            canvas,
            c,
            d.rect.center,
            const Color(0xFFFFFF8A),
            stormProgress,
            electric: true,
          );
          _drawHubDoorElectricAccent(canvas, d.rect.center, stormProgress);
        }
      }
    }
  }

  void _drawEntryIgnitionPuzzle(Canvas canvas, DungeonRoom room) {
    final gust = room.currents.isNotEmpty
        ? room.currents.first.rect.center
        : const Offset(360, 310);
    final door = room.doors.isNotEmpty
        ? room.doors.first.rect.center
        : const Offset(708, 275);
    // IGNITE ramp (shared _entryReveal): the rune-ring brightens, the stream
    // accelerates and electrifies, and the door-veil dissolves — all eased,
    // instead of snapping from dark to lit.
    final ignite = _entryReveal.clamp(0.0, 1.0);
    final cyan = const Color(0xFF5BC8E8);
    final gold = const Color(0xFFE4C16A);
    final lightning = const Color(0xFFFFFF8A);
    final pulse = 0.55 + 0.45 * sin(_time * (2.0 + 3.5 * ignite)).abs();
    final ringColor = Color.lerp(cyan, lightning, ignite)!;

    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        gust,
        82 + 50 * ignite,
        ringColor.withValues(alpha: 0.10 + 0.14 * ignite),
      );
    }

    _drawWindRing(
      canvas,
      gust,
      56,
      ringColor.withValues(alpha: 0.34 + (0.48 + 0.16 * pulse) * ignite),
      active: ignite > 0.3,
    );
    _drawRuneCircle(
      canvas,
      gust,
      86,
      Color.lerp(cyan, gold, ignite)!.withValues(alpha: 0.14 + 0.24 * ignite),
    );

    final streamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2 + 0.8 * ignite
      ..color = ringColor.withValues(alpha: 0.12 + 0.40 * ignite);
    final path = Path()
      ..moveTo(gust.dx + 62, gust.dy)
      ..cubicTo(
        gust.dx + 150,
        gust.dy - 52,
        door.dx - 130,
        door.dy + 44,
        door.dx - 12,
        door.dy,
      );
    canvas.drawPath(path, streamPaint);

    for (var i = 0; i < 10; i++) {
      final t = ((_time * (0.28 + 0.47 * ignite) + i / 10) % 1.0).toDouble();
      final a = Offset.lerp(gust + const Offset(62, 0), door, t)!;
      final wobble = Offset(
        sin(_time * 4 + i) * (5 + 4 * ignite),
        cos(_time * 3 + i * 1.4) * (3 + 3 * ignite),
      );
      canvas.drawCircle(
        a + wobble,
        1.6 + 0.8 * ignite,
        Paint()
          ..color = Color.lerp(
            ringColor,
            Colors.white,
            0.30 + 0.25 * ignite,
          )!.withValues(alpha: 0.22 + 0.36 * ignite),
      );
    }

    final veil = Rect.fromCenter(center: door, width: 76, height: 124);
    // The sealing veil dissolves as it ignites…
    if (ignite < 1.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(veil, const Radius.circular(20)),
        Paint()
          ..color = const Color(
            0xFF0B111D,
          ).withValues(alpha: 0.86 * (1 - ignite)),
      );
      for (var i = 0; i < 5; i++) {
        final x = door.dx - 25 + i * 12.5;
        final p = Path()
          ..moveTo(x, door.dy - 46)
          ..cubicTo(
            x + sin(_time + i) * 7,
            door.dy - 18,
            x - 4,
            door.dy + 14,
            x + sin(_time * 0.7 + i) * 7,
            door.dy + 48,
          );
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round
            ..color = cyan.withValues(alpha: 0.16 * (1 - ignite)),
        );
      }
    }
    // …and the charged threshold glow fades in behind it.
    if (ignite > 0.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(veil, const Radius.circular(18)),
        Paint()..color = cyan.withValues(alpha: (0.11 + 0.05 * pulse) * ignite),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(veil, const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = lightning.withValues(alpha: (0.68 + 0.20 * pulse) * ignite),
      );
    }
  }

  void _drawHubRouteLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Color baseColor,
    double progress, {
    bool electric = false,
    bool motes = true,
  }) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(
        (from.dx + to.dx) / 2,
        (from.dy + to.dy) / 2 - 34,
        to.dx,
        to.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF74613A).withValues(alpha: 0.16),
    );
    if (p > 0.02) {
      // Quiet routes (e.g. loom hinted by discoveries only) glow statically;
      // the pulse + travelling motes mean "active progress here".
      final pulse = motes ? 0.72 + 0.28 * sin(_time * (electric ? 9 : 4)) : 0.6;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = electric ? 2.0 : 1.55
          ..strokeCap = StrokeCap.round
          ..color = baseColor.withValues(alpha: (0.18 + 0.58 * p) * pulse),
      );
      if (motes) {
        _drawHubRouteMotes(canvas, from, to, baseColor, p, electric: electric);
      }
    }

    final doorColor = p >= 1
        ? const Color(0xFFE4C16A)
        : Color.lerp(const Color(0xFF74613A), baseColor, p)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: to, width: 58, height: 18),
        const Radius.circular(9),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = p > 0.45 ? 1.7 : 1.0
        ..color = doorColor.withValues(alpha: 0.30 + 0.55 * p),
    );
  }

  void _drawHubRouteMotes(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    double progress, {
    required bool electric,
  }) {
    final count = (2 + progress * 5).round();
    final control = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 34);
    for (var i = 0; i < count; i++) {
      final t = ((_time * (electric ? 0.85 : 0.45) + i / count) % 1.0)
          .clamp(0.0, 1.0)
          .toDouble();
      final a = Offset.lerp(from, control, t)!;
      final b = Offset.lerp(control, to, t)!;
      final pos = Offset.lerp(a, b, t)!;
      if (electric) {
        final jitter = Offset(
          sin(_time * 12 + i) * 5,
          cos(_time * 10 + i * 1.7) * 4,
        );
        canvas.drawLine(
          pos - jitter * 0.55,
          pos + jitter,
          Paint()
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.62 * progress),
        );
      }
      canvas.drawCircle(
        pos,
        electric ? 2.3 : 2.0,
        Paint()
          ..color = Color.lerp(
            color,
            Colors.white,
            electric ? 0.55 : 0.24,
          )!.withValues(alpha: 0.42 + 0.42 * progress),
      );
    }
  }

  void _drawHubDoorElectricAccent(
    Canvas canvas,
    Offset center,
    double progress,
  ) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0.02) return;
    final pulse = 0.55 + 0.45 * sin(_time * 9).abs();
    final color = const Color(0xFFFFFF8A);
    final rect = Rect.fromCenter(center: center, width: 70, height: 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + p * 0.8
        ..color = color.withValues(alpha: (0.22 + p * 0.38) * pulse),
    );

    final sparkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.36 * p * pulse);
    for (var i = 0; i < 3; i++) {
      final phase = _time * 7 + i * 2.1;
      final side = i.isEven ? -1.0 : 1.0;
      final start = center + Offset(side * (26 + sin(phase) * 4), -8 + i * 7);
      canvas.drawLine(
        start,
        start + Offset(side * 8, 3 + cos(phase) * 3),
        sparkPaint,
      );
      canvas.drawLine(
        start + Offset(side * 8, 3 + cos(phase) * 3),
        start + Offset(side * 3, 9 + sin(phase * 0.7) * 2),
        sparkPaint,
      );
    }
  }

  void _drawDistantSpireSilhouette(Canvas canvas, Rect b) {
    final c = Offset(b.right - 120, b.top + 155);
    final p = Paint()..color = const Color(0xFF070B13).withValues(alpha: 0.38);
    final path = Path()
      ..moveTo(c.dx, c.dy - 120)
      ..lineTo(c.dx + 38, c.dy + 90)
      ..lineTo(c.dx - 42, c.dy + 90)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawCircle(
      c + const Offset(0, -32),
      42,
      Paint()..color = const Color(0xFF5BC8E8).withValues(alpha: 0.035),
    );
  }

  /// Seven stars wheel slowly around the compass, joined by faint threads —
  /// drawn only after all three stars are banked.
  void _drawCelebrationConstellation(Canvas canvas, Offset c) {
    final pts = <Offset>[];
    for (var i = 0; i < 7; i++) {
      final a = _time * 0.12 + i * pi * 2 / 7;
      final r = 120.0 + 46 * sin(i * 1.7 + _time * 0.2);
      pts.add(c + Offset(cos(a), sin(a)) * r);
    }
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFE4C16A).withValues(alpha: 0.22);
    for (var i = 0; i < pts.length; i++) {
      canvas.drawLine(pts[i], pts[(i + 2) % pts.length], thread);
    }
    for (var i = 0; i < pts.length; i++) {
      final tw = 0.55 + 0.45 * sin(_time * 2.2 + i * 1.3);
      _drawStarGlyph(
        canvas,
        pts[i],
        4.5 + 1.5 * tw,
        Color.lerp(
          const Color(0xFFE4C16A),
          Colors.white,
          0.4,
        )!.withValues(alpha: 0.5 + 0.4 * tw),
      );
    }
  }

  void _drawCelestialCompass(
    Canvas canvas,
    Offset c,
    double r, {
    double windProgress = 0,
    double loomProgress = 0,
    double stormProgress = 0,
    double spin = 0,
  }) {
    _drawRuneCircle(
      canvas,
      c,
      r,
      const Color(0xFFC4A35A).withValues(alpha: 0.25),
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5BC8E8).withValues(alpha: 0.32);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + spin;
      final p1 = c + Offset(cos(a), sin(a)) * r * 0.18;
      final p2 = c + Offset(cos(a), sin(a)) * r * (i.isEven ? 0.95 : 0.62);
      canvas.drawLine(p1, p2, p);
    }
    _drawStarGlyph(
      canvas,
      c,
      18,
      const Color(0xFFE4C16A).withValues(alpha: 0.65),
    );
    _drawCompassProgressArc(
      canvas,
      c,
      r * 0.62,
      windProgress,
      const Color(0xFF5BC8E8),
      -pi / 2,
    );
    _drawCompassProgressArc(
      canvas,
      c,
      r * 0.82,
      loomProgress,
      const Color(0xFFE4C16A),
      pi * 0.18,
    );
    _drawCompassProgressArc(
      canvas,
      c,
      r * 1.02,
      stormProgress,
      const Color(0xFFFFFF8A),
      pi * 0.72,
      electric: true,
    );
    final total = (windProgress + loomProgress + stormProgress) / 3;
    if (total > 0.02) {
      canvas.drawCircle(
        c,
        28 + 10 * total,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF5BC8E8),
            const Color(0xFFE4C16A),
            loomProgress.clamp(0.0, 1.0),
          )!.withValues(alpha: 0.08 + 0.16 * total),
      );
    }
  }

  void _drawCompassProgressArc(
    Canvas canvas,
    Offset c,
    double r,
    double progress,
    Color color,
    double start, {
    bool electric = false,
  }) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0.01) return;
    final pulse = 0.78 + 0.22 * sin(_time * (electric ? 9 : 3.6) + r * 0.02);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      start,
      pi * 2 * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = electric ? 2.2 : 1.8
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: (0.28 + 0.48 * p) * pulse),
    );
    if (p >= 1) {
      for (var i = 0; i < 8; i++) {
        final a = start + i * pi * 2 / 8 + _time * (electric ? 0.18 : 0.06);
        final pos = c + Offset(cos(a), sin(a)) * r;
        _drawStarGlyph(
          canvas,
          pos,
          electric ? 4.0 : 3.2,
          Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: 0.72),
        );
      }
    }
  }

  void _drawRunePillars(
    Canvas canvas,
    Offset c,
    double radius,
    int count, {
    double drift = 0,
  }) {
    for (var i = 0; i < count; i++) {
      final a = i * pi * 2 / count + pi / 4 + drift;
      final pos = c + Offset(cos(a), sin(a)) * radius;
      final rect = Rect.fromCenter(center: pos, width: 34, height: 64);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a + pi / 2);
      canvas.translate(-pos.dx, -pos.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = const Color(0xFF111723).withValues(alpha: 0.82),
      );
      canvas.drawLine(
        pos + const Offset(-9, 0),
        pos + const Offset(9, 0),
        Paint()
          ..strokeWidth = 1.4
          ..color = const Color(0xFF5BC8E8).withValues(alpha: 0.35),
      );
      canvas.restore();
    }
  }

  void _drawVerticalSpireGhost(Canvas canvas, Rect b) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFF8FE6FF).withValues(alpha: 0.09);
    for (var i = 0; i < 4; i++) {
      final x = b.center.dx + (i - 1.5) * 48 + sin(_time + i) * 8;
      canvas.drawLine(Offset(x, b.bottom - 70), Offset(x, b.top + 70), p);
    }
  }

  void _drawHangingChains(Canvas canvas, List<Rect> platforms) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.16);
    for (final pl in platforms.skip(1)) {
      canvas.drawLine(
        pl.topLeft + const Offset(22, 4),
        pl.topLeft + const Offset(-20, -76),
        p,
      );
      canvas.drawLine(
        pl.topRight + const Offset(-22, 4),
        pl.topRight + const Offset(24, -70),
        p,
      );
    }
  }

  void _drawBrokenBridgeLines(Canvas canvas, List<Rect> platforms) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF74613A).withValues(alpha: 0.28);
    for (var i = 0; i < platforms.length - 1; i++) {
      final a = platforms[i].centerRight;
      final b = platforms[i + 1].centerLeft;
      canvas.drawLine(a + const Offset(-12, -22), b + const Offset(12, -22), p);
      canvas.drawLine(a + const Offset(-12, 24), b + const Offset(12, 24), p);
    }
  }

  void _drawWindBanners(Canvas canvas, Rect b) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFBFD2E6).withValues(alpha: 0.18);
    for (var i = 0; i < 10; i++) {
      final x = b.left + 90 + i * 88;
      final y = b.top + 95 + (i.isEven ? 0 : 310);
      final path = Path()..moveTo(x, y);
      path.cubicTo(
        x + 28,
        y + sin(_time * 2 + i) * 18,
        x + 74,
        y - 16,
        x + 116,
        y + 6,
      );
      canvas.drawPath(path, p);
    }
  }

  void _drawMoonbeam(Canvas canvas, Offset top, double width, double height) {
    final path = Path()
      ..moveTo(top.dx - width * 0.35, top.dy)
      ..lineTo(top.dx + width * 0.35, top.dy)
      ..lineTo(top.dx + width, top.dy + height)
      ..lineTo(top.dx - width, top.dy + height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(top, top + Offset(0, height), [
          const Color(0xFFBFD2E6).withValues(alpha: 0.08),
          const Color(0x00BFD2E6),
        ]),
    );
  }

  void _drawAmbientStarAnchors(Canvas canvas, List<Offset> anchors) {
    for (final p in anchors) {
      _drawStarGlyph(
        canvas,
        p,
        7,
        const Color(0xFFBFD2E6).withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        p,
        18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFC4A35A).withValues(alpha: 0.22),
      );
    }
  }

  void _drawCrownRuins(
    Canvas canvas,
    Offset c,
    double r, {
    bool stormVariant = false,
  }) {
    final col = stormVariant
        ? const Color(0xFF090B12)
        : const Color(0xFF111723);
    for (var i = 0; i < 9; i++) {
      final a = -pi * 0.95 + i * pi * 1.9 / 8;
      final pos = c + Offset(cos(a), sin(a)) * r * (0.72 + 0.08 * (i % 3));
      final h = 48 + (i % 4) * 12.0;
      final rect = Rect.fromCenter(center: pos, width: 28, height: h);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a + pi / 2);
      canvas.translate(-pos.dx, -pos.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = col.withValues(alpha: stormVariant ? 0.88 : 0.78),
      );
      canvas.restore();
    }
  }

  void _drawStarPedestal(Canvas canvas, Offset c, {required bool active}) {
    final col = active ? const Color(0xFFE4C16A) : const Color(0xFF74613A);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        55,
        col.withValues(alpha: active ? 0.34 : 0.12),
      );
    }
    canvas.drawCircle(
      c,
      34,
      Paint()..color = const Color(0xFF111723).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      c,
      34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = col.withValues(alpha: active ? 0.78 : 0.35),
    );
    _drawStarGlyph(canvas, c, 15, col.withValues(alpha: active ? 0.95 : 0.38));
  }

  void _drawWindSpireSummitEndpoint(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final summit = room.summit;
    final claimed = hasStar(0);
    final ready = claimed || summitOpen;
    final center = summit?.rect.center ?? b.center;

    _drawCrownRuins(canvas, b.center, 230);

    final entry = Offset(b.center.dx, b.bottom - 48);
    final routeColor = claimed
        ? const Color(0xFFE4C16A)
        : ready
        ? const Color(0xFF5BC8E8)
        : const Color(0xFF74613A);
    final routeAlpha = claimed
        ? 0.74
        : ready
        ? 0.56
        : 0.18;
    _drawSpireEndpointRoute(
      canvas,
      entry,
      center,
      routeColor.withValues(alpha: routeAlpha),
      active: ready,
    );

    if (ready) {
      _drawMoonbeam(
        canvas,
        Offset(center.dx, b.top + 18),
        86,
        center.dy - b.top + 80,
      );
      for (var i = 0; i < 7; i++) {
        final a = _time * 0.75 + i * pi * 2 / 7;
        final r = 64 + sin(_time * 1.8 + i) * 6;
        final p = center + Offset(cos(a), sin(a)) * r;
        canvas.drawCircle(
          p,
          claimed ? 2.8 : 2.2,
          Paint()..color = routeColor.withValues(alpha: claimed ? 0.72 : 0.46),
        );
      }
    }

    _drawStarPedestal(canvas, center, active: ready);

    if (summit != null) {
      final rect = summit.rect.inflate(ready ? 10 : 0);
      final col = ready ? routeColor : const Color(0xFF3A352B);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ready ? 2.0 : 1.1
          ..color = col.withValues(alpha: ready ? 0.72 : 0.35),
      );
    }
  }

  void _drawSpireEndpointRoute(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color, {
    required bool active,
  }) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        from.dx - 80,
        from.dy - 95,
        to.dx - 92,
        to.dy + 70,
        to.dx,
        to.dy + 34,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2.2 : 1.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final mirror = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        from.dx + 80,
        from.dy - 95,
        to.dx + 92,
        to.dy + 70,
        to.dx,
        to.dy + 34,
      );
    canvas.drawPath(
      mirror,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2.2 : 1.2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: color.a * 0.86),
    );
    if (!active) return;
    for (var i = 0; i < 8; i++) {
      final t = ((_time * 0.55 + i / 8) % 1.0).toDouble();
      final base = Offset.lerp(from, to, t)!;
      final sway = Offset(
        sin(t * pi * 2 + _time * 2.4) * 24,
        -22 * sin(t * pi),
      );
      canvas.drawCircle(
        base + sway,
        2.0,
        Paint()
          ..color = Color.lerp(
            color,
            Colors.white,
            0.42,
          )!.withValues(alpha: 0.42 + 0.24 * sin(_time * 5 + i)),
      );
    }
  }

  void _drawWonderRoomLandmark(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    final type = room.clouds.isNotEmpty ? room.clouds.first.cloudType : '';
    if (_sealedWonderCloud(room) != null) {
      _drawWonderTrialOverlay(canvas, room);
    }
    switch (type) {
      case 'Spiral':
        // Galaxy arm: soft wide underlay + bright core + outward motes.
        final cyan = const Color(0xFF5BC8E8);
        final path = Path()..moveTo(c.dx, c.dy);
        for (var i = 1; i <= 70; i++) {
          final a = i * 0.28 + _time * 0.15;
          final r = i * 1.55;
          path.lineTo(c.dx + cos(a) * r, c.dy + sin(a) * r);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..color = cyan.withValues(alpha: 0.07),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = cyan.withValues(alpha: 0.25),
        );
        for (var i = 0; i < 5; i++) {
          final u = ((_time * 0.18 + i / 5) % 1.0) * 64 + 4;
          final a = u * 0.28 + _time * 0.15;
          canvas.drawCircle(
            c + Offset(cos(a), sin(a)) * (u * 1.55),
            2.0,
            Paint()
              ..color = Color.lerp(
                cyan,
                Colors.white,
                0.4,
              )!.withValues(alpha: 0.4),
          );
        }
        break;
      case 'Ring':
        _drawRuneCircle(
          canvas,
          c,
          135,
          const Color(0xFFC4A35A).withValues(alpha: 0.24),
        );
        break;
      case 'Anvil':
        _drawStormFloor(canvas, room.bounds);
        _drawAnvilLightningRods(canvas, c, 170, 4, dim: true);
        break;
      case 'Feather':
        _drawFeatherRune(
          canvas,
          c,
          170,
          color: const Color(0xFFBFD2E6).withValues(alpha: 0.34),
        );
        break;
      case 'Veil':
        _drawVeilCurtain(canvas, room.bounds);
        break;
    }
  }

  /// A moonlit quill: curved spine, a gradient-filled vane silhouette,
  /// swept barbs and downy curls at the base — drifting gently as it
  /// floats. ~20 small path ops, comparable to the old stick drawing.
  /// Trial progress pips drawn under the sealed echo.
  void _drawTrialPips(Canvas canvas, Offset at, int total, int done) {
    const pip = 6.0;
    const gap = 6.0;
    final width = total * pip + (total - 1) * gap;
    var x = at.dx - width / 2;
    for (var i = 0; i < total; i++) {
      final filled = i < done;
      canvas.drawCircle(
        Offset(x + pip / 2, at.dy),
        pip / 2,
        Paint()
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = filled
              ? const Color(0xFFE4C16A)
              : const Color(0xFF74613A).withValues(alpha: 0.7),
      );
      x += pip + gap;
    }
  }

  /// Live trial state for the sealed wonder chambers — every visit shows
  /// something moving, progressing, or waiting to be read.
  void _drawWonderTrialOverlay(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    final cl = room.clouds.first;
    final pipAnchor = cl.position + const Offset(0, 52);
    switch (room.id) {
      case 'spiral_cloud':
        // The Gale Eye draws itself in the Air file, beside the gust shrines
        // whose stonework its vents are cut from.
        _drawGaleEye(canvas, room);
        _drawTrialPips(
          canvas,
          pipAnchor,
          kSpiralJetsNeeded,
          spiralTorn ? 0 : spiralOpenJets.length.clamp(0, kSpiralJetsNeeded),
        );
        break;

      case 'ring_cloud':
        // The trio reagents circle the orbit; they brighten as they gather.
        final orbitR = 135.0;
        final aligned = ringMotesAligned;
        final gather =
            1.0 -
            (_angularGap(_ringMoteAngle(0), _ringMoteAngle(1)) +
                    _angularGap(_ringMoteAngle(1), _ringMoteAngle(2))) /
                (pi * 2);
        const elements = ['Air', 'Fire', 'Lightning'];
        for (var i = 0; i < 3; i++) {
          final a = _ringMoteAngle(i);
          final p = c + Offset(cos(a), sin(a)) * orbitR;
          final col = elementColor(elements[i]);
          if (_fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              14 + 16 * gather,
              col.withValues(alpha: 0.25 + 0.4 * gather),
            );
          }
          canvas.drawCircle(p, 5.5, Paint()..color = col);
          canvas.drawCircle(
            p,
            2.2,
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        }
        // Keeper socket at the centre — flares while the trio is gathered.
        canvas.drawCircle(
          c,
          16,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = aligned ? 2.4 : 1.2
            ..color =
                (aligned ? const Color(0xFFFFFFFF) : const Color(0xFFC4A35A))
                    .withValues(alpha: aligned ? 0.95 : 0.4),
        );
        if (aligned && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            c,
            54,
            Colors.white.withValues(alpha: 0.30),
          );
        }
        break;

      case 'anvil_cloud':
        // The storm shell over the sleeping anvil; cracks once struck.
        final shell = cl.position;
        final struck = _anvilShellStruck;
        final col = struck ? const Color(0xFFFFFF8A) : const Color(0xFF8FB3D6);
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: shell, radius: 44.0 + i * 7),
            pi + i * 0.2,
            pi - i * 0.4,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0 - i * 0.4
              ..color = col.withValues(alpha: (struck ? 0.7 : 0.45) - i * 0.1),
          );
        }
        if (struck) {
          _drawLightningArc(
            canvas,
            shell + const Offset(-20, -34),
            shell + const Offset(12, 6),
            const Color(0xFFFFF4B0),
          );
          final remaining = _anvilWave
              .where((e) => !e.isDead && e.hp > 0)
              .length;
          _drawTrialPips(
            canvas,
            pipAnchor,
            _anvilWave.length.clamp(1, 3),
            (_anvilWave.length - remaining).clamp(0, 3),
          );
        }
        break;

      case 'feather_cloud':
        for (final p in _feathers) {
          _drawFeatherRune(
            canvas,
            p,
            34,
            color: const Color(0xFFE8F2FA).withValues(alpha: 0.6),
          );
          if (_fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              20,
              const Color(0xFFBFD2E6).withValues(alpha: 0.22),
            );
          }
        }
        _drawTrialPips(
          canvas,
          pipAnchor,
          3,
          _wonderProgress['feather_cloud'] ?? 0,
        );
        break;

      case 'veil_cloud':
        final spots = veilSpots(room);
        final visible = veilVisibleSpotIndex;
        final flare = veilFlareTimer > 0;
        for (var i = 0; i < spots.length; i++) {
          if (_veilPinned.contains(i)) {
            _drawStarGlyph(
              canvas,
              spots[i],
              7,
              const Color(0xFFE4C16A).withValues(alpha: 0.85),
            );
            continue;
          }
          final showing = flare || visible == i;
          final ghost = revealTier >= 1; // Mask insight: faint markers
          if (!showing && !ghost) continue;
          final breath = ((_time % 2.5) / 1.6).clamp(0.0, 1.0);
          final alpha = showing ? (0.55 - 0.3 * breath) : 0.12;
          for (var ring = 0; ring < 2; ring++) {
            canvas.drawCircle(
              spots[i],
              12 + ring * 9 + (showing ? breath * 10 : 0),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2
                ..color = const Color(
                  0xFFBFD2E6,
                ).withValues(alpha: alpha - ring * 0.12),
            );
          }
        }
        _drawTrialPips(canvas, pipAnchor, spots.length, _veilPinned.length);
        break;
    }
  }

  void _drawFeatherRune(Canvas canvas, Offset c, double len, {Color? color}) {
    final col = color ?? const Color(0xFFBFD2E6).withValues(alpha: 0.30);
    final sway = sin(_time * 1.1 + c.dx * 0.01) * 0.05;
    canvas.save();
    canvas.translate(c.dx, c.dy + sin(_time * 0.9 + c.dy * 0.01) * 2.5);
    canvas.rotate(-0.62 + sway); // the plume lies on a gentle diagonal

    final half = len * 0.5;
    final maxW = len * 0.20;
    Offset spinePt(double t) =>
        Offset(-half + t * len, -sin(t * pi) * len * 0.06);
    double vaneW(double t) {
      final u = ((t - 0.18) / 0.82).clamp(0.0, 1.0);
      return maxW * pow(sin(u * pi), 0.65).toDouble() * (1.0 - u * 0.22);
    }

    // Vane silhouette (upper edge out to the tip, back along the lower).
    final vane = Path();
    const samples = 13;
    for (var i = 0; i <= samples; i++) {
      final t = 0.18 + (i / samples) * 0.82;
      final p = spinePt(t);
      final w = vaneW(t);
      final q = Offset(p.dx - w * 0.30, p.dy - w);
      if (i == 0) {
        vane.moveTo(q.dx, q.dy);
      } else {
        vane.lineTo(q.dx, q.dy);
      }
    }
    for (var i = samples; i >= 0; i--) {
      final t = 0.18 + (i / samples) * 0.82;
      final p = spinePt(t);
      final w = vaneW(t);
      vane.lineTo(p.dx - w * 0.16, p.dy + w * 0.70);
    }
    vane.close();
    canvas.drawPath(
      vane,
      Paint()
        ..shader = ui.Gradient.linear(Offset(-half, 0), Offset(half, 0), [
          col.withValues(alpha: (col.a * 0.50).clamp(0.0, 1.0)),
          col.withValues(alpha: (col.a * 0.16).clamp(0.0, 1.0)),
        ]),
    );
    canvas.drawPath(
      vane,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = col.withValues(alpha: (col.a * 0.85).clamp(0.0, 1.0)),
    );

    // Quill shaft — bright, extending below the vane to a bare point.
    final spine = Path()..moveTo(-half - len * 0.13, len * 0.035);
    for (var i = 0; i <= samples; i++) {
      final p = spinePt(i / samples);
      spine.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      spine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          col,
          Colors.white,
          0.35,
        )!.withValues(alpha: (col.a * 1.1).clamp(0.0, 1.0)),
    );

    // Swept barbs: curving toward the tip, never straight ticks.
    final barbPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = col.withValues(alpha: (col.a * 0.6).clamp(0.0, 1.0));
    for (var k = 0; k < 7; k++) {
      final t = 0.27 + k * 0.094;
      final p = spinePt(t);
      final w = vaneW(t);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(
            p.dx + w * 0.42,
            p.dy - w * 0.5,
            p.dx + len * 0.045 + w * 0.26,
            p.dy - w * 0.92,
          ),
        barbPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(
            p.dx + w * 0.30,
            p.dy + w * 0.36,
            p.dx + len * 0.04 + w * 0.18,
            p.dy + w * 0.62,
          ),
        barbPaint,
      );
    }

    // Downy curls where the vane meets the bare quill.
    for (var k = 0; k < 2; k++) {
      final p = spinePt(0.16 + k * 0.05);
      canvas.drawArc(
        Rect.fromCircle(center: p + Offset(-2, -3 - k * 3), radius: 4 + k * 2),
        pi * 0.2,
        pi * 0.9,
        false,
        barbPaint,
      );
    }
    canvas.restore();
  }

  /// Layered gossamer curtain: translucent swaying ribbon fills with fine
  /// inner strands — instead of bare wavy lines.
  void _drawVeilCurtain(Canvas canvas, Rect b) {
    final col = const Color(0xFFBFD2E6);
    final top = b.top + 105;
    final bottom = b.bottom - 80;
    // Three wide translucent ribbons.
    for (var i = 0; i < 3; i++) {
      final x = b.left + 150 + i * (b.width - 300) / 2;
      final w = 90.0 + i * 14;
      final sway1 = sin(_time * 0.7 + i * 1.9) * 26;
      final sway2 = sin(_time * 0.5 + i * 1.3 + 2) * 34;
      final ribbon = Path()
        ..moveTo(x - w / 2, top)
        ..quadraticBezierTo(x, top - 14, x + w / 2, top)
        ..cubicTo(
          x + w / 2 + sway1,
          top + (bottom - top) * 0.4,
          x + w / 3 + sway2,
          top + (bottom - top) * 0.75,
          x + w * 0.28 + sway2,
          bottom,
        )
        ..quadraticBezierTo(
          x + sway2 * 0.6,
          bottom + 10,
          x - w * 0.3 + sway2,
          bottom,
        )
        ..cubicTo(
          x - w / 3 + sway2,
          top + (bottom - top) * 0.7,
          x - w / 2 + sway1,
          top + (bottom - top) * 0.35,
          x - w / 2,
          top,
        )
        ..close();
      canvas.drawPath(
        ribbon,
        Paint()
          ..shader = ui.Gradient.linear(Offset(x, top), Offset(x, bottom), [
            col.withValues(alpha: 0.09),
            col.withValues(alpha: 0.025),
          ]),
      );
      canvas.drawPath(
        ribbon,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = col.withValues(alpha: 0.16),
      );
    }
    // Fine strands drifting between the ribbons.
    final strand = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = col.withValues(alpha: 0.12);
    for (var i = 0; i < 6; i++) {
      final x = b.left + 130 + i * (b.width - 260) / 5;
      final path = Path()..moveTo(x, top + 8);
      path.cubicTo(
        x + sin(_time + i) * 22,
        top + (bottom - top) * 0.38,
        x - 18,
        top + (bottom - top) * 0.7,
        x + sin(_time * 0.7 + i) * 30,
        bottom - 6,
      );
      canvas.drawPath(path, strand);
    }
  }

  void _drawSkyLoomMechanism(
    Canvas canvas,
    Offset c,
    double r,
    DungeonRoom room,
  ) {
    _drawRuneCircle(
      canvas,
      c,
      r,
      const Color(0xFFC4A35A).withValues(alpha: 0.20),
    );
    _drawRuneCircle(
      canvas,
      c,
      r * 0.58,
      const Color(0xFF5BC8E8).withValues(alpha: 0.19),
    );
    final corePulse =
        0.14 + 0.10 * filledAnchors.length / max(1, room.anchors.length);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        78,
        const Color(0xFF5BC8E8).withValues(alpha: corePulse),
      );
    }
    canvas.drawCircle(
      c,
      42,
      Paint()..color = const Color(0xFF111723).withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      c,
      42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFE4C16A).withValues(alpha: 0.42),
    );
    for (final an in room.anchors) {
      final filled = filledAnchors.containsKey(an.id);
      final col = filled
          ? const Color(0xFF5BC8E8).withValues(alpha: 0.55)
          : const Color(0xFF74613A).withValues(alpha: 0.18);
      _drawRouteLine(canvas, c, an.position, col);
    }
  }

  void _drawRelicShrine(Canvas canvas, Offset c) {
    _drawMoonbeam(canvas, c + const Offset(0, -210), 82, 360);
    canvas.drawCircle(
      c,
      42,
      Paint()..color = const Color(0xFF111723).withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      c,
      42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.45),
    );
    final relic = Path()
      ..moveTo(c.dx, c.dy - 32)
      ..lineTo(c.dx + 18, c.dy)
      ..lineTo(c.dx, c.dy + 32)
      ..lineTo(c.dx - 18, c.dy)
      ..close();
    canvas.drawPath(
      relic,
      Paint()..color = const Color(0xFFBFD2E6).withValues(alpha: 0.60),
    );
  }

  /// The rune hall's mural: a wall diagram of the twin-conduit sync. Partial
  /// for everyone (one pylon lit, the other a question); a Mask's reveal
  /// completes it — both pylons arcing to the altar IN UNISON.
  void _drawStormMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final c = Offset(b.center.dx, b.top + 140);
    const cyan = Color(0xFF5BC8E8);
    const gold = Color(0xFFC4A35A);
    final complete = revealTier >= 1;

    // Stone panel.
    final panel = Rect.fromCenter(center: c, width: 340, height: 150);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(12)),
      Paint()..color = const Color(0xFF0B0F18).withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = gold.withValues(alpha: 0.4),
    );

    final leftPylon = c + const Offset(-110, 28);
    final rightPylon = c + const Offset(110, 28);
    final altarGlyph = c + const Offset(0, -34);

    void pylonGlyph(Offset p, bool lit) {
      final path = Path()
        ..moveTo(p.dx - 12, p.dy + 14)
        ..lineTo(p.dx, p.dy - 16)
        ..lineTo(p.dx + 12, p.dy + 14)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = (lit ? cyan : gold).withValues(alpha: lit ? 0.8 : 0.35),
      );
    }

    canvas.drawCircle(
      altarGlyph,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = gold.withValues(alpha: 0.6),
    );

    if (complete) {
      // The lesson: both arcs pulse IN UNISON.
      final sync = 0.5 + 0.5 * sin(_time * 3.0);
      pylonGlyph(leftPylon, true);
      pylonGlyph(rightPylon, true);
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = cyan.withValues(alpha: 0.25 + 0.5 * sync);
      for (final p in [leftPylon, rightPylon]) {
        final mid = Offset(
          (p.dx + altarGlyph.dx) / 2 + sin(_time * 9) * 5,
          (p.dy + altarGlyph.dy) / 2 - 10,
        );
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - 14)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(altarGlyph.dx, altarGlyph.dy + 9),
          arcPaint,
        );
      }
      canvas.drawCircle(
        altarGlyph,
        11,
        Paint()..color = cyan.withValues(alpha: 0.15 + 0.25 * sync),
      );
    } else {
      // Partial: one pylon dimly remembered, the other unread.
      pylonGlyph(leftPylon, true);
      pylonGlyph(rightPylon, false);
      canvas.drawPath(
        Path()
          ..moveTo(leftPylon.dx, leftPylon.dy - 14)
          ..lineTo(
            (leftPylon.dx + altarGlyph.dx) / 2,
            (leftPylon.dy + altarGlyph.dy) / 2 - 10,
          )
          ..lineTo(altarGlyph.dx, altarGlyph.dy + 9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = cyan.withValues(alpha: 0.18),
      );
      _drawTinyLabel(canvas, rightPylon + const Offset(0, 24), '?');
    }
  }

  void _drawStormFloor(Canvas canvas, Rect b) {
    final scar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5BC8E8).withValues(alpha: 0.18);
    for (var i = 0; i < 9; i++) {
      final sx = b.left + 90 + (i * 97) % max(1, b.width.toInt() - 180);
      final sy = b.top + 100 + (i * 73) % max(1, b.height.toInt() - 190);
      final path = Path()
        ..moveTo(sx.toDouble(), sy.toDouble())
        ..lineTo(sx + 24, sy + 18)
        ..lineTo(sx + 8, sy + 42)
        ..lineTo(sx + 38, sy + 64);
      canvas.drawPath(path, scar);
    }
  }

  /// The Anvil cloud's decorative lightning-rod crown. NOT the Star-3 rod
  /// FIELD (`_drawStormRodField`, in the Air part file) — different mechanic,
  /// deliberately different grammar: these are a thin radiating crown, the
  /// real rods are notched iron that visibly ranks.
  void _drawAnvilLightningRods(
    Canvas canvas,
    Offset c,
    double r,
    int count, {
    bool dim = false,
  }) {
    final col = dim
        ? const Color(0xFF74613A).withValues(alpha: 0.35)
        : const Color(0xFF5BC8E8).withValues(alpha: 0.55);
    for (var i = 0; i < count; i++) {
      final a = i * pi * 2 / count + pi / 4;
      final p = c + Offset(cos(a), sin(a)) * r;
      final top = p + Offset(cos(a), sin(a)) * 28;
      canvas.drawLine(
        p,
        top,
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF111723),
      );
      canvas.drawCircle(top, 5, Paint()..color = col);
    }
  }

  void _drawStormAltar(Canvas canvas, Offset c, {required bool active}) {
    _drawAnvilLightningRods(canvas, c, 170, 8, dim: !active);
    final col = active ? const Color(0xFF5BC8E8) : const Color(0xFF74613A);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        active ? 88 : 48,
        col.withValues(alpha: active ? 0.36 : 0.12),
      );
    }
    canvas.drawCircle(
      c,
      66,
      Paint()..color = const Color(0xFF090B12).withValues(alpha: 0.94),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        c,
        34 + i * 16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = col.withValues(alpha: active ? 0.42 : 0.18),
      );
    }
  }

  void _renderCurrents(Canvas canvas, DungeonRoom room) {
    final mote = _fx.mote;
    for (final cur in room.currents) {
      if (room.id == 'entry') continue;
      final len = cur.dir.distance;
      final dir = len > 0 ? cur.dir / len : const Offset(0, -1);
      final strong = cur.requiredSpeed > 0;
      final tint = strong
          ? const Color(0xFF8FE6FF)
          : (cur.strength > 0
                ? const Color(0xFFE4C16A)
                : const Color(0xFF9FB3C8));

      // Soft channel wash.
      canvas.drawRect(
        cur.rect,
        Paint()..color = tint.withValues(alpha: strong ? 0.07 : 0.04),
      );

      if (mote == null) continue;
      final r = cur.rect;
      // Flowing motes: travel up the channel with a per-current crosswind lean.
      final speed = 40 + cur.strength * 0.7;
      final cycle = r.height;
      final count = (r.width * r.height / 14000).clamp(6, 26).toInt();
      for (var i = 0; i < count; i++) {
        final colX = r.left + ((i * 113) % r.width.toInt());
        final travel = (_time * speed + i * 37.0) % cycle;
        final y = r.bottom - travel;
        final x = colX + dir.dx * (cycle - travel) * 0.35;
        if (x < r.left || x > r.right) continue;
        final fade = (travel / cycle); // brighter as it rises
        final sz = (strong ? 7.0 : 5.0) + 2.0 * sin(_time * 3 + i);
        drawGlow(
          canvas,
          mote,
          Offset(x, y),
          sz,
          tint.withValues(alpha: (0.18 + 0.5 * fade).clamp(0.0, 0.8)),
        );
      }
    }
  }

  void _renderClouds(Canvas canvas, DungeonRoom room) {
    if (_roomCleared(room)) return; // loom solved — clouds gone
    for (final cl in room.clouds) {
      final branchClaimed = _branchWonderCloudClaimed(room, cl);
      if (placedClouds.contains(cl.id) || branchClaimed) {
        if (room.anchors.isEmpty) {
          _drawWonderCloudRemnant(
            canvas,
            cl.position,
            cl.cloudType,
            strong: branchClaimed,
          );
        }
        continue;
      }
      if (cl.id == carriedCloudId) continue;
      final discovered = discoveredClouds.contains(cl.id);
      final col = discovered
          ? const Color(0xFFB9C7D6)
          : const Color(0xFF5BC8E8);
      final alpha = discovered ? 0.85 : (0.2 + 0.12 * sin(_time * 2));
      _drawWonderCloud(
        canvas,
        cl.position,
        cl.cloudType,
        col.withValues(alpha: alpha),
        discovered: discovered,
      );
    }
  }

  bool _branchWonderCloudClaimed(DungeonRoom room, HiddenCloud cloud) {
    if (room.anchors.isNotEmpty || room.clouds.length != 1) return false;
    if (placedClouds.contains(cloud.id)) return true;
    if (filledAnchors.values.contains(cloud.cloudType)) return true;
    // The Sky Loom star means the branch echoes have already served their role,
    // even after a restart/re-entry where transient placement state is gone.
    return hasStar(1) &&
        const {
          'Spiral',
          'Ring',
          'Anvil',
          'Feather',
          'Veil',
        }.contains(cloud.cloudType);
  }

  void _renderAnchors(Canvas canvas, DungeonRoom room) {
    if (_roomCleared(room)) return; // loom solved — anchors gone
    for (final an in room.anchors) {
      final filled = filledAnchors.containsKey(an.id);
      final col = filled ? const Color(0xFF22C55E) : const Color(0xFFC4A35A);
      // Fixed celestial point the constellation aligns to (above the socket).
      _drawStarGlyph(
        canvas,
        an.position + const Offset(0, -30),
        6,
        const Color(0xFF9FB3D6).withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        an.position,
        16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = col.withValues(alpha: filled ? 0.9 : 0.55),
      );
      if (filled) {
        _drawWonderCloud(
          canvas,
          an.position,
          filledAnchors[an.id] ?? an.requiredCloudType,
          const Color(0xFFB9C7D6).withValues(alpha: 0.9),
          discovered: true,
          echo: true,
        );
      } else {
        // Hint label scales with the last reveal tier.
        final label = revealTier >= 1 ? an.requiredCloudType : '?';
        _drawTinyLabel(canvas, an.position + const Offset(0, 22), label);
        // The no-Mask strategy: up close, every anchor whispers its riddle
        // ("the endless orbit" → Ring). Mask reveal upgrades this to the
        // explicit type / ghost outline.
        final a = active;
        if (revealTier < 1 &&
            an.clue.isNotEmpty &&
            a != null &&
            (a.position - an.position).distance < 100) {
          _drawClueLabel(canvas, an.position + const Offset(0, 36), an.clue);
        }
        if (revealTier >= 2) {
          _drawWonderCloud(
            canvas,
            an.position,
            an.requiredCloudType,
            const Color(0xFFB9C7D6).withValues(alpha: 0.18),
            discovered: true,
            echo: true,
          );
        }
      }
    }
  }

  void _renderConduitsAndGuardian(Canvas canvas, DungeonRoom room) {
    if (_roomCleared(room)) return; // altar solved — conduits & guardian gone
    for (final c in room.conduits) {
      final live = altarOpen || (conduitEnergy[c.id] ?? 0) > 0;
      final col = live ? const Color(0xFF5BC8E8) : const Color(0xFF74613A);
      final pulse = live ? 0.6 + 0.4 * sin(_time * 10) : 1.0;
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c.position,
          live ? 34 : 22,
          col.withValues(alpha: (live ? 0.6 : 0.18) * pulse),
        );
      }
      _drawStormConduit(canvas, c.position, col, charged: live);
      // Drain timer: the hold's remaining window, readable at a glance.
      final energy = conduitEnergy[c.id] ?? 0;
      if (live && energy.isFinite && energy > 0) {
        final maxE = _conduitMaxEnergy[c.id] ?? energy;
        final frac = (energy / max(0.001, maxE)).clamp(0.0, 1.0).toDouble();
        canvas.drawArc(
          Rect.fromCircle(center: c.position, radius: 40),
          -pi / 2,
          pi * 2 * frac,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(
              const Color(0xFFC0392B),
              const Color(0xFF5BC8E8),
              frac,
            )!.withValues(alpha: 0.85),
        );
      } else if (live && !energy.isFinite) {
        // Synchronized: a steady full ring.
        canvas.drawCircle(
          c.position,
          40,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = const Color(0xFF5BC8E8).withValues(alpha: 0.6),
        );
      }
      _drawTinyLabel(canvas, c.position + const Offset(0, 30), c.id);
    }
    final g = room.guardian;
    if (g != null && guardianArriving) {
      _drawGuardianArrival(canvas, g);
      return;
    }
    if (g != null && (altarOpen || guardianAwake)) {
      final pos = _guardianPosition(g);
      final col = guardianVulnerable
          ? const Color(0xFFE4C16A)
          : const Color(0xFFC0392B);
      final pulse = 0.5 + 0.5 * sin(_time * (guardianVulnerable ? 3 : 8));
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          pos,
          56,
          col.withValues(alpha: 0.5 * pulse),
        );
      }
      // Guardian is procedural (cosmic-enemy wisp/phantom style). The combat
      // body drives position + hit flash so there is exactly one Roc.
      final enemyFlash = _guardianEnemy?.hitFlash ?? 0;
      final flash = max(guardianHitFlash, enemyFlash);
      final bodyCol = flash > 0
          ? Color.lerp(col, Colors.white, (flash / 0.3).clamp(0, 1))!
          : col;
      _renderGuardianBody(canvas, pos, 40, bodyCol, guardianVulnerable);
      // Swoop telegraph ring while the Roc rears back.
      final ge = _guardianEnemy;
      final gm = ge?.flightSteering;
      if (gm != null && gm.showTelegraphRing) {
        canvas.drawCircle(
          pos,
          52 + gm.windupTimer * 70,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = Colors.white.withValues(alpha: 0.6),
        );
      }

      // HP pips (one shared pool), shown once it's been hurt at all.
      final frac = _guardianHpFraction;
      if (frac < 1) {
        const pip = 6.0;
        const gap = 5.0;
        final filledPips = (frac * maxGuardianHp).ceil();
        final total = maxGuardianHp * pip + (maxGuardianHp - 1) * gap;
        var px = pos.dx - total / 2;
        final py = pos.dy - 60;
        for (var i = 0; i < maxGuardianHp; i++) {
          final filled = i < filledPips;
          canvas.drawCircle(
            Offset(px + pip / 2, py),
            pip / 2,
            Paint()
              ..color = filled
                  ? const Color(0xFFE4C16A)
                  : const Color(0xFF74613A).withValues(alpha: 0.5),
          );
          px += pip + gap;
        }
      }
    }
  }

  /// THE ARRIVAL. The mystic falls onto its own perch: a shadow tightens on
  /// the ground, a warning ring closes on the spot, and the body drops out of
  /// the dark above with an accelerating (eased-in) fall. The room shake is
  /// driven from the update side; this is only what the eye follows.
  void _drawGuardianArrival(Canvas canvas, GuardianNode g) {
    final t = (_guardianArrival / kGuardianArrivalSeconds).clamp(0.0, 1.0);
    final fall = t * t * t; // ease-in: slow lift, hard landing
    final pos = g.position;
    final col = const Color(0xFFC0392B);

    // Ground shadow: wide and faint at height, tight and black on landing.
    final shadowW = 96.0 - 46.0 * fall;
    canvas.drawOval(
      Rect.fromCenter(center: pos, width: shadowW, height: shadowW * 0.42),
      Paint()..color = Colors.black.withValues(alpha: 0.20 + 0.42 * fall),
    );
    // The spot it is going to land on, closing.
    canvas.drawCircle(
      pos,
      120 - 78 * fall,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = col.withValues(alpha: 0.30 + 0.45 * fall),
    );

    final from = pos - Offset(0, 460 * (1 - fall));
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        from,
        46 + 22 * fall,
        col.withValues(alpha: 0.30 + 0.35 * fall),
      );
    }
    _renderGuardianBody(canvas, from, 40, col, false);
  }

  void _drawStormConduit(
    Canvas canvas,
    Offset c,
    Color color, {
    required bool charged,
  }) {
    final body = Path()
      ..moveTo(c.dx - 24, c.dy + 22)
      ..lineTo(c.dx - 16, c.dy - 30)
      ..lineTo(c.dx, c.dy - 42)
      ..lineTo(c.dx + 16, c.dy - 30)
      ..lineTo(c.dx + 24, c.dy + 22)
      ..lineTo(c.dx + 13, c.dy + 32)
      ..lineTo(c.dx - 13, c.dy + 32)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          c + const Offset(0, -42),
          c + const Offset(0, 34),
          const [Color(0xFF222837), Color(0xFF090B12)],
        ),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: charged ? 0.85 : 0.38),
    );
    final channel = Rect.fromCenter(
      center: c + const Offset(0, -2),
      width: 8,
      height: 54,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(channel, const Radius.circular(6)),
      Paint()..color = color.withValues(alpha: charged ? 0.70 : 0.20),
    );
    for (var i = 0; i < 3; i++) {
      final y = c.dy - 22 + i * 19.0;
      canvas.drawLine(
        Offset(c.dx - 17, y),
        Offset(c.dx - 7, y + 6),
        Paint()
          ..strokeWidth = 1
          ..color = color.withValues(alpha: charged ? 0.65 : 0.25),
      );
      canvas.drawLine(
        Offset(c.dx + 17, y),
        Offset(c.dx + 7, y + 6),
        Paint()
          ..strokeWidth = 1
          ..color = color.withValues(alpha: charged ? 0.65 : 0.25),
      );
    }
    if (!charged) return;
    _drawLightningArc(
      canvas,
      c + const Offset(-28, -18),
      c + const Offset(30, 12),
      const Color(0xFFBFF5FF),
    );
  }

  /// The planet guardian. With an authored Mystic sheet it renders the REAL
  /// creature sprite — perched and breathing during the lull, airborne and
  /// bobbing during rage. Falls back to the procedural orb-with-wings.
  void _renderGuardianBody(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    bool vulnerable,
  ) {
    final t = _time;
    final ticker = _guardianTicker;
    if (ticker != null) {
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          r * 2.3,
          color.withValues(
            alpha: 0.30 * (0.6 + 0.4 * sin(t * (vulnerable ? 2.4 : 7))),
          ),
        );
      }
      if (vulnerable) {
        // Perched: grounded shadow + a gold lull halo (the strike window).
        canvas.drawOval(
          Rect.fromCenter(
            center: c + const Offset(0, 52),
            width: 96,
            height: 22,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.30),
        );
        canvas.drawCircle(
          c,
          66 + 5 * sin(t * 2.2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = const Color(0xFFE4C16A).withValues(alpha: 0.55),
        );
      }
      final facingRight =
          (active?.position.dx ?? c.dx) >= c.dx; // face the party
      final breathe = vulnerable ? 1.0 + 0.03 * sin(t * 2.2) : 1.0;
      final hover = vulnerable ? 10.0 : sin(t * 2.6) * 6.0;
      canvas.save();
      canvas.translate(c.dx, c.dy + hover);
      canvas.scale(
        (facingRight ? -1 : 1) * _guardianSpriteScale * breathe,
        _guardianSpriteScale * breathe,
      );
      ticker.getSprite().render(
        canvas,
        anchor: Anchor.center,
        overridePaint: Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();
      // Hit feedback: a white bloom (the sprite itself stays untinted).
      if (guardianHitFlash > 0 || (_guardianEnemy?.hitFlash ?? 0) > 0) {
        final f = max(guardianHitFlash, _guardianEnemy?.hitFlash ?? 0);
        canvas.drawCircle(
          c + Offset(0, hover),
          54,
          Paint()
            ..color = Colors.white.withValues(
              alpha: 0.35 * (f / 0.3).clamp(0.0, 1.0),
            ),
        );
      }
      return;
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        r * 2.2,
        color.withValues(
          alpha: 0.35 * (0.6 + 0.4 * sin(t * (vulnerable ? 3 : 8))),
        ),
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);

    // Writhing tendrils.
    final tp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.5);
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + t * 0.6;
      final len = r * (1.4 + 0.3 * sin(t * 2 + i));
      final path = Path()..moveTo(cos(a) * r * 0.5, sin(a) * r * 0.5);
      path.quadraticBezierTo(
        cos(a + 0.3 * sin(t + i)) * r,
        sin(a + 0.3 * sin(t + i)) * r,
        cos(a) * len,
        sin(a) * len,
      );
      canvas.drawPath(path, tp);
    }

    // Storm wings (Roc silhouette), gently flapping.
    final flap = 0.5 + 0.5 * sin(t * (vulnerable ? 2.5 : 5));
    final wingPaint = Paint()..color = color.withValues(alpha: 0.30);
    final wingEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.6);
    for (final side in [-1.0, 1.0]) {
      final lift = (0.5 - flap) * r * 0.7;
      final wing = Path()
        ..moveTo(side * r * 0.35, -r * 0.1)
        ..quadraticBezierTo(
          side * r * 1.9,
          -r * 0.9 - lift,
          side * r * 2.3,
          -r * 0.05 - lift,
        )
        ..quadraticBezierTo(side * r * 1.7, r * 0.5, side * r * 0.35, r * 0.3)
        ..close();
      canvas.drawPath(wing, wingPaint);
      canvas.drawPath(wing, wingEdge);
    }

    // Body orb.
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.2, -r * 0.2),
          r * 1.3,
          [
            Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: 0.95),
            color.withValues(alpha: 0.85),
            Color.lerp(color, Colors.black, 0.5)!.withValues(alpha: 0.85),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: 0.6),
    );

    // Glowing eyes.
    final eyePulse = 0.6 + 0.4 * sin(t * 8);
    final eyeSpread = r * 0.32;
    final eyeY = -r * 0.1;
    for (final ex in [-eyeSpread, eyeSpread]) {
      canvas.drawCircle(
        Offset(ex, eyeY),
        r * 0.22,
        Paint()..color = color.withValues(alpha: 0.4 * eyePulse),
      );
      canvas.drawCircle(
        Offset(ex, eyeY),
        r * 0.12,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * eyePulse),
      );
    }
    canvas.restore();
  }

  void _renderGlideTrail(Canvas canvas) {
    final mote = _fx.mote;
    if (mote == null || _glideTrail.length < 2) return;
    for (var i = 0; i < _glideTrail.length; i++) {
      final t = i / _glideTrail.length; // 0 oldest .. 1 newest
      drawGlow(
        canvas,
        mote,
        _glideTrail[i],
        6 + 8 * t,
        const Color(0xFF8FE6FF).withValues(alpha: 0.30 * t),
      );
    }
  }

  void _renderCarriedCloud(Canvas canvas) {
    final a = active;
    if (a == null || carriedCloudType == null) return;
    // Wind wake behind the carrier.
    final mote = _fx.mote;
    if (mote != null) {
      for (var i = 0; i < _carryTrail.length; i++) {
        final t = i / max(1, _carryTrail.length);
        drawGlow(
          canvas,
          mote,
          _carryTrail[i],
          4 + 6 * t,
          const Color(0xFFB9C7D6).withValues(alpha: 0.18 * t),
        );
      }
    }
    final sway = Offset(sin(_time * 2.1) * 5, sin(_time * 3.1) * 2.5);
    final pos = a.position + const Offset(0, -30) + sway;
    final col = carriedCloudType == 'Thundercloud'
        ? const Color(0xFF5BC8E8)
        : const Color(0xFFB9C7D6);
    _drawWonderCloud(
      canvas,
      pos,
      carriedCloudType!,
      col.withValues(alpha: 0.95),
      discovered: true,
    );
  }

  void _drawWonderCloud(
    Canvas canvas,
    Offset c,
    String type,
    Color color, {
    required bool discovered,
    bool echo = false,
  }) {
    final pulse = discovered ? 1.0 : 0.65 + 0.25 * sin(_time * 2.0);
    final col = color.withValues(alpha: (color.a * pulse).clamp(0.0, 1.0));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = echo ? 1.1 : 1.5
      ..strokeCap = StrokeCap.round
      ..color = col.withValues(alpha: (col.a * 0.9).clamp(0.0, 1.0));
    final fill = Paint()
      ..color = col.withValues(alpha: (col.a * 0.35).clamp(0.0, 1.0));

    if (_fx.ready) {
      final width = switch (type) {
        'Feather' => 74.0,
        'Veil' => 68.0,
        'Anvil' || 'Thundercloud' => 66.0,
        'Ring' => 56.0,
        _ => 50.0,
      };
      drawPuff(
        canvas,
        _fx.puff!,
        c,
        width,
        col.withValues(alpha: col.a * 0.58),
      );
    }

    switch (type) {
      case 'Spiral':
        // Smooth galaxy curl: a soft wide pass under a bright core stroke,
        // with motes flowing outward along the arm.
        final spiral = Path()..moveTo(c.dx, c.dy);
        for (var i = 1; i <= 34; i++) {
          final a = i * 0.34 + _time * 0.45;
          final r = i * 0.7;
          spiral.lineTo(c.dx + cos(a) * r, c.dy + sin(a) * r);
        }
        canvas.drawPath(
          spiral,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round
            ..color = col.withValues(alpha: (col.a * 0.22).clamp(0.0, 1.0)),
        );
        canvas.drawPath(spiral, stroke);
        canvas.drawCircle(
          c,
          3.2,
          Paint()
            ..color = Color.lerp(
              col,
              Colors.white,
              0.5,
            )!.withValues(alpha: (col.a * 0.9).clamp(0.0, 1.0)),
        );
        for (var i = 0; i < 3; i++) {
          final u = ((_time * 0.32 + i / 3) % 1.0) * 30 + 4;
          final a = u * 0.34 + _time * 0.45;
          canvas.drawCircle(
            c + Offset(cos(a), sin(a)) * (u * 0.7),
            1.8,
            Paint()
              ..color = Color.lerp(
                col,
                Colors.white,
                0.4,
              )!.withValues(alpha: (col.a * 0.7).clamp(0.0, 1.0)),
          );
        }
        break;
      case 'Ring':
        // A slowly turning halo: arc segments with a soft body, dark eye,
        // and orbiting motes trailing thin arcs.
        final rot = _time * 0.7;
        final rect18 = Rect.fromCircle(center: c, radius: 18);
        canvas.drawCircle(
          c,
          18,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = col.withValues(alpha: (col.a * 0.18).clamp(0.0, 1.0)),
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(rect18, rot + i * pi * 2 / 3, pi * 0.5, false, stroke);
        }
        canvas.drawCircle(
          c,
          9,
          Paint()..color = Colors.black.withValues(alpha: 0.16),
        );
        for (var i = 0; i < 5; i++) {
          final a = _time * 0.8 + i * pi * 2 / 5;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: 25),
            a - 0.5,
            0.42,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0
              ..color = col.withValues(alpha: (col.a * 0.35).clamp(0.0, 1.0)),
          );
          canvas.drawCircle(
            c + Offset(cos(a), sin(a)) * 25,
            2.2,
            Paint()
              ..color = Color.lerp(
                col,
                Colors.white,
                0.35,
              )!.withValues(alpha: col.a),
          );
        }
        break;
      case 'Anvil':
      case 'Thundercloud':
        // A proper cumulonimbus: puffy base lobes, a rising column, and the
        // sheared flat-topped anvil slab. Thunderclouds glow from within.
        final thunder = type == 'Thundercloud';
        final baseY = c.dy + 12;
        final puff = Paint()
          ..color = col.withValues(alpha: (col.a * 0.40).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(c.dx - 17, baseY), 11, puff);
        canvas.drawCircle(Offset(c.dx + 3, baseY + 2), 13, puff);
        canvas.drawCircle(Offset(c.dx + 20, baseY), 10, puff);
        final column = Path()
          ..moveTo(c.dx - 18, baseY)
          ..quadraticBezierTo(c.dx - 24, c.dy - 4, c.dx - 27, c.dy - 9)
          ..lineTo(c.dx + 33, c.dy - 9)
          ..quadraticBezierTo(c.dx + 20, c.dy - 1, c.dx + 17, baseY)
          ..close();
        canvas.drawPath(
          column,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(c.dx, c.dy - 17),
              Offset(c.dx, baseY),
              [
                col.withValues(alpha: (col.a * 0.55).clamp(0.0, 1.0)),
                col.withValues(alpha: (col.a * 0.18).clamp(0.0, 1.0)),
              ],
            ),
        );
        final slab = Path()
          ..moveTo(c.dx - 31, c.dy - 9)
          ..lineTo(c.dx + 38, c.dy - 9)
          ..lineTo(c.dx + 28, c.dy - 17)
          ..lineTo(c.dx - 23, c.dy - 17)
          ..close();
        canvas.drawPath(
          slab,
          Paint()
            ..color = Color.lerp(
              col,
              Colors.white,
              0.18,
            )!.withValues(alpha: (col.a * 0.6).clamp(0.0, 1.0)),
        );
        canvas.drawLine(
          Offset(c.dx - 31, c.dy - 9),
          Offset(c.dx + 38, c.dy - 9),
          stroke,
        );
        if (thunder) {
          final flicker = 0.5 + 0.5 * sin(_time * 9).abs();
          canvas.drawCircle(
            Offset(c.dx, c.dy + 2),
            10,
            Paint()
              ..color = const Color(
                0xFFFFF4B0,
              ).withValues(alpha: 0.18 * flicker),
          );
          _drawLightningArc(
            canvas,
            c + const Offset(-12, 8),
            c + const Offset(-4, 30),
            const Color(0xFFFFF4B0),
          );
          _drawLightningArc(
            canvas,
            c + const Offset(14, 10),
            c + const Offset(20, 28),
            const Color(0xFFFFF4B0),
          );
        }
        break;
      case 'Feather':
        _drawFeatherRune(canvas, c, 76, color: col);
        break;
      case 'Veil':
        // A miniature gossamer drape: one translucent ribbon + strands.
        final sway = sin(_time * 0.8 + c.dx * 0.02) * 7;
        final ribbon = Path()
          ..moveTo(c.dx - 22, c.dy - 26)
          ..quadraticBezierTo(c.dx, c.dy - 33, c.dx + 22, c.dy - 26)
          ..cubicTo(
            c.dx + 25 + sway,
            c.dy - 4,
            c.dx + 12 + sway,
            c.dy + 16,
            c.dx + 14 + sway,
            c.dy + 33,
          )
          ..quadraticBezierTo(
            c.dx + sway,
            c.dy + 38,
            c.dx - 12 + sway,
            c.dy + 33,
          )
          ..cubicTo(
            c.dx - 16 + sway,
            c.dy + 12,
            c.dx - 25,
            c.dy - 6,
            c.dx - 22,
            c.dy - 26,
          )
          ..close();
        canvas.drawPath(
          ribbon,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(c.dx, c.dy - 30),
              Offset(c.dx, c.dy + 36),
              [
                col.withValues(alpha: (col.a * 0.30).clamp(0.0, 1.0)),
                col.withValues(alpha: (col.a * 0.06).clamp(0.0, 1.0)),
              ],
            ),
        );
        canvas.drawPath(
          ribbon,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = col.withValues(alpha: (col.a * 0.55).clamp(0.0, 1.0)),
        );
        for (var i = 0; i < 3; i++) {
          final x = c.dx - 12 + i * 12.0;
          final path = Path()..moveTo(x, c.dy - 22);
          path.cubicTo(
            x + sin(_time + i) * 7,
            c.dy - 4,
            x - 5,
            c.dy + 12,
            x + sin(_time * 0.7 + i) * 9 + sway * 0.5,
            c.dy + 30,
          );
          canvas.drawPath(path, stroke);
        }
        break;
      default:
        canvas.drawCircle(c + const Offset(-8, 2), 8, fill);
        canvas.drawCircle(c + const Offset(8, 2), 8, fill);
        canvas.drawCircle(c + const Offset(0, -4), 10, fill);
    }
  }

  void _drawWonderCloudRemnant(
    Canvas canvas,
    Offset c,
    String type, {
    bool strong = false,
  }) {
    final pulse = 0.5 + 0.5 * sin(_time * 2.2).abs();
    final cyan = const Color(0xFF5BC8E8);
    final gold = const Color(0xFFE4C16A);
    final strength = strong ? 1.0 : 0.55;
    final remnantPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.8 : 1.2
      ..strokeCap = StrokeCap.round
      ..color = cyan.withValues(alpha: (0.18 + 0.16 * pulse) * strength);
    final motePaint = Paint()
      ..color = Color.lerp(
        cyan,
        Colors.white,
        0.35,
      )!.withValues(alpha: strong ? 0.62 : 0.35);

    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        strong ? 150 : 95,
        cyan.withValues(alpha: strong ? 0.14 : 0.08),
      );
    }

    canvas.drawCircle(
      c,
      strong ? 52 : 38,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strong ? 1.2 : 0.8
        ..color = gold.withValues(alpha: strong ? 0.20 : 0.10),
    );

    _drawWonderCloud(
      canvas,
      c,
      type,
      cyan.withValues(alpha: strong ? 0.34 : 0.18),
      discovered: true,
      echo: true,
    );

    switch (type) {
      case 'Ring':
        canvas.drawCircle(c, strong ? 44 : 31, remnantPaint..strokeWidth = 2.0);
        canvas.drawCircle(
          c,
          strong ? 20 : 12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strong ? 1.4 : 1
            ..color = gold.withValues(
              alpha: (strong ? 0.30 : 0.18) + 0.08 * pulse,
            ),
        );
        final moteCount = strong ? 10 : 7;
        for (var i = 0; i < moteCount; i++) {
          final a = -_time * 0.35 + i * pi * 2 / moteCount;
          canvas.drawCircle(
            c + Offset(cos(a), sin(a)) * (strong ? 60 : 39),
            strong ? 2.4 : 1.8,
            motePaint,
          );
        }
        break;
      case 'Spiral':
        final path = Path()..moveTo(c.dx, c.dy);
        for (var i = 0; i < 46; i++) {
          final a = i * 0.32 + _time * 0.12;
          final r = i * 0.95;
          path.lineTo(c.dx + cos(a) * r, c.dy + sin(a) * r);
        }
        canvas.drawPath(path, remnantPaint);
        break;
      case 'Anvil':
      case 'Thundercloud':
        canvas.drawLine(
          c + const Offset(-42, 18),
          c + const Offset(42, 18),
          remnantPaint..strokeWidth = 1.7,
        );
        for (var i = 0; i < 4; i++) {
          final x = c.dx - 27 + i * 18;
          canvas.drawLine(
            Offset(x, c.dy + 24),
            Offset(x + sin(_time * 3 + i) * 5, c.dy + 40),
            remnantPaint,
          );
        }
        break;
      case 'Feather':
        final path = Path()
          ..moveTo(c.dx - 35, c.dy + 22)
          ..quadraticBezierTo(c.dx + 4, c.dy - 26, c.dx + 44, c.dy - 12);
        canvas.drawPath(path, remnantPaint..strokeWidth = 1.6);
        break;
      case 'Veil':
        for (var i = 0; i < 5; i++) {
          final x = c.dx - 30 + i * 15.0;
          canvas.drawLine(
            Offset(x, c.dy - 26),
            Offset(x + sin(_time + i) * 6, c.dy + 32),
            remnantPaint,
          );
        }
        break;
    }
  }

  void _drawLightningArc(Canvas canvas, Offset a, Offset b, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.78);
    final mid = Offset(
      (a.dx + b.dx) / 2 + sin(_time * 12) * 9,
      (a.dy + b.dy) / 2 - 8,
    );
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(b.dx, b.dy);
    canvas.drawPath(path, p);
  }

  void _drawTinyLabel(Canvas canvas, Offset center, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFE8DFC8),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Rune-chip backing so labels read over busy geometry.
    final origin = center - Offset(tp.width / 2, 0);
    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        origin.dx - 5,
        origin.dy - 2.5,
        tp.width + 10,
        tp.height + 5,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      chip,
      Paint()..color = const Color(0xFF0B0F18).withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      chip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.45),
    );
    tp.paint(canvas, origin);
  }

  /// Muted italic riddle text under an anchor ("the endless orbit").
  void _drawClueLabel(Canvas canvas, Offset center, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: '“$text”',
        style: TextStyle(
          color: const Color(0xFFC4A35A).withValues(alpha: 0.85),
          fontSize: 8.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 150);
    final origin = center - Offset(tp.width / 2, 0);
    // Soft backing so the riddle reads over busy loom geometry.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          origin.dx - 5,
          origin.dy - 2,
          tp.width + 10,
          tp.height + 4,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF080808).withValues(alpha: 0.55),
    );
    tp.paint(canvas, origin);
  }

  /// Two detuned sines instead of random jitter: a shudder the eye can track,
  /// and it costs nothing per frame.
  Offset _shakeOffset() {
    if (_shake <= 0.01) return Offset.zero;
    return Offset(sin(_time * 51.0) * _shake, cos(_time * 43.0) * _shake * 0.7);
  }

  Offset _cameraTopLeft(DungeonRoom room, Offset focus) {
    final vw = size.x, vh = size.y;
    final b = room.bounds;
    double camX, camY;
    if (b.width <= vw) {
      camX = b.center.dx - vw / 2; // center small room
    } else {
      camX = (focus.dx - vw / 2).clamp(b.left, b.right - vw);
    }
    if (b.height <= vh) {
      camY = b.center.dy - vh / 2;
    } else {
      camY = (focus.dy - vh / 2).clamp(b.top, b.bottom - vh);
    }
    return Offset(camX, camY);
  }

  void _renderIslandAndVoid(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;

    // Open-sky rooms (platforms): floating ledges over the drifting sky.
    if (room.platforms.isNotEmpty) {
      for (final p in room.platforms) {
        _renderFloatingIsland(canvas, p, sigil: false);
      }
      return;
    }

    // Plain rooms: a translucent, soft-edged sky-island so the shader sky
    // shows through and around it (no boxy slab). The cathedral lays stone
    // flags instead of a floating island.
    if (room.gaps.isEmpty) {
      if (_isCathedral) {
        _renderCathedralFloor(canvas, room);
      } else if (_isTemple) {
        _renderTempleFloor(canvas, room);
      } else if (_isBarrow) {
        _renderBarrowFloor(canvas, room);
      } else if (_isCircuit) {
        _renderCircuitFloor(canvas, room);
      } else if (_isVapor) {
        _renderSteamFloor(canvas, room);
      } else {
        _renderPlainFloor(canvas, b, room.id == layout.entranceRoomId);
      }
      return;
    }

    // Spire-style rooms: open sky with solid island ledges between the gaps.
    final gaps = room.gaps.map((g) => g.rect).toList()
      ..sort((x, y) => x.top.compareTo(y.top));
    var cursor = b.top;
    final solids = <Rect>[];
    for (final g in gaps) {
      if (g.top > cursor) {
        solids.add(Rect.fromLTRB(b.left, cursor, b.right, g.top));
      }
      cursor = max(cursor, g.bottom);
    }
    if (cursor < b.bottom) {
      solids.add(Rect.fromLTRB(b.left, cursor, b.right, b.bottom));
    }

    // Floating ledges over the drifting sky.
    for (final s in solids) {
      _renderFloatingIsland(canvas, s, sigil: false);
    }
  }

  /// A whole-room sky-island for plain rooms (hub/loom/altar): heavily rounded,
  /// translucent so the elemental sky shows through, with cloud-feathered edges
  /// on all sides so it reads as land floating in air rather than a box.
  /// Corner radius of a plain stage.
  ///
  /// Was 70, which with the cloud feathering that used to surround it made
  /// every room read as a soft blue lozenge floating in fog. A dungeon is
  /// architecture; the stage should have a built edge.
  static const double _kStageRadius = 34;

  void _renderPlainFloor(Canvas canvas, Rect b, bool showSigil) {
    final rr = RRect.fromRectAndRadius(
      b.deflate(8),
      const Radius.circular(_kStageRadius),
    );
    // Tinted from this planet's own sky palette, so the stage belongs to the
    // world it is in. Alphas hold the FLOOR TRANSLUCENCY RULE (§8): the
    // shader is the room's mood and must keep showing through the stone.
    final tint = dungeonFloorTint(layout.element);
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          tint.top.withValues(alpha: 0.52),
          tint.bottom.withValues(alpha: 0.60),
        ]),
    );
    // The perimeter used to be feathered with sprite puffs on all four sides —
    // up to 44 blits a frame, in a fixed blue-grey that belonged to no planet,
    // and it read as cheesy fog around every room. Gone. What replaces it is
    // an EDGE: a darker lip inset from the rim, so the stage looks like a
    // raised platform someone built rather than a cloud someone drew.
    canvas.drawRRect(
      rr.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = tint.bottom.withValues(alpha: 0.55),
    );
    // Bright top rim catching the light from the sky above.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = tint.top.withValues(alpha: 0.55),
    );
    if (showSigil) _drawSigil(canvas, b); // hub only — declutter trial rooms
  }

  _IslandGeometry _cachedIslandGeometry(
    Rect rect, {
    required bool stormVariant,
  }) {
    final key =
        '${rect.left.toStringAsFixed(1)},${rect.top.toStringAsFixed(1)},'
        '${rect.width.toStringAsFixed(1)},${rect.height.toStringAsFixed(1)},'
        '${stormVariant ? 1 : 0}';
    return _islandCache.putIfAbsent(key, () {
      final seed =
          rect.left * 0.73 +
          rect.top * 1.37 +
          rect.width * 0.19 +
          rect.height * 0.31 +
          (stormVariant ? 91 : 17);
      double n(int i) {
        final v = sin(seed + i * 12.9898) * 43758.5453;
        return v - v.floorToDouble();
      }

      final radius = min(24.0, rect.height * 0.34);
      final top = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

      final underside = Path()
        ..moveTo(rect.left + radius * 0.4, rect.top + rect.height * 0.48)
        ..lineTo(rect.right - radius * 0.4, rect.top + rect.height * 0.48);
      final points = 9;
      for (var i = points; i >= 0; i--) {
        final u = i / points;
        final x = rect.left + rect.width * u;
        final jag = rect.bottom + 10 + n(i) * rect.height * 0.42;
        final taper = sin(u * pi) * rect.height * 0.34;
        underside.lineTo(x, jag + taper);
      }
      underside.close();

      final debris = <Offset>[];
      final debrisCount = (rect.width / 110).clamp(2, 7).toInt();
      for (var i = 0; i < debrisCount; i++) {
        final side = n(40 + i) > 0.5 ? 1.0 : -1.0;
        debris.add(
          Offset(
            rect.center.dx + side * (rect.width * (0.48 + n(50 + i) * 0.22)),
            rect.center.dy + (n(60 + i) - 0.25) * rect.height * 0.95,
          ),
        );
      }

      final runes = <Offset>[];
      final runeCount = (rect.width / 180).clamp(1, 4).toInt();
      for (var i = 0; i < runeCount; i++) {
        runes.add(
          Offset(
            rect.left + rect.width * (0.18 + 0.64 * n(80 + i)),
            rect.top + rect.height * (0.20 + 0.20 * n(90 + i)),
          ),
        );
      }

      return _IslandGeometry(
        top: top,
        underside: underside,
        debris: debris,
        runes: runes,
      );
    });
  }

  /// A solid floating island: cached procedural top/underside paths, readable
  /// flat walkable surface, jagged hanging stone, and sparse rune/debris detail.
  void _renderFloatingIsland(Canvas canvas, Rect rect, {required bool sigil}) {
    final stormVariant = _isStormRoom(currentRoom);
    final geom = _cachedIslandGeometry(rect, stormVariant: stormVariant);

    // Dark hanging underside, drawn first so the playable top remains crisp.
    canvas.drawPath(
      geom.underside.shift(const Offset(0, 5)),
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          Offset(rect.center.dx, rect.bottom + rect.height * 0.65),
          stormVariant
              ? const [Color(0xFF0A0B12), Color(0xFF030407)]
              : const [Color(0xFF111723), Color(0xFF05070D)],
        ),
    );

    // Opaque stone body.
    canvas.drawPath(
      geom.top,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          stormVariant
              ? const [Color(0xFF26303F), Color(0xFF151B27), Color(0xFF080A11)]
              : const [Color(0xFF35465A), Color(0xFF202B3A), Color(0xFF101722)],
          const [0.0, 0.4, 1.0],
        ),
    );
    // Lit top surface band.
    canvas.save();
    canvas.clipPath(geom.top);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.34),
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          Offset(rect.center.dx, rect.top + rect.height * 0.34),
          [
            (stormVariant ? const Color(0xFF5BC8E8) : const Color(0xFFBFD2E6))
                .withValues(alpha: stormVariant ? 0.16 : 0.22),
            const Color(0x00000000),
          ],
        ),
    );
    canvas.restore();
    // Crisp top rim highlight.
    canvas.drawPath(
      geom.top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color =
            (stormVariant ? const Color(0xFF5BC8E8) : const Color(0xFFBFD2E6))
                .withValues(alpha: stormVariant ? 0.42 : 0.35),
    );

    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color =
          (stormVariant ? const Color(0xFF5BC8E8) : const Color(0xFFC4A35A))
              .withValues(alpha: 0.24);
    for (final r in geom.runes) {
      canvas.drawLine(
        r + const Offset(-8, 0),
        r + const Offset(8, 0),
        runePaint,
      );
      canvas.drawLine(
        r + const Offset(0, -6),
        r + const Offset(0, 6),
        runePaint,
      );
    }

    final debrisPaint = Paint()
      ..color = const Color(
        0xFF0A0E16,
      ).withValues(alpha: stormVariant ? 0.85 : 0.68);
    for (var i = 0; i < geom.debris.length; i++) {
      final d = geom.debris[i];
      final wobble = Offset(0, sin(_time * 0.8 + i) * 2);
      canvas.drawCircle(d + wobble, 3 + (i % 3) * 1.5, debrisPaint);
    }

    // Thin mist clinging to the underside only (doesn't engulf the island).
    if (_fx.ready) {
      final n = (rect.width / 140).clamp(2, 6).toInt();
      for (var i = 0; i < n; i++) {
        final x = rect.left + (i + 0.5) / n * rect.width;
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, rect.bottom + 6),
          70,
          const Color(0xFF2A3850).withValues(alpha: stormVariant ? 0.28 : 0.4),
        );
      }
    }

    if (sigil) _drawSigil(canvas, rect);
  }

  void _drawSigil(Canvas canvas, Rect rect) {
    final sigilR = min(rect.width, rect.height) * 0.22;
    final pulse = 0.06 + 0.03 * sin(_time * 1.5);
    canvas.drawCircle(
      rect.center,
      sigilR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF8FB3D6).withValues(alpha: pulse),
    );
    canvas.drawCircle(
      rect.center,
      sigilR * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF8FB3D6).withValues(alpha: pulse * 0.7),
    );
  }

  void _renderWalls(Canvas canvas, DungeonRoom room) {
    for (final w in room.walls) {
      // Soft cast shadow under the rock.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          w.translate(0, 4).inflate(2),
          const Radius.circular(12),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      final rock = RRect.fromRectAndRadius(w, const Radius.circular(11));
      // Cool stone body.
      canvas.drawRRect(
        rock,
        Paint()
          ..shader = ui.Gradient.linear(
            w.topCenter,
            w.bottomCenter,
            const [Color(0xFF45566B), Color(0xFF2A3543), Color(0xFF1C2531)],
            const [0.0, 0.55, 1.0],
          ),
      );
      // Top highlight (lit from above).
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w.left, w.top, w.width, w.height * 0.42),
          const Radius.circular(11),
        ),
        Paint()..color = const Color(0xFF6E8197).withValues(alpha: 0.30),
      );
      // Faint cool rim.
      canvas.drawRRect(
        rock,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF9FB6CE).withValues(alpha: 0.25),
      );
    }
  }

  void _renderHazards(Canvas canvas, DungeonRoom room) {
    for (final h in room.hazards) {
      final pulse = 0.18 + 0.10 * sin(_time * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(h, const Radius.circular(6)),
        Paint()..color = const Color(0xFFC0392B).withValues(alpha: pulse),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(h, const Radius.circular(6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFC0392B).withValues(alpha: 0.6),
      );
    }
  }

  /// Wind-gates instead of plain teal rectangles: a soft passage glow, a
  /// gradient veil that fades into the room, rune posts flanking the
  /// opening, and motes drifting through to say "this way out".
  void _renderDoors(Canvas canvas, DungeonRoom room) {
    const cyan = Color(0xFF5BC8E8);
    const amber = Color(0xFFC4A35A);
    for (final d in room.doors) {
      if (isDoorHidden(room, d)) continue;
      final r = d.rect;
      // Sealed star-gated door: a dark slab. The FINALE door reads as a
      // barred ritual seal that SHOWS PROGRESS — one star gem per required
      // star (Star 1 + Star 2), lit gold when banked, dim when not — so the
      // player sees "1 of 2" at a glance. Tide / other locks keep a plain rune.
      if (isDoorLocked(room, d)) {
        final rrLocked = RRect.fromRectAndRadius(r, const Radius.circular(5));
        canvas.drawRRect(
          rrLocked,
          Paint()..color = const Color(0xFF0B0F18).withValues(alpha: 0.9),
        );
        canvas.drawRRect(
          rrLocked,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = amber.withValues(alpha: 0.55),
        );
        final horizontal = r.width >= r.height;
        final lockPulse = 0.5 + 0.25 * sin(_time * 1.8);
        final isFinale = layout.finaleDoor?.matches(room, d) ?? false;

        if (isFinale) {
          // Heavy stone bars across the passage.
          final barFill = Paint()
            ..color = const Color(0xFF2A2416).withValues(alpha: 0.95);
          final barEdge = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = amber.withValues(alpha: 0.4);
          for (final t in const [0.32, 0.68]) {
            final bar = horizontal
                ? Rect.fromLTWH(
                    r.left + 3,
                    r.top + r.height * t - 2.5,
                    r.width - 6,
                    5,
                  )
                : Rect.fromLTWH(
                    r.left + r.width * t - 2.5,
                    r.top + 3,
                    5,
                    r.height - 6,
                  );
            final rb = RRect.fromRectAndRadius(bar, const Radius.circular(2));
            canvas.drawRRect(rb, barFill);
            canvas.drawRRect(rb, barEdge);
          }
          // The TWO keys that open it, shown right on the door: one star gem
          // per required star, lit gold when banked. (Two stars unlock it.)
          const gap = 18.0;
          for (var i = 0; i < 2; i++) {
            final delta = i == 0 ? -gap : gap;
            final gp = horizontal
                ? r.center + Offset(delta, 0)
                : r.center + Offset(0, delta);
            final lit = hasStar(i);
            final col = lit ? const Color(0xFFE8C56A) : const Color(0xFF49391F);
            if (_fx.ready && lit) {
              drawGlow(
                canvas,
                _fx.glow!,
                gp,
                12,
                col.withValues(alpha: 0.5 + 0.15 * sin(_time * 2.4 + i)),
              );
            }
            _drawStarGlyph(
              canvas,
              gp,
              6.5,
              col.withValues(alpha: lit ? 0.98 : 0.55),
            );
          }
          // Central keyhole medallion.
          canvas.drawCircle(
            r.center,
            6.5,
            Paint()..color = const Color(0xFF0B0F18).withValues(alpha: 0.92),
          );
          canvas.drawCircle(
            r.center,
            6.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3
              ..color = amber.withValues(alpha: lockPulse),
          );
          canvas.drawCircle(
            r.center + const Offset(0, -1),
            1.6,
            Paint()..color = amber.withValues(alpha: lockPulse),
          );
          canvas.drawLine(
            r.center + const Offset(0, 0.5),
            r.center + const Offset(0, 3.5),
            Paint()
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round
              ..color = amber.withValues(alpha: lockPulse),
          );
        } else {
          // Tide / other simple lock: a single amber lock rune.
          canvas.drawCircle(
            r.center,
            7,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = amber.withValues(alpha: lockPulse),
          );
          canvas.drawLine(
            r.center + const Offset(0, -3),
            r.center + const Offset(0, 3),
            Paint()
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round
              ..color = amber.withValues(alpha: lockPulse),
          );
        }
        continue;
      }
      final horizontal = r.width >= r.height; // opening in a top/bottom edge
      final pulse = 0.7 + 0.3 * sin(_time * 2.2 + r.left * 0.013);

      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          r.center,
          max(r.width, r.height) * 0.85,
          cyan.withValues(alpha: 0.10 * pulse),
        );
      }

      // Gradient veil along the passage axis (brighter at the threshold).
      final rrect = RRect.fromRectAndRadius(r, const Radius.circular(5));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            horizontal ? r.topCenter : r.centerLeft,
            horizontal ? r.bottomCenter : r.centerRight,
            [
              cyan.withValues(alpha: 0.26 * pulse),
              cyan.withValues(alpha: 0.07),
            ],
          ),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = cyan.withValues(alpha: 0.55 + 0.2 * pulse),
      );

      // Rune posts flanking the opening.
      final ends = horizontal
          ? [
              r.centerLeft + const Offset(-5, 0),
              r.centerRight + const Offset(5, 0),
            ]
          : [
              r.topCenter + const Offset(0, -5),
              r.bottomCenter + const Offset(0, 5),
            ];
      for (final e in ends) {
        canvas.drawCircle(
          e,
          4.5,
          Paint()..color = const Color(0xFF111723).withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          e,
          4.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = amber.withValues(alpha: 0.6),
        );
        canvas.drawCircle(
          e,
          1.6,
          Paint()..color = cyan.withValues(alpha: 0.65 * pulse),
        );
      }

      // Motes drifting through the opening.
      for (var i = 0; i < 3; i++) {
        final t = ((_time * 0.45 + i / 3) % 1.0).toDouble();
        final along = horizontal
            ? Offset(r.left + r.width * t, r.center.dy)
            : Offset(r.center.dx, r.top + r.height * t);
        final wobble = sin(_time * 3 + i * 2.1) * 3.0;
        canvas.drawCircle(
          along + (horizontal ? Offset(0, wobble) : Offset(wobble, 0)),
          1.8,
          Paint()
            ..color = Color.lerp(
              cyan,
              Colors.white,
              0.4,
            )!.withValues(alpha: 0.55 * (1 - (t - 0.5).abs() * 2 * 0.6)),
        );
      }
    }
  }

  void _renderDoorRevealFx(Canvas canvas) {
    for (final fx in _doorRevealFx) {
      if (fx.roomId != currentRoomId || !fx.burstFired) continue;
      final p = (1 - fx.ttl / 2.2).clamp(0.0, 1.0).toDouble();
      final alpha = (1 - p) * 0.7;
      for (var ring = 0; ring < 2; ring++) {
        canvas.drawCircle(
          fx.position,
          14 + p * 70 + ring * 12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 - ring * 0.7
            ..color = const Color(
              0xFFE4C16A,
            ).withValues(alpha: alpha - ring * 0.2),
        );
      }
    }
  }

  void _renderStars(Canvas canvas, DungeonRoom room) {
    for (final s in room.stars) {
      if (_earnedStars.contains(s.starIndex)) continue;
      final pulse = 0.6 + 0.4 * sin(_time * 3 + s.starIndex);
      canvas.drawCircle(
        s.position,
        18,
        Paint()
          ..color = const Color(0xFFE4C16A).withValues(alpha: 0.18 * pulse),
      );
      _drawStarGlyph(canvas, s.position, 10, const Color(0xFFE4C16A));
    }
  }

  void _drawStarGlyph(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outer = -pi / 2 + i * (pi * 2 / 5);
      final inner = outer + pi / 5;
      final po = Offset(c.dx + cos(outer) * r, c.dy + sin(outer) * r);
      final pi2 = Offset(
        c.dx + cos(inner) * r * 0.45,
        c.dy + sin(inner) * r * 0.45,
      );
      if (i == 0) {
        path.moveTo(po.dx, po.dy);
      } else {
        path.lineTo(po.dx, po.dy);
      }
      path.lineTo(pi2.dx, pi2.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _renderAlchemyParticles(Canvas canvas) {
    for (final p in _alchemyParticles) {
      final fade = (1 - p.t).clamp(0.0, 1.0).toDouble();
      final alpha = fade * fade;
      if (p.arc) {
        final dir = p.velocity.distance > 0.01
            ? p.velocity / p.velocity.distance
            : const Offset(1, 0);
        final perp = Offset(-dir.dy, dir.dx);
        final kink =
            p.position - dir * p.size * 2.4 + perp * sin(_time * 18) * 5;
        canvas.drawLine(
          p.position - dir * p.size * 5.0,
          kink,
          Paint()
            ..color = p.color.withValues(alpha: 0.44 * alpha)
            ..strokeWidth = max(1.0, p.size * 0.42)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          kink,
          p.position + dir * p.size * 2.2,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.62 * alpha)
            ..strokeWidth = max(0.8, p.size * 0.28)
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawCircle(
          p.position,
          p.size * (0.9 + p.t * 0.8),
          Paint()..color = p.color.withValues(alpha: 0.42 * alpha),
        );
      }
      canvas.drawCircle(
        p.position,
        max(0.8, p.size * 0.38),
        Paint()
          ..color = Color.lerp(
            p.color,
            Colors.white,
            0.45,
          )!.withValues(alpha: 0.76 * alpha),
      );
    }
  }

  void _renderWingBeams(Canvas canvas) {
    for (final beam in _activeWingBeams) {
      if (beam.dead) continue;
      final descriptor = beam.descriptor;
      final color = elementColor(descriptor.element);
      final pulse = 0.78 + 0.22 * sin(_time * 7.0 + beam.life);
      final fade = beam.life < 0.35
          ? (beam.life / 0.35).clamp(0.0, 1.0).toDouble()
          : 1.0;

      if (beam.chargeTimer > 0) {
        final progress = descriptor.chargeTime <= 0
            ? 1.0
            : (1.0 - beam.chargeTimer / descriptor.chargeTime)
                  .clamp(0.0, 1.0)
                  .toDouble();
        final chargeRadius = 20 + 34 * progress;
        canvas.drawCircle(
          beam.origin,
          chargeRadius,
          Paint()..color = color.withValues(alpha: 0.18 * pulse),
        );
        canvas.drawCircle(
          beam.origin,
          chargeRadius * 0.48,
          Paint()
            ..color = Color.lerp(
              color,
              Colors.white,
              0.5,
            )!.withValues(alpha: 0.36 * pulse),
        );
        for (var i = 0; i < 5; i++) {
          final a = _time * 5.5 + i * pi * 2 / 5;
          canvas.drawLine(
            beam.origin + Offset(cos(a), sin(a)) * chargeRadius * 0.55,
            beam.origin + Offset(cos(a + 0.22), sin(a + 0.22)) * chargeRadius,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.45 * progress)
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round,
          );
        }
        continue;
      }

      if (descriptor.targetPolicy == WingBeamTargetPolicy.ring &&
          descriptor.radius > 0) {
        _renderWingBeamRing(canvas, beam, color, pulse * fade);
        continue;
      }

      final end = _wingBeamEnd(beam);
      final width = descriptor.width;
      canvas.drawLine(
        beam.origin,
        end,
        Paint()
          ..color = color.withValues(alpha: 0.18 * pulse * fade)
          ..strokeWidth = width * 3.0
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        beam.origin,
        end,
        Paint()
          ..color = color.withValues(alpha: 0.54 * pulse * fade)
          ..strokeWidth = width * 1.35
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        beam.origin,
        end,
        Paint()
          ..color = Color.lerp(
            color,
            Colors.white,
            0.72,
          )!.withValues(alpha: 0.86 * pulse * fade)
          ..strokeWidth = max(2.0, width * 0.38)
          ..strokeCap = StrokeCap.round,
      );

      final dir = end - beam.origin;
      final dist = dir.distance;
      if (dist > 0.01) {
        final unit = dir / dist;
        final perp = Offset(-unit.dy, unit.dx);
        for (var i = 0; i < 5; i++) {
          final t = ((_time * 1.8 + i * 0.19) % 1.0).toDouble();
          final p =
              beam.origin +
              unit * dist * t +
              perp * sin(t * pi * 4 + i) * width * 0.55;
          canvas.drawCircle(
            p,
            1.3 + width * 0.08,
            Paint()
              ..color = Color.lerp(
                color,
                Colors.white,
                0.45,
              )!.withValues(alpha: 0.58 * fade),
          );
        }
      }
    }
  }

  void _renderWingBeamRing(
    Canvas canvas,
    _DungeonWingBeam beam,
    Color color,
    double alphaScale,
  ) {
    final r = beam.descriptor.radius;
    canvas.drawCircle(
      beam.origin,
      r,
      Paint()..color = color.withValues(alpha: 0.055 * alphaScale),
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = beam.descriptor.width * 0.55
      ..color = color.withValues(alpha: 0.42 * alphaScale);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: beam.origin, radius: r * (0.78 + i * 0.1)),
        _time * (0.8 + i * 0.25) + i * pi * 2 / 3,
        pi * 0.72,
        false,
        ringPaint,
      );
    }
    final hot = Color.lerp(color, Colors.white, 0.62)!;
    for (var i = 0; i < 10; i++) {
      final a = _time * 1.3 + i * pi * 2 / 10;
      final p = beam.origin + Offset(cos(a), sin(a)) * r;
      canvas.drawCircle(
        p,
        2.0,
        Paint()..color = hot.withValues(alpha: 0.45 * alphaScale),
      );
    }
  }

  /// Kin charged-laser flashes: three-layer beam that fades fast.
  void _renderKinBeams(Canvas canvas) {
    for (final beam in _kinBeams) {
      final fade = (beam.life / 0.34).clamp(0.0, 1.0).toDouble();
      canvas.drawLine(
        beam.origin,
        beam.end,
        Paint()
          ..color = beam.color.withValues(alpha: 0.16 * fade)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        beam.origin,
        beam.end,
        Paint()
          ..color = beam.color.withValues(alpha: 0.5 * fade)
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        beam.origin,
        beam.end,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * fade)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _renderCombatProjectiles(Canvas canvas) {
    for (final p in combatProjectiles) {
      final color = elementColor(p.element ?? 'Air');
      if (_drawSurvivalProjectileVisual(canvas, p, color)) {
        continue;
      }
      _drawSurvivalFallbackProjectile(canvas, p, color);
    }
  }

  bool _drawSurvivalProjectileVisual(
    Canvas canvas,
    Projectile projectile,
    Color color,
  ) {
    final position = projectile.position;
    if (projectile.abilityFamily == 'kin' &&
        projectile.element == 'Spirit' &&
        projectile.followSourceCompanion) {
      final tier = projectile.effectCount.clamp(1, 4);
      final spirit = elementColor('Spirit');
      final white = Color.lerp(spirit, Colors.white, 0.55)!;
      final scale = 1.0 + 0.35 * (tier - 1);
      canvas.drawCircle(
        position,
        14.0 * scale,
        Paint()..color = spirit.withValues(alpha: 0.16 + 0.04 * tier),
      );
      canvas.drawCircle(
        position,
        8.5 * scale,
        Paint()..color = spirit.withValues(alpha: 0.30 + 0.06 * tier),
      );
      canvas.drawCircle(
        position,
        4.0 * scale,
        Paint()..color = white.withValues(alpha: 0.55 + 0.10 * tier),
      );
      canvas.drawCircle(
        position,
        1.4 + 0.4 * tier,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      for (var i = 0; i < tier - 1; i++) {
        final a = _time * 2.4 + i * (pi * 2 / max(1, tier - 1));
        final r = 9.0 * scale + 2.0;
        canvas.drawCircle(
          position + Offset(cos(a) * r, sin(a) * r),
          1.6,
          Paint()..color = white.withValues(alpha: 0.85),
        );
      }
      return true;
    }

    if (projectile.visualStyle == ProjectileVisualStyle.mysticOrbital) {
      if (projectile.stationary &&
          drawMaskElementalProjectileVisual(
            canvas: canvas,
            projectile: projectile,
            position: position,
            color: color,
            time: _time,
          )) {
        if (projectile.abilityFamily == 'mask' &&
            projectile.element == 'Plant') {
          _drawMaskPlantTendrils(canvas, projectile, color);
        }
        return true;
      }
      _drawSurvivalMysticOrbital(canvas, projectile, color);
      return true;
    }

    final drawn =
        drawMaskElementalProjectileVisual(
          canvas: canvas,
          projectile: projectile,
          position: position,
          color: color,
          time: _time,
        ) ||
        drawLetElementalProjectileVisual(
          canvas: canvas,
          projectile: projectile,
          position: position,
          color: color,
          time: _time,
        ) ||
        drawPipElementalProjectileVisual(
          canvas: canvas,
          projectile: projectile,
          position: position,
          color: color,
          time: _time,
        ) ||
        drawManeElementalProjectileVisual(
          canvas: canvas,
          projectile: projectile,
          position: position,
          color: color,
          time: _time,
        ) ||
        drawHornElementalProjectileVisual(
          canvas: canvas,
          projectile: projectile,
          position: position,
          color: color,
          time: _time,
        );
    if (drawn) {
      if (projectile.abilityFamily == 'mask' && projectile.element == 'Plant') {
        _drawMaskPlantTendrils(canvas, projectile, color);
      }
      drawProjectileRoleOverlay(
        canvas: canvas,
        projectile: projectile,
        position: position,
        color: color,
        time: _time,
      );
    }
    return drawn;
  }

  /// Mask+Plant traps grow writhing tendrils toward nearby enemies — the same
  /// authored overlay survival draws. Gathers in-reach enemies nearest-first
  /// and hands off to the shared renderer.
  void _drawMaskPlantTendrils(Canvas canvas, Projectile vine, Color color) {
    final reach = max(vine.snareRadius, vine.effectRadius);
    final reachSq = reach * reach;
    final targets = <Offset>[];
    if (reach > 10) {
      for (final e in combatEnemies) {
        if (e.isDead) continue;
        if ((e.position - vine.position).distanceSquared > reachSq) continue;
        targets.add(e.position);
      }
      if (targets.length > 1) {
        targets.sort(
          (a, b) => (a - vine.position).distanceSquared.compareTo(
            (b - vine.position).distanceSquared,
          ),
        );
      }
    }
    drawMaskPlantWormyTendrils(
      canvas: canvas,
      vine: vine,
      color: color,
      time: _time,
      targetsInReach: targets,
    );
  }

  void _drawSurvivalMysticOrbital(
    Canvas canvas,
    Projectile projectile,
    Color color,
  ) {
    final dir = Offset(cos(projectile.angle), sin(projectile.angle));
    final radius = (1.65 * projectile.visualScale).clamp(1.4, 6.1).toDouble();
    final pulse = 0.78 + 0.22 * sin(_time * 4.0 + projectile.life);

    canvas.drawCircle(
      projectile.position,
      radius * 2.6,
      Paint()..color = color.withValues(alpha: 0.18 * pulse),
    );
    for (var i = 1; i <= 3; i++) {
      final fade = 1.0 - i * 0.30;
      final back = projectile.position - dir * (radius * 2.0 * i);
      canvas.drawCircle(
        back,
        radius * (1.0 + i * 0.18) * 0.55,
        Paint()..color = color.withValues(alpha: 0.32 * fade),
      );
    }
    canvas.drawCircle(
      projectile.position,
      radius,
      Paint()..color = color.withValues(alpha: 0.92 * pulse),
    );
    canvas.drawCircle(
      projectile.position,
      radius * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.85 * pulse),
    );
    drawProjectileRoleOverlay(
      canvas: canvas,
      projectile: projectile,
      position: projectile.position,
      color: color,
      time: _time,
    );
  }

  void _drawSurvivalFallbackProjectile(
    Canvas canvas,
    Projectile projectile,
    Color color,
  ) {
    final position = projectile.position;
    final visualScale = projectile.visualScale;
    switch (projectile.visualStyle) {
      case ProjectileVisualStyle.meteor:
        final tailLen = 22.0 * visualScale;
        final tailStart =
            position -
            Offset(cos(projectile.angle), sin(projectile.angle)) * tailLen;
        canvas.drawLine(
          tailStart,
          position,
          Paint()
            ..shader = ui.Gradient.linear(
              tailStart,
              position,
              [
                color.withValues(alpha: 0.02),
                color.withValues(alpha: 0.35),
                Color.lerp(color, Colors.white, 0.35)!,
              ],
              const [0.0, 0.6, 1.0],
            )
            ..strokeWidth = 7.5 * visualScale
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          position,
          6.0 * visualScale,
          Paint()..color = color.withValues(alpha: 0.92),
        );
        canvas.drawCircle(
          position -
              Offset(cos(projectile.angle), sin(projectile.angle)) *
                  (2.5 * visualScale),
          3.2 * visualScale,
          Paint()..color = Color.lerp(color, const Color(0xFF2B1A12), 0.55)!,
        );
        canvas.drawCircle(
          position +
              Offset(cos(projectile.angle + 0.6), sin(projectile.angle + 0.6)) *
                  (1.8 * visualScale),
          1.7 * visualScale,
          Paint()..color = const Color(0xFFFFF2D6).withValues(alpha: 0.85),
        );
        break;
      case ProjectileVisualStyle.slash:
        final len = 8.0 * visualScale;
        canvas.drawLine(
          position - Offset(cos(projectile.angle), sin(projectile.angle)) * len,
          position + Offset(cos(projectile.angle), sin(projectile.angle)) * len,
          Paint()
            ..color = color.withValues(alpha: 0.9)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
        break;
      case ProjectileVisualStyle.dart:
        canvas.drawCircle(
          position,
          2 * visualScale,
          Paint()..color = color.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          position,
          4 * visualScale,
          Paint()..color = color.withValues(alpha: 0.15),
        );
        break;
      case ProjectileVisualStyle.sigil:
      case ProjectileVisualStyle.hornImpact:
        final pulse = 0.7 + 0.3 * sin(_time * 4);
        canvas.drawCircle(
          position,
          4 * visualScale,
          Paint()..color = color.withValues(alpha: 0.4 * pulse),
        );
        canvas.drawCircle(
          position,
          2 * visualScale,
          Paint()..color = Colors.white.withValues(alpha: 0.6 * pulse),
        );
        break;
      case ProjectileVisualStyle.kinOrbital:
        final radius = (1.6 * visualScale).clamp(1.4, 5.8).toDouble();
        final pulse = 0.78 + 0.22 * sin(_time * 3.4 + projectile.life);
        canvas.drawCircle(
          position,
          radius * 2.6,
          Paint()..color = color.withValues(alpha: 0.20 * pulse),
        );
        for (var i = 0; i < 2; i++) {
          final a = _time * 2.4 + i * pi;
          canvas.drawCircle(
            position + Offset(cos(a), sin(a)) * radius * 1.9,
            radius * 0.42,
            Paint()..color = color.withValues(alpha: 0.75 * pulse),
          );
        }
        canvas.drawCircle(
          position,
          radius,
          Paint()..color = color.withValues(alpha: 0.92 * pulse),
        );
        canvas.drawCircle(
          position,
          radius * 0.42,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * pulse),
        );
        break;
      case ProjectileVisualStyle.mysticOrbital:
        canvas.drawCircle(
          position,
          3 * visualScale,
          Paint()..color = color.withValues(alpha: 0.6),
        );
        canvas.drawCircle(
          position,
          6 * visualScale,
          Paint()..color = color.withValues(alpha: 0.12),
        );
        break;
      case ProjectileVisualStyle.letShard:
        final dir = Offset(cos(projectile.angle), sin(projectile.angle));
        final perp = Offset(-dir.dy, dir.dx);
        final tailLen = 30.0 * visualScale;
        final tail = position - dir * tailLen;
        canvas.drawLine(
          tail,
          position,
          Paint()
            ..shader = ui.Gradient.linear(
              tail,
              position,
              [
                color.withValues(alpha: 0.0),
                color.withValues(alpha: 0.16),
                Color.lerp(color, Colors.white, 0.18)!,
              ],
              const [0.0, 0.58, 1.0],
            )
            ..strokeWidth = 5.4 * visualScale
            ..strokeCap = StrokeCap.round,
        );
        final shard = Path()
          ..moveTo(
            position.dx + dir.dx * (8.5 * visualScale),
            position.dy + dir.dy * (8.5 * visualScale),
          )
          ..lineTo(
            position.dx + perp.dx * (4.2 * visualScale),
            position.dy + perp.dy * (4.2 * visualScale),
          )
          ..lineTo(
            position.dx - dir.dx * (6.0 * visualScale),
            position.dy - dir.dy * (6.0 * visualScale),
          )
          ..lineTo(
            position.dx - perp.dx * (4.2 * visualScale),
            position.dy - perp.dy * (4.2 * visualScale),
          )
          ..close();
        canvas.drawPath(
          shard,
          Paint()
            ..shader = ui.Gradient.linear(
              tail,
              position + dir * (10.0 * visualScale),
              [
                Color.lerp(color, const Color(0xFF1A1014), 0.42)!,
                color,
                Color.lerp(color, Colors.white, 0.55)!,
              ],
              const [0.0, 0.62, 1.0],
            ),
        );
        canvas.drawPath(
          shard,
          Paint()
            ..color = Color.lerp(
              color,
              Colors.white,
              0.42,
            )!.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 * visualScale,
        );
        canvas.drawCircle(
          position - dir * (1.2 * visualScale),
          2.4 * visualScale,
          Paint()..color = const Color(0xFFFFF4DC).withValues(alpha: 0.85),
        );
        break;
      case ProjectileVisualStyle.standard:
        canvas.drawCircle(
          position,
          3 * visualScale,
          Paint()..color = color.withValues(alpha: 0.8),
        );
        canvas.drawCircle(
          position,
          5 * visualScale,
          Paint()..color = color.withValues(alpha: 0.15),
        );
        break;
    }

    drawProjectileRoleOverlay(
      canvas: canvas,
      projectile: projectile,
      position: position,
      color: color,
      time: _time,
    );

    if (projectile.decoy) {
      canvas.drawCircle(
        position,
        12 * visualScale,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _renderCombatEnemies(Canvas canvas) {
    for (final enemy in combatEnemies) {
      if (enemy.isDead) continue;
      // The guardian is drawn as the winged Roc body (one Roc, not a blob
      // chasing alongside it).
      if (identical(enemy, _guardianEnemy)) continue;
      final base = elementColor(enemy.element);
      // Dive telegraph: a tightening ring during the windup so the swoop is
      // readable and dodgeable.
      final motion = enemy.flightSteering;
      if (motion != null && motion.showTelegraphRing) {
        canvas.drawCircle(
          enemy.position,
          enemy.radius + 6 + motion.windupTimer * 46,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Color.lerp(
              base,
              Colors.white,
              0.5,
            )!.withValues(alpha: 0.75),
        );
      }
      final flash = enemy.hitFlash > 0
          ? Color.lerp(base, Colors.white, enemy.hitFlash.clamp(0.0, 1.0))!
          : base;
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          enemy.position,
          enemy.radius * (enemy.isElite ? 2.8 : 2.1),
          flash.withValues(alpha: enemy.isElite ? 0.34 : 0.22),
        );
      }
      canvas.save();
      canvas.translate(enemy.position.dx, enemy.position.dy);
      canvas.rotate(enemy.angle);
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2 + _time * (enemy.isElite ? 1.2 : 1.8);
        final path = Path()
          ..moveTo(cos(a) * enemy.radius * 0.4, sin(a) * enemy.radius * 0.4)
          ..quadraticBezierTo(
            cos(a + 0.35) * enemy.radius * 1.1,
            sin(a + 0.35) * enemy.radius * 1.1,
            cos(a) * enemy.radius * 1.7,
            sin(a) * enemy.radius * 1.7,
          );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = enemy.isElite ? 3 : 2
            ..strokeCap = StrokeCap.round
            ..color = flash.withValues(alpha: 0.38),
        );
      }
      canvas.drawCircle(
        Offset.zero,
        enemy.radius,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(-enemy.radius * 0.2, -enemy.radius * 0.25),
            enemy.radius * 1.25,
            [
              Color.lerp(flash, Colors.white, 0.45)!.withValues(alpha: 0.95),
              flash.withValues(alpha: 0.82),
              const Color(0xFF05070D).withValues(alpha: 0.92),
            ],
            const [0.0, 0.52, 1.0],
          ),
      );
      canvas.restore();

      final barW = enemy.radius * 2.2;
      final bar = Rect.fromCenter(
        center: enemy.position + Offset(0, -enemy.radius - 12),
        width: barW,
        height: 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(3)),
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            bar.left,
            bar.top,
            bar.width * enemy.hpFraction,
            bar.height,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = flash.withValues(alpha: 0.85),
      );
    }
  }

  /// A refusal, drawn instead of said.
  ///
  /// A cold ring collapsing INWARD on the active creature — inward because it
  /// reads as something being turned back, where the outward bursts every
  /// successful verb throws read as something taking effect. No blur, three
  /// strokes, gone in under half a second.
  void _renderRefusalPulse(Canvas canvas) {
    if (refusalFlash <= 0) return;
    final a = active;
    if (a == null) return;
    final t = refusalFlash.clamp(0.0, 1.0);
    for (var i = 0; i < 3; i++) {
      final phase = (t - i * 0.12).clamp(0.0, 1.0);
      if (phase <= 0) continue;
      canvas.drawCircle(
        a.position,
        14 + phase * 26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFE25544).withValues(alpha: 0.42 * phase),
      );
    }
  }

  void _renderCreatures(Canvas canvas) {
    for (var i = 0; i < creatures.length; i++) {
      final c = creatures[i];
      final isActive = i == activeIndex && c.alive;
      final ec = elementColor(c.member.element);

      canvas.save();
      canvas.translate(c.position.dx, c.position.dy);

      // Downed: a dim, grounded ghost of the creature — no aura, no ring.
      if (!c.alive) {
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 14), width: 34, height: 10),
          Paint()..color = Colors.black.withValues(alpha: 0.30),
        );
        final ticker = c.ticker;
        if (ticker != null) {
          final sprite = ticker.getSprite();
          final paint = Paint()
            ..filterQuality = ui.FilterQuality.high
            ..color = Colors.white.withValues(alpha: 0.32);
          canvas.save();
          canvas.scale(c.spriteScale, c.spriteScale);
          sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
          canvas.restore();
        } else {
          canvas.drawCircle(
            Offset.zero,
            13,
            Paint()..color = ec.withValues(alpha: 0.25),
          );
        }
        canvas.restore();
        continue;
      }

      // Elemental aura (baked glow) — kept soft so it never reads as a
      // shield bubble around the body.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          Offset.zero,
          isActive ? 26 : 24,
          ec.withValues(alpha: isActive ? 0.38 : 0.28),
        );
      } else {
        canvas.drawCircle(
          Offset.zero,
          22,
          Paint()..color = ec.withValues(alpha: isActive ? 0.18 : 0.12),
        );
      }
      // Charge trail: glow + trailing motes behind a ramming horn — the
      // same dash language as survival.
      final chargingComp = i < combatCompanions.length
          ? combatCompanions[i]
          : null;
      if (chargingComp != null && chargingComp.chargeTimer > 0) {
        final chargeWidth = (chargingComp.chargeSweepRadius / 48.0).clamp(
          0.70,
          2.20,
        );
        final trailScale = (chargingComp.chargeOvershootDistance / 80.0).clamp(
          0.65,
          2.10,
        );
        canvas.drawCircle(
          Offset.zero,
          28 * chargeWidth,
          Paint()..color = ec.withValues(alpha: 0.35),
        );
        for (var t = 0; t < 4; t++) {
          final trailAngle = c.angle + pi;
          final trailDist = (7.0 + t * 7.0) * trailScale;
          canvas.drawCircle(
            Offset(cos(trailAngle) * trailDist, sin(trailAngle) * trailDist),
            (5.0 - t) * chargeWidth,
            Paint()..color = ec.withValues(alpha: (1.0 - t / 4.0) * 0.34),
          );
        }
      }
      if (isActive) {
        // Underfoot selection marker (ground reticle, not a bubble).
        final markerPulse = 0.65 + 0.35 * sin(_time * 3.2);
        final marker = Rect.fromCenter(
          center: const Offset(0, 17),
          width: 36,
          height: 11,
        );
        canvas.drawOval(
          marker,
          Paint()
            ..color = const Color(
              0xFFE4C16A,
            ).withValues(alpha: 0.14 * markerPulse),
        );
        canvas.drawOval(
          marker,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(
              0xFFE4C16A,
            ).withValues(alpha: 0.55 + 0.25 * markerPulse),
        );
        if (flightActive) {
          // Swirling wind ring while gliding.
          for (var k = 0; k < 3; k++) {
            final ang = _time * 5 + k * (pi * 2 / 3);
            canvas.drawCircle(
              Offset(cos(ang) * 28, sin(ang) * 28),
              2.2,
              Paint()..color = const Color(0xFF5BC8E8).withValues(alpha: 0.8),
            );
          }
        }
      }

      // Damage feedback: brief red flash on the body when struck.
      final hitFlash = i < combatCompanions.length
          ? combatCompanions[i].hitFlash
          : 0.0;
      if (hitFlash > 0) {
        canvas.drawCircle(
          Offset.zero,
          20,
          Paint()
            ..color = const Color(
              0xFFE0524D,
            ).withValues(alpha: 0.45 * (hitFlash / 0.22).clamp(0.0, 1.0)),
        );
      }

      // Cast telegraphs: a converging ring while a kin laser charges or a
      // horn winds up / brews its storm.
      if (i < combatCompanions.length) {
        final castComp = combatCompanions[i];
        double progress = -1;
        if (castComp.kinAutoChargeTimer > 0) {
          progress = (castComp.kinAutoChargeTimer / _kinChargeTime).clamp(
            0.0,
            1.0,
          );
        } else if (castComp.windUpTimer > 0 ||
            castComp.hornPostDashWindUpTimer > 0) {
          progress = 0.5 + 0.5 * sin(_time * 7).abs();
        }
        if (progress >= 0) {
          canvas.drawCircle(
            Offset.zero,
            26 - 12 * progress,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = Color.lerp(
                ec,
                Colors.white,
                0.45,
              )!.withValues(alpha: 0.35 + 0.45 * progress),
          );
        }
      }

      // Active horn shield: rotating arc segments (reads as a barrier,
      // not a selection marker).
      final shieldHp = i < combatCompanions.length
          ? combatCompanions[i].shieldHp
          : 0;
      if (shieldHp > 0) {
        final shieldPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF8FE6FF).withValues(alpha: 0.62);
        final rect = Rect.fromCircle(center: Offset.zero, radius: 23);
        for (var k = 0; k < 3; k++) {
          canvas.drawArc(
            rect,
            _time * 1.6 + k * pi * 2 / 3,
            pi * 0.42,
            false,
            shieldPaint,
          );
        }
      }

      final ticker = c.ticker;
      if (ticker != null) {
        final sprite = ticker.getSprite();
        final paint = Paint()..filterQuality = ui.FilterQuality.high;
        final facingRight = cos(c.angle) > 0;
        canvas.save();
        canvas.scale(
          facingRight ? -c.spriteScale : c.spriteScale,
          c.spriteScale,
        );
        sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
        canvas.restore();
      } else {
        canvas.drawCircle(
          Offset.zero,
          13,
          Paint()..color = ec.withValues(alpha: 0.9),
        );
      }
      canvas.restore();
    }
  }
}
