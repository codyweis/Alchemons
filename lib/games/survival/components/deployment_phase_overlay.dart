// lib/games/survival/components/deployment_phase_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';

class DeploymentCreature {
  final PartyCombatantStats stats;
  final int partyIndex;
  int? assignedSlot;

  DeploymentCreature({required this.stats, required this.partyIndex});

  bool get isPlaced => assignedSlot != null;
  String get id => stats.id;
  String get name => stats.name;
  String get family => stats.family;
  List<String> get types => stats.types;
  int get level => stats.level;
  SpriteSheetDef? get sheetDef => stats.sheetDef;
  SpriteVisuals? get spriteVisuals => stats.spriteVisuals;
  bool get hasSprite => sheetDef != null;
}

class DeploymentResult {
  final Map<int, DeploymentCreature> slotAssignments;
  final List<DeploymentCreature> deployedCreatures;
  final List<DeploymentCreature> benchCreatures;

  DeploymentResult({
    required this.slotAssignments,
    required this.deployedCreatures,
    required this.benchCreatures,
  });
}

// ── Ring definition matching survival_game.dart _initGuardianSlots ──
class _RingDef {
  final String label;
  final double gameRadius; // actual radius in the game world
  final int slotCount;
  final double angleOffset;
  final int startIndex; // global slot index of first slot in this ring

  const _RingDef({
    required this.label,
    required this.gameRadius,
    required this.slotCount,
    required this.angleOffset,
    required this.startIndex,
  });
}

// Must match _initGuardianSlots() in survival_game.dart exactly
const List<_RingDef> _kRings = [
  _RingDef(
    label: 'INNER',
    gameRadius: 350,
    slotCount: 8,
    angleOffset: -1.5707963,
    startIndex: 0,
  ),
  _RingDef(
    label: 'MID',
    gameRadius: 550,
    slotCount: 10,
    angleOffset: 0.31415926,
    startIndex: 8,
  ),
  _RingDef(
    label: 'OUTER',
    gameRadius: 780,
    slotCount: 12,
    angleOffset: 0,
    startIndex: 18,
  ),
  _RingDef(
    label: 'RANGE',
    gameRadius: 1000,
    slotCount: 14,
    angleOffset: 0.44879895,
    startIndex: 30,
  ),
  _RingDef(
    label: 'OUTPOST',
    gameRadius: 1250,
    slotCount: 16,
    angleOffset: 0,
    startIndex: 44,
  ),
];

class DeploymentPhaseOverlay extends StatefulWidget {
  final List<PartyMember> party;
  final CreatureCatalog catalog;
  final void Function(DeploymentResult result) onConfirm;
  final VoidCallback onCancel;

  const DeploymentPhaseOverlay({
    super.key,
    required this.party,
    required this.catalog,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<DeploymentPhaseOverlay> createState() => _DeploymentPhaseOverlayState();
}

class _DeploymentPhaseOverlayState extends State<DeploymentPhaseOverlay>
    with TickerProviderStateMixin {
  late List<DeploymentCreature> _creatures;
  DeploymentCreature? _selectedCreature;
  final Map<int, DeploymentCreature?> _slotAssignments = {};

  late AnimationController _pulseController;
  late AnimationController _introController;

  // Deploy exactly 4 guardians; rest start on bench
  static const int minDeployments = 4;
  static const int maxDeployments = 4;

  int get deployedCount => _creatures.where((c) => c.isPlaced).length;
  int get unplacedCount => _creatures.length - deployedCount;
  bool get canConfirm => deployedCount >= minDeployments;

  // Which ring is visible (for swipe / tab navigation)
  int _activeRingIndex = 0;

  @override
  void initState() {
    super.initState();

    _creatures = widget.party.asMap().entries.map((entry) {
      return DeploymentCreature(
        stats: entry.value.combatant,
        partyIndex: entry.key,
      );
    }).toList();

    // Initialize all slot assignments across all rings
    for (final ring in _kRings) {
      for (int i = 0; i < ring.slotCount; i++) {
        _slotAssignments[ring.startIndex + i] = null;
      }
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _selectCreature(DeploymentCreature creature) {
    setState(() {
      if (_selectedCreature == creature) {
        _selectedCreature = null;
      } else if (creature.isPlaced) {
        _removeFromSlot(creature);
        _selectedCreature = creature;
      } else {
        _selectedCreature = creature;
      }
    });
  }

  void _removeFromSlot(DeploymentCreature creature) {
    if (creature.assignedSlot != null) {
      _slotAssignments[creature.assignedSlot!] = null;
      creature.assignedSlot = null;
    }
  }

  void _assignToSlot(int slotIndex) {
    if (_selectedCreature == null) return;

    // If creature is not already placed and we're at the cap, block
    if (!_selectedCreature!.isPlaced && deployedCount >= maxDeployments) return;

    setState(() {
      // If something is already in this slot, unplace it
      final existingCreature = _slotAssignments[slotIndex];
      if (existingCreature != null) {
        existingCreature.assignedSlot = null;
      }

      // If creature was previously in a different slot, clear it
      if (_selectedCreature!.assignedSlot != null) {
        _slotAssignments[_selectedCreature!.assignedSlot!] = null;
      }

      _slotAssignments[slotIndex] = _selectedCreature;
      _selectedCreature!.assignedSlot = slotIndex;
      _selectedCreature = null;
    });
    HapticFeedback.lightImpact();
  }

  void _confirm() {
    if (!canConfirm) return;

    final deployed = <DeploymentCreature>[];
    final bench = <DeploymentCreature>[];
    final Map<int, DeploymentCreature> filledSlots = {};

    for (final entry in _slotAssignments.entries) {
      if (entry.value != null) {
        deployed.add(entry.value!);
        filledSlots[entry.key] = entry.value!;
      }
    }

    for (final creature in _creatures) {
      if (!creature.isPlaced) {
        bench.add(creature);
      }
    }

    HapticFeedback.heavyImpact();
    widget.onConfirm(
      DeploymentResult(
        slotAssignments: filledSlots,
        deployedCreatures: deployed,
        benchCreatures: bench,
      ),
    );
  }

  /// Auto-place up to 4 unplaced creatures into open slots (inner ring first)
  void _autoPlace() {
    setState(() {
      // Cardinal slots on the inner ring: N=0, E=2, S=4, W=6
      const cardinalSlots = [0, 4, 6, 2]; // top, bottom, left, right
      final unplaced = _creatures.where((c) => !c.isPlaced).toList();
      for (final slotIdx in cardinalSlots) {
        if (unplaced.isEmpty || deployedCount >= maxDeployments) break;
        if (_slotAssignments[slotIdx] != null) continue; // already occupied
        final creature = unplaced.removeAt(0);
        _slotAssignments[slotIdx] = creature;
        creature.assignedSlot = slotIdx;
      }
      _selectedCreature = null;
    });
    HapticFeedback.mediumImpact();
  }

  /// Clear all placements
  void _clearAll() {
    setState(() {
      for (final creature in _creatures) {
        if (creature.assignedSlot != null) {
          _slotAssignments[creature.assignedSlot!] = null;
          creature.assignedSlot = null;
        }
      }
      _selectedCreature = null;
    });
  }

  // ── Ring label for a given global slot index ──
  String _ringLabelForSlot(int slotIndex) {
    for (final ring in _kRings) {
      if (slotIndex >= ring.startIndex &&
          slotIndex < ring.startIndex + ring.slotCount) {
        final local = slotIndex - ring.startIndex + 1;
        return '${ring.label}·$local';
      }
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _introController,
      builder: (context, child) {
        final introProgress = Curves.easeOutCubic.transform(
          _introController.value,
        );
        return Opacity(
          opacity: introProgress,
          child: Transform.scale(
            scale: 0.9 + 0.1 * introProgress,
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final fc = FC.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fc.bg0, fc.bg1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildRingTabs(),
              Expanded(child: _buildArena()),
              _buildCreatureGrid(),
              _buildConfirmButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final fc = FC.of(context);
    final needMore = minDeployments - deployedCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fc.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fc.borderDim),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: fc.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEPLOY GUARDIANS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: fc.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canConfirm
                      ? 'Ready — $unplacedCount on bench'
                      : 'Place $needMore more to begin',
                  style: TextStyle(
                    color: canConfirm ? fc.amberBright : fc.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Auto-place / Clear buttons
          GestureDetector(
            onTap: deployedCount > 0 ? _clearAll : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: fc.bg2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: fc.borderDim),
              ),
              child: Text(
                'CLEAR',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: deployedCount > 0 ? fc.textSecondary : fc.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: unplacedCount > 0 && deployedCount < maxDeployments
                ? _autoPlace
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: unplacedCount > 0
                    ? fc.amber.withValues(alpha: 0.15)
                    : fc.bg2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: unplacedCount > 0
                      ? fc.amber.withValues(alpha: 0.5)
                      : fc.borderDim,
                ),
              ),
              child: Text(
                'AUTO',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: unplacedCount > 0 ? fc.amberBright : fc.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: fc.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: canConfirm ? fc.amber : fc.borderDim,
                width: 1.5,
              ),
            ),
            child: Text(
              '$deployedCount / $maxDeployments',
              style: TextStyle(
                fontFamily: 'monospace',
                color: canConfirm ? fc.amberBright : fc.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ring selector tabs ──
  Widget _buildRingTabs() {
    final fc = FC.of(context);
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fc.borderDim),
      ),
      child: Row(
        children: List.generate(_kRings.length, (i) {
          final ring = _kRings[i];
          final isActive = i == _activeRingIndex;
          final filledInRing = _countFilledInRing(ring);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeRingIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isActive
                      ? fc.amber.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: isActive
                      ? Border.all(color: fc.amber.withValues(alpha: 0.4))
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ring.label,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isActive ? fc.amberBright : fc.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (filledInRing > 0) ...[
                      const SizedBox(width: 3),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: fc.success.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$filledInRing',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: fc.success,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  int _countFilledInRing(_RingDef ring) {
    int count = 0;
    for (int i = 0; i < ring.slotCount; i++) {
      if (_slotAssignments[ring.startIndex + i] != null) count++;
    }
    return count;
  }

  // ── Arena: shows the active ring as a circle of slots around the orb ──
  Widget _buildArena() {
    final ring = _kRings[_activeRingIndex];

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200 &&
            _activeRingIndex < _kRings.length - 1) {
          setState(() => _activeRingIndex++);
        } else if (details.primaryVelocity! > 200 && _activeRingIndex > 0) {
          setState(() => _activeRingIndex--);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final areaSize = math.min(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );
          final radius = areaSize * 0.34;
          final slotSize = _slotSizeForRing(ring, areaSize);

          // Compute slot positions for this ring
          final slotPositions = <int, Offset>{};
          for (int i = 0; i < ring.slotCount; i++) {
            final angle = (i / ring.slotCount) * math.pi * 2 + ring.angleOffset;
            slotPositions[ring.startIndex + i] = Offset(
              center.dx + math.cos(angle) * radius,
              center.dy + math.sin(angle) * radius,
            );
          }

          return Stack(
            children: [
              // Background arena painting
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ArenaPainter(
                  animation: _pulseController,
                  center: center,
                  radius: radius,
                  slotCount: ring.slotCount,
                  angleOffset: ring.angleOffset,
                ),
              ),
              // Central orb
              Positioned(
                left: center.dx - 30,
                top: center.dy - 30,
                child: _buildCentralOrb(),
              ),
              // Slots
              ...slotPositions.entries.map((entry) {
                final halfSlot = slotSize / 2;
                return Positioned(
                  left: entry.value.dx - halfSlot,
                  top: entry.value.dy - halfSlot,
                  child: _buildSlot(entry.key, slotSize),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  double _slotSizeForRing(_RingDef ring, double areaSize) {
    // Scale slot size based on ring density so they don't overlap
    if (ring.slotCount <= 8) return 56;
    if (ring.slotCount <= 10) return 50;
    if (ring.slotCount <= 12) return 46;
    if (ring.slotCount <= 14) return 42;
    return 38;
  }

  Widget _buildCentralOrb() {
    final fc = FC.of(context);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.9 + 0.1 * pulse,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: fc.amber.withValues(alpha: 0.12 + 0.16 * pulse),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      fc.amberGlow.withValues(alpha: 0.5 + 0.2 * pulse),
                      FC.orange.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: fc.amber.withValues(alpha: 0.5 + 0.25 * pulse),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1C1208),
                  border: Border.all(
                    color: fc.amberBright.withValues(alpha: 0.7 + 0.3 * pulse),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: fc.amberBright,
                  size: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlot(int globalIndex, double slotSize) {
    final fc = FC.of(context);
    final creature = _slotAssignments[globalIndex];
    final isOccupied = creature != null;
    final hasSelection = _selectedCreature != null;
    final isHighlighted = hasSelection && !_selectedCreature!.isPlaced;
    final isSwapHighlighted = hasSelection && _selectedCreature!.isPlaced;

    return GestureDetector(
      onTap: () {
        if (_selectedCreature != null) {
          _assignToSlot(globalIndex);
        } else if (isOccupied) {
          _selectCreature(creature);
        }
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;
          final scale = (isHighlighted || isSwapHighlighted)
              ? 1.0 + 0.08 * pulse
              : 1.0;
          final glowColor = isOccupied
              ? _getFamilyColor(creature.family)
              : isHighlighted
              ? fc.amberBright
              : isSwapHighlighted
              ? fc.amber
              : fc.borderDim;

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: slotSize,
              height: slotSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isHighlighted || isSwapHighlighted || isOccupied)
                    Container(
                      width: slotSize + 6,
                      height: slotSize + 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: glowColor.withValues(
                            alpha: isHighlighted ? 0.2 + 0.2 * pulse : 0.12,
                          ),
                          width: 1.0,
                        ),
                      ),
                    ),
                  Container(
                    width: slotSize,
                    height: slotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOccupied
                          ? _getFamilyColor(
                              creature.family,
                            ).withValues(alpha: 0.15)
                          : isHighlighted
                          ? fc.amber.withValues(alpha: 0.06 + 0.05 * pulse)
                          : fc.bg2.withValues(alpha: 0.8),
                      border: Border.all(
                        color: isHighlighted
                            ? fc.amberBright.withValues(
                                alpha: 0.7 + 0.3 * pulse,
                              )
                            : isSwapHighlighted
                            ? fc.amber.withValues(alpha: 0.6 + 0.2 * pulse)
                            : isOccupied
                            ? _getFamilyColor(
                                creature.family,
                              ).withValues(alpha: 0.7)
                            : fc.borderDim.withValues(alpha: 0.5),
                        width: (isHighlighted || isSwapHighlighted) ? 2.0 : 1.0,
                      ),
                    ),
                    child: isOccupied
                        ? _buildSlotCreature(creature, slotSize)
                        : _buildEmptySlot(globalIndex, isHighlighted, slotSize),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotCreature(DeploymentCreature creature, double slotSize) {
    final spriteSize = slotSize * 0.65;
    return Center(
      child: creature.hasSprite
          ? SizedBox(
              width: spriteSize,
              height: spriteSize,
              child: CreatureSprite(
                spritePath: creature.sheetDef!.path,
                totalFrames: creature.sheetDef!.totalFrames,
                rows: creature.sheetDef!.rows,
                frameSize: creature.sheetDef!.frameSize,
                stepTime: creature.sheetDef!.stepTime,
                scale: creature.spriteVisuals?.scale ?? 1.0,
                saturation: creature.spriteVisuals?.saturation ?? 1.0,
                brightness: creature.spriteVisuals?.brightness ?? 1.0,
                hueShift: creature.spriteVisuals?.hueShiftDeg ?? 0.0,
                isPrismatic: creature.spriteVisuals?.isPrismatic ?? false,
                tint: creature.spriteVisuals?.tint,
                alchemyEffect: creature.spriteVisuals?.alchemyEffect,
                variantFaction: creature.spriteVisuals?.variantFaction,
                effectSlotSize: spriteSize,
              ),
            )
          : Text(
              creature.family[0],
              style: TextStyle(
                color: _getFamilyColor(creature.family),
                fontSize: slotSize * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildEmptySlot(int globalIndex, bool isHighlighted, double slotSize) {
    final fc = FC.of(context);
    final localIndex = globalIndex - _kRings[_activeRingIndex].startIndex + 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isHighlighted
              ? Icons.add_circle_rounded
              : Icons.radio_button_unchecked,
          color: isHighlighted
              ? fc.amberBright
              : fc.textMuted.withValues(alpha: 0.35),
          size: slotSize * 0.32,
        ),
        Text(
          '$localIndex',
          style: TextStyle(
            fontFamily: 'monospace',
            color: isHighlighted
                ? fc.amber
                : fc.textMuted.withValues(alpha: 0.4),
            fontSize: 7,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatureGrid() {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: fc.borderDim)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Text('YOUR GUARDIANS', style: ft.label),
                const Spacer(),
                Text(
                  'tap creature → tap slot',
                  style: TextStyle(color: fc.textMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _creatures.length,
              itemBuilder: (context, index) =>
                  _buildCreatureCard(_creatures[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatureCard(DeploymentCreature creature) {
    final fc = FC.of(context);
    final isSelected = _selectedCreature == creature;
    final isPlaced = creature.isPlaced;
    final familyColor = _getFamilyColor(creature.family);

    return GestureDetector(
      onTap: () => _selectCreature(creature),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? familyColor.withValues(alpha: 0.18) : fc.bg2,
          border: Border.all(
            color: isSelected
                ? familyColor
                : isPlaced
                ? fc.success.withValues(alpha: 0.55)
                : fc.borderDim,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Expanded(
                    child: creature.hasSprite
                        ? CreatureSprite(
                            spritePath: creature.sheetDef!.path,
                            totalFrames: creature.sheetDef!.totalFrames,
                            rows: creature.sheetDef!.rows,
                            frameSize: creature.sheetDef!.frameSize,
                            stepTime: creature.sheetDef!.stepTime,
                            scale: creature.spriteVisuals?.scale ?? 1.0,
                            saturation:
                                creature.spriteVisuals?.saturation ?? 1.0,
                            brightness:
                                creature.spriteVisuals?.brightness ?? 1.0,
                            hueShift:
                                creature.spriteVisuals?.hueShiftDeg ?? 0.0,
                            isPrismatic:
                                creature.spriteVisuals?.isPrismatic ?? false,
                            tint: creature.spriteVisuals?.tint,
                            alchemyEffect:
                                creature.spriteVisuals?.alchemyEffect,
                            variantFaction:
                                creature.spriteVisuals?.variantFaction,
                            effectSlotSize: 44,
                          )
                        : Center(
                            child: Text(
                              creature.family[0],
                              style: TextStyle(
                                color: familyColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  Text(
                    creature.name,
                    style: TextStyle(
                      color: fc.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Lv${creature.level}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: familyColor.withValues(alpha: 0.9),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isPlaced)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: fc.bg0,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: fc.amber, width: 1.0),
                  ),
                  child: Text(
                    _ringLabelForSlot(creature.assignedSlot!),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.amberBright,
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isPlaced && !isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: fc.bg0.withValues(alpha: 0.35),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final fc = FC.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;
          final needMore = minDeployments - deployedCount;
          return GestureDetector(
            onTap: canConfirm ? _confirm : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: canConfirm
                    ? fc.amberDim.withValues(alpha: 0.85 + 0.15 * pulse)
                    : fc.bg2,
                border: Border.all(
                  color: canConfirm
                      ? fc.amber.withValues(alpha: 0.7 + 0.3 * pulse)
                      : fc.borderDim,
                  width: canConfirm ? 2.0 : 1.0,
                ),
                boxShadow: canConfirm
                    ? [
                        BoxShadow(
                          color: fc.amber.withValues(
                            alpha: 0.15 + 0.12 * pulse,
                          ),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    canConfirm
                        ? Icons.play_arrow_rounded
                        : Icons.lock_outline_rounded,
                    color: canConfirm ? fc.amberBright : fc.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    canConfirm
                        ? 'BEGIN BATTLE  ·  $deployedCount DEPLOYED'
                        : 'PLACE $needMore MORE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: canConfirm ? fc.amberBright : fc.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getFamilyColor(String family) {
    switch (family.toLowerCase()) {
      case 'let':
        return const Color(0xFF3B82F6);
      case 'pip':
        return const Color(0xFFF59E0B);
      case 'mane':
        return const Color(0xFFEF4444);
      case 'mask':
        return const Color(0xFF8B5CF6);
      case 'horn':
        return const Color(0xFF10B981);
      case 'wing':
        return const Color(0xFF06B6D4);
      case 'kin':
        return const Color(0xFFEC4899);
      case 'mystic':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ── Arena background painter ──
class _ArenaPainter extends CustomPainter {
  final Animation<double> animation;
  final Offset center;
  final double radius;
  final int slotCount;
  final double angleOffset;

  _ArenaPainter({
    required this.animation,
    required this.center,
    required this.radius,
    required this.slotCount,
    required this.angleOffset,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = animation.value;

    // Background radial atmosphere
    final bgGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1A1005).withValues(alpha: 0.55),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.8));
    canvas.drawCircle(center, radius * 1.8, bgGlow);

    // Connector lines from center to each slot
    for (int i = 0; i < slotCount; i++) {
      final angle = (i / slotCount) * math.pi * 2 + angleOffset;
      final startX = center.dx + math.cos(angle) * 32;
      final startY = center.dy + math.sin(angle) * 32;
      final endX = center.dx + math.cos(angle) * (radius - 8);
      final endY = center.dy + math.sin(angle) * (radius - 8);
      final connPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment(
                math.cos(angle + math.pi),
                math.sin(angle + math.pi),
              ),
              end: Alignment(math.cos(angle), math.sin(angle)),
              colors: [
                Colors.transparent,
                const Color(0xFFD97706).withValues(alpha: 0.08 + pulse * 0.06),
                const Color(0xFFD97706).withValues(alpha: 0.18 + pulse * 0.10),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)),
            )
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), connPaint);
    }

    // Main orbit ring with glow
    final mainGlow = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.04 + pulse * 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, mainGlow);

    final mainRing = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.22 + pulse * 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, mainRing);

    // Inner decorative ring
    final innerRing = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.18 + pulse * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.22, innerRing);

    // Rotating arcs
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pulse * math.pi * 0.2);
    final arcPaint = Paint()
      ..color = const Color(0xFF92400E).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < slotCount; i += 3) {
      final start = (i / slotCount) * math.pi * 2 + math.pi / slotCount;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius + 16),
        start,
        math.pi / (slotCount * 0.6),
        false,
        arcPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}
