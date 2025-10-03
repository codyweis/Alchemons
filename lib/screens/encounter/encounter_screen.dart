// EncounterPage (updated)
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/likelihood_analyzer.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/widgets/badges/badge_widget.dart';
import 'package:alchemons/widgets/glowing_icon.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum EncounterResult { ran, bred, completed }

class EncounterPage extends StatefulWidget {
  final String speciesId;
  final Creature? hydrated;
  final List<PartyMember> party;

  const EncounterPage({
    super.key,
    required this.speciesId,
    required this.party,
    this.hydrated,
  });

  @override
  State<EncounterPage> createState() => _EncounterPageState();
}

class _EncounterPageState extends State<EncounterPage>
    with TickerProviderStateMixin {
  PartyMember? _selected;
  bool _isBreeding = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final (primaryColor, _, accentColor) = getFactionColors(currentFaction);
    final repo = context.read<CreatureRepository>();
    final base = repo.getCreatureById(widget.speciesId);
    final wild = widget.hydrated ?? base;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, EncounterResult.ran);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: _GlassContainer(
                  accentColor: accentColor,
                  glowController: _glowController,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _IconButton(
                          icon: Icons.arrow_back_rounded,
                          accentColor: accentColor,
                          onTap: () =>
                              Navigator.pop(context, EncounterResult.ran),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'ENCOUNTER',
                            style: _TextStyles.headerTitle,
                          ),
                        ),
                        GlowingIcon(
                          icon: Icons.pets_outlined,
                          color: accentColor,
                          controller: _glowController,
                          dialogTitle: "Wild Creature",
                          dialogMessage:
                              "This is the wild creature you are attempting to breed with. Select a suitable partner from your party below.",
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    // Wild hero
                    _WildHeroSection(wild: wild),

                    const SizedBox(height: 10),

                    // Pick partner
                    _SectionCard(
                      title: 'Select A Breeding Specimen',
                      icon: Icons.groups_outlined,
                      accent: accentColor,
                      child: SizedBox(
                        height: 168,
                        child: _PartyStrip(
                          party: widget.party,
                          selected: _selected,
                          onPick: (p) => setState(() => _selected = p),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Stats (wild + selected partner)
                    _SectionCard(
                      title: 'Info',
                      icon: Icons.analytics_outlined,
                      accent: Colors.tealAccent.shade400,
                      child: _StatsPanel(wild: wild, selection: _selected),
                    ),

                    const SizedBox(height: 80), // space above sticky footer
                  ],
                ),
              ),

              // Sticky footer
              _FooterBar(
                busy: _isBreeding,
                enabled: _selected != null && !_isBreeding,
                primaryColor: primaryColor,
                onBreed: _selected == null
                    ? null
                    : () => _handleBreed(context, _selected!),
                onAbort: () => Navigator.pop(context, EncounterResult.ran),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- breeding logic unchanged (snipped for brevity, keep your existing _handleBreed / dialogs) -----
  Future<void> _handleBreed(BuildContext context, PartyMember partner) async {
    setState(() => _isBreeding = true);

    final factions = context.read<FactionService>();
    final firePerk2 = await factions.perk2Active();
    final dbApi = context.read<db.AlchemonsDatabase>();
    final engine = context.read<BreedingEngine>();
    final repo = context.read<CreatureRepository>();
    final stamina = context.read<StaminaService>();

    bool spinnerOpen = false;
    void openSpinner() {
      if (spinnerOpen) return;
      spinnerOpen = true;
      // NOTE: do NOT await this
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    void closeSpinnerIfOpen() {
      if (!spinnerOpen) return;
      spinnerOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      final inst = await dbApi.getInstance(partner.instanceId);
      if (inst == null) {
        _snack('Could not load partner.');
        return;
      }
      final creatureOfInst = repo.getCreatureById(inst.baseId);
      if (creatureOfInst == null) {
        _snack('Could not load partner creature.');
        return;
      }

      final can = await stamina.canBreed(inst.instanceId);
      if (!can) {
        _snack('This partner is resting.');
        return;
      }

      final wild = widget.hydrated ?? repo.getCreatureById(widget.speciesId);
      if (wild == null) {
        _snack('Wild specimen unavailable.');
        return;
      }

      openSpinner();

      final hasFireParent =
          repo.getCreatureById(inst.baseId)?.types.contains('Fire') == true ||
          wild.types.contains('Fire');

      final fireMult = factions.fireHatchTimeMultiplier(
        hasFireParent: hasFireParent,
        perk2: firePerk2,
      );

      final analyzer = BreedingLikelihoodAnalyzer(
        repository: repo,
        elementRecipes: engine.elementRecipes,
        familyRecipes: engine.familyRecipes,
        specialRules: engine.specialRules,
        tuning: engine.tuning,
      );

      final result = engine.breedInstanceWithCreature(inst, wild);
      if (!result.success || result.creature == null) {
        closeSpinnerIfOpen();
        _snack('No offspring this time.');
        return;
      }

      final baby = result.creature!;
      final justification = analyzer.justifyBreedingResult(
        creatureOfInst,
        wild,
        baby,
      );

      final rarityKey = baby.rarity.toLowerCase();
      final baseHatch =
          BreedConstants.rarityHatchTimes[rarityKey] ??
          const Duration(minutes: 10);
      final hatchMult = hatchMultForNature(baby.nature?.id);
      final adjusted = Duration(
        milliseconds: (baseHatch.inMilliseconds * hatchMult * fireMult).round(),
      );

      final payload = {
        'baseId': baby.id,
        'rarity': baby.rarity,
        'natureId': baby.nature?.id,
        'genetics': baby.genetics?.variants ?? <String, String>{},
        'parentage': baby.parentage?.toJson(),
        'isPrismaticSkin': baby.isPrismaticSkin,
        'likelihoodAnalysis': jsonEncode(justification.toJson()),
      };
      final payloadJson = jsonEncode(payload);
      final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';

      final free = await dbApi.firstFreeSlot();
      int? placedIndex;
      bool enqueued = false;

      if (free == null) {
        await dbApi.enqueueEgg(
          eggId: eggId,
          resultCreatureId: baby.id,
          bonusVariantId: result.variantUnlocked?.id,
          rarity: baby.rarity,
          remaining: adjusted,
          payloadJson: payloadJson,
        );
        enqueued = true;
      } else {
        final hatchAtUtc = DateTime.now().toUtc().add(adjusted);
        await dbApi.placeEgg(
          slotId: free.id,
          eggId: eggId,
          resultCreatureId: baby.id,
          bonusVariantId: result.variantUnlocked?.id,
          rarity: baby.rarity,
          hatchAtUtc: hatchAtUtc,
          payloadJson: payloadJson,
        );
        placedIndex = free.id;
      }

      final factionsSvc = context.read<FactionService>();
      final waterPerk1 = factionsSvc.perk1Active && factionsSvc.isWater();
      final partnerIsWater =
          (repo.getCreatureById(inst.baseId)?.types.contains('Water') ?? false);
      final wildIsWater = wild.types.contains('Water');

      final skipStamina = factionsSvc.waterSkipBreedStamina(
        bothWater: partnerIsWater && wildIsWater,
        perk1: waterPerk1,
      );

      if (!skipStamina) {
        await stamina.spendForBreeding(inst.instanceId);
      }

      closeSpinnerIfOpen();

      if (!mounted) return;
      await _showResultDialog(
        context,
        baby,
        incubatorSlotIndex: placedIndex,
        hatchIn: adjusted,
        enqueuedInstead: enqueued,
      );

      if (!mounted) return;
      Navigator.of(context).pop(EncounterResult.bred);
    } catch (e) {
      closeSpinnerIfOpen();
      _snack('Breeding failed: $e');
    } finally {
      if (mounted) setState(() => _isBreeding = false);
    }
  }

  Future<void> _showResultDialog(
    BuildContext context,
    Creature baby, {
    int? incubatorSlotIndex,
    Duration? hatchIn,
    bool enqueuedInstead = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ResultDialog(
        baby: baby,
        slotIndex: incubatorSlotIndex,
        hatchIn: hatchIn,
        enqueued: enqueuedInstead,
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ------------------------------------------------------------
// UI Pieces
// ------------------------------------------------------------

class _WildHeroSection extends StatelessWidget {
  final Creature? wild;
  const _WildHeroSection({required this.wild});

  @override
  Widget build(BuildContext context) {
    final Genetics? g = wild?.genetics;
    final tintBorder = _tintSwatchColor(g) ?? Colors.purple.shade400;

    final wildNature = wild?.nature?.id ?? '—';
    final wildSize = _sizeName(wild?.genetics);
    final wildTint = _tintName(wild?.genetics);

    return _SectionCard(
      title: 'Wild Specimen',
      icon: Icons.pets_outlined,
      accent: tintBorder,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WildPreviewBox(creature: wild, borderColor: tintBorder),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wild?.name ?? 'Unknown Species',
                  style: _TextStyles.wildCreatureName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatChip(
                      icon: Icons.psychology,
                      label: 'Nature',
                      value: wildNature,
                    ),
                    _StatChip(
                      icon: Icons.height,
                      label: 'Size',
                      value: wildSize,
                    ),
                    _StatChip(
                      icon: Icons.palette,
                      label: 'Tint',
                      value: wildTint,
                      swatch: _TintDot(color: _tintSwatchColor(wild?.genetics)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (wild?.types.isNotEmpty == true)
                      Expanded(child: TypeBadges(types: wild!.types)),
                    const SizedBox(width: 8),
                    RarityBadge(rarity: wild?.rarity ?? 'Unknown'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final glowController = AnimationController(
      duration: const Duration(milliseconds: 1),
      vsync: Navigator.of(context),
    ); // static glow

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassContainer(
        accentColor: accent,
        glowController: glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text(title.toUpperCase(), style: _TextStyles.sectionTitle),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyStrip extends StatelessWidget {
  final List<PartyMember> party;
  final PartyMember? selected;
  final ValueChanged<PartyMember> onPick;

  const _PartyStrip({
    required this.party,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (party.isEmpty) {
      return Center(
        child: Text('No team members available', style: _TextStyles.hint),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: party.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final p = party[i];
        final isSel = selected?.instanceId == p.instanceId;
        return _PartyCard(member: p, selected: isSel, onTap: () => onPick(p));
      },
    );
  }
}

class _FooterBar extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final Color primaryColor;
  final VoidCallback? onBreed;
  final VoidCallback onAbort;

  const _FooterBar({
    required this.busy,
    required this.enabled,
    required this.primaryColor,
    required this.onBreed,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(.14)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: enabled ? onBreed : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: enabled
                          ? LinearGradient(
                              colors: [
                                primaryColor.withOpacity(.95),
                                primaryColor.withOpacity(.8),
                              ],
                            )
                          : null,
                      color: enabled ? null : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(.18)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (busy)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.science_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          busy ? 'Processing...' : 'Initiate Breeding',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onAbort,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_outlined,
                          color: _TextStyles.softText,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text('Abort', style: _TextStyles.cardTitle),
                      ],
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

/// Stats panel: partner with nature/size/tint and stamina.
class _StatsPanel extends StatelessWidget {
  final Creature? wild; // kept for callsite compatibility, not used here
  final PartyMember? selection;
  const _StatsPanel({required this.wild, required this.selection});

  @override
  Widget build(BuildContext context) {
    if (selection == null) {
      return Text(
        'Select a partner to view detailed stats.',
        style: _TextStyles.hint,
      );
    }

    final repo = context.read<CreatureRepository>();
    final adb = context.read<AlchemonsDatabase>();

    return FutureBuilder<db.CreatureInstance?>(
      future: adb.getInstance(selection!.instanceId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final inst = snap.data!;
        final base = repo.getCreatureById(inst.baseId);
        final Genetics? g = _geneticsFromJson(inst.geneticsJson);
        final partnerName = base?.name ?? inst.baseId;
        final nature = inst.natureId ?? base?.nature?.id ?? '—';
        final size = _sizeName(g);
        final tint = _tintName(g);
        final stamina = inst.staminaBars;
        final maxStamina = inst.staminaMax;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsRowHeader(label: 'Partner'),
            const SizedBox(height: 8),
            _EntityStatsRow(
              preview: _TintedSpritePreview(
                spritePath: base?.spriteData?.spriteSheetPath,
                frames: base?.spriteData?.totalFrames ?? 1,
                rows: base?.spriteData?.rows ?? 1,
                frameW: base?.spriteData?.frameWidth?.toDouble() ?? 64,
                frameH: base?.spriteData?.frameHeight?.toDouble() ?? 64,
                genetics: g,
                prismatic: inst.isPrismaticSkin == true,
              ),
              name: partnerName,
              chips: [
                _StatChip(
                  icon: Icons.psychology,
                  label: 'Nature',
                  value: nature,
                ),
                _StatChip(icon: Icons.height, label: 'Size', value: size),
                _StatChip(
                  icon: Icons.palette,
                  label: 'Tint',
                  value: tint,
                  swatch: _TintDot(color: _tintSwatchColor(g)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StaminaBar(current: stamina, max: maxStamina),
                ),
                const SizedBox(width: 8),
                Text('$stamina/$maxStamina', style: _TextStyles.cardSmallTitle),
              ],
            ),
          ],
        );
      },
    );
  }
}
// ---------- Small stat building blocks ----------

class _StatsRowHeader extends StatelessWidget {
  final String label;
  const _StatsRowHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: Colors.white.withOpacity(.8)),
        const SizedBox(width: 6),
        Text(label.toUpperCase(), style: _TextStyles.sectionTitle),
      ],
    );
  }
}

class _DividerThin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white.withOpacity(.08));
  }
}

class _EntityStatsRow extends StatelessWidget {
  final Widget preview;
  final String name;
  final List<Widget> chips;

  const _EntityStatsRow({
    required this.preview,
    required this.name,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        preview,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: _TextStyles.cardTitle),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: chips),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? swatch;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.swatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withOpacity(.85)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFFB6C0CC),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (swatch != null) ...[const SizedBox(width: 6), swatch!],
        ],
      ),
    );
  }
}

class _TintDot extends StatelessWidget {
  final Color? color;
  const _TintDot({this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade500;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }
}

// ------------------------------------------------------------
// Shared widgets (reused, with minor tweak to accept borderColor)
// ------------------------------------------------------------

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final AnimationController glowController;

  const _GlassContainer({
    required this.child,
    required this.accentColor,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedBuilder(
          animation: glowController,
          builder: (context, _) {
            final glow = 0.35 + glowController.value * 0.4;
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(glow * 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glow * 0.5),
                    blurRadius: 20 + glowController.value * 14,
                  ),
                ],
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(.35)),
        ),
        child: Icon(icon, color: _TextStyles.softText, size: 18),
      ),
    );
  }
}

class _WildPreviewBox extends StatelessWidget {
  final Creature? creature;
  final Color borderColor;

  const _WildPreviewBox({required this.creature, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    if (creature?.spriteData == null) {
      return Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(Icons.help_outline, color: _TextStyles.mutedText, size: 32),
      );
    }

    final sd = creature!.spriteData!;
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.6), width: 2),
      ),
      padding: const EdgeInsets.all(4),
      child: GameWidget(
        game: _OneSpriteGame(
          spritePath: sd.spriteSheetPath,
          frames: sd.totalFrames,
          rows: sd.rows,
          frameSize: Vector2(
            sd.frameWidth.toDouble(),
            sd.frameHeight.toDouble(),
          ),
          stepTime: sd.frameDurationMs / 1000.0,
          genetics: creature!.genetics,
          prismatic: creature!.isPrismaticSkin == true,
        ),
      ),
    );
  }
}

/// A tiny sprite preview that tints/size-scales using Genetics.
class _TintedSpritePreview extends StatelessWidget {
  final String? spritePath;
  final int frames;
  final int rows;
  final double frameW;
  final double frameH;
  final Genetics? genetics;
  final bool prismatic;

  const _TintedSpritePreview({
    required this.spritePath,
    required this.frames,
    required this.rows,
    required this.frameW,
    required this.frameH,
    required this.genetics,
    required this.prismatic,
  });

  factory _TintedSpritePreview.fromCreature(Creature? c) {
    final sd = c?.spriteData;
    return _TintedSpritePreview(
      spritePath: sd?.spriteSheetPath,
      frames: sd?.totalFrames ?? 1,
      rows: sd?.rows ?? 1,
      frameW: (sd?.frameWidth ?? 64).toDouble(),
      frameH: (sd?.frameHeight ?? 64).toDouble(),
      genetics: c?.genetics,
      prismatic: c?.isPrismaticSkin == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (spritePath == null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(.18)),
        ),
        child: Icon(Icons.image_not_supported, color: Colors.white54, size: 18),
      );
    }

    final border = _tintSwatchColor(genetics) ?? Colors.white24;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withOpacity(.7), width: 2),
        color: Colors.white.withOpacity(.03),
      ),
      padding: const EdgeInsets.all(3),
      child: GameWidget(
        game: _OneSpriteGame(
          spritePath: spritePath!,
          frames: frames,
          rows: rows,
          frameSize: Vector2(frameW, frameH),
          stepTime: .08,
          genetics: genetics,
          prismatic: prismatic,
        ),
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  final PartyMember member;
  final bool selected;
  final VoidCallback onTap;

  const _PartyCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dbInstance = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green.shade400.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.green.shade400
                : Colors.white.withOpacity(0.25),
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.green.shade400.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: FutureBuilder<db.CreatureInstance?>(
          future: dbInstance.getInstance(member.instanceId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            final inst = snap.data!;
            final base = repo.getCreatureById(inst.baseId);
            final displayName = base?.name ?? inst.baseId;
            final stamina = inst.staminaBars;
            final maxStamina = inst.staminaMax;

            final sd = base?.spriteData;
            final genetics = _geneticsFromJson(inst.geneticsJson);

            return Column(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio:
                        1, // keep it perfectly square like the wild preview
                    child: Builder(
                      builder: (context) {
                        final sd = base?.spriteData;
                        final genetics = _geneticsFromJson(inst.geneticsJson);
                        final borderColor =
                            _tintSwatchColor(genetics) ??
                            (base != null
                                ? CreatureFilterUtils.getTypeColor(
                                    base.types.first,
                                  )
                                : Colors.grey.shade600);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: borderColor.withOpacity(0.6),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(
                            4,
                          ), // same padding as wild box
                          child: sd != null
                              ? GameWidget(
                                  game: _OneSpriteGame(
                                    spritePath: sd.spriteSheetPath,
                                    frames: sd.totalFrames,
                                    rows: sd.rows,
                                    frameSize: Vector2(
                                      sd.frameWidth.toDouble(),
                                      sd.frameHeight.toDouble(),
                                    ),
                                    stepTime: sd.frameDurationMs / 1000.0,
                                    genetics: genetics,
                                    prismatic: inst.isPrismaticSkin == true,
                                  ),
                                )
                              : Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.03),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(.15),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: _TextStyles.mutedText,
                                    size: 24,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  style: selected
                      ? _TextStyles.cardTitle
                      : _TextStyles.cardSmallTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _StaminaBar(current: stamina, max: maxStamina),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StaminaBar extends StatelessWidget {
  final int current;
  final int max;

  const _StaminaBar({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (max <= 0) ? 0.0 : (current / max).clamp(0.0, 1.0);
    final color = pct > 0.5
        ? Colors.green.shade400
        : pct > 0.2
        ? Colors.orange.shade400
        : Colors.red.shade400;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 6,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.7), color],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Dialog & Flame game (unchanged behavior)
// ------------------------------------------------------------

class _ResultDialog extends StatelessWidget {
  final Creature baby;
  final int? slotIndex;
  final Duration? hatchIn;
  final bool enqueued;

  const _ResultDialog({
    required this.baby,
    this.slotIndex,
    this.hatchIn,
    required this.enqueued,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade400.withOpacity(0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.science_outlined,
                  color: Colors.green.shade400,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text('Breeding Success!', style: _TextStyles.resultTitle),
                const SizedBox(height: 12),
                Text(
                  enqueued
                      ? 'Embryo secured in research queue for incubation.'
                      : 'Embryo placed in laboratory incubator for development.',
                  style: _TextStyles.description,
                  textAlign: TextAlign.center,
                ),
                if (hatchIn != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Estimated development: ${_formatDuration(hatchIn!)}',
                    style: _TextStyles.resultEta,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _OneSpriteGame extends FlameGame {
  final String spritePath;
  final int frames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;
  final Genetics? genetics;
  final bool prismatic;

  _OneSpriteGame({
    required this.spritePath,
    required this.frames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    required this.genetics,
    required this.prismatic,
  });

  @override
  Future<void> onLoad() async {
    final box = Vector2(size.x, size.y);
    final scale = scaleFromGenes(genetics);

    add(
      CreatureSpriteComponent(
          spritePath: spritePath,
          totalFrames: frames,
          rows: rows,
          frameSize: frameSize,
          stepTime: stepTime,
          scaleFactor: scale,
          saturation: satFromGenes(genetics),
          brightness: briFromGenes(genetics),
          baseHueShift: hueFromGenes(genetics),
          isPrismatic: prismatic,
          desiredSize: box,
        )
        ..anchor = Anchor.center
        ..position = box / 2,
    );
  }
}

// ------------------------------------------------------------
// Helpers (labels, genetics, tint color)
// ------------------------------------------------------------

const Map<String, String> _sizeLabels = {
  'micro': 'Micro',
  'small': 'Small',
  'normal': 'Standard',
  'large': 'Large',
  'giant': 'Giant',
};

const Map<String, String> _tintLabels = {
  'normal': 'Standard',
  'warm': 'Warm',
  'cool': 'Cool',
  'vibrant': 'Vibrant',
  'muted': 'Muted',
  'ashen': 'Ashen',
  'verdant': 'Verdant',
  'fiery': 'Fiery',
  'aqua': 'Aqua',
};

String _sizeName(Genetics? g) {
  final raw = g?.get('size') ?? 'normal';
  return _sizeLabels[raw] ?? _capitalize(raw);
}

String _tintName(Genetics? g) {
  final raw = g?.get('tinting') ?? 'normal';
  return _tintLabels[raw] ?? _capitalize(raw);
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Genetics? _geneticsFromJson(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return null;
  try {
    final m = Map<String, dynamic>.from(jsonDecode(jsonStr));
    return Genetics(m.map((k, v) => MapEntry(k, v.toString())));
  } catch (_) {
    return null;
  }
}

Color? _tintSwatchColor(Genetics? g) {
  if (g == null) return null;
  final hue = hueFromGenes(g); // degrees
  final sat = satFromGenes(g).clamp(0.0, 1.0);
  final bri = briFromGenes(g).clamp(0.0, 1.0);
  final h = ((hue % 360) + 360) % 360;
  return HSVColor.fromAHSV(1.0, h, sat, math.max(.35, bri)).toColor();
}

// ------------------------------------------------------------
// Text styles
// ------------------------------------------------------------

class _TextStyles {
  static const softText = Color(0xFFE8EAED);
  static const mutedText = Color(0xFFB6C0CC);

  static const headerTitle = TextStyle(
    color: softText,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
  );

  static const sectionTitle = TextStyle(
    color: softText,
    fontSize: 12.5,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );

  static const wildCreatureName = TextStyle(
    color: softText,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );

  static const description = TextStyle(
    color: mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const hint = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const cardTitle = TextStyle(
    color: softText,
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  static const cardSmallTitle = TextStyle(
    color: softText,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static const resultTitle = TextStyle(
    color: softText,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  static TextStyle get resultEta => TextStyle(
    color: mutedText.withOpacity(.9),
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
}
