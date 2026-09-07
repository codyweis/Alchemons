// lib/screens/mystic_altar/boss_altar_detail_screen.dart
//
// Individual boss ritual screen.
// Creature slots orbit on a spinning ellipse carousel — same mechanic as the
// Mystic Altar hub. Drag to spin, tap a slot to snap it to the front and focus
// it. Tap the focused slot a second time to place an Alchemon.

import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFF060912);
  static const surface = Color(0xFF111320);
  static const border = Color(0xFF252840);
  static const muted = Color(0xFF4A3F6B);
  static const sub = Color(0xFF8C7BB5);
  static const gold = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFC0392B);

  // Ivory rite palette — neutral chrome, element color only as accent.
  static const ivory = Color(0xFFE8DFC8);
  static const ivoryDim = Color(0xFFB5A98A);
  static const ivoryMuted = Color(0xFF6B6050);
}

TextStyle _titleStyle(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

TextStyle _display(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) => _titleStyle(
  context,
  size,
  color,
  weight: weight,
  letterSpacing: letterSpacing,
  fontStyle: fontStyle,
);

TextStyle _body(
  BuildContext context,
  double size,
  Color color, {
  double height = 1.5,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class _WitnessRequirement {
  const _WitnessRequirement({
    required this.bossId,
    required this.label,
    required this.color,
    required this.completed,
  });

  final String bossId;
  final String label;
  final Color color;
  final bool completed;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BossAltarDetailScreen extends StatefulWidget {
  final AltarEntry boss;
  const BossAltarDetailScreen({super.key, required this.boss});

  @override
  State<BossAltarDetailScreen> createState() => _BossAltarDetailScreenState();
}

class _BossAltarDetailScreenState extends State<BossAltarDetailScreen>
    with TickerProviderStateMixin {
  // ── ambient pulse ─────────────────────────────────────────────────────────
  late final AnimationController _pulse;
  late final AnimationController _ritualCtrl;

  // ── carousel spin ─────────────────────────────────────────────────────────
  double _wheelOffset = 0.0;
  int _selectedIndex = 0;
  late final AnimationController _snapCtrl;
  late Animation<double> _snapAnim;
  double _snapFrom = 0.0;

  // ── placement data ────────────────────────────────────────────────────────
  final Map<String, String?> _placed = {};
  List<Creature> _species = [];
  Creature? _mystic;
  List<_WitnessRequirement> _bloodWitnesses = const [];
  bool _hasKey = false;
  bool _relicPlaced = false;
  bool _loading = true;
  bool _summoning = false;
  bool _showRitualAnimation = false;
  bool _storyCheckStarted = false;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _ritualCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _snapAnim = AlwaysStoppedAnimation(_wheelOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
      _maybeShowBossRelicStoryIntro();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ritualCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _loadState() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();

    final traitKey = BossLootKeys.traitKeyForElement(widget.boss.element);
    final qty = await db.inventoryDao.getItemQty(traitKey);
    final relicPlaced = (await db.altarDao.getRelicPlacedIds([
      widget.boss.id,
    ])).contains(widget.boss.id);
    final placements = await db.altarDao.getPlacementsForBoss(widget.boss.id);
    final mystic = catalog.mysticByElement(widget.boss.element);
    final species = catalog
        .byType(widget.boss.element)
        .where((s) => s.id != mystic?.id)
        .toList();
    final bloodWitnesses = <_WitnessRequirement>[];

    if (_isBloodBoss) {
      for (final boss in kAltarEntries.where((b) => b.order < 17)) {
        final summonedValue = await db.settingsDao.getSetting(
          'altar_summoned_${boss.id}',
        );
        final summoned =
            summonedValue != null && summonedValue.trim().isNotEmpty;
        bloodWitnesses.add(
          _WitnessRequirement(
            bossId: boss.id,
            label: catalog.mysticByElement(boss.element)?.name ?? boss.name,
            color: boss.elementColor,
            completed: summoned,
          ),
        );
      }
    }

    final placed = <String, String?>{};
    for (final sp in species) {
      placed[sp.id] = null;
    }
    for (final p in placements) {
      placed[p.speciesId] = p.instanceId;
    }

    if (mounted) {
      setState(() {
        _hasKey = relicPlaced || qty > 0;
        _relicPlaced = relicPlaced;
        _mystic = mystic;
        _species = species;
        _bloodWitnesses = bloodWitnesses;
        _placed
          ..clear()
          ..addAll(placed);
        _loading = false;
      });
    }
  }

  Future<void> _maybeShowBossRelicStoryIntro() async {
    if (_storyCheckStarted || !mounted) return;
    _storyCheckStarted = true;

    final db = context.read<AlchemonsDatabase>();
    final hasSeen = await db.settingsDao.hasSeenBossRelicScreenStoryIntro();
    if (!hasSeen && mounted) {
      await LandscapeDialog.show(
        context,
        title: 'A Relic Is Not A Trophy',
        icon: AppIcons.album_outlined,
        typewriter: true,
        message:
            'It is what remains when form fails. Not the creature, not its beauty, but the instruction that endured beneath both.\n\n'
            'Is creation discovery or concealment, is beauty truth made visible, or a veil drawn over something worse.',
      );

      if (!mounted) return;
      await db.settingsDao.setBossRelicScreenStoryIntroSeen();
    }

    if (!_isBloodBoss || !mounted) return;
    final hasSeenBloodIntro =
        await db.settingsDao.getSetting(
          'blood_mystic_relic_story_intro_seen_v1',
        ) ==
        '1';
    if (hasSeenBloodIntro || !mounted) return;

    await LandscapeDialog.show(
      context,
      title: 'Not A Return',
      icon: AppIcons.auto_awesome_outlined,
      typewriter: true,
      message:
          'A relic does not bring something back. It gives the surviving instruction a body again.\n\n'
          'If the mystics were made to guard what this world could not bear, then Sanguorath is what remains when sacrifice itself is taught to take shape.',
    );

    if (!mounted) return;
    await db.settingsDao.setSetting(
      'blood_mystic_relic_story_intro_seen_v1',
      '1',
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  bool get _isBloodBoss => widget.boss.element.toLowerCase() == 'blood';

  bool get _allFilled =>
      _species.isNotEmpty && _species.every((s) => _placed[s.id] != null);

  bool get _allWitnessed =>
      !_isBloodBoss ||
      (_bloodWitnesses.isNotEmpty && _bloodWitnesses.every((w) => w.completed));

  int get _witnessRemaining =>
      _bloodWitnesses.where((w) => !w.completed).length;

  bool get _canSummon => _hasKey && _allFilled && _allWitnessed && !_summoning;

  String _traitName() {
    final meta = BossLootKeys.elementRewards[widget.boss.element.toLowerCase()];
    return meta?.traitName ?? 'Key Item';
  }

  void _snack(String msg) {
    if (!mounted) return;
    final elColor = widget.boss.elementColor;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.error_outline_rounded,
              color: elColor.withValues(alpha: 0.95),
              size: 17,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: _C.ivory,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B0D14),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: Border(
          left: BorderSide(color: elColor.withValues(alpha: 0.72), width: 2),
          top: BorderSide(color: elColor.withValues(alpha: 0.28), width: 1),
          bottom: BorderSide(color: elColor.withValues(alpha: 0.20), width: 1),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── carousel helpers ───────────────────────────────────────────────────────

  int get _n => _species.length;

  double _slotAngle(int i) {
    final raw = _wheelOffset + (i / _n) * math.pi * 2;
    return _norm(raw);
  }

  double _norm(double a) {
    while (a > math.pi) {
      a -= math.pi * 2;
    }
    while (a < -math.pi) {
      a += math.pi * 2;
    }
    return a;
  }

  // depth 0 = back, 1 = front (angle near 0 = bottom of ellipse = front)
  double _depth(int i) => (math.cos(_slotAngle(i)) + 1) / 2;

  void _onPanUpdate(DragUpdateDetails d) {
    _snapCtrl.stop();
    setState(() {
      _wheelOffset += d.delta.dx * 0.013;
      _updateSelected();
    });
  }

  void _onPanEnd(DragEndDetails _) => _snapToSelected();

  void _updateSelected() {
    double minD = double.infinity;
    for (int i = 0; i < _n; i++) {
      final d = _slotAngle(i).abs();
      if (d < minD) {
        minD = d;
        _selectedIndex = i;
      }
    }
  }

  void _snapToSelected() {
    double t = -(_selectedIndex / _n) * math.pi * 2;
    while ((t - _wheelOffset) > math.pi) {
      t -= math.pi * 2;
    }
    while ((t - _wheelOffset) < -math.pi) {
      t += math.pi * 2;
    }

    _snapFrom = _wheelOffset;
    _snapCtrl.reset();
    _snapAnim = Tween<double>(begin: _snapFrom, end: t).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutBack),
    )..addListener(() => setState(() => _wheelOffset = _snapAnim.value));
    _snapCtrl.forward();
  }

  void _snapToIndex(int idx) {
    if (idx < 0 || idx >= _n) return;
    setState(() => _selectedIndex = idx);
    HapticFeedback.lightImpact();
    _snapToSelected();
  }

  // ── placement ──────────────────────────────────────────────────────────────

  Future<void> _handlePlaceAlchemon(Creature sp) async {
    if (_placed[sp.id] != null) return;
    final db = context.read<AlchemonsDatabase>();

    final all = await db.creatureDao.listInstancesBySpecies(sp.id);
    final avail = all.where((i) => !i.locked).toList();
    if (avail.isEmpty) {
      _snack('No ${sp.name} available.');
      return;
    }

    if (!mounted) return;
    final picked = await showModalBottomSheet<CreatureInstance>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstancePickerSheet(
        species: sp,
        instances: avail,
        elColor: widget.boss.elementColor,
      ),
    );
    if (picked == null || !mounted) return;

    final ok = await _confirmPlace(sp, picked);
    if (!ok || !mounted) return;

    // Snapshot genetic Potential before the instance is deleted. Current
    // Power, level, and Enhancement are individual training and never pass on.
    final snapshot = jsonEncode({
      'natureId': picked.natureId,
      'natureId2': picked.natureId2,
      'scaleVersion': 2,
      'speedPotential': picked.statSpeedPotential,
      'intelligencePotential': picked.statIntelligencePotential,
      'strengthPotential': picked.statStrengthPotential,
      'beautyPotential': picked.statBeautyPotential,
    });

    await db.altarDao.placeAlchemon(
      bossId: widget.boss.id,
      speciesId: sp.id,
      instanceId: picked.instanceId,
      snapshotJson: snapshot,
    );
    await db.creatureDao.deleteInstances([picked.instanceId]);

    HapticFeedback.mediumImpact();
    setState(() => _placed[sp.id] = picked.instanceId);
  }

  Future<bool> _confirmPlace(Creature sp, CreatureInstance inst) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => _GameDialog(
          elColor: widget.boss.elementColor,
          icon: AppIcons.warning_amber_rounded,
          iconColor: _C.gold,
          title: 'COMMIT ALCHEMON?',
          body:
              'Placing ${inst.nickname ?? sp.name} is permanent, it will be consumed by the ritual.',
          cancelLabel: 'CANCEL',
          confirmLabel: 'COMMIT',
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ) ??
      false;

  // ── summon ─────────────────────────────────────────────────────────────────

  Future<void> _handleSummon() async {
    if (!_canSummon) return;
    final ok = await _confirmSummon();
    if (!ok || !mounted) return;

    setState(() => _summoning = true);
    HapticFeedback.heavyImpact();

    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final boss = widget.boss;

    try {
      // Read placements FIRST (we need their snapshots), then clear them.
      final placements = await db.altarDao.getPlacementsForBoss(boss.id);
      final sacrificePayload = _deriveFromSacrifices(placements);

      await db.altarDao.clearPlacementsForBoss(boss.id);
      if (!_relicPlaced) {
        await db.altarDao.setRelicPlaced(boss.id);
      }

      final mystic = catalog.mysticByElement(boss.element);
      final fallback = catalog.byType(boss.element).firstOrNull;
      final target = mystic ?? fallback;
      if (target == null) {
        _snack('Error: no species for ${boss.element}.');
        setState(() => _summoning = false);
        return;
      }

      var slot = await db.incubatorDao.firstFreeSlot();
      if (slot == null) {
        final newId = await db.incubatorDao.purchaseFusionSlot();
        slot = await (db.select(
          db.incubatorSlots,
        )..where((t) => t.id.equals(newId))).getSingleOrNull();
      }
      if (slot == null || !mounted) {
        _snack('No open Alchemy Chamber slots.');
        setState(() => _summoning = false);
        return;
      }

      final hatchAt = DateTime.now().toUtc().add(const Duration(hours: 1));
      final eggId =
          'boss_summon_${boss.id}_${DateTime.now().millisecondsSinceEpoch}';
      await db.incubatorDao.placeEgg(
        slotId: slot.id,
        eggId: eggId,
        resultCreatureId: target.id,
        rarity: 'Mythic',
        hatchAtUtc: hatchAt,
        payloadJson: jsonEncode(_payload(target, boss, sacrificePayload)),
      );

      await db.settingsDao.setSetting(
        'altar_summoned_${boss.id}',
        DateTime.now().toUtc().toIso8601String(),
      );

      if (!mounted) return;
      await _playRitualAnimation();
      if (!mounted) return;
      setState(() => _summoning = false);
      await _showSuccess(target, boss);
    } catch (e) {
      debugPrint('Summon error: $e');
      if (mounted) _snack('Summoning failed. Try again.');
    } finally {
      if (mounted) setState(() => _summoning = false);
    }
  }

  Future<void> _playRitualAnimation() async {
    if (!mounted) return;
    setState(() => _showRitualAnimation = true);
    _ritualCtrl
      ..stop()
      ..value = 0;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    await _ritualCtrl.forward();
    if (!mounted) return;
    setState(() => _showRitualAnimation = false);
  }

  /// Parses placement snapshots and returns the dominant nature plus averaged
  /// genetic Potential. Mystic rituals reward strong sacrifices with a modest
  /// +10 Potential lift without inheriting current Power or Enhancement.
  Map<String, dynamic> _deriveFromSacrifices(List<AltarPlacement> placements) {
    final natureCounts = <String, int>{};
    double totalSpeed = 0;
    double totalIntelligence = 0;
    double totalStrength = 0;
    double totalBeauty = 0;
    int count = 0;

    for (final p in placements) {
      if (p.snapshotJson == null) continue;
      try {
        final snap = jsonDecode(p.snapshotJson!) as Map<String, dynamic>;
        for (final natureId in [snap['natureId'], snap['natureId2']]) {
          if (natureId is String && natureId.isNotEmpty) {
            natureCounts[natureId] = (natureCounts[natureId] ?? 0) + 1;
          }
        }
        final version = (snap['scaleVersion'] as num?)?.toInt() ?? 1;
        double potential(String key, String legacyKey) {
          final direct = snap[key] as num?;
          if (direct != null) {
            return AlchemonStatSystem.normalizePotential(
              direct,
              legacyScale: version < 2 && direct <= 5,
            ).toDouble();
          }
          // Placements made before the Potential migration only retained a
          // current 0-5 stat snapshot. Convert it once for save compatibility.
          final legacy = (snap[legacyKey] as num?)?.toDouble() ?? 3.0;
          return AlchemonStatSystem.normalizePotential(
            legacy,
            legacyScale: true,
          ).toDouble();
        }

        totalSpeed += potential('speedPotential', 'speed');
        totalIntelligence += potential('intelligencePotential', 'intelligence');
        totalStrength += potential('strengthPotential', 'strength');
        totalBeauty += potential('beautyPotential', 'beauty');
        count++;
      } catch (_) {
        // Malformed snapshot — skip, defaults will be used.
      }
    }

    // Dominant nature = most common; ties are broken by first encountered.
    final dominantNatures = natureCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const mysticBonus = 10.0;
    double avg(double total) =>
        count > 0 ? (total / count + mysticBonus).clamp(1.0, 100.0) : 75.0;

    return {
      'natureId': dominantNatures.isEmpty ? null : dominantNatures.first.key,
      'natureId2': dominantNatures.length < 2 ? null : dominantNatures[1].key,
      'speed': avg(totalSpeed),
      'intelligence': avg(totalIntelligence),
      'strength': avg(totalStrength),
      'beauty': avg(totalBeauty),
    };
  }

  Map<String, dynamic> _payload(
    Creature sp,
    AltarEntry boss,
    Map<String, dynamic> sacrificePayload,
  ) => {
    'baseId': sp.id,
    'rarity': 'Mythic',
    'source': 'boss_summon',
    'bossId': boss.id,
    'bossName': boss.name,
    'element': boss.element,
    'isPrismaticSkin': false,
    'genetics': {},
    if (sacrificePayload['natureId'] != null)
      'natureId': sacrificePayload['natureId'],
    if (sacrificePayload['natureId2'] != null)
      'natureId2': sacrificePayload['natureId2'],
    'stats': {
      'speed': 0.0,
      'intelligence': 0.0,
      'strength': 0.0,
      'beauty': 0.0,
    },
    'statPotentials': {
      'scaleVersion': 2,
      'speed': sacrificePayload['speed'],
      'intelligence': sacrificePayload['intelligence'],
      'strength': sacrificePayload['strength'],
      'beauty': sacrificePayload['beauty'],
    },
    'lineage': {
      'generationDepth': 0,
      'factionLineage': {},
      'elementLineage': {boss.element.toLowerCase(): 1},
      'familyLineage': {},
    },
  };

  Future<bool> _confirmSummon() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => _GameDialog(
          elColor: widget.boss.elementColor,
          icon: widget.boss.elementIcon,
          iconColor: widget.boss.elementColor,
          title: 'PERFORM RITUAL?',
          body:
              'Summoning ${widget.boss.name} will consume the committed Alchemons. The ${_traitName()} remains bound to the altar. A Mystic Vial will be placed in your Chamber.',
          cancelLabel: 'CANCEL',
          confirmLabel: 'SUMMON',
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ) ??
      false;

  Future<void> _showSuccess(Creature sp, AltarEntry boss) async {
    if (boss.element.toLowerCase() == 'blood') {
      final db = context.read<AlchemonsDatabase>();
      final seen =
          await db.settingsDao.getSetting('blood_mystic_space_hint_seen_v1') ==
          '1';
      if (!seen && mounted) {
        await LandscapeDialog.show(
          context,
          title: 'Carry It Outward',
          icon: AppIcons.public_rounded,
          typewriter: true,
          message:
              'Do not keep it here.\n\nThe stars are not above this world. They are part of the seal. Bring the blood mystic outward, where the last offering can be witnessed.',
        );
        if (mounted) {
          await db.settingsDao.setSetting(
            'blood_mystic_space_hint_seen_v1',
            '1',
          );
        }
      }
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        boss: boss,
        species: sp,
        onClose: () => Navigator.pop(ctx),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final boss = widget.boss;
    final elColor = boss.elementColor;
    final filled = _species.where((s) => _placed[s.id] != null).length;
    final total = _species.length;

    final selFilled =
        _species.isNotEmpty && _placed[_species[_selectedIndex].id] != null;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: AlchemicalParticleBackground(backgroundColor: _C.bg),
          ),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED),
                      strokeWidth: 1.5,
                    ),
                  )
                : Column(
                    children: [
                      _TopBar(
                        boss: boss,
                        mystic: _mystic,
                        hasKey: _hasKey,
                        traitName: _traitName(),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onPanUpdate: _n > 1 ? _onPanUpdate : null,
                          onPanEnd: _n > 1 ? _onPanEnd : null,
                          behavior: HitTestBehavior.opaque,
                          child: _CarouselArena(
                            boss: boss,
                            mystic: _mystic,
                            species: _species,
                            placed: _placed,
                            pulse: _pulse,
                            selectedIndex: _selectedIndex,
                            depthOf: _depth,
                            angleOf: _slotAngle,
                            onTapSlot: (i) {
                              if (i == _selectedIndex) {
                                // already front → place
                                _handlePlaceAlchemon(_species[i]);
                              } else {
                                _snapToIndex(i);
                              }
                            },
                          ),
                        ),
                      ),
                      _BottomBar(
                        filled: filled,
                        total: total,
                        canSummon: _canSummon,
                        hasKey: _hasKey,
                        allFilled: _allFilled,
                        witnesses: _bloodWitnesses,
                        witnessRemaining: _witnessRemaining,
                        summoning: _summoning,
                        elColor: elColor,
                        pulse: _pulse,
                        selectedFilled: selFilled,
                        selectedName: _species.isNotEmpty
                            ? _species[_selectedIndex].name
                            : '',
                        onSummon: _handleSummon,
                        onPlace: _species.isNotEmpty
                            ? () =>
                                  _handlePlaceAlchemon(_species[_selectedIndex])
                            : null,
                        onPrev: _n > 1
                            ? () => _snapToIndex((_selectedIndex - 1 + _n) % _n)
                            : null,
                        onNext: _n > 1
                            ? () => _snapToIndex((_selectedIndex + 1) % _n)
                            : null,
                      ),
                    ],
                  ),
          ),
          if (_showRitualAnimation)
            Positioned.fill(
              child: _RitualSacrificeOverlay(
                animation: _ritualCtrl,
                boss: boss,
                mystic: _mystic,
                species: _species,
                placed: _placed,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final AltarEntry boss;
  final Creature? mystic;
  final bool hasKey;
  final String traitName;
  const _TopBar({
    required this.boss,
    this.mystic,
    required this.hasKey,
    required this.traitName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          _BackBracketButton(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mystic?.name ?? boss.name,
                  style: _display(context, 24, _C.ivory, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  '${boss.element} mystic ritual',
                  style: _display(
                    context,
                    13,
                    _C.ivoryMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          _RelicStatusChip(boss: boss, hasKey: hasKey, traitName: traitName),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAROUSEL ARENA  — ellipse turntable with mystic in the center
// ─────────────────────────────────────────────────────────────────────────────

class _CarouselArena extends StatelessWidget {
  final AltarEntry boss;
  final Creature? mystic;
  final List<Creature> species;
  final Map<String, String?> placed;
  final Animation<double> pulse;
  final int selectedIndex;
  final double Function(int) depthOf;
  final double Function(int) angleOf;
  final void Function(int) onTapSlot;

  const _CarouselArena({
    required this.boss,
    required this.mystic,
    required this.species,
    required this.placed,
    required this.pulse,
    required this.selectedIndex,
    required this.depthOf,
    required this.angleOf,
    required this.onTapSlot,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final cx = w / 2;
        final cy = h * 0.46;

        // Ellipse radii
        final rx = w * 0.36;
        final ry = h * 0.22;

        final n = species.length;

        // Depth-sort so closer nodes paint on top
        final sorted = List.generate(n, (i) => i)
          ..sort((a, b) => depthOf(a).compareTo(depthOf(b)));

        final filledCount = placed.values.where((v) => v != null).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Orbit track + progress arc
            Positioned.fill(
              child: AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => CustomPaint(
                  painter: _TrackPainter(
                    color: boss.elementColor,
                    cx: cx,
                    cy: cy,
                    rx: rx,
                    ry: ry,
                    pulse: pulse.value,
                    placedCount: filledCount,
                    total: n,
                  ),
                ),
              ),
            ),

            // Creature slot nodes
            for (final i in sorted) _buildNode(i, cx, cy, rx, ry),

            // Center mystic
            Positioned(
              left: cx - 54,
              top: cy - 54,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => _CenterMystic(
                  mystic: mystic,
                  boss: boss,
                  pulse: pulse.value,
                  size: 108,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNode(int i, double cx, double cy, double rx, double ry) {
    final angle = angleOf(i);
    final depth = depthOf(i);
    final x = cx + rx * math.sin(angle);
    final y = cy + ry * math.cos(angle);
    final scale = 0.50 + 0.50 * depth;
    final opacity = (0.20 + 0.80 * depth).clamp(0.0, 1.0);
    const base = 64.0;
    final nodeSize = base * scale;
    final isSel = i == selectedIndex;
    final isFilled = placed[species[i].id] != null;

    return Positioned(
      left: x - nodeSize / 2,
      top: y - nodeSize / 2,
      child: GestureDetector(
        onTap: () => onTapSlot(i),
        child: AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Opacity(
            opacity: opacity,
            child: _SlotNode(
              key: ValueKey(species[i].id),
              species: species[i],
              size: nodeSize,
              isFilled: isFilled,
              isSelected: isSel,
              elColor: boss.elementColor,
              pulse: pulse.value,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLOT NODE
// ─────────────────────────────────────────────────────────────────────────────

class _SlotNode extends StatefulWidget {
  final Creature species;
  final double size, pulse;
  final bool isFilled, isSelected;
  final Color elColor;

  const _SlotNode({
    super.key,
    required this.species,
    required this.size,
    required this.pulse,
    required this.isFilled,
    required this.isSelected,
    required this.elColor,
  });

  @override
  State<_SlotNode> createState() => _SlotNodeState();
}

class _SlotNodeState extends State<_SlotNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _placeCtrl;

  @override
  void initState() {
    super.initState();
    _placeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(_SlotNode old) {
    super.didUpdateWidget(old);
    if (!old.isFilled && widget.isFilled) {
      _placeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _placeCtrl,
      builder: (_, __) => _buildContent(_placeCtrl.value),
    );
  }

  Widget _buildContent(double t) {
    // t = 0..1 over 900ms; drives the placement burst
    final scale = 1.0 + 0.28 * math.sin(t * math.pi);
    final ringScale1 = 1.0 + t * 2.0;
    final ringOpacity1 = widget.isFilled ? (1.0 - t).clamp(0.0, 1.0) : 0.0;
    final t2 = ((t - 0.15) / 0.85).clamp(0.0, 1.0);
    final ringScale2 = 1.0 + t2 * 1.6;
    final ringOpacity2 = widget.isFilled
        ? (1.0 - t2).clamp(0.0, 1.0) * 0.55
        : 0.0;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // ── Burst ring 1 (placement animation) ──────────────────────────
        if (ringOpacity1 > 0.01)
          Transform.scale(
            scale: ringScale1,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.elColor.withValues(alpha: ringOpacity1 * 0.90),
                  width: 2.5,
                ),
              ),
            ),
          ),

        // ── Burst ring 2 (delayed) ───────────────────────────────────────
        if (ringOpacity2 > 0.01)
          Transform.scale(
            scale: ringScale2,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.elColor.withValues(alpha: ringOpacity2),
                  width: 1.5,
                ),
              ),
            ),
          ),

        // ── Main disc (scale pops on placement) ─────────────────────────
        Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: (widget.isFilled || widget.isSelected)
                  ? RadialGradient(
                      colors: [
                        widget.elColor.withValues(
                          alpha: widget.isFilled ? 0.22 : 0.12,
                        ),
                        Colors.transparent,
                      ],
                    )
                  : null,
              color: (widget.isFilled || widget.isSelected)
                  ? null
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: _C.ivoryDim.withValues(
                  alpha: widget.isFilled
                      ? 0.80
                      : widget.isSelected
                      ? 0.55
                      : 0.25,
                ),
                width: widget.isFilled
                    ? 1.6
                    : widget.isSelected
                    ? 1.4
                    : 0.8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.isFilled
                // Full-color lit image
                ? Image.asset(
                    'assets/images/${widget.species.image}',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      AppIcons.auto_awesome,
                      color: widget.elColor,
                      size: widget.size * 0.42,
                    ),
                  )
                // Dark element-tinted silhouette
                : ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Color.lerp(
                        const Color(0xFF06090F),
                        widget.elColor,
                        widget.isSelected ? 0.22 : 0.14,
                      )!,
                      BlendMode.srcIn,
                    ),
                    child: Opacity(
                      opacity: widget.isSelected ? 0.68 : 0.42,
                      child: Image.asset(
                        'assets/images/${widget.species.image}',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          AppIcons.auto_awesome,
                          color: widget.elColor.withValues(alpha: 0.35),
                          size: widget.size * 0.42,
                        ),
                      ),
                    ),
                  ),
          ),
        ),

        // ── Filled check badge ───────────────────────────────────────────
        if (widget.isFilled)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: widget.size * 0.30,
              height: widget.size * 0.30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.success,
                border: Border.all(color: _C.bg, width: 1.5),
              ),
              child: Icon(
                AppIcons.check_rounded,
                color: Colors.white,
                size: widget.size * 0.14,
              ),
            ),
          ),

        // ── "Tap to place" badge when selected + empty ───────────────────
        if (widget.isSelected && !widget.isFilled)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: widget.size * 0.30,
              height: widget.size * 0.30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.elColor,
                border: Border.all(color: _C.bg, width: 1.5),
              ),
              child: Icon(
                AppIcons.add_rounded,
                color: Colors.white,
                size: widget.size * 0.15,
              ),
            ),
          ),

        // ── Name label ───────────────────────────────────────────────────
        Positioned(
          bottom: -19,
          child: SizedBox(
            width: 76,
            child: Text(
              widget.species.name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: widget.isFilled
                    ? _C.ivory
                    : (widget.isSelected
                          ? _C.ivory.withValues(alpha: 0.78)
                          : _C.ivoryMuted),
                fontSize: 12,
                fontWeight: widget.isFilled ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CENTER MYSTIC
// ─────────────────────────────────────────────────────────────────────────────

class _CenterMystic extends StatelessWidget {
  final Creature? mystic;
  final AltarEntry boss;
  final double pulse, size;
  const _CenterMystic({
    required this.mystic,
    required this.boss,
    required this.pulse,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final elColor = boss.elementColor;
    final sheet = mystic?.spriteData != null
        ? sheetFromCreature(mystic!)
        : null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size + 16,
            height: size + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.ivoryDim.withValues(alpha: 0.20),
                width: 1.0,
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [elColor.withValues(alpha: 0.18), Colors.transparent],
              ),
              border: Border.all(
                color: _C.ivoryDim.withValues(alpha: 0.65),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: sheet != null
                ? Center(
                    child: SizedBox.square(
                      dimension: size * 0.90,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox.square(
                          dimension: 69,
                          child: CreatureSprite(
                            spritePath: sheet.path,
                            totalFrames: sheet.totalFrames,
                            rows: sheet.rows,
                            frameSize: sheet.frameSize,
                            stepTime: sheet.stepTime,
                          ),
                        ),
                      ),
                    ),
                  )
                : Icon(boss.elementIcon, color: elColor, size: size * 0.48),
          ),
          Positioned(
            bottom: -22,
            child: Text(
              mystic?.name.toUpperCase() ?? 'MYSTIC',
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: _C.ivory.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RITUAL SACRIFICE OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

class _RitualSacrificeOverlay extends StatelessWidget {
  const _RitualSacrificeOverlay({
    required this.animation,
    required this.boss,
    required this.mystic,
    required this.species,
    required this.placed,
  });

  final Animation<double> animation;
  final AltarEntry boss;
  final Creature? mystic;
  final List<Creature> species;
  final Map<String, String?> placed;

  @override
  Widget build(BuildContext context) {
    final offerings = species.where((s) => placed[s.id] != null).toList();
    final elColor = boss.elementColor;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final t = Curves.easeInOutCubic.transform(animation.value);
          final collapse = _ritualInterval(animation.value, 0.24, 0.74);
          final vanish = _ritualInterval(animation.value, 0.50, 0.86);
          final flash = _ritualInterval(animation.value, 0.70, 0.92);

          return LayoutBuilder(
            builder: (_, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;
              final cx = w / 2;
              final cy = h * 0.48;
              final rx = w * (0.38 - collapse * 0.30);
              final ry = h * (0.20 - collapse * 0.17);
              final spin = animation.value * math.pi * 7.5;
              final n = math.max(offerings.length, 1);

              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.54 + t * 0.42),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RitualSacrificePainter(
                        progress: animation.value,
                        color: elColor,
                      ),
                    ),
                  ),
                  for (var i = 0; i < offerings.length; i++)
                    _OfferingRitualSprite(
                      species: offerings[i],
                      left:
                          cx + rx * math.sin((i / n) * math.pi * 2 + spin) - 34,
                      top:
                          cy + ry * math.cos((i / n) * math.pi * 2 + spin) - 34,
                      size: 68,
                      opacity: (1 - vanish).clamp(0.0, 1.0),
                      scale:
                          1.0 +
                          math.sin(animation.value * math.pi * 18) * 0.07 -
                          collapse * 0.34,
                      color: elColor,
                    ),
                  Positioned(
                    left: cx - 48 - flash * 16,
                    top: cy - 48 - flash * 16,
                    child: Transform.scale(
                      scale: 1.0 + flash * 0.55,
                      child: Opacity(
                        opacity: (0.35 + flash * 0.65).clamp(0.0, 1.0),
                        child: _RitualMysticCore(
                          mystic: mystic,
                          boss: boss,
                          size: 96,
                          progress: animation.value,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferingRitualSprite extends StatelessWidget {
  const _OfferingRitualSprite({
    required this.species,
    required this.left,
    required this.top,
    required this.size,
    required this.opacity,
    required this.scale,
    required this.color,
  });

  final Creature species;
  final double left;
  final double top;
  final double size;
  final double opacity;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale.clamp(0.2, 1.35),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A0507).withValues(alpha: 0.74),
              border: Border.all(
                color: color.withValues(alpha: 0.78),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A0F16).withValues(alpha: 0.28),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                const Color(0xFFB91C1C).withValues(alpha: 0.30),
                BlendMode.srcATop,
              ),
              child: Image.asset(
                'assets/images/${species.image}',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  AppIcons.auto_awesome,
                  color: color,
                  size: size * 0.42,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RitualMysticCore extends StatelessWidget {
  const _RitualMysticCore({
    required this.mystic,
    required this.boss,
    required this.size,
    required this.progress,
  });

  final Creature? mystic;
  final AltarEntry boss;
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final sheet = mystic?.spriteData != null
        ? sheetFromCreature(mystic!)
        : null;
    final color = boss.elementColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF05020A).withValues(alpha: 0.84),
        border: Border.all(
          color: color.withValues(alpha: 0.62 + progress * 0.30),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.36 + progress * 0.24),
            blurRadius: 34,
            spreadRadius: 5,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: sheet != null
          ? FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.square(
                dimension: 69,
                child: CreatureSprite(
                  spritePath: sheet.path,
                  totalFrames: sheet.totalFrames,
                  rows: sheet.rows,
                  frameSize: sheet.frameSize,
                  stepTime: sheet.stepTime,
                ),
              ),
            )
          : Icon(boss.elementIcon, color: color, size: size * 0.46),
    );
  }
}

class _RitualSacrificePainter extends CustomPainter {
  const _RitualSacrificePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final spin = progress * math.pi * 7.5;
    final crack = _ritualInterval(progress, 0.02, 0.24);
    final collapse = _ritualInterval(progress, 0.24, 0.74);
    final burst = _ritualInterval(progress, 0.48, 0.80);
    final fade = 1 - _ritualInterval(progress, 0.82, 1.0);
    final stream = _ritualInterval(progress, 0.32, 0.98);
    final radius = size.shortestSide * (0.33 - collapse * 0.24);

    _paintAltarCracks(canvas, center, size, crack, spin);
    _paintRisingWisps(canvas, size, stream, fade);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final r = radius + i * 18 + math.sin(progress * math.pi * 6 + i) * 4;
      ringPaint
        ..color = Color.lerp(
          color,
          const Color(0xFF8A0F16),
          0.55,
        )!.withValues(alpha: (0.22 + i * 0.06) * fade)
        ..strokeWidth = 1.2 + i * 0.4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r.clamp(22.0, 260.0)),
        spin + i * math.pi / 2,
        math.pi * (0.95 + collapse * 0.8),
        false,
        ringPaint,
      );
    }

    final beamPaint = Paint()
      ..color = const Color(0xFFB91C1C).withValues(alpha: 0.16 * burst * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (var i = 0; i < 10; i++) {
      final a = spin + i * math.pi * 2 / 10;
      canvas.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * (radius + burst * 120),
        beamPaint,
      );
    }

    final splatterPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 42; i++) {
      final seed = i * 12.9898;
      final a = seed % (math.pi * 2) + spin * 0.18;
      final d =
          (24 + (i * 37 % 150).toDouble()) *
          Curves.easeOutCubic.transform(burst);
      final wobble = Offset(
        math.sin(seed * 1.7) * 18,
        math.cos(seed * 2.1) * 14,
      );
      final p = center + Offset(math.cos(a), math.sin(a)) * d + wobble;
      final dot = 2.0 + (i % 5) * 1.3;
      splatterPaint.color = Color.lerp(
        const Color(0xFF5D0710),
        const Color(0xFFE11D48),
        (i % 7) / 7,
      )!.withValues(alpha: (0.18 + (i % 4) * 0.06) * burst * fade);
      canvas.drawCircle(p, dot * (0.6 + burst * 0.7), splatterPaint);

      if (i % 6 == 0) {
        final end = p + Offset(math.cos(a + 0.5), math.sin(a + 0.5)) * 16;
        canvas.drawLine(
          p,
          end,
          Paint()
            ..color = splatterPaint.color.withValues(alpha: 0.35)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    final flash = _ritualInterval(progress, 0.68, 0.90);
    canvas.drawCircle(
      center,
      34 + flash * 140,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.34 * flash * fade),
            const Color(0xFFB91C1C).withValues(alpha: 0.18 * flash * fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 180)),
    );
  }

  void _paintAltarCracks(
    Canvas canvas,
    Offset center,
    Size size,
    double crack,
    double spin,
  ) {
    if (crack <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFF8A0F16).withValues(alpha: 0.34 * crack)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 14; i++) {
      final angle = spin * 0.08 + i * math.pi * 2 / 14;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * 34;
      final length = (54 + (i % 5) * 24) * crack;
      final path = Path()..moveTo(start.dx, start.dy);
      var current = start;
      for (var j = 0; j < 4; j++) {
        final kink =
            angle +
            math.sin(i * 1.7 + j * 2.1) * 0.34 +
            (j.isEven ? 0.18 : -0.12);
        current +=
            Offset(math.cos(kink), math.sin(kink)) *
            (length / 4) *
            (0.70 + j * 0.16);
        path.lineTo(current.dx, current.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintRisingWisps(Canvas canvas, Size size, double stream, double fade) {
    if (stream <= 0) return;
    final paint = Paint()..style = PaintingStyle.stroke;
    final blood = const Color(0xFF8A0F16);
    final ember = Color.lerp(color, const Color(0xFFE8DFC8), 0.22) ?? color;

    for (var i = 0; i < 24; i++) {
      final lane = (i + 0.5) / 24;
      final xBase = size.width * lane;
      final rise = size.height * (0.12 + stream * (0.58 + (i % 5) * 0.045));
      final yBase = size.height * (0.78 - stream * 0.34) + (i % 4) * 18;
      final path = Path()..moveTo(xBase, yBase);

      for (var j = 1; j <= 5; j++) {
        final p = j / 5;
        final wave =
            math.sin(progress * math.pi * 5 + i * 0.81 + j * 0.9) *
            (18 + (i % 4) * 4);
        path.lineTo(xBase + wave * p, yBase - rise * p);
      }

      paint
        ..color = Color.lerp(
          blood,
          ember,
          (i % 6) / 6,
        )!.withValues(alpha: (0.06 + (i % 4) * 0.025) * stream * fade)
        ..strokeWidth = 0.8 + (i % 3) * 0.45;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RitualSacrificePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

double _ritualInterval(double value, double begin, double end) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return Curves.easeInOutCubic.transform((value - begin) / (end - begin));
}

// ─────────────────────────────────────────────────────────────────────────────
// TRACK PAINTER  — orbit ellipse + progress arc
// ─────────────────────────────────────────────────────────────────────────────

class _TrackPainter extends CustomPainter {
  final Color color;
  final double cx, cy, rx, ry, pulse;
  final int placedCount, total;

  const _TrackPainter({
    required this.color,
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.pulse,
    required this.placedCount,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Faint orbit ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Progress arc (drawn as a circular arc at the average radius)
    final r = (rx + ry) / 2;
    if (total > 0 && placedCount > 0) {
      final fraction = placedCount / total;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.35 + pulse * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Inner centre ring
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.44,
      Paint()
        ..color = color.withValues(alpha: 0.04 + pulse * 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.pulse != pulse || old.placedCount != placedCount;
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM BAR
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int filled, total;
  final bool canSummon, hasKey, allFilled, summoning, selectedFilled;
  final List<_WitnessRequirement> witnesses;
  final int witnessRemaining;
  final String selectedName;
  final Color elColor;
  final Animation<double> pulse;
  final VoidCallback onSummon;
  final VoidCallback? onPlace, onPrev, onNext;

  const _BottomBar({
    required this.filled,
    required this.total,
    required this.canSummon,
    required this.hasKey,
    required this.allFilled,
    required this.witnesses,
    required this.witnessRemaining,
    required this.summoning,
    required this.selectedFilled,
    required this.selectedName,
    required this.elColor,
    required this.pulse,
    required this.onSummon,
    required this.onPlace,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        16,
        14,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_C.bg.withValues(alpha: 0.95), _C.bg.withValues(alpha: 0.0)],
        ),
      ),
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pip progress track ───────────────────────────────────────
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < total.clamp(0, 12); i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Container(
                        width: 28,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < filled
                              ? _C.ivoryDim.withValues(alpha: 0.75)
                              : _C.ivoryMuted.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            if (witnesses.isNotEmpty) ...[
              _WitnessSection(witnesses: witnesses, pulse: pulse.value),
              const SizedBox(height: 12),
            ],

            // ── Selected creature row: ‹ name › + place button ───────────
            if (selectedName.isNotEmpty) ...[
              Row(
                children: [
                  // Prev
                  _NavBtn(icon: AppIcons.chevron_left_rounded, onTap: onPrev),
                  const SizedBox(width: 8),
                  // Place / filled button
                  Expanded(
                    child: GestureDetector(
                      onTap: selectedFilled ? null : onPlace,
                      child: _BracketActionButton(
                        label: selectedFilled
                            ? '$selectedName placed'
                            : 'Place $selectedName',
                        icon: selectedFilled
                            ? AppIcons.check_circle_outline_rounded
                            : AppIcons.add_circle_outline_rounded,
                        color: selectedFilled ? _C.success : elColor,
                        enabled: !selectedFilled,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Next
                  _NavBtn(icon: AppIcons.chevron_right_rounded, onTap: onNext),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // ── Summon button ────────────────────────────────────────────
            if (!hasKey || !allFilled || witnessRemaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  !hasKey
                      ? 'Relic required'
                      : !allFilled
                      ? '${total - filled} offering slots remain'
                      : '$witnessRemaining witness${witnessRemaining == 1 ? '' : 'es'} remain',
                  style: _body(
                    context,
                    12,
                    _C.ivoryMuted,
                    weight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: canSummon
                    ? () {
                        HapticFeedback.mediumImpact();
                        onSummon();
                      }
                    : null,
                child: Transform.scale(
                  scale: canSummon ? 1.0 + pulse.value * 0.018 : 1.0,
                  child: CustomPaint(
                    painter: _CornerBracketPainter(
                      color: (canSummon ? elColor : _C.ivoryMuted).withValues(
                        alpha: canSummon ? 0.62 + pulse.value * 0.28 : 0.35,
                      ),
                      bracketSize: 12,
                      strokeWidth: canSummon ? 1.2 : 1.1,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: canSummon
                            ? elColor.withValues(
                                alpha: 0.055 + pulse.value * 0.045,
                              )
                            : Colors.white.withValues(alpha: 0.03),
                        boxShadow: canSummon
                            ? [
                                BoxShadow(
                                  color: elColor.withValues(
                                    alpha: 0.12 + pulse.value * 0.12,
                                  ),
                                  blurRadius: 18 + pulse.value * 12,
                                  spreadRadius: 1 + pulse.value * 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: summoning
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: _C.ivory,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Perform ritual',
                                style: _display(
                                  context,
                                  14,
                                  canSummon ? _C.ivory : _C.ivoryMuted,
                                  letterSpacing: 0.9,
                                ),
                              ),
                      ),
                    ),
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

class _WitnessSection extends StatelessWidget {
  const _WitnessSection({required this.witnesses, required this.pulse});

  final List<_WitnessRequirement> witnesses;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final completed = witnesses.where((w) => w.completed).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _C.bg.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Witnesses  $completed / ${witnesses.length}',
            style: _display(context, 13, _C.ivoryDim, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final witness in witnesses)
                _WitnessChip(witness: witness, pulse: pulse),
            ],
          ),
        ],
      ),
    );
  }
}

class _WitnessChip extends StatelessWidget {
  const _WitnessChip({required this.witness, required this.pulse});

  final _WitnessRequirement witness;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final activeColor = witness.completed
        ? witness.color.withValues(alpha: 0.24 + pulse * 0.06)
        : _C.surface;
    final borderColor = witness.completed
        ? witness.color.withValues(alpha: 0.55 + pulse * 0.10)
        : _C.muted.withValues(alpha: 0.24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: activeColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            witness.completed
                ? AppIcons.check_circle_rounded
                : AppIcons.radio_button_unchecked_rounded,
            color: witness.completed ? witness.color : _C.muted,
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            witness.label.toUpperCase(),
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: witness.completed ? Colors.white : _C.sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: _C.ivoryDim.withValues(alpha: onTap != null ? 0.42 : 0.18),
          bracketSize: 8,
          strokeWidth: 1.0,
        ),
        child: Icon(
          icon,
          color: _C.ivory.withValues(alpha: onTap != null ? 0.85 : 0.25),
          size: 22,
        ),
      ),
    ),
  );
}

class _BackBracketButton extends StatelessWidget {
  const _BackBracketButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _CornerBracketPainter(
            color: _C.ivoryMuted.withValues(alpha: 0.4),
            bracketSize: 8,
            strokeWidth: 1.0,
          ),
          child: const Icon(
            AppIcons.chevron_left_rounded,
            color: _C.ivoryDim,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _RelicStatusChip extends StatelessWidget {
  const _RelicStatusChip({
    required this.boss,
    required this.hasKey,
    required this.traitName,
  });

  final AltarEntry boss;
  final bool hasKey;
  final String traitName;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: _C.ivoryDim.withValues(alpha: hasKey ? 0.52 : 0.28),
        bracketSize: 8,
        strokeWidth: 1.0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: Colors.white.withValues(alpha: 0.03),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            hasKey
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: Image.asset(
                      boss.relicImagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        AppIcons.key_rounded,
                        color: _C.success,
                        size: 12,
                      ),
                    ),
                  )
                : const Icon(
                    AppIcons.lock_outline_rounded,
                    color: _C.danger,
                    size: 12,
                  ),
            const SizedBox(width: 6),
            Text(
              hasKey ? traitName : 'Relic missing',
              style: _display(
                context,
                12,
                _C.ivory.withValues(alpha: hasKey ? 0.95 : 0.55),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketActionButton extends StatelessWidget {
  const _BracketActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: color.withValues(alpha: enabled ? 0.62 : 0.42),
        bracketSize: 10,
        strokeWidth: 1.1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        color: Colors.white.withValues(alpha: 0.03),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _display(context, 13, color, letterSpacing: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({
    required this.color,
    required this.bracketSize,
    required this.strokeWidth,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTANCE PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _InstancePickerSheet extends StatelessWidget {
  final Creature species;
  final List<CreatureInstance> instances;
  final Color elColor;
  const _InstancePickerSheet({
    required this.species,
    required this.instances,
    required this.elColor,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.68;
    final sheetHeight = math.min(maxHeight, 154 + instances.length * 86.0);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: _RitualDialogSurface(
          accent: elColor,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              math.max(14, media.padding.bottom + 10),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _C.ivoryMuted.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SheetSpeciesMark(species: species, color: elColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select ${species.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _display(
                              context,
                              16,
                              _C.ivory,
                              weight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose the specimen to commit.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _body(
                              context,
                              12,
                              _C.ivoryMuted,
                              height: 1.2,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: instances.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (ctx, i) {
                      final inst = instances[i];
                      return _SpecimenPickTile(
                        species: species,
                        instance: inst,
                        color: elColor,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, inst);
                        },
                      );
                    },
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

class _SheetSpeciesMark extends StatelessWidget {
  const _SheetSpeciesMark({required this.species, required this.color});

  final Creature species;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: color.withValues(alpha: 0.50),
          bracketSize: 8,
          strokeWidth: 1.0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/images/${species.image}',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(AppIcons.catching_pokemon_rounded, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SpecimenPickTile extends StatelessWidget {
  const _SpecimenPickTile({
    required this.species,
    required this.instance,
    required this.color,
    required this.onTap,
  });

  final Creature species;
  final CreatureInstance instance;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: color.withValues(alpha: 0.26),
          bracketSize: 10,
          strokeWidth: 0.9,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              color: Colors.black.withValues(alpha: 0.18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.07),
                      border: Border.all(
                        color: color.withValues(alpha: 0.16),
                        width: 0.8,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/images/${species.image}',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          AppIcons.catching_pokemon_rounded,
                          color: color.withValues(alpha: 0.64),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instance.nickname ?? species.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _display(
                            context,
                            14,
                            _C.ivory,
                            weight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Lv ${instance.level} · ${species.rarity}',
                          style: _body(
                            context,
                            12,
                            _C.ivoryMuted,
                            height: 1.2,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CustomPaint(
                    painter: _CornerBracketPainter(
                      color: color.withValues(alpha: 0.54),
                      bracketSize: 7,
                      strokeWidth: 0.9,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        'Select',
                        style: TextStyle(
                          fontFamily: appFontFamily(context),
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _GameDialog extends StatelessWidget {
  final Color elColor, iconColor;
  final IconData icon;
  final String title, body, cancelLabel, confirmLabel;
  final VoidCallback onCancel, onConfirm;

  const _GameDialog({
    required this.elColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: _RitualDialogSurface(
        accent: elColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DialogSigil(icon: icon, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _sentenceCase(title),
                      style: _display(
                        context,
                        15,
                        _C.ivory,
                        weight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                body,
                style: _body(
                  context,
                  13,
                  _C.ivoryDim,
                  height: 1.55,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _Btn(
                      label: cancelLabel,
                      color: _C.ivoryMuted,
                      onTap: onCancel,
                      primary: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Btn(
                      label: confirmLabel,
                      color: elColor,
                      onTap: onConfirm,
                      primary: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RitualDialogSurface extends StatelessWidget {
  const _RitualDialogSurface({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: accent.withValues(alpha: 0.66),
        bracketSize: 18,
        strokeWidth: 1.2,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D14).withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.42), width: 1),
            bottom: BorderSide(color: accent.withValues(alpha: 0.24), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _DialogSigil extends StatelessWidget {
  const _DialogSigil({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: color.withValues(alpha: 0.54),
          bracketSize: 7,
          strokeWidth: 1.0,
        ),
        child: Icon(icon, color: color.withValues(alpha: 0.90), size: 18),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool primary;
  const _Btn({
    required this.label,
    required this.color,
    required this.onTap,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: CustomPaint(
      painter: _CornerBracketPainter(
        color: color.withValues(alpha: primary ? 0.72 : 0.34),
        bracketSize: 9,
        strokeWidth: 1.0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        color: primary
            ? color.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.025),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: primary ? color : _C.ivoryDim,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessDialog extends StatefulWidget {
  final AltarEntry boss;
  final Creature species;
  final VoidCallback onClose;
  const _SuccessDialog({
    required this.boss,
    required this.species,
    required this.onClose,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final el = widget.boss.elementColor;
    final sheet = widget.species.spriteData != null
        ? sheetFromCreature(widget.species)
        : null;

    return FadeTransition(
      opacity: _anim,
      child: Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(_anim),
          child: _RitualDialogSurface(
            accent: el,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DialogMysticPreview(
                        sheet: sheet,
                        fallbackIcon: widget.boss.elementIcon,
                        color: el,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ritual complete',
                              style: _display(
                                context,
                                18,
                                _C.ivory,
                                weight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.species.name} waits in the chamber',
                              style: _body(
                                context,
                                12,
                                _C.ivoryMuted,
                                height: 1.25,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.025),
                      border: Border(
                        left: BorderSide(
                          color: el.withValues(alpha: 0.66),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.science_outlined,
                          color: el.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A Mystic Vial awaits in your Alchemy Chamber. Cultivation: 1 hour.',
                            style: _body(
                              context,
                              12,
                              _C.ivoryDim,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Btn(label: 'DEPART', color: el, onTap: widget.onClose),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogMysticPreview extends StatelessWidget {
  const _DialogMysticPreview({
    required this.sheet,
    required this.fallbackIcon,
    required this.color,
  });

  final SpriteSheetDef? sheet;
  final IconData fallbackIcon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.18),
                  const Color(0xFF05060A).withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.56)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.24),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          if (sheet != null)
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.square(
                dimension: 69,
                child: CreatureSprite(
                  spritePath: sheet!.path,
                  totalFrames: sheet!.totalFrames,
                  rows: sheet!.rows,
                  frameSize: sheet!.frameSize,
                  stepTime: sheet!.stepTime,
                ),
              ),
            )
          else
            Icon(fallbackIcon, color: color, size: 30),
        ],
      ),
    );
  }
}

String _sentenceCase(String value) {
  final text = value.replaceAll('?', '').trim().toLowerCase();
  if (text.isEmpty) return value;
  return text[0].toUpperCase() + text.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSIONS
// ─────────────────────────────────────────────────────────────────────────────

extension _ListX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
