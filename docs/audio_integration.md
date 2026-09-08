# Sound integration: first gameplay pass

The app bundles all 83 one-shot cues and their 21 variations. Playback uses the
existing master/SFX switches. Music remains independently controlled.

## Connected events

- Main navigation selection, home shortcut buttons, black-market navigation,
  shared floating close buttons, extraction-vial dialog buttons, survival menu
  actions, and survival base-command buttons.
- Extraction cinematic: reaction buildup ends at the 55% burst marker; the
  pressure-release cue fires at the visible burst. The result dialog starts its
  scanner cue with the scan animation and adjusts playback speed so the
  identification tone matches the ready event, including performance mode and
  new-discovery timing. Rare/prismatic specimens use the extended scan.
- Existing cosmic portal, orb pickup/deposit, anomaly, and starforge events now
  resolve to bundled WAVs. Cache opening uses its dedicated cache sound.
- Survival: ship/companion projectile launches, enemy hits and defeats, ship/orb
  damage, wave starts/clears, wave-50 milestone, boss arrival, outbreaks,
  power-up selection, and game over.
- Dungeons: interaction attempts, visible gate reveals, successful elemental
  combat specials (all 17 elements), refused/cooling specials, direct enemy hits
  and defeats, stars, discoveries, guardian arrival, player down, and raid victory.

## Playback policy

`lib/audio/sound_cue.dart` maps exact filenames, gain, cooldown, priority, and
variation selection. `SoundEffectsPlayer` reserves at most six concurrent voices
before loading and retains up to eight completed voices for reuse. Frequent
effects are softer and rate-limited; important feedback can displace lower
priority effects. Muting/backgrounding cancels active and loading effects.
Extraction and game screens cancel their owned sounds when they close; survival
pause also stops its current effects. Early events before audio settings finish
loading are dropped instead of being replayed late.

## Remaining sound-design pass

This is the first gameplay integration, not every library asset assigned to an
event. Six ambience loops remain preview assets; they need scene-aware loop
playback and a listening/mix pass. Many specialized cues (individual puzzle
mechanisms, footsteps, capture, harvesting, shop rewards) remain available in the
catalog for future hooks. Not every custom button has sound yet. No device build
or audible on-device latency/mixing check has been performed for this pass.

## Validation

- Scheduling tests cover cooldowns, concurrent loading limits, priority eviction,
  cancellation during loading, owner isolation, and player reuse.
- Asset tests load every mapped cue/variation from Flutter's bundle.
- Scan widget test checks one cue event per scan, without replay on rebuild.
- Existing survival balance and dungeon combat/action tests exercise the modified
  game code without requiring a platform audio backend.
