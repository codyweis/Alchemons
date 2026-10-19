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
import 'works_tutorials.dart';

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
    this.berthCount = 2,
    this.knownRecipes = const {},
    this.shipSkin,
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

  /// Berths round home for the home buildings (by the largest size
  /// unlocked).
  final int berthCount;

  /// Refinery recipes the Codex has found, as pair keys ('Fire+Water').
  final Set<String> knownRecipes;

  /// The hull the ship flies, held in the Armory's gantry.
  final String? shipSkin;
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
  void setRecipe(String? recipe);
  void setRefineKeep(int keep);
  void openArmory();
  Future<void> openCodex();
  Future<void> dismantle(WorksBuilding b);
  Future<void> openOutpost(String element);
}

const Color _amber = CosmicScreenStyles.amberBright;

String fmtDuration(int ms) {
  final s = (ms / 1000).round();
  if (s >= 3600) return '${s ~/ 3600}H ${(s % 3600) ~/ 60}M';
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// A rate a minute as every Works screen writes it: whole from 10 up, else
/// to one place, so a slot and its building's summary always agree.
String fmtRate(double r) =>
    r >= 10 || r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(1);

/// What [p] makes or moves a minute at [job]: what goes in, out, or home a
/// minute, the same figure the building's summary adds up.
double jobRate(
  WorkJob job,
  WorkerProfile p, {
  double distance = 0,
  int pressTier = 1,
  int refineTier = 1,
}) => switch (job) {
  WorkJob.miner => p.harvestRate.toDouble(),
  WorkJob.courier =>
    WorkRules.courierLoad(p.strength) /
        (WorkRules.courierCycleMs(distance, p.speed) / 60000),
  WorkJob.scavenger =>
    WorkRules.scavengerFind(p.strength) /
        (WorkRules.scavengerTripMs(p.speed) / 60000),
  WorkJob.presser =>
    WorkRules.pressRate(p.beauty, pressTier) / WorkRules.grainsPerSilver,
  WorkJob.refiner =>
    WorkRules.refineRate(p.intelligence) * WorkRules.refineYield(refineTier),
};

/// What [p] would do at [job], as a rate a minute: the figure the picker
/// sorts by and every slot shows.
String jobFigure(
  WorkJob job,
  WorkerProfile p, {
  double distance = 0,
  int pressTier = 1,
  int refineTier = 1,
}) {
  final r = fmtRate(
    jobRate(
      job,
      p,
      distance: distance,
      pressTier: pressTier,
      refineTier: refineTier,
    ),
  );
  return switch (job) {
    WorkJob.presser => '$r SILVER/MIN',
    WorkJob.refiner => '$r MADE/MIN',
    _ => '$r/MIN',
  };
}

/// How a run or a trip makes up that rate, for those that come in loads.
String? jobDetail(WorkJob job, WorkerProfile p, {double distance = 0}) =>
    switch (job) {
      WorkJob.courier =>
        '${WorkRules.courierLoad(p.strength)} A RUN · '
            '${fmtDuration(WorkRules.courierCycleMs(distance, p.speed))}',
      WorkJob.scavenger =>
        '${WorkRules.scavengerFind(p.strength)} A TRIP · '
            '${fmtDuration(WorkRules.scavengerTripMs(p.speed))}',
      _ => null,
    };

/// How the picker ranks: the rate, and for a scavenger its odds of shards
/// on top.
double jobScore(
  WorkJob job,
  WorkerProfile p, {
  double distance = 0,
  int pressTier = 1,
}) =>
    jobRate(job, p, distance: distance, pressTier: pressTier) +
    (job == WorkJob.scavenger
        ? WorkRules.scavengerShardOdds(p.intelligence)
        : 0);

/// Which stats a job reads, for the slot's small print.
String jobReads(WorkJob job) => switch (job) {
  WorkJob.miner => 'LEVEL · SIZE · NATURE',
  WorkJob.courier => 'SPEED · STRENGTH',
  WorkJob.scavenger => 'SPEED · STRENGTH · INTELLIGENCE',
  WorkJob.presser => 'BEAUTY',
  WorkJob.refiner => 'INTELLIGENCE',
};

String _stat(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// [p]'s own figures for what [job] reads: SPD 3 · STR 2. A miner's rate
/// comes from its level, size and nature together, so it shows its level.
String jobStats(WorkJob job, WorkerProfile p, {required int level}) =>
    switch (job) {
      WorkJob.miner => 'LV $level',
      WorkJob.courier => 'SPD ${_stat(p.speed)} · STR ${_stat(p.strength)}',
      WorkJob.scavenger =>
        'SPD ${_stat(p.speed)} · STR ${_stat(p.strength)} · '
            'INT ${_stat(p.intelligence)}',
      WorkJob.presser => 'BEAUTY ${_stat(p.beauty)}',
      WorkJob.refiner => 'INT ${_stat(p.intelligence)}',
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
    this.refineTier = 1,
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
  final int refineTier;
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
    final detail = jobDetail(job, p, distance: distance);
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
                    Text.rich(
                      TextSpan(
                        text: jobFigure(
                          job,
                          p,
                          distance: distance,
                          pressTier: pressTier,
                          refineTier: refineTier,
                        ),
                        children: [
                          if (detail != null)
                            TextSpan(
                              text: '  $detail',
                              style: panelLabel(
                                8.5,
                                panelPalette.muted,
                                spacing: 0.4,
                              ),
                            ),
                        ],
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
              // The whole row changes who works it; said here so it is
              // found.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                child: Text('CHANGE', style: panelLabel(9, ink, spacing: 0.8)),
              ),
              GestureDetector(
                key: switch (slotKey) {
                  ValueKey<String>(:final value) => ValueKey('$value.remove'),
                  _ => null,
                },
                behavior: HitTestBehavior.opaque,
                onTap: context.soundAction(onClear),
                // Takes the Alchemon off the job; a wide target for a thumb.
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    'REMOVE',
                    style: panelLabel(9, panelPalette.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A cost in words: its named elements against what is held, the elements
/// of any kind it takes, and its silver (a coin alone did not say silver).
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

  /// When the elements come out of the ship's cargo instead (an extractor's
  /// build).
  final Map<String, double>? fromHold;

  @override
  Widget build(BuildContext context) {
    final source = fromHold ?? storage;
    // Said the way the rest of the line is: how much of what, and what is
    // held only when it falls short.
    final parts = <Widget>[
      for (final e in cost.elements.entries)
        () {
          final have = source[e.key] ?? 0;
          final ok = have + 1e-6 >= e.value;
          final ink = elementInk(e.key);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PanelDot(ok ? ink : ink.withValues(alpha: 0.4), size: 6),
              const SizedBox(width: 5),
              Text(
                '${panelFmt(e.value)} ${e.key.toUpperCase()}'
                '${ok ? '' : ' · YOU HAVE ${panelFmt(have)}'}',
                style: panelLabel(
                  9.5,
                  ok ? ink : CosmicScreenStyles.textMuted,
                  spacing: 0.4,
                ),
              ),
            ],
          );
        }(),
    ];
    if (fromHold != null) {
      parts.add(Text('FROM CARGO', style: panelLabel(8.5, panelPalette.muted)));
    }
    if (cost.matter > 0) {
      // Any elements will do; which ones the confirmation names.
      final named = cost.elements.values.fold(0, (s, v) => s + v);
      final have = storage.values.fold(0.0, (s, v) => s + v) - named;
      final ok = have + 1e-6 >= cost.matter;
      parts.add(
        Text(
          '${panelFmt(cost.matter)} ANY ELEMENTS'
          '${ok ? '' : ' · YOU HAVE ${panelFmt(have < 0 ? 0 : have)}'}',
          style: panelLabel(
            9.5,
            ok ? panelPalette.ink : CosmicScreenStyles.textMuted,
            spacing: 0.4,
          ),
        ),
      );
    }
    if (cost.silver > 0) {
      final ok = silver >= cost.silver;
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(kind: CoinKind.silver, size: 11),
            const SizedBox(width: 4),
            Text(
              '${panelFmt(cost.silver)} SILVER'
              '${ok ? '' : ' · YOU HAVE ${panelFmt(silver)}'}',
              style: panelLabel(
                9.5,
                ok ? panelPalette.ink : CosmicScreenStyles.textMuted,
                spacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('COSTS', style: panelLabel(8.5, panelPalette.muted)),
        ...parts,
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

/// One building's view in the Works: its name and tier, its stage, and what
/// it does. Wide, the stage stands beside the rest; narrow, above it.
class _BuildingView extends StatelessWidget {
  const _BuildingView({
    required this.title,
    required this.accent,
    required this.tier,
    required this.stage,
    required this.children,
    this.help,
  });

  final String title;
  final Color accent;
  final int tier;

  /// Whose tutorial the ? beside the name opens.
  final WorksBuilding? help;

  /// The stage at a height (infinite: fill the column).
  final Widget Function(double height) stage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final head = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: panelLabel(12, accent, spacing: 2),
            ),
          ),
          if (tier > 0) ...[
            Text('TIER $tier  ', style: panelLabel(9, panelPalette.muted)),
            _TierBeads(tier, accent),
          ],
          if (help != null) WorksHelpButton(building: help!, accent: accent),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: stage(double.infinity)),
              Expanded(
                flex: 6,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 16),
                  children: [head, ...children],
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [head, stage(150), _gap(4), ...children],
        );
      },
    );
  }
}

Widget _line(String text, {Color? color, double size = 9.5}) => Padding(
  padding: const EdgeInsets.only(top: 3),
  child: Text(
    text,
    style: panelLabel(size, color ?? panelPalette.muted, spacing: 0.6),
  ),
);

Widget _gap([double h = 8]) => SizedBox(height: h);

/// An extractor at a glance, for the PLANETS list: whether it has stopped,
/// what its miners make, and where its courier is.
String outpostStatus(
  ExtractorState x,
  Map<String, WorkerProfile> profiles,
  int nowMs,
) {
  final rate = minerRate(x, profiles);
  final courier = courierStatus(x, nowMs);
  return [
    if (extractorNeed(x) == WorksNeed.full) 'FULL',
    if (x.miners.every((m) => m == null))
      'NO MINER'
    else
      'MINING ${fmtRate(rate)}/MIN',
    if (WorkRules.hasCourier(x.tier))
      x.courier == null ? 'NO COURIER' : 'COURIER ${courier ?? 'WAITING'}',
  ].join(' · ');
}

/// What a refinery tier makes of what it takes, in whole numbers.
String refineYieldLine(int tier) => switch (tier) {
  <= 1 => '2 IN → 1 OUT',
  2 => '5 IN → 3 OUT',
  _ => '3 IN → 2 OUT',
};

// ── the Works ───────────────────────────────────────────────────────────────

enum WorksTab { armory, bay, press, refinery, planets }

/// Whether [tab] holds something that wants the player (see [WorksNeed]).
bool worksTabNeeds(WorksTab tab, WorksView v) => switch (tab) {
  WorksTab.armory => false,
  WorksTab.bay => bayNeed(v.works.bay) != null,
  WorksTab.press => pressNeed(v.works.press) != null,
  WorksTab.refinery => refineryNeed(v.works.refinery, v.knownRecipes) != null,
  WorksTab.planets => v.works.extractorsNeed,
};

/// The first tab that wants the player, or null when none does.
WorksTab? firstWorksTabNeeding(WorksView v) {
  for (final t in WorksTab.values) {
    if (worksTabNeeds(t, v)) return t;
  }
  return null;
}

class WorksPanel extends StatefulWidget {
  const WorksPanel({
    super.key,
    required this.view,
    required this.actions,
    this.initialTab = WorksTab.armory,
    this.onTabChanged,
  });

  final ValueListenable<WorksView> view;
  final WorksActions actions;
  final WorksTab initialTab;

  /// Told each tab the player turns to, so the Works can open on it again.
  final ValueChanged<WorksTab>? onTabChanged;

  @override
  State<WorksPanel> createState() => _WorksPanelState();
}

class _WorksPanelState extends State<WorksPanel> {
  late WorksTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(covariant WorksPanel old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  WorksActions get actions => widget.actions;

  static const _labels = ['ARMORY', 'BAY', 'PRESS', 'REFINERY', 'PLANETS'];

  Color _accentOf(WorksTab t) => switch (t) {
    WorksTab.armory => kArmoryLight,
    WorksTab.bay => kScavengerBayLight,
    WorksTab.press => kSilverPressLight,
    WorksTab.refinery => kRefineryLight,
    WorksTab.planets => _amber,
  };

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
          child: ValueListenableBuilder<WorksView>(
            valueListenable: widget.view,
            builder: (context, v, _) => Column(
              children: [
                PanelHeader(
                  title: 'THE WORKS',
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // What the Works are paid in, held to hand.
                        Row(
                          key: const ValueKey('works.silver'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CoinIcon(kind: CoinKind.silver, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              panelFmt(v.silver),
                              style: panelLabel(
                                11.5,
                                coinColor(CoinKind.silver),
                                spacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'SLOTS ${v.works.berthsUsed}/${v.berthCount}',
                          key: const ValueKey('works.berths'),
                          style: panelLabel(9.5, panelPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  onClose: close,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _TabStrip(
                    key: const ValueKey('works.tabs'),
                    labels: _labels,
                    selected: _tab.index,
                    onSelect: (i) {
                      setState(() => _tab = WorksTab.values[i]);
                      widget.onTabChanged?.call(_tab);
                    },
                    accent: _accentOf(_tab),
                    marked: {
                      for (final t in WorksTab.values)
                        if (worksTabNeeds(t, v)) t.index,
                    },
                  ),
                ),
                Expanded(
                  child: switch (_tab) {
                    WorksTab.armory => _armoryView(context, v),
                    WorksTab.bay => _bay(context, v),
                    WorksTab.press => _press(context, v),
                    WorksTab.refinery => _refinery(context, v),
                    WorksTab.planets => _planets(context, v),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// BUILD, or UPGRADE to the next tier, with its cost; or FULLY BUILT. A
  /// home building needs a free berth to be built.
  Widget _buildOrUpgrade(
    WorksView v,
    WorksBuilding b,
    int tier, {
    Color accent = _amber,
    Key? key,
  }) {
    if (tier >= WorkRules.maxTier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_gap(10), _line('FULLY BUILT'), _takeDown(b)],
      );
    }
    final noBerth = tier == 0 && v.works.freeBerth(v.berthCount) == null;
    final cost = worksCost(b, tier + 1);
    final ok = !noBerth && worksCostCovered(cost, v.storage, v.silver);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gap(10),
        if (tier > 0) const PanelSectionHeader('UPGRADE'),
        if (noBerth)
          _line(
            'NO FREE SLOTS. A BIGGER PLANET HAS MORE.',
            color: panelPalette.ink,
          )
        else
          WorksCostLine(cost: cost, storage: v.storage, silver: v.silver),
        _gap(6),
        BracketButton(
          key: key,
          label: tier == 0 ? 'BUILD' : 'UPGRADE TO TIER ${tier + 1}',
          height: 40,
          palette: panelPalette,
          accent: accent,
          // Lit when it can be paid for: a quiet upgrade read as one that
          // could not be.
          primary: tier == 0 || ok,
          enabled: ok,
          onTap: () => tier == 0 ? actions.build(b) : actions.upgrade(b),
        ),
        if (tier > 0) _takeDown(b),
      ],
    );
  }

  /// A quiet way to free a berth.
  Widget _takeDown(WorksBuilding b) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        key: ValueKey('works.takeDown.${b.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(() => actions.dismantle(b)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            'TAKE DOWN',
            style: panelLabel(9, panelPalette.muted, spacing: 1.2),
          ),
        ),
      ),
    ),
  );

  Widget _stage({
    required double height,
    required Color accent,
    required double reach,
    double? reachX,
    required bool dim,
    required void Function(Canvas c, double t) paint,
  }) {
    final stage = WorksStage(
      accent: accent,
      reach: reach,
      reachX: reachX,
      height: height,
      paint: paint,
    );
    return dim ? Opacity(opacity: 0.45, child: stage) : stage;
  }

  // ── armory ──

  Widget _armoryView(BuildContext context, WorksView v) {
    final a = v.works.armory;
    Widget stage(double h) => _stage(
      height: h,
      accent: kArmoryLight,
      reach: 40,
      reachX: 34,
      dim: !a.built,
      paint: (c, t) => paintArmory(
        c,
        at: const Offset(0, -2),
        tier: a.built ? a.tier : 1,
        t: t,
        skin: v.shipSkin,
      ),
    );
    if (!a.built) {
      return _BuildingView(
        title: 'ARMORY',
        help: WorksBuilding.armory,
        accent: kArmoryLight,
        tier: 0,
        stage: stage,
        children: [
          _line(
            'WHERE YOUR SHIP IS UPGRADED.',
            color: panelPalette.ink,
            size: 10,
          ),
          _buildOrUpgrade(
            v,
            WorksBuilding.armory,
            0,
            accent: kArmoryLight,
            key: const ValueKey('works.armory.build'),
          ),
        ],
      );
    }
    final power = WorkRules.armoryPowerCap(a.tier);
    final tank = WorkRules.armoryTankCap(a.tier);
    return _BuildingView(
      title: 'ARMORY',
      help: WorksBuilding.armory,
      accent: kArmoryLight,
      tier: a.tier,
      stage: stage,
      children: [
        // In the Armory's own words, so the caps read straight across.
        _line(
          'AMMO + MISSILE POWER UP TO LV $power OF 5',
          color: panelPalette.ink,
          size: 10,
        ),
        _gap(4),
        _line(
          'FUEL TANK + CARGO HOLD UP TO LV $tank OF 3',
          color: panelPalette.ink,
          size: 10,
        ),
        _gap(10),
        BracketButton(
          key: const ValueKey('works.armory.open'),
          label: 'OPEN THE ARMORY',
          height: 44,
          palette: panelPalette,
          accent: kArmoryLight,
          onTap: actions.openArmory,
        ),
        _buildOrUpgrade(v, WorksBuilding.armory, a.tier, accent: kArmoryLight),
      ],
    );
  }

  // ── bay ──

  Widget _bay(BuildContext context, WorksView v) {
    final bay = v.works.bay;
    Widget stage(double h) => _stage(
      height: h,
      accent: kScavengerBayLight,
      reach: 26,
      reachX: kBayReach,
      dim: !bay.built,
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
      return _BuildingView(
        title: 'SCAVENGER BAY',
        help: WorksBuilding.scavengerBay,
        accent: kScavengerBayLight,
        tier: 0,
        stage: stage,
        children: [
          _line(
            'SCAVENGERS BRING BACK ELEMENTS FROM PLANETS YOU HAVE FOUND.',
            color: panelPalette.ink,
            size: 10,
          ),
          _buildOrUpgrade(
            v,
            WorksBuilding.scavengerBay,
            0,
            accent: kScavengerBayLight,
            key: const ValueKey('works.bay.build'),
          ),
        ],
      );
    }
    final finds = bay.crates.length;
    final units = bay.crates.fold(0, (s, c) => s + c.units);
    final shards = bay.crates.fold(0, (s, c) => s + c.shards);
    return _BuildingView(
      title: 'SCAVENGER BAY',
      help: WorksBuilding.scavengerBay,
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
        _gap(4),
        BracketButton(
          key: const ValueKey('works.bay.collect'),
          label: finds == 0
              ? 'NOTHING TO COLLECT'
              : 'COLLECT ${panelFmt(units)}'
                    '${shards > 0 ? ' + $shards SHARDS' : ''}',
          height: 40,
          palette: panelPalette,
          accent: kScavengerBayLight,
          enabled: finds > 0,
          onTap: actions.collectCrates,
        ),
        _gap(10),
        PanelSectionHeader(bay.slots.length > 1 ? 'SCAVENGERS' : 'SCAVENGER'),
        for (var i = 0; i < bay.slots.length; i++) ...[
          if (i > 0) _gap(6),
          _slot(
            v,
            WorkSlotRef(WorkJob.scavenger, index: i),
            bay.slots[i].instanceId,
            status: _scavengerStatus(v, bay, bay.slots[i]),
            key: ValueKey('works.bay.slot.$i'),
          ),
        ],
        _buildOrUpgrade(
          v,
          WorksBuilding.scavengerBay,
          bay.tier,
          accent: kScavengerBayLight,
        ),
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

  // ── press ──

  Widget _press(BuildContext context, WorksView v) {
    final press = v.works.press;
    final intake = <Color>[
      for (final e in v.storage.entries)
        if (e.value > press.reserve + 0.5) elementColor(e.key),
    ];
    final presser = press.presser == null ? null : v.profiles[press.presser];
    Widget stage(double h) => _stage(
      height: h,
      accent: kSilverPressLight,
      reach: 38,
      reachX: 36,
      dim: !press.built,
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
      return _BuildingView(
        title: 'SILVER PRESS',
        help: WorksBuilding.silverPress,
        accent: kSilverPressLight,
        tier: 0,
        stage: stage,
        children: [
          _line(
            'TURNS SPARE ELEMENTS INTO SILVER.',
            color: panelPalette.ink,
            size: 10,
          ),
          _buildOrUpgrade(
            v,
            WorksBuilding.silverPress,
            0,
            accent: kSilverPressLight,
            key: const ValueKey('works.press.build'),
          ),
        ],
      );
    }
    final surplus = v.storage.values.fold(
      0.0,
      (s, x) => s + (x > press.reserve ? x - press.reserve : 0),
    );
    return _BuildingView(
      title: 'SILVER PRESS',
      help: WorksBuilding.silverPress,
      accent: kSilverPressLight,
      tier: press.tier,
      stage: stage,
      children: [
        _line(
          presser == null
              ? 'NO PRESSER'
              : surplus < 1
              ? 'NOTHING OVER WHAT IT KEEPS'
              : 'PRESSING ${panelFmt(surplus)} SPARE · '
                    '${jobFigure(WorkJob.presser, presser, pressTier: press.tier)}',
          color: presser != null && surplus >= 1 ? panelPalette.ink : null,
          size: 10,
        ),
        _line(
          '${WorkRules.grainsPerSilver} ELEMENTS MAKE 1 SILVER · '
          '${panelFmt(press.pressedSilver)} PRESSED SO FAR',
        ),
        _gap(10),
        const PanelSectionHeader('PRESSER'),
        _slot(
          v,
          const WorkSlotRef(WorkJob.presser),
          press.presser,
          pressTier: press.tier,
          key: const ValueKey('works.press.slot'),
        ),
        _gap(10),
        const PanelSectionHeader('KEEP OF EACH'),
        _chips(
          'works.press.keep',
          press.reserve,
          kSilverPressLight,
          actions.setReserve,
        ),
        _buildOrUpgrade(
          v,
          WorksBuilding.silverPress,
          press.tier,
          accent: kSilverPressLight,
        ),
      ],
    );
  }

  Widget _chips(
    String keyPrefix,
    int value,
    Color accent,
    ValueChanged<int> onPick,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final r in WorkRules.pressReserves)
        _Chip(
          key: ValueKey('$keyPrefix.$r'),
          label: panelFmt(r),
          on: value == r,
          accent: accent,
          onTap: () => onPick(r),
        ),
    ],
  );

  // ── refinery ──

  Widget _refinery(BuildContext context, WorksView v) {
    final r = v.works.refinery;
    final parts = r.parts;
    final refiner = r.refiner == null ? null : v.profiles[r.refiner];
    final spare =
        parts != null &&
        (v.storage[parts.$1] ?? 0) > r.keep + 0.5 &&
        (v.storage[parts.$2] ?? 0) > r.keep + 0.5;
    final working = r.built && refiner != null && spare;
    Widget stage(double h) => _stage(
      height: h,
      accent: kRefineryLight,
      reach: 40,
      reachX: 38,
      dim: !r.built,
      paint: (c, t) => paintRefinery(
        c,
        at: Offset.zero,
        tier: r.built ? r.tier : 1,
        t: t,
        inA: parts == null ? null : elementColor(parts.$1),
        inB: parts == null ? null : elementColor(parts.$2),
        out: parts == null ? null : elementColor(parts.$3),
        working: working,
      ),
    );
    if (!r.built) {
      return _BuildingView(
        title: 'REFINERY',
        help: WorksBuilding.refinery,
        accent: kRefineryLight,
        tier: 0,
        stage: stage,
        children: [
          _line(
            'MAKES ONE ELEMENT FROM TWO, BY THE RECIPES IN YOUR CODEX.',
            color: panelPalette.ink,
            size: 10,
          ),
          _buildOrUpgrade(
            v,
            WorksBuilding.refinery,
            0,
            accent: kRefineryLight,
            key: const ValueKey('works.refinery.build'),
          ),
        ],
      );
    }
    final perMin = refiner == null
        ? 0.0
        : WorkRules.refineRate(refiner.intelligence) *
              WorkRules.refineYield(r.tier);
    final String status;
    if (parts == null) {
      status = 'CHOOSE WHAT TO MAKE';
    } else if (refiner == null) {
      status = 'NO REFINER';
    } else if (!spare) {
      final short = (v.storage[parts.$1] ?? 0) <= r.keep + 0.5
          ? parts.$1
          : parts.$2;
      status = 'OUT OF ${short.toUpperCase()} OVER WHAT IT KEEPS';
    } else {
      status = 'MAKING ${parts.$3.toUpperCase()} · ${fmtRate(perMin)}/MIN';
    }
    final all = WorkRules.refineRecipes.entries.toList();
    final found = [
      for (final e in all)
        if (v.knownRecipes.contains(e.key)) e,
    ];
    return _BuildingView(
      title: 'REFINERY',
      help: WorksBuilding.refinery,
      accent: kRefineryLight,
      tier: r.tier,
      stage: stage,
      children: [
        _line(status, color: working ? panelPalette.ink : null, size: 10),
        _line(refineYieldLine(r.tier)),
        _gap(10),
        const PanelSectionHeader('REFINER'),
        _slot(
          v,
          const WorkSlotRef(WorkJob.refiner),
          r.refiner,
          refineTier: r.tier,
          key: const ValueKey('works.refinery.slot'),
        ),
        _gap(10),
        Row(
          children: [
            const Expanded(child: PanelSectionHeader('MAKE')),
            const SizedBox(width: 10),
            GestureDetector(
              key: const ValueKey('works.refinery.codex'),
              behavior: HitTestBehavior.opaque,
              onTap: context.soundAction(actions.openCodex),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 0, 8),
                child: Text('CODEX ›', style: panelLabel(9.5, kRefineryLight)),
              ),
            ),
          ],
        ),
        if (found.isEmpty) _line('NONE YET'),
        for (final e in found)
          _recipeRow(v, e.key, e.value, r.recipe == e.key, r.keep),
        _gap(10),
        const PanelSectionHeader('KEEP OF EACH INPUT'),
        _chips(
          'works.refinery.keep',
          r.keep,
          kRefineryLight,
          actions.setRefineKeep,
        ),
        _buildOrUpgrade(
          v,
          WorksBuilding.refinery,
          r.tier,
          accent: kRefineryLight,
        ),
      ],
    );
  }

  Widget _recipeRow(
    WorksView v,
    String key,
    String out,
    bool chosen,
    int keep,
  ) {
    final ab = key.split('+');
    final ink = elementInk(out);
    String have(String e) =>
        '${e.toUpperCase()} ${panelFmt((v.storage[e] ?? 0).floor())}';
    // The first input without any over the keep, if one is short: such a
    // recipe can still be chosen, but it would stand idle.
    String? short;
    for (final e in ab) {
      if ((v.storage[e] ?? 0) <= keep + 0.5) {
        short = e;
        break;
      }
    }
    final row = GestureDetector(
      key: ValueKey('works.refinery.recipe.$key'),
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(() => actions.setRecipe(chosen ? null : key)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: (chosen ? kRefineryLight : panelPalette.line).withValues(
              alpha: chosen ? 0.9 : 0.35,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            color: chosen
                ? kRefineryLight.withValues(alpha: 0.1)
                : panelPalette.bg1.withValues(alpha: 0.5),
            child: Row(
              children: [
                PanelDot(ink, size: 9),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        out.toUpperCase(),
                        style: panelLabel(10.5, ink, spacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${have(ab[0])} + ${have(ab[1])}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: panelLabel(
                          8.5,
                          panelPalette.muted,
                          spacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (short != null)
                  Text(
                    'NOT ENOUGH ${short.toUpperCase()}',
                    style: panelLabel(8.5, panelPalette.muted),
                  )
                else if (chosen)
                  Text('MAKING', style: panelLabel(8.5, kRefineryLight)),
              ],
            ),
          ),
        ),
      ),
    );
    return short == null ? row : Opacity(opacity: 0.5, child: row);
  }

  // ── planets ──

  Widget _planets(BuildContext context, WorksView v) {
    final built = v.works.extractors;
    return _BuildingView(
      title: 'EXTRACTORS',
      accent: _amber,
      tier: 0,
      stage: (h) => _stage(
        height: h,
        accent: _amber,
        reach: kExtractorReach * 0.62,
        dim: false,
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
          'FLY TO A PLANET TO BUILD ONE THERE.',
          color: panelPalette.ink,
          size: 10,
        ),
        _gap(8),
        if (v.planetsFound.isEmpty) _line('NONE FOUND YET'),
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
    final need = x == null ? null : extractorNeed(x);
    return GestureDetector(
      key: ValueKey('works.outpost.$e'),
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(() => actions.openOutpost(e)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            PanelDot(x == null ? ink.withValues(alpha: 0.35) : ink, size: 8),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 92,
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
                            ? Text(
                                'NOT BUILT',
                                style: panelLabel(9, panelPalette.muted),
                              )
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
                                    style: panelLabel(
                                      9,
                                      panelPalette.ink,
                                      spacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  if (x != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          if (need != null) ...[
                            const AttentionDot(color: _amber, size: 5),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              outpostStatus(x, v.profiles, v.nowMs),
                              key: ValueKey('works.outpost.$e.status'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: panelLabel(
                                8.5,
                                need != null ? _amber : panelPalette.muted,
                                spacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
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
    int refineTier = 1,
    Key? key,
  }) => WorkerSlotRow(
    slotKey: key,
    job: ref.job,
    member: id == null ? null : v.members[id],
    profile: id == null ? null : v.profiles[id],
    status: status,
    pressTier: pressTier,
    refineTier: refineTier,
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
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool on;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: context.soundAction(onTap),
    child: CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: (on ? accent : panelPalette.line).withValues(
          alpha: on ? 0.9 : 0.45,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: on
            ? accent.withValues(alpha: 0.12)
            : panelPalette.bg1.withValues(alpha: 0.5),
        child: Text(
          label,
          style: panelLabel(
            9.5,
            on ? accent : panelPalette.muted,
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
                    trailing: WorksHelpButton(
                      building: WorksBuilding.extractor,
                      element: element,
                      accent: ink,
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
        'MINES ${element.toUpperCase()}. ITS MINER MUST BE '
        '${element.toUpperCase()}.',
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
                  : 'NEEDS ${WorkRules.extractorBuildUnits} ${element.toUpperCase()} IN CARGO')
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
    final runRate = courier == null
        ? 0.0
        : jobRate(WorkJob.courier, courier, distance: distance);
    final upTier = x.tier + 1;
    final upCost = worksCost(WorksBuilding.extractor, upTier, element: element);
    final canUpgrade = worksCostCovered(upCost, v.storage, v.silver);
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
            : 'MINING ${fmtRate(rate)}/MIN'
                  '${courier != null ? ' · COURIER MOVES ${fmtRate(runRate)}/MIN' : ''}',
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
          status: courier == null ? null : courierStatus(x, v.nowMs),
          distance: distance,
          onAssign: () =>
              actions.assign(WorkSlotRef(WorkJob.courier, element: element)),
          onClear: () =>
              actions.clear(WorkSlotRef(WorkJob.courier, element: element)),
        )
      else
        _line('TIER 2 ADDS A COURIER.'),
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
        WorksCostLine(cost: upCost, storage: v.storage, silver: v.silver),
        _gap(6),
        BracketButton(
          key: const ValueKey('outpost.upgrade'),
          label: 'UPGRADE TO TIER $upTier',
          height: 38,
          palette: panelPalette,
          accent: ink,
          primary: canUpgrade,
          enabled: canUpgrade,
          onTap: () =>
              actions.upgrade(WorksBuilding.extractor, element: element),
        ),
      ],
    ];
  }
}

/// The Works' tabs: one row of even tabs where each keeps its whole name,
/// and a row that scrolls sideways where they would be cut short.
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    required this.accent,
    this.marked = const {},
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final Color accent;

  /// Tabs that want the player, by index: a dot in the corner.
  final Set<int> marked;

  static const double _minTab = 88;

  /// BracketTabs' label: 12 px monospace, spaced 1.6 a letter.
  static const double _labelSize = 12;
  static const double _labelSpacing = 1.6;

  /// The smallest the labels are drawn to fit them all in, as a fraction of
  /// their size: about 9 px. Narrower than that, the strip scrolls.
  static const double _minFit = 0.75;

  /// The text size, as a fraction of [_labelSize], at which every label
  /// fits a tab [width] wide with [pad] clear either side. Letter spacing
  /// does not shrink with the text, so it is taken out first.
  double _fitFor(double width, double pad) {
    var fit = double.infinity;
    for (final l in labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: l,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: _labelSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final spacing = l.length * _labelSpacing;
      fit = min(fit, (width - 2 * pad - spacing) / max(1.0, tp.width));
      tp.dispose();
    }
    return fit;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final now = scaler.scale(_labelSize) / _labelSize;
      final n = labels.length;
      // At their own size, with room to spare.
      final even = (box.maxWidth - 8 * (n - 1)) / n;
      if (even >= _minTab && _fitFor(even, 8) >= now) {
        return BracketTabs(
          labels: labels,
          selected: selected,
          onSelect: onSelect,
          palette: panelPalette,
          accent: accent,
          marked: marked,
          markColor: _amber,
        );
      }
      // Closer together, the labels a little smaller: every tab in view.
      const gap = 4.0;
      final fit = min(now, _fitFor((box.maxWidth - gap * (n - 1)) / n, 3));
      if (fit >= _minFit) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(fit)),
          child: BracketTabs(
            labels: labels,
            selected: selected,
            onSelect: onSelect,
            palette: panelPalette,
            accent: accent,
            gap: gap,
            marked: marked,
            markColor: _amber,
          ),
        );
      }
      // Too narrow even so: the strip scrolls, fading at its edge so the
      // tabs past it read as more to come rather than cut off.
      return SizedBox(
        height: 40,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.9, 1],
          ).createShader(r),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 28),
            itemCount: n,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => SizedBox(
              width: _minTab,
              child: BracketTabs(
                labels: [labels[i]],
                selected: i == selected ? 0 : -1,
                onSelect: (_) => onSelect(i),
                palette: panelPalette,
                accent: accent,
                marked: marked.contains(i) ? const {0} : const {},
                markColor: _amber,
              ),
            ),
          ),
        ),
      );
    },
  );
}
