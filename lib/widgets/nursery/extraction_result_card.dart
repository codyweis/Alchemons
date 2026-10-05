// lib/widgets/nursery/extraction_result_card.dart
//
// THE EXTRACTION RESULT: the card a new specimen arrives on.
//
//   The extraction card's own layout -- the forge header, the stat profile,
//   the SPECIMEN / GENETICS analysis tabs and the docked confirm -- around a
//   lit stage where the specimen arrives. The hatch ends with the newborn
//   gathering out of grains, and the stage picks up there: its element gathers
//   into it (the same [ElementalEssence] reveal its details open with), and
//   only once it stands whole does the reading come in.
//
//   The stage replaced a cyan scan line over a holographic grid, played in
//   the middle of the card before the specimen flew to a corner dock, with an
//   8σ BackdropFilter behind it all. There is no blur here. The per-frame work
//   is the reveal while it plays (about a second and a half, batched points)
//   and the sprite itself.
//
//   The stage sits on the left with the stat profile beside it, as the old
//   sprite dock did. What is notable about the specimen (a new discovery, a
//   mutation, prismatic skin, a variant, its purity) is engraved in one quiet
//   line under the two, rather than as coloured badges stuck to its corners.
//
// One card for every extraction, single or batch -- the batch awaits it once
// per specimen -- so there is never a lesser second copy of it to drift.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/potential_genetics.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/card_dissolve.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/essence_rim.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart' show mutationAccent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The largest scale the size gene applies to a sprite (`giant`, from
/// alchemons_genetics.json). The stage fits the sprite to its box divided by
/// this, so a large specimen is never cut off.
const double _kMaxSizeGeneScale = 1.3;

/// From the moment a reveal is let go to the grains landing: the essence's
/// reveal runs from 1.05s to its landing at 2.2s, plus a frame or two to read
/// the sprite. The reveal sound's lock is timed against this.
const int _kRevealLandsMs = 1200;

/// The dim the card is shown on. Darker than the default: there is no blur
/// behind the card any more. The card lifts it as it comes apart.
const Color kExtractionCardBarrier = Color.from(
  alpha: 0.78,
  red: 0,
  green: 0,
  blue: 0,
);

/// The extraction result for one specimen. Show it in a dialog
/// ([showDialog], not dismissible): it closes itself from its own button.
class ExtractionResultCard extends StatefulWidget {
  const ExtractionResultCard({
    super.key,
    required this.species,
    required this.instance,
    required this.isNewDiscovery,
    required this.cinematicQuality,
    this.onDeferDiscoveryFlight,
  });

  /// The species as this specimen expresses it (its genetics and natures).
  final Creature species;
  final CreatureInstance instance;
  final bool isNewDiscovery;
  final CinematicQuality cinematicQuality;

  /// When set, a new discovery's card is captured and handed back INSTEAD of
  /// flying to the catalog. The batch ceremony uses this: flying on each card
  /// would switch sections partway through the run, which is what made the
  /// discovery animation play before the player had seen every specimen.
  final void Function(DiscoveryFlightCapture? capture)? onDeferDiscoveryFlight;

  @override
  State<ExtractionResultCard> createState() => _ExtractionResultCardState();
}

class _ExtractionResultCardState extends State<ExtractionResultCard> {
  // On the card's RepaintBoundary, so a new discovery can be snapshotted for
  // its filing-away flight into the catalog.
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'extraction-card-boundary');
  final EssenceReveal _reveal = EssenceReveal.once();
  final Object _soundOwner = Object();
  AudioController? _audio;

  /// The reveal waits on this so its landing can be put on the sound's lock.
  bool _hold = true;
  bool _revealed = false;
  bool _closing = false;
  Timer? _release;
  Timer? _failsafe;

  Creature get _species => widget.species;
  CreatureInstance get _instance => widget.instance;

  bool get _rare {
    final rarity = _species.rarity.toLowerCase();
    return widget.isNewDiscovery ||
        _instance.isPrismaticSkin == true ||
        _instance.mutation != null ||
        rarity == 'legendary' ||
        rarity == 'mystic';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  void _begin() {
    if (!mounted) return;
    _audio = context.audio;
    // The cue's grains land at a fixed point in it (REVEAL_LAND / RARE_LAND
    // in tool/sounds/extraction.py), so the reveal is timed to the sound
    // rather than the sound stretched to the reveal: a rare one gets a beat
    // of empty, lit stage first.
    final lockMs = _rare ? 1770 : 1200;
    context.sound(
      _rare ? SoundCue.extractionRareReveal : SoundCue.extractionCreatureReveal,
      owner: _soundOwner,
    );
    final lead = math.max(0, lockMs - _kRevealLandsMs);
    _release = Timer(Duration(milliseconds: lead), () {
      if (mounted) setState(() => _hold = false);
    });
    // The essence always reports back (it shows the sprite plainly if it
    // cannot read it), but the button must never depend on that.
    _failsafe = Timer(Duration(milliseconds: lead + 4000), _onRevealed);
  }

  void _onRevealed() {
    if (!mounted || _revealed) return;
    _failsafe?.cancel();
    setState(() => _revealed = true);
  }

  @override
  void dispose() {
    _release?.cancel();
    _failsafe?.cancel();
    _audio?.stopSoundOwner(_soundOwner);
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_closing) return;
    // Grabbed BEFORE the awaits. Looked up after the flight, this element can
    // be defunct (the shell switches tabs underneath it) and Navigator.of
    // throws, so the card flew and the result just sat there.
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    try {
      unawaited(
        context.read<AlchemonsDatabase>().settingsDao.setSetting(
          'nav_locked_until_extraction_ack',
          '0',
        ),
      );
    } catch (_) {}
    setState(() => _closing = true);

    // A new species flies into the catalog; everything else comes apart
    // into its sand on the way out.
    var dissolve = true;
    if (widget.isNewDiscovery) {
      final defer = widget.onDeferDiscoveryFlight;
      if (defer != null) {
        // Captured while the card is still up; the batch flies them all once
        // every card has been seen.
        defer(
          await NewDiscoveryReveal.instance.captureCard(
            context: context,
            cardBoundaryKey: _cardKey,
          ),
        );
      } else {
        dissolve = false;
        await NewDiscoveryReveal.instance.playFilingAway(
          context: context,
          cardBoundaryKey: _cardKey,
          creatureId: _species.id,
        );
      }
    }

    if (dissolve && mounted) {
      // A frame for the card to hold still (its tickers are off now), so
      // the picture taken of it is the card as it stands.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        final mutation = AlchemonMutation.byId(_instance.mutation);
        final going = await CardDissolve.play(
          context: context,
          boundaryKey: _cardKey,
          element: _species.types.isEmpty ? null : _species.types.first,
          colour: _rimColour(mutation),
          barrier: kExtractionCardBarrier,
          reduced: widget.cinematicQuality == CinematicQuality.performance,
          seed: _instance.instanceId.hashCode,
        );
        // Not on the card's owner: that is stopped as the card goes.
        if (going && mounted) context.sound(SoundCue.extractionDissolve);
      }
    }

    if (route != null && route.isActive) {
      navigator.removeRoute(route);
    } else if (navigator.canPop()) {
      navigator.pop();
    }
  }

  RimColour _rimColour(AlchemonMutation? mutation) =>
      mutation == AlchemonMutation.transmuted
      ? RimColour.gilded
      : _instance.isPrismaticSkin == true
      ? RimColour.prismatic
      : RimColour.element;

  void _openDetails() {
    if (_closing) return;
    CreatureDetailsDialog.show(
      context,
      _species,
      true,
      instanceId: _instance.instanceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final fc = FC(theme);
    final tokens = ForgeTokens(theme);
    final reading = _Reading.of(
      context,
      species: _species,
      instance: _instance,
      isNewDiscovery: widget.isNewDiscovery,
      tokens: tokens,
    );
    final element = _species.types.isEmpty ? null : _species.types.first;
    final elementColor = element == null
        ? theme.accent
        : BreedConstants.getTypeColor(element);
    final palette = BracketPalette.fromTheme(theme);
    final mutation = AlchemonMutation.byId(_instance.mutation);
    final variant = _displayVariant(_instance.variantFaction);
    final size = MediaQuery.sizeOf(context);
    final cardW = size.width * 0.95;
    final cardH = size.height * 0.82;
    // The specimen on the left, its stats on the right: side by side they
    // leave the analysis below the room a full-width stage took from it.
    final topH = (cardH * 0.3).clamp(180.0, 260.0);
    final stageW = cardW * 0.5;
    final spriteBox = math.min(stageW, topH) * 0.86;
    // Where the stage's floor meets the card's left edge: the sand spills
    // from there. The header is about this tall.
    const headerH = 74.0;
    final stageLight = theme.isDark
        ? elementColor
        : tokens.readableAccent(elementColor);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: RepaintBoundary(
        key: _cardKey,
        child: TickerMode(
          // Closing: hold still for the capture.
          enabled: !_closing,
          // The border is the specimen's own sand, run off the stage and
          // settled round the edge once it has arrived.
          child: EssenceRim(
            element: element,
            pour: _revealed,
            colour: _rimColour(mutation),
            loose: mutation == AlchemonMutation.alchemized,
            looseLight: mutationAccent(AlchemonMutation.alchemized),
            fleck: variant == null ? null : FactionColors.of(variant),
            sourceY: ((headerH + topH * 0.82) / cardH).clamp(0.1, 0.9),
            seed: _instance.instanceId.hashCode,
            reduced: widget.cinematicQuality == CinematicQuality.performance,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: cardW,
                height: cardH,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _revealed ? 1.0 : 0.4),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, strength, child) => CustomPaint(
                    painter: _GlassPainter(
                      palette: palette,
                      light: stageLight,
                      strength: strength,
                      // The stage's centre, as a share of the card.
                      lightAt: Offset(
                        stageW / 2 / cardW,
                        (headerH + topH * 0.48) / cardH,
                      ),
                    ),
                    child: child,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(name: _species.name, fc: fc, palette: palette),
                      SizedBox(
                        height: topH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: stageW,
                              child: _Stage(
                                // A pale element's light vanishes into parchment;
                                // on the light theme it pools in its readable
                                // shade.
                                color: stageLight,
                                lit: _revealed,
                                child: SizedBox.square(
                                  dimension: spriteBox,
                                  child: ElementalEssence(
                                    key: ValueKey(_instance.instanceId),
                                    element: element,
                                    dark: theme.isDark,
                                    reveal: _reveal,
                                    hold: _hold,
                                    onRevealed: _onRevealed,
                                    maxGrains:
                                        widget.cinematicQuality ==
                                            CinematicQuality.performance
                                        ? 1400
                                        : 2200,
                                    child: Center(
                                      child: InstanceSprite(
                                        creature: _species,
                                        instance: _instance,
                                        size: spriteBox / _kMaxSizeGeneScale,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _StatProfile(
                                stats: reading.stats,
                                fc: fc,
                                palette: palette,
                                shown: _revealed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _FadeRule(color: palette.line),
                      if (reading.marks.isNotEmpty)
                        _Inscription(
                          marks: reading.marks,
                          palette: palette,
                          shown: _revealed,
                        ),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: _revealed ? 1 : 0,
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOut,
                          child: _AnalysisTabs(
                            reading: reading,
                            fc: fc,
                            palette: palette,
                          ),
                        ),
                      ),
                      _Dock(
                        fc: fc,
                        palette: palette,
                        shown: _revealed,
                        enabled: _revealed && !_closing,
                        onConfirm: _confirm,
                        onInfo: _openDetails,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's body: dark glass, with the light the specimen gives off
/// spreading from its stage across the card, faintly. It swells once the
/// specimen has arrived.
class _GlassPainter extends CustomPainter {
  const _GlassPainter({
    required this.palette,
    required this.light,
    required this.strength,
    required this.lightAt,
  });

  final BracketPalette palette;
  final Color light;
  final double strength;
  final Offset lightAt;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bg1, palette.bg0],
        ).createShader(rect),
    );
    final at = Offset(lightAt.dx * size.width, lightAt.dy * size.height);
    final r = size.width * 0.95;
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            light.withValues(alpha: 0.10 * strength),
            light.withValues(alpha: 0.035 * strength),
            light.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.palette != palette ||
      old.light != light ||
      old.strength != strength ||
      old.lightAt != lightAt;
}

/// A hairline that fades out at both ends.
class _FadeRule extends StatelessWidget {
  const _FadeRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

// ── what the card reads off the specimen ────────────────────────────────────

/// Something notable about the specimen, engraved at the foot of the stage.
@immutable
class _MarkData {
  const _MarkData(this.label, this.color, {this.prismatic = false});

  final String label;
  final Color color;
  final bool prismatic;
}

@immutable
class _StatData {
  const _StatData({
    required this.label,
    required this.color,
    required this.value,
    required this.potential,
    required this.dominant,
  });

  final String label;
  final Color color;
  final double value;

  /// Null without the Potential Analyzer: the figure is not theirs to read.
  final int? potential;

  /// One of the two stats it passes down, and the player can see that.
  final bool dominant;
}

/// Everything the card shows about the specimen, worked out once per build.
@immutable
class _Reading {
  const _Reading({
    required this.marks,
    required this.stats,
    required this.specimen,
    required this.genetics,
  });

  final List<_MarkData> marks;
  final List<_StatData> stats;
  final List<(String, String)> specimen;
  final List<(String, String)> genetics;

  factory _Reading.of(
    BuildContext context, {
    required Creature species,
    required CreatureInstance instance,
    required bool isNewDiscovery,
    required ForgeTokens tokens,
  }) {
    final effects = context.read<ConstellationEffectsService>();
    // Both figures are behind their analyzers everywhere else; this is the
    // first place a specimen's could ever be read, so it keeps the gates.
    final showPotential = effects.hasPotentialAnalyzer();
    final showDominants = effects.hasDominantAnalyzer();
    // Pre-Dominants creatures fall back to whatever they are best at.
    final dominants =
        DominantStats.decode(instance.dominantStats) ??
        DominantStats.fromPotentials(
          speed: instance.statSpeedPotential,
          intelligence: instance.statIntelligencePotential,
          strength: instance.statStrengthPotential,
          beauty: instance.statBeautyPotential,
        );
    final purity = classifyInstancePurity(instance, species: species);
    final notablePurity =
        purity.isPure || purity.isElementallyPure || purity.isSpeciesPure;
    final mutation = AlchemonMutation.byId(instance.mutation);
    final variant = _displayVariant(instance.variantFaction);
    final nature = _natureLabel(species);

    _StatData stat(
      StatKind kind,
      String label,
      Color color,
      double value,
      double potential,
    ) => _StatData(
      label: label,
      color: tokens.readableAccent(color),
      value: value,
      potential: showPotential
          ? AlchemonStatSystem.normalizePotential(potential)
          : null,
      dominant: showDominants && dominants.contains(kind),
    );

    return _Reading(
      marks: [
        if (isNewDiscovery)
          _MarkData(
            'NEW DISCOVERY',
            tokens.isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
          ),
        if (mutation != null)
          _MarkData(
            mutation.label.toUpperCase(),
            tokens.readableAccent(mutationAccent(mutation)),
          ),
        if (instance.isPrismaticSkin == true)
          const _MarkData('PRISMATIC', Color(0xFFE879F9), prismatic: true),
        if (variant != null)
          _MarkData(
            variant.toUpperCase(),
            tokens.readableAccent(FactionColors.of(variant)),
          ),
        if (notablePurity)
          _MarkData(
            purity.label.toUpperCase(),
            tokens.readableAccent(_purityColor(purity)),
          ),
      ],
      stats: [
        stat(
          StatKind.speed,
          'SPEED',
          const Color(0xFF0EA5E9),
          instance.statSpeed,
          instance.statSpeedPotential,
        ),
        stat(
          StatKind.intelligence,
          'INTELLIGENCE',
          const Color(0xFFA855F7),
          instance.statIntelligence,
          instance.statIntelligencePotential,
        ),
        stat(
          StatKind.strength,
          'STRENGTH',
          const Color(0xFFC0392B),
          instance.statStrength,
          instance.statStrengthPotential,
        ),
        stat(
          StatKind.beauty,
          'BEAUTY',
          const Color(0xFFF59E0B),
          instance.statBeauty,
          instance.statBeautyPotential,
        ),
      ],
      specimen: [
        ('CLASSIFICATION', species.rarity),
        ('TYPE', species.types.join(', ')),
        if (mutation != null) ('MUTATION', _mutationReading(mutation)),
        if (notablePurity) ('PURITY', purity.label),
        if (species.description.isNotEmpty) ('NOTES', species.description),
      ],
      genetics: [
        if (showDominants)
          (
            'DOMINANT',
            dominants.all.map((k) => k.label.toUpperCase()).join(' · '),
          ),
        ('SIZE VARIANT', _sizeName(species)),
        ('PIGMENTATION', _tintName(species)),
        // An Alchemon can carry two natures; both go on the one line.
        if (nature != null) ('BEHAVIOR', nature),
        if (variant != null) ('VARIANT FACTION', variant),
      ],
    );
  }
}

// ── header ──────────────────────────────────────────────────────────────────

/// What happened, small, over the specimen's name.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.fc, required this.palette});

  final String name;
  final FC fc;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EXTRACTION COMPLETE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.amber.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bracketText(
              context,
              23,
              palette.ink,
              weight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── stage ───────────────────────────────────────────────────────────────────

/// Where the specimen stands: its element's light behind it and pooled on
/// the floor under it, both gradients (never a ring). Turned up once it has
/// arrived.
class _Stage extends StatelessWidget {
  const _Stage({required this.color, required this.lit, required this.child});

  final Color color;
  final bool lit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: lit ? 1.0 : 0.45),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, strength, child) => CustomPaint(
        painter: _StageLightPainter(color: color, strength: strength),
        child: child,
      ),
      child: Center(child: child),
    );
  }
}

class _StageLightPainter extends CustomPainter {
  const _StageLightPainter({required this.color, required this.strength});

  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    // Not clipped: with no frame round the stage any more, a clipped light
    // showed its edge. It fades out a little past the stage instead.
    final k = strength;

    // The light it gives off, behind it.
    final back = Offset(size.width / 2, size.height * 0.46);
    final backR = math.min(size.width, size.height) * 0.62;
    canvas.drawCircle(
      back,
      backR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.20 * k),
            color.withValues(alpha: 0.06 * k),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: back, radius: backR)),
    );

    // Pooled on the floor where it stands.
    final floor = Offset(size.width / 2, size.height * 0.86);
    final floorR = math.min(size.width * 0.38, 160.0);
    canvas.save();
    canvas.translate(floor.dx, floor.dy);
    canvas.scale(1, 0.2);
    canvas.drawCircle(
      Offset.zero,
      floorR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.42 * k),
            color.withValues(alpha: 0.12 * k),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: floorR)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StageLightPainter old) =>
      old.color != color || old.strength != strength;
}

/// The marks as one engraved line under the specimen and its stats: small
/// letterspaced capitals in muted ink, each after a small diamond of its own
/// colour. No boxes, no fills -- the colour is in the diamond, the words
/// stay quiet.
class _Inscription extends StatelessWidget {
  const _Inscription({
    required this.marks,
    required this.palette,
    required this.shown,
  });

  final List<_MarkData> marks;
  final BracketPalette palette;

  /// Engraved once the specimen has arrived; the line's room is kept from
  /// the start so nothing moves when it is.
  final bool shown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Center(
            // A long set (all five) shrinks to fit rather than wrapping.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < marks.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    _Diamond(mark: marks[i]),
                    const SizedBox(width: 7),
                    Text(
                      marks[i].label,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Diamond extends StatelessWidget {
  const _Diamond({required this.mark});

  final _MarkData mark;

  static const _prism = [
    Color(0xFFF87171),
    Color(0xFFFBBF24),
    Color(0xFF4ADE80),
    Color(0xFF22D3EE),
    Color(0xFF818CF8),
    Color(0xFFE879F9),
    Color(0xFFF87171),
  ];

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: mark.prismatic ? null : mark.color,
          gradient: mark.prismatic ? const SweepGradient(colors: _prism) : null,
        ),
      ),
    );
  }
}

// ── stat profile ────────────────────────────────────────────────────────────

class _StatProfile extends StatelessWidget {
  const _StatProfile({
    required this.stats,
    required this.fc,
    required this.palette,
    required this.shown,
  });

  final List<_StatData> stats;
  final FC fc;
  final BracketPalette palette;

  /// The figures come in once the specimen has arrived; the labels are
  /// there from the start, so nothing moves when they do.
  final bool shown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'STAT PROFILE',
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'monospace',
              color: palette.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.line.withValues(alpha: 0.7),
                  palette.line.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          // The pane is as tall as the stage beside it. The rows share that
          // height, and at a large font they shrink together rather than
          // spill out of it.
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: box.maxWidth,
                  height: math.max(box.maxHeight, 4 * 26.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final stat in stats)
                        _StatRow(
                          data: stat,
                          fc: fc,
                          palette: palette,
                          shown: shown,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stat's name, its rating, and its Potential as a number when the
/// Potential Analyzer is unlocked -- otherwise nothing at all.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.data,
    required this.fc,
    required this.palette,
    required this.shown,
  });

  final _StatData data;
  final FC fc;
  final BracketPalette palette;
  final bool shown;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final p = d.potential;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              d.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                color: d.dominant ? fc.dominant : palette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 380),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${AlchemonStatSystem.displayRating(d.value)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: d.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (p != null) ...[
                  const SizedBox(width: 7),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.muted.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        const TextSpan(text: 'P '),
                        TextSpan(
                          text: '$p',
                          style: TextStyle(
                            color: _potentialTierColor(p),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _potentialTierColor(int potential) {
  if (potential <= 20) return const Color(0xFFC0392B);
  if (potential <= 40) return const Color(0xFFF97316);
  if (potential <= 60) return const Color(0xFFF59E0B);
  if (potential <= 80) return const Color(0xFF22C55E);
  return const Color(0xFFA855F7);
}

// ── analysis ────────────────────────────────────────────────────────────────

/// SPECIMEN and GENETICS, a swipe or a tap apart.
class _AnalysisTabs extends StatefulWidget {
  const _AnalysisTabs({
    required this.reading,
    required this.fc,
    required this.palette,
  });

  final _Reading reading;
  final FC fc;
  final BracketPalette palette;

  @override
  State<_AnalysisTabs> createState() => _AnalysisTabsState();
}

class _AnalysisTabsState extends State<_AnalysisTabs> {
  double _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (tabContext) {
          final controller = DefaultTabController.of(tabContext);
          return Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => BracketTabs(
                    labels: const ['SPECIMEN', 'GENETICS'],
                    selected: controller.index,
                    onSelect: controller.animateTo,
                    palette: palette,
                    accent: widget.fc.amber,
                  ),
                ),
              ),
              Expanded(
                // The panels scroll vertically, so the swipe between them is
                // read off the raw pointer rather than fought for by a
                // horizontal scroll view.
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _dragDx = 0,
                  onPointerMove: (e) => _dragDx += e.delta.dx,
                  onPointerCancel: (_) => _dragDx = 0,
                  onPointerUp: (_) {
                    final dx = _dragDx;
                    _dragDx = 0;
                    if (dx.abs() < 32) return;
                    final target = (controller.index + (dx < 0 ? 1 : -1)).clamp(
                      0,
                      controller.length - 1,
                    );
                    if (target != controller.index) {
                      controller.animateTo(target);
                    }
                  },
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _AnalysisPanel(
                        rows: widget.reading.specimen,
                        palette: palette,
                      ),
                      _AnalysisPanel(
                        rows: widget.reading.genetics,
                        palette: palette,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalysisPanel extends StatelessWidget {
  const _AnalysisPanel({required this.rows, required this.palette});

  final List<(String, String)> rows;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows)
            _AnalysisRow(label: label, value: value, palette: palette),
        ],
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    // The notes are prose: the book's hand, a little quieter.
    final prose = label == 'NOTES';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: palette.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: bracketText(
                context,
                prose ? 14 : 15,
                prose ? palette.ink.withValues(alpha: 0.8) : palette.ink,
                fontStyle: prose ? FontStyle.italic : FontStyle.normal,
              ).copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── docked confirm ──────────────────────────────────────────────────────────

class _Dock extends StatelessWidget {
  const _Dock({
    required this.fc,
    required this.palette,
    required this.shown,
    required this.enabled,
    required this.onConfirm,
    required this.onInfo,
  });

  final FC fc;
  final BracketPalette palette;
  final bool shown;
  final bool enabled;
  final VoidCallback onConfirm;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Clear of the sand banked along the foot.
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !enabled,
          child: Row(
            children: [
              Expanded(
                child: BracketButton(
                  label: 'CONTINUE',
                  onTap: onConfirm,
                  palette: palette,
                  accent: fc.amber,
                  height: 48,
                ),
              ),
              const SizedBox(width: 10),
              BracketIconButton(
                icon: AppIcons.info_outline_rounded,
                onTap: onInfo,
                palette: palette,
                size: 48,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── readings ────────────────────────────────────────────────────────────────

/// Both natures on one line. Two separate rows would read as a duplicate
/// rather than as a pair.
String? _natureLabel(Creature creature) {
  final parts = <String>[
    if (creature.nature != null) creature.nature!.id,
    if (creature.nature2 != null) creature.nature2!.id,
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

String? _displayVariant(String? faction) {
  final trimmed = faction?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

/// What a mutated specimen reads as: the name, and what it means to look at.
String _mutationReading(AlchemonMutation m) => switch (m) {
  AlchemonMutation.alchemized => 'Alchemized: made of grains that never settle',
  AlchemonMutation.transmuted => 'Transmuted: turned to gold',
};

Color _purityColor(InstancePurityStatus purity) {
  if (purity.isPure) return const Color(0xFF4ADE80);
  if (purity.isElementallyPure) return const Color(0xFF22D3EE);
  if (purity.isSpeciesPure) return const Color(0xFFFBBF24);
  return const Color(0xFFFDBA74);
}

String _sizeName(Creature c) =>
    sizeLabels[c.genetics?.get('size') ?? 'normal'] ?? 'Standard';

String _tintName(Creature c) =>
    tintLabels[c.genetics?.get('tinting') ?? 'normal'] ?? 'Standard';
