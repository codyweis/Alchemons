// lib/screens/cosmic/widgets/works_panels.dart
//
// The Works' screens, in the station kit's language:
//
//   WorksPanel    from the home base window: the Scavenger Bay, the Silver
//                 Press and every extractor, each on its own little stage
//                 turning as it does in space, with who works it and what
//                 they make.
//   OutpostPanel  at a planet: its extractor (or what building one takes),
//                 the hopper, the miners and the courier, SEND HOME.
//
// Both are dumb about the game: they read a [WorksView] off a listenable
// the screen refreshes as the works tick, and hand every action back
// through [WorksActions].

import 'dart:math';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/works.dart';
import 'package:alchemons/games/cosmic/works_art.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'cosmic_overlay_chrome.dart';
import 'cosmic_panel_kit.dart';
import 'cosmic_screen_styles.dart';
import 'station_panel_kit.dart' show StationDock;

/// A slot a worker fills: its job, the extractor it is at (null at home),
/// and which of that job's slots.
@immutable
class WorkSlotRef {
  const WorkSlotRef(this.job, {this.element, this.index = 0});
  final WorkJob job;
  final String? element;
  final int index;
}

/// What the Works' screens show.
class WorksView {
  const WorksView({
    required this.works,
    required this.profiles,
    required this.members,
    required this.storage,
    required this.hold,
    required this.silver,
    required this.planetsFound,
    required this.distanceHome,
    required this.nowMs,
    this.nearRig,
    this.atPlanet,
  });

  final WorksState works;
  final Map<String, WorkerProfile> profiles;
  final Map<String, CosmicPartyMember> members;

  /// Home storage, and what the ship's hold carries.
  final Map<String, double> storage;
  final Map<String, double> hold;
  final int silver;

  /// The planets the ship has found, by element, in world order.
  final List<String> planetsFound;
  final double Function(String element) distanceHome;
  final int nowMs;

  /// The extractor the ship is beside, if any (SEND HOME works there).
  final String? nearRig;

  /// The element of the found planet the ship is at, if any (an extractor
  /// is built there).
  final String? atPlanet;
}

/// What the screens can ask for.
abstract class WorksActions {
  Future<void> build(WorksBuilding b, {String? element});
  Future<void> upgrade(WorksBuilding b, {String? element});
  Future<void> assign(WorkSlotRef slot);
  Future<void> clear(WorkSlotRef slot);
  void collectCrates();
  void sendHome(String element);
  void setReserve(int reserve);
  Future<void> openOutpost(String element);
  Future<void> help();
}

const Color _amber = CosmicScreenStyles.amberBright;

String fmtDuration(int ms) {
  final s = (ms / 1000).round();
  if (s >= 3600) return '${s ~/ 3600}H ${(s % 3600) ~/ 60}M';
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// What [p] would do at [job], in a few words: the figure the picker sorts
/// by and every slot shows.
String jobFigure(
  WorkJob job,
  WorkerProfile p, {
  double distance = 0,
  int pressTier = 1,
}) => switch (job) {
  WorkJob.miner => '${p.harvestRate}/MIN',
  WorkJob.courier =>
    '${WorkRules.courierLoad(p.strength)} A RUN · '
        '${fmtDuration(WorkRules.courierCycleMs(distance, p.speed))}',
  WorkJob.scavenger =>
    '${WorkRules.scavengerFind(p.strength)} A TRIP · '
        '${fmtDuration(WorkRules.scavengerTripMs(p.speed))}',
  WorkJob.presser =>
    '${WorkRules.pressRate(p.strength, pressTier).toStringAsFixed(0)}/MIN',
};

/// Units a minute [p] moves at [job]: how the picker ranks.
double jobScore(
  WorkJob job,
  WorkerProfile p, {
  double distance = 0,
  int pressTier = 1,
}) => switch (job) {
  WorkJob.miner => p.harvestRate.toDouble(),
  WorkJob.courier =>
    WorkRules.courierLoad(p.strength) /
        (WorkRules.courierCycleMs(distance, p.speed) / 60000),
  WorkJob.scavenger =>
    WorkRules.scavengerFind(p.strength) /
            (WorkRules.scavengerTripMs(p.speed) / 60000) +
        WorkRules.scavengerShardOdds(p.intelligence),
  WorkJob.presser => WorkRules.pressRate(p.strength, pressTier),
};

/// Which stats a job reads, for the slot's small print.
String jobReads(WorkJob job) => switch (job) {
  WorkJob.miner => 'LEVEL · SIZE · NATURE',
  WorkJob.courier => 'SPEED · STRENGTH',
  WorkJob.scavenger => 'SPEED · STRENGTH · INTELLIGENCE',
  WorkJob.presser => 'STRENGTH',
};

// ── the stage ───────────────────────────────────────────────────────────────

/// A building turning on a small stage: [paint] draws it about the centre
/// of a canvas scaled so [reach] art units fill most of the height.
class WorksStage extends StatefulWidget {
  const WorksStage({
    super.key,
    required this.paint,
    required this.reach,
    this.reachX,
    this.accent = _amber,
    this.height = 96,
  });

  final void Function(Canvas c, double t) paint;

  /// How far the art reaches up and down from the centre, in art units;
  /// [reachX] across, when that is what limits it (a wide building).
  final double reach;
  final double? reachX;
  final Color accent;
  final double height;

  @override
  State<WorksStage> createState() => _WorksStageState();
}

class _WorksStageState extends State<WorksStage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _clock = ValueNotifier(3);
  late final Ticker _ticker = createTicker(
    (d) => _clock.value = 3 + d.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _WorksStagePainter(
          clock: _clock,
          paintArt: widget.paint,
          reach: widget.reach,
          reachX: widget.reachX,
          accent: widget.accent,
        ),
      ),
    ),
  );
}

class _WorksStagePainter extends CustomPainter {
  _WorksStagePainter({
    required this.clock,
    required this.paintArt,
    required this.reach,
    required this.reachX,
    required this.accent,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final void Function(Canvas c, double t) paintArt;
  final double reach;
  final double? reachX;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.08), accent.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(size.width / 2, size.height / 2);
    var k = size.height * 0.46 / reach;
    final rx = reachX;
    if (rx != null) k = k < size.width * 0.44 / rx ? k : size.width * 0.44 / rx;
    canvas.scale(k);
    paintArt(canvas, clock.value);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WorksStagePainter old) => true;
}

/// A plain lit planet whose rim is at the origin, under an extractor on a
/// stage.
void paintStagePlanet(Canvas c, Color col, {double r = 90}) {
  final centre = Offset(0, r);
  c.drawCircle(
    centre,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.55),
        radius: 1.1,
        colors: [
          Color.lerp(col, Colors.white, 0.2)!,
          Color.lerp(col, Colors.black, 0.35)!,
          Color.lerp(col, Colors.black, 0.9)!,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: centre, radius: r)),
  );
}

// ── pieces ──────────────────────────────────────────────────────────────────

/// A worker's portrait from its look.
class MemberSprite extends StatelessWidget {
  const MemberSprite(this.member, {super.key, this.size = 34});
  final CosmicPartyMember member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final sheet = member.spriteSheet;
    final v = member.spriteVisuals;
    if (sheet == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: PanelDot(elementInk(member.element), size: size * 0.4),
        ),
      );
    }
    final s = sheet;
    return SizedBox(
      width: size,
      height: size,
      child: CreatureSprite(
        spritePath: s.path,
        totalFrames: s.totalFrames,
        rows: s.rows,
        frameSize: s.frameSize,
        stepTime: s.stepTime,
        scale: v?.scale ?? 1.0,
        saturation: v?.saturation ?? 1.0,
        brightness: v?.brightness ?? 1.0,
        hueShift: v?.hueShiftDeg ?? 0.0,
        isPrismatic: v?.isPrismatic ?? false,
        mutation: v?.mutation,
        tint: v?.tint,
        costumes: v?.costumes,
        variantFaction: v?.variantFaction,
        elementType: v?.elementType,
        effectSlotSize: size,
      ),
    );
  }
}

/// A job's slot: who is in it and what they do, or an empty one to fill.
class WorkerSlotRow extends StatelessWidget {
  const WorkerSlotRow({
    super.key,
    required this.job,
    required this.member,
    required this.profile,
    required this.status,
    required this.onAssign,
    required this.onClear,
    this.distance = 0,
    this.pressTier = 1,
    this.emptyLabel,
    this.slotKey,
  });

  final WorkJob job;
  final CosmicPartyMember? member;
  final WorkerProfile? profile;

  /// What it is doing right now ("OUT · 2:10", "RESTING").
  final String? status;
  final VoidCallback onAssign;
  final VoidCallback onClear;
  final double distance;
  final int pressTier;
  final String? emptyLabel;
  final Key? slotKey;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final p = profile;
    if (m == null || p == null) {
      return GestureDetector(
        key: slotKey,
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(onAssign),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: _amber.withValues(alpha: 0.55),
          ),
          child: Container(
            height: 44,
            color: panelPalette.bg1.withValues(alpha: 0.5),
            alignment: Alignment.center,
            child: Text(
              emptyLabel ?? '+ ASSIGN A ${job.label}',
              style: panelLabel(10, _amber, spacing: 1.2),
            ),
          ),
        ),
      );
    }
    final ink = elementInk(m.element);
    return GestureDetector(
      key: slotKey,
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onAssign),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: panelPalette.line.withValues(alpha: 0.5),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
          color: panelPalette.bg1.withValues(alpha: 0.6),
          child: Row(
            children: [
              MemberSprite(m, size: 36),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.displayName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: panelLabel(10, ink, spacing: 0.6),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      jobFigure(
                        job,
                        p,
                        distance: distance,
                        pressTier: pressTier,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: panelLabel(9.5, panelPalette.ink, spacing: 0.4),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        status!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: panelLabel(
                          8.5,
                          panelPalette.muted,
                          spacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: context.soundAction(onClear),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text('OFF', style: panelLabel(9, panelPalette.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A cost as chips: named elements against storage, any-matter, silver.
class WorksCostLine extends StatelessWidget {
  const WorksCostLine({
    super.key,
    required this.cost,
    required this.storage,
    required this.silver,
    this.fromHold,
  });

  final WorksCost cost;
  final Map<String, double> storage;
  final int silver;

  /// When the elements come out of the hold instead (an extractor's build).
  final Map<String, double>? fromHold;

  @override
  Widget build(BuildContext context) {
    final source = fromHold ?? storage;
    final storeTotal = storage.values.fold(0.0, (s, v) => s + v);
    final named = cost.elements.values.fold(0, (s, v) => s + v);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final e in cost.elements.entries)
          CostChip(e.key, e.value, source, size: 9.5),
        if (cost.matter > 0)
          Text(
            '${panelFmt(cost.matter)} ANY ELEMENTS',
            style: panelLabel(
              9.5,
              storeTotal - named >= cost.matter
                  ? panelPalette.ink
                  : CosmicScreenStyles.textMuted,
              spacing: 0.4,
            ),
          ),
        if (cost.silver > 0)
          CoinAmount(
            kind: CoinKind.silver,
            amount: cost.silver,
            size: 10,
            color: silver >= cost.silver ? null : CosmicScreenStyles.textMuted,
          ),
        if (fromHold != null)
          Text('FROM CARGO', style: panelLabel(8.5, panelPalette.muted)),
      ],
    );
  }
}

bool worksCostCovered(
  WorksCost cost,
  Map<String, double> storage,
  int silver, {
  Map<String, double>? fromHold,
}) {
  if (silver < cost.silver) return false;
  if (fromHold != null) {
    for (final e in cost.elements.entries) {
      if ((fromHold[e.key] ?? 0) + 1e-6 < e.value) return false;
    }
    return planMatter(cost.matter, storage) != null;
  }
  return elementsForCost(cost, storage) != null;
}

/// Tier as lit beads.
class _TierBeads extends StatelessWidget {
  const _TierBeads(this.tier, this.color);
  final int tier;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= WorkRules.maxTier; i++) ...[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= tier ? color : panelPalette.lineSoft,
          ),
        ),
        if (i < WorkRules.maxTier) const SizedBox(width: 4),
      ],
    ],
  );
}

/// One building's card: its name and tier over its stage, then [children].
class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.title,
    required this.accent,
    required this.tier,
    required this.stage,
    required this.children,
  });

  final String title;
  final Color accent;
  final int tier;
  final Widget stage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: BracketFramePainter(
      color: accent.withValues(alpha: 0.4),
    ),
    child: Container(
      color: panelPalette.bg1.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelLabel(11, accent, spacing: 1.8),
                ),
              ),
              if (tier > 0) _TierBeads(tier, accent),
            ],
          ),
          stage,
          ...children,
        ],
      ),
    ),
  );
}

Widget _line(String text, {Color? color, double size = 9.5}) => Padding(
  padding: const EdgeInsets.only(top: 3),
  child: Text(
    text,
    style: panelLabel(size, color ?? panelPalette.muted, spacing: 0.6),
  ),
);

Widget _gap([double h = 8]) => SizedBox(height: h);

// ── the Works ───────────────────────────────────────────────────────────────

class WorksPanel extends StatelessWidget {
  const WorksPanel({super.key, required this.view, required this.actions});

  final ValueListenable<WorksView> view;
  final WorksActions actions;

  @override
  Widget build(BuildContext context) {
    void close() {
      HapticFeedback.lightImpact();
      Navigator.of(context).maybePop();
    }

    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: close,
        alpha: 0.96,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Column(
            children: [
              PanelHeader(
                title: 'THE WORKS',
                trailing: GestureDetector(
                  key: const ValueKey('works.help'),
                  behavior: HitTestBehavior.opaque,
                  onTap: context.soundAction(actions.help),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text('HOW IT WORKS', style: panelLabel(9.5, _amber)),
                  ),
                ),
                onClose: close,
              ),
              Expanded(
                child: ValueListenableBuilder<WorksView>(
                  valueListenable: view,
                  builder: (context, v, _) => LayoutBuilder(
                    builder: (context, box) {
                      final cards = [
                        _bayCard(context, v),
                        _pressCard(context, v),
                        _outpostsCard(context, v),
                      ];
                      if (box.maxWidth < 640) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          children: [
                            for (final c in cards) ...[c, _gap(12)],
                          ],
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(
                                child: SingleChildScrollView(child: cards[i]),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrUpgrade(
    BuildContext context,
    WorksView v,
    WorksBuilding b,
    int tier, {
    String? element,
    Key? key,
  }) {
    if (tier >= WorkRules.maxTier) {
      return _line('FULLY BUILT', color: panelPalette.muted);
    }
    final cost = worksCost(b, tier + 1, element: element);
    final ok = worksCostCovered(cost, v.storage, v.silver);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gap(8),
        WorksCostLine(cost: cost, storage: v.storage, silver: v.silver),
        _gap(6),
        BracketButton(
          key: key,
          label: tier == 0 ? 'BUILD' : 'UPGRADE TO TIER ${tier + 1}',
          height: 38,
          palette: panelPalette,
          accent: _amber,
          primary: tier == 0,
          enabled: ok,
          onTap: () => tier == 0
              ? actions.build(b, element: element)
              : actions.upgrade(b, element: element),
        ),
      ],
    );
  }

  Widget _bayCard(BuildContext context, WorksView v) {
    final bay = v.works.bay;
    final stage = WorksStage(
      accent: kScavengerBayLight,
      reach: 26,
      reachX: kBayReach,
      paint: (c, t) => paintScavengerBay(
        c,
        at: const Offset(0, 4),
        tier: bay.built ? bay.tier : 1,
        t: t,
        resting: [for (final s in bay.slots) s.instanceId != null && !s.out],
        crates: [for (final cr in bay.crates) elementColor(_lead(cr))],
        crateCap: bay.built ? bay.crateCap : 6,
        searching: bay.out > 0,
      ),
    );
    if (!bay.built) {
      return _BuildingCard(
        title: 'SCAVENGER BAY',
        accent: kScavengerBayLight,
        tier: 0,
        stage: Opacity(opacity: 0.45, child: stage),
        children: [
          _line(
            'Scavengers fly out and bring back elements from the planets you have found, and sometimes astral shards.',
            size: 9.5,
          ),
          _buildOrUpgrade(
            context,
            v,
            WorksBuilding.scavengerBay,
            0,
            key: const ValueKey('works.bay.build'),
          ),
        ],
      );
    }
    final finds = bay.crates.length;
    final units = bay.crates.fold(0, (s, c) => s + c.units);
    final shards = bay.crates.fold(0, (s, c) => s + c.shards);
    return _BuildingCard(
      title: 'SCAVENGER BAY',
      accent: kScavengerBayLight,
      tier: bay.tier,
      stage: stage,
      children: [
        PanelGauge(
          label: 'CRATES',
          labelWidth: 56,
          fraction: finds / bay.crateCap,
          value: '$finds/${bay.crateCap}',
          color: kScavengerBayLight,
        ),
        for (var i = 0; i < bay.slots.length; i++) ...[
          _gap(6),
          _slot(
            v,
            WorkSlotRef(WorkJob.scavenger, index: i),
            bay.slots[i].instanceId,
            status: _scavengerStatus(v, bay, bay.slots[i]),
            key: ValueKey('works.bay.slot.$i'),
          ),
        ],
        _gap(8),
        BracketButton(
          key: const ValueKey('works.bay.collect'),
          label: finds == 0
              ? 'NOTHING TO COLLECT'
              : 'COLLECT ${panelFmt(units)}${shards > 0 ? ' + $shards SHARDS' : ''}',
          height: 38,
          palette: panelPalette,
          accent: kScavengerBayLight,
          enabled: finds > 0,
          onTap: actions.collectCrates,
        ),
        _buildOrUpgrade(context, v, WorksBuilding.scavengerBay, bay.tier),
      ],
    );
  }

  String _scavengerStatus(WorksView v, ScavengerBayState bay, ScavengerSlot s) {
    if (s.instanceId == null) return '';
    if (s.out) {
      final left = s.tripStartMs + s.tripMs - v.nowMs;
      return 'OUT · BACK IN ${fmtDuration(left.clamp(0, 1 << 31))}';
    }
    if (bay.crates.length + bay.out >= bay.crateCap) {
      return 'RESTING · CRATES FULL';
    }
    return 'RESTING';
  }

  Widget _pressCard(BuildContext context, WorksView v) {
    final press = v.works.press;
    final intake = <Color>[
      for (final e in v.storage.entries)
        if (e.value > press.reserve + 0.5) elementColor(e.key),
    ];
    final presser = press.presser == null ? null : v.profiles[press.presser];
    final stage = WorksStage(
      accent: kSilverPressLight,
      reach: 38,
      reachX: 36,
      paint: (c, t) => paintSilverPress(
        c,
        at: Offset.zero,
        tier: press.built ? press.tier : 1,
        t: t,
        pressing: press.built && presser != null && intake.isNotEmpty,
        intake: intake.take(4).toList(),
      ),
    );
    if (!press.built) {
      return _BuildingCard(
        title: 'SILVER PRESS',
        accent: kSilverPressLight,
        tier: 0,
        stage: Opacity(opacity: 0.45, child: stage),
        children: [
          _line(
            'Presses spare elements into silver. It leaves alone what you tell it to keep.',
          ),
          _buildOrUpgrade(
            context,
            v,
            WorksBuilding.silverPress,
            0,
            key: const ValueKey('works.press.build'),
          ),
        ],
      );
    }
    final surplus = v.storage.values.fold(
      0.0,
      (s, x) => s + (x > press.reserve ? x - press.reserve : 0),
    );
    return _BuildingCard(
      title: 'SILVER PRESS',
      accent: kSilverPressLight,
      tier: press.tier,
      stage: stage,
      children: [
        _line(
          presser == null
              ? 'NO PRESSER'
              : surplus < 1
              ? 'NOTHING OVER THE RESERVE'
              : 'PRESSING ${panelFmt(surplus)} SPARE',
          color: presser != null && surplus >= 1 ? panelPalette.ink : null,
        ),
        _line(
          '${WorkRules.grainsPerSilver} ELEMENTS MAKE 1 SILVER · ${panelFmt(press.pressedSilver)} PRESSED SO FAR',
        ),
        _gap(6),
        _slot(
          v,
          const WorkSlotRef(WorkJob.presser),
          press.presser,
          pressTier: press.tier,
          key: const ValueKey('works.press.slot'),
        ),
        _gap(8),
        Text('KEEP OF EACH', style: panelLabel(9, panelPalette.muted)),
        _gap(4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in WorkRules.pressReserves)
              _Chip(
                key: ValueKey('works.press.keep.$r'),
                label: panelFmt(r),
                on: press.reserve == r,
                onTap: () => actions.setReserve(r),
              ),
          ],
        ),
        _buildOrUpgrade(context, v, WorksBuilding.silverPress, press.tier),
      ],
    );
  }

  Widget _outpostsCard(BuildContext context, WorksView v) {
    final built = v.works.extractors;
    return _BuildingCard(
      title: 'EXTRACTORS',
      accent: _amber,
      tier: 0,
      stage: WorksStage(
        accent: _amber,
        reach: kExtractorReach * 0.62,
        paint: (c, t) {
          c.translate(0, 26);
          const col = Color(0xFFE0B068);
          paintStagePlanet(c, col);
          paintExtractor(
            c,
            at: Offset.zero,
            essence: col,
            tier: 2,
            t: t,
            fill: 0.55 + 0.25 * sin(t * 0.4),
            scale: 0.6,
          );
        },
      ),
      children: [
        _line(
          'Build one at any planet you have found, with ${WorkRules.extractorBuildUnits} of its element in your cargo.',
        ),
        _gap(6),
        if (v.planetsFound.isEmpty)
          _line('NO PLANETS FOUND YET', color: panelPalette.muted),
        for (final e in v.planetsFound) _outpostRow(context, v, e, built[e]),
      ],
    );
  }

  Widget _outpostRow(
    BuildContext context,
    WorksView v,
    String e,
    ExtractorState? x,
  ) {
    final ink = elementInk(e);
    return GestureDetector(
      key: ValueKey('works.outpost.$e'),
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(() => actions.openOutpost(e)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            PanelDot(x == null ? ink.withValues(alpha: 0.35) : ink, size: 8),
            const SizedBox(width: 7),
            SizedBox(
              width: 78,
              child: Text(
                planetName(e).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: panelLabel(
                  9.5,
                  x == null ? panelPalette.muted : ink,
                  spacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: x == null
                  ? Text('NOT BUILT', style: panelLabel(9, panelPalette.muted))
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 5,
                            child: LinearProgressIndicator(
                              value: x.hopper / x.hopperCap,
                              backgroundColor: panelPalette.lineSoft,
                              valueColor: AlwaysStoppedAnimation(
                                ink.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${x.hopper.floor()}/${x.hopperCap}',
                          style: panelLabel(9, panelPalette.ink, spacing: 0.3),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 6),
            Text('›', style: panelLabel(13, panelPalette.muted)),
          ],
        ),
      ),
    );
  }

  Widget _slot(
    WorksView v,
    WorkSlotRef ref,
    String? id, {
    String? status,
    int pressTier = 1,
    Key? key,
  }) => WorkerSlotRow(
    slotKey: key,
    job: ref.job,
    member: id == null ? null : v.members[id],
    profile: id == null ? null : v.profiles[id],
    status: status,
    pressTier: pressTier,
    onAssign: () => actions.assign(ref),
    onClear: () => actions.clear(ref),
  );
}

String _lead(ScavengerFind f) => f.elements.isEmpty
    ? 'Earth'
    : f.elements.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: context.soundAction(onTap),
    child: CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: (on ? kSilverPressLight : panelPalette.line).withValues(
          alpha: on ? 0.9 : 0.45,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        color: on
            ? kSilverPressLight.withValues(alpha: 0.12)
            : panelPalette.bg1.withValues(alpha: 0.5),
        child: Text(
          label,
          style: panelLabel(
            9.5,
            on ? kSilverPressLight : panelPalette.muted,
            spacing: 0.4,
          ),
        ),
      ),
    ),
  );
}

// ── an outpost ──────────────────────────────────────────────────────────────

class OutpostPanel extends StatelessWidget {
  const OutpostPanel({
    super.key,
    required this.element,
    required this.view,
    required this.actions,
  });

  final String element;
  final ValueListenable<WorksView> view;
  final WorksActions actions;

  @override
  Widget build(BuildContext context) {
    void close() {
      HapticFeedback.lightImpact();
      Navigator.of(context).maybePop();
    }

    final color = elementColor(element);
    final ink = elementInk(element);
    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: close,
        alpha: 0.96,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: ValueListenableBuilder<WorksView>(
            valueListenable: view,
            builder: (context, v, _) {
              final x = v.works.extractors[element];
              final near = v.nearRig == element;
              return Column(
                children: [
                  PanelHeader(
                    title: '${planetName(element).toUpperCase()} EXTRACTOR',
                    trailing: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: context.soundAction(actions.help),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          'HOW IT WORKS',
                          style: panelLabel(9.5, _amber),
                        ),
                      ),
                    ),
                    onClose: close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final rig = WorksStage(
                          accent: color,
                          reach: kExtractorReach * 0.95,
                          height: box.maxWidth >= 560
                              ? double.infinity
                              : (box.maxHeight * 0.34).clamp(120.0, 200.0),
                          paint: (c, t) {
                            c.translate(0, 34);
                            paintStagePlanet(c, color, r: 130);
                            paintExtractor(
                              c,
                              at: Offset.zero,
                              essence: color,
                              tier: x?.tier ?? 1,
                              t: t,
                              fill: x == null ? 0 : x.hopper / x.hopperCap,
                              mining:
                                  x != null &&
                                  x.miners.any(
                                    (m) => m != null && v.profiles[m] != null,
                                  ),
                            );
                          },
                        );
                        // Not built yet: the rig stands faint, as a plan.
                        final stage = x == null
                            ? Opacity(opacity: 0.5, child: rig)
                            : rig;
                        final body = x == null
                            ? _unbuilt(context, v, ink)
                            : _built(context, v, x, ink, near);
                        if (box.maxWidth >= 560) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: stage),
                              Expanded(
                                flex: 6,
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    4,
                                    16,
                                    12,
                                  ),
                                  children: body,
                                ),
                              ),
                            ],
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          children: [stage, _gap(6), ...body],
                        );
                      },
                    ),
                  ),
                  if (x != null)
                    StationDock(
                      accent: color,
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: BracketButton(
                                key: const ValueKey('outpost.sendHome'),
                                label: near
                                    ? (x.hopper >= 1
                                          ? 'SEND ${x.hopper.floor()} HOME'
                                          : 'HOPPER EMPTY')
                                    : 'FLY HERE TO SEND HOME',
                                height: 44,
                                palette: panelPalette,
                                accent: color,
                                enabled: near && x.hopper >= 1,
                                onTap: () => actions.sendHome(element),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _unbuilt(BuildContext context, WorksView v, Color ink) {
    final cost = worksCost(WorksBuilding.extractor, 1, element: element);
    final here = v.nearRig == element || _atPlanet(v);
    final ok =
        here && worksCostCovered(cost, const {}, v.silver, fromHold: v.hold);
    final have = (v.hold[element] ?? 0).floor();
    return [
      const PanelSectionHeader('NOT BUILT'),
      _line(
        'An extractor mines this planet\'s ${element.toUpperCase()} into its hopper. '
        'Only ${element.toUpperCase()} Alchemons can mine it.',
        color: panelPalette.ink,
        size: 10,
      ),
      _gap(10),
      PanelGauge(
        label: 'CARGO',
        labelWidth: 56,
        fraction: have / WorkRules.extractorBuildUnits,
        value: '$have/${WorkRules.extractorBuildUnits}',
        color: ink,
        note: element.toUpperCase(),
      ),
      _gap(4),
      _line(
        here
            ? (have >= WorkRules.extractorBuildUnits
                  ? 'READY TO BUILD'
                  : 'GATHER ${WorkRules.extractorBuildUnits - have} MORE ${element.toUpperCase()} HERE, OR LOAD IT AT HOME')
            : 'FLY TO ${planetName(element).toUpperCase()} TO BUILD',
      ),
      _gap(10),
      BracketButton(
        key: const ValueKey('outpost.build'),
        label: 'BUILD EXTRACTOR',
        height: 44,
        palette: panelPalette,
        accent: ink,
        enabled: ok,
        onTap: () => actions.build(WorksBuilding.extractor, element: element),
      ),
    ];
  }

  bool _atPlanet(WorksView v) => v.atPlanet == element;

  List<Widget> _built(
    BuildContext context,
    WorksView v,
    ExtractorState x,
    Color ink,
    bool near,
  ) {
    final rate = minerRate(x, v.profiles);
    final distance = v.distanceHome(element);
    final courier = x.courier == null ? null : v.profiles[x.courier];
    final runMs = courier == null
        ? 0
        : WorkRules.courierCycleMs(distance, courier.speed);
    final runRate = courier == null
        ? 0.0
        : WorkRules.courierLoad(courier.strength) / (runMs / 60000);
    String? courierStatus;
    if (courier != null && x.cycleMs > 0) {
      final ph = (v.nowMs - x.cycleStartMs) / x.cycleMs;
      courierStatus = ph < 0.5
          ? (x.cargo > 0 ? 'FLYING ${x.cargo.floor()} HOME' : 'ON ITS WAY HOME')
          : 'FLYING BACK';
    }
    final upTier = x.tier + 1;
    return [
      PanelGauge(
        label: 'HOPPER',
        labelWidth: 54,
        fraction: x.hopper / x.hopperCap,
        value: '${x.hopper.floor()}/${x.hopperCap}',
        color: ink,
        note: x.hopperFull ? 'FULL' : null,
      ),
      _line(
        rate <= 0
            ? 'NO MINER · NOTHING COMING IN'
            : 'MINING ${rate.toStringAsFixed(0)}/MIN'
                  '${courier != null ? ' · COURIER MOVES ${runRate.toStringAsFixed(1)}/MIN' : ''}',
        color: rate > 0 ? panelPalette.ink : null,
      ),
      _gap(8),
      PanelSectionHeader(x.miners.length > 1 ? 'MINERS' : 'MINER'),
      for (var i = 0; i < x.miners.length; i++) ...[
        WorkerSlotRow(
          slotKey: ValueKey('outpost.miner.$i'),
          job: WorkJob.miner,
          member: x.miners[i] == null ? null : v.members[x.miners[i]],
          profile: x.miners[i] == null ? null : v.profiles[x.miners[i]],
          status: null,
          emptyLabel: '+ ASSIGN A ${element.toUpperCase()} MINER',
          onAssign: () => actions.assign(
            WorkSlotRef(WorkJob.miner, element: element, index: i),
          ),
          onClear: () => actions.clear(
            WorkSlotRef(WorkJob.miner, element: element, index: i),
          ),
        ),
        _gap(6),
      ],
      _gap(4),
      const PanelSectionHeader('COURIER'),
      if (WorkRules.hasCourier(x.tier))
        WorkerSlotRow(
          slotKey: const ValueKey('outpost.courier'),
          job: WorkJob.courier,
          member: x.courier == null ? null : v.members[x.courier],
          profile: courier,
          status: courierStatus,
          distance: distance,
          onAssign: () =>
              actions.assign(WorkSlotRef(WorkJob.courier, element: element)),
          onClear: () =>
              actions.clear(WorkSlotRef(WorkJob.courier, element: element)),
        )
      else
        _line(
          'AT TIER 2 A COURIER FLIES THE HOPPER HOME ON ITS OWN. UNTIL THEN, COME HERE AND SEND IT HOME.',
        ),
      _gap(10),
      const PanelSectionHeader('UPGRADE'),
      if (x.tier >= WorkRules.maxTier)
        _line('FULLY BUILT')
      else ...[
        _line(switch (upTier) {
          2 => 'TIER 2: HOPPER ${WorkRules.hopperCap(2)} AND A COURIER',
          _ => 'TIER 3: HOPPER ${WorkRules.hopperCap(3)} AND A SECOND MINER',
        }, color: panelPalette.ink),
        _gap(6),
        WorksCostLine(
          cost: worksCost(WorksBuilding.extractor, upTier, element: element),
          storage: v.storage,
          silver: v.silver,
        ),
        _gap(6),
        BracketButton(
          key: const ValueKey('outpost.upgrade'),
          label: 'UPGRADE TO TIER $upTier',
          height: 38,
          palette: panelPalette,
          accent: ink,
          primary: false,
          enabled: worksCostCovered(
            worksCost(WorksBuilding.extractor, upTier, element: element),
            v.storage,
            v.silver,
          ),
          onTap: () =>
              actions.upgrade(WorksBuilding.extractor, element: element),
        ),
      ],
    ];
  }
}
