# Cosmic Ability Contract

This is the short source-of-truth checklist for Cosmic Survival ability plumbing.
It is derived from `alchemon_abilities_transcription.md` and backed by tests.

## Rules

- Ability mechanics live in `lib/games/cosmic/cosmic_data.dart`.
- Projectile drawing lives in `lib/games/cosmic/cosmic_projectile_vfx.dart`.
- Survival may scale cooldown, size, lifetime, and ambient density, but it must
  not replace authored family or element silhouettes with generic visuals.
- Performance visual mode can trim secondary glows, labels, and ambient VFX.
  It must preserve species ability identity.
- Avoid behavior checks based only on incidental flags like `homing`, `decoy`,
  or `stationary`. Prefer `abilityFamily`, `visualStyle`, and effect descriptors.
- Lightning is drawn by one renderer everywhere: `drawLightningBolt` /
  `drawLightningCrackle` in `cosmic_projectile_vfx.dart`, ported from the
  Voltara dungeon. Do not re-fork a per-game zigzag. Their `glowPasses`
  argument is the performance dial — 0 keeps the white-hot core and drops
  only the halo, so lightning identity survives performance visual mode.

## Authored Matrices

The transcribed family matrices are:

- Mane: catapult and piercing specials.
- Wing: beam specials.
- Mask: trap specials.
- Let: meteor specials.
- Pip: ricochet specials.

The expanded in-game authored families are:

- Horn
- Wing
- Let
- Pip
- Mane
- Mask
- Kin
- Mystic

Every authored family is expected to produce a special payload for every
canonical element in `kCosmicAbilityElements`. Payloads must either create
projectiles that preserve authored visual identity or create beam/support
effects that survival resolves explicitly.

## Ability Contact Sheets

Every authored ability (8 families x 17 elements = 136, covering all 137
creatures) can be rendered to PNG for visual review:

```
VFX_SHEET_OUT=docs/ability_sheets flutter test \
  test/family_vfx_contact_sheet_test.dart --tags preview
```

One sheet per family; rows are elements, columns are moments in the cast. The
harness calls `createCosmicSpecialAbility` and draws through the same renderer
chain survival uses, so the sheet cannot drift from the game.

Projectiles only. Wing beams and the charge/shield/blessing payloads are drawn
by the game, not the shared VFX layer, so those cells name the payload instead.
The generic silhouette for projectiles no family renderer claims (kin, mystic,
wing) lives in `drawGenericProjectileVisual` in `cosmic_projectile_vfx.dart`.

## Enemy Contact Sheets

```
ENEMY_SHEET_OUT=docs/ability_sheets flutter test \
  test/enemy_vfx_contact_sheet_test.dart --tags preview
```

Every procedural hostile renderer now lives in `lib/games/cosmic/cosmic_enemy_vfx.dart`
so both the game and the harness can reach it:

| Function | Used by |
| --- | --- |
| `drawSurvivalEnemy` | survival enemies |
| `drawSurvivalBoss` | survival bosses (incl. `extraBosses`) |
| `drawOpenWorldEnemy` | roaming-space enemies |
| `drawOpenWorldBoss` | lair bosses |
| `drawBossLair` | the waiting lair marker |

NOT procedural, so not on a sheet: the battle-ring opponent and the planet
dungeon guardians both render real creature sprites.

**These are four independent renderers for what is conceptually one roster.**
Survival bans per-frame blur; the open-world pass uses `MaskFilter.blur` in 15
places for enemies plus 6 for its boss. Converging them behind one silhouette
is open work — see the enemy audit.
