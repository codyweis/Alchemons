# Alchemons sound asset brief

Suggested production targets, not measured requirements. Durations include the audible decay.

**How the sounds are made now (2026-10-04).** Every sound effect and ambience loop is rendered by `tool/material_sounds.py` from the family modules in `tool/sounds/` (extraction, fusion, harvest, rewards, interface, combat, cosmic, dungeon, elements); `tool/sounds/core.py` holds the shared voices and the levelling rule. Each cue is built from the material its moment is about (grains where the picture is grains; coins, stone, wood, wax, fire, water, ice, obsidian impacts elsewhere) and scored to what its screen does, with the timing constants named after the Dart they come from. No clean sine tones, sweeps, note runs, chimes, drum thumps or crash bursts. Levels are set by what a phone speaker plays (300 Hz–8 kHz RMS). Frequent cues have real variants (`_01`–`_03`, each its own render); loops are joined seamlessly.

Render: `python tool/material_sounds.py [sfx_name ...]` (NumPy + SciPy; `--list` shows every cue and its module, `--out DIR` renders elsewhere). Inspect what you cannot hear: `python tool/sound_inspect.py file.wav --png DIR`. The manifest (`assets/audio/sounds/sound_manifest.json`) records each cue's current description, level and source module, and is the place to read what a sound is now. The old tone-based generator and its preview were retired.

The tables below are the original production brief: the targets the first library was made against, kept for the uses and lengths they record. Where a row's description and the manifest disagree, the manifest describes the sound that ships.

## Direction and delivery

Cosmic alchemy: warm crystalline tones, soft electronic pulses, mysterious resonances, and tactile elemental impacts. Combat should feel punchy without becoming harsh. Avoid voices, music beds, and long silence in individual effects.

- Deliver short effects as WAV, ideally 48 kHz / 16-bit. Keep original high-quality masters if available. Mono is sufficient for most UI and combat effects; stereo suits spacious reveals and ambience.
- Put effects directly in `assets/audio/sounds/`, except the five existing cosmic cues, which belong in `assets/audio/sounds/cosmic/`. Their existing names are preserved below.
- Use lowercase snake_case. Tables specify exact filenames. If creating variations of a new repeated effect, use `_01`, `_02`, `_03` before `.wav` and configure those names when wiring playback. Keep the five existing cosmic names unchanged for their primary files.
- Make 3 variations of frequent attacks, impacts, pickups, and footsteps where budget allows. Variation is more valuable here than dozens of unique UI sounds.
- Start immediately, trim silence, avoid clipping, and give one-shots a natural tail. Match perceived loudness across related sounds rather than normalizing every sound equally loud.
- Loop files must have a seamless join and no baked-in fade-in/fade-out. Playback should handle fades.
- P1 = first playable sound pass. P2 = next pass. P3 = optional atmosphere/detail. Reuse shared sounds across modes.

## Shared controls and rewards

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_ui_tap.wav` | 0.05–0.12 s | Soft glass tick for ordinary buttons |
| P1 | `sfx_ui_confirm.wav` | 0.15–0.30 s | Clear two-tone acceptance |
| P1 | `sfx_ui_back.wav` | 0.10–0.25 s | Gentle downward tick |
| P2 | `sfx_ui_panel_open.wav` | 0.15–0.30 s | Airy page/panel sweep |
| P2 | `sfx_ui_panel_close.wav` | 0.12–0.25 s | Softer reverse sweep |
| P1 | `sfx_ui_denied.wav` | 0.20–0.40 s | Muted low double pulse; locked or unavailable |
| P2 | `sfx_ui_select.wav` | 0.08–0.18 s | Party/item selection tick |
| P1 | `sfx_reward_collect.wav` | 0.40–0.80 s | Small sparkling reward |
| P2 | `sfx_currency_gain.wav` | 0.20–0.50 s | Coins or silver in: a small bright pinch and a little high glass |
| P2 | `sfx_purchase_success.wav` | 0.40–0.80 s | Bought: a pinch into glass, settled |
| P2 | `sfx_upgrade_complete.wav` | 0.80–1.50 s | Upgraded: grains gather and a glass blooms |
| P2 | `sfx_achievement_unlock.wav` | 1.50–2.50 s | Claimed: a pour into two glasses, mostly gone before the reward flight lands |

Do not stack tap + confirm + purchase for the same action; choose the most meaningful cue.

## Cosmic exploration

The first five rows already have cue definitions and calls in the app. Their generated files are saved in the `cosmic/` subfolder. Portal opening uses the approved darker descending rumble rather than the original bright crystalline direction.

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_cosmic_portal_open.wav` | 1.50–2.50 s | Space folding inward, crystalline opening |
| P1 | `sfx_cosmic_orb_pickup.wav` | 0.12–0.25 s | Tiny bright liquid-glass plink |
| P1 | `sfx_cosmic_orb_deposit.wav` | 0.50–1.00 s | Gathered particles resolving into a warm chord |
| P1 | `sfx_cosmic_anomaly_burst.wav` | 0.70–1.30 s | Unstable magical rupture with a short tail |
| P1 | `sfx_cosmic_starforge_activate.wav` | 2.00–3.50 s | Ancient cosmic machine awakening |
| P2 | `sfx_cosmic_dash.wav` | 0.20–0.45 s | Fast airy energy streak |
| P2 | `sfx_cosmic_planet_enter.wav` | 1.00–2.00 s | Atmospheric descent sweep |
| P2 | `sfx_cosmic_cache_open.wav` | 0.80–1.50 s | Sealed crystal vessel releasing treasure |
| P2 | `sfx_cosmic_discovery.wav` | 1.00–2.00 s | Found in the cosmos: a wide shimmer gathering over a stroked glass |
| P3 | `sfx_cosmic_scan.wav` | 0.60–1.20 s | Soft sonar ripple with magical shimmer |

## Shared combat: survival, cosmic enemies, and dungeon guardians

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_combat_projectile.wav` | 0.10–0.25 s | Soft compact energy launch |
| P1 | `sfx_combat_hit_light.wav` | 0.10–0.25 s | Small crisp impact |
| P1 | `sfx_combat_hit_heavy.wav` | 0.25–0.50 s | Weightier impact with controlled bass |
| P1 | `sfx_combat_player_hurt.wav` | 0.25–0.50 s | Distinct dull impact and downward energy tone |
| P1 | `sfx_combat_enemy_defeat.wav` | 0.25–0.60 s | Quick dissolving energy puff |
| P2 | `sfx_combat_shield_hit.wav` | 0.15–0.35 s | Resonant glass deflection |
| P2 | `sfx_combat_shield_break.wav` | 0.40–0.80 s | Energy shell cracking apart |
| P2 | `sfx_combat_heal.wav` | 0.60–1.00 s | Warm rising restorative shimmer |
| P1 | `sfx_combat_danger.wav` | 0.30–0.60 s | Readable incoming attack warning |
| P1 | `sfx_combat_victory.wav` | 2.00–3.50 s | Won: grains swell in from wide, settle, two glasses bloom |
| P1 | `sfx_combat_defeat.wav` | 1.50–2.50 s | Lost: grains falling away and a muted glass |
| P1 | `sfx_combat_special_cast.wav` | 0.30–0.50 s | Quiet mechanism releasing; a special has gone off. Layers UNDER the element cue, which says which element it was — so it carries no colour of its own and no flourish |

### Alchemon auto-attacks, one per family

Every alchemon's basic attack is its FAMILY's, and the eight families throw
genuinely different things — twin slashes, three darts, one slow heavy shot.
One generic launch blip for all of them says nothing, which is what the whole
roster shared before. Each cue is shaped like the projectile it belongs to.

These are the most-repeated sounds in the game: a run fires thousands. They are
deliberately quieter than every impact they cause, short, and first to be
dropped when the mixer runs out of voices — the hit should be louder than the
shot. Three pitch variations each.

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_basic_mane.wav` | 0.10–0.25 s | Twin airy swipes, the second close behind the first |
| P1 | `sfx_basic_let.wav` | 0.15–0.30 s | One slow heavy lob with low body |
| P1 | `sfx_basic_pip.wav` | 0.10–0.22 s | Three tiny high ticks in quick succession |
| P1 | `sfx_basic_horn.wav` | 0.15–0.30 s | One low shove of air; weight without a bang |
| P1 | `sfx_basic_mask.wav` | 0.10–0.22 s | A thin focused zip that pierces rather than hits |
| P1 | `sfx_basic_wing.wav` | 0.10–0.22 s | Two soft high blips, light and fast |
| P1 | `sfx_basic_kin.wav` | 0.15–0.30 s | A small charge gathering, then letting go |
| P1 | `sfx_basic_mystic.wav` | 0.10–0.25 s | Three soft mid blips, gentler than a pip's darts |

Keep frequent launch/hit sounds understated. Throttle overlapping hits and pickups; prioritize player damage, danger warnings, and major events. Do not sound every projectile in a crowded wave.

## Survival-specific events

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_survival_wave_start.wav` | 0.60–1.00 s | Focused rising challenge pulse |
| P2 | `sfx_survival_wave_clear.wav` | 0.70–1.20 s | Brief resolved success pulse |
| P1 | `sfx_survival_boss_arrive.wav` | 1.50–2.50 s | Low ominous swell with a clear arrival hit |
| P1 | `sfx_survival_powerup_collect.wav` | 0.30–0.60 s | Bright energizing pop |
| P2 | `sfx_survival_powerup_choose.wav` | 0.50–0.90 s | Stronger confirmation for draft selection |
| P2 | `sfx_survival_outbreak.wav` | 1.00–1.80 s | Unstable alarm texture, distinct from boss cue |
| P2 | `sfx_survival_milestone.wav` | 1.50–2.50 s | Larger achievement flourish for major waves |

## Dungeon interactions

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_dungeon_interact.wav` | 0.20–0.40 s | Tactile magical activation |
| P1 | `sfx_dungeon_gate_open.wav` | 1.00–2.00 s | Ancient stone mechanism unlocking and moving |
| P2 | `sfx_dungeon_switch.wav` | 0.20–0.45 s | Weighted switch click |
| P1 | `sfx_dungeon_puzzle_solved.wav` | 1.00–1.80 s | Solved: a pour settling into place, two glasses |
| P1 | `sfx_dungeon_star_collect.wav` | 1.50–2.50 s | A star: a cluster of glints, then a clear glass |
| P2 | `sfx_dungeon_secret_reveal.wav` | 0.80–1.50 s | A secret opens: a stroked glass swelling up, fine grains glittering loose |
| P2 | `sfx_dungeon_wall_break.wav` | 0.50–1.00 s | Stone crack and falling rubble |
| P2 | `sfx_dungeon_block_move.wav` | 0.40–0.80 s | Short stone scrape for a discrete movement |
| P2 | `sfx_dungeon_hazard_trigger.wav` | 0.30–0.70 s | Mechanical/magical trap snap |
| P2 | `sfx_dungeon_checkpoint.wav` | 0.60–1.20 s | Banked: something set down, low and quiet |
| P2 | `sfx_dungeon_relic_collect.wav` | 1.50–2.50 s | A relic: a slow pour into a deep glass that rings long |
| P3 | `sfx_dungeon_step_stone.wav` | 0.08–0.18 s | Restrained stone footstep; make 4 variations |
| P3 | `sfx_dungeon_step_water.wav` | 0.10–0.25 s | Light shallow splash; make 4 variations |

Use UI denied for unmet gates, shared danger for guardian telegraphs, shared victory for guardian wins, and portal open for magical entrances where appropriate. Add checkpoint audio only where a matching gameplay event exists.

## Creatures, breeding, and everyday progression

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P2 | `sfx_creature_summon.wav` | 0.50–1.00 s | Friendly magical materialization |
| P1 | `sfx_capture_throw.wav` | 0.20–0.45 s | A harvester chosen: a pinch of grains into glass |
| P2 | `sfx_capture_attempt.wav` | 0.60–1.00 s | Rings of motes close on the specimen, bite, and strain as it shoves (on HarvestParticleField.beats engage) |
| P1 | `sfx_capture_success.wav` | 1.20–2.00 s | The specimen turned to grains and drawn down, turning, into the harvester, sealed with a small glass (on the take beat) |
| P2 | `sfx_capture_escape.wav` | 0.50–0.90 s | The field thrown apart with a breath of heat; the specimen shrugs it off (on the shatter beat) |
| P2 | `sfx_harvest_collect.wav` | 0.30–0.60 s | A chamber collected: the flask drains (1.1 s), its essence venting up out of the surface |
| P2 | `sfx_extraction_complete.wav` | 0.80–1.30 s | Collect all: every finished chamber lets go at once; the reward flights carry the landing |

## Alchemical extraction

The reveal animation depicts an alchemical extraction reaction, not a shell cracking. Use independently timed stages so the buildup, release, and specimen appearance can follow the animation. Trigger the rare reveal instead of the ordinary reveal, not on top of it. The separate extraction-complete UI chime should not stack with the reveal flourish.

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_extraction_creature_reveal.wav` | 2.00–2.50 s | Grains swirl home and settle with a soft weight; a low glass rings once |
| P2 | `sfx_extraction_rare_reveal.wav` | 3.00–3.50 s | A held, charged beat, then grains swirl home and settle into two glass bodies |
| P1 | `sfx_extraction_ceremony.wav` | 6.05 s | Two parents' grains gather into one shell, settle as it cinches (4.25 s), and ring it open as it unravels (5.24 s) |
| P1 | `sfx_fusion_merge.wav` | 3.15 s | The breed tab's merge: grains made, standing, poured over the gap, circling the orb, falling in to a bloom (2.5 s); measured from FusionParticleField |
| P1 | `sfx_fusion_eruption.wav` | 3.7 s | The fusion cinematic from the core: shivering knot, eruption (0.45 s), gather, the sigil's glinting lock (1.55–1.95 s) |
| P1 | `sfx_fusion_calibrate.wav` | 2.0 s | A wild fusion's catalyst spent: the merge's first 0.62 s, then glints while the verdict is out |
| P1 | `sfx_fusion_pour.wav` | 2.5 s | The verdict held: the merge from 0.62 s on, to the bloom |
| P1 | `sfx_fusion_recoil.wav` | 1.2 s | The verdict failed: grains run back up into the pair, which settle whole |
| P1 | `sfx_reward_flight.wav` | 1.6 s | Any reward flight (playRewardCollect): thrown out of its card, drawn in faster and faster, settled into its total at 0.98 s |

The extraction sounds are the ceremony (scored to the shell's per-strand motion) and the card's reveal (grains land at 1.20 s, or 1.77 s after a rare specimen's held beat); see `tool/sounds/extraction.py`. The prior egg-crack, egg-hatch and reaction prototypes are retired.

## Element identity pass

After the shared effects work, add these reusable accents for combat and dungeon abilities. These are P2/P3 additions; layer selectively or use in place of the generic cast. A separate cast and impact per element can come later.

| Filename | Length | Character |
|---|---|---|
| `sfx_element_fire.wav` | 0.40–0.80 s | Compact flame ignition and whoosh |
| `sfx_element_water.wav` | 0.40–0.80 s | Rounded splash and flowing droplets |
| `sfx_element_air.wav` | 0.30–0.60 s | Clean spiraling gust |
| `sfx_element_earth.wav` | 0.40–0.80 s | Dense stone thud and grit |
| `sfx_element_lightning.wav` | 0.20–0.50 s | Sharp electric snap with short buzz |
| `sfx_element_steam.wav` | 0.50–0.90 s | Pressurized vapor release |
| `sfx_element_lava.wav` | 0.50–1.00 s | Thick bubbling impact and low flame |
| `sfx_element_poison.wav` | 0.40–0.80 s | Acidic bubble pop and short hiss |
| `sfx_element_ice.wav` | 0.30–0.70 s | Brittle freeze crack and icy tinkle |
| `sfx_element_mud.wav` | 0.30–0.70 s | Heavy wet squelch |
| `sfx_element_dust.wav` | 0.40–0.80 s | Dry granular swirl |
| `sfx_element_crystal.wav` | 0.40–0.90 s | Clear faceted glass resonance |
| `sfx_element_plant.wav` | 0.40–0.80 s | Rapid vine growth and leaf rustle |
| `sfx_element_spirit.wav` | 0.60–1.20 s | Ethereal nonverbal spectral resonance |
| `sfx_element_dark.wav` | 0.50–1.00 s | Hollow inward pull and muted low pulse |
| `sfx_element_light.wav` | 0.50–1.00 s | Radiant bell-like burst |
| `sfx_element_blood.wav` | 0.40–0.80 s | Deep heartbeat and liquid energy pulse |

## Optional ambience and music

All ambience below is P3, stereo, and authored for seamless looping. Scene-aware playback is implemented for space, laboratories, and dungeons. These subtle textures leave space for existing music; audible loop/mix verification on the device remains outstanding.

| Filename | Loop length | Character |
|---|---|---|
| `amb_cosmic_space_loop.wav` | 30–60 s | Quiet deep-space resonance and distant particles |
| `amb_dungeon_ruins_loop.wav` | 30–60 s | Hollow air and occasional distant stone movement |
| `amb_dungeon_water_loop.wav` | 20–40 s | Underground flow and scattered drips |
| `amb_dungeon_fire_loop.wav` | 20–40 s | Restrained crackle and subterranean heat rumble |
| `amb_dungeon_arcane_loop.wav` | 30–60 s | Slow magical oscillations and crystal resonance |
| `amb_lab_loop.wav` | 20–40 s | Soft equipment hum and occasional alchemical bubbles |

Keep WAV ambience as production masters; choose compressed runtime exports after checking size and target-device playback. Existing music already covers home, survival, space exploration, boss battle, planets, portals, wilderness biomes, and credits. New music is lower priority than interaction sounds. If adding a dedicated dungeon exploration track, target 90–180 seconds with a clean loop; a boss track can target 60–120 seconds. Preserve existing music filenames unless updating their mappings.

## Later additions

Rows added after the first production pass.

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P2 | `sfx_cosmic_matter_collect.wav` | 0.15–0.30 s | Alchemical matter drawn into the meter — a soft intake, not a coin |

| Filename | Loop length | Character |
|---|---|---|
| `amb_cosmic_boost_loop.wav` | 30 s | The booster held down — a continuous thruster, not a repeated whoosh |

## Implementation notes from the current app

- `lib/providers/audio_provider.dart` defines five cosmic `SoundCue` values and their asset candidates; `lib/screens/cosmic/cosmic_screen.dart` calls them.
- `assets/audio/sounds/cosmic/` now contains the five mapped cosmic effects and three orb-pickup variations.
- The cosmic subfolder is explicitly registered in the Flutter asset manifest.
- All one-shot filenames above now have cue mappings. Connected gameplay/UI hooks are listed in `docs/audio_integration.md`; unused cues remain available for later events.
- Playback now reuses completed players, caps concurrent sounds at six, and applies per-cue gain, variation selection, cooldowns, and priority. First-use latency still needs an audible device check.
- Ambient loops now use their own lifecycle-managed player, with scene fades, route ownership, and muting/background behavior consistent with the SFX settings.
- Generated files passed numerical checks for PCM format, clipping, DC offset, one-shot endpoints, loop boundary steps, and unchanged approved samples. Runtime scheduling, asset bundling, scan callbacks, and selected gameplay regressions also passed automated tests. These checks do not replace listening review. Verify real-device latency, overlapping effects, background/resume behavior, and music/SFX balance.
