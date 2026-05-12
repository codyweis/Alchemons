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
