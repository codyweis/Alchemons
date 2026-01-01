// lib/games/survival/components/deployment_phase_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

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

  Map<int, String> toFormationSlots() {
    final Map<int, String> result = {};
    for (int i = 0; i < deployedCreatures.length && i < 4; i++) {
      result[i] = deployedCreatures[i].id;
    }
    for (int i = 0; i < benchCreatures.length && i < 4; i++) {
      result[100 + i] = benchCreatures[i].id;
    }
    return result;
  }
}

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

  static const int maxDeployments = 4;
  static const List<String> _slotLabels = ['TOP', 'RIGHT', 'BOTTOM', 'LEFT'];

  int get deployedCount => _creatures.where((c) => c.isPlaced).length;
  bool get canConfirm => deployedCount == maxDeployments;

  @override
  void initState() {
    super.initState();

    _creatures = widget.party.asMap().entries.map((entry) {
      return DeploymentCreature(
        stats: entry.value.combatant,
        partyIndex: entry.key,
      );
    }).toList();

    for (int i = 0; i < 4; i++) {
      _slotAssignments[i] = null;
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
    if (deployedCount >= maxDeployments && !_selectedCreature!.isPlaced) return;

    setState(() {
      final existingCreature = _slotAssignments[slotIndex];
      if (existingCreature != null) {
        existingCreature.assignedSlot = null;
      }

      if (_selectedCreature!.assignedSlot != null) {
        _slotAssignments[_selectedCreature!.assignedSlot!] = null;
      }

      _slotAssignments[slotIndex] = _selectedCreature;
      _selectedCreature!.assignedSlot = slotIndex;
      _selectedCreature = null;
    });
  }

  void _confirm() {
    if (!canConfirm) return;

    final deployed = <DeploymentCreature>[];
    final bench = <DeploymentCreature>[];
    final Map<int, DeploymentCreature> filledSlots = {};

    for (int i = 0; i < 4; i++) {
      final creature = _slotAssignments[i];
      if (creature != null) {
        deployed.add(creature);
        filledSlots[i] = creature;
      }
    }

    for (final creature in _creatures) {
      if (!creature.isPlaced) {
        bench.add(creature);
      }
    }

    widget.onConfirm(
      DeploymentResult(
        slotAssignments: filledSlots,
        deployedCreatures: deployed,
        benchCreatures: bench,
      ),
    );
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
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF1a1a2e), Color(0xFF0f0f1a), Colors.black],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(flex: 5, child: _buildArena()),
            _buildCreatureGrid(),
            _buildConfirmButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DEPLOY GUARDIANS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select 4 creatures for battle',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canConfirm
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:
                      (canConfirm
                              ? const Color(0xFF10B981)
                              : const Color(0xFF8B5CF6))
                          .withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '$deployedCount / $maxDeployments',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArena() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        final radius = size * 0.30;

        // Cardinal positions: Top, Right, Bottom, Left
        final slotPositions = [
          Offset(center.dx, center.dy - radius), // Top
          Offset(center.dx + radius, center.dy), // Right
          Offset(center.dx, center.dy + radius), // Bottom
          Offset(center.dx - radius, center.dy), // Left
        ];

        return Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ArenaPainter(
                animation: _pulseController,
                center: center,
                radius: radius,
              ),
            ),
            Positioned(
              left: center.dx - 40,
              top: center.dy - 40,
              child: _buildCentralOrb(),
            ),
            ...List.generate(4, (index) {
              final pos = slotPositions[index];
              return Positioned(
                left: pos.dx - 40,
                top: pos.dy - 40,
                child: _buildSlot(index),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildCentralOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 0.95 + 0.05 * _pulseController.value;
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFD700).withOpacity(0.8),
                  const Color(0xFFFF8C00).withOpacity(0.5),
                  const Color(0xFFFF4500).withOpacity(0.2),
                ],
                stops: const [0.2, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.shield_rounded, color: Colors.white, size: 32),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlot(int index) {
    final creature = _slotAssignments[index];
    final isOccupied = creature != null;
    final isHighlighted =
        _selectedCreature != null &&
        !_selectedCreature!.isPlaced &&
        deployedCount < maxDeployments;
    final isSwapHighlighted =
        _selectedCreature != null && _selectedCreature!.isPlaced;

    return GestureDetector(
      onTap: () {
        if (_selectedCreature != null) {
          _assignToSlot(index);
        } else if (isOccupied) {
          _selectCreature(creature);
        }
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = isHighlighted || isSwapHighlighted
              ? 1.0 + 0.08 * _pulseController.value
              : 1.0;

          return Transform.scale(
            scale: pulse,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOccupied
                    ? _getFamilyColor(creature.family).withOpacity(0.3)
                    : Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: isHighlighted
                      ? const Color(0xFF10B981)
                      : isSwapHighlighted
                      ? const Color(0xFFFFD700)
                      : isOccupied
                      ? _getFamilyColor(creature.family)
                      : Colors.white24,
                  width: isHighlighted || isSwapHighlighted ? 3 : 2,
                ),
                boxShadow: isHighlighted || isSwapHighlighted
                    ? [
                        BoxShadow(
                          color:
                              (isHighlighted
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFFD700))
                                  .withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: isOccupied
                  ? _buildSlotCreature(creature)
                  : _buildEmptySlot(index, isHighlighted),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotCreature(DeploymentCreature creature) {
    return Stack(
      children: [
        Center(
          child: creature.hasSprite
              ? SizedBox(
                  width: 54,
                  height: 54,
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
                  ),
                )
              : Text(
                  creature.family[0],
                  style: TextStyle(
                    color: _getFamilyColor(creature.family),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Lv${creature.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySlot(int index, bool isHighlighted) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isHighlighted
              ? Icons.add_circle_outline
              : Icons.radio_button_unchecked,
          color: isHighlighted
              ? const Color(0xFF10B981)
              : Colors.white.withOpacity(0.3),
          size: 26,
        ),
        const SizedBox(height: 4),
        Text(
          _slotLabels[index],
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatureGrid() {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Text(
                  'YOUR GUARDIANS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to select → tap slot',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
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
    final isSelected = _selectedCreature == creature;
    final isPlaced = creature.isPlaced;
    final familyColor = _getFamilyColor(creature.family);

    return GestureDetector(
      onTap: () => _selectCreature(creature),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [familyColor.withOpacity(0.4), familyColor.withOpacity(0.2)]
                : [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
          ),
          border: Border.all(
            color: isSelected
                ? familyColor
                : isPlaced
                ? const Color(0xFF10B981).withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: familyColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
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
                          )
                        : Center(
                            child: Text(
                              creature.family[0],
                              style: TextStyle(
                                color: familyColor,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    creature.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Lv${creature.level} • ${creature.family}',
                    style: TextStyle(
                      color: familyColor.withOpacity(0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isPlaced)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _slotLabels[creature.assignedSlot!][0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            if (isPlaced && !isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: canConfirm ? _confirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canConfirm
                ? const Color(0xFF10B981)
                : Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withOpacity(0.1),
            disabledForegroundColor: Colors.white38,
            elevation: canConfirm ? 8 : 0,
            shadowColor: const Color(0xFF10B981).withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: canConfirm ? const Color(0xFF10B981) : Colors.white24,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                canConfirm ? Icons.play_arrow_rounded : Icons.lock_outline,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                canConfirm
                    ? 'BEGIN BATTLE'
                    : 'PLACE ${maxDeployments - deployedCount} MORE',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
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

class _ArenaPainter extends CustomPainter {
  final Animation<double> animation;
  final Offset center;
  final double radius;

  _ArenaPainter({
    required this.animation,
    required this.center,
    required this.radius,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = animation.value;

    // Outer ring
    final outerRingPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.15 + pulse * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius + 50, outerRingPaint);

    // Main ring
    final mainRingPaint = Paint()
      ..color = const Color(0xFF6366F1).withOpacity(0.25 + pulse * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, mainRingPaint);

    // Inner glow
    final innerRingPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.2 + pulse * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius * 0.4, innerRingPaint);

    // Cardinal lines to slots
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * math.pi * 2 - math.pi / 2;
      final startX = center.dx + math.cos(angle) * radius * 0.5;
      final startY = center.dy + math.sin(angle) * radius * 0.5;
      final endX = center.dx + math.cos(angle) * radius;
      final endY = center.dy + math.sin(angle) * radius;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), linePaint);
    }

    // Rotating decoration
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pulse * math.pi * 0.5);

    final decorPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final decorRadius = radius + 80;
    for (int i = 0; i < 8; i++) {
      final startAngle = (i / 8) * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: decorRadius),
        startAngle,
        math.pi / 10,
        false,
        decorPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}
