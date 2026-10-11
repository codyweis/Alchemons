// lib/screens/debug/ability_lab_screen.dart
//
// DEVELOPER TOOL — test any Alchemon's attacks from the profile.
//
// The Battle tab's full preview (the real Survival game with the waves held
// back, a ring of practice bodies and the special on a button) is the place
// to judge an ability, but it is three taps deep inside one creature's
// details. This lists EVERY species by family, owned or not, and opens that
// same preview with the species built at a chosen stat band
// ([openAbilityPreviewForSpecies]): level 10 with one Potential in every
// stat, optionally fully enhanced. So every ability can be stepped through,
// and its scaling seen, without owning or breeding anything.
//
// Nothing here writes to the save. Aesthetic follows the other profile debug
// screens (the Scorched Forge surfaces, monospace).

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _kFamilies = [
  'Horn',
  'Wing',
  'Let',
  'Pip',
  'Mane',
  'Mask',
  'Kin',
  'Mystic',
];

class AbilityLabScreen extends StatefulWidget {
  const AbilityLabScreen({super.key});

  @override
  State<AbilityLabScreen> createState() => _AbilityLabScreenState();
}

/// A stat band the lab builds every species at.
class _Band {
  const _Band(this.label, this.potential, [this.enhancement = 0]);
  final String label;
  final int potential;
  final int enhancement;
}

const _kBands = [
  _Band('P50', 50),
  _Band('P70', 70),
  _Band('P100', 100),
  _Band('P100 E10', 100, 10),
];

class _AbilityLabScreenState extends State<AbilityLabScreen> {
  /// Null shows every family.
  String? _family;
  _Band _band = _kBands[1];

  Future<void> _test(Creature creature) => openAbilityPreviewForSpecies(
    context,
    creature: creature,
    potential: _band.potential,
    enhancementRank: _band.enhancement,
  );

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.watch<FactionTheme>();
    final t = ForgeTokens(factionTheme);
    final catalog = context.read<CreatureCatalog>();

    int familyRank(Creature c) {
      final i = _kFamilies.indexOf(c.mutationFamily ?? '');
      return i < 0 ? _kFamilies.length : i;
    }

    // Every species with a combat family, in family order, then element,
    // then name.
    final species = [
      for (final c in catalog.creatures)
        if (_kFamilies.contains(c.mutationFamily)) c,
    ]..sort((a, b) {
        final f = familyRank(a).compareTo(familyRank(b));
        if (f != 0) return f;
        final e = (a.types.firstOrNull ?? '').compareTo(
          b.types.firstOrNull ?? '',
        );
        if (e != 0) return e;
        return a.name.compareTo(b.name);
      });
    final shown = _family == null
        ? species
        : [
            for (final c in species)
              if (c.mutationFamily == _family) c,
          ];

    return ParticleBackgroundScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  'ABILITY LAB',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Test any Alchemon in the practice arena: its auto attack, '
                  'and its special on a button. Each one is built at level 10 '
                  'with the stat band below, so you can see how it scales.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'STATS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in _kBands)
                      _FamilyChip(
                        label: b.label,
                        selected: identical(b, _band),
                        onTap: () => setState(() => _band = b),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'FAMILY',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _FamilyChip(
                      label: 'ALL ${species.length}',
                      selected: _family == null,
                      onTap: () => setState(() => _family = null),
                    ),
                    for (final f in _kFamilies)
                      _FamilyChip(
                        label:
                            '${f.toUpperCase()} '
                            '${species.where((c) => c.mutationFamily == f).length}',
                        selected: _family == f,
                        onTap: () => setState(() => _family = f),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  Text(
                    'No species found.',
                    style: TextStyle(color: t.textMuted, fontSize: 12),
                  )
                else
                  for (final creature in shown) ...[
                    _LabRow(
                      creature: creature,
                      band: _band.label,
                      onTest: context.soundTap(() => _test(creature)),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingCloseButton(
                onTap: context.soundTap(() => Navigator.pop(context)),
                theme: factionTheme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyChip extends StatelessWidget {
  const _FamilyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return GestureDetector(
      onTap: context.soundTap(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? t.amber.withValues(alpha: 0.18) : t.bg2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? t.amber : t.borderDim),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: selected ? t.amberBright : t.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _LabRow extends StatelessWidget {
  const _LabRow({
    required this.creature,
    required this.band,
    required this.onTest,
  });

  final Creature creature;
  final String band;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final element = creature.types.firstOrNull ?? 'Normal';
    final accent = kElementColors[element] ?? t.amber;
    final name = creature.name;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTest,
      child: Container(
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: t.borderDim),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accent),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.asset(
                    'assets/images/${creature.image}',
                    fit: BoxFit.contain,
                    cacheWidth: 96,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${creature.mutationFamily ?? '?'} · $element · '
                        'LV 10 · $band',
                        style: TextStyle(color: t.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    'TEST',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
