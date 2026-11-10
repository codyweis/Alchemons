# Survival as a survival game: look audit, 2026-11-09

Read from the code and from headless frames of a full party at waves 3, 24
and 62 (`test/survival_field_preview_test.dart`, phone portrait, flying
zoom). No device was connected, and creature sprites do not load headless,
so the party is discs in those frames. Baseline cost on this Mac (JIT, not a
phone): wave 62, 1,035 bodies, every special cast: update 1.05 ms median /
2.63 p95, recording the frame's drawing 2.23 ms median / 4.42 p95
(`test/survival_late_wave_cost_test.dart`).

Ranked by how much better a run would feel.

## 1. The arena never changes (waves and pacing)
Wave 62's floor is wave 3's floor: a faint pool of the core's light and
stars. A thousand bodies have died on it and it shows nothing. The rim belt,
the only arena feature, is 1,140 units out and the view is about 690 × 1,540,
so it is off screen for most of a run. Nothing marks how deep the run is.

## 2. A wave has no arrival and no end (waves and pacing)
The wave turns over in one frame (`update`: intermission, cleanup, next wave)
at 90% killed. Each wave rolls a bearing and two to four fronts with an
escape gap, but nothing shows it until bodies walk into view. A hard wave
ending and an easy one ending look the same: nothing happens. A boss wave
changes nothing in the arena either.

## 3. A crowd is separate dots (enemies)
Late fronts are several hundred bodies in one wave element, drawn as lit
points on black with nothing under them. They do not read as one mass with a
leading edge; the eye counts dots. Nothing shows where a front has been.

## 4. A creature's readiness is not on its body (abilities)
Every companion stands on the same pool of light whether its special is
spent or ready. The only readout is the party case in the HUD.

## 5. Growth does not show (abilities)
A level 1 creature with no mastery and a level 10 one on a finished path
cast the same picture. Nothing a strong creature does stays on the field
longer than a weak one's.

## 6. Bosses borrow UI (enemies)
The six boss bodies are the best art in the mode, but what surrounds them is
stroked: the entrance portal arcs, the venting hoop with six dots, the
shield band, a red-to-orange health bar. Elites differ from chaff by a pool
of affix colour only.

## 7. A hit sheds nothing (enemies)
A struck body flashes. Heavies do not lose material or show weight.

## 8. Endless stops looking new at wave 50
Body counts climb to wave 100; the picture does not.

## 9. Combined abilities do not show
A blessed Horn's charge is a plain charge.

## 10. Smaller
- A drone's wind-up is 0.35 s, under the half second asked for. Lengthening
  it changes how hard drones hit the party, so it is reported, not changed.
- Orb contact bursts at wave 62 are white puffs, brighter than anything
  else on the floor.
- Rim-vanish bug: see the end of the run notes.

## Order of work
1 and 2 together (one arena layer: wear, edge loss, drift from the wave's
bearing, the settle after a clear), then 3, 4, 5/9 through the same layer,
6, 7.

---

# What was built, same day

Five commits on master, nothing pushed. Headless frames only: no device, no
simulator, and the party is drawn as discs because sprites do not load in
tests.

| Item | Built | Where |
| --- | --- | --- |
| 1, 8 | The floor keeps ash and char where bodies fell, blasts landed, fronts stood and specials struck; it loses light and the rim goes dark with the wave number, and goes on doing so to wave 100 | `arena_wear.dart` |
| 2 | Ash rides the air from the wave's bearing, thicker and faster the fuller the field; a boss stills it and darkens the rim; a cleared wave swells the floor's light and eases the dark for six seconds, further after a wave that filled the field | `arena_wear.dart`, `spawner.waveBearing` |
| 3 | One soft bank of dust under each knot of three or more bodies, in the wave's light | `_paintCrowdMass` |
| 4 | Grains of the creature's material lie loose while its special is spent, draw in as it returns, ring its feet when ready; a cast throws them out | `cosmic/ready_bed_vfx.dart` |
| 5 | A grown creature (level and mastery nodes) stands on more grains, and its specials leave wider, longer-warm marks that are always kept; a weak one's are rationed | `_creaturePower`, `ArenaWear.strike` |
| 9 | Under a blessing: gilt among the grains at its feet and gilt in the ash its casts leave | same |
| 6 | Boss arrival is a dark floor with grains drawn in; venting is heat on the floor and embers streaming off. 176 lines of stroked hoops, spokes and discipline marks deleted | `cosmic_enemy_vfx.dart` |
| 7 | A struck brute, colossus or elite sheds a few of its own grains off the struck face, at most once a flash | `_damageEnemy` |

## Cost
`LATE_COST=1 flutter test test/survival_late_wave_cost_test.dart --tags preview`,
this Mac, JIT, full party, every special cast, 240 frames:

| | Bodies | Update median / p95 | Draw-record median / p95 |
| --- | --- | --- | --- |
| Wave 62 before | 1,035 | 1.05 / 2.63 ms | 2.23 / 4.42 ms |
| Wave 62 after | 1,035 | 0.78 / 1.66 ms | 2.11 / 3.12 ms |
| Wave 24 before | 344 | 0.56 / 1.20 ms | 1.59 / 4.02 ms |
| Wave 24 after | 344 | 0.57 / 2.10 ms | 1.59 / 3.54 ms |

The differences are inside run-to-run noise: the work adds nothing this
harness can measure. Body counts match to the body, so seeded runs play out
as before. Raster (GPU) time is not measured here. What the new layers hand
the GPU a frame: two gradient fills (floor light, dark), eight to twelve
textured quads and as many point Pictures for the floor, two point batches
of drift, one gradient fill per dense crowd cell, one fill and up to three
small point batches per creature.

## Not done, or not seen
- Not on a phone or simulator. Density, brightness and motion (the drift,
  the settle, the bed gathering) are unjudged; stills cannot show them.
- Real creature sprites over the bed of grains were not seen.
- The boss arrival was only caught at the edge of the harness camera.
- Wave lulls: no pause was added between waves. The settle is visual; the
  next wave still starts the frame the last one clears. A real gap would
  move the stat walls.
- Elites are still chaff with a pool of affix colour. Not touched.
- Family specials themselves (the seventeen pictures per family) were not
  redrawn. Growth and blessing show through what a cast leaves and what the
  creature stands on, not through the cast's own art.
- Open space does not draw the bed of grains or the wear; both are survival
  only. The boss changes are survival's boss draw only.
- A drone's 0.35 s wind-up is unchanged.
- The white clumps where bodies burst on the core (11-03 work) are the
  brightest thing on a late floor. Left for judgement with the rest of that
  pass.
- Audio untouched.
