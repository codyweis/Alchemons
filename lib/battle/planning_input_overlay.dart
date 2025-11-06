// lib/battle/planning_input_overlay.dart
// UPDATED: Choose between THROW or SUMMON each turn

import 'dart:math' as math;
import 'package:alchemons/battle/battle_game_core.dart';
import 'package:flutter/material.dart';

import 'battle_bootstrap.dart';
import 'arena_bridge.dart';

enum PlanningMode { selecting, throwing, summoning }

class PlanningInputOverlay extends StatefulWidget {
  final BattleBootstrap battle;
  const PlanningInputOverlay({super.key, required this.battle});

  @override
  State<PlanningInputOverlay> createState() => _PlanningInputOverlayState();
}

class _PlanningInputOverlayState extends State<PlanningInputOverlay> {
  PlanningMode _mode = PlanningMode.selecting;

  // Throw mode
  BubbleHandle? _selectedBubble;
  Offset? _dragStart;
  Offset? _dragNow;
  Offset? _plannedAim;
  double? _plannedPower;

  // Summon mode
  BattleCreature? _selectedSummon;

  static const double _maxArrowLen = 180;
  bool get _isPlanning => widget.battle.state.phase == Phase.planning;

  // Base elements that can be manually summoned
  static const baseElements = {'Fire', 'Water', 'Earth', 'Air'};

  @override
  void initState() {
    super.initState();
    widget.battle.addListener(_onBattleUpdate);
  }

  @override
  void dispose() {
    widget.battle.removeListener(_onBattleUpdate);
    super.dispose();
  }

  void _onBattleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _resetPlan() {
    setState(() {
      _mode = PlanningMode.selecting;
      _selectedBubble = null;
      _selectedSummon = null;
      _dragStart = null;
      _dragNow = null;
      _plannedAim = null;
      _plannedPower = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allBubbles = widget.battle.arena.allBubbles();
    final playerBubbles = allBubbles.where((b) => b.team == 0).toList();

    return Stack(
      children: [
        // Gesture surface for throwing
        if (_mode != PlanningMode.summoning)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (!_isPlanning || _mode == PlanningMode.summoning) return;
                print('🟢 POINTER DOWN at ${event.localPosition}');

                final nearest = _nearestPlayerBubble(event.localPosition);
                if (nearest != null) {
                  setState(() {
                    _mode = PlanningMode.throwing;
                    _selectedBubble = nearest;
                    _dragStart = event.localPosition;
                    _dragNow = event.localPosition;
                    _plannedAim = null;
                    _plannedPower = null;
                  });
                }
              },
              onPointerMove: (event) {
                if (!_isPlanning || _mode != PlanningMode.throwing) return;
                setState(() {
                  _dragNow = event.localPosition;
                });
              },
              onPointerUp: (event) {
                if (!_isPlanning || _mode != PlanningMode.throwing) return;

                if (_selectedBubble != null &&
                    _dragStart != null &&
                    _dragNow != null) {
                  final pull = _dragStart! - _dragNow!;
                  final len = pull.distance;
                  if (len > 8) {
                    setState(() {
                      _plannedAim = pull / len;
                      _plannedPower = (len / _maxArrowLen).clamp(0.1, 1.0);
                    });
                    print('   ✅ Throw plan set - power: $_plannedPower');
                  }
                }

                setState(() {
                  _dragStart = null;
                  _dragNow = null;
                });
              },
              child: CustomPaint(
                painter: _AimPainter(
                  bubble: _selectedBubble,
                  from: _dragStart,
                  now: _dragNow,
                  maxLen: _maxArrowLen,
                  persistAim: _plannedAim,
                  persistPower: _plannedPower,
                ),
              ),
            ),
          ),

        // Debug overlay
        if (_isPlanning)
          Positioned(
            top: 60,
            left: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode: ${_mode.name.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bubbles: ${allBubbles.length} (${playerBubbles.length} yours)',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    if (_selectedBubble != null &&
                        _mode == PlanningMode.throwing)
                      Text(
                        'Throwing: ${_selectedBubble!.element}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                        ),
                      ),
                    if (_selectedSummon != null &&
                        _mode == PlanningMode.summoning)
                      Text(
                        'Summoning: ${_selectedSummon!.element}',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 10,
                        ),
                      ),
                    if (_plannedAim != null)
                      Text(
                        'Plan ready! Power: ${(_plannedPower! * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // Action choice buttons
        if (_isPlanning && _mode == PlanningMode.selecting)
          _buildActionChoice(),

        // Summon bench selection
        if (_mode == PlanningMode.summoning) _buildSummonSelection(),

        // Bottom HUD (Ready / Clear / Switch Mode)
        if (_isPlanning) _buildBottomHUD(),
      ],
    );
  }

  Widget _buildActionChoice() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CHOOSE YOUR ACTION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.launch,
                    label: 'THROW',
                    color: Colors.orange,
                    onTap: () {
                      setState(() {
                        _mode = PlanningMode.throwing;
                      });
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.add_circle,
                    label: 'SUMMON',
                    color: Colors.blue,
                    onTap: () {
                      setState(() {
                        _mode = PlanningMode.summoning;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummonSelection() {
    final bench = widget.battle.state.playerBench;
    final summonableBases = bench
        .where(
          (c) => c.summonable && !c.onField && baseElements.contains(c.element),
        )
        .toList();

    if (summonableBases.isEmpty) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber, size: 60, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'NO BASE ELEMENTS TO SUMMON',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only Fire, Water, Earth, Air can be summoned\nFusions must be created in battle!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Text(
              'SELECT CREATURE TO SUMMON',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: summonableBases.length,
                itemBuilder: (context, index) {
                  final creature = summonableBases[index];
                  final isSelected = _selectedSummon == creature;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSummon = creature;
                      });
                      print('   📦 Selected ${creature.element} for summon');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.cyanAccent.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: isSelected
                              ? Colors.cyanAccent
                              : Colors.white.withOpacity(0.3),
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _elementIcon(creature.element),
                            size: 40,
                            color: _elementColor(creature.element),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            creature.element,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'HP: ${creature.hp}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
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

  Widget _buildBottomHUD() {
    final hasThrowPlan = _plannedAim != null && _mode == PlanningMode.throwing;
    final hasSummonPlan =
        _selectedSummon != null && _mode == PlanningMode.summoning;
    final canConfirm = hasThrowPlan || hasSummonPlan;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Back button (if not in selecting mode)
          if (_mode != PlanningMode.selecting)
            ElevatedButton.icon(
              onPressed: _resetPlan,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),

          if (_mode != PlanningMode.selecting) const SizedBox(width: 12),

          // Ready button
          ElevatedButton.icon(
            onPressed: canConfirm ? _confirmPlan : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('READY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm
                  ? Colors.green.shade600
                  : Colors.grey.shade800,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade800,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmPlan() {
    if (_mode == PlanningMode.throwing &&
        _plannedAim != null &&
        _selectedBubble != null) {
      print('🚀 Confirming THROW plan');
      widget.battle.bridge.setPlayerPlan(
        _selectedBubble!,
        _plannedAim!,
        _plannedPower ?? 0.3,
      );
      widget.battle.bridge.maybeResolve();
      _resetPlan();
    } else if (_mode == PlanningMode.summoning && _selectedSummon != null) {
      print('🚀 Confirming SUMMON plan');
      widget.battle.bridge.setPlayerSummon(_selectedSummon!);
      widget.battle.bridge.maybeResolve();
      _resetPlan();
    }
  }

  BubbleHandle? _nearestPlayerBubble(Offset p) {
    final all = widget.battle.arena
        .allBubbles()
        .where((b) => b.team == 0)
        .toList();
    if (all.isEmpty) return null;

    BubbleHandle best = all.first;
    double bestD = (best.pos - p).distance;

    for (final h in all.skip(1)) {
      final d = (h.pos - p).distance;
      if (d < bestD) {
        bestD = d;
        best = h;
      }
    }

    if (bestD > 200) return null;
    return best;
  }

  IconData _elementIcon(String element) {
    switch (element) {
      case 'Fire':
        return Icons.local_fire_department;
      case 'Water':
        return Icons.water_drop;
      case 'Earth':
        return Icons.terrain;
      case 'Air':
        return Icons.air;
      default:
        return Icons.circle;
    }
  }

  Color _elementColor(String element) {
    switch (element) {
      case 'Fire':
        return Colors.deepOrange;
      case 'Water':
        return Colors.blue;
      case 'Earth':
        return Colors.brown;
      case 'Air':
        return Colors.grey.shade300;
      default:
        return Colors.white;
    }
  }
}

class _AimPainter extends CustomPainter {
  final BubbleHandle? bubble;
  final Offset? from;
  final Offset? now;
  final double maxLen;
  final Offset? persistAim;
  final double? persistPower;

  const _AimPainter({
    this.bubble,
    this.from,
    this.now,
    required this.maxLen,
    this.persistAim,
    this.persistPower,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bubble == null) return;

    if (persistAim != null && persistPower != null) {
      _drawArrow(canvas, bubble!.pos, persistAim!, persistPower! * maxLen);
    }

    if (from != null && now != null) {
      final pull = from! - now!;
      final len = pull.distance;
      if (len >= 4) {
        final dir = pull / len;
        final used = len.clamp(0, maxLen).toDouble();
        _drawArrow(canvas, bubble!.pos, dir, used);
      }
      canvas.drawCircle(
        bubble!.pos,
        bubble!.radius + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.yellowAccent,
      );
    } else if (bubble != null) {
      canvas.drawCircle(
        bubble!.pos,
        bubble!.radius + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.greenAccent,
      );
    }
  }

  void _drawArrow(Canvas c, Offset center, Offset dir, double len) {
    final start = center;
    final end = center + dir * len;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    c.drawLine(start, end, paint);

    final arrowSize = 15.0;
    final angle = math.atan2(dir.dy, dir.dx);
    final leftAngle = angle + math.pi * 0.75;
    final rightAngle = angle - math.pi * 0.75;
    c.drawLine(
      end,
      end + Offset(math.cos(leftAngle), math.sin(leftAngle)) * arrowSize,
      paint,
    );
    c.drawLine(
      end,
      end + Offset(math.cos(rightAngle), math.sin(rightAngle)) * arrowSize,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AimPainter old) =>
      old.bubble != bubble ||
      old.from != from ||
      old.now != now ||
      old.persistAim != persistAim ||
      old.persistPower != persistPower;
}
