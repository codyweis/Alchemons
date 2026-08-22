// lib/screens/extract_vial_dialog.dart
//
// The confirmation shown before a vial is spent.
//
// It used to be a stock Material `AlertDialog` — rounded, elevated, with
// "Extract Vial?" and one line of body text — dropped on top of a game that
// looks nothing like it. Worse, it told you nothing you needed: not what the
// vial would produce, not how many you had, and it offered Extract on vials
// that can never produce anything, answering with a failure toast afterwards.
//
// Same shape as the constellation skill dialog: square, dark, states the
// ledger up front, and never offers an action that cannot succeed.

import 'dart:math' as math;

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';

/// Shows the confirmation. Returns true if the player chose to extract.
Future<bool> showExtractVialDialog({
  required BuildContext context,
  required ExtractionVial vial,
  required int owned,
  required Iterable<Creature> catalog,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Extract vial',
    barrierColor: const Color(0xC404060A),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) =>
        ExtractVialDialog(vial: vial, owned: owned, catalog: catalog),
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
  return result ?? false;
}

class ExtractVialDialog extends StatelessWidget {
  const ExtractVialDialog({
    super.key,
    required this.vial,
    required this.owned,
    required this.catalog,
  });

  final ExtractionVial vial;
  final int owned;
  final Iterable<Creature> catalog;

  static const _bg = Color(0xFF0B0E14);
  static const _bgRaised = Color(0xFF141A24);
  static const _hairline = Color(0xFF232C3A);
  static const _text = Color(0xFFE8DCC8);
  static const _textSoft = Color(0xFFAFBDCC);
  static const _textMuted = Color(0xFF7E8CA0);
  static const _warn = Color(0xFFE0885A);

  /// How many distinct species this vial could yield. Zero means it is a dead
  /// item — see [vialCanProduceSpecimen].
  int get _candidateCount {
    final types = vial.group.elementTypes;
    final wanted = creatureRarityForVial(vial.rarity).toLowerCase();
    return catalog
        .where(
          (c) =>
              c.rarity.toLowerCase() == wanted &&
              c.types.any(types.contains),
        )
        .length;
  }

  bool get _usable => _candidateCount > 0 && owned > 0;

  @override
  Widget build(BuildContext context) {
    final skin = vial.group.skin;
    final accent = _candidateCount > 0 ? skin.badge : _warn;
    final candidates = _candidateCount;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _bg,
              border: Border.all(color: accent.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                const BoxShadow(color: Color(0xCC000000), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(accent, skin),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidates > 0
                            ? 'Breaking the seal draws one '
                                  '${creatureRarityForVial(vial.rarity).toLowerCase()} '
                                  'specimen at random from the '
                                  '${vial.group.displayName.toLowerCase()} strains, '
                                  'and places it in the extraction chamber.'
                            : 'No ${creatureRarityForVial(vial.rarity).toLowerCase()} '
                                  '${vial.group.displayName.toLowerCase()} strain has '
                                  'been catalogued, so this vial has nothing to draw. '
                                  'It cannot be extracted.',
                        style: const TextStyle(
                          color: _textSoft,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ledger(accent, candidates),
                      const SizedBox(height: 18),
                      _actions(context, accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Color accent, ElementalGroupSkin skin) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.13),
            accent.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CustomPaint(
                  painter: _VialSigilPainter(accent: accent, fill: skin.fill),
                  child: Center(
                    child: Icon(
                      AppIcons.biotech_rounded,
                      size: 22,
                      color: accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${vial.group.displayName} Vial',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      vial.rarity.badgeLabel.toUpperCase(),
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.85),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 7,
            width: double.infinity,
            child: CustomPaint(painter: _RulePainter(accent: accent)),
          ),
        ],
      ),
    );
  }

  Widget _ledger(Color accent, int candidates) {
    final dead = candidates == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bgRaised,
        border: Border.all(
          color: accent.withValues(alpha: dead ? 0.45 : 0.22),
        ),
      ),
      child: Column(
        children: [
          _row(
            'POSSIBLE SPECIMENS',
            dead ? 'NONE' : '$candidates',
            dead ? _warn : accent,
            bold: true,
          ),
          const SizedBox(height: 7),
          _row('IN STOCK', '$owned', _textSoft),
          if (!dead) ...[
            const SizedBox(height: 9),
            Container(height: 1, color: _hairline),
            const SizedBox(height: 9),
            _row('AFTER EXTRACTION', '${owned - 1}', _text, bold: true),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: bold ? 15 : 13.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, Color accent) {
    if (!_usable) {
      return _Button(
        label: 'CLOSE',
        accent: _textSoft,
        onTap: () => Navigator.of(context).pop(false),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _Button(
            label: 'CANCEL',
            accent: _textSoft,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _Button(
            label: 'EXTRACT',
            accent: accent,
            filled: true,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: filled
                  ? accent.withValues(alpha: 0.85)
                  : ExtractVialDialog._hairline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A flask outline, echoing the vial card's frame colours.
class _VialSigilPainter extends CustomPainter {
  const _VialSigilPainter({required this.accent, required this.fill});
  final Color accent;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRect(r.deflate(6), Paint()..color = fill);
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      r.deflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_VialSigilPainter old) =>
      old.accent != accent || old.fill != fill;
}

class _RulePainter extends CustomPainter {
  const _RulePainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final mid = size.width / 2;
    final line = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.45),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(Offset(0, y), Offset(mid - 9, y), line);
    canvas.drawLine(Offset(mid + 9, y), Offset(size.width, y), line);
    canvas.save();
    canvas.translate(mid, y);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 4.4, height: 4.4),
      Paint()..color = accent.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.accent != accent;
}
