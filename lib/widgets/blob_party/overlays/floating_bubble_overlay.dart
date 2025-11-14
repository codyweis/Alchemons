// lib/widgets/blob_party/floating_bubbles_overlay.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/blob_party/bubble_widget.dart';
import 'package:alchemons/widgets/blob_party/floating_creature.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FloatingBubblesOverlay extends StatefulWidget {
  const FloatingBubblesOverlay({
    super.key,
    this.regionPadding = const EdgeInsets.fromLTRB(12, 140, 12, 160),
    required this.discoveredCreatures,
    required this.theme,
  });

  final EdgeInsets regionPadding;
  final List<CreatureEntry> discoveredCreatures;

  final FactionTheme theme;

  @override
  State<FloatingBubblesOverlay> createState() => _FloatingBubblesOverlayState();
}

class _FloatingBubblesOverlayState extends State<FloatingBubblesOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  final List<_Bubble> _bubbles = [];
  Size _regionSize = Size.zero;
  int _slotsUnlocked = 1;

  final List<_Spark> _sparks = [];

  Timer? _saveLayoutDebounce;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _loadFromDb(); // <- build bubbles from DB (default 1)
  }

  Duration _lastElapsed = Duration.zero;

  void _tick(Duration elapsed) {
    if (!mounted || _regionSize == Size.zero) return;

    // Compute delta time in seconds since last frame (clamped to avoid giant steps)
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(
      0.0,
      1 / 20,
    );
    _lastElapsed = elapsed;

    // --- 1. UPDATE SPARKS (ADD THIS SECTION) ---
    const sparkGravity = 250.0;
    _sparks.removeWhere((s) => s.life <= 0);
    for (final s in _sparks) {
      s.update(dt);

      // keep softly in-bounds
      const bounce = 0.6;
      final r = s.radius;
      final maxX = _regionSize.width - r, maxY = _regionSize.height - r;
      if (s.pos.dx < r) {
        s.pos = Offset(r, s.pos.dy);
        s.vel = Offset(s.vel.dx.abs() * bounce, s.vel.dy);
      } else if (s.pos.dx > maxX) {
        s.pos = Offset(maxX, s.pos.dy);
        s.vel = Offset(-s.vel.dx.abs() * bounce, s.vel.dy);
      }
      if (s.pos.dy < r) {
        s.pos = Offset(s.pos.dx, r);
        s.vel = Offset(s.vel.dx, s.vel.dy.abs() * bounce);
      } else if (s.pos.dy > maxY) {
        s.pos = Offset(s.pos.dx, maxY);
        s.vel = Offset(s.vel.dx, -s.vel.dy.abs() * bounce);
      }
    }
    // --- END SPARK UPDATE ---

    // 1) integrate motion + wall bounce + damping
    for (final b in _bubbles) {
      b.pos += b.vel * dt;

      // soft wobble drift
      final wob = Offset(
        math.sin(b.seed + b.life * 0.7) * 10.0, // was 6
        math.cos(b.seed + b.life * 0.9) * 10.0,
      );
      b.pos += wob * (0.006 * dt * 60); // a bit more idle wander

      // keep inside padded region
      final r = b.radius;
      final maxX = _regionSize.width - r, maxY = _regionSize.height - r;
      if (b.pos.dx < r) {
        b.pos = Offset(r, b.pos.dy);
        b.vel = Offset(b.vel.dx.abs(), b.vel.dy) * 0.98;
      } else if (b.pos.dx > maxX) {
        b.pos = Offset(maxX, b.pos.dy);
        b.vel = Offset(-b.vel.dx.abs(), b.vel.dy) * 0.98;
      }
      if (b.pos.dy < r) {
        b.pos = Offset(b.pos.dx, r);
        b.vel = Offset(b.vel.dx, b.vel.dy.abs()) * 0.98;
      } else if (b.pos.dy > maxY) {
        b.pos = Offset(b.pos.dx, maxY);
        b.vel = Offset(b.vel.dx, -b.vel.dy.abs()) * 0.98;
      }

      const tau = .8; // seconds; speed halves every ~1.2s (tune this)
      final decay = math.pow(0.5, dt / tau) as double;
      b.vel *= decay;
      b.life += dt;
    }

    // 2) pairwise collisions (elastic-ish)
    for (int i = 0; i < _bubbles.length; i++) {
      for (int j = i + 1; j < _bubbles.length; j++) {
        final a = _bubbles[i], c = _bubbles[j];
        final delta = c.pos - a.pos;
        final dist = delta.distance;
        final minDist = a.radius + c.radius - 2; // slight overlap tolerance
        if (dist > 0 && dist < minDist) {
          _spawnSparks(
            (a.pos + c.pos) / 2.0, // Midpoint
            a.color, // Color from bubble A
            c.color, // Color from bubble C
          );
          final n = delta / dist;
          final push = (minDist - dist) * 0.6;
          a.pos -= n * push * 0.5;
          c.pos += n * push * 0.5;

          // exchange velocity along the normal
          final va = a.vel.dx * n.dx + a.vel.dy * n.dy;
          final vb = c.vel.dx * n.dx + c.vel.dy * n.dy;
          final impulse = (vb - va) * 0.75;
          a.vel += n * impulse;
          c.vel -= n * impulse;
        }
      }
    }

    setState(() {});
  }

  void _scheduleSaveLayout() {
    // Reset the debounce timer so we only write after a short pause
    _saveLayoutDebounce?.cancel();
    _saveLayoutDebounce = Timer(const Duration(milliseconds: 500), () {
      _persistLayout();
    });
  }

  Future<void> _persistLayout() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();

    // Save all bubble positions keyed by index
    for (int i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      final key = 'blob_slot_${i}_pos';
      final value =
          '${b.pos.dx.toStringAsFixed(1)},${b.pos.dy.toStringAsFixed(1)}';
      await db.settingsDao.setSetting(key, value);
    }
  }

  Future<void> _loadFromDb() async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    final slots = await db.settingsDao.getBlobSlotsUnlocked(); // 1..3
    final ids = await db.settingsDao.getBlobInstanceSlots(); // List<String?>

    final normalized = [
      ...ids.take(slots),
      ...List.filled((slots - ids.length).clamp(0, slots), null),
    ];

    final rng = math.Random();
    final baseR = 28.0; // smaller collapsed bubble
    _bubbles.clear();
    for (var i = 0; i < slots; i++) {
      final xJitter = rng.nextDouble() * 120;
      final yJitter = rng.nextDouble() * 140;

      final b = _Bubble(
        pos: Offset(
          widget.regionPadding.left + baseR + 40 + xJitter + i * 24,
          widget.regionPadding.top + baseR + 60 + yJitter + i * 18,
        ),
        vel: Offset.zero,
        radius: baseR,
        seed: rng.nextDouble() * math.pi * 2,
      );

      // hydrate instance if saved
      final id = normalized[i];
      if (id != null) {
        final inst = await db.creatureDao.getInstance(id);
        if (inst != null) b.instance = inst;
      }

      // NEW: hydrate persisted position if present
      final savedPosRaw = await db.settingsDao.getSetting('blob_slot_${i}_pos');
      if (savedPosRaw != null && savedPosRaw.isNotEmpty) {
        final parts = savedPosRaw.split(',');
        if (parts.length == 2) {
          final dx = double.tryParse(parts[0]);
          final dy = double.tryParse(parts[1]);
          if (dx != null && dy != null) {
            b.pos = Offset(dx, dy);
          }
        }
      }

      _bubbles.add(b);
    }
    setState(() => _slotsUnlocked = slots);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _saveLayoutDebounce?.cancel();

    super.dispose();
  }

  void _openDetailsFor(_Bubble b) {
    final inst = b.instance;
    if (inst == null) return;

    final repo = context.read<CreatureCatalog>();
    final base = repo.getCreatureById(inst.baseId);
    if (base == null) return;

    // `isDiscovered` is effectively true when instanceId is provided
    CreatureDetailsDialog.show(
      context,
      base,
      false,
      instanceId: inst.instanceId,
    );
  }

  // ... _tick() stays the same (integration, damping, collisions) ...

  Color _colorForInstance(CreatureCatalog repo, CreatureInstance? inst) {
    if (inst == null) return Colors.white.withOpacity(0.35);
    final base = repo.getCreatureById(inst.baseId);
    final type = (base?.types.isNotEmpty ?? false)
        ? base!.types.first
        : 'Neutral';
    return BreedConstants.getTypeColor(type);
  }

  Future<void> _pickInstanceFor(_Bubble b, int index) async {
    final repo = context.read<CreatureCatalog>();
    final db = context.read<AlchemonsDatabase>();

    final available = await db.creatureDao
        .getSpeciesWithInstances(); // Set<String> baseIds

    final filteredDiscovered = filterByAvailableInstances(
      widget.discoveredCreatures,
      available,
    );

    // 1) pick species first
    final pickedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return CreatureSelectionSheet(
              scrollController: scrollController,
              discoveredCreatures: filteredDiscovered,
              onSelectCreature: (creatureId) {
                Navigator.pop(context, creatureId);
              },
            );
          },
        );
      },
    );
    if (pickedSpeciesId == null) return;

    final species = repo.getCreatureById(pickedSpeciesId);
    if (species == null) return;

    // 2) pick instance
    // 2) pick instance  (in _pickInstanceFor)
    final inst = await showModalBottomSheet<CreatureInstance>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BottomSheetShell(
          theme: widget.theme,
          title: '${species.name} Specimens',
          child: InstancesSheet(
            theme: widget.theme,
            species: species,
            onTap: (CreatureInstance ci) {
              Navigator.pop(context, ci);
            },
          ),
        );
      },
    );

    if (inst == null) return;

    // 3) assign & persist
    setState(() {
      b.instance = inst;
      b.expanded = true;
    });
    await db.settingsDao.setBlobSlotInstance(index, inst.instanceId);
    HapticFeedback.lightImpact();
  }

  void _spawnSparks(Offset pos, Color c1, Color c2) {
    final rng = math.Random();

    // helper: keep the exact hue; only nudge saturation/value (no hue shift)
    Color _boostSameHue(
      Color src, {
      double satMul = 1.06,
      double valMul = 1.12,
    }) {
      final hsv = HSVColor.fromColor(src);
      return hsv
          .withSaturation((hsv.saturation * satMul).clamp(0.0, 1.0))
          .withValue((hsv.value * valMul).clamp(0.0, 1.0))
          .toColor();
    }

    // fewer, weightier sparks
    final count = 3 + rng.nextInt(4); // 3..6
    for (int i = 0; i < count; i++) {
      // upward-ish with spread
      final baseAngle = -math.pi / 2; // up
      final jitter = (rng.nextDouble() - 0.5) * math.pi * 0.6; // +/- ~54°
      final angle = baseAngle + jitter;

      final speed = 60.0 + rng.nextDouble() * 110.0;
      final vel = Offset(math.cos(angle) * speed, math.sin(angle) * speed);

      final life = 0.8 + rng.nextDouble() * 0.7; // 0.8..1.5 s
      final radius = 2.2 + rng.nextDouble() * 2.6; // 2.2..4.8 px

      // strictly use only the touching elements’ colors
      final base = (i.isEven ? c1 : c2);
      final color = _boostSameHue(base).withOpacity(1.0);

      final spin = (rng.nextDouble() - 0.5) * 2.2; // -1.1..1.1 rad/s
      final damping = 0.30 + rng.nextDouble() * 0.25; // gentle drift

      _sparks.add(
        _Spark(
          pos: pos,
          vel: vel,
          color: color,
          life: life,
          radius: radius,
          spin: spin,
          damping: damping,
          seed: rng.nextDouble() * 1000.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();

    return Positioned.fill(
      child: Padding(
        padding: widget.regionPadding,
        child: LayoutBuilder(
          builder: (_, c) {
            _regionSize = Size(c.maxWidth, c.maxHeight);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // --- 1. MODIFIED BUBBLE LOOP ---
                for (int i = 0; i < _bubbles.length; i++)
                  // We use a closure here to calculate the color
                  // and assign it to the bubble in one go.
                  () {
                    final b = _bubbles[i];
                    // CALCULATE AND CACHE THE COLOR
                    final color = _colorForInstance(repo, b.instance);
                    b.color = color; // <-- Store color on the model

                    return BubbleWidget(
                      key: ValueKey('bubble_$i'),
                      bubble: _bubbles[i],
                      color: color, // <-- Use the calculated color
                      // NEW
                      onDragStart: () {
                        final b = _bubbles[i];
                        b.dragAccum = Offset.zero;
                        b.totalDrag = 0;
                        b.lastMoveAtMs = DateTime.now().millisecondsSinceEpoch;
                        b.vel = Offset.zero; // kill residual while dragging
                      },
                      onDragUpdate: (delta) {
                        final b = _bubbles[i];
                        b.pos += delta;

                        // Only accumulate if it’s real motion (filters jitter while holding still)
                        const moveEps = 0.8; // px
                        final d = delta.distance;
                        if (d > moveEps) {
                          b.dragAccum += delta;
                          b.totalDrag += d;
                          b.lastMoveAtMs =
                              DateTime.now().millisecondsSinceEpoch;
                        }

                        setState(() {});
                      },
                      onDragEnd: (details) {
                        final b = _bubbles[i];

                        const quietMs = 140;
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final quiet = (now - b.lastMoveAtMs) >= quietMs;
                        if (quiet) {
                          b.vel = Offset.zero;
                          _scheduleSaveLayout(); // NEW: persist final resting spot
                          return;
                        }

                        var v = details.pixelsPerSecond;
                        final speed = v.distance;

                        const gain = 1.0;
                        const maxSpeed = 700.0;
                        const minThrow = 90.0;
                        const minFlight = 180.0;
                        const glideSpeed = 240.0;
                        const dragDirMin = 18.0;

                        if (speed >= minThrow) {
                          var applied = (speed * gain).clamp(
                            minFlight,
                            maxSpeed,
                          );
                          b.vel = (v / speed) * applied;
                        } else if (b.totalDrag >= dragDirMin) {
                          final dirLen = b.dragAccum.distance;
                          if (dirLen > 0) {
                            b.vel = (b.dragAccum / dirLen) * glideSpeed;
                          } else {
                            b.vel = Offset.zero;
                          }
                        } else {
                          b.vel = Offset.zero;
                        }

                        // NEW: any kind of throw/drag completion → schedule save
                        _scheduleSaveLayout();
                      }, // context menu
                      onLongPress: () async {
                        final b = _bubbles[i];

                        final items = <PopupMenuEntry<String>>[];

                        if (b.instance != null) {
                          items.add(
                            const PopupMenuItem(
                              value: 'details',
                              child: Text('View details'),
                            ),
                          );
                          items.add(
                            const PopupMenuItem(
                              value: 'reassign',
                              child: Text('Reassign creature'),
                            ),
                          );
                          items.add(
                            const PopupMenuItem(
                              value: 'clear',
                              child: Text('Remove creature'),
                            ),
                          );
                        } else {
                          items.add(
                            const PopupMenuItem(
                              value: 'reassign',
                              child: Text('Assign creature'),
                            ),
                          );
                        }

                        final choice = await showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            b.pos.dx,
                            b.pos.dy,
                            _regionSize.width - b.pos.dx,
                            _regionSize.height - b.pos.dy,
                          ),
                          items: items,
                        );

                        if (choice == null) return;

                        if (choice == 'details') {
                          _openDetailsFor(b);
                        } else if (choice == 'reassign') {
                          await _pickInstanceFor(b, i);
                        } else if (choice == 'clear') {
                          setState(() => b.instance = null);
                          await context
                              .read<AlchemonsDatabase>()
                              .settingsDao
                              .setBlobSlotInstance(i, null);
                        }
                      },
                      // tap (toggle / pick first)
                      onTap: () async {
                        final b = _bubbles[i];
                        if (!b.expanded && b.instance == null) {
                          await _pickInstanceFor(b, i);
                          return;
                        }
                        b.toggle();
                        HapticFeedback.selectionClick();
                        setState(() {});
                      },
                      builderInside: (pub) {
                        final b = _bubbles[i];
                        if (!pub.expanded || b.instance == null) {
                          return const SizedBox.shrink();
                        }
                        final base = repo.getCreatureById(b.instance!.baseId);
                        if (base?.spriteData == null) {
                          return const SizedBox.shrink();
                        }
                        return FloatingCreature(
                          sprite: InstanceSprite(
                            creature: base!,
                            instance: b.instance!,
                            size: 45, // You changed this, looks good.
                          ),
                        );
                      },
                    );
                  }(), // <-- Note the () to invoke the closure
                // --- 2. NEW SPARK RENDERING LOOP ---
                IgnorePointer(
                  ignoring: true,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _AlchemySparkPainter(_sparks),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bubble {
  _Bubble({
    required this.pos,
    required this.vel,
    required this.radius,
    required this.seed,
  });

  Offset pos;
  Offset vel;
  double radius;
  double seed;
  double life = 0;
  CreatureInstance? instance;
  bool expanded = false;
  bool dragging = false;
  double totalDrag = 0; // NEW: total path length this drag
  int lastMoveAtMs = 0; // NEW: last time we saw real movement
  Color color = Colors.white;
  // NEW: accumulate drag direction for slow drags
  Offset dragAccum = Offset.zero;

  void toggle() => expanded = !expanded;
}

class _Spark {
  _Spark({
    required this.pos,
    required this.vel,
    required this.color,
    required this.life,
    required this.radius,
    required this.spin, // radians/s, small
    required this.damping, // 0..1 per second
    required this.seed,
  }) : initialLife = life;

  Offset pos;
  Offset vel;
  Color color;
  double life;
  final double initialLife;

  double radius; // visual size (px)
  double spin; // angular precession of velocity
  double damping; // velocity decay factor per second
  double seed; // per-spark randomness

  // short trail (most recent last)
  final List<Offset> _trail = <Offset>[];

  void update(double dt) {
    life -= dt;
    if (life <= 0) return;

    // Gentle buoyancy upward
    const double buoyancy = -28.0; // negative Y = up
    vel += const Offset(0, buoyancy) * dt;

    // Swirl: rotate velocity slightly each frame
    if (spin != 0) {
      final c = math.cos(spin * dt);
      final s = math.sin(spin * dt);
      final vx = vel.dx * c - vel.dy * s;
      final vy = vel.dx * s + vel.dy * c;
      vel = Offset(vx, vy);
    }

    // Subtle noise wobble (cheap)
    final n = math.sin((life + seed) * 7.0);
    vel += Offset(n * 6.0, -n.abs() * 4.0) * dt;

    // Damping
    final decay = math.pow(1.0 - damping, dt).toDouble(); // continuous-ish
    vel *= decay.clamp(0.0, 1.0);

    pos += vel * dt;

    // Trail bookkeeping (cap length)
    _trail.add(pos);
    if (_trail.length > 6) _trail.removeAt(0);
  }
}

class _AlchemySparkPainter extends CustomPainter {
  _AlchemySparkPainter(this.sparks);

  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint core = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1); // soft bloom

    final Paint halo = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final Paint trail = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final s in sparks) {
      if (s.life <= 0) continue;

      final t = (s.life / s.initialLife).clamp(0.0, 1.0);
      // ease-out for opacity/size
      final ease = t * t * (3 - 2 * t);

      // Trail: thinner, fading with segments
      if (s._trail.length >= 2) {
        for (int i = 0; i < s._trail.length - 1; i++) {
          final a = s._trail[i];
          final b = s._trail[i + 1];
          final segT = (i + 1) / s._trail.length;
          trail
            ..color = s.color.withOpacity(0.10 * ease * segT)
            ..strokeWidth = (s.radius * 0.9) * segT;
          canvas.drawLine(a, b, trail);
        }
      }

      // Halo first (bigger & softer), then bright core
      final haloR = s.radius * (1.8 + 0.4 * (1 - ease));
      halo.color = adjustBrightness(s.color, .1);

      canvas.drawCircle(s.pos, haloR, halo);

      final coreR = s.radius * (0.9 + 0.2 * ease);
      core.color = adjustBrightness(s.color, 2);
      canvas.drawCircle(s.pos, coreR, core);
    }
  }

  Color adjustBrightness(Color color, double factor) {
    // factor > 1.0 → brighter; factor < 1.0 → darker
    final hsv = HSVColor.fromColor(color);
    final newValue = (hsv.value * factor).clamp(0.0, 1.0);
    return hsv.withValue(newValue).toColor();
  }

  @override
  bool shouldRepaint(covariant _AlchemySparkPainter oldDelegate) {
    return true;
  }
}
