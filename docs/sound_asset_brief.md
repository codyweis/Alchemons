# Alchemons sound asset brief

Suggested production targets, not measured requirements. Durations include the audible decay.

Production status: all 89 core sounds have been synthesized as WAV prototypes, including six 30-second stereo ambience loops. There are also 21 additional variations across projectiles, light/heavy hits, enemy defeat, orb pickup, and stone/water footsteps. The ten samples approved during review were preserved byte-for-byte. The extraction sequence now uses an alchemical reaction and specimen scanning rather than egg cracking/hatching. The first runtime pass is implemented; see [integration coverage](audio_integration.md) for connected events, remaining hooks, and device-validation limits.

Preview: `build/audio_review/index.html` (searchable by name and category). Exact durations, paths, levels, and variant filenames: `assets/audio/sounds/sound_manifest.json`. Regenerate the remaining library and full preview with `tool/generate_sound_library.py` using Python with NumPy installed. The earlier `tool/generate_ui_sound_samples.py` recreates the first ten samples and its smaller preview; run the full-library generator afterward to restore the complete preview.

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
| P2 | `sfx_currency_gain.wav` | 0.20–0.50 s | Brief coin/crystal scatter |
| P2 | `sfx_purchase_success.wav` | 0.40–0.80 s | Satisfying transactional chime |
| P2 | `sfx_upgrade_complete.wav` | 0.80–1.50 s | Rising energy and resolved tone |
| P2 | `sfx_achievement_unlock.wav` | 1.50–2.50 s | Distinct celebratory flourish |

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
| P2 | `sfx_cosmic_discovery.wav` | 1.00–2.00 s | Curious ascending constellation tones |
| P3 | `sfx_cosmic_scan.wav` | 0.60–1.20 s | Soft sonar ripple with magical shimmer |

## Shared combat: survival, cosmic enemies, and dungeon guardians

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_combat_projectile.wav` | 0.10–0.25 s | Soft compact energy launch |
| P1 | `sfx_combat_hit_light.wav` | 0.10–0.25 s | Small crisp impact |
| P1 | `sfx_combat_hit_heavy.wav` | 0.25–0.50 s | Weightier impact with controlled bass |
| P2 | `sfx_combat_critical.wav` | 0.25–0.55 s | Sharper sparkling impact; replaces normal hit |
| P1 | `sfx_combat_player_hurt.wav` | 0.25–0.50 s | Distinct dull impact and downward energy tone |
| P1 | `sfx_combat_enemy_defeat.wav` | 0.25–0.60 s | Quick dissolving energy puff |
| P2 | `sfx_combat_shield_hit.wav` | 0.15–0.35 s | Resonant glass deflection |
| P2 | `sfx_combat_shield_break.wav` | 0.40–0.80 s | Energy shell cracking apart |
| P2 | `sfx_combat_heal.wav` | 0.60–1.00 s | Warm rising restorative shimmer |
| P1 | `sfx_combat_danger.wav` | 0.30–0.60 s | Readable incoming attack warning |
| P1 | `sfx_combat_victory.wav` | 2.00–3.50 s | Short triumphant cosmic flourish |
| P1 | `sfx_combat_defeat.wav` | 1.50–2.50 s | Gentle descending unresolved chord |

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
| P1 | `sfx_dungeon_puzzle_solved.wav` | 1.00–1.80 s | Recognizable ascending discovery phrase |
| P1 | `sfx_dungeon_star_collect.wav` | 1.50–2.50 s | Bright memorable star reward flourish |
| P2 | `sfx_dungeon_secret_reveal.wav` | 0.80–1.50 s | Quiet unveiling with a sparkling finish |
| P2 | `sfx_dungeon_wall_break.wav` | 0.50–1.00 s | Stone crack and falling rubble |
| P2 | `sfx_dungeon_block_move.wav` | 0.40–0.80 s | Short stone scrape for a discrete movement |
| P2 | `sfx_dungeon_hazard_trigger.wav` | 0.30–0.70 s | Mechanical/magical trap snap |
| P2 | `sfx_dungeon_checkpoint.wav` | 0.60–1.20 s | Reassuring resonance for a bank/save event |
| P2 | `sfx_dungeon_relic_collect.wav` | 1.50–2.50 s | Deep ancient chime with bright overtones |
| P3 | `sfx_dungeon_step_stone.wav` | 0.08–0.18 s | Restrained stone footstep; make 4 variations |
| P3 | `sfx_dungeon_step_water.wav` | 0.10–0.25 s | Light shallow splash; make 4 variations |

Use UI denied for unmet gates, shared danger for guardian telegraphs, shared victory for guardian wins, and portal open for magical entrances where appropriate. Add checkpoint audio only where a matching gameplay event exists.

## Creatures, breeding, and everyday progression

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P2 | `sfx_creature_summon.wav` | 0.50–1.00 s | Friendly magical materialization |
| P1 | `sfx_capture_throw.wav` | 0.20–0.45 s | Swift arc and soft energy release |
| P2 | `sfx_capture_attempt.wav` | 0.60–1.00 s | One containment pulse; repeat in code if needed |
| P1 | `sfx_capture_success.wav` | 1.20–2.00 s | Secure click resolving into cheerful sparkle |
| P2 | `sfx_capture_escape.wav` | 0.50–0.90 s | Containment breaking with an airy release |
| P2 | `sfx_breeding_start.wav` | 0.80–1.50 s | Two tones blending into a pulsing shimmer |
| P2 | `sfx_harvest_collect.wav` | 0.30–0.60 s | Organic pluck and tiny sparkle |
| P2 | `sfx_extraction_complete.wav` | 0.80–1.30 s | Machine settling and a clean success chime |

## Alchemical extraction

The reveal animation depicts an alchemical extraction reaction, not a shell cracking. Use independently timed stages so the buildup, release, and specimen appearance can follow the animation. Trigger the rare reveal instead of the ordinary reveal, not on top of it. The separate extraction-complete UI chime should not stack with the reveal flourish.

| Priority | Filename | Length | Sound / use |
|---|---|---|---|
| P1 | `sfx_extraction_reaction_start.wav` | 1.20–2.00 s | Accelerating liquid bubbles and rising reactive energy |
| P1 | `sfx_extraction_reaction_burst.wav` | 0.50–1.00 s | Pressurized vapor and a rounded magical release |
| P1 | `sfx_extraction_creature_reveal.wav` | 1.50–2.50 s | Scanner sweeps and short data ticks resolve into a specimen identification tone |
| P2 | `sfx_extraction_rare_reveal.wav` | 2.00–3.50 s | Extended specimen scan and data readout with an extra rare-identification ping |

The prior egg-crack, egg-hatch, and creature-rare-reveal prototypes are retired from the active library. Their backups are in `build/audio_review/retired/`. Regenerate just these four cues with `tool/generate_sound_library.py --only-extraction`.

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

## Implementation notes from the current app

- `lib/providers/audio_provider.dart` defines five cosmic `SoundCue` values and their asset candidates; `lib/screens/cosmic/cosmic_screen.dart` calls them.
- `assets/audio/sounds/cosmic/` now contains the five mapped cosmic effects and three orb-pickup variations.
- The cosmic subfolder is explicitly registered in the Flutter asset manifest.
- All one-shot filenames above now have cue mappings. Connected gameplay/UI hooks are listed in `docs/audio_integration.md`; unused cues remain available for later events.
- Playback now reuses completed players, caps concurrent sounds at six, and applies per-cue gain, variation selection, cooldowns, and priority. First-use latency still needs an audible device check.
- Ambient loops now use their own lifecycle-managed player, with scene fades, route ownership, and muting/background behavior consistent with the SFX settings.
- Generated files passed numerical checks for PCM format, clipping, DC offset, one-shot endpoints, loop boundary steps, and unchanged approved samples. Runtime scheduling, asset bundling, scan callbacks, and selected gameplay regressions also passed automated tests. These checks do not replace listening review. Verify real-device latency, overlapping effects, background/resume behavior, and music/SFX balance.
