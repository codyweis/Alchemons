// lib/games/planet_dungeon/planet_dungeon_layout_poison.dart
//
// VENOM MONASTERY — the Poison planet's layout AND its pure triage rules.
//
// docs/dungeons.md §5.5 claims for Poison:
//   topology  — "Quarantine wards: sealed wards; opening one lets the
//               contagion in"
//   question  — "you cannot cure every ward — choose what to sacrifice"
//   vault     — "inside the ward you chose NOT to save"
//   mechanic  — "irreversible sacrifice choice" (open archetype pool)
// and §6.13 fixes the flavour: *every strain BEHAVES — behavior is the
// diagnosis; and one ward cannot be saved.*
//
// TOPOLOGY — THE LAZARET LADDER (untaken; not a hub, not a ring, not a line).
// One long ambulatory runs the length of the house with FOUR wards ranged
// along its north flank, and the wards are ALSO joined to one another by
// inner squints. Every ward therefore has two approaches — the clean
// corridor, or straight through your neighbour's contagion — which is what
// makes the Mud mane's trail worth carrying. The charnel at the far end is
// the exception: the monks bricked it shut, so it has no squint at all.
// Nothing here is a spoke off a court: the ambulatory is a WALK, the wards
// are its stations, and the crypt hangs under whichever ward you gave up.
//
// THE RULES ARE PURE AND LIVE HERE (the burn_field.dart model): the engine,
// the renderer and the solvability proof in test/venom_monastery_test.dart
// all reason about ONE copy of [WardTriage], so "can this run still be
// finished" is answered by the shipped code and not by a model of it.
//
// The fixture classes live here too (rather than in planet_dungeon_data.dart
// with the older planets') so this planet's diff against shared files stays
// to a handful of additive lines while other elements are built in parallel.

import 'dart:math' show Random;
import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart'
    show GuardianEncounterRequirement;

// ─────────────────────────────────────────────────────────
// THE STRAINS — behaviour IS the diagnosis (§6.13)
// ─────────────────────────────────────────────────────────

/// What a ward's contagion DOES. Never a colour, never a label: the player
/// reads the habit and nothing else (the ash-garden playtest lesson — an icon
/// that "means" something is not a fact the player owns; a thing that visibly
/// keeps a beat is).
enum WardStrain {
  /// Blooms and shrinks on a steady beat, out from the ward's heart.
  pulse,

  /// Crawls the walls: a fringe that creeps along the room's border.
  creep,

  /// Jumps host to host — it reappears beside whoever is walking.
  leap,

  /// Plays dead. Still, dark patches that erupt only when a body nears.
  feign,
}

/// The four draughts the infirmary still can pour. Each is defined by what it
/// physically DOES, so matching one to a strain is reasoning, never lore.
enum WardDraught {
  /// The stilling bell — damps motion. Nothing keeps a beat in it.
  stilling,

  /// The lime kiln — caustic. It eats whatever clings to stone.
  quicklime,

  /// The smoke pot — fills the space BETWEEN bodies. Nothing crosses a gap
  /// it has filled.
  binding,

  /// The wake-bitters — nothing lies still in it. It rouses what plays dead.
  rousing,
}

/// The one-to-one counter. Every pairing is deducible from the two
/// behaviours alone (§5.6: mechanics knowledge is EARNED, never labelled).
WardDraught antidoteFor(WardStrain strain) => switch (strain) {
  WardStrain.pulse => WardDraught.stilling, // break the beat
  WardStrain.creep => WardDraught.quicklime, // burn it off the stone
  WardStrain.leap => WardDraught.binding, // fill the gap it jumps
  WardStrain.feign => WardDraught.rousing, // nothing plays dead in bitters
};

/// The inverse, for the render and the insight lines.
WardStrain strainAnsweredBy(WardDraught draught) => switch (draught) {
  WardDraught.stilling => WardStrain.pulse,
  WardDraught.quicklime => WardStrain.creep,
  WardDraught.binding => WardStrain.leap,
  WardDraught.rousing => WardStrain.feign,
};

/// The fixture a spout wears, so the world tells you what it does without a
/// caption (§5.6 — the world and Mask do the teaching).
String draughtFixtureName(WardDraught d) => switch (d) {
  WardDraught.stilling => 'the stilling bell',
  WardDraught.quicklime => 'the lime kiln',
  WardDraught.binding => 'the smoke pot',
  WardDraught.rousing => 'the wake-bitters',
};

/// One clause naming what a strain visibly DOES — the diagnosis, in words,
/// only ever spoken by earned Mask insight.
String strainHabit(WardStrain s) => switch (s) {
  WardStrain.pulse => 'it keeps a beat',
  WardStrain.creep => 'it clings to the stone',
  WardStrain.leap => 'it jumps the gap to whoever walks',
  WardStrain.feign => 'it lies still until it is touched',
};

/// What administering a draught did. The renderer and the hint channel both
/// read this, so "why did that not work" is answerable from one place.
enum DoseOutcome {
  /// Right draught: the strain dies and the sacristy unlocks.
  cured,

  /// Wrong draught: the strain FEEDS on it (§6.13) and turns virulent — for
  /// the rest of the run, and out into the ambulatory.
  fed,

  /// Nothing in hand.
  noPhial,

  /// This ward is already clean, or already crossed off.
  settled,

  /// Still waxed shut — you cannot dose what you have not let out.
  sealed,
}

// ─────────────────────────────────────────────────────────
// THE TRIAGE — the pure, headless rules
// ─────────────────────────────────────────────────────────

/// Cures the house can ever afford. FOUR wards, THREE cures: the surrender is
/// structural, not a difficulty knob (§5.5 strategic question).
const int kMonasteryCures = 3;

/// Draughts the venom cistern holds at the start of a run. Exactly enough for
/// a clean sweep and not one spare — so the count is felt.
const int kMonasteryCistern = 3;

/// The monastery's whole triage, as rules with no engine in them.
///
/// THE ONE INVARIANT, and the reason this is testable in isolation:
/// **exactly three wards can ever be cured, and three always can be.**
///   · never four — once three are clean the cistern is dry and the dregs
///     refuse, so no amount of play saves the house entire;
///   · never fewer — [dregsAvailable] tops the cistern back up whenever it
///     runs dry with wards still savable, so a misdiagnosis costs the player
///     a permanently virulent strain (real) and never a star (not punishing).
class WardTriage {
  WardTriage({
    required List<String> wardIds,
    required Map<String, WardStrain> strains,
  }) : wardIds = List.unmodifiable(wardIds),
       _strains = Map.of(strains);

  /// Ward ids in walking order along the ambulatory.
  final List<String> wardIds;
  final Map<String, WardStrain> _strains;

  /// Draughts left in the venom cistern.
  int cistern = kMonasteryCistern;

  /// The phial in hand (one at a time — a physician carries one dose).
  WardDraught? carried;

  /// Wards whose wax seal has been broken. Opening a ward lets its contagion
  /// meet you — and is the only way to watch it behave (§5.5 topology).
  final Set<String> opened = {};

  /// Wards whose strain is dead.
  final Set<String> cured = {};

  /// Wards fed a wrong draught. Permanent for the run: the strain doubles and
  /// spills out into the ambulatory.
  final Set<String> virulent = {};

  /// Sacristies already claimed (a cured ward's one mercy).
  final Set<String> sacristiesTaken = {};

  /// The ward barred with the plague-cross. Null until the triage is
  /// committed; irreversible after.
  String? surrendered;

  bool get isEmpty => wardIds.isEmpty;

  WardStrain? strainOf(String wardId) => _strains[wardId];

  /// THE DREGS — the almoner's never-strand valve, and the rule that makes
  /// "three, never four" true. The cistern refills by one ONLY when it is
  /// dry, nothing is in hand, and there are still wards that can be saved.
  /// Once three are clean it refuses forever.
  bool get dregsAvailable =>
      cistern <= 0 && carried == null && cured.length < kMonasteryCures;

  /// Break a ward's wax seal. Returns false if it was already open.
  bool open(String wardId) => opened.add(wardId);

  /// Draw [d] from the still. False when hands are full or the house is dry
  /// (see [dregsAvailable]).
  bool draw(WardDraught d) {
    if (carried != null) return false;
    if (cistern <= 0) {
      if (!dregsAvailable) return false;
      cistern = 1; // the dregs
    }
    cistern--;
    carried = d;
    return true;
  }

  /// Patient zero's own venom, in the crypt: the finale is a diagnosis under
  /// fire, never a supply problem, so the carrion font never runs dry and
  /// never touches the cistern.
  bool drawCarrion(WardDraught d) {
    if (carried != null) return false;
    carried = d;
    return true;
  }

  /// Give up the carried phial without dosing a ward (the sick wisp).
  WardDraught? spend() {
    final d = carried;
    carried = null;
    return d;
  }

  /// Administer the carried draught to [wardId].
  DoseOutcome dose(String wardId) {
    final d = carried;
    if (d == null) return DoseOutcome.noPhial;
    if (surrendered != null || cured.contains(wardId)) {
      return DoseOutcome.settled;
    }
    if (!opened.contains(wardId)) return DoseOutcome.sealed;
    carried = null;
    if (antidoteFor(_strains[wardId]!) == d) {
      cured.add(wardId);
      return DoseOutcome.cured;
    }
    // §6.13: a wrong brew FEEDS it.
    virulent.add(wardId);
    return DoseOutcome.fed;
  }

  /// The triage can be sealed once three wards are clean.
  bool get canCommit => cured.length >= kMonasteryCures && surrendered == null;

  /// The ward still uncured when the cross goes up — chosen by which three
  /// you saved, which is where the real decision lived all along.
  String? get condemned {
    for (final w in wardIds) {
      if (!cured.contains(w)) return w;
    }
    return null;
  }

  /// COMMIT — irreversible. Returns the ward surrendered, or null if the
  /// house is not ready to be crossed off.
  String? commit() {
    if (!canCommit) return null;
    return surrendered = condemned;
  }

  /// A strain loose in the ambulatory: the one you surrendered, plus any you
  /// fed. This is the cost the player carries for the rest of the run.
  Set<WardStrain> get loose {
    // NOTHING IS LOOSE BY DEFAULT ANY MORE. `surrendered` names the crypt
    // ward now, not a ward given up, so reading it here put the dead-house's
    // strain in the cloister for the whole run.
    final out = <WardStrain>{};
    for (final v in virulent) {
      if (cured.contains(v)) continue; // a cured strain is dead, fed or not
      final st = _strains[v];
      if (st != null) out.add(st);
    }
    return out;
  }

  /// Can this run still finish? True whenever three wards are already clean,
  /// or enough are still savable — the honest answer to "have I ruined it",
  /// and it is ALWAYS yes (proved exhaustively in the test).
  bool get canStillFinish {
    if (surrendered != null) return cured.length >= kMonasteryCures;
    final savable = wardIds.where((w) => !cured.contains(w)).length;
    return cured.length + savable >= kMonasteryCures;
  }
}

// ─────────────────────────────────────────────────────────
// FIXTURES
// ─────────────────────────────────────────────────────────

/// One quarantine ward. Its strain is ROLLED PER RUN (never authored here —
/// wikis can never spoil a diagnosis), so the cell only carries geometry.
class WardCell {
  /// Stable id, also the room id.
  final String id;

  /// The house's own name for it, used in copy.
  final String name;

  /// Where the contagion lives — the render anchor and the pulse's centre.
  final Offset heart;

  /// The censer: where a draught is administered.
  final Offset censer;

  /// The sacristy: sealed until the ward is cured, then one mercy.
  final Offset sacristy;

  /// The oubliette stone in the floor — the way down to patient zero. Only
  /// ever opened in the ward that was surrendered (§5.5 vault trick).
  final Offset oubliette;

  /// The charnel is bricked, not waxed: only a Lava HORN breaches it (§4
  /// hard gate). A party without one simply cannot open this ward, which
  /// makes it their surrender — the gate SHAPES the triage instead of
  /// blocking a star.
  final bool bricked;

  const WardCell({
    required this.id,
    required this.name,
    required this.heart,
    required this.censer,
    required this.sacristy,
    required this.oubliette,
    this.bricked = false,
  });
}

/// One tap of the still, wearing the fixture that shows what it pours.

// ── THE CAULDRON (2026-09-03 rework) ─────────────────────────────────────
//
// The monastery stops being a diagnosis and becomes a WORKING. Three plagues
// sleep in three wards; each is woken by a potion brewed from two elements,
// and the brewing is the puzzle:
//
//   · An alchemon can contribute to TWO potions and no more. Three of them,
//     three potions of two ingredients each — six slots against six hands,
//     which is exactly tight and therefore forced with the ideal trio.
//   · So the strategy is not WHICH hand but WHEN. Contributing DRAINS that
//     alchemon until the next plague is down: whoever you spend on a brew is
//     the one who fights it weakened. Deciding who is fresh for which fight
//     is the whole of it.
//   · A woken plague does not stay put. It crawls out to the ambulatory and
//     waits for you there — so waking two before killing one is a choice you
//     are allowed to make and will regret.

/// One brew: what it takes, and what it wakes.
class PlaguePotion {
  const PlaguePotion({
    required this.id,
    required this.name,
    required this.first,
    required this.second,
    required this.wardId,
    required this.plague,
    required this.clue,
    required this.relic,
    required this.pot,
  });

  final String id;

  /// What the pot makes. It has a name because you carry it in a bottle with
  /// that name on it, and because "the deafening draught" told the player
  /// what it DOES — which is the answer, handed over.
  final String name;

  /// The two elements it is made of. Order never matters (deliberately: the
  /// three pairings are already the puzzle, and ordering them would only make
  /// it longer, not better).
  final String first;
  final String second;

  /// The ward whose sleeper it wakes, and what that sleeper is called.
  /// Null for the pure vial, which wakes nothing — it is the key that opens
  /// every ward at once, poured into the font in the middle of the cloister.
  final String? wardId;
  final String plague;

  /// THE ONLY THING THE HOUSE TELLS YOU. Nailed up in the plague's own room.
  /// It names neither ingredient — it says what the answer must DO, and the
  /// three ingredients are three verbs, so the clue and the larder shelf
  /// together are a deduction. (§5.6: state a fact, never a method.)
  final String clue;

  /// What the plague leaves on the floor when it goes down. Three of these
  /// at the cross is the pair of stars.
  final String relic;

  /// How the pot behaves the moment this pair comes together — the reaction
  /// is the receipt, and each one is unmistakably a different brew.
  final CauldronReaction pot;

  bool takes(String element) => element == first || element == second;
}

/// What the cauldron DOES when a pair lands in it. Also what the brew looks
/// like in the bottle and on the plague, so a potion reads the same in all
/// three places it is ever seen.
enum CauldronReaction {
  /// Poison + Poison. Nothing happens, loudly: it goes perfectly clear and
  /// perfectly still, which on this planet is the most alarming thing a pot
  /// has ever done.
  pure,

  /// Poison + Plant. Luminous flowers erupt off the surface and let go of
  /// sparkling spores.
  bloom,

  /// Poison + Mud. It goes black, thickens, and climbs the glass.
  climb,

  /// Plant + Mud. Roots thread up through the sludge and rot away at once.
  rot,
}

/// What each ingredient does in the pot, said once, at the cauldron. This is
/// the half of the deduction the apothecary is allowed to hand over — three
/// verbs against three clues, and the pairing falls out of it.
const Map<String, String> kPotionIngredientEffect = {
  'Poison': 'sickens — it turns a thing against its own body',
  'Plant': 'grows — green takes root in whatever will hold it',
  'Mud': 'slows — nothing moves quickly through it',
};

/// THE KEY. Poison and Poison — the one recipe that asks the same hand
/// twice, which is why the Poison alchemon has four gives in it and the
/// others two. Poured into the lustral font, every wax seal in the cloister
/// lets go at once.
const PlaguePotion kPureVial = PlaguePotion(
  id: 'purevial',
  name: 'the Pure Vial',
  first: 'Poison',
  second: 'Poison',
  wardId: null,
  plague: 'the sealed cloister',
  clue: 'This PURE poison is required.',
  relic: 'no reliquary',
  pot: CauldronReaction.pure,
);

const List<PlaguePotion> kPlaguePotions = [
  PlaguePotion(
    id: 'bloomvenom',
    name: 'Bloomvenom',
    first: 'Poison',
    second: 'Plant',
    wardId: 'ward_bell',
    plague: 'the Plague of Breath',
    clue: 'This poison must GROW within the plague.',
    relic: 'the Breath Reliquary',
    pot: CauldronReaction.bloom,
  ),
  PlaguePotion(
    id: 'mirebane',
    name: 'Mirebane',
    first: 'Poison',
    second: 'Mud',
    wardId: 'ward_refectory',
    plague: 'the Plague of Blood',
    clue: 'The poison must SLOW this plague to awaken it.',
    relic: 'the Blood Reliquary',
    pot: CauldronReaction.climb,
  ),
  PlaguePotion(
    id: 'graverot',
    name: 'Graverot',
    first: 'Plant',
    second: 'Mud',
    wardId: 'ward_scriptorium',
    plague: 'the Plague of Decay',
    clue: 'Pure poison, WITHOUT its purity, must be used here.',
    relic: 'the Decay Reliquary',
    pot: CauldronReaction.rot,
  ),
];

/// Everything the pot can make: the key first, then the three that wake
/// something. Order matters only for display.
const List<PlaguePotion> kAllBrews = [kPureVial, ...kPlaguePotions];

/// How many brews one alchemon can give to.
///
/// THE SUMS STILL COME OUT EVEN, which is the whole reason the numbers are
/// these numbers. Four recipes want Poison ×4 (one each for Bloomvenom and
/// Mirebane, and BOTH halves of the Pure Vial), Plant ×2 and Mud ×2. The
/// party has exactly that and not one give more.
const int kPotionContributionsEach = 2;
const int kPoisonContributions = 4;

int contributionsAllowedFor(String element) =>
    element == 'Poison' ? kPoisonContributions : kPotionContributionsEach;

/// The ward the crypt hangs off. It is the one ward with no plague in it —
/// the bricked dead-house — and the oubliette in its floor is the way down
/// to patient zero.
///
/// A CONSTANT, not run state. The triage that used to CHOOSE this ward is
/// gone, and the first thing that broke when it went was the way down: the
/// field it used to set is only written in a reset the constructor does not
/// call, so a fresh game had no crypt at all and capped at two stars.
const String kCryptWard = 'ward_charnel';

class ApothecarySpout {
  final WardDraught draught;
  final Offset position;
  const ApothecarySpout({required this.draught, required this.position});
}

/// The infirmary still (and, in the crypt, the carrion font that wears the
/// same four taps). Charging a spout wants Poison — or the monastery's own
/// braid, **Lava+Mud→Poison** (§6.13), with wisps as the recipe's price.
class Apothecary {
  final Offset cistern;
  final List<ApothecarySpout> spouts;
  const Apothecary({required this.cistern, required this.spouts});
}

/// The prior's seal: where the triage is committed and both of the first two
/// stars are declared. Carrying the star indices here (rather than on a room
/// flag) keeps the wards themselves star-free — Star 1 can bank in any of the
/// four, and the layout still declares 0 and 1 exactly once.
class PriorsSeal {
  final Offset position;

  /// Star banked by the FIRST correct cure (the Physician's Star).
  final int diagnosisStarIndex;

  /// Star banked when the plague-cross goes up (the Triage Star).
  final int triageStarIndex;

  const PriorsSeal({
    required this.position,
    required this.diagnosisStarIndex,
    required this.triageStarIndex,
  });
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Poison's lost maxim (§6 easter eggs #13, "The Dose").
const String kPoisonDoseEggId = 'egg:poison_the_dose';

/// Ward ids in walking order along the ambulatory. The charnel is last — the
/// dead-house at the end of the walk, and the one behind brick.
const List<String> kMonasteryWardIds = [
  'ward_bell',
  'ward_scriptorium',
  'ward_refectory',
  'ward_charnel',
];

/// Roll a fresh run's triage: every strain present exactly once, spread over
/// the four wards. ROLLED PER RUN (Earth's scale is the precedent) so the
/// diagnosis is always a reading of the world and never a memorised answer.
WardTriage rollWardTriage([Random? rng]) {
  final order = List.of(WardStrain.values)..shuffle(rng ?? Random());
  return WardTriage(
    wardIds: kMonasteryWardIds,
    strains: {
      for (var i = 0; i < kMonasteryWardIds.length; i++)
        kMonasteryWardIds[i]: order[i],
    },
  );
}

/// VENOM MONASTERY — the Poison dungeon.
///
/// Stars (§7: one core mechanic + one consequence + one success, each):
///  0 · **Physician's Star** — core: read a strain by its BEHAVIOUR and pour
///      the draught that answers it. Consequence: a wrong draught FEEDS the
///      strain, permanently, and out into the corridor. Success: the first
///      ward goes quiet.
///  1 · **Triage Star** — core: spend three cures across four wards and take
///      the plague-cross to the fourth. Consequence: the surrendered strain
///      owns the monastery for the rest of the run and its sacristy is
///      forfeit. Success: the cross goes up.
///  2 · **Blightfang** — patient zero, in the crypt under the ward you let go.
///
/// Family gates (§4, both tied to entry slots, neither blocking a star):
///  · `ward_charnel_brick` — **Plant HORN**. The bricked dead-house. A root
///    put through a joint is what actually takes a wall apart, and it must be
///    an element the pot uses: the summons asks for exactly Poison, Plant and
///    Mud, because those three are the only things the cauldron drinks.
///  · `ward_squint` — **Mud MANE**. The inner squints between wards: only a
///    trail-layer crosses a live ward with a brew still good. The ambulatory
///    reaches every ward regardless, so this buys a shortcut, not a star.
const DungeonLayout poisonLayout = DungeonLayout(
  element: 'Poison',
  entranceRoomId: 'lazar_gate',
  entranceSpawn: Offset(150, 240),
  title: 'THE VENOM MONASTERY',
  descentTitle: 'Toxica Lazaret',
  stars: [
    DungeonStarSpec(
      name: 'Physician\'s Star',
      earnAnnouncement:
          'The Physician\'s Star is yours — three brews, three plagues woken',
    ),
    DungeonStarSpec(
      name: 'Triage Star',
      earnAnnouncement:
          'The Triage Star is yours — and every ward of the house is quiet',
    ),
    DungeonStarSpec(name: 'Blightfang\'s Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('lazar_gate', 'ambulatory'),
  riteAnnouncement:
      'The cross rots off the barred ward — what you gave up lies open',
  guardianSealedHint:
      'The oubliette will not lift — the house keeps patient zero until all '
      'three plagues are down',
  mercyShrineRoomId: 'apothecary',
  // Ideal: Poisonmask · Planthorn · Mudmane — hinted by VERB, never body part
  // (§4 THE DESCENT RIDDLE). These three are also THE POT'S WHOLE LARDER, so
  // the riddle is doing double duty: bring the wrong hands and the cauldron
  // has nothing to mix.
  riddle: [
    'Send me Poison, to turn a thing against its own body;',
    'a Plant Horn, to put a root through my brick and close a sound;',
    'and a Mud Mane, to leave a clean road, and to slow what runs on it.',
  ],
  primer: [
    'The pot takes two and makes one. It drinks Poison, Plant and Mud.',
    'Any alchemon has two brews in it. Three of them, three brews, no spare.',
  ],
  familyGates: [
    DungeonFamilyGate(
      objectId: 'ward_charnel_brick',
      element: 'Plant',
      family: 'Horn',
      hintLine: 'Only a Plant horn roots this brick apart',
    ),
    DungeonFamilyGate(
      objectId: 'ward_squint',
      element: 'Mud',
      family: 'Mane',
      hintLine: 'Only a Mud mane crosses a live ward clean',
    ),
  ],
  rooms: {
    // ── The Lazar Gate — the way in. The quarantine door is waxed shut; a
    // Poison creature's own touch softens the seal (entry rite).
    'lazar_gate': DungeonRoom(
      id: 'lazar_gate',
      bounds: Rect.fromLTWH(0, 0, 720, 480),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 195, 24, 90),
          targetRoomId: 'ambulatory',
          targetSpawn: Offset(90, 260),
        ),
      ],
    ),

    // ── The Ambulatory — the processional walk, and the spine of the ladder.
    // Four ward doors along its north flank, the infirmary below, the prior's
    // seal at the far end. Whatever contagion you let loose walks here too.
    'ambulatory': DungeonRoom(
      id: 'ambulatory',
      bounds: Rect.fromLTWH(0, 0, 1400, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 215, 24, 90),
          targetRoomId: 'lazar_gate',
          targetSpawn: Offset(630, 240),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(150, 0, 110, 24),
          chromeless: true, // sealed with wax, not locked with a key
          targetRoomId: 'ward_bell',
          // (280, 330) landed exactly on the bottom edge of ward_bell's own
          // door down to the lazar crypt — walk in from the ambulatory and
          // you fell straight through to the crypt. Below it, beside the way
          // back, where arriving from the south belongs.
          targetSpawn: Offset(280, 380),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(470, 0, 110, 24),
          chromeless: true, // sealed with wax, not locked with a key
          targetRoomId: 'ward_scriptorium',
          // Every ward is laid out alike, with its own hatch down to the
          // crypt at (255, 290, 50, 40) — and (280, 330) sat exactly on that
          // hatch's bottom edge, so walking in from the ambulatory dropped
          // you straight through into the lazar crypt.
          targetSpawn: Offset(280, 380),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(790, 0, 110, 24),
          chromeless: true, // sealed with wax, not locked with a key
          targetRoomId: 'ward_refectory',
          // Every ward is laid out alike, with its own hatch down to the
          // crypt at (255, 290, 50, 40) — and (280, 330) sat exactly on that
          // hatch's bottom edge, so walking in from the ambulatory dropped
          // you straight through into the lazar crypt.
          targetSpawn: Offset(280, 380),
        ),
        // The bricked one (Lava HORN — §4 hard gate).
        DungeonDoor(
          rect: Rect.fromLTWH(1110, 0, 110, 24),
          chromeless: true, // sealed with wax, not locked with a key
          targetRoomId: 'ward_charnel',
          // Every ward is laid out alike, with its own hatch down to the
          // crypt at (255, 290, 50, 40) — and (280, 330) sat exactly on that
          // hatch's bottom edge, so walking in from the ambulatory dropped
          // you straight through into the lazar crypt.
          targetSpawn: Offset(280, 380),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(640, 496, 110, 24),
          targetRoomId: 'apothecary',
          targetSpawn: Offset(360, 120),
        ),
      ],
      // THE LUSTRAL FONT, dead centre of the corridor and between the two
      // middle ward doors, so it is the first fixture you meet coming up
      // from the laboratory and it is on the way to everywhere.
      lustralFont: Offset(685, 250),
      priorsSeal: PriorsSeal(
        position: Offset(1230, 330),
        diagnosisStarIndex: 0,
        triageStarIndex: 1,
      ),
    ),

    // ── The Apothecary — the cauldron, the larder shelf above it, and the
    // house's mercy. The still's four taps were taken out with the triage;
    // what is here now is one pot in the middle of the floor and three
    // labelled jars on the wall behind it. The pot is centred on purpose:
    // you walk in at the top, and the thing you came for is dead ahead with
    // its ingredients written up over it.
    'apothecary': DungeonRoom(
      id: 'apothecary',
      bounds: Rect.fromLTWH(0, 0, 720, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(305, 0, 110, 24),
          targetRoomId: 'ambulatory',
          targetSpawn: Offset(695, 400),
        ),
      ],
      apothecary: Apothecary(
        cistern: Offset(360, 250),
        spouts: [
          ApothecarySpout(
            draught: WardDraught.stilling,
            position: Offset(130, 190),
          ),
          ApothecarySpout(
            draught: WardDraught.quicklime,
            position: Offset(590, 190),
          ),
          ApothecarySpout(
            draught: WardDraught.binding,
            position: Offset(130, 400),
          ),
          ApothecarySpout(
            draught: WardDraught.rousing,
            position: Offset(590, 400),
          ),
        ],
      ),
    ),

    // ── Ward of the Bell — first station on the walk.
    'ward_bell': DungeonRoom(
      id: 'ward_bell',
      bounds: Rect.fromLTWH(0, 0, 560, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(225, 416, 110, 24),
          targetRoomId: 'ambulatory',
          targetSpawn: Offset(205, 90),
        ),
        // Inner squint east (Mud MANE — §4 hard gate).
        DungeonDoor(
          rect: Rect.fromLTWH(536, 190, 24, 90),
          targetRoomId: 'ward_scriptorium',
          targetSpawn: Offset(60, 235),
        ),
        // The oubliette: mid-floor, and only ever there in a surrendered ward.
        DungeonDoor(
          rect: Rect.fromLTWH(255, 290, 50, 40),
          targetRoomId: 'lazar_crypt',
          targetSpawn: Offset(145, 120),
        ),
      ],
      ward: WardCell(
        id: 'ward_bell',
        name: 'Ward of the Bell',
        heart: Offset(280, 200),
        censer: Offset(140, 120),
        sacristy: Offset(450, 110),
        oubliette: Offset(280, 310),
      ),
    ),

    // ── Ward of the Scriptorium.
    'ward_scriptorium': DungeonRoom(
      id: 'ward_scriptorium',
      bounds: Rect.fromLTWH(0, 0, 560, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(225, 416, 110, 24),
          targetRoomId: 'ambulatory',
          targetSpawn: Offset(525, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 190, 24, 90),
          targetRoomId: 'ward_bell',
          targetSpawn: Offset(500, 235),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(536, 190, 24, 90),
          targetRoomId: 'ward_refectory',
          targetSpawn: Offset(60, 235),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(255, 290, 50, 40),
          targetRoomId: 'lazar_crypt',
          targetSpawn: Offset(345, 120),
        ),
      ],
      ward: WardCell(
        id: 'ward_scriptorium',
        name: 'Ward of the Scriptorium',
        heart: Offset(280, 200),
        censer: Offset(140, 120),
        sacristy: Offset(450, 110),
        oubliette: Offset(280, 310),
      ),
    ),

    // ── Ward of the Refectory.
    'ward_refectory': DungeonRoom(
      id: 'ward_refectory',
      bounds: Rect.fromLTWH(0, 0, 560, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(225, 416, 110, 24),
          targetRoomId: 'ambulatory',
          targetSpawn: Offset(845, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 190, 24, 90),
          targetRoomId: 'ward_scriptorium',
          targetSpawn: Offset(500, 235),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(255, 290, 50, 40),
          targetRoomId: 'lazar_crypt',
          targetSpawn: Offset(545, 120),
        ),
      ],
      ward: WardCell(
        id: 'ward_refectory',
        name: 'Ward of the Refectory',
        heart: Offset(280, 200),
        censer: Offset(140, 120),
        sacristy: Offset(450, 110),
        oubliette: Offset(280, 310),
      ),
    ),

    // ── The Charnel — the dead-house. Bricked on every side, so it has no
    // squint at all: a Lava horn is the only way in, and a party without one
    // has already chosen what it will sacrifice.
    'ward_charnel': DungeonRoom(
      id: 'ward_charnel',
      bounds: Rect.fromLTWH(0, 0, 560, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(225, 416, 110, 24),
          targetRoomId: 'ambulatory',
          targetSpawn: Offset(1165, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(255, 290, 50, 40),
          targetRoomId: 'lazar_crypt',
          targetSpawn: Offset(745, 120),
        ),
      ],
      ward: WardCell(
        id: 'ward_charnel',
        name: 'The Charnel Ward',
        heart: Offset(280, 200),
        censer: Offset(140, 120),
        sacristy: Offset(450, 110),
        oubliette: Offset(280, 310),
        bricked: true,
      ),
    ),

    // ── The Lazar Crypt — under the ward you gave up. Blightfang lies here,
    // and so does the bottled essence: **you may only loot what you
    // sacrificed** (§5.5 vault trick). The carrion font wears the same four
    // taps as the still, because the fight is one more diagnosis.
    'lazar_crypt': DungeonRoom(
      id: 'lazar_crypt',
      bounds: Rect.fromLTWH(0, 0, 860, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(100, 0, 90, 24),
          targetRoomId: 'ward_bell',
          targetSpawn: Offset(280, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(300, 0, 90, 24),
          targetRoomId: 'ward_scriptorium',
          targetSpawn: Offset(280, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(500, 0, 90, 24),
          targetRoomId: 'ward_refectory',
          targetSpawn: Offset(280, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(700, 0, 90, 24),
          targetRoomId: 'ward_charnel',
          targetSpawn: Offset(280, 250),
        ),
      ],
      apothecary: Apothecary(
        cistern: Offset(150, 600),
        spouts: [
          ApothecarySpout(
            draught: WardDraught.stilling,
            position: Offset(80, 470),
          ),
          ApothecarySpout(
            draught: WardDraught.quicklime,
            position: Offset(230, 470),
          ),
          ApothecarySpout(
            draught: WardDraught.binding,
            position: Offset(80, 620),
          ),
          ApothecarySpout(
            draught: WardDraught.rousing,
            position: Offset(230, 620),
          ),
        ],
      ),
      // LIFTED off the crypt floor (2026-08-31). At (700, 600) the cache sat
      // under the action pad: the crypt is 700 tall against a 915 viewport, so
      // it never pans vertically, and it is close enough to the east wall that
      // the camera is clamped there whenever you stand on it. The pickup was
      // permanently behind the button you press to take it.
      vaultCache: Offset(700, 430),
      guardian: GuardianNode(
        position: Offset(470, 330),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Poison',
          mysticId: 'Blightfang',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);
