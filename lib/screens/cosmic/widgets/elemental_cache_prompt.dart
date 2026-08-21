// lib/screens/cosmic/widgets/elemental_cache_prompt.dart
//
// The prompt that appears when the ship parks at a sealed elemental cache.
//
// It polls the game a few times a second because the thing it reports on — is
// a companion of the right element standing close enough — changes without the
// cosmic screen rebuilding.

import 'dart:async';

import 'package:alchemons/games/cosmic/cosmic_cache_data.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:flutter/material.dart';

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
    final accent = elementColor(widget.cache.element);
    final font = appFontFamily(context);
    final tint = _ready ? accent : Colors.white54;

    // Nothing at all until a companion of the right element is standing close
    // enough. The sealed state used to sit on screen announcing itself; now the
    // cache stays quiet and the prompt IS the signal that you can open it.
    if (!_ready) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tint.withValues(alpha: _ready ? 1.0 : 0.4),
            width: _ready ? 2 : 1.2,
          ),
          boxShadow: _ready
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.5),
                    blurRadius: 26,
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 46,
                    spreadRadius: 4,
                  ),
                ]
              : const [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BREAK THE SEAL',
              style: TextStyle(
                fontFamily: font,
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 5),
            // The seal is named by what it asked for, never by its element —
            // "a living spark", not "LIGHTNING CACHE".
            Text(
              'Your companion answers ${cacheHintFor(widget.cache.element)}',
              style: TextStyle(
                fontFamily: font,
                color: tint.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
