# Wild Alchemons in cosmic space

Built 2026-09-28. Not yet played on a device.

## Why

The wilderness is the pretty lie; cosmic space is what is under it (see [campaign canon](campaign_story_canon.md)). Real Alchemons drifting in the dark are that idea made playable. They sit alongside the wilderness rather than replacing it: the timed wilderness spawns stay for good.

## Decisions (from the creator)

- **Look:** the creatures are not reskinned. They use the same sprites and genetics as owned ones. What makes them feel real is staging: small, alone, lit only by their own element's glow, drifting.
- **Ram to encounter:** the ship touching a creature pauses space, tears a portal, and opens the normal Harvest / Fuse encounter.
- **Encounter backdrop:** a new space backdrop, not a wilderness scene. If the ship was beside a planet, the **home planet included**, that planet sits in the frame on the side it really is on.
- **One attempt:** a failed harvest, a failed fusion, or a successful fusion leaves the creature **gone for good**. Harvest success obviously does too. Leaving without trying keeps it in space.
- **Potentials:** with the Wild Potential Scanner (`breeder_wild_potential_analyzer`) unlocked, the four Potentials float over each creature in space. They are rolled once at spawn and are exactly what the encounter shows and passes on.
- **Combat:** they can be fought, and they fight back.
- **Battle Ring removed.** Its duel machinery became the wild-creature fight.

## How it plays

| Situation | What happens |
|---|---|
| Arrival | Each planet has a **territory** 3,000 units out (`kPlanetTerritoryRadius`). Inside: up to 3 at a time, one every 20 s, 80% the planet's element and 20% strays of any discovered element. In the deep space between territories: up to 1, one every 45 s, any discovered element. Rarity and level are the same everywhere (creator's call). Spawned just off-screen; Mystics never wander. Territories show as a faint element wash with drifting motes, and are shaded on both maps. |
| Drifting | Slow drift tethered to where it arrived. Name plate within 480 units; Potentials above it if the scanner is unlocked. |
| Fight | Starts on its own, with no prompt or captions (the creator wanted space to feel live): any creature turns on a summoned companion that comes within 200, and **Horn and Mane** (territorial) turn on the ship within 250. With nothing summoned you can drift up and ram in peace. It fights the summoned companion, or the ship when none is out, with its own family abilities. Ship shots hit only the creature being fought, so a stray shot never starts a fight. |
| Beaten | At 0 HP it is **exhausted**, not dead: it slumps and drifts for 30 s, then recovers and leaves. |
| Flying off | Past 1,400 units the fight ends; the creature keeps its damage. |
| Ship destroyed | The creature leaves. |
| Ram | Opens the portal from any state, including mid-fight. Harvest bonus: +25% × damage taken, or **+30% when exhausted**. |

**Family odds** (creator-set, `_wildFamilyOdds`): Kin 1%, Wing 2%, Horn 5%, Mask 5%, Mane 25%, Pip 25%, Let 37%. The family is rolled first, then that family's species in the area's element.

Level is `rollSpaceLevel(guardians) × 2` (2 early, up to 10 late). Stats are the specimen's real stats, so high Potential means a harder fight.

## The transition (one continuous shot)

1. **In space, 0.95 s.** Time slows almost to a stop. The camera leans in on the creature (×1.6) and a white-hot slit opens *behind* it, so it hangs silhouetted. Light streams inward, then darkness opens inside the slit and widens until it swallows the screen. The HUD steps out for the shot, and the planet slides out of frame on its real side.
2. **Hand-off.** The encounter route opens with no fade on the same dark, so the turn to landscape happens unseen (held about 0.3 s).
3. **The encounter, 1.8 s timeline.** The same lens opens from a slit. The starfield settles from 1.22× scale, the planet rises in from further off the frame on the side it left by, and the creature steps out (scale and fade). The HUD arrives halfway through.
4. **Back in space.** The tear closes over 0.55 s as time and the camera ease back.

Both halves are drawn by `lib/games/cosmic/portal_tear_paint.dart` using filled lenses and gradient light only (no strokes, no blur). The preview test also writes `wild_tear_space.png` and `wild_tear_arrival.png` frame strips.

## Where it lives

- `lib/games/cosmic/cosmic_game_wild.dart`: creature state, drift, fight start/end, contact, rendering, and the backdrop snapshot (`captureEncounterBackdrop`, `renderPlanetBackdropImage`).
- `lib/screens/cosmic/wild_space_encounter_screen.dart`: the portal screen (`WildSpaceBackdrop` + `EncounterOverlay` in single-attempt mode).
- `lib/screens/cosmic/cosmic_screen.dart`: `_onWildSpawnWanted` (species pick + specimen roll), `_onWildContact`, the FIGHT prompt.
- `EncounterOverlay.singleAttempt` / `onSpecimenLost` / `harvestBonus`; `CatchService.attemptCatch(bonusChance:)`.
- Preview: `WILD_OUT=/tmp flutter test test/wild_space_encounter_preview_test.dart --tags preview`.

## Battle Ring removal notes

- `CosmicWorld.retiredArenaPosition` is still rolled and still counts as a landmark. The world is rebuilt from a saved seed on every load, so dropping it would move the Blood Ring, the contest arenas and every cache in existing saves.
- The old `cosmic_battle_ring_v1` pref is deleted on load.
- Contest cinematics still use the same opponent slot (`duelOpponent`); a contest is refused mid-fight.
- The ring's first-clear gold (about 22 gold total) no longer exists.

## Open

- Device playtest: readability at space zoom, ship-shot and ship-damage tuning (`_wildShipShotScale`, the `/45` in `_WildDuelTarget`), and spawn density.
- Whether fusing should require the Wild Fusion catalyst in space, as it does in the wilderness.
