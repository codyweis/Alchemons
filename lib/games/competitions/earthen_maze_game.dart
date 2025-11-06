// lib/screens/earthen_maze_game.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/competition_instance_selection_screen.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import 'package:alchemons/constants/competition_data.dart';
import 'package:alchemons/models/competition.dart';

// DB + sprite
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

/// ===== CONFIG =====
const _tickMs = 90; // fixed sim step

(int, int) _computeMazeSize(BoxConstraints c, {required int level}) {
  final targetCell = 24.0;
  final usableW = (c.maxWidth - 160).clamp(280.0, 5000.0);
  final usableH = (c.maxHeight - 120).clamp(280.0, 5000.0);

  final levelScale = 1.0 + (level - 1) * 0.25; // 1.0 → 2.0
  final gw = (usableW / (targetCell / levelScale)).floor();
  final gh = (usableH / (targetCell / levelScale)).floor();

  int makeOdd(int x, int min) => (x.isEven ? x - 1 : x).clamp(min, 9999);
  final w = makeOdd(gw, 25);
  final h = makeOdd(gh, 19);
  return (w, h);
}

class EarthenMazeGameScreen extends StatefulWidget {
  final int level; // 1..5
  const EarthenMazeGameScreen({super.key, required this.level});

  @override
  State<EarthenMazeGameScreen> createState() => _EarthenMazeGameScreenState();
}

class _EarthenMazeGameScreenState extends State<EarthenMazeGameScreen> {
  int _simulationSpeed = 2;
  Maze? _maze;

  DateTime? _raceStartTime;
  static const _maxRaceDuration = Duration(seconds: 10);

  _Actor? player;
  List<_NPC>? npcs;
  CompetitionLevel? compLevel;

  bool _awaitingSelection = true;
  bool _countingDown = false;
  int _count = 3;
  bool _started = false;
  bool _finished = false;

  // finish order
  final Map<_Actor, int> _finishTimes = {};

  Timer? _tick;

  // player stats (from chosen creature)
  double playerInt = 6.5;
  double playerSpd = 6.0;

  // sprite hookup
  String? _playerInstanceId;
  Future<_SpriteMeta>? _playerSpriteFuture;

  // Master RNG for this race (ensures deterministic divergence per actor)
  final math.Random _raceRng = math.Random(
    DateTime.now().millisecondsSinceEpoch,
  );

  @override
  void initState() {
    super.initState();
    compLevel = CompetitionData.getLevel(
      CompetitionBiome.earthen,
      widget.level,
    );

    // force selection first
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureCreatureSelected();
      if (!mounted) return;
      setState(() => _awaitingSelection = false);
      _startCountdown();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _ensureCreatureSelected() async {
    final pickedId = await pickInstanceForCompetition(
      context: context,
      biome: CompetitionBiome.earthen,
    );
    if (pickedId == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _playerInstanceId = pickedId;
      _playerSpriteFuture = _loadSpriteMeta(context, pickedId);
    });

    final meta = await _playerSpriteFuture!;
    if (!mounted) return;
    setState(() {
      playerInt = meta.intelligence.clamp(0, 10);
      playerSpd = meta.speed.clamp(0, 10);
    });
  }

  void _startCountdown() {
    if (_countingDown || _started) return;
    setState(() {
      _countingDown = true;
      _count = 3;
    });

    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_count > 1) {
        setState(() => _count--);
      } else {
        t.cancel();
        setState(() => _count = 0); // GO!
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _countingDown = false;
            _started = true;
          });
          _startTick();
        });
      }
    });
  }

  void _startTick() {
    _raceStartTime = DateTime.now(); // ✅ Track when race starts
    _tick?.cancel();
    final speedMs = (_tickMs / _simulationSpeed).round();
    _tick = Timer.periodic(Duration(milliseconds: speedMs), _onTick);
  }

  void _toggleSpeed() {
    setState(() {
      _simulationSpeed = switch (_simulationSpeed) {
        1 => 2,
        2 => 4,
        4 => 8,
        _ => 1,
      };
    });

    // Restart tick with new speed if already running
    if (_started && !_finished) {
      _startTick();
    }
  }

  void _initActorsIfNeeded() {
    if (_maze == null || player != null || npcs != null || compLevel == null) {
      return;
    }

    // Player
    player = _Actor('You', _maze!.entry, iq: playerInt, spd: playerSpd);

    // NPCs: use competition stat as INT; derive SPD close to INT with some jitter
    final rnd = _raceRng;
    npcs = compLevel!.npcs.map((n) {
      final iq = n.statValue.clamp(0.0, 10.0);
      final spd =
          (iq + (rnd.nextDouble() * 2 - 1) * 1.0) // ±1 wiggle
              .clamp(0.0, 10.0);
      return _NPC.fromStats(n.name, iq, spd, _maze!.entry);
    }).toList();

    for (final r in [player!, ...npcs!]) {
      final seed = _raceRng.nextInt(0x7fffffff);
      r.brain = _Brain(
        r,
        _maze!,
        rng: math.Random(seed),
        personality: BrainPersonality.randomized(_raceRng, iq: r.iq),
      );
    }
  }

  void _onTick(Timer _) {
    if (!_started ||
        _finished ||
        _maze == null ||
        npcs == null ||
        player == null) {
      return;
    }

    // ✅ Check if race has been going too long
    final elapsed = DateTime.now().difference(_raceStartTime!);
    final shouldForceFinish = elapsed > _maxRaceDuration;

    for (final racer in [player!, ...npcs!]) {
      if (_finishTimes.containsKey(racer)) continue;

      racer._cooldown--;

      if (racer._cooldown <= 0) {
        // ✅ Force perfect pathfinding if timeout reached
        if (shouldForceFinish) {
          racer.brain!._forceOptimalPath();
        }

        racer.brain!.update();

        final speedFactor = (racer.spd / 10.0).clamp(0.1, 1.0);
        racer._cooldown = (10.0 * (1.0 - speedFactor) + 1.0).round();

        final before = racer.pos;
        final dir = racer.brain!.nextMove;
        _applyMove(racer, dir);
        racer.brain!.onStepApplied(moved: racer.pos != before);

        // ✅ Don't replan randomly when forced to finish
        if (!shouldForceFinish &&
            racer.brain!.rng.nextDouble() <
                racer.brain!.personality.planFrequency) {
          racer.brain!._replan();
        }

        if (racer.pos == _maze!.exit) {
          _finishTimes[racer] = DateTime.now().millisecondsSinceEpoch;
        }
      }
    }

    // End when ALL racers finish
    if (_finishTimes.length == [player!, ...npcs!].length) {
      _finished = true;
      _tick?.cancel();
      _showPodium();
    }

    if (mounted) setState(() {});
  }

  void _applyMove(_Actor a, Offset dir) {
    if (dir == Offset.zero || _maze == null) return;
    final p = a.pos + dir;
    if (_maze!.isWalkable(p)) a.pos = p;
  }

  void _showPodium() {
    final racers = [player!, ...npcs!];
    final exit = _maze!.exit;

    double manhattan(Offset p) =>
        (p.dx - exit.dx).abs() + (p.dy - exit.dy).abs();

    final ranked = racers.toList()
      ..sort((a, b) {
        final ta = _finishTimes[a];
        final tb = _finishTimes[b];
        if (ta != null && tb != null) return ta.compareTo(tb);
        if (ta != null) return -1;
        if (tb != null) return 1;
        return manhattan(a.pos).compareTo(manhattan(b.pos));
      });

    final winner = ranked.first;
    final isVictory = winner == player;
    final color = CompetitionBiome.earthen.primaryColor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultsDialog(
        ranked: ranked,
        isVictory: isVictory,
        color: color,
        level: widget.level,
        compLevel: compLevel!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = CompetitionBiome.earthen.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(child: CustomPaint(painter: _MazeBackdropPainter())),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildModernHeader(color),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // Build maze once
                      _maze ??= () {
                        final (w, h) = _computeMazeSize(c, level: widget.level);
                        final m = Maze.generate(
                          w,
                          h,
                          seed: DateTime.now().millisecondsSinceEpoch,
                        );
                        final p = 0.10 + widget.level * 0.04;
                        m.addLoops(probability: p.clamp(0.0, 0.35));
                        return m;
                      }();

                      if (!_awaitingSelection) _initActorsIfNeeded();

                      final cell = math
                          .min(
                            (c.maxWidth - 40) / _maze!.w,
                            (c.maxHeight - 200) / _maze!.h,
                          )
                          .clamp(14.0, 40.0);

                      final boardSize = Size(_maze!.w * cell, _maze!.h * cell);

                      return Column(
                        children: [
                          // Maze board
                          Expanded(
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: color.withOpacity(.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(.2),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: boardSize,
                                        painter: _MazePainter(
                                          maze: _maze!,
                                          cell: cell,
                                          primary: color,
                                        ),
                                      ),
                                      // Player sprite
                                      if (_playerSpriteFuture != null &&
                                          player != null)
                                        FutureBuilder<_SpriteMeta>(
                                          future: _playerSpriteFuture,
                                          builder: (context, snap) {
                                            if (!snap.hasData) {
                                              return const SizedBox.shrink();
                                            }
                                            return _SpriteOverlay(
                                              actor: player!,
                                              meta: snap.data!,
                                              cell: cell,
                                              boardSize: boardSize,
                                            );
                                          },
                                        ),
                                      // NPC sprites
                                      if (npcs != null)
                                        ...npcs!.map(
                                          (npc) => _NPCSpriteOverlay(
                                            actor: npc,
                                            cell: cell,
                                            boardSize: boardSize,
                                            color: color,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Progress HUD
                          if (player != null && npcs != null)
                            Stack(
                              children: [
                                _ModernHudBar(
                                  color: color,
                                  racers: [player!, ...npcs!],
                                  exit: _maze!.exit,
                                ),
                                // ✅ NEW: Speed button overlay
                                if (_started && !_finished)
                                  Positioned(
                                    right: 24,
                                    bottom: 24,
                                    child: _SpeedButton(
                                      speed: _simulationSpeed,
                                      color: color,
                                      onTap: _toggleSpeed,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Overlays
          if (_awaitingSelection ||
              _countingDown ||
              (!_started && !_awaitingSelection))
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.65),
                alignment: Alignment.center,
                child: _awaitingSelection
                    ? _ModernOverlayPill(
                        text: 'Select your competitor',
                        icon: Icons.pets_rounded,
                        color: color,
                      )
                    : _ModernCountdown(count: _count, color: color),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(Color color) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(.15), blurRadius: 16)],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withOpacity(.5), color.withOpacity(.1)],
                ),
                border: Border.all(color: color.withOpacity(.6), width: 2),
              ),
              child: Icon(Icons.psychology_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EARTHEN ACADEMY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      shadows: [
                        Shadow(color: color.withOpacity(.5), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Level ${widget.level} • Maze Trial',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${compLevel?.rewardAmount ?? 0}',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

// New modern results dialog widget
class _ResultsDialog extends StatelessWidget {
  final List<_Actor> ranked;
  final bool isVictory;
  final Color color;
  final int level;
  final CompetitionLevel compLevel;

  const _ResultsDialog({
    required this.ranked,
    required this.isVictory,
    required this.color,
    required this.level,
    required this.compLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isVictory
                ? Colors.amber.withOpacity(.5)
                : color.withOpacity(.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isVictory
                  ? Colors.amber.withOpacity(.3)
                  : color.withOpacity(.2),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isVictory
                      ? [
                          Colors.amber.withOpacity(.2),
                          Colors.orange.withOpacity(.1),
                        ]
                      : [color.withOpacity(.15), Colors.transparent],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isVictory
                        ? Icons.emoji_events_rounded
                        : Icons.psychology_rounded,
                    color: isVictory ? Colors.amber : color,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVictory ? 'VICTORY!' : 'RACE COMPLETE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: isVictory
                              ? Colors.amber.withOpacity(.6)
                              : color.withOpacity(.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVictory
                        ? 'You navigated the maze first!'
                        : '${ranked.first.name} reached the exit first',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Podium
            Padding(
              padding: const EdgeInsets.all(20),
              child: _ModernPodium(ranked: ranked, color: color),
            ),

            // Reward (if victory)
            if (isVictory)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REWARD EARNED',
                          style: TextStyle(
                            color: Colors.amber.shade300,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Continue button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop({
                    'winner': ranked.first.name,
                    'level': level,
                    'reward': compLevel.rewardResource,
                    'amount': isVictory ? compLevel.rewardAmount : 0,
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isVictory
                          ? [Colors.amber, Colors.orange.shade700]
                          : [color, color.withOpacity(.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isVictory ? Colors.amber : color).withOpacity(
                          .4,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'CONTINUE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isVictory ? Colors.black : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
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

// Modern podium with better styling
class _ModernPodium extends StatelessWidget {
  final List<_Actor> ranked;
  final Color color;

  const _ModernPodium({required this.ranked, required this.color});

  @override
  Widget build(BuildContext context) {
    Widget place(_Actor actor, int position) {
      final heights = [72.0, 56.0, 48.0, 40.0];
      final h = heights[position - 1];

      final medals = [
        Icons.workspace_premium_rounded,
        Icons.military_tech_rounded,
        Icons.emoji_events_outlined,
        Icons.star_outline_rounded,
      ];

      final colors = [
        Colors.amber,
        Colors.grey.shade300,
        Colors.orange.shade700,
        Colors.blue.shade300,
      ];

      final medal = medals[position - 1];
      final medalColor = colors[position - 1];

      return Expanded(
        child: Column(
          children: [
            // Medal icon
            Icon(medal, color: medalColor, size: position == 1 ? 32 : 24),
            const SizedBox(height: 8),

            // Position number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: medalColor.withOpacity(.2),
                border: Border.all(color: medalColor, width: 2),
              ),
              child: Center(
                child: Text(
                  '$position',
                  style: TextStyle(
                    color: medalColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Podium block
            Container(
              height: h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    medalColor.withOpacity(.25),
                    medalColor.withOpacity(.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border.all(color: medalColor.withOpacity(.4), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actor.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        size: 12,
                        color: Colors.blue.shade300,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        actor.iq.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.speed_rounded,
                        size: 12,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        actor.spd.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.green.shade300,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
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

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (ranked.length > 1) place(ranked[1], 2),
          const SizedBox(width: 8),
          place(ranked[0], 1),
          const SizedBox(width: 8),
          if (ranked.length > 2) place(ranked[2], 3),
          const SizedBox(width: 8),
          if (ranked.length > 3) place(ranked[3], 4),
        ],
      ),
    );
  }
}

class _MazeBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // Subtle vignette
    final vignette =
        RadialGradient(
          colors: [Colors.white.withOpacity(.02), Colors.transparent],
        ).createShader(
          Rect.fromCircle(
            center: size.center(Offset.zero),
            radius: size.longestSide * 0.7,
          ),
        );
    canvas.drawRect(Offset.zero & size, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(_MazeBackdropPainter old) => false;
}

class _ModernCountdown extends StatelessWidget {
  final int count;
  final Color color;

  const _ModernCountdown({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = count == 0 ? 'GO!' : '$count';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.5), width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(.3), blurRadius: 24)],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: count == 0 ? Colors.amber : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: count == 0 ? 56 : 64,
            letterSpacing: 2,
            shadows: [
              Shadow(color: count == 0 ? Colors.amber : color, blurRadius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernOverlayPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _ModernOverlayPill({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.4), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(.25), blurRadius: 20)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernHudBar extends StatelessWidget {
  final Color color;
  final List<_Actor> racers;
  final Offset exit;

  const _ModernHudBar({
    required this.color,
    required this.racers,
    required this.exit,
  });

  double _dist(Offset a, Offset b) => (a.dx - b.dx).abs() + (a.dy - b.dy).abs();

  @override
  Widget build(BuildContext context) {
    final maxD =
        racers.map((r) => _dist(r.pos, exit)).fold<double>(0, math.max) + 1;

    Widget racerRow(_Actor a, int index) {
      final d = _dist(a.pos, exit);
      final progress = (1 - (d / maxD)).clamp(0.0, 1.0);
      final isPlayer = index == 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isPlayer
              ? color.withOpacity(.15)
              : Colors.white.withOpacity(.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlayer
                ? color.withOpacity(.4)
                : Colors.white.withOpacity(.1),
          ),
        ),
        child: Row(
          children: [
            // Position indicator
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isPlayer
                    ? color.withOpacity(.3)
                    : Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPlayer
                      ? color.withOpacity(.6)
                      : Colors.white.withOpacity(.2),
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isPlayer ? color : Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name
            SizedBox(
              width: 80,
              child: Text(
                a.name,
                style: TextStyle(
                  color: Colors.white.withOpacity(.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Progress bar
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPlayer
                              ? [color, color.withOpacity(.7)]
                              : [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: (isPlayer ? color : Colors.orange)
                                .withOpacity(.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Stats
            Row(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  size: 14,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(width: 3),
                Text(
                  a.iq.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.speed_rounded,
                  size: 14,
                  color: Colors.green.shade300,
                ),
                const SizedBox(width: 3),
                Text(
                  a.spd.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'Race Progress',
                style: TextStyle(
                  color: Colors.white.withOpacity(.95),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...racers.asMap().entries.map((e) => racerRow(e.value, e.key)),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final int speed;
  final Color color;
  final VoidCallback onTap;

  const _SpeedButton({
    required this.speed,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(.8)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '${speed}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picker nav (kept same signature you used earlier)
Future<String?> pickInstanceForCompetition({
  required BuildContext context,
  required CompetitionBiome biome,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => CompetitionPickerScreen(biome: biome)),
  );
}

class _NPCSpriteOverlay extends StatefulWidget {
  final _Actor actor;
  final double cell;
  final Size boardSize;
  final Color color;

  const _NPCSpriteOverlay({
    required this.actor,
    required this.cell,
    required this.boardSize,
    required this.color,
  });

  @override
  State<_NPCSpriteOverlay> createState() => _NPCSpriteOverlayState();
}

class _NPCSpriteOverlayState extends State<_NPCSpriteOverlay> {
  Future<_SpriteMeta>? _spriteFuture;

  @override
  void initState() {
    super.initState();
    _spriteFuture = _loadRandomNPCSprite();
  }

  Future<_SpriteMeta> _loadRandomNPCSprite() async {
    final repo = context.read<CreatureCatalog>();

    // ✅ Try to find creature by exact name match first
    final exactMatch = repo.creatures.firstWhere(
      (c) => c.name.toLowerCase() == widget.actor.name.toLowerCase(),
      orElse: () {
        // Fallback: random compatible creature if name not found
        final compatible = repo.creatures.where((creature) {
          if (creature.spriteData == null) return false;
          return CompetitionBiome.earthen.canCompete(creature.types);
        }).toList();

        if (compatible.isEmpty) {
          throw Exception('No compatible creatures with sprites');
        }

        final rng = math.Random(widget.actor.name.hashCode);
        return compatible[rng.nextInt(compatible.length)];
      },
    );

    if (exactMatch.spriteData == null) {
      throw Exception('Creature ${widget.actor.name} has no sprite data');
    }

    // Create sprite widget from the matched creature
    final sprite = CreatureSprite(
      spritePath: exactMatch.spriteData!.spriteSheetPath,
      totalFrames: exactMatch.spriteData!.totalFrames,
      rows: exactMatch.spriteData!.rows,
      frameSize: Vector2(
        exactMatch.spriteData!.frameWidth.toDouble(),
        exactMatch.spriteData!.frameHeight.toDouble(),
      ),
      stepTime: exactMatch.spriteData!.frameDurationMs / 1000.0,
      scale: 1.0,
      saturation: 1.0,
      brightness: 1.0,
      hueShift: 0.0,
      isPrismatic: false,
    );

    return _SpriteMeta(
      widget: sprite,
      intelligence: widget.actor.iq,
      speed: widget.actor.spd,
      strength: 5.0,
      beauty: 5.0,
      level: 1,
      name: widget.actor.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SpriteMeta>(
      future: _spriteFuture,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return _SpriteOverlay(
          actor: widget.actor,
          meta: snap.data!,
          cell: widget.cell,
          boardSize: widget.boardSize,
        );
      },
    );
  }
}

class _SpriteOverlay extends StatelessWidget {
  final _Actor actor;
  final _SpriteMeta meta;
  final double cell;
  final Size boardSize;

  const _SpriteOverlay({
    required this.actor,
    required this.meta,
    required this.cell,
    required this.boardSize,
  });

  @override
  Widget build(BuildContext context) {
    final px = actor.pos.dx * cell;
    final py = actor.pos.dy * cell;

    // ✅ NEW: Make sprites bigger - 1.5x to 2x the cell size
    final spriteSize =
        cell * 1.8; // Adjust this multiplier (1.5, 1.8, 2.0, etc.)

    // ✅ Center the larger sprite on the cell
    final offsetX = px - (spriteSize - cell) / 2;
    final offsetY = py - (spriteSize - cell) / 2;

    return SizedBox(
      width: boardSize.width,
      height: boardSize.height,
      child: Stack(
        children: [
          Positioned(
            left: offsetX,
            top: offsetY,
            width: spriteSize,
            height: spriteSize,
            child: FittedBox(fit: BoxFit.contain, child: meta.widget),
          ),
        ],
      ),
    );
  }
}

/// Sprite + stats meta
class _SpriteMeta {
  _SpriteMeta({
    required this.widget,
    required this.intelligence,
    required this.speed,
    required this.strength,
    required this.beauty,
    required this.level,
    required this.name,
  });

  final Widget widget;
  final double intelligence;
  final double speed;
  final double strength;
  final double beauty;
  final int level;
  final String name;
}

Future<_SpriteMeta> _loadSpriteMeta(BuildContext ctx, String instanceId) async {
  final db = ctx.read<AlchemonsDatabase>();
  final repo = ctx.read<CreatureCatalog>();
  final inst = await db.creatureDao.getInstance(instanceId);
  if (inst == null) throw Exception('Instance missing');

  final base = repo.getCreatureById(inst.baseId);
  if (base == null || base.spriteData == null) throw Exception('Base missing');

  final genes = decodeGenetics(inst.geneticsJson);

  final sprite = CreatureSprite(
    spritePath: base.spriteData!.spriteSheetPath,
    totalFrames: base.spriteData!.totalFrames,
    rows: base.spriteData!.rows,
    frameSize: Vector2(
      base.spriteData!.frameWidth.toDouble(),
      base.spriteData!.frameHeight.toDouble(),
    ),
    stepTime: base.spriteData!.frameDurationMs / 1000.0,
    scale: scaleFromGenes(genes),
    saturation: satFromGenes(genes),
    brightness: briFromGenes(genes),
    hueShift: hueFromGenes(genes),
    isPrismatic: inst.isPrismaticSkin,
  );

  return _SpriteMeta(
    widget: sprite,
    intelligence: inst.statIntelligence,
    speed: inst.statSpeed,
    strength: inst.statStrength,
    beauty: inst.statBeauty,
    level: inst.level,
    name: inst.nickname ?? base.name,
  );
}

/// ======= Maze / Game model =======

class Maze {
  final int w, h;
  final List<List<bool>> walls; // true = wall
  late final Offset entry;
  late final Offset exit;

  Maze._(this.w, this.h, this.walls);

  static Maze generate(int w, int h, {int? seed}) {
    if (w.isEven || h.isEven) {
      throw ArgumentError('Use odd dimensions for nicer maze (got $w x $h)');
    }
    final rnd = math.Random(seed);
    final grid = List.generate(h, (_) => List<bool>.filled(w, true));

    void carve(int cx, int cy) {
      grid[cy][cx] = false;
      final dirs = [
        const Offset(2, 0),
        const Offset(-2, 0),
        const Offset(0, 2),
        const Offset(0, -2),
      ]..shuffle(rnd);
      for (final d in dirs) {
        final nx = cx + d.dx.toInt();
        final ny = cy + d.dy.toInt();
        if (nx > 0 && ny > 0 && nx < w - 1 && ny < h - 1 && grid[ny][nx]) {
          grid[cy + d.dy ~/ 2][cx + d.dx ~/ 2] = false; // knock wall
          carve(nx, ny);
        }
      }
    }

    carve(1, 1);
    final m = Maze._(w, h, grid);

    m.entry = m._firstOpenOnRow(1) ?? const Offset(1, 1);
    m.exit = m._firstOpenOnRow(h - 2, fromRight: true) ?? Offset(w - 2, h - 2);
    // ensure exit tile is open
    m.walls[m.exit.dy.toInt()][m.exit.dx.toInt()] = false;
    return m;
  }

  void addLoops({required double probability}) {
    final rnd = math.Random();

    bool wouldCreatePlaza(int x, int y) {
      // Any of the four 2x2 blocks around (x,y) would become all-open?
      bool open(int yy, int xx) => !walls[yy][xx];
      // bounds are safe because we only iterate 1..(w-2/h-2)
      final a =
          open(y - 1, x - 1) &&
          open(y - 1, x) &&
          open(y, x - 1); // top-left L already open
      final b =
          open(y - 1, x) && open(y - 1, x + 1) && open(y, x + 1); // top-right
      final c =
          open(y, x - 1) && open(y + 1, x - 1) && open(y + 1, x); // bottom-left
      final d =
          open(y, x + 1) &&
          open(y + 1, x) &&
          open(y + 1, x + 1); // bottom-right
      return a || b || c || d;
    }

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        if (!walls[y][x]) continue; // only consider knocking a wall

        // Only knock walls that connect two open cells in a straight line
        final horiz = !walls[y][x - 1] && !walls[y][x + 1];
        final vert = !walls[y - 1][x] && !walls[y + 1][x];
        if (!(horiz || vert)) continue;

        if (rnd.nextDouble() < probability) {
          // Prevent plazas: skip if this would make any 2x2 fully open
          if (wouldCreatePlaza(x, y)) continue;
          walls[y][x] = false;
        }
      }
    }
  }

  Offset? _firstOpenOnRow(int row, {bool fromRight = false}) {
    final xs = List.generate(w, (i) => i);
    if (fromRight) xs.reverse();
    for (final x in xs) {
      if (!walls[row][x]) return Offset(x.toDouble(), row.toDouble());
    }
    return null;
  }

  bool isWalkable(Offset p) {
    final x = p.dx.toInt(), y = p.dy.toInt();
    return x >= 0 && y >= 0 && x < w && y < h && !walls[y][x];
  }
}

/// Actor with INT (routing) + SPD (step rate)
class _Actor {
  final String name;
  Offset pos;
  final double iq; // 0..10
  final double spd; // 0..10 (affects cooldown)
  _Brain? brain;

  // runtime helpers
  int _cooldown = 1;
  final int _stuckFor = 0;

  _Actor(this.name, this.pos, {required this.iq, required this.spd});
}

class _NPC extends _Actor {
  _NPC(super.name, double iq, double spd, super.spawn)
    : super(iq: iq, spd: spd);

  factory _NPC.fromStats(String name, double iq, double spd, Offset spawn) {
    return _NPC(name, iq.isFinite ? iq : 5, spd.isFinite ? spd : 5, spawn)
      ..nameOverride(name);
  }

  void nameOverride(String n) {
    // ignore; just for clarity if needed
  }
}

/// ======= Brain / Pathfinding with intersection rolls =======

class BrainPersonality {
  final double
  planFrequency; // How often to replan (0-1, higher = more frequent)
  final double errorRate; // Base chance to make wrong turn (0-1)

  const BrainPersonality({
    required this.planFrequency,
    required this.errorRate,
  });

  static BrainPersonality randomized(math.Random rng, {required double iq}) {
    // Higher IQ = more frequent replanning = better adaptation
    final iq01 = (iq / 10.0).clamp(0.0, 1.0);

    return BrainPersonality(
      planFrequency: 0.3 + (iq01 * 0.5), // 0.3 to 0.8
      errorRate: (1.0 - iq01) * 0.20, // 20% errors at IQ 0, 0% at IQ 10
    );
  }
}

class _Brain {
  final _Actor me;
  final Maze maze;
  final math.Random rng;
  final BrainPersonality personality;

  bool _forcedFinish = false;

  // Core state
  List<Offset> _currentPath = [];
  int _stepsWithoutProgress = 0;
  Offset? _lastPos;

  // ✅ NEW: Track if we're committed to a wrong turn
  bool _committedToWrongPath = false;
  int _stepsSinceWrongTurn = 0;

  // Movement memory
  Offset _lastDir = Offset.zero;
  final Set<math.Point<int>> _visited = {};

  _Brain(this.me, this.maze, {required this.rng, required this.personality});

  Offset nextMove = Offset.zero;

  math.Point<int> _pt(Offset o) => math.Point(o.dx.toInt(), o.dy.toInt());

  void _forceOptimalPath() {
    if (_forcedFinish) return; // Already forced

    _forcedFinish = true;
    _committedToWrongPath = false; // Cancel any wrong turns
    _currentPath.clear(); // Clear current path
    _replan(); // Calculate optimal path
  }

  void update() {
    // Track if we're stuck
    if (_lastPos == me.pos) {
      _stepsWithoutProgress++;
    } else {
      _stepsWithoutProgress = 0;
      _lastPos = me.pos;
    }

    // Mark current tile as visited
    _visited.add(_pt(me.pos));

    // ✅ Skip mistake-making logic if forced to finish
    if (!_forcedFinish) {
      // If committed to wrong path, keep following it until dead end
      if (_committedToWrongPath) {
        _stepsSinceWrongTurn++;

        final neighbors = _getWalkableNeighbors(me.pos);
        final isDeadEnd = neighbors.length == 1;
        final tooLongWithoutProgress =
            _stepsSinceWrongTurn > 15 && _stepsWithoutProgress > 3;

        if (isDeadEnd || tooLongWithoutProgress) {
          _committedToWrongPath = false;
          _stepsSinceWrongTurn = 0;
          _currentPath.clear();
          _replan();
        } else {
          _followCurrentDirection(neighbors);
          return;
        }
      }

      // At intersections, chance to make a wrong turn
      final neighbors = _getWalkableNeighbors(me.pos);
      if (neighbors.length > 2 && _currentPath.isNotEmpty) {
        final errorRate = (1.0 - me.iq / 10.0) * 0.25;

        if (rng.nextDouble() < errorRate) {
          _makeWrongTurn(neighbors);
          _committedToWrongPath = true;
          _stepsSinceWrongTurn = 0;
          return;
        }
      }
    }

    // Only replan if truly stuck or no path
    if (_stepsWithoutProgress > 3 || _currentPath.isEmpty) {
      _replan();
    }

    // Follow the planned path
    if (_currentPath.isNotEmpty) {
      final nextTile = _currentPath.first;
      final dir = nextTile - me.pos;
      nextMove = Offset(dir.dx.sign.toDouble(), dir.dy.sign.toDouble());

      if ((me.pos - nextTile).distance < 0.1) {
        _currentPath.removeAt(0);
      }
    } else {
      final exits = _getWalkableNeighbors(me.pos);
      if (exits.isNotEmpty) {
        final unvisited = exits
            .where((e) => !_visited.contains(_pt(e)))
            .toList();
        final target = unvisited.isNotEmpty
            ? unvisited[rng.nextInt(unvisited.length)]
            : exits[rng.nextInt(exits.length)];

        final dir = target - me.pos;
        nextMove = Offset(dir.dx.sign.toDouble(), dir.dy.sign.toDouble());
      } else {
        nextMove = Offset.zero;
      }
    }

    _lastDir = nextMove;
  }

  // ✅ Keep following current direction when committed to wrong path
  void _followCurrentDirection(List<Offset> neighbors) {
    if (_lastDir == Offset.zero || neighbors.isEmpty) {
      // No previous direction, pick any forward direction
      if (neighbors.isNotEmpty) {
        final choice = neighbors[rng.nextInt(neighbors.length)];
        final dir = choice - me.pos;
        nextMove = Offset(dir.dx.sign.toDouble(), dir.dy.sign.toDouble());
        _lastDir = nextMove;
      } else {
        nextMove = Offset.zero;
      }
      return;
    }

    // Try to keep going in the same direction
    final forward = me.pos + _lastDir;
    if (maze.isWalkable(forward)) {
      nextMove = _lastDir;
      return;
    }

    // Can't go forward, pick another direction (but NOT backward if possible)
    final back = _lastDir * -1;
    final nonBack = neighbors.where((n) {
      final dir = n - me.pos;
      final step = Offset(dir.dx.sign.toDouble(), dir.dy.sign.toDouble());
      return step != back;
    }).toList();

    if (nonBack.isNotEmpty) {
      final choice = nonBack[rng.nextInt(nonBack.length)];
      final dir = choice - me.pos;
      nextMove = Offset(dir.dx.sign.toDouble(), dir.dy.sign.toDouble());
      _lastDir = nextMove;
    } else if (neighbors.isNotEmpty) {
      // Only option is to go back - we've hit a dead end
      final choice = neighbors.first;
      final dir = choice - me.pos;
      nextMove = Offset(dir.dx.sign.toDouble(), dir.dy.sign.toDouble());
      _lastDir = nextMove;
    } else {
      nextMove = Offset.zero;
    }
  }

  // ✅ Make a wrong turn at an intersection
  void _makeWrongTurn(List<Offset> neighbors) {
    // Pick a random direction that's NOT on our planned path
    final wrongTurns = neighbors.where((n) {
      return _currentPath.isEmpty || n != _currentPath.first;
    }).toList();

    if (wrongTurns.isNotEmpty) {
      final wrongChoice = wrongTurns[rng.nextInt(wrongTurns.length)];
      final dir = wrongChoice - me.pos;
      nextMove = Offset(dir.dx.sign.toDouble(), dir.dy.sign.toDouble());
      _lastDir = nextMove;

      // DON'T clear path yet - we're committed to this mistake!
    }
  }

  void onStepApplied({required bool moved}) {
    // Clear some visited tiles occasionally to allow re-exploration
    if (moved && _visited.length > 50 && rng.nextDouble() < 0.1) {
      final toRemove = _visited.take(10).toList();
      _visited.removeAll(toRemove);
    }
  }

  void _replan() {
    // Use A* with intelligence affecting heuristic weight
    final path = _aStar(me.pos, maze.exit);
    if (path.isNotEmpty) {
      _currentPath = path.skip(1).toList(); // Skip current position
      _stepsWithoutProgress = 0;
    }
  }

  List<Offset> _getWalkableNeighbors(Offset pos) {
    final neighbors = <Offset>[];
    for (final d in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      final next = pos + d;
      if (maze.isWalkable(next)) {
        neighbors.add(next);
      }
    }
    return neighbors;
  }

  List<Offset> _aStar(Offset start, Offset goal) {
    final openSet = <Offset>{start};
    final cameFrom = <math.Point<int>, Offset>{};
    final gScore = <math.Point<int>, double>{_pt(start): 0};

    final intFactor = (me.iq / 10.0).clamp(0.3, 1.0);

    double heuristic(Offset pos) {
      final dx = (pos.dx - goal.dx).abs();
      final dy = (pos.dy - goal.dy).abs();
      final manhattan = dx + dy;

      final noise = rng.nextDouble() * (1.0 - intFactor) * 8.0;
      return manhattan * intFactor + noise;
    }

    double fScore(Offset pos) {
      final g = gScore[_pt(pos)] ?? double.infinity;
      return g + heuristic(pos);
    }

    int maxIterations = 1000;
    int iterations = 0;

    while (openSet.isNotEmpty && iterations++ < maxIterations) {
      var current = openSet.first;
      var minF = fScore(current);
      for (final node in openSet) {
        final f = fScore(node);
        if (f < minF) {
          minF = f;
          current = node;
        }
      }

      if ((current - goal).distance < 0.1) {
        return _reconstructPath(cameFrom, current);
      }

      openSet.remove(current);

      for (final neighbor in _getWalkableNeighbors(current)) {
        final neighborPt = _pt(neighbor);

        final visitPenalty = _visited.contains(neighborPt) ? 2.0 : 0.0;
        final tentativeG =
            (gScore[_pt(current)] ?? double.infinity) + 1.0 + visitPenalty;

        if (tentativeG < (gScore[neighborPt] ?? double.infinity)) {
          cameFrom[neighborPt] = current;
          gScore[neighborPt] = tentativeG;
          openSet.add(neighbor);
        }
      }
    }

    return [];
  }

  List<Offset> _reconstructPath(
    Map<math.Point<int>, Offset> cameFrom,
    Offset current,
  ) {
    final path = <Offset>[current];
    var currentPt = _pt(current);

    while (cameFrom.containsKey(currentPt)) {
      current = cameFrom[currentPt]!;
      path.insert(0, current);
      currentPt = _pt(current);
    }

    return path;
  }
}

List<Offset> _neighborsWalkable(Maze maze, Offset p) {
  final nbs = <Offset>[];
  for (final d in const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
  ]) {
    final nb = p + d;
    if (maze.isWalkable(nb)) nbs.add(nb);
  }
  return nbs;
}

/// ======= Rendering =======

class _MazePainter extends CustomPainter {
  final Maze maze;
  final double cell;
  final Color primary;

  _MazePainter({required this.maze, required this.cell, required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // Floor with subtle pattern
    final floor = Paint()..color = const Color(0xFF1A1F24);
    for (int y = 0; y < maze.h; y++) {
      for (int x = 0; x < maze.w; x++) {
        if (!maze.walls[y][x]) {
          // Checkered pattern
          final isLight = (x + y) % 2 == 0;
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            Paint()
              ..color = isLight
                  ? const Color(0xFF2A2F34) // ✅ Lighter floor
                  : const Color(0xFF242A2F), // ✅ Slightly darker floor
          );
        }
      }
    }

    // Walls - MUCH DARKER
    for (int y = 0; y < maze.h; y++) {
      for (int x = 0; x < maze.w; x++) {
        if (maze.walls[y][x]) {
          final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);

          // ✅ Much darker gradient
          final gradient = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color.fromARGB(255, 29, 33, 37), // ✅ Very dark
              const Color.fromARGB(255, 40, 42, 48), // ✅ Almost black
            ],
          );

          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()..shader = gradient.createShader(rect),
          );

          // ✅ Darker border to make walls more distinct
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFF000000).withOpacity(.4)
              ..strokeWidth = 1.5,
          );
        }
      }
    }

    // Exit with glow
    final exitRect = Rect.fromLTWH(
      maze.exit.dx * cell,
      maze.exit.dy * cell,
      cell,
      cell,
    );

    // Glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(exitRect.inflate(4), const Radius.circular(8)),
      Paint()
        ..color = Colors.amber.withOpacity(.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Exit tile
    final exitGradient = RadialGradient(
      colors: [Colors.amber.shade200, Colors.amber.shade700],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(exitRect, const Radius.circular(6)),
      Paint()..shader = exitGradient.createShader(exitRect),
    );

    // Exit icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: '🏁',
        style: TextStyle(fontSize: cell * 0.6),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        maze.exit.dx * cell + (cell - iconPainter.width) / 2,
        maze.exit.dy * cell + (cell - iconPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => old.maze != maze;
}

/// ======= HUD & Overlays =======

class _HudBarRace extends StatelessWidget {
  final Color color;
  final List<_Actor> racers;
  final Offset exit;

  const _HudBarRace({
    required this.color,
    required this.racers,
    required this.exit,
  });

  double _dist(Offset a, Offset b) => (a.dx - b.dx).abs() + (a.dy - b.dy).abs();

  @override
  Widget build(BuildContext context) {
    final maxD =
        racers.map((r) => _dist(r.pos, exit)).fold<double>(0, math.max) + 1;

    Widget row(_Actor a, Color c) {
      final d = _dist(a.pos, exit);
      final progress = (1 - (d / maxD)).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                a.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [c, c.withOpacity(.75)]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'INT ${a.iq.toStringAsFixed(1)} • SPD ${a.spd.toStringAsFixed(1)}',
              style: TextStyle(
                color: Colors.white.withOpacity(.85),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.25),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: const [
                Icon(Icons.psychology_rounded, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text(
                  'Race to the Exit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            row(racers[0], Colors.lightGreenAccent),
            for (final n in racers.skip(1)) row(n, Colors.orangeAccent),
          ],
        ),
      ),
    );
  }
}

class _CountdownView extends StatelessWidget {
  final int count; // 3..2..1..0 (0 = GO!)
  const _CountdownView({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count == 0 ? 'GO!' : '$count';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.2)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: count == 0 ? 40 : 48,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _OverlayPill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<_Actor> ranked;
  final Color accent;
  const _Podium({required this.ranked, required this.accent});

  @override
  Widget build(BuildContext context) {
    Widget step(_Actor a, int place, {double h = 56}) {
      final label = switch (place) {
        1 => '1st',
        2 => '2nd',
        3 => '3rd',
        _ => '4th',
      };
      final crown = place == 1
          ? Icons.emoji_events_rounded
          : Icons.military_tech;

      return Expanded(
        child: Column(
          children: [
            Icon(
              crown,
              color: place == 1 ? Colors.amberAccent : Colors.white70,
              size: place == 1 ? 28 : 22,
            ),
            const SizedBox(height: 6),
            Container(
              height: h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(.35)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    a.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '$label • INT ${a.iq.toStringAsFixed(1)} • SPD ${a.spd.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 380,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          step(ranked.length > 1 ? ranked[1] : ranked[0], 2, h: 52),
          const SizedBox(width: 8),
          step(ranked[0], 1, h: 68),
          const SizedBox(width: 8),
          step(ranked.length > 2 ? ranked[2] : ranked[0], 3, h: 48),
          const SizedBox(width: 8),
          step(ranked.length > 3 ? ranked[3] : ranked.last, 4, h: 40),
        ],
      ),
    );
  }
}
