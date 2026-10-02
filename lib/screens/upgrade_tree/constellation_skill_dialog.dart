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
//
// It wears the chart's materials: the skill's own stone (StoneArt), its tree's
// light as the accent, and the bracket frames the lab and the market use.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/constellations/constellation_art.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
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
    required this.pointsAvailable,
    this.prerequisiteStates = const {},
    this.onUnlock,
  });

  final ConstellationSkill skill;
  final SkillDialogMode mode;

  /// The player's current skill-point balance, so the cost can be read as a
  /// ledger rather than a number in isolation.
  final int pointsAvailable;

  /// Prerequisite id → whether it is already unlocked.
  final Map<String, bool> prerequisiteStates;

  final Future<void> Function()? onUnlock;

  bool get _affordable => pointsAvailable >= skill.pointsCost;
  bool get _canBuy => mode == SkillDialogMode.available && _affordable;

  static const _bg = Color(0xFF0E1117);
  static const _bgRaised = Color(0xFF080A0E);
  static const _hairline = Color(0xFF252D3A);
  static const _text = kChartInk;
  static const _textSoft = Color(0xFFCFC4B1);
  static const _textMuted = kChartMuted;

  Color get _accent => switch (mode) {
    SkillDialogMode.locked => _textMuted,
    _ => treeLight(skill.tree).essence,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: accent.withValues(alpha: 0.9),
                bracketSize: 14,
                strokeWidth: 1.3,
              ),
              child: ColoredBox(
                color: _bg,
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
        borderRadius: BorderRadius.zero,
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
                width: 60,
                height: 60,
                child: CustomPaint(
                  painter: _StonePainter(
                    tree: skill.tree,
                    sigil: sigilFor(skill),
                    state: switch (mode) {
                      SkillDialogMode.owned => StoneState.owned,
                      SkillDialogMode.available => StoneState.open,
                      SkillDialogMode.locked => StoneState.locked,
                    },
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
                              _Mark(color: accent.withValues(alpha: 0.9)),
                              const SizedBox(width: 2),
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

    canvas.drawPath(
      costStarPath(Offset(mid, y), 5.5),
      Paint()..color = accent.withValues(alpha: 0.85),
    );
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

/// The skill's own stone, as the chart draws it, with its glyph.
class _StonePainter extends CustomPainter {
  const _StonePainter({
    required this.tree,
    required this.sigil,
    required this.state,
  });

  final ConstellationTree tree;
  final ChartSigil sigil;
  final StoneState state;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.4;
    final art = StoneArt.of(tree, state, r, c);
    art.paint(canvas, halo: state == StoneState.open ? art.breath(6) : null);
    canvas.drawPath(
      sigilPathAt(sigil, c, r * 0.33),
      Paint()..color = art.sigilColor,
    );
  }

  @override
  bool shouldRepaint(_StonePainter old) =>
      old.tree != tree || old.sigil != sigil || old.state != state;
}

/// A small diamond: a done prerequisite, a mark beside a word.
class _Mark extends StatelessWidget {
  const _Mark({required this.color});
  final Color color;
  static const double size = 7;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size + 4,
    height: size + 4,
    child: Center(
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(width: size, height: size, color: color),
      ),
    ),
  );
}

/// The four-pointed star a price is counted in.
class _CostStar extends StatelessWidget {
  const _CostStar({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 12,
    height: 12,
    child: CustomPaint(painter: _CostStarPainter(color)),
  );
}

class _CostStarPainter extends CustomPainter {
  const _CostStarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    costStarPath(size.center(Offset.zero), size.width / 2),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_CostStarPainter old) => old.color != color;
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
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: tone.withValues(alpha: warn ? 0.7 : 0.45),
        bracketSize: 8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: ConstellationSkillDialog._bgRaised,
        child: Column(
          children: [
            _row('COST', '$cost', tone, bold: true),
            const SizedBox(height: 7),
            _row('BALANCE', '$available', ConstellationSkillDialog._textSoft),
            const SizedBox(height: 9),
            Container(height: 1, color: ConstellationSkillDialog._hairline),
            const SizedBox(height: 9),
            _row(
              warn ? 'SHORT BY' : 'REMAINING',
              warn ? '${-remainder}' : '$remainder',
              warn ? _warnColor : ConstellationSkillDialog._text,
              bold: true,
            ),
          ],
        ),
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
        _CostStar(color: color),
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
        const _CostStar(color: ConstellationSkillDialog._textSoft),
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
                _Mark(
                  color: done
                      ? treeLight(skill.tree).essence
                      : ConstellationSkillDialog._textMuted.withValues(
                          alpha: 0.45,
                        ),
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
                      decorationColor: ConstellationSkillDialog._textMuted,
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
        onTap: context.soundAction(() => Navigator.of(context).pop()),
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
            onTap: context.soundAction(() => Navigator.of(context).pop()),
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
                    if (!context.mounted) return;
                    context.sound(SoundCue.upgradeComplete, owner: this);
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
        onTap: context.soundAction(live ? onTap : null),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: filled
                ? accent.withValues(alpha: live ? 0.95 : 0.3)
                : ConstellationSkillDialog._hairline.withValues(alpha: 1),
            bracketSize: 9,
            strokeWidth: filled ? 1.3 : 1,
          ),
          child: Container(
            width: double.infinity,
            // 44pt tall: the old buttons were 11pt padding around a 12pt label,
            // which lands under the minimum comfortable touch target.
            height: 44,
            alignment: Alignment.center,
            color: filled
                ? accent.withValues(alpha: live ? 0.18 : 0.06)
                : Colors.white.withValues(alpha: 0.03),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                color: live
                    ? (filled ? ConstellationSkillDialog._text : accent)
                    : accent.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
