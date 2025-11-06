import 'dart:ui';
import 'dart:math' as math;
import 'package:alchemons/games/competitions/earthen_maze_game.dart';
import 'package:alchemons/models/competition.dart';
import 'package:flutter/material.dart';

class CompetitionHubScreen extends StatefulWidget {
  const CompetitionHubScreen({super.key});

  @override
  State<CompetitionHubScreen> createState() => _CompetitionHubScreenState();
}

class _CompetitionHubScreenState extends State<CompetitionHubScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => CustomPaint(
                painter: _CompetitionBackdropPainter(t: _bgCtrl.value),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                //coming soon
                // Text('Coming Soon', style: TextStyle(color: Colors.white)),
                Expanded(child: _buildArenaGrid()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const accentColor = Color(0xFFB565FF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowCtrl,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _IconButton(
                icon: Icons.arrow_back_rounded,
                accentColor: accentColor,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMPETITION ARENAS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: accentColor.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Compete in elemental arenas to test your Alchemons',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withOpacity(.3)),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArenaGrid() {
    final arenas = CompetitionBiome.values;
    final width = MediaQuery.of(context).size.width;
    final cross = width >= 900
        ? 3
        : width >= 650
        ? 2
        : 1;

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.1,
      ),
      itemCount: arenas.length,
      // in CompetitionHubScreen._buildArenaGrid itemBuilder
      itemBuilder: (_, i) => _ArenaCard(
        biome: arenas[i],
        onTap: () {
          final biome = arenas[i];
          if (biome == CompetitionBiome.earthen) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EarthenMazeGameScreen(level: 1), // start at L1
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${biome.name} coming soon')),
            );
          }
        },
      ),
    );
  }
}

// Arena Card Widget
class _ArenaCard extends StatefulWidget {
  final CompetitionBiome biome;
  final VoidCallback onTap;

  const _ArenaCard({required this.biome, required this.onTap});

  @override
  State<_ArenaCard> createState() => _ArenaCardState();
}

class _ArenaCardState extends State<_ArenaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.biome.primaryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(.12),
                    Colors.black.withOpacity(.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(.25), blurRadius: 20),
                ],
              ),
              child: Stack(
                children: [
                  // Shine effect
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shine,
                      builder: (_, __) {
                        return ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (rect) {
                            final dx = rect.width * (_shine.value * 1.3 - .2);
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                color.withOpacity(.2),
                                Colors.transparent,
                              ],
                              stops: const [0.3, 0.5, 0.7],
                            ).createShader(
                              Rect.fromLTWH(
                                dx,
                                0,
                                rect.width * .25,
                                rect.height,
                              ),
                            );
                          },
                          child: Container(color: Colors.transparent),
                        );
                      },
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    color.withOpacity(.5),
                                    color.withOpacity(.08),
                                  ],
                                ),
                                border: Border.all(
                                  color: color.withOpacity(.6),
                                  width: 1.6,
                                ),
                              ),
                              child: Icon(
                                widget.biome.icon,
                                color: color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.biome.name,
                                style: const TextStyle(
                                  color: Color(0xFFE8EAED),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.biome.type.icon,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.biome.type.label.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.biome.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        if (widget.biome.allowedTypes.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: widget.biome.allowedTypes.map((type) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.15),
                                  ),
                                ),
                                child: Text(
                                  type,
                                  style: const TextStyle(
                                    color: Color(0xFFE8EAED),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400.withOpacity(.2),
                                  Colors.pink.shade400.withOpacity(.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.purple.withOpacity(.4),
                              ),
                            ),
                            child: const Text(
                              'ALL TYPES',
                              style: TextStyle(
                                color: Color(0xFFE8EAED),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Reuse glass components from harvest screen
class _GlassContainer extends StatelessWidget {
  final Color accentColor;
  final AnimationController glowController;
  final Widget child;

  const _GlassContainer({
    required this.accentColor,
    required this.glowController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (_, __) {
        final glow = 0.15 + (glowController.value * 0.15);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.08),
                    Colors.black.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glow),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _IconButton extends StatefulWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// Background painter
class _CompetitionBackdropPainter extends CustomPainter {
  final double t;

  _CompetitionBackdropPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F14);
    canvas.drawRect(Offset.zero & size, bg);

    // Curved lines
    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 4; i++) {
      final path = Path();
      final amp = 20.0 + i * 12;
      final speed = (t + i * .18) * 2 * math.pi;
      for (double x = 0; x <= size.width; x += 10) {
        final y =
            size.height * (0.2 + i * .2) +
            math.sin((x / size.width * 4 * math.pi) + speed) * amp;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, pathPaint);
    }

    // Particles
    final dot = Paint()..color = Colors.white.withOpacity(.06);
    for (int i = 0; i < 45; i++) {
      final px = (i * 40 + t * size.width) % size.width;
      final py = (size.height * (0.1 + (i % 6) * .16)) % size.height;
      final r = 1.0 + math.sin((t + i) * 2 * math.pi) * .5;
      canvas.drawCircle(Offset(px, py), r, dot);
    }
  }

  @override
  bool shouldRepaint(_CompetitionBackdropPainter old) => old.t != t;
}
