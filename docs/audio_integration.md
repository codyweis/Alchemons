# Sound integration

The app bundles all 83 one-shot cues and their 21 variations. Playback uses the
existing master/SFX switches. Music remains independently controlled.

Six ambience loops are also connected, using a separate single-loop player.

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
- Capture: device launch, containment attempt, escape, and success. Success plays
  after the captured specimen is stored; attempt audio is cancelled if the
  encounter closes. The success tone can finish across that closing transition.
- Harvesting: existing collection sounds now require a positive payout; chamber
  start/reload and biome unlock report success or refusal. Empty collect-all does
  not play a reward. Existing capture and harvesting hooks were retained.
- Purchases: ordinary shop items, alternate offer cards, and both black-market
  purchase paths report the actual result. Existing slot-purchase sounds remain.
  These are in-game purchases, not a new cue on initiation of a platform payment.
- Mechanisms: Earth lintel, rib movement and rising sockets; Water tide changes
  and opening sluices; Lightning breakers and rotating mirrors; first conduit
  charge; Anvil shell fracture; Fire mural torches; Steam corner seals; Ice stair
  shattering; Crystal socket sealing. Successful state changes trigger these
  sounds; already-completed/blocked attempts do not replay the success cue.
- Ambience: space exploration, extraction hub/detail laboratories, and elemental
  dungeons. Water/ice/mud/poison use water; fire/lava/steam use fire;
  crystal/spirit/light/dark/lightning/blood use arcane; others use ruins.
- Button feedback across shared controls and custom screens (roughly 500 new
  callbacks), including long-press specimen controls. Null callbacks stay disabled;
  touch-absorbing empty callbacks remain silent. Synchronous outcome cues and
  nested sound wrappers suppress the fallback tap. Dialog opening, closing,
  barrier dismissal, and route back navigation have dedicated feedback.
- Space discovery, successful scanner activation, boost activation, and planet
  descent. Achievement reward claims use the achievement cue after persistence.
- Survival: heavy impacts (100+ damage), shield absorption/breakage, positive
  healing, crossing below 25% orb health, and a newly filled power-up meter.
  Healing and shield feedback are rate-limited.
- Dungeons: ground footsteps every 48 units of actual movement, flooded Water
  temple footsteps, hazard entry, party-member revival, first puzzle-star
  completion, and the guardian relic's collection animation ending. Flight,
  blocked movement, and repeating an already-earned star do not retrigger them.

## Playback policy

`lib/audio/sound_cue.dart` maps exact filenames, gain, cooldown, priority, and
variation selection. `SoundEffectsPlayer` reserves at most six concurrent voices
before loading and retains up to eight completed voices for reuse. Frequent
effects are softer and rate-limited; important feedback can displace lower
priority effects. Muting/backgrounding cancels active and loading effects.
Extraction and game screens cancel their owned sounds when they close; survival
pause also stops its current effects. Early events before audio settings finish
loading are dropped instead of being replayed late.

`AmbiencePlayer` serializes loading and fading so only one scene bed plays at a
time. `SceneAmbience` uses the application's ambience route observer to stop a
covered route and restore it on return. Muting/backgrounding stops the loop;
unmuting/foregrounding restores the requested scene. Late loads are discarded.
Ordinary route changes use short fades; ambience stays outside the one-shot
budget and below the music/effects mix.

## Device verification and reserved assets

The critical-hit asset remains bundled for future use. Combat exposes crit-chance
stats but does not currently report a resolved critical-hit event; ordinary hits
must not masquerade as critical hits just to use that file.

The completed arm64 debug APK built and was installed on September 9, 2026.
Installation required removing the previous app because its signing key differed.
An on-device listening pass remains necessary for loop transitions, loudness,
and latency; automated tests cannot establish how the phone speakers sound.
Later builds must include this integration commit to retain the final button,
specimen-selection, gameplay, and ambience hooks.

## Validation

- Scheduling tests cover cooldowns, concurrent loading limits, priority eviction,
  cancellation during loading, owner isolation, and player reuse.
- Asset tests load every mapped cue/variation from Flutter's bundle.
- Scan widget test checks one cue event per scan, without replay on rebuild.
- Existing survival balance and dungeon combat/action tests exercise the modified
  game code without requiring a platform audio backend.
- Ambience tests cover owner isolation, mute/resume, failed/stale loads,
  cancellation during loading, and route coverage/restoration. Asset tests load
  all six stereo ambience files from Flutter's bundle.
- Mechanism sound tests verify the Earth gate fires once on success and never on
  a wrong-element attempt. Full-run/mechanic regressions cover Water, Earth,
  Lightning, Fire, Steam, and Ice.
- Button tests cover disabled controls, nested callbacks, outcome precedence,
  initial-route silence, popup opening, and barrier dismissal.
- The complete survival/dungeon/scan regression selection passed 1,287 tests
  with one skipped test during the completion pass; the focused audio tests
  passed 17 tests.
- The full Flutter test suite passed 1,857 tests with 19 skipped tests.
