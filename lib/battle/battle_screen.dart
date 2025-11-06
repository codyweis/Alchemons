import 'package:alchemons/battle/arena_bridge.dart';
import 'package:alchemons/battle/battle_game_core.dart';
import 'package:alchemons/battle/planning_input_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../battle/battle_bootstrap.dart';

class BattleScreen extends StatefulWidget {
  final List<BattleCreature> team;
  const BattleScreen({super.key, required this.team});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with SingleTickerProviderStateMixin {
  BattleBootstrap? _battle; // nullable until sized
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battle')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_battle == null && size.width > 0 && size.height > 0) {
            // init now that we know the real canvas size
            _battle = BattleBootstrap(
              size,
              playerTeam10: widget.team,
              aiTeam10: widget.team,
            )..start();

            _ticker = createTicker((elapsed) {
              var dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
              dt = dt.clamp(0.0, 1 / 20.0); // clamp to avoid big jumps
              _lastElapsed = elapsed;
              if (dt > 0) {
                _battle!.tick(dt);
                if (mounted) setState(() {});
              }
            })..start();
          }

          if (_battle == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: BattlePainter(_battle!.arena, _battle!.state),
                  ),
                ),
                Positioned.fill(child: PlanningInputOverlay(battle: _battle!)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// lib/battle/battle_painter.dart
// Lightweight CustomPainter that draws bubbles, zones, and element nodes.

class BattlePainter extends CustomPainter {
  final PhysicsArena arena;
  final BattleState state;
  BattlePainter(this.arena, this.state);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawZones(canvas);
    _drawNodes(canvas);
    _drawBubbles(canvas);
    _drawScore(canvas, size);
  }

  void _drawBackground(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0F1222));
  }

  void _drawZones(Canvas c) {
    _drawZone(c, state.zoneP, const Color(0xFF2E7D32));
    _drawZone(c, state.zoneA, const Color(0xFF1565C0));
  }

  void _drawZone(Canvas c, TargetZone z, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withOpacity(0.6);
    c.drawCircle(z.center, z.rOuter, p);
    c.drawCircle(z.center, z.rMid, p..color = color.withOpacity(0.75));
    c.drawCircle(z.center, z.rInner, p..color = color);
  }

  void _drawNodes(Canvas c) {
    final p = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.amberAccent;
    for (final n in state.nodes) {
      if (n.consumed) continue;
      final r = Rect.fromCenter(center: n.pos, width: 18, height: 18);
      final path = Path()
        ..moveTo(r.center.dx, r.top)
        ..lineTo(r.right, r.center.dy)
        ..lineTo(r.center.dx, r.bottom)
        ..lineTo(r.left, r.center.dy)
        ..close();
      c.drawPath(path, p);
      // label
      final tp = TextPainter(
        text: TextSpan(
          text: n.element,
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, n.pos + const Offset(-16, -22));
    }
  }

  void _drawBubbles(Canvas c) {
    for (final b in arena.allBubbles()) {
      final color = _colorFor(b.element, b.team);
      c.drawCircle(b.pos, b.radius, Paint()..color = color.withOpacity(0.85));
      c.drawCircle(
        b.pos,
        b.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withOpacity(0.25),
      );
    }
  }

  void _drawScore(Canvas c, Size s) {
    final text = 'You  ${state.scoreP}  :  ${state.scoreA}  AI';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(s.width / 2 - tp.width / 2, 12));
  }

  Color _colorFor(String element, int team) {
    // Quick palette by element; adjust to your theme
    switch (element) {
      case 'Fire':
        return Colors.deepOrangeAccent;
      case 'Water':
        return Colors.lightBlueAccent;
      case 'Earth':
        return Colors.brown;
      case 'Air':
        return Colors.grey;
      case 'Ice':
        return Colors.cyanAccent;
      case 'Plant':
        return Colors.greenAccent;
      case 'Poison':
        return Colors.purpleAccent;
      case 'Lightning':
        return Colors.yellowAccent;
      default:
        return team == 0 ? Colors.tealAccent : Colors.indigoAccent;
    }
  }

  @override
  bool shouldRepaint(covariant BattlePainter oldDelegate) => true;
}
