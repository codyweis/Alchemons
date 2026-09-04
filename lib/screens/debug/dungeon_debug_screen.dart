// lib/screens/debug/dungeon_debug_screen.dart
//
// DEVELOPER TOOL — descend into any built dungeon from the profile.
//
// The cosmic screen already had a debug descent, but it is only reachable by
// parking beside the right planet: seventeen dungeons meant seventeen flights
// to test seventeen things. This is the same descent as a flat list.
//
// Nothing here writes to the save. The gate stays sealed, the carried party is
// untouched, and only what the run itself banks persists — so a debug descent
// can never fake progression the player did not earn. The star pips are read
// from the same prefs key the cosmic screen owns, purely to show what a run
// would still be worth.
//
// Aesthetic follows the profile's Scorched Forge surfaces (dark metal panels,
// amber accents, monospace) rather than inventing a third debug look.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must match `_CosmicScreenState._planetStarStatePrefsKey` — the cosmic screen
/// owns this key; this screen only ever READS it.
const String _kPlanetStarStatePrefsKey = 'cosmic_planet_stars';

class DungeonDebugScreen extends StatefulWidget {
  const DungeonDebugScreen({super.key});

  @override
  State<DungeonDebugScreen> createState() => _DungeonDebugScreenState();
}

class _DungeonDebugScreenState extends State<DungeonDebugScreen> {
  PlanetStarState _stars = PlanetStarState.fresh();

  /// Authoring order, not alphabetical: the layouts map is declared in the
  /// order the planets were built, which is the order a tester thinks in
  /// ("the new one is at the bottom").
  late final List<String> _elements = kPlanetDungeonLayouts.keys.toList();

  @override
  void initState() {
    super.initState();
    _loadStars();
  }

  Future<void> _loadStars() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stars = PlanetStarState.deserialise(
        prefs.getString(_kPlanetStarStatePrefsKey) ?? '',
      );
    });
  }

  Future<void> _descend(String element) async {
    final catalog = context.read<CreatureCatalog>();
    final party = debugIdealTrio(catalog, element);
    if (party.isEmpty) {
      // The catalog could not field anything for this element's slots. Say so
      // instead of pushing a dungeon whose front door cannot be opened.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No creatures match $element\'s entry trio.')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanetDungeonScreen(element: element, party: party),
      ),
    );
    if (!mounted) return;
    // A run can bank stars; re-read so the pips are honest on the way back.
    await _loadStars();
  }

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.watch<FactionTheme>();
    final t = ForgeTokens(factionTheme);
    final catalog = context.read<CreatureCatalog>();

    return ParticleBackgroundScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    Icon(AppIcons.bug_report_rounded, size: 16, color: t.teal),
                    const SizedBox(width: 8),
                    Text(
                      'DUNGEON DEBUG',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Descend into any built dungeon with its ideal trio, '
                  'skipping the gate and the carried party. The gate stays '
                  'sealed, only what a run banks is kept.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_elements.length} built',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                for (final element in _elements) ...[
                  _DungeonRow(
                    element: element,
                    stars: _stars.starMaskFor(element),
                    exactTrio: debugTrioIsExact(catalog, element),
                    onDescend: () => _descend(element),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingCloseButton(
                onTap: () => Navigator.pop(context),
                theme: factionTheme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DungeonRow extends StatelessWidget {
  const _DungeonRow({
    required this.element,
    required this.stars,
    required this.exactTrio,
    required this.onDescend,
  });

  final String element;
  final int stars;
  final bool exactTrio;
  final VoidCallback onDescend;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final accent = kElementColors[element] ?? t.amber;
    final entry = kCosmicPlanetEntry[element] ?? const [];
    final families = kDungeonIdealFamilies[element] ?? const [];
    final guardian = kRaidGuardianIds[element];
    final layout = kPlanetDungeonLayouts[element];
    final gates = layout?.familyGates ?? const <DungeonFamilyGate>[];

    // "Icemane · Lightmask · Airwing" — the team the descent will fabricate,
    // spelled the way the riddle and the docs spell it.
    final trio = [
      for (var i = 0; i < entry.length; i++)
        '${entry[i]}${i < families.length ? families[i].toLowerCase() : ''}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (kPlanetDisplayName[element] ?? element)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                element.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              for (var i = 0; i < 3; i++)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  // star_filled vs star_rounded, NOT
                                  // star_rounded vs star_outline_rounded:
                                  // those two are the same Phosphor glyph, so
                                  // that pairing would separate earned from
                                  // unearned by colour alone.
                                  child: Icon(
                                    (stars & (1 << i)) != 0
                                        ? AppIcons.star_filled
                                        : AppIcons.star_rounded,
                                    size: 12,
                                    color: (stars & (1 << i)) != 0
                                        ? t.amberBright
                                        : t.borderMid,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trio,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                          if (guardian != null)
                            Text(
                              guardian,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textMuted,
                                fontSize: 10,
                                letterSpacing: 1.1,
                              ),
                            ),
                          // THE ACCESS TEXT — the verse the gate speaks and
                          // the keys it will actually check. Shown here for
                          // the same reason the descent panel shows it: this
                          // screen skips the gate, so without it there is no
                          // way to read what a planet asks for before being
                          // dropped inside it.
                          if (layout != null) ...[
                            const SizedBox(height: 6),
                            for (final line in layout.riddle)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 1),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    color: t.textSecondary.withValues(
                                      alpha: 0.85,
                                    ),
                                    fontSize: 10.5,
                                    height: 1.35,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                          if (gates.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final g in gates)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Text(
                                      g.label.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: accent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          // A missing family is not a missing element: the
                          // descent still happens, but a hard family gate
                          // inside will have no key. Better said here than
                          // discovered at the locked door.
                          if (!exactTrio)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '⚠ no exact family match. Family gates may '
                                'be unopenable',
                                style: TextStyle(
                                  color: t.amber,
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onDescend,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          '⇩',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
