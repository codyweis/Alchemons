// lib/games/survival/components/deployment_phase_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
  static const List<String> _slotLabels = ['NORTH', 'EAST', 'SOUTH', 'WEST'];
  static const List<IconData> _slotIcons = [
    Icons.keyboard_arrow_up_rounded,
    Icons.keyboard_arrow_right_rounded,
    Icons.keyboard_arrow_down_rounded,
    Icons.keyboard_arrow_left_rounded,
  ];

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
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [FC.bg0, FC.bg1],
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
                color: FC.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FC.borderDim),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: FC.textSecondary,
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
                    fontFamily: 'monospace',
                    color: FC.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deployedCount == maxDeployments
                      ? 'Ready to begin — tap Begin Battle'
                      : 'Place ${maxDeployments - deployedCount} more guardian${maxDeployments - deployedCount == 1 ? '' : 's'} to begin',
                  style: TextStyle(
                    color: deployedCount == maxDeployments
                        ? FC.amberBright
                        : FC.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: FC.bg2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: canConfirm ? FC.amber : FC.borderDim,
                width: 1.5,
              ),
            ),
            child: Text(
              '$deployedCount / $maxDeployments',
              style: TextStyle(
                fontFamily: 'monospace',
                color: canConfirm ? FC.amberBright : FC.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
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
        final pulse = _pulseController.value;
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing halo
              Transform.scale(
                scale: 0.88 + 0.12 * pulse,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FC.amber.withOpacity(0.10 + 0.18 * pulse),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Mid glow ring
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      FC.amberGlow.withOpacity(0.55 + 0.25 * pulse),
                      FC.orange.withOpacity(0.28),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: FC.amber.withOpacity(0.55 + 0.25 * pulse),
                    width: 2.0,
                  ),
                ),
              ),
              // Inner core
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1C1208),
                  border: Border.all(
                    color: FC.amberBright.withOpacity(0.75 + 0.25 * pulse),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: FC.amberBright,
                  size: 20,
                ),
              ),
            ],
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
          final pulse = _pulseController.value;
          final scale = isHighlighted || isSwapHighlighted
              ? 1.0 + 0.09 * pulse
              : 1.0;
          final glowColor = isOccupied
              ? _getFamilyColor(creature.family)
              : isHighlighted
              ? FC.amberBright
              : isSwapHighlighted
              ? FC.amber
              : FC.borderDim;

          return Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow halo when active
                if (isHighlighted || isSwapHighlighted || isOccupied)
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: glowColor.withOpacity(
                          isHighlighted ? 0.25 + 0.25 * pulse : 0.15,
                        ),
                        width: 1.0,
                      ),
                    ),
                  ),
                // Main slot circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOccupied
                        ? _getFamilyColor(creature.family).withOpacity(0.15)
                        : isHighlighted
                        ? FC.amber.withOpacity(0.08 + 0.06 * pulse)
                        : FC.bg2,
                    border: Border.all(
                      color: isHighlighted
                          ? FC.amberBright.withOpacity(0.8 + 0.2 * pulse)
                          : isSwapHighlighted
                          ? FC.amber.withOpacity(0.7 + 0.2 * pulse)
                          : isOccupied
                          ? _getFamilyColor(creature.family).withOpacity(0.75)
                          : FC.borderDim,
                      width: isHighlighted || isSwapHighlighted ? 2.5 : 1.5,
                    ),
                  ),
                  child: isOccupied
                      ? _buildSlotCreature(creature)
                      : _buildEmptySlot(index, isHighlighted),
                ),
              ],
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
              color: FC.bg0,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FC.borderDim),
            ),
            child: Text(
              'Lv${creature.level}',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: FC.textSecondary,
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
          isHighlighted ? Icons.add_circle_rounded : _slotIcons[index],
          color: isHighlighted
              ? FC.amberBright
              : FC.textMuted.withOpacity(0.55),
          size: isHighlighted ? 26 : 20,
        ),
        const SizedBox(height: 3),
        Text(
          _slotLabels[index],
          style: TextStyle(
            fontFamily: 'monospace',
            color: isHighlighted ? FC.amber : FC.textMuted,
            fontSize: 7,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatureGrid() {
    return Container(
      height: 155,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FC.borderDim)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                const Text('YOUR GUARDIANS', style: FT.label),
                const Spacer(),
                const Text(
                  'tap to select  ·  tap slot to place',
                  style: TextStyle(color: FC.textMuted, fontSize: 10),
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
          color: isSelected ? familyColor.withOpacity(0.18) : FC.bg2,
          border: Border.all(
            color: isSelected
                ? familyColor
                : isPlaced
                ? FC.success.withOpacity(0.55)
                : FC.borderDim,
            width: isSelected ? 2.0 : 1.0,
          ),
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
                      color: FC.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Lv${creature.level} · ${creature.family}',
                    style: TextStyle(
                      fontFamily: 'monospace',
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
                  decoration: BoxDecoration(
                    color: FC.bg0,
                    shape: BoxShape.circle,
                    border: Border.all(color: FC.amber, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _slotLabels[creature.assignedSlot!][0],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: FC.amberBright,
                        fontSize: 8,
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
                    color: FC.bg0.withOpacity(0.4),
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
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;
          return GestureDetector(
            onTap: canConfirm ? _confirm : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: canConfirm
                    ? FC.amberDim.withOpacity(0.85 + 0.15 * pulse)
                    : FC.bg2,
                border: Border.all(
                  color: canConfirm
                      ? FC.amber.withOpacity(0.7 + 0.3 * pulse)
                      : FC.borderDim,
                  width: canConfirm ? 2.0 : 1.0,
                ),
                boxShadow: canConfirm
                    ? [
                        BoxShadow(
                          color: FC.amber.withOpacity(0.18 + 0.14 * pulse),
                          blurRadius: 18,
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
                    color: canConfirm ? FC.amberBright : FC.textMuted,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    canConfirm
                        ? 'BEGIN BATTLE'
                        : 'PLACE ${maxDeployments - deployedCount} MORE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: canConfirm ? FC.amberBright : FC.textSecondary,
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

    // --- Background radial atmosphere ---
    final bgGlow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A1005).withOpacity(0.55), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.9));
    canvas.drawCircle(center, radius * 1.9, bgGlow);

    // --- Glowing cardinal connector lines ---
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * math.pi * 2 - math.pi / 2;
      final startX = center.dx + math.cos(angle) * radius * 0.42;
      final startY = center.dy + math.sin(angle) * radius * 0.42;
      final endX = center.dx + math.cos(angle) * (radius - 4);
      final endY = center.dy + math.sin(angle) * (radius - 4);
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
                const Color(0xFFD97706).withOpacity(0.2 + pulse * 0.18),
                const Color(0xFFD97706).withOpacity(0.45 + pulse * 0.2),
              ],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(
              Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)),
            )
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), connPaint);

      // Tick mark at slot end
      final tickPaint = Paint()
        ..color = const Color(0xFFD97706).withOpacity(0.5 + pulse * 0.3)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final perp = Offset(-math.sin(angle), math.cos(angle));
      canvas.drawLine(
        Offset(endX - perp.dx * 6, endY - perp.dy * 6),
        Offset(endX + perp.dx * 6, endY + perp.dy * 6),
        tickPaint,
      );
    }

    // --- Main orbit ring with glow ---
    final mainGlow = Paint()
      ..color = const Color(0xFFD97706).withOpacity(0.06 + pulse * 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, mainGlow);

    final mainRing = Paint()
      ..color = const Color(0xFFD97706).withOpacity(0.28 + pulse * 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius, mainRing);

    // --- Outer decorative ring ---
    final outerRing = Paint()
      ..color = const Color(0xFF92400E).withOpacity(0.14 + pulse * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius + 52, outerRing);

    // --- Mid ring ---
    final midRing = Paint()
      ..color = const Color(0xFF6B4C20).withOpacity(0.18 + pulse * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.6, midRing);

    // --- Inner ring ---
    final innerRing = Paint()
      ..color = const Color(0xFFD97706).withOpacity(0.22 + pulse * 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.36, innerRing);

    // --- Dot marks at cardinal inner ring ---
    final dotPaint = Paint()
      ..color = const Color(0xFFD97706).withOpacity(0.5 + pulse * 0.3)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final a = (i / 4) * math.pi * 2 - math.pi / 2;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(a) * radius * 0.36,
          center.dy + math.sin(a) * radius * 0.36,
        ),
        2.5,
        dotPaint,
      );
    }

    // --- Clockwise rotating arcs (inner band) ---
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pulse * math.pi * 0.25);
    final arcPaint1 = Paint()
      ..color = const Color(0xFF92400E).withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final start = (i / 4) * math.pi * 2 + math.pi / 8;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius + 28),
        start,
        math.pi / 6,
        false,
        arcPaint1,
      );
    }
    canvas.restore();

    // --- Counter-rotating outer arcs ---
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pulse * math.pi * 0.15);
    final arcPaint2 = Paint()
      ..color = const Color(0xFF6B21A8).withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final start = (i / 6) * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius + 52),
        start,
        math.pi / 9,
        false,
        arcPaint2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}
