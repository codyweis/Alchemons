// lib/screens/mystic_altar/boss_altar_detail_screen.dart
//
// Individual boss ritual screen.
// Creature slots orbit on a spinning ellipse carousel — same mechanic as the
// Mystic Altar hub. Drag to spin, tap a slot to snap it to the front and focus
// it. Tap the focused slot a second time to place an Alchemon.

import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFF060912);
  static const surface = Color(0xFF111320);
  static const border = Color(0xFF252840);
  static const text = Color(0xFFE8E0FF);
  static const muted = Color(0xFF4A3F6B);
  static const sub = Color(0xFF8C7BB5);
  static const gold = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFC0392B);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BossAltarDetailScreen extends StatefulWidget {
  final Boss boss;
  const BossAltarDetailScreen({super.key, required this.boss});

  @override
  State<BossAltarDetailScreen> createState() => _BossAltarDetailScreenState();
}

class _BossAltarDetailScreenState extends State<BossAltarDetailScreen>
    with TickerProviderStateMixin {
  // ── ambient pulse ─────────────────────────────────────────────────────────
  late final AnimationController _pulse;

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
  bool _hasKey = false;
  bool _loading = true;
  bool _summoning = false;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _snapAnim = AlwaysStoppedAnimation(_wheelOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadState());
  }

  @override
  void dispose() {
    _pulse.dispose();
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
    final placements = await db.altarDao.getPlacementsForBoss(widget.boss.id);
    final mystic = catalog.mysticByElement(widget.boss.element);
    final species = catalog
        .byType(widget.boss.element)
        .where((s) => s.id != mystic?.id)
        .toList();

    final placed = <String, String?>{};
    for (final sp in species) {
      placed[sp.id] = null;
    }
    for (final p in placements) {
      placed[p.speciesId] = p.instanceId;
    }

    if (mounted) {
      setState(() {
        _hasKey = qty > 0;
        _mystic = mystic;
        _species = species;
        _placed
          ..clear()
          ..addAll(placed);
        _loading = false;
      });
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  bool get _allFilled =>
      _species.isNotEmpty && _species.every((s) => _placed[s.id] != null);

  bool get _canSummon => _hasKey && _allFilled && !_summoning;

  String _traitName() {
    final meta = BossLootKeys.elementRewards[widget.boss.element.toLowerCase()];
    return meta?.traitName ?? 'Key Item';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
        backgroundColor: _C.surface,
        behavior: SnackBarBehavior.floating,
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

    // Snapshot key stats before the instance is deleted — used later
    // during summoning to seed the mystic egg's nature and base stats.
    final snapshot = jsonEncode({
      'natureId': picked.natureId,
      'speed': picked.statSpeed,
      'intelligence': picked.statIntelligence,
      'strength': picked.statStrength,
      'beauty': picked.statBeauty,
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
          icon: Icons.warning_amber_rounded,
          iconColor: _C.gold,
          title: 'COMMIT ALCHEMON?',
          body:
              'Placing ${inst.nickname ?? sp.name} is permanent — it will be consumed by the ritual.',
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
      final traitKey = BossLootKeys.traitKeyForElement(boss.element);

      // Read placements FIRST (we need their snapshots), then clear them.
      final placements = await db.altarDao.getPlacementsForBoss(boss.id);
      final sacrificePayload = _deriveFromSacrifices(placements);

      await db.inventoryDao.consumeItem(traitKey, qty: 1);
      await db.altarDao.clearPlacementsForBoss(boss.id);
      await db.altarDao.clearRelicPlaced(boss.id);

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
      await _showSuccess(target, boss);
    } catch (e) {
      debugPrint('Summon error: $e');
      if (mounted) _snack('Summoning failed. Try again.');
    } finally {
      if (mounted) setState(() => _summoning = false);
    }
  }

  /// Parses placement snapshots and returns the dominant nature + averaged
  /// (and slightly boosted) base stats to seed the mystic egg.
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
        final natureId = snap['natureId'] as String?;
        if (natureId != null && natureId.isNotEmpty) {
          natureCounts[natureId] = (natureCounts[natureId] ?? 0) + 1;
        }
        totalSpeed += (snap['speed'] as num?)?.toDouble() ?? 3.0;
        totalIntelligence += (snap['intelligence'] as num?)?.toDouble() ?? 3.0;
        totalStrength += (snap['strength'] as num?)?.toDouble() ?? 3.0;
        totalBeauty += (snap['beauty'] as num?)?.toDouble() ?? 3.0;
        count++;
      } catch (_) {
        // Malformed snapshot — skip, defaults will be used.
      }
    }

    // Dominant nature = most common; ties are broken by first encountered.
    String? dominantNature;
    if (natureCounts.isNotEmpty) {
      dominantNature = natureCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // Average stats from sacrifices, with a +2.0 mystic bonus per stat,
    // clamped to the 1–10 range.
    const mysticBonus = 2.0;
    double avg(double total) =>
        count > 0 ? (total / count + mysticBonus).clamp(1.0, 10.0) : 8.0;

    return {
      'natureId': dominantNature,
      'speed': avg(totalSpeed),
      'intelligence': avg(totalIntelligence),
      'strength': avg(totalStrength),
      'beauty': avg(totalBeauty),
    };
  }

  Map<String, dynamic> _payload(
    Creature sp,
    Boss boss,
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
    'stats': {
      'speed': sacrificePayload['speed'],
      'intelligence': sacrificePayload['intelligence'],
      'strength': sacrificePayload['strength'],
      'beauty': sacrificePayload['beauty'],
    },
    'statPotentials': {
      'speed': 10.0,
      'intelligence': 10.0,
      'strength': 10.0,
      'beauty': 10.0,
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
              'Summoning ${widget.boss.name} will consume your ${_traitName()} and all committed Alchemons. A Mystic Egg will be placed in your Chamber.',
          cancelLabel: 'CANCEL',
          confirmLabel: 'SUMMON',
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ) ??
      false;

  Future<void> _showSuccess(Creature sp, Boss boss) async {
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Boss boss;
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
    final elColor = boss.elementColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _C.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.muted.withValues(alpha: 0.4), width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _C.sub,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (mystic?.name ?? boss.name).toUpperCase(),
                  style: GoogleFonts.cinzelDecorative(
                    color: elColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${boss.element.toUpperCase()} MYSTIC RITUAL',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _C.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: hasKey
                  ? _C.success.withValues(alpha: 0.12)
                  : _C.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasKey
                    ? _C.success.withValues(alpha: 0.4)
                    : _C.danger.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                hasKey
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: Image.asset(
                          boss.relicImagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.key_rounded,
                            color: _C.success,
                            size: 12,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.lock_outline_rounded,
                        color: _C.danger,
                        size: 12,
                      ),
                const SizedBox(width: 4),
                Text(
                  hasKey ? traitName.toUpperCase() : 'KEY MISSING',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: hasKey ? _C.success : _C.danger,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
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

// ─────────────────────────────────────────────────────────────────────────────
// CAROUSEL ARENA  — ellipse turntable with mystic in the center
// ─────────────────────────────────────────────────────────────────────────────

class _CarouselArena extends StatelessWidget {
  final Boss boss;
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

    final borderOp = widget.isFilled
        ? (0.70 + widget.pulse * 0.30)
        : (widget.isSelected ? (0.45 + widget.pulse * 0.30) : 0.22);
    final bgOp = widget.isFilled
        ? (0.28 + widget.pulse * 0.16)
        : (widget.isSelected ? 0.10 : 0.06);

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

        // ── Outer ambient glow ring (filled / selected) ──────────────────
        if (widget.isFilled || widget.isSelected)
          Container(
            width: widget.size + 14 + widget.pulse * 8,
            height: widget.size + 14 + widget.pulse * 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.elColor.withValues(alpha: 
                  (widget.isFilled ? 0.32 : 0.14) + widget.pulse * 0.24,
                ),
                width: 1.0,
              ),
            ),
          ),

        // ── Bloom glow behind disc (filled only) ────────────────────────
        if (widget.isFilled)
          Container(
            width: widget.size + 6,
            height: widget.size + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.elColor.withValues(alpha: 0.45 + widget.pulse * 0.38),
                  blurRadius: 22,
                  spreadRadius: 4,
                ),
              ],
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
              color: (widget.isFilled || widget.isSelected)
                  ? widget.elColor.withValues(alpha: bgOp)
                  : _C.surface.withValues(alpha: 0.50),
              border: Border.all(
                color: widget.elColor.withValues(alpha: borderOp),
                width: (widget.isFilled || widget.isSelected) ? 2.2 : 0.8,
              ),
              boxShadow: widget.isFilled
                  ? [
                      BoxShadow(
                        color: widget.elColor.withValues(alpha: 
                          0.38 + widget.pulse * 0.32,
                        ),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.elColor.withValues(alpha: 
                          0.20 + widget.pulse * 0.18,
                        ),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.isFilled
                // Full-color lit image
                ? Image.asset(
                    'assets/images/${widget.species.image}',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_awesome,
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
                          Icons.auto_awesome,
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
                boxShadow: [
                  BoxShadow(color: _C.success.withValues(alpha: 0.50), blurRadius: 7),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
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
                boxShadow: [
                  BoxShadow(
                    color: widget.elColor.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                Icons.add_rounded,
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
                fontFamily: 'monospace',
                color: widget.isFilled
                    ? widget.elColor
                    : (widget.isSelected
                          ? widget.elColor.withValues(alpha: 0.80)
                          : _C.muted),
                fontSize: 7.5,
                fontWeight: widget.isFilled ? FontWeight.w800 : FontWeight.w600,
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
  final Boss boss;
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
                color: elColor.withValues(alpha: (0.40 + pulse * 0.35) * 0.30),
                width: 1.0,
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: elColor.withValues(alpha: 0.10),
              border: Border.all(
                color: elColor.withValues(alpha: 0.40 + pulse * 0.35),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: elColor.withValues(alpha: 0.18 + pulse * 0.15),
                  blurRadius: 18,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: mystic != null
                ? Image.asset(
                    'assets/images/${mystic!.image}',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      boss.elementIcon,
                      color: elColor,
                      size: size * 0.48,
                    ),
                  )
                : Icon(boss.elementIcon, color: elColor, size: size * 0.48),
          ),
          Positioned(
            bottom: -22,
            child: Text(
              mystic?.name.toUpperCase() ?? 'MYSTIC',
              style: TextStyle(
                fontFamily: 'monospace',
                color: elColor.withValues(alpha: 0.65),
                fontSize: 8,
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
        10,
        14,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.90),
        border: const Border(top: BorderSide(color: _C.border, width: 0.5)),
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
                              ? elColor.withValues(alpha: 0.75 + pulse.value * 0.20)
                              : _C.muted.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Selected creature row: ‹ name › + place button ───────────
            if (selectedName.isNotEmpty) ...[
              Row(
                children: [
                  // Prev
                  _NavBtn(
                    icon: Icons.chevron_left_rounded,
                    elColor: elColor,
                    onTap: onPrev,
                  ),
                  const SizedBox(width: 8),
                  // Place / filled button
                  Expanded(
                    child: GestureDetector(
                      onTap: selectedFilled ? null : onPlace,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedFilled
                              ? _C.success.withValues(alpha: 0.10)
                              : elColor.withValues(alpha: 0.14 + pulse.value * 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedFilled ? _C.success : elColor,
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                selectedFilled
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: selectedFilled ? _C.success : elColor,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedFilled
                                    ? '${selectedName.toUpperCase()} · PLACED'
                                    : 'PLACE  ${selectedName.toUpperCase()}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: selectedFilled ? _C.success : elColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Next
                  _NavBtn(
                    icon: Icons.chevron_right_rounded,
                    elColor: elColor,
                    onTap: onNext,
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // ── Summon button ────────────────────────────────────────────
            if (!hasKey || !allFilled)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  !hasKey
                      ? 'KEY ITEM REQUIRED'
                      : '${total - filled} OFFERING SLOTS REMAINING',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _C.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
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
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: canSummon
                        ? elColor.withValues(alpha: 0.18 + pulse.value * 0.07)
                        : _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: canSummon ? elColor : _C.muted.withValues(alpha: 0.22),
                      width: canSummon ? 1.5 : 0.5,
                    ),
                  ),
                  child: Center(
                    child: summoning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: elColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: canSummon ? elColor : _C.muted,
                                size: 15,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PERFORM RITUAL',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: canSummon ? elColor : _C.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ],
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

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final Color elColor;
  final VoidCallback? onTap;
  const _NavBtn({
    required this.icon,
    required this.elColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: onTap != null ? elColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: onTap != null
              ? elColor.withValues(alpha: 0.4)
              : _C.muted.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Icon(
        icon,
        color: onTap != null ? elColor : _C.muted.withValues(alpha: 0.25),
        size: 22,
      ),
    ),
  );
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
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: elColor.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: _C.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: elColor.withValues(alpha: 0.1),
                      border: Border.all(color: elColor.withValues(alpha: 0.3)),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/${species.image}',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.catching_pokemon_rounded,
                          color: elColor,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SELECT ${species.name.toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose which specimen to commit to the ritual.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _C.muted,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: instances.length,
                itemBuilder: (ctx, i) {
                  final inst = instances[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, inst);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _C.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: elColor.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: elColor.withValues(alpha: 0.07),
                                child: Image.asset(
                                  'assets/images/${species.image}',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.catching_pokemon_rounded,
                                    color: elColor.withValues(alpha: 0.5),
                                    size: 22,
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
                                    (inst.nickname ?? species.name)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: _C.text,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'LVL ${inst.level}  ·  ${species.rarity.toUpperCase()}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: _C.muted,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: elColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: elColor.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'SELECT',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: elColor,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
      backgroundColor: _C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: elColor.withValues(alpha: 0.45), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: elColor.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: _C.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: const TextStyle(
                    color: _C.sub,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _Btn(
                        label: cancelLabel,
                        color: _C.muted,
                        onTap: onCancel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Btn(
                        label: confirmLabel,
                        color: elColor,
                        onTap: onConfirm,
                      ),
                    ),
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

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
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
  final Boss boss;
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
    return ScaleTransition(
      scale: _anim,
      child: Dialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: el.withValues(alpha: 0.5), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: el.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: el.withValues(alpha: 0.12),
                      border: Border.all(
                        color: el.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(color: el.withValues(alpha: 0.3), blurRadius: 18),
                      ],
                    ),
                    child: Icon(widget.boss.elementIcon, color: el, size: 32),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'RITUAL COMPLETE',
                    style: GoogleFonts.cinzelDecorative(
                      color: el,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.boss.name.toUpperCase()} HAS BEEN SUMMONED',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: _C.muted,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: el.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: el.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.egg_outlined,
                          color: el.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'A Mystic Egg awaits in your Alchemy Chamber. Incubation: 1 hour.',
                            style: TextStyle(
                              color: _C.sub,
                              fontSize: 11,
                              height: 1.4,
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSIONS
// ─────────────────────────────────────────────────────────────────────────────

extension _ListX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
