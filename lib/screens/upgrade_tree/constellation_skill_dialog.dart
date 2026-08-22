// lib/screens/upgrade_tree/constellation_skill_dialog.dart
//
// The skill dialog for the constellation tree.
//
// This replaces three near-identical Material `Dialog`s that lived inline in
// constellation_screen.dart. They were generic dark rounded rectangles with a
// hairline border — nothing about them said "star chart", and more importantly
// they withheld the one number the decision actually turns on: whether you can
// afford this, and what you'd have left. Spending was confirmed by a red
// SnackBar AFTER you pressed UNLOCK.
//
// The dialog now:
//   * opens on the node you touched — same hexagon, same glyph, same state
//   * states the ledger up front (cost, balance, remainder)
//   * refuses to offer a purchase you cannot make, instead of failing later
//   * shows prerequisites as a checklist, not a bare list of names
//
// It takes plain data and callbacks so it can be rendered in a test.

import 'dart:math' as math;

import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';

/// Which of the three states the tapped node is in.
enum SkillDialogMode {
  /// Owned already — this is a reference card.
  owned,

  /// Prerequisites met. Affordability is a separate question.
  available,

  /// Prerequisites not met. Nothing to buy yet.
  locked,
}

class ConstellationSkillDialog extends StatelessWidget {
  const ConstellationSkillDialog({
    super.key,
    required this.skill,
    required this.mode,
    required this.primary,
    required this.secondary,
    required this.pointsAvailable,
    this.prerequisiteStates = const {},
    this.onUnlock,
  });

  final ConstellationSkill skill;
  final SkillDialogMode mode;
  final Color primary;
  final Color secondary;

  /// The player's current skill-point balance, so the cost can be read as a
  /// ledger rather than a number in isolation.
  final int pointsAvailable;

  /// Prerequisite id → whether it is already unlocked.
  final Map<String, bool> prerequisiteStates;

  final Future<void> Function()? onUnlock;

  bool get _affordable => pointsAvailable >= skill.pointsCost;
  bool get _canBuy => mode == SkillDialogMode.available && _affordable;

  static const _bg = Color(0xFF0B0E14);
  static const _bgRaised = Color(0xFF141A24);
  static const _hairline = Color(0xFF232C3A);
  static const _text = Color(0xFFE8DCC8);
  static const _textSoft = Color(0xFFAFBDCC);
  static const _textMuted = Color(0xFF7E8CA0);

  Color get _accent => switch (mode) {
    SkillDialogMode.owned => primary,
    SkillDialogMode.available => Color.lerp(primary, secondary, 0.35)!,
    SkillDialogMode.locked => _textMuted,
  };

  static const _tierNames = [
    '',
    'First Light',
    'Second Light',
    'Third Light',
    'Fourth Light',
    'Fifth Light',
  ];

  String get _tierLabel => skill.tier < _tierNames.length
      ? _tierNames[skill.tier]
      : 'Tier ${skill.tier}';

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
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
                _Header(
                  skill: skill,
                  mode: mode,
                  accent: accent,
                  tierLabel: _tierLabel,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.description,
                        style: const TextStyle(
                          color: _textSoft,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                      if (mode == SkillDialogMode.locked &&
                          skill.prerequisites.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _PrerequisiteList(
                          skill: skill,
                          states: prerequisiteStates,
                        ),
                      ],
                      // A locked skill shows its price for planning, but not
                      // a balance and remainder — that framing implies you
                      // could buy it, and prerequisites are the real blocker.
                      if (mode == SkillDialogMode.locked) ...[
                        const SizedBox(height: 16),
                        _CostLine(cost: skill.pointsCost),
                      ] else if (mode == SkillDialogMode.available) ...[
                        const SizedBox(height: 18),
                        _CostLedger(
                          cost: skill.pointsCost,
                          available: pointsAvailable,
                          accent: accent,
                          warn: !_affordable,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _Actions(
                        mode: mode,
                        canBuy: _canBuy,
                        accent: accent,
                        cost: skill.pointsCost,
                        shortfall: skill.pointsCost - pointsAvailable,
                        onUnlock: onUnlock,
                      ),
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
}

/// The hexagon sigil plus title. The hexagon deliberately mirrors the node on
/// the star chart — same shape, same glyph, same unlocked/available styling —
/// so the dialog reads as an expansion of the thing you touched.
class _Header extends StatelessWidget {
  const _Header({
    required this.skill,
    required this.mode,
    required this.accent,
    required this.tierLabel,
  });

  final ConstellationSkill skill;
  final SkillDialogMode mode;
  final Color accent;
  final String tierLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CustomPaint(
                  painter: _NodeSigilPainter(
                    accent: accent,
                    filled: mode == SkillDialogMode.owned,
                    dim: mode == SkillDialogMode.locked,
                  ),
                  child: Center(
                    child: Icon(
                      skill.identityIcon,
                      size: 22,
                      color: mode == SkillDialogMode.locked
                          ? ConstellationSkillDialog._textMuted
                          : accent,
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
                      skill.name,
                      style: const TextStyle(
                        color: ConstellationSkillDialog._text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Wrap, not Row: a long tier name beside the ATTUNED
                    // marker overflows a narrow phone otherwise.
                    Wrap(
                      spacing: 7,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tierLabel.toUpperCase(),
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.85),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        if (mode == SkillDialogMode.owned)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '·',
                                style: TextStyle(
                                  color: accent.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Icon(
                                AppIcons.check_circle,
                                size: 12,
                                color: accent.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'ATTUNED',
                                style: TextStyle(
                                  color: accent.withValues(alpha: 0.9),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StarRule(accent: accent),
        ],
      ),
    );
  }
}

/// A divider drawn as a short constellation: a line with a node on it.
class _StarRule extends StatelessWidget {
  const _StarRule({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7,
      width: double.infinity,
      child: CustomPaint(painter: _StarRulePainter(accent: accent)),
    );
  }
}

class _StarRulePainter extends CustomPainter {
  const _StarRulePainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final mid = size.width / 2;
    final line = Paint()
      ..strokeWidth = 1
      ..shader = _ruleGradient(size, accent);
    canvas.drawLine(Offset(0, y), Offset(mid - 9, y), line);
    canvas.drawLine(Offset(mid + 9, y), Offset(size.width, y), line);

    final dot = Paint()..color = accent.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(mid, y), 2.4, dot);
    final halo = Paint()..color = accent.withValues(alpha: 0.22);
    canvas.drawCircle(Offset(mid, y), 5.0, halo);
  }

  @override
  bool shouldRepaint(_StarRulePainter old) => old.accent != accent;
}

Shader _ruleGradient(Size size, Color accent) {
  return LinearGradient(
    colors: [
      accent.withValues(alpha: 0.0),
      accent.withValues(alpha: 0.45),
      accent.withValues(alpha: 0.0),
    ],
  ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
}

/// The same hexagon the star chart draws for a node.
class _NodeSigilPainter extends CustomPainter {
  const _NodeSigilPainter({
    required this.accent,
    required this.filled,
    required this.dim,
  });

  final Color accent;
  final bool filled;
  final bool dim;

  Path _hex(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = (math.pi / 3) * i - math.pi / 6;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outer = _hex(c, size.width / 2 - 1);
    final inner = _hex(c, size.width / 2 - 8);

    if (filled) {
      canvas.drawCircle(
        c,
        size.width / 2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: 0.28),
              accent.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: size.width / 2)),
      );
    }

    canvas.drawPath(
      inner,
      Paint()
        ..color = filled
            ? accent.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: dim ? 0.30 : 0.85),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: dim ? 0.16 : 0.40),
    );
  }

  @override
  bool shouldRepaint(_NodeSigilPainter old) =>
      old.accent != accent || old.filled != filled || old.dim != dim;
}

/// Cost, balance and remainder on one line each. The remainder is the number
/// players actually want and the old dialog never showed.
class _CostLedger extends StatelessWidget {
  const _CostLedger({
    required this.cost,
    required this.available,
    required this.accent,
    required this.warn,
  });

  final int cost;
  final int available;
  final Color accent;
  final bool warn;

  static const _warnColor = Color(0xFFE0885A);

  @override
  Widget build(BuildContext context) {
    final remainder = available - cost;
    final tone = warn ? _warnColor : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ConstellationSkillDialog._bgRaised,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tone.withValues(alpha: warn ? 0.45 : 0.22)),
      ),
      child: Column(
        children: [
          _row('COST', '$cost', tone, bold: true),
          const SizedBox(height: 7),
          _row('BALANCE', '$available', ConstellationSkillDialog._textSoft),
          const SizedBox(height: 9),
          Container(
            height: 1,
            color: ConstellationSkillDialog._hairline,
          ),
          const SizedBox(height: 9),
          _row(
            warn ? 'SHORT BY' : 'REMAINING',
            warn ? '${-remainder}' : '$remainder',
            warn ? _warnColor : ConstellationSkillDialog._text,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ConstellationSkillDialog._textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        Icon(AppIcons.auto_awesome_rounded, size: 12, color: color),
        const SizedBox(width: 5),
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
}


/// The bare price, for a skill that cannot be bought yet.
class _CostLine extends StatelessWidget {
  const _CostLine({required this.cost});
  final int cost;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'COST',
          style: TextStyle(
            color: ConstellationSkillDialog._textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(width: 10),
        const Icon(
          AppIcons.auto_awesome_rounded,
          size: 12,
          color: ConstellationSkillDialog._textSoft,
        ),
        const SizedBox(width: 5),
        Text(
          '$cost',
          style: const TextStyle(
            color: ConstellationSkillDialog._textSoft,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Prerequisites as a checklist. The old dialog listed names with a chevron,
/// which told you what was required but not what you were missing.
class _PrerequisiteList extends StatelessWidget {
  const _PrerequisiteList({required this.skill, required this.states});

  final ConstellationSkill skill;
  final Map<String, bool> states;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REQUIRES',
          style: TextStyle(
            color: ConstellationSkillDialog._textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 9),
        ...skill.prerequisites.map((id) {
          final done = states[id] ?? false;
          final name = ConstellationCatalog.byId(id)?.name ?? id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Icon(
                  done ? AppIcons.check_circle : AppIcons.lock_outline,
                  size: 14,
                  color: done
                      ? const Color(0xFF6FD08C)
                      : ConstellationSkillDialog._textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: done
                          ? ConstellationSkillDialog._textSoft
                          : ConstellationSkillDialog._textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor:
                          ConstellationSkillDialog._textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _Actions extends StatefulWidget {
  const _Actions({
    required this.mode,
    required this.canBuy,
    required this.accent,
    required this.cost,
    required this.shortfall,
    required this.onUnlock,
  });

  final SkillDialogMode mode;
  final bool canBuy;
  final Color accent;
  final int cost;
  final int shortfall;
  final Future<void> Function()? onUnlock;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (widget.mode != SkillDialogMode.available) {
      return _DialogButton(
        label: 'CLOSE',
        accent: ConstellationSkillDialog._textSoft,
        filled: false,
        onTap: () => Navigator.of(context).pop(),
      );
    }

    // Unaffordable: say so on the button itself rather than letting the player
    // press it and answering with a red SnackBar.
    if (!widget.canBuy) {
      return Column(
        children: [
          _DialogButton(
            label: 'NEED ${widget.shortfall} MORE',
            accent: ConstellationSkillDialog._textMuted,
            filled: false,
            enabled: false,
            onTap: () {},
          ),
          const SizedBox(height: 9),
          _DialogButton(
            label: 'CLOSE',
            accent: ConstellationSkillDialog._textSoft,
            filled: false,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _DialogButton(
            label: 'CANCEL',
            accent: ConstellationSkillDialog._textSoft,
            filled: false,
            onTap: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _DialogButton(
            label: _busy ? 'ATTUNING…' : 'ATTUNE  ·  ${widget.cost}',
            accent: widget.accent,
            filled: true,
            onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await widget.onUnlock?.call();
                    if (mounted) setState(() => _busy = false);
                  },
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.accent,
    required this.onTap,
    this.filled = true,
    this.enabled = true,
  });

  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onTap != null;
    return Semantics(
      button: true,
      enabled: live,
      label: label,
      child: GestureDetector(
        onTap: live ? onTap : null,
        child: Container(
          width: double.infinity,
          // 44pt tall: the old buttons were 11pt padding around a 12pt label,
          // which lands under the minimum comfortable touch target.
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? accent.withValues(alpha: live ? 0.18 : 0.06)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: filled
                  ? accent.withValues(alpha: live ? 0.85 : 0.25)
                  : ConstellationSkillDialog._hairline,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: live
                  ? accent
                  : accent.withValues(alpha: 0.55),
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
