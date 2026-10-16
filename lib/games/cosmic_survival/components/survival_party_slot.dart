// lib/games/cosmic_survival/components/survival_party_slot.dart
//
// The party along the bottom edge of the run: a row of specimen cases, the
// whole party in slot order (a party is five at most, so nobody is ever
// hidden), and FOLLOW / FREE at its end. Nothing stands on it: the joystick
// floats (see FloatingJoystick). The field stays clear; the top bar
// and the surge tube carry the run. Only a debug squad of more than five
// folds its bench into one "+N" case.
//
// Each case is its own repaint boundary. The row rebuilds on the HUD's tick
// as the rest of the HUD does, and a case's tubes repaint only when its
// health moves or its special's charge crosses one of 24 steps.

import 'dart:math';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter, elementLight;
import 'package:flutter/material.dart';
import '../cosmic_survival_game.dart';
import '../../cosmic/cosmic_data.dart';
import 'survival_hud.dart';

/// Live combat state takes precedence over the values cached on recall.
class SurvivalPartySlotState {
  const SurvivalPartySlotState({
    required this.active,
    required this.following,
    required this.dead,
    required this.hp,
    required this.cooldown,
    this.charge = 0,
  });

  factory SurvivalPartySlotState.fromGame(CosmicSurvivalGame game, int slot) {
    final companion = game.activeCompanions[slot];
    final hp = (companion?.hpPercent ?? game.companionHpFraction[slot] ?? 1.0)
        .clamp(0.0, 1.0);
    final dead =
        game.defeatedCompanionSlots.contains(slot) ||
        (companion?.isDead ?? false) ||
        hp <= 0;
    final active = companion != null && !dead;
    final cooldown =
        companion?.specialCooldown ?? game.companionSpecialCooldown[slot] ?? 0;
    // How far the special has come back, for its tube. A reserve has no
    // interval to measure against, so its cached wait reads against ten
    // seconds.
    var charge = 0.0;
    if (!dead && cooldown.isFinite && cooldown > 0.05) {
      final total = companion?.effectiveSpecialCooldown ?? 10.0;
      charge = (1 - cooldown / max(0.5, total)).clamp(0.0, 0.97);
    }
    return SurvivalPartySlotState(
      active: active,
      following: active && game.tetheredCompanionSlot == slot,
      dead: dead,
      hp: dead ? 0 : hp,
      cooldown: cooldown,
      charge: (charge * 24).floor() / 24,
    );
  }

  final bool active;
  final bool following;
  final bool dead;
  final double hp;
  final double cooldown;

  /// While the special recharges, how far back it is, 0..1 in 24 steps.
  final double charge;

  /// A Mystic whose world is out carries an INFINITE cooldown: the cast is
  /// spent for the deployment and only a recall gives it back.
  bool get worldOut => !dead && !cooldown.isFinite;
  bool get ready => !dead && cooldown.isFinite && cooldown <= 0.05;

  /// The special's tube: full when ready, empty while a world is out.
  double get specialFill => ready ? 1 : (worldOut ? 0 : charge);

  String get label => dead
      ? 'DOWN'
      : following
      ? 'FOLLOW'
      : active
      ? 'ACTIVE'
      : 'RESERVE';

  String get specialLabel => dead
      ? ''
      : worldOut
      ? 'world out'
      : ready
      ? 'special ready'
      : 'special in ${cooldown.ceil()} s';
}

/// A party member as a small specimen case: out in the arena, it stands in
/// its element's light; in reserve, it waits grey. Under it, two glass tubes:
/// its health, and its special (pale brass, brighter and fuller when ready).
/// The one the ship tows is lit from below in the follow color.
class SurvivalPartySlot extends StatelessWidget {
  const SurvivalPartySlot({
    super.key,
    required this.member,
    required this.state,
    required this.onTap,
    this.feedCount,
    this.width = defaultWidth,
  });

  final CosmicPartyMember member;
  final SurvivalPartySlotState state;
  final VoidCallback onTap;

  /// A Plant Mask's feeds this deployment, shown in the case's corner.
  final int? feedCount;

  /// The case's width; its height and art follow from it.
  final double width;

  static const defaultWidth = 52.0;
  static double heightFor(double width) => (width * 1.34).roundToDouble();
  double get height => heightFor(width);
  double get _art => width - 12;

  /// Reserve: the creature in grey, dimmed — present, not out.
  static const _reserve = ColorFilter.matrix([
    0.16, 0.32, 0.06, 0, 0, //
    0.16, 0.32, 0.06, 0, 0, //
    0.17, 0.34, 0.07, 0, 0, //
    0, 0, 0, 0.8, 0,
  ]);

  static Color _hpColor(double hp) => hp > 0.5
      ? SurvivalInk.follow
      : hp > 0.25
      ? SurvivalInk.brass
      : SurvivalInk.danger;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final name = member.displayName.isEmpty ? 'Alchemon' : member.displayName;
    final action = s.dead
        ? 'Defeated'
        : s.active
        ? 'Tap to recall'
        : 'Tap to deploy';
    final portrait = member.imagePath == null
        ? Text(
            name.characters.first,
            style: hudMono(18, SurvivalInk.muted, weight: FontWeight.w900),
          )
        : Image.asset(
            member.imagePath!,
            width: _art,
            height: _art,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => SizedBox.square(dimension: _art),
          );
    final vines = feedCount == null || !s.active
        ? null
        : (1 + (feedCount! ~/ 10)).clamp(1, 10);
    final special = s.specialLabel;
    return Semantics(
      label: [
        name,
        s.label,
        '${(s.hp * 100).round()} percent health',
        if (special.isNotEmpty) special,
        if (vines != null) '$feedCount fed, $vines vines',
      ].join(', '),
      hint: action,
      button: true,
      enabled: !s.dead,
      child: Tooltip(
        message: '$name · ${s.label}\n$action',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: s.dead ? null : context.soundAction(onTap),
          child: RepaintBoundary(
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: s.following ? SurvivalInk.follow : SurvivalInk.plain,
                strokeWidth: 1.5,
              ),
              child: Container(
                width: width,
                height: height,
                color: SurvivalInk.bg0.withValues(alpha: 0.86),
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 6),
                child: Column(
                  children: [
                    SizedBox(
                      height: _art + 4,
                      child: CustomPaint(
                        painter: s.active
                            ? CaseLightPainter(
                                color: elementLight(member.element),
                              )
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: s.dead ? 0.3 : 1,
                              child: s.active
                                  ? portrait
                                  : ColorFiltered(
                                      colorFilter: _reserve,
                                      child: portrait,
                                    ),
                            ),
                            if (s.dead)
                              Icon(
                                Icons.close_rounded,
                                color: SurvivalInk.danger,
                                size: _art * 0.6,
                              ),
                            if (vines != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Text(
                                  '$feedCount',
                                  style: hudMono(
                                    8,
                                    SurvivalInk.follow,
                                    spacing: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    _tube(s.hp, _hpColor(s.hp), 4),
                    const SizedBox(height: 3),
                    _tube(
                      s.specialFill,
                      s.ready ? SurvivalInk.brassGlow : SurvivalInk.brass,
                      s.ready ? 5 : 4,
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

  static Widget _tube(double fraction, Color color, double height) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: HudTubePainter(fraction, color)),
  );
}

/// One party member as the row lays it out.
class SurvivalPartyEntry {
  const SurvivalPartyEntry({
    required this.slot,
    required this.member,
    required this.state,
    this.feedCount,
  });

  final int slot;
  final CosmicPartyMember member;
  final SurvivalPartySlotState state;
  final int? feedCount;
}

/// The party along the bottom edge: every member in slot order, out ones
/// lit, the bench grey, the fallen crossed, then FOLLOW / FREE. Over
/// [shownMax] (a debug squad), the ones out stay in the row, a dim empty case
/// marks each open place, and the bench folds into one "+N" case that opens
/// it in a tray above the row.
class SurvivalPartyRow extends StatefulWidget {
  const SurvivalPartyRow({
    super.key,
    required this.entries,
    required this.maxActive,
    required this.tethered,
    required this.onTapSlot,
    required this.onFollow,
    required this.wrap,
    this.caseWidth = SurvivalPartySlot.defaultWidth,
    this.padSlot,
  });

  final List<SurvivalPartyEntry> entries;
  final int maxActive;
  final bool tethered;
  final void Function(int slot) onTapSlot;
  final VoidCallback onFollow;

  /// Lets the screen mark the controller's chosen slot.
  final Widget Function(int slot, Widget child) wrap;

  /// Each case's width.
  final double caseWidth;

  /// The slot a controller is on, if one is steering: a reserve chosen that
  /// way opens the tray so it can be seen.
  final int? padSlot;

  /// The most a party can bring; up to this many, every case is shown.
  static const shownMax = 5;
  static const gap = 4.0;
  static const foldWidth = 30.0;
  static const followWidth = 42.0;

  /// How many case-widths the row needs for a party of [members].
  static int casesFor(int members) =>
      members <= shownMax ? members : shownMax + 1;

  /// The row's width for [members] cases of [caseWidth], FOLLOW included.
  static double widthFor(int members, double caseWidth) =>
      casesFor(members) * (caseWidth + gap) + followWidth;

  /// The row's height with cases of [caseWidth].
  static double heightFor(double caseWidth) =>
      SurvivalPartySlot.heightFor(caseWidth);

  @override
  State<SurvivalPartyRow> createState() => _SurvivalPartyRowState();
}

class _SurvivalPartyRowState extends State<SurvivalPartyRow> {
  bool _tray = false;

  Widget _case(SurvivalPartyEntry e, VoidCallback onTap) => widget.wrap(
    e.slot,
    SurvivalPartySlot(
      member: e.member,
      state: e.state,
      feedCount: e.feedCount,
      onTap: onTap,
      width: widget.caseWidth,
    ),
  );

  /// The bench opens up to this many cases across.
  static const _trayAcross = 6;

  Widget get _follow => _FollowKey(
    tethered: widget.tethered,
    onTap: widget.onFollow,
    height: SurvivalPartySlot.heightFor(widget.caseWidth),
  );

  @override
  Widget build(BuildContext context) =>
      widget.entries.length <= SurvivalPartyRow.shownMax
      ? _buildAll()
      : LayoutBuilder(
          builder: (context, box) => _buildFolded(context, box.maxWidth),
        );

  /// The whole party, each in its own place.
  Widget _buildAll() => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final e in widget.entries) ...[
        _case(e, () => widget.onTapSlot(e.slot)),
        const SizedBox(width: SurvivalPartyRow.gap),
      ],
      _follow,
    ],
  );

  Widget _buildFolded(BuildContext context, double room) {
    final caseH = SurvivalPartySlot.heightFor(widget.caseWidth);
    final out = widget.entries
        .where((e) => e.state.active || e.state.dead)
        .toList();
    final reserve = widget.entries
        .where((e) => !e.state.active && !e.state.dead)
        .toList();
    final open = max(
      0,
      widget.maxActive - out.where((e) => !e.state.dead).length,
    );
    final empty = min(open, reserve.length);
    final padOnReserve = reserve.any((e) => e.slot == widget.padSlot);
    // With nobody out (a run's start), the bench is what there is to do:
    // it stands open until someone is deployed.
    final nobodyOut = out.every((e) => e.state.dead);
    final trayShown =
        (_tray || padOnReserve || nobodyOut) && reserve.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomRight,
          child: trayShown
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  // Six across at most (fewer on a narrow screen), filling
                  // from the right: a long bench stacks up in a few rows.
                  child: SizedBox(
                    width: min(
                      room,
                      _trayAcross *
                              (widget.caseWidth + SurvivalPartyRow.gap) -
                          SurvivalPartyRow.gap,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: SurvivalPartyRow.gap,
                      runSpacing: SurvivalPartyRow.gap,
                      children: [
                        for (final e in reserve)
                          _case(e, () {
                            widget.onTapSlot(e.slot);
                            setState(() => _tray = false);
                          }),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: 0, height: 0),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in out) ...[
              _case(e, () => widget.onTapSlot(e.slot)),
              const SizedBox(width: SurvivalPartyRow.gap),
            ],
            // An open place: tapping it opens the bench to fill it.
            for (var i = 0; i < empty; i++) ...[
              Semantics(
                button: true,
                label: 'Open place',
                hint: 'Show the reserves',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: context.soundAction(
                    () => setState(() => _tray = true),
                  ),
                  child: Container(
                    width: widget.caseWidth,
                    height: caseH,
                    color: SurvivalInk.bg0.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: SurvivalPartyRow.gap),
            ],
            if (reserve.isNotEmpty) ...[
              _ReserveFold(
                count: reserve.length,
                open: trayShown,
                height: caseH,
                onTap: () => setState(() => _tray = !_tray),
              ),
              const SizedBox(width: SurvivalPartyRow.gap),
            ],
            _follow,
          ],
        ),
      ],
    );
  }
}

/// The reserves, folded to their count.
class _ReserveFold extends StatelessWidget {
  const _ReserveFold({
    required this.count,
    required this.open,
    required this.height,
    required this.onTap,
  });

  final int count;
  final bool open;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count in reserve',
    hint: open ? 'Close the reserves' : 'Show the reserves',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: open ? SurvivalInk.brass : SurvivalInk.plain,
          strokeWidth: 1.4,
        ),
        child: Container(
          width: SurvivalPartyRow.foldWidth,
          height: height,
          color: SurvivalInk.bg0.withValues(alpha: 0.86),
          alignment: Alignment.center,
          child: Text(
            '+$count',
            style: hudMono(
              12,
              open ? SurvivalInk.brassBright : SurvivalInk.muted,
              weight: FontWeight.w900,
              spacing: 0.2,
            ),
          ),
        ),
      ),
    ),
  );
}

/// FOLLOW (the nearest Alchemon tows behind the ship) or FREE. The word is
/// the control; lit from below while one follows.
class _FollowKey extends StatelessWidget {
  const _FollowKey({
    required this.tethered,
    required this.onTap,
    required this.height,
  });

  final bool tethered;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: tethered,
    label: tethered ? 'Follow on' : 'Follow off',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: tethered ? SurvivalInk.follow : SurvivalInk.plain,
          strokeWidth: 1.4,
        ),
        child: Container(
          width: SurvivalPartyRow.followWidth,
          height: height,
          color: SurvivalInk.bg0.withValues(alpha: 0.86),
          alignment: Alignment.center,
          child: Text(
            tethered ? 'FOLLOW' : 'FREE',
            style: hudMono(
              8,
              tethered ? SurvivalInk.follow : SurvivalInk.muted,
              spacing: 0.6,
            ),
          ),
        ),
      ),
    ),
  );
}
