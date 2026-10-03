// lib/screens/faction_picker.dart
//
// Choosing a division, once, at the start. Each division is shown as its
// realm — the home background it will give you, in grains, stirred by any
// finger on the screen — with its starter orb above and its creed and perks
// in the bracket frame. Swiping between divisions flies the grains from one
// realm into the next.

import 'package:alchemons/audio/audio.dart';

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
import 'package:google_fonts/google_fonts.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FactionPickerDialog extends StatefulWidget {
  const FactionPickerDialog({super.key});

  @override
  State<FactionPickerDialog> createState() => _FactionPickerDialogState();
}

class _FactionPickerDialogState extends State<FactionPickerDialog> {
  late PageController _pageController;

  /// The realm behind every page: one field, so a swipe reforms the grains
  /// from one faction's ground into the next rather than cutting.
  final FactionRealmField _realm = FactionRealmField(
    faction: FactionId.volcanic,
  );

  int _currentIndex = 0;

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
      make(
        FactionId.earthen,
        uiTitle: 'Earthen',
        primary: const Color(0xFF95D5B2),
        secondary: const Color(0xFF74C69D),
        accent: const Color(0xFFB7E4C7),
        group: ElementalGroup.earthen,
      ),
      make(
        FactionId.verdant,
        uiTitle: 'Verdant',
        primary: const Color(0xFFF3E8FF),
        secondary: const Color(0xFFD4C5F9),
        accent: const Color(0xFFE5D9F2),
        group: ElementalGroup.verdant,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _factions = _fromCatalog();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _realm.dispose();
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

    if (mounted) {
      Navigator.of(context).pop(selected.id);
    }
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
          absorbing: _committing,
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
                        child: BracketButton(
                          label: 'JOIN THE ${chosen.name} DIVISION',
                          palette: palette,
                          accent: accent,
                          height: 50,
                          enabled: !_committing,
                          onTap: _selectFaction,
                        ),
                      ),
                    ],
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
  });

  final List<_FactionCardData> factions;
  final int currentIndex;
  final BracketPalette palette;
  final ValueChanged<int> onTap;

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
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.data, required this.chosen, required this.palette});

  final _FactionCardData data;
  final bool chosen;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth;
        final vial = ExtractionVial(
          price: null,
          id: 'starter_${data.elementalGroup.name}',
          name: 'STARTER VIAL',
          group: data.elementalGroup,
          rarity: VialRarity.uncommon,
          quantity: 1,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: chosen ? 1 : 0.55,
              child: SizedBox.square(
                dimension: side,
                child: ExtractionVialCard(
                  vial: vial,
                  compact: !chosen,
                  showTags: false,
                  circular: true,
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
