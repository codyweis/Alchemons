// lib/screens/faction_picker.dart

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/interactive_background_widget.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final svc = context.read<FactionService>();
    await svc.setId(selected.id);

    await db.settingsDao.setMustPickFaction(false);
    // Trigger any side-effects tied to faction selection.
    await svc.ensureAirExtraSlotUnlocked(); // harmless no-op unless Air + perk1

    if (mounted) {
      Navigator.of(context).pop(selected.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        body: Stack(
          children: [
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
                padding: const EdgeInsets.only(top: 40),
                child: _OrbNavigation(
                  factions: _factions,
                  currentIndex: _currentIndex,
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
                  padding: const EdgeInsets.only(bottom: 40),
                  child: _ConfirmButton(
                    factionName: _factions[_currentIndex].name,
                    color: _factions[_currentIndex].primaryColor,
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

        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 120), // Space for orb navigation
                // Faction title
                Text(
                  data.title.toUpperCase(),
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: data.primaryColor.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Divider line
                Container(
                  width: 100,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        data.primaryColor.withOpacity(0),
                        data.primaryColor,
                        data.primaryColor.withOpacity(0),
                      ],
                    ),
                  ),
                ),

                // Vial display
                SizedBox(
                  height: 280,
                  child: Center(
                    child: _VialDisplay(
                      elementalGroup: data.elementalGroup,
                      color: data.primaryColor,
                      pulseController: pulseController,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 🔽 Scrollable section starts here
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100.0),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Philosophy text
                          Text(
                            data.philosophy,
                            style: GoogleFonts.crimsonText(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.95),
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 25),

                          // Description
                          Text(
                            data.description,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // Perks section
                          _PerksSection(
                            perks: data.perks,
                            color: data.primaryColor,
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                // 🔼 Scrollable section ends here
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
        final scale = 1.0 + (pulse * 0.05);

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 200,
            height: 240,
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

  const _PerksSection({required this.perks, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Perks title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'DIVISION PERKS',
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Perk cards
        ...perks.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PerkCard(perk: entry.value, color: color, index: entry.key),
          );
        }).toList(),
      ],
    );
  }
}

class _PerkCard extends StatelessWidget {
  final _Perk perk;
  final Color color;
  final int index;

  const _PerkCard({
    required this.perk,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
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
                    BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  perk.title,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 0.4,
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
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.white.withOpacity(0.85),
                height: 1.3,
              ),
            ),
          ),
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
  final ValueChanged<int> onTap;

  const _OrbNavigation({
    required this.factions,
    required this.currentIndex,
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
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: isActive ? 70 : 50,
            height: isActive ? 70 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? faction.primaryColor
                    : Colors.white.withOpacity(0.3),
                width: isActive ? 3 : 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: faction.primaryColor.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
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
                    color: faction.primaryColor.withOpacity(0.3),
                    child: Icon(
                      Icons.circle,
                      color: faction.primaryColor,
                      size: isActive ? 35 : 25,
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
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.factionName,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SELECT $factionName',
              style: GoogleFonts.robotoMono(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
