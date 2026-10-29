// lib/screens/cosmic/widgets/elemental_cache_prompt.dart
//
// The prompt that appears when the ship parks at a sealed elemental cache.
//
// It polls the game a few times a second because the thing it reports on — is
// a companion of the right element standing close enough — changes without the
// cosmic screen rebuilding.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_cache_data.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'planet_action_button.dart';

class ElementalCachePrompt extends StatefulWidget {
  const ElementalCachePrompt({
    super.key,
    required this.game,
    required this.cache,
    required this.onTap,
  });

  final CosmicGame game;
  final ElementalCache cache;
  final VoidCallback onTap;

  @override
  State<ElementalCachePrompt> createState() => _ElementalCachePromptState();
}

class _ElementalCachePromptState extends State<ElementalCachePrompt> {
  Timer? _poll;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ready = widget.game.cacheAttunementReady(widget.cache);
    _poll = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (!mounted) return;
      final ready = widget.game.cacheAttunementReady(widget.cache);
      if (ready != _ready) setState(() => _ready = ready);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing at all until a companion of the right element is standing close
    // enough. The sealed state used to sit on screen announcing itself; now the
    // cache stays quiet and the prompt IS the signal that you can open it.
    if (!_ready) return const SizedBox.shrink();

    final accent = elementColor(widget.cache.element);
    // The planet's lens, holding the cache's light as grains. (A glowing
    // rounded plate reading BREAK THE SEAL until 2026-10.) The seal is
    // named by what it asked for, never by its element — "a living spark",
    // not "LIGHTNING CACHE".
    return PlanetActionButton(
      label: 'OPEN',
      sublabel: 'Your companion answers ${cacheHintFor(widget.cache.element)}',
      light: accent,
      glyph: GrainGlyph(
        size: PlanetActionButton.glyphSize,
        animate: true,
        painter: (clock) => _SealedGrainsPainter(clock, accent),
      ),
      onTap: widget.onTap,
    );
  }
}

/// What the seal holds: a sphere of the element's grains, held a little
/// loose, as if it would come apart at a touch.
class _SealedGrainsPainter extends CustomPainter {
  _SealedGrainsPainter(this.clock, this.color) : super(repaint: clock);

  final ValueListenable<double>? clock;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final t = clock?.value ?? 0;
    GrainGlass.sphere(
      canvas,
      Offset(s / 2, s / 2),
      s * 0.28,
      t,
      a: color,
      spin: 0.8,
      gather: 0.82 + 0.06 * math.sin(t * 1.7),
      glass: 0.7,
    );
  }

  @override
  bool shouldRepaint(covariant _SealedGrainsPainter old) =>
      old.clock != clock || old.color != color;
}
