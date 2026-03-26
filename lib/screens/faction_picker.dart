// lib/screens/faction_picker.dart

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/interactive_background_widget.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FactionPickerDialog extends StatefulWidget {
  const FactionPickerDialog({super.key});

  @override
  State<FactionPickerDialog> createState() => _FactionPickerDialogState();
}

class _FactionPickerDialogState extends State<FactionPickerDialog>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _particleController;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  late AnimationController _pulseController;

  int _currentIndex = 0;

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
      required String orb,
    }) {
      final info = FactionService.catalog[id]!;
      return _FactionCardData(
        id: id,
        name: info.name.toUpperCase(),
        title: '$uiTitle Division',
        philosophy: info.philosophy,
        description: info.description,
        perks: info.perks
            .map((p) => _Perk(title: p.title, description: p.description))
            .toList(),
        primaryColor: primary,
        secondaryColor: secondary,
        accentColor: accent,
        elementalGroup: group,
        orbImage: orb,
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
        orb: 'assets/images/factions/volcanic.png',
      ),
      make(
        FactionId.oceanic,
        uiTitle: 'Oceanic',
        primary: const Color(0xFF4ECDC4),
        secondary: const Color(0xFF45B7D1),
        accent: const Color(0xFF96CEB4),
        group: ElementalGroup.oceanic,
        orb: 'assets/images/factions/oceanic.png',
      ),
      make(
        FactionId.earthen,
        uiTitle: 'Earthen',
        primary: const Color(0xFF95D5B2),
        secondary: const Color(0xFF74C69D),
        accent: const Color(0xFFB7E4C7),
        group: ElementalGroup.earthen,
        orb: 'assets/images/factions/earthen.png',
      ),
      make(
        FactionId.verdant,
        uiTitle: 'Verdant',
        primary: const Color(0xFFF3E8FF),
        secondary: const Color(0xFFD4C5F9),
        accent: const Color(0xFFE5D9F2),
        group: ElementalGroup.verdant,
        orb: 'assets/images/factions/verdant.png',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _particleController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _factions = _fromCatalog();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _particleController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    HapticFeedback.mediumImpact();
  }

  Future<void> _selectFaction() async {
    HapticFeedback.heavyImpact();
    final selected = _factions[_currentIndex];
    final svc = context.read<FactionService>();
    // final elementalGroup = selected.elementalGroup;
    // final biome = Biome.values.firstWhere(
    //   (b) => b.name == elementalGroup.name,
    //   orElse: () => Biome.earthen,
    // );
    final db = context.read<AlchemonsDatabase>();
    await db.biomeDao.unlockBiome(biomeId: Biome.verdant.id, free: true);
    await db.biomeDao.unlockBiome(biomeId: Biome.earthen.id, free: true);
    await db.biomeDao.unlockBiome(biomeId: Biome.oceanic.id, free: true);
    await db.biomeDao.unlockBiome(biomeId: Biome.volcanic.id, free: true);
    // Persist through the service (single source of truth).
    await svc.setId(selected.id);

    await db.settingsDao.setMustPickFaction(false);

    if (mounted) {
      Navigator.of(context).pop(selected.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.watch<FactionTheme>());

    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        backgroundColor: t.bg0,
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.bg0, t.bg1, t.bg2.withValues(alpha: 0.9)],
                  ),
                ),
              ),
            ),
            // Page view with faction cards
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _factions.length,
              itemBuilder: (context, index) {
                return _FactionCard(
                  data: _factions[index],
                  particleController: _particleController,
                  rotationController: _rotationController,
                  waveController: _waveController,
                  pulseController: _pulseController,
                );
              },
            ),

            // Top orb navigation
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _OrbNavigation(
                  factions: _factions,
                  currentIndex: _currentIndex,
                  tokens: t,
                  onTap: (index) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                ),
              ),
            ),

            // Bottom confirm button
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: _ConfirmButton(
                    factionName: _factions[_currentIndex].name,
                    color: _factions[_currentIndex].primaryColor,
                    tokens: t,
                    onPressed: _selectFaction,
                  ),
                ),
              ),
            ),
          ],
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
  final String orbImage;

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
    required this.orbImage,
  });
}

class _Perk {
  final String title;
  final String description;

  const _Perk({required this.title, required this.description});
}

// ============================================================================
// FACTION CARD
// ============================================================================

class _FactionCard extends StatelessWidget {
  final _FactionCardData data;
  final AnimationController particleController;
  final AnimationController rotationController;
  final AnimationController waveController;
  final AnimationController pulseController;

  const _FactionCard({
    required this.data,
    required this.particleController,
    required this.rotationController,
    required this.waveController,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.watch<FactionTheme>());
    final accentTextColor = t.readableAccent(data.primaryColor);
    final bodyTextColor = t.isDark
        ? t.textSecondary
        : t.textPrimary.withValues(alpha: 0.82);

    return Stack(
      children: [
        // Interactive background
        Positioned.fill(
          child: InteractiveBackground(
            particleController: particleController,
            rotationController: rotationController,
            waveController: waveController,
            primaryColor: data.primaryColor,
            secondaryColor: data.secondaryColor,
            accentColor: data.accentColor,
            factionType: data.id,
            particleSpeed: 1.0,
            rotationSpeed: 0.1,
            elementalSpeed: 0.5,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  t.bg0.withValues(alpha: 0.6),
                  t.bg1.withValues(alpha: 0.55),
                  t.bg0.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 95),
            child: Column(
              children: [
                Text(
                  data.title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: accentTextColor,
                    letterSpacing: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(height: 1, width: 120, color: t.borderMid),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: Center(
                    child: _VialDisplay(
                      elementalGroup: data.elementalGroup,
                      color: data.primaryColor,
                      pulseController: pulseController,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                    child: Column(
                      children: [
                        Text(
                          data.philosophy,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: t.textPrimary.withValues(alpha: 0.96),
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          data.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: bodyTextColor,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _PerksSection(
                          perks: data.perks,
                          color: data.primaryColor,
                          tokens: t,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// VIAL DISPLAY
// ============================================================================

class _VialDisplay extends StatelessWidget {
  final ElementalGroup elementalGroup;
  final Color color;
  final AnimationController pulseController;

  const _VialDisplay({
    required this.elementalGroup,
    required this.color,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    // Create a starter vial for this faction
    final vial = ExtractionVial(
      price: null,
      id: 'starter_${elementalGroup.name}',
      name: 'STARTER VIAL',
      group: elementalGroup,
      rarity: VialRarity.uncommon,
      quantity: 1,
    );

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulse = pulseController.value;
        final scale = 0.72 + (pulse * 0.03);

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 130,
            height: 150,
            child: ExtractionVialCard(vial: vial, compact: false),
          ),
        );
      },
    );
  }
}

// ============================================================================
// PERKS SECTION
// ============================================================================

class _PerksSection extends StatelessWidget {
  final List<_Perk> perks;
  final Color color;
  final ForgeTokens tokens;

  const _PerksSection({
    required this.perks,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final accentTextColor = tokens.readableAccent(color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Perks title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Container(height: 1, color: tokens.borderMid)),
            const SizedBox(width: 8),
            Text(
              'DIVISION PERKS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: accentTextColor,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: tokens.borderMid)),
          ],
        ),
        const SizedBox(height: 16),

        // Perk cards
        ...perks.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PerkCard(
              perk: entry.value,
              color: color,
              index: entry.key,
              tokens: tokens,
            ),
          );
        }),
      ],
    );
  }
}

class _PerkCard extends StatelessWidget {
  final _Perk perk;
  final Color color;
  final int index;
  final ForgeTokens tokens;

  const _PerkCard({
    required this.perk,
    required this.color,
    required this.index,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final accentTextColor = tokens.readableAccent(color);
    final bodyTextColor = tokens.isDark
        ? tokens.textSecondary
        : tokens.textPrimary.withValues(alpha: 0.82);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Perk title
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '[${index + 1}]',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  perk.title,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accentTextColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Perk description
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              perk.description,
              style: TextStyle(
                fontSize: 11,
                color: bodyTextColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: tokens.borderDim.withValues(alpha: 0.55)),
        ],
      ),
    );
  }
}

// ============================================================================
// ORB NAVIGATION
// ============================================================================

class _OrbNavigation extends StatelessWidget {
  final List<_FactionCardData> factions;
  final int currentIndex;
  final ForgeTokens tokens;
  final ValueChanged<int> onTap;

  const _OrbNavigation({
    required this.factions,
    required this.currentIndex,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(factions.length, (index) {
        final faction = factions[index];
        final isActive = index == currentIndex;

        return GestureDetector(
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: isActive ? 62 : 46,
            height: isActive ? 62 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.bg2,
              border: Border.all(
                color: isActive ? faction.primaryColor : tokens.borderDim,
                width: isActive ? 2 : 1.2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: faction.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: Image.asset(
                faction.orbImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: faction.primaryColor.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.circle,
                      color: faction.primaryColor,
                      size: isActive ? 30 : 22,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// CONFIRM BUTTON
// ============================================================================

class _ConfirmButton extends StatelessWidget {
  final String factionName;
  final Color color;
  final ForgeTokens tokens;
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.factionName,
    required this.color,
    required this.tokens,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accentTextColor = tokens.readableAccent(color);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tokens.bg2.withValues(alpha: 0.88), tokens.bg1],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: tokens.bg0.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SELECT $factionName',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accentTextColor,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: accentTextColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
