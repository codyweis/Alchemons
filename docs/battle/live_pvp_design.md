# Live friend PvP battle — design (2026-10-21)

**Phase 1 built 2026-10-21, not yet played on two phones.** The defaults
below were confirmed by the user. Where the build differs from this design:

- **Mirroring** happens at the link (`BattlePacket.mirrored()`). The random
  scatter at cast time (Mask traps, Dust Wing shards, Lightning Mane orbs) is
  laid out by angle from the cast, so a seed plus the mirrored angle lands in
  the same place.
- **The playback timeline is the host's real clock.** Each sample carries the
  fight clock and the slow-motion factor, so the end's slow motion plays out on
  the guest too.
- **Snapshots own the replica every frame.** Health, shields, positions,
  cooldowns and life are written back after the replica's local step, so
  local hits and heals can't flicker.
- **The guest's roster comes from the snapshots**, not from events: who
  stands where, falls and swaps. Events draw specials and the phoenix, and
  carry the end (with the DETAILS breakdown).
- **Leaving the room mid-fight** counts as leaving the fight. A guest who
  leaves the room concedes, and if the host closes the room the guest wins.
  The room's `result` backs up the stream's end event.

Where the code is:

- Wire format, tape and playback: `lib/games/cosmic/battle_wire.dart`
- Links (away, waiting, no contest): `lib/games/cosmic/battle_link.dart`
- Host and replica hooks: `cosmic_game_battle_live.dart`
- Room model: `lib/models/battle_room.dart`
- Room service: `lib/services/battle_room_service.dart`
- Screen link: `lib/screens/battle/battle_live.dart`
- Lobby: `lib/screens/battle/battle_lobby_screen.dart`
- Rules: `battle_rooms` in `firestore.rules`, not deployed yet. Their test is
  `functions/test/battle_rooms_rules.test.cjs`, which needs the emulator.
- Tests: `test/battle_live_test.dart`, `battle_room_test.dart` and
  `battle_lobby_test.dart`
- Film: `test/battle_live_preview_test.dart` →
  `docs/battle/live_two_phones.mp4`

On the fake network (150–450 ms delay), the guest stood 0.05 px from the
host's positions typically and 1.0 px at the 95th percentile. With 20% of
packets lost it was 2.1 px. Health matched exactly, and every special was
redrawn.

The rest of this file is the design as written before the build.

**Line numbers are at `39e2dc71`, before the battle-readiness work.** That
work has since landed: the Trials have a BATTLE tab (gated after Silver), a
first-time rules dialog (`lib/screens/battle/battle_how_to.dart`), and the
result card's DETAILS breakdown (`_battleCredit`, `damageDealt/Taken/healing`
in `cosmic_game_battle.dart`). The PvP work touches the same functions
(`_battleTurn`, `_settleBattleBodies`, `_battlerTurn`), so re-find the lines
before editing. Wherever this says "Emerald Cup WITH A FRIEND" or "the hub is
debug-only", read it as WITH A FRIEND on the Trials BATTLE tab.

**Defaults proposed to the user (not yet confirmed):** no rewards, plus a
head-to-head record with that friend; the computer plays a dropped guest's
side, a host gone for 30 s is no contest, leaving concedes; each player's
saved four, first two lead; entry from a friend's page and WITH A FRIEND on
the Trials BATTLE tab; Firestore first, the Realtime Database only if the
delay hurts on two phones.

---

## TL;DR

**Recommendation: host-authoritative, with the guest running a "replica" of the fight.**

- The **host's phone runs the real fight**, exactly as the vs-computer battle runs
  today. The guest's team is side 1 with `auto: false`, and the guest's focus and
  swap taps come in over the network.
- The **guest's phone runs the same `CosmicGame` battle in replica mode**. The host
  sends two things:
  - **events**: specials with caster/angle/target/seed, summons, swaps, falls,
    phoenix, end;
  - **absolute snapshots** at 10 Hz: field roster, positions, HP, shields,
    cooldowns, focus, swaps left, bench health.

  The guest replays each cast through the real `_castCompanionSpecial`, so every
  projectile, beam, trap and VFX is drawn by the real code. HP, positions, falls
  and results come only from the host. Basics and VFX run locally and are only
  for looks.
- **Phase 1 transport is Firestore**:
  - the lobby is a new `battle_rooms/{id}` collection, using the race room's
    patterns;
  - the host sends 4 packets/s into a ring of 8 docs under
    `battle_rooms/{id}/stream/{0..7}`, so each doc is written every 2 s, well under
    the 1 write/s per-doc limit;
  - guest inputs are a whole-list field on the room doc, the same way race taps
    are sent.

  This needs no new SDK and no console setup, and it can be tested end to end in
  one process with `fake_cloud_firestore`, which is already in `dev_dependencies`.
  The cost is a **guest view about 0.8 s behind the host** and a guest tap-to-effect
  of about 1.0–1.3 s. Focus is drawn on the guest's screen at once (prediction).
- **Phase 2, only if playing it on two phones shows the lag hurts: the Realtime
  Database.** It is not in the project today. It would bring the guest delay down
  to about 0.25 s and add `onDisconnect` presence.
- **Why not lockstep:** the battle runs on about 25k lines of combat code that
  survival, dungeons and space share. It uses the platform's sin/cos/atan2/exp/pow
  on almost every projectile every frame, and a shared unseeded RNG that both logic
  and VFX draw from. Its time step depends on frame rate, and two rules read the
  screen size. Making it bit-exact across iOS, Android and web is about 2–3 weeks.
  Any future change to that shared code can break it silently, and only two real
  phones on different platforms can prove it works. Lockstep also still needs a
  fast channel and a fallback for desyncs, and that fallback is host authority
  anyway.
- **Effort:** Phase 1 is about 5–7 agent-days including tests, plus a two-phone
  session with the user. Lockstep would be about 2–3 weeks to a first trustworthy
  fight, plus a cost on every later combat change.

---

## 1. Can the battle sim be made deterministic for lockstep?

### What the battle path is

- `CosmicGame.update` (cosmic_game.dart:2328) calls `super.update(dt)` and then
  returns into `_updateBattle(dt)` while a battle is on (cosmic_game.dart:2330-2332).
- `_updateBattle` (cosmic_game_battle.dart:563-650) runs both sides through
  `_battleTurn` → `_runAsSide` (cosmic_game_duel.dart:464-560). That swaps the
  game's `enemies`, `companionProjectiles`, `activeCompanions`, wing beams, mask and
  kin state and the ship stand-in to each side in turn.
- Inside that, the battle runs the **same code open space and survival use**:
  - `_battlerTurn` (battle.dart:783-851)
  - `_updateHornPhases`, `_tickOpenFamilyPassives`, `_fireCompanionBasic` and
    `_castCompanionSpecial` (cosmic_game_combat_actions.dart:61-210)
  - `createCosmicSpecialAbility` (cosmic_data.dart:5292) and the family builders
    `_hornSpecial` 6009, `_wingSpecial` 6828, `_letSpecial` 7874, `_pipSpecial`
    8024, `_maneSpecial` 8677, `_maskSpecial` 9739 and `_kinSpecial` 10325
  - `_updateAbilityProjectiles` (cosmic_game_ability_pass.dart:8)
  - the Wing, Mask, Kin, Mane and Horn parts
  - `cosmic_ability_runtime.dart`, `horn_runtime.dart`, `kin_support_runtime.dart`,
    `mane_runtime.dart`, `mask_trap_placement.dart` and
    `games/shared/companion_stance.dart`
- `cosmic_data.dart` and `cosmic_ability_runtime.dart` are also imported by
  `cosmic_survival_game.dart` and `cosmic_survival_spawner.dart`, so they are
  shared with survival.

### Inventory of what breaks determinism

| # | Category | Evidence | Logic or looks? |
|---|---|---|---|
| 1 | **Frame-rate dt** | `_updateBattle(dt)` takes Flame's real per-frame dt (cosmic_game.dart:2328-2331; BattleScreen hosts a `GameWidget`, battle_screen.dart:467). `_battleSlowMotion` eases the sim's own dt with `exp(-dt*7)` of real time (battle.dart:1222-1236). Side order flips **per frame**: `b._frame.isEven` (battle.dart:613). Explicit Euler steps such as `comp.position += comp.velocity*dt` (battle.dart:904, 916) and per-frame cooldown checks. | Logic. Even vs the computer, a 120 Hz phone fights a slightly different fight from a 60 Hz one. |
| 2 | **Shared unseeded RNG** | `final Random _rng = Random();` (cosmic_game.dart:736) is used by both logic and VFX. **Logic draws:** status-effect chance `_rng.nextDouble() <= projectile.effectChance` (ability_pass.dart:645); Dust Kin shot miss, 80% (kin.dart:860, kin_support_runtime.dart:335); Kin Plant flower spots, which carry heals (kin.dart:932, kin_support_runtime.dart:737-740); Dark Horn capture jitter moves foes (horn.dart:417-420); Mud Horn sludge jitter (horn.dart:650-651); Mask field eject landing (mask.dart:612-617 → cosmic_ability_runtime.dart:851); Mane Lightning orb landing points (mane.dart:76 → mane_runtime.dart:93-94); Earth Mane quake pulses (mane.dart:105 → mane_runtime.dart:180); Wing Steam kill clouds (wing.dart:573 → cosmic_ability_runtime.dart:1165-1170). **Fresh `Random()` inside cast building:** Dust Mane sandblast angles (cosmic_data.dart:7326); every Mask trap scatter (cosmic_data.dart:9756, used at 9920). | About 14 logic sites. About 25 VFX emitters draw from the **same** `_rng`: horn.dart 257/450/454/458/520/548/640/726, wing 361/387, mask 175/347/421/617/685, kin 554/643, ability_pass 1230, and others. |
| 3 | **VFX feeding logic** | VFX pool sizes gate how many draws are taken from that shared `_rng`: `if (_abilityVfx.length < 140 && _rng.nextDouble() < dt * 6.0)` (mask.dart:343), `particleRoom: _abilityVfx.length < kWingChargeParticleBudget` (wing.dart:360), `_abilityVfx.length < kWingBeamParticleBudget` (wing.dart:380), `_kinVfxHasRoom` (kin.dart:97). Changing a VFX budget, or a particle's life, shifts the logic RNG stream. `maneLavaPoolCrowd` is set **in render** (battle.dart:1443), but it only thins VFX (mane_alchemical_vfx.dart:592), so it is safe. | Couples looks to logic. |
| 4 | **Platform transcendentals** | Projectiles move by `cos(p.angle)*pSpeed*dt` and `sin(...)` every tick (ability_pass.dart:1105-1106), and homing uses `atan2` (ability_pass.dart:1036). Cast geometry in `createCosmicSpecialAbility`..`_mysticSpecial` (cosmic_data.dart 5292-10911) has **74 sin, 75 cos, 2 atan2 and 1 pow**. Runtime files: cosmic_ability_runtime 17, mane_runtime 12, kin_support_runtime 14, mask_trap_placement 9, horn_runtime 6. Battle: atan2 at 818 and 893, cos at 820, exp at 595 and 903. Duel knockback `exp` (duel.dart:361). `companionStation` sway uses sin/cos (companion_stance.dart:113-121). Stat curve `log` (stat_system.dart:169). Let recharge `pow` (alchemon_combat_stats.dart:463). Ability scaling `log` (cosmic_data.dart ~11572). | About 250–300 call sites on the logic path. Dart AOT calls the platform libm for these. Apple's libm and Android's bionic differ in the last bit for some inputs, and bionic changed its exp/log/pow implementation in later Android versions. Web uses JS `Math`. The fight is chaotic (range checks, collision radii, `reach <= attackRange`), so a 1-ulp difference becomes a different fight within seconds. `sqrt`/`.distance` and + − × ÷ are IEEE-exact and safe. |
| 5 | **Screen- and zoom-dependent rules** | `_maskFieldRadius = max(size.x,size.y)/_currentZoom*0.54` clamped to 1140–1660 (mask.dart:27-31). It sets where Mask ejects land. Mane Lightning `scatterRadius` uses `max(size.x,size.y)/max(0.7,_currentZoom)*0.42` (mane.dart:72-75). | Logic. It differs between a Fold and an iPhone, and changes with the player's zoom preset. This is also a small fairness bug vs the computer today. |
| 6 | **Identity hashes** | Hit-once sets keyed by `identityHashCode(enemy)` (ability_pass.dart:767, 1024, 1331, 1578; mask.dart:496, 593) and by `e.hashCode` (horn.dart:356-367, 704). | Membership only, so the only risk is a hash collision. Low priority; replace with stable body ids. |
| 7 | **Hash-ordered iteration** | None found. Dart's `{}` maps and sets are insertion-ordered `LinkedHashMap`/`LinkedHashSet`, and no `HashMap`/`HashSet` is on the path. `side._bodies`, `_targets` and `_combatBodies` are all insertion-ordered. | Safe, provided insertion order is the same. |
| 8 | **Flame components** | `CosmicGame` adds no child components, so `super.update` does nothing for the fight. Sprite tickers are cosmetic. Body radius comes from member data, `spriteVisuals.scale` (companion_motion.dart:70-74), not the loaded image. `_loadCompanionSprite` is async and logic never waits on it (battle.dart:512-514). | Safe. |
| 9 | **Starting state** | Both phones would need identical `CosmicPartyMember`s. Stats include constellation bonuses (`stadiumMemberOf`, stadium_screen.dart:92-118), and the stat curve has `log`. The race room handles this by having the owner compute the numbers (race_room.dart:6-10). The world is fixed: `CosmicWorld.generate(seed: 5)` (battle_screen.dart:246-247). | Solvable: send owner-computed numbers. |
| 10 | **Rollback is not available** | Races fix a late tap by replaying the whole race from tick 0 (`mergeTaps`). The battle's state is an object graph (projectiles, beams, traps, side states, identity-keyed maps) that cannot be snapshotted, and a replay from 0 means a new `CosmicGame` plus up to 5400 ticks. So lockstep would have to be **delay-based** with confirmed inputs. That needs heartbeats at around 10 Hz, which is beyond Firestore's per-document rate. | Needs RTDB plus stall handling. |
| 11 | **Web** | dart2js uses JS `Math.*`, and ints behave differently (bitwise ops are 32-bit, ints are doubles). | Web would need its own verification, or would be left out of lockstep. |

### Honest size of a lockstep pass

| Step | Work |
|---|---|
| Fixed 60 Hz step with an accumulator; split `_updateBattle` into sim and presentation (camera, floor, slow-mo, VFX ageing) | ~1 day |
| `det_math.dart` (sin, cos, tan, atan2, exp, pow, log, using + − × ÷ series as `islandSin` does in island_rules.dart:72-87). `import 'dart:math' hide …` in about 12 libraries. `cosmic_game.dart` is one library with 22 `part` files, so one import covers all of them. Handle `Offset.direction`/`fromDirection` (3 sites) and `math.`-prefixed calls (4 sites). | 1–2 days. Measure render cost: the same import also changes VFX and render code in open space and survival. |
| Split the RNG: about 14 logic sites to a seeded battle RNG, about 25 emitters to an fx RNG, and thread an rng into the two fresh `Random()`s | ~1 day |
| Pin screen-dependent radii; give bodies stable ids; owner-computed stats in seats | ~1 day |
| Determinism harness (the same fight under jittered frame pacing, other screen sizes and zooms, other VFX budgets must give the same fingerprint) and a source-scan guard test | ~1 day |
| **Finding the misses** in about 25k lines of shared combat code | 2–5 days, and never really finished: survival's family rebuild (b1a3d8d8, about 70 fixes) landed in these same files yesterday |
| Lockstep netcode: inputs scheduled N ticks ahead, heartbeats and confirmed ticks, stalls, fingerprints every second, "no contest" or correction on desync | 3–5 days, on RTDB |
| Proof | Only on real iPhone + Android pairs, and ideally two Android OS versions |

**About 2–3 weeks to the first trustworthy cross-platform fight, plus a standing
risk on every later combat change.** On a desync the only good recovery is the
host's state, which is the recommended design anyway.

---

## 2. Host-authoritative

### What the guest renders with

- **A lightweight replay renderer: rejected.** It would have to re-implement
  `_renderCompanion` (costumes, variants, albino, mutation sheets, effects) and the
  look of all 7 families' specials, or fall back to generic bursts. The user's VFX
  standard rules that out ("material not lines", alchemy in particles). It would
  also double the upkeep of every visual.
- **The full `CosmicGame` with logic off: not enough on its own.** A special's
  look is sim state: the projectiles, beams, traps and `_abilityVfx` its cast
  creates. With logic fully off nothing is cast, so nothing is drawn.
- **Recommended: the full `CosmicGame` in replica mode.**
  - **Runs on the guest from host data:** casts, from host events with the host's
    origin, angle, target and a per-cast seed, so trap scatter and orb landings
    match. Snapshots set positions (interpolated), HP, shields, special cooldowns,
    who is on the field and swaps left.
  - **Runs locally, for looks only:** projectiles, beams, traps, basic attacks,
    Kin lasers, VFX, sounds, floor steps, hit sparks and floor ripples (the ripples
    come from HP drops in the snapshots).
  - **Switched off on the guest:** `_battleSteer`, the HP part of
    `_settleOnCompanion`, `_battleFalls`, `_battleReplace`, `_battleThink`,
    `_judgeBattle` and the auto-special in `_battlerTurn` (battle.dart:839).
  - **HUD, camera, floor art and end card** are unchanged: BattleScreen and
    `_renderBattle` work as they do now.
- **Mirroring.** The guest's game puts the **guest's own team on side 0**, so
  every "side 0 = you, at the bottom" assumption in BattleScreen and `_renderBattle`
  stays true. Incoming host data is mirrored at the link: side → 1 − side, position
  relative to centre → its negative, angle → angle + π.
  - The arena is symmetric under a 180° turn: `spotAt` and `benchAt` (battle.dart:343-352).
  - Seeded scatter is relative to `baseAngle`, so it turns with the mirror.
  - Specials must be cast **inside that side's `_runAsSide` turn**: queue them per
    side and run them first in the `turn:` closure, because casts write to the
    side's own projectile and beam lists.

### State, rate, size

- **Snapshot (absolute, so a lost packet costs nothing):**
  - fight clock in ms, and timeScale × 100 so the guest follows slow-motion;
  - per side: the two field spots, a fallen mask, swaps left, focus, phoenix spent;
  - per field creature: x, y (×10, relative to centre), hp, shield, special
    cooldown in tenths of a second, faceRight, arrived;
  - health share of all 8 creatures, for the bench tubes.

  That is about 60 ints, roughly 250 bytes as JSON.
- **Events** (about 70 a fight): specials (≈0.5–0.8/s), summons, swaps, falls,
  phoenix, away, end, and accept/reject of a guest input. Each is a short int list.
  Every packet repeats the last ~24 events, numbered, so the guest can fill gaps.
- **Rate.**
  - Sample at **10 Hz of fight time**. Creatures turn within ~0.3 s
    (`kBattleAcceleration` 900); a Horn ram runs at `chargeSpeed` 400 × multiplier
    (cosmic_data.dart:12805) in a straight line. Linear interpolation of 100 ms
    samples is smooth for both.
  - 5 Hz would cut corners on turns.
  - Because casts are replayed exactly and positions interpolated, the samples
    never need to be faster than 10 Hz.
  - **Send** 4 packets/s on Firestore (2–3 samples each) or 10/s on RTDB.
- **Guest jitter buffer.** Playback time = newest sample − D. D is about 0.8 s on
  Firestore and 0.25–0.35 s on RTDB. Play 10% fast when behind; hold when starved.
  After 3 s starved, show "Waiting for Bo…". After 30 s, "No result".

### Transport

| | Firestore (in the project) | Realtime Database | Other |
|---|---|---|---|
| In the project? | Yes: `cloud_firestore ^5.6.12`, rules in `firestore.rules`, `fake_cloud_firestore` in dev deps | **No.** No `firebase_database` in pubspec.yaml; firebase.json has only `firestore` and `functions`; no `firebase_url`/`DATABASE_URL` in google-services.json or GoogleService-Info.plist. The instance probably doesn't exist yet and would need creating in the console (user). | Nothing realtime. `cloud_functions` is request/response only. `web_socket_channel` in pubspec.lock is a test-only transitive dependency. |
| Rate limit | 1 sustained write/s per **document** (soft). A ring of 8 stream docs at 4 packets/s gives 0.5 writes/s/doc. | Effectively none at this scale | — |
| Latency, write to other phone | Typically ~150–400 ms, with tails near 1 s. The guest is ~0.8 s behind; guest tap-to-effect ~1.0–1.3 s. | ~50–150 ms. The guest is ~0.3 s behind; tap-to-effect ~0.4 s. | — |
| Cost per ~50 s fight | ≈200 stream writes + ≈200 rule `get()` reads + ≈200 guest reads + ~30 room writes ≈ **$0.0005** (≈$0.18/100k writes, $0.06/100k reads). The project is on Blaze, since Cloud Functions are deployed, so there is no daily quota cliff. | ~125 KB down ≈ **$0.0001** ($1/GB down); 200k concurrent connections on Blaze | — |
| Disconnects | No `onDisconnect`. Use beat staleness: the host stream's seq, plus a guest beat every 2 s on the room doc. | `onDisconnect()` presence plus `.info/connected` | — |
| Rules | Can check friendship (`exists(players/{x}/friends/{y})`, as `raceFriendAt` does at firestore.rules:595-599) | **Cannot read Firestore.** It trusts a copy of host and guest written at room creation; friendship is checked in the Firestore lobby. | — |
| Setup | One rules block; deployed manually by the user (`firebase deploy --only firestore:rules --project prod`) | Console instance, plugin (`firebase_database` 11.x for firebase_core 3.x), pods, `database.rules.json` + a firebase.json `database` entry, manual `--only database` deploy | — |
| Testable in-process | Yes, with FakeFirebaseFirestore | Would need a new mock dependency | — |

Put the transport behind one small interface (`BattleWire`: `sendPacket`,
`packets`, `sendInputs`, `inputs`, `beats`) so moving to RTDB later is contained.

---

## 3. Matchmaking and lobby

**Separate `battle_rooms`, not `ev:'battle'` inside `race_rooms`.**

- Reusing `race_rooms` would mean changing `isRaceRoomShape` and `isRaceSeat`
  (firestore.rules:558-592). Their `hasOnly` lists also guard live races, so a slip
  breaks those.
- The race lobby (race_lobby_screen.dart, 1450 lines) is built around six lanes and
  courses. A battle room is two players, two fours and an arena.
- What to reuse: `RaceRoomService`'s patterns. These are the invite listener
  (`where invited arrayContains me`, race_room_service.dart:89-110), the
  server-clock offset (`sit`, 311-336), the gun time (`start`, 267-281),
  `leave`/`decline`/`dismiss`, `_run` with its 20 s timeouts and error words, and
  `kRaceInviteLife`. Also reuse the `_InviteSheet` and the invite notice:
  generalize `RaceInvites` (race_invites.dart; mounted in main.dart:196) to merge
  battle invites ("Bo asks you to battle · Glass Orrery").

**Flow.**

1. **Entry points:**
   - a BATTLE button beside RACE on the friend's planet page (`_RaceButton`,
     friend_planet_screen.dart:692-770; gated on the Trials being found, like RACE);
   - WITH A FRIEND on the Emerald Cup in the Trials GEMS tab, which today is
     computer-only (race_lobby_screen.dart:292-296 skips battle cups);
   - WITH A FRIEND in the battle hub, which is still under DEBUG TOOLS.
2. **Room contents:**
   - host, guest and `players` [host, guest], plus names;
   - `arena`: the **host's** `chosenBattleArena`. Looks only; the guest sees it
     even if they don't own it, since all floor art is in code (`battleFloorFor`);
   - `state` lobby | fighting, `run`, `seats`, `ready`, `inputs`, `result`,
     `startAt`, `createdAt`, `updatedAt`.
3. **Seats.** Each player's **saved four** (`loadBattleTeam`, battle_hub_screen.dart:48;
   `kBattleTeamKey` battle_screen.dart:47) as numbers worked out by the owner:
   - base, element, family, level, the 4 combat stats with constellation bonuses
     applied, the 4 potentials, name and `ResidentLook`;
   - plus `v` = `kBattleLinkVersion`;
   - Mystics refused at both ends (`battleAllows`, battle.dart:125).
   - **Both phones build both teams from the seats**, including their own, so the
     two sides are identical on both phones.
   - CHANGE uses `pickBattleTeam` and un-readies. Both fours are visible in the
     lobby, which is the team preview.
4. **Starting.** Guest READY, then host START: `startAt` = server now + 5 s, to
   load 8 sprite sheets. Both open `BattleScreen` at the gun. The host's fight
   starts on landing as today (`_maybeBegin`). The guest's playback starts with the
   first packet.
5. **Leads.** Phase 1: the first two of the saved order lead, as vs the computer.
   A secret lead pick is a later option (it was "my default, not confirmed").
6. **Rematch.** The result card's AGAIN becomes REMATCH and readies; BACK TO THE
   LOBBY returns both players. Same as races (`backToLobby`).

**Disconnects and forfeits.**

| Situation | What happens |
|---|---|
| Guest's beat silent > 6 s (app paused, network) | The host turns side 1 to `auto = true`: the computer picks focus and swaps. A strip says "Bo is away — their side fights on its own." It switches back when beats return, and **the result stands**. This fits an auto-battler, where specials and replacements are already automatic. |
| Host's stream silent | Guest: "Waiting for Bo…" after 3 s, then **no contest** after 30 s. The host's game loop stops while the app is backgrounded, so the fight just pauses and picks up if the host returns. |
| LEAVE mid-fight | Concede: the other player wins (a `ff` input from the guest, or an end event from the host). The existing LEAVE confirm says "Nothing is lost". |
| Version mismatch | The seat shows "NEEDS THE LATEST VERSION" and can't ready, as `kRaceRoomVersion` does. |

**Rewards.** **None paid**, as live friend races pay nothing ("A bout with friends
is for the bout: nothing is paid", race_lobby_screen.dart:570). Reasons: the host
decides the result, and two friends could farm. Keep a local head-to-head record
per friend (`battle_vs_<uid>` → "w,l,d"), show it in the lobby ("You 3 – 2 Bo"),
and later on the friend page. Leave the hub's vs-computer `battle_record_v1` alone.
**Ask the user.**

---

## 4. Recommendation and build plan

### Architecture

```
HOST phone                                        GUEST phone
BattleScreen(live: host)                          BattleScreen(live: guest)
 CosmicGame.startBattle(home: hostTeam,            CosmicGame.startBattle(home: guestTeam,
   away: guestTeam, awayAuto: false)                 away: hostTeam, replica: true)
 _updateBattle (real fight, unchanged)             _updateBattle → _updateReplica:
 BattleTape: 10 Hz samples + b.log events            apply due events (cast w/ seed, summon,
   (+ special origin/angle/target/seed)              swap, fall, phoenix, end) in side turns;
 BattleRemote: apply guest inputs →                  set pos/HP/shield/cd from playback;
   focusBattleTarget(1,…)/battleSummon(1,…)          local basics/projectiles/VFX only
   away → side1.auto                               BattlePlayback: jitter buffer, mirror
        │  stream ring (4 pkt/s) ───────────────────────▶│
        │◀──────────────── inputs list + beat (room doc) │
             Firestore battle_rooms/{id} (+ /stream/{0..7})
```

### Phase 1 (shippable)

New files:

- `lib/games/cosmic/battle_wire.dart` (pure Dart, ~350 lines)
  - `BattleSnapshot` and `BattleWireEvent` with compact int-list encoding;
  - `BattleTape` (host sampler and packer);
  - `BattlePlayback` (guest jitter buffer: interpolation, events due by t,
    starvation state);
  - `mirror()`;
  - `BattleSeatTeam` (four members as numbers + looks ⇄ `CosmicPartyMember`,
    using `visualsFromInstance`/`ResidentLook` as `seatMember` does in
    race_bodies.dart:310).
- `lib/games/cosmic/cosmic_game_battle_live.dart` (new `part`, ~400 lines)
  - host side: `recordBattleCast`, `applyRemoteBattleInput`, `setBattleSideAway`;
  - guest side: `_updateReplica`, `_replayCast`, `_applyReplicaSnapshot`.
- `lib/models/battle_room.dart` (~250 lines): `BattleRoom`/`BattleSeat` fromJson/toJson,
  `canStart`, `isReady`, version.
- `lib/services/battle_room_service.dart` (~400 lines, provider `lazy:false` next to
  RaceRoomService in app_providers.dart:269)
  - host, invite, sit, setReady, start, leave, decline, finish;
  - stream ring writer and listener;
  - `sendInputs`, beat;
  - server-clock offset.
- `lib/screens/battle/battle_lobby_screen.dart` (~600 lines, portrait): YOU and
  FRIEND cases with both fours, the arena name, status line, LEAVE | READY/START,
  CHANGE, INVITE.

Small changes:

- `cosmic_game_battle.dart`
  - `CosmicBattle.replica`, plus a branch at the top of `_updateBattle`;
  - skip the auto-special at 839 when replica;
  - skip `_battleSteer` (799) and the HP in `_settleBattleBodies` (930-949) when replica;
  - a `BattleEvent` payload (origin, angle, target, seed);
  - per-cast seed drawn from a battle-seeded rng.
- `cosmic_game_combat_actions.dart:88` (`_castCompanionSpecial`): take a cast `Random`.
- `cosmic_data.dart`
  - `createCosmicSpecialAbility(…, Random? rng)` threaded to 7326 (Dust Mane) and
    9756 (Mask);
  - and `cosmic_game_mane.dart:76` (Lightning orbs) uses the cast rng.
- `cosmic_game_mask.dart:27-31` and `cosmic_game_mane.dart:72-75`: fixed radii
  while `_battle != null`. This also removes the screen-size effect vs the computer.
- `battle_screen.dart`
  - an optional `live` link: `_tapField`/`_tapFloor`/`_tapBench` (386-440) call the
    link on the guest, with pending UI and the focus pool shown at once;
  - the friend's name in the top strip;
  - waiting/away overlays;
  - result buttons REMATCH / BACK TO THE LOBBY;
  - `onFinished` → head-to-head record.
- `race_invites.dart`: merge battle invites. `friend_planet_screen.dart`: BATTLE
  button. `stadium_screen.dart` (Emerald Cup) and `battle_hub_screen.dart`: WITH A
  FRIEND.

**Rules** (`firestore.rules`, deployed manually; hand the command to the user):

- `match /battle_rooms/{id}`:
  - get/list for `players`;
  - create by host only, with `state == 'lobby'`, `run == 0`, no seats,
    `createdAt == request.time`, and the guest a friend
    (`exists(/players/$(guest)/friends/$(host))`);
  - guest update limited to their own `seats`/`ready`/`inputs`/`left` entries
    (`onlyMine` style). The seat may change only in the lobby; inputs only while
    fighting, for the current `run`, with ≤ 60 entries;
  - host update limited to `state`, `run`, `startAt`, `arena`, `result`, their own
    seat, and clearing `inputs`/`ready`;
  - `isBattleRoomShape` with `hasOnly(...)` and size checks; `isBattleSeat`
    (team list ≤ 4, player ≤ 40, `at == request.time`);
  - delete by host.
- `match /battle_rooms/{id}/stream/{slot}`:
  - read for `players`;
  - write only by the room's host, while `state == 'fighting'`, `slot` in `'0'..'7'`,
    keys `hasOnly(['run','seq','s','e'])`, `run` = the room's run, list sizes
    bounded.
  - Each write does one `get()` of the room.
- The host deletes the 8 stream docs when it closes the room.
- Rules test: `functions/test/battle_rooms_rules.test.cjs`. It can't run until an
  emulator jar and Java are available, the same as the race rules test.

**Tests** (keep runs serial; this is CPU-heavy):

- `test/battle_live_test.dart` — **two phones in one process**, like
  gem_live_test.dart's `_twoPhones`:
  - A host `CosmicGame` and a guest replica `CosmicGame`, built as in
    battle_test.dart `battleArena()` but on the screen's `seed: 5` world.
  - A fake wire with latency, jitter and drop. The host steps at 1/60; the guest at
    jittered dt (1/50–1/120), to prove the replica doesn't need equal frame rates.
  - Scripted inputs: guest focus at 4 s and a swap at 12 s; host focus at 6 s.
  - **Assert:**
    - every host event reaches the guest, mirrored, in order;
    - at sampled times the guest's field creatures are within ~2 px of the mirrored
      host positions and have **exactly** the host's HP and shield;
    - the guest's swap lands on the host within latency + 1 frame and is echoed back;
    - the result is the same on both;
    - with 20% of packets dropped it still converges, because snapshots are absolute;
    - host silent 5 s gives guest "waiting" then resume; 35 s gives no contest;
    - guest beat stale 7 s turns host side 1 auto, then back;
    - the guest's view has its own team on side 0.
- `test/battle_room_test.dart`: two `BattleRoomService`s with two uids on **one
  `FakeFirebaseFirestore`**. Covers host/invite/sit/ready/start, the stream ring
  (seq order, 8-slot wrap), inputs whole-list, leave/decline, and version gating.
- `test/battle_wire_test.dart`: encode/decode round trip, mirror twice = identity,
  interpolation, event de-duplication across ring wrap.
- Re-run the existing `battle_test.dart`, `battle_harness_test.dart` and the duel
  and parity tests to show the vs-computer fight is unchanged when no link is set.
- Preview: `BATTLE_LOBBY_OUT=dir` frames, like race_lobby_test's `LOBBY_OUT`.

**Effort:** about 5–7 agent-days (~2.5–3k lines including ~600 of tests), then one
two-phone session with the user. Ideally that is an iPhone and the Fold, with a
friend race tried in the same session, since that has never been played on two
phones either.

### Phase 2 (only if needed after playing)

- RTDB transport behind `BattleWire`: about 1.5 days, plus console setup and a
  rules deploy by the user. `onDisconnect` gives faster away/no-contest detection.
- Secret lead pick; head-to-head on the friend page; emotes/reactions if wanted.

### Phase 3 (cheap extras this design makes possible)

- **Replays:** keep the host's packet tape (~125 KB) and play it into a replica.
- Spectators: a second guest replica, read-only.

### Risks

1. **Replica looks diverge at the edges.**
   - A local basic or shot can hit on the guest where the host's missed, or the
     reverse. Only sparks are affected.
   - Kill-triggered extras on the guest (Wing Steam clouds, Plant flowers) can
     differ.
   - HP, positions, falls and results are always the host's.
2. **Firestore lag** (~1 s for the guest) may feel sluggish. It is softened by the
   0.8 s arrival time and automatic replacements; RTDB is the fix (phase 2).
3. **The host is the authority.** The host has zero input delay (a small edge in an
   auto-battler) and could cheat. Acceptable for friends with nothing paid.
4. **Concurrent edits to the battle code** (the damage breakdown is in flight now).
   Rebase and merge carefully; the replica hooks sit in the same functions.
5. **Mirroring has to cover every coordinate** in events: origin, target and angle
   (+π). Covered by the mirror and two-phone tests.
6. **Two-game test coupling** through globals or statics, such as
   `maneLavaPoolCrowd` (render-only) and `CosmicBattle.debugUnknown` (in-flight).
   Watch for others.
7. **Version skew** between phones: gate on `kBattleLinkVersion`. Balance is the
   host's anyway.
8. **Rules are a manual deploy**, and the auto-mode classifier blocks prod deploys
   from here (memory). The feature is dead until the user runs the deploy.
9. **Backgrounding:** a host switching apps pauses everyone. It is surfaced as
   "Waiting for Bo…".
10. **Web:** this needs no determinism, so it should work on the web build (the
    Firestore web SDK is present), but it is untested.

---

## 5. Questions for the user before building

1. Rewards: nothing paid, plus a head-to-head record with that friend? (Recommended.)
2. If a friend drops mid-fight, their side fighting on by itself and the result
   standing? (Recommended.) Or call it no contest?
3. Leads: first two of the saved four (phase 1), or a secret lead pick before the
   gun?
4. Entry points: friend page BATTLE plus Emerald Cup WITH A FRIEND (the battle hub
   is debug-only today)?
5. Accept about 1 s of guest delay on Firestore for phase 1, with RTDB only if it
   feels slow? Or go straight to RTDB, which needs them to create the database in
   the Firebase console?
