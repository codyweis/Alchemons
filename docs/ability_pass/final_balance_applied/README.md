# Final balance pass — APPLIED (2026-10-10)

**Status: applied to `lib/` on 2026-10-10 and re-measured (all 136).** The final numbers are in `../README.md`, "Final results". The text below the "Applied" section is the validation record as it was written before the changes went in.

## Applied
- The eight validated changes went in with `tools/apply.py` and the edit modules `mystic.py`, `mask_spirit.py`, `kin_spirit.py`, `mane_horn_trim.py` and `let_wing.py` (main mode). `edits/final_values.json` holds the values used.
  - `let_wing.py` is the main-tree form of changes 6-8 (they existed only as knobs in `levers_exp.py`). The Wing co-beam rule is one shared rule: a beam co-fired from an anchor (Earth's orb beam and Spirit's ship beam) holds half the wing's own (`WingBeamRules.coBeamLife`), in survival and open space.
  - Mane Fire's count edit in `mane_horn_trim.py` is skipped unless `final_values.json` names `mane.fire.perfect`; Fire was settled by hand instead (below).
  - Mystic Poison: `final_values.json` has the validated tick-with-tempo setting (`m.poison.texp`), but the Poison world was then changed by hand (below), so re-running `mystic.py` reports that edit as failed. `m.earth.beat` is 33 (validated at 31; moved below).
- Then edited by hand (exact replacements), each measured in an experiment tree first:
  - **Mane Plant:** recharges in the 1.13 element tier (was 0.91); a rooted kill blows up 70 px (was 165), read from `ManeRuntime.plantRootExplodeRadius` by survival, open space and dungeons; the vine's growth caps at 9 / 7.5 (was 18 / 15).
  - **Mane Dark:** the void bolt's pull reaches 80 (was 180).
  - **Mane Fire:** 4 / 5 / 6 fireballs (was 4 / 8 / 16), and recharges in the 1.13 tier (was 0.77).
  - **Wing Dark:** half the execution seekers, living 1.6 s (was 2.8). Measured: the homing, piercing seekers were the whole standout; the lances, the beam and its pulse barely moved it.
  - **Wing Spirit:** the reaping spirits live 2.0 s (was 3.6).
  - **Mask Steam:** turret shots 0.5 of SPECIAL (was 0.75).
  - **Mystic Poison:** patches spread `22 x tempo^1.5` (was a flat 30), live `x tempo`, and the wake holds `26 x tempo` patches; the bite still quickens with tempo.
  - **Mystic Earth:** quake beat 33 s at P50 (was 31). The 45 s window holds three or four quakes at P100E10 depending on when the cast lands, so this world reads in steps.
  - **Let Steam:** the kill vent lasts 9 s (was 12).
  - **Horn Dark (dungeon parity):** dungeons drag from `hornDarkAuraRadius(Beauty)` and capture with `hornDarkCaptureRadius(Beauty)`, like survival and open space (was a fixed 200).
- Not changed (measured just under the line after the rest): Mane Crystal, Mane Earth, Horn Lava. Mystic Water stays the support exception.
- Tests: `test/ability_final_balance_test.dart` (new), the M2 group of `ability_family_rules_test` (tempo, beats, Poison wake), `mystic_worlds_test` clock tests on `mysticWorldBeat(slot)`, the Mask Spirit bank tests in `mask_ability_runtime_test`, a co-beam test in `cosmic_wing_parity_test`, a Horn Dark test in `dungeon_ability_parity_test`, and the Mane Fire count in `survival_mastery_mane_test`.

---

## Changes and measured results
Each result is share of the all-136 median, in the 45 s main pass, P50 / P70 / P90 / P100E10.

1. **Mystic worlds** (`mystic.py`). A new `mysticWorldTempo` is 1 at P50 and ×2.43 at P100E10. It drives each damage world's beat, rate or reach. Tests to update to the new `mysticWorldBeat(slot)` getter: `mystic_worlds_test` (clock tests) and the M2 group of `ability_family_rules_test`.

   | World | Before | After |
   | --- | --- | --- |
   | Air | 3.7 → 1.9 | 2.5 / 2.6 / 2.3 / 2.5 |
   | Plant | 5.3 → 2.5 | 2.8 / 2.4 / 2.3 / 2.3 |
   | Fire | 1.7 → 1.1 | 2.1 / 2.0 / 1.9 / 1.8 |
   | Lightning | 0.29 → 0.07 | 2.0 / 1.9 / 1.7 / 1.7 |
   | Spirit | 2.1 → 0.7 | 2.1 / 1.9 / 2.0 / 2.6 |
   | Earth | 4.6 → 2.4 | 2.4 / 1.9 / 2.7 / 3.5 |
   | Lava (held boss) | 0.5 → 1.9 | 0.5 / 1.3 / 3.0 / 3.3 |

   The values behind those results:

   | World | Value |
   | --- | --- |
   | Lightning | beat 2.2 s, splash 120 |
   | Earth | beat 31 s |
   | Plant | lash 2.1, thorn 1.7 |
   | Air | travel speed 0.22 |
   | Fire | reignite 0.65 |
   | Spirit | strike 0.45; the host grows with tempo |
   | Lava | fissure rearm 4.0 ÷ tempo |

   Still open:
   - Poison stays early (3.6 → 1.5).
   - Water is 3.0–4.2, but it's a support, so leave it as an exception.

2. **Mask Spirit** (`mask_spirit.py`). The clear threshold is 1.5 casts' worth of wisps, banked across casts. Result: 3.5 / 3.1 / 2.8 / 2.7 (was 6.1 / 6.0 / 5.1 / 6.1), with a mild ramp. Update the six-wisp tests in `mask_ability_runtime_test`.

3. **Kin Spirit** (`kin_spirit.py`). The wisp survives contact, Tier 3 shoots (0.5 of SPECIAL, with its rate riding SPECIAL), and Tier 4 heals on kills. Placed-turret shots are credited to their caster, which also lifts Mask Steam to about 2.0. Result: 2.0 / 1.7 / 1.6 / 1.7 (was 0 everywhere). The turret fields on `Projectile` become non-final.

4. **Mane Lightning** (`mane_horn_trim.py`). The orb count follows the Beauty-scaled lane count, held to 5–10. P100E10 goes 1.18 → 1.46.

5. **Horn Dust/Dark** (`mane_horn_trim.py`). Taunt+pull zones keep their authored reach and the old 110 burst cap. Dust protect 0.21 → 0.31 and control 938 → 1216 body-seconds at P100E10; Dark is neutral.

6. **Let Fire.** The kill blast reaches 2× the meteor's blast radius, and the 555 px floor is dropped. Result: 1.9 / 2.1 / 2.2 / 2.4 (was 6.5 / 5.7 / 5.2 / 5.2).

7. **Let Dark.** Follow-ups use the anchored count curve (2 / 3 / 5) and are 1.4× the size. Result: 2.0 / 1.9 / 2.4 / 3.1 (was 3.4 / 3.1 / 3.5 / 4.5).

8. **Wing Earth.** The orb co-beam lasts half as long. Result: 3.1 / 3.0 / 2.5 / 2.2.

## Finding: trimming damage doesn't help
`kSpecialBalanceTrim` barely moves the standouts, because their hits already kill what they reach. Let Fire ×0.5 only went from 6.5 to 5.9. The levers that work are reach, count and rate.

## Not done
- **Still above 3.3×:**
  - Mane Plant, about 5. Its vine growth per pierce is the next lever.
  - Mane Dark, 3.7.
  - Mane Fire, 3.5–3.9.
  - Wing Dark, 4.7–5.5.
  - Wing Spirit, about 3.9.
- **Mask Steam's turret share** was never set. The pass was leaning to 0.5: boss share was 7–13, and 5.7–9.7 at 0.4.
- **Just over the line:** Mane Crystal, Mane Earth, Horn Lava and Let Steam each sit 0.1–0.3 over the line at one band.
- **Axis fixes for `profiles.csv`:** judge Mask Dark on control, and treat Mask Light's single execute as a design question.
- **Not started:** regression tests, the full 136 re-measure, the aggregate, and the README "Final results".

The baseline measurements (all 136 on the current tree) stayed in the session scratchpad (`fb/m0`), which may be gone by now. Re-measure if needed.
