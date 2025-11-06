// lib/widgets/blob_party/floating_bubbles_overlay.dart
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

  Future<void> _loadFromDb() async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    final slots = await db.settingsDao.getBlobSlotsUnlocked(); // 1..3
    final ids = await db.settingsDao.getBlobInstanceSlots(); // List<String?>

    // ensure list length == slots
    final normalized = [
      ...ids.take(slots),
      ...List.filled((slots - ids.length).clamp(0, slots), null),
    ];

    // initial placement grid-ish
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
      _bubbles.add(b);
    }
    setState(() => _slotsUnlocked = slots);
  }

  @override
  void dispose() {
    _ticker.dispose();
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
    final inst = await showModalBottomSheet<CreatureInstance>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return InstancesSheet(
          theme: widget.theme,
          species: species,
          onTap: (CreatureInstance ci) {
            Navigator.pop(context, ci);
          },
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
                for (int i = 0; i < _bubbles.length; i++)
                  BubbleWidget(
                    key: ValueKey('bubble_$i'),
                    bubble: _bubbles[i],
                    color: _colorForInstance(repo, _bubbles[i].instance),

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
                        b.lastMoveAtMs = DateTime.now().millisecondsSinceEpoch;
                      }

                      setState(() {});
                    },
                    onDragEnd: (details) {
                      final b = _bubbles[i];

                      // If we were stationary just before lift, treat as place (no flight)
                      const quietMs =
                          140; // how long we must be still to cancel glide
                      final now = DateTime.now().millisecondsSinceEpoch;
                      final quiet = (now - b.lastMoveAtMs) >= quietMs;
                      if (quiet) {
                        b.vel = Offset.zero;
                        return;
                      }

                      // Gesture velocity in logical px/s
                      var v = details.pixelsPerSecond;
                      final speed = v.distance;

                      // Tunables
                      const gain = 1.0; // fling strength scaling
                      const maxSpeed = 700.0; // hard cap
                      const minThrow =
                          90.0; // below this we consider it a slow drag
                      const minFlight = 180.0; // floor for real flings
                      const glideSpeed = 240.0; // speed for slow-drag glides
                      const dragDirMin =
                          18.0; // need at least this much total drag to glide

                      if (speed >= minThrow) {
                        // Real fling → keep direction, floor/ceiling speed
                        var applied = (speed * gain).clamp(minFlight, maxSpeed);
                        b.vel = (v / speed) * applied;
                      } else if (b.totalDrag >= dragDirMin) {
                        // Slow drag → glide along accumulated drag direction
                        final dirLen = b.dragAccum.distance;
                        if (dirLen > 0) {
                          b.vel = (b.dragAccum / dirLen) * glideSpeed;
                        } else {
                          b.vel = Offset.zero;
                        }
                      } else {
                        // Basically a tap/place
                        b.vel = Offset.zero;
                      }
                    },
                    // context menu
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
                          size: 96,
                        ),
                      );
                    },
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

  // NEW: accumulate drag direction for slow drags
  Offset dragAccum = Offset.zero;

  void toggle() => expanded = !expanded;
}
