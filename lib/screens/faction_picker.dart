// lib/screens/faction_picker.dart
//
// Choosing a division, once, at the start. Each division is shown as its
// realm — the home background it will give you, in grains, stirred by any
// finger on the screen — with its starter orb above and its creed and perks
// in the bracket frame. Swiping between divisions flies the grains from one
// realm into the next.

import 'package:alchemons/audio/audio.dart';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/starter_vial_handoff.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FactionPickerDialog extends StatefulWidget {
  const FactionPickerDialog({super.key, this.emergeFrom});

  /// Opened from the opening's last page: the realm gathers out of the knot
  /// of grains that page ended in, at this point on screen, and the rest of
  /// the picker fades in once it has.
  final Offset? emergeFrom;

  @override
  State<FactionPickerDialog> createState() => _FactionPickerDialogState();
}

class _FactionPickerDialogState extends State<FactionPickerDialog>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;

  /// The picker's words and buttons, faded in after the realm has formed
  /// when it opens out of the opening (see [FactionPickerDialog.emergeFrom]).
  late final AnimationController _chrome = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: widget.emergeFrom == null ? 1 : 0,
  );

  /// The realm behind every page: one field, so a swipe reforms the grains
  /// from one faction's ground into the next rather than cutting.
  final FactionRealmField _realm = FactionRealmField(
    faction: FactionId.volcanic,
  );

  int _currentIndex = 0;

  /// The chosen division's starter orb: where the handoff picks it up.
  final GlobalKey _chosenOrbKey = GlobalKey(debugLabel: 'chosen-starter-orb');

  /// The realm was handed to [StarterVialHandoff], which disposes it.
  bool _realmHandedOff = false;

  /// Set while the choice is being saved: the button dims and nothing else
  /// takes a tap, so the wait reads as the choice being made.
  bool _committing = false;

  late List<_FactionCardData> _factions;

  // Build UI card data from the service catalog to keep UI + logic in sync.
  List<_FactionCardData> _fromCatalog() {
    _FactionCardData make(
      FactionId id, {
      required String uiTitle,
      required Color primary,
      required Color secondary,
      required Color accent,
      required ElementalGroup group,
    }) {
      final info = FactionService.catalog[id]!;
      return _FactionCardData(
        id: id,
        name: info.name.toUpperCase(),
        title: uiTitle,
        philosophy: info.philosophy,
        description: info.description,
        perks: info.perks
            .map((p) => _Perk(title: p.title, description: p.description))
            .toList(),
        primaryColor: primary,
        secondaryColor: secondary,
        accentColor: accent,
        elementalGroup: group,
      );
    }

    return [
      make(
        FactionId.volcanic,
        uiTitle: 'Volcanic',
        primary: const Color(0xFFFF6B35),
        secondary: const Color(0xFFFF8C42),
        accent: const Color(0xFFFFAA64),
        group: ElementalGroup.volcanic,
      ),
      make(
        FactionId.oceanic,
        uiTitle: 'Oceanic',
        primary: const Color(0xFF4ECDC4),
        secondary: const Color(0xFF45B7D1),
        accent: const Color(0xFF96CEB4),
        group: ElementalGroup.oceanic,
      ),
      // Each division in its realm's colors: Earthen the ochre of its
      // strata, Verdant the green of the seeds its wind carries.
      make(
        FactionId.earthen,
        uiTitle: 'Earthen',
        primary: const Color(0xFFD6A35C),
        secondary: const Color(0xFFC07E48),
        accent: const Color(0xFFE6C690),
        group: ElementalGroup.earthen,
      ),
      make(
        FactionId.verdant,
        uiTitle: 'Verdant',
        primary: const Color(0xFF86CF9C),
        secondary: const Color(0xFF6BB886),
        accent: const Color(0xFFB4E2C2),
        group: ElementalGroup.verdant,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _factions = _fromCatalog();
    // Taps wait for the chrome: rebuild once it has faded in.
    _chrome.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
    final knot = widget.emergeFrom;
    if (knot != null) {
      _realm.emergeFrom(knot);
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _chrome.forward();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chrome.dispose();
    if (!_realmHandedOff) _realm.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    HapticFeedback.mediumImpact();
  }

  Future<void> _selectFaction() async {
    if (_committing) return;
    HapticFeedback.heavyImpact();
    setState(() => _committing = true);
    final selected = _factions[_currentIndex];
    final svc = context.read<FactionService>();
    final db = context.read<AlchemonsDatabase>();
    // Only the very first choice brings a starter vial to carry into a
    // chamber; a faction change bought later just closes.
    final firstChoice = svc.current == null;

    try {
      for (final biome in [
        Biome.verdant,
        Biome.earthen,
        Biome.oceanic,
        Biome.volcanic,
      ]) {
        await db.biomeDao.unlockBiome(biomeId: biome.id, free: true);
      }
      // Persist through the service (single source of truth).
      await svc.setId(selected.id);
      await db.settingsDao.setMustPickFaction(false);
    } catch (_) {
      if (mounted) setState(() => _committing = false);
      rethrow;
    }

    if (!mounted) return;
    if (firstChoice) _handOffToChamber(selected);
    Navigator.of(context).pop(selected.id);
  }

  /// The choice keeps the screen: the realm and the chosen starter orb move
  /// into the root overlay, the grains pour into the orb, and it carries on
  /// into the first chamber once the app has loaded under it (see
  /// starter_vial_handoff.dart). Skipped if the orb isn't on screen.
  void _handOffToChamber(_FactionCardData chosen) {
    final box = _chosenOrbKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final orbRect = box.localToGlobal(Offset.zero) & box.size;
    final (a, b) = chosen.elementalGroup.particleTypes;
    final theme = context.read<FactionTheme>();
    final ink = !ForgeTokens(theme).isDark;
    StarterVialHandoff.instance.begin(
      context,
      faction: chosen.id,
      ink: ink,
      field: _realm,
      vial: _starterVialFor(chosen),
      orbRect: orbRect,
      grainColors: [
        BreedConstants.getTypeColor(a),
        if (b != null) BreedConstants.getTypeColor(b),
        // Parchment grains on the dark page; sepia ones on the light, where
        // parchment would vanish into it.
        ink ? const Color(0xFF4A3C30) : const Color(0xFFE8DCC8),
      ],
    );
    _realmHandedOff = true;
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.watch<FactionTheme>());
    final palette = BracketPalette.fromTheme(context.watch<FactionTheme>());
    final chosen = _factions[_currentIndex];
    final accent = t.readableAccent(chosen.primaryColor);

    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        backgroundColor: t.bg0,
        // Nothing is worth tapping once the choice is made, and a second tap
        // on Confirm mid-flood would be a second commit.
        body: AbsorbPointer(
          absorbing: _committing || _chrome.value < 1,
          // Any finger anywhere stirs the realm, a swipe between pages too.
          child: FactionRealmStir(
            field: _realm,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FactionRealmView(
                    faction: chosen.id,
                    ink: !t.isDark,
                    field: _realm,
                    stirs: false,
                  ),
                ),
                SafeArea(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _chrome,
                      curve: Curves.easeOut,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        Text(
                          'CHOOSE YOUR DIVISION',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.muted,
                            letterSpacing: 2.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _OrbRow(
                          factions: _factions,
                          currentIndex: _currentIndex,
                          palette: palette,
                          orbKey: _chosenOrbKey,
                          onTap: (index) => _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            itemCount: _factions.length,
                            itemBuilder: (context, index) => _FactionPage(
                              data: _factions[index],
                              palette: palette,
                              accent: t.readableAccent(
                                _factions[index].primaryColor,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 6, 28, 20),
                          // On the light page the button would sit on the
                          // ground's stipple: give it paper under its wash.
                          child: ColoredBox(
                            color: palette.isDark
                                ? const Color(0x00000000)
                                : palette.chromeFill(),
                            child: BracketButton(
                              label: 'JOIN THE ${chosen.name} DIVISION',
                              palette: palette,
                              accent: accent,
                              height: 50,
                              enabled: !_committing,
                              onTap: _selectFaction,
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
        ),
      ),
    );
  }
}

// ============================================================================
// FACTION CARD DATA
// ============================================================================

class _FactionCardData {
  final FactionId id;
  final String name;
  final String title;
  final String philosophy;
  final String description;
  final List<_Perk> perks;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final ElementalGroup elementalGroup;

  const _FactionCardData({
    required this.id,
    required this.name,
    required this.title,
    required this.philosophy,
    required this.description,
    required this.perks,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.elementalGroup,
  });
}

class _Perk {
  final String title;
  final String description;

  const _Perk({required this.title, required this.description});
}

// ============================================================================
// THE ORBS: one per division, the chosen one held up
// ============================================================================

class _OrbRow extends StatelessWidget {
  const _OrbRow({
    required this.factions,
    required this.currentIndex,
    required this.palette,
    required this.onTap,
    required this.orbKey,
  });

  final List<_FactionCardData> factions;
  final int currentIndex;
  final BracketPalette palette;
  final ValueChanged<int> onTap;
  final GlobalKey orbKey;

  @override
  Widget build(BuildContext context) {
    final big = MediaQuery.sizeOf(context).shortestSide < 380 ? 92.0 : 108.0;
    return SizedBox(
      height: big + 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < factions.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: context.soundAction(() => onTap(i)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                width: i == currentIndex ? big : 46,
                height: i == currentIndex ? big + 26 : 46,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: _Orb(
                  data: factions[i],
                  chosen: i == currentIndex,
                  palette: palette,
                  orbKey: i == currentIndex ? orbKey : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The starter vial a division hands out, as its orb shows it.
ExtractionVial _starterVialFor(_FactionCardData data) => ExtractionVial(
  price: null,
  id: 'starter_${data.elementalGroup.name}',
  name: 'STARTER VIAL',
  group: data.elementalGroup,
  rarity: VialRarity.uncommon,
  quantity: 1,
);

class _Orb extends StatelessWidget {
  const _Orb({
    required this.data,
    required this.chosen,
    required this.palette,
    this.orbKey,
  });

  final _FactionCardData data;
  final bool chosen;
  final BracketPalette palette;
  final GlobalKey? orbKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth;
        final vial = _starterVialFor(data);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              // (On paper a faded orb only turns grey: fade it less.)
              opacity: chosen ? 1 : (palette.isDark ? 0.55 : 0.8),
              child: SizedBox.square(
                key: orbKey,
                dimension: side,
                child: ExtractionVialCard(
                  vial: vial,
                  compact: !chosen,
                  showTags: false,
                  circular: true,
                  onLight: !palette.isDark,
                ),
              ),
            ),
            if (chosen && box.maxHeight >= side + 20)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'STARTER ORB',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// A DIVISION'S PAGE: its name, its creed, its perks
// ============================================================================

class _FactionPage extends StatelessWidget {
  const _FactionPage({
    required this.data,
    required this.palette,
    required this.accent,
  });

  final _FactionCardData data;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final shadow = [
      Shadow(
        color: palette.bg0.withValues(alpha: palette.isDark ? 0.9 : 0.6),
        blurRadius: 12,
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 16),
      child: Column(
        children: [
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 1.2,
              shadows: shadow,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'DIVISION',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: palette.muted,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            data.philosophy,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontStyle: FontStyle.italic,
              color: palette.ink,
              height: 1.45,
              shadows: shadow,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: palette.muted,
              height: 1.45,
              shadows: shadow,
            ),
          ),
          const SizedBox(height: 22),
          CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: accent.withValues(alpha: 0.85),
              bracketSize: 10,
              strokeWidth: 1.2,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              color: palette.surfaceMutedFill(
                darkAlpha: 0.62,
                lightAlpha: 0.86,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERKS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: palette.muted,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final perk in data.perks)
                    _PerkRow(perk, palette, accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow(this.perk, this.palette, this.accent);

  final _Perk perk;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 10),
            child: Transform.rotate(
              angle: 0.785,
              child: Container(width: 5, height: 5, color: accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perk.title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  perk.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.ink.withValues(alpha: 0.86),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
