// lib/screens/wilderness_peek_dialog.dart
//
// "Wilderness Peek" — long-press a biome to see what is waiting in it.
//
// The old version was a rounded Material dialog listing creature NAMES as
// ListTile text with a rarity pill, in a fixed 220px box. In a game whose
// entire appeal is the creatures, the one screen that previews them showed
// none of them — you had to recognise "Emberlet" from a string. It also
// predated the square dark dialog language used by the skill and vial
// dialogs, and its rarity colours were a private copy.
//
// This shows the actual sprites, sized to content, in the shared language.

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter/material.dart';

/// One previewed spawn: the resolved species (null if the catalog has no
/// entry) and the rarity it rolled at.
class PeekedSpawn {
  const PeekedSpawn({required this.rarityName, this.creature, this.fallbackId});

  final String rarityName;
  final Creature? creature;

  /// Shown when [creature] could not be resolved.
  final String? fallbackId;

  String get displayName => creature?.name ?? fallbackId ?? 'Unknown';
}

Future<void> showWildernessPeekDialog({
  required BuildContext context,
  required String biomeName,
  required List<PeekedSpawn> spawns,
  VoidCallback? onResetSpawns,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Wilderness peek',
    barrierColor: const Color(0xC404060A),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => WildernessPeekDialog(
      biomeName: biomeName,
      spawns: spawns,
      onResetSpawns: onResetSpawns,
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class WildernessPeekDialog extends StatelessWidget {
  const WildernessPeekDialog({
    super.key,
    required this.biomeName,
    required this.spawns,
    this.onResetSpawns,
  });

  final String biomeName;
  final List<PeekedSpawn> spawns;
  final VoidCallback? onResetSpawns;

  static const _bg = Color(0xFF0B0E14);
  static const _bgRaised = Color(0xFF141A24);
  static const _hairline = Color(0xFF232C3A);
  static const _text = Color(0xFFE8DCC8);
  static const _textSoft = Color(0xFFAFBDCC);
  static const _textMuted = Color(0xFF7E8CA0);
  static const _accent = Color(0xFF8FB8D8);

  static Color rarityColor(String rarity) => switch (rarity.toLowerCase()) {
    'legendary' => const Color(0xFFE4C16A),
    'rare' => const Color(0xFF6FC6E0),
    'uncommon' => const Color(0xFF7BE38B),
    _ => const Color(0xFF8C9AAB),
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _bg,
              border: Border.all(color: _accent.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.10),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                const BoxShadow(color: Color(0xCC000000), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _list(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: _actions(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _accent.withValues(alpha: 0.12),
            _accent.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(AppIcons.remove_red_eye_rounded, color: _accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  biomeName,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  spawns.length == 1
                      ? '1 SPECIMEN DETECTED'
                      : '${spawns.length} SPECIMENS DETECTED',
                  style: TextStyle(
                    color: _accent.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    // Sized to content up to a cap, rather than a fixed 220px box that left
    // dead space for two spawns and cut off eight.
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: spawns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _row(spawns[i]),
    );
  }

  Widget _row(PeekedSpawn spawn) {
    final colour = rarityColor(spawn.rarityName);
    final sprite = spawn.creature?.spriteData;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bgRaised,
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            // The whole point of a preview: show the creature, not its name.
            child: sprite == null
                ? Icon(
                    AppIcons.help_outline_rounded,
                    color: _textMuted,
                    size: 20,
                  )
                : RepaintBoundary(
                    child: CreatureSprite(
                      spritePath: sprite.spriteSheetPath,
                      totalFrames: sprite.totalFrames,
                      rows: sprite.rows,
                      frameSize: Vector2(
                        sprite.frameWidth.toDouble(),
                        sprite.frameHeight.toDouble(),
                      ),
                      stepTime: sprite.frameDurationMs / 1000.0,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spawn.displayName,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  spawn.rarityName.toUpperCase(),
                  style: TextStyle(
                    color: colour,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // A quiet rarity rail rather than a pill competing with the name.
          Container(width: 3, height: 34, color: colour),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final reset = onResetSpawns;
    return Row(
      children: [
        Expanded(
          // Equal halves rather than 2:1 — "RESET SPAWNS" does not fit the
          // narrow slot on a small phone.
          child: _Btn(
            label: 'CLOSE',
            accent: _textSoft,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        if (reset != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _Btn(
              label: 'RESET SPAWNS',
              accent: const Color(0xFFE0885A),
              onTap: () {
                Navigator.of(context).pop();
                reset();
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.accent, required this.onTap});

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: accent == const Color(0xFFE0885A)
                  ? accent.withValues(alpha: 0.5)
                  : WildernessPeekDialog._hairline,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
