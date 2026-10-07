part of 'battle_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE BATTLE SHEET — the creature fighting, and what its stats make of it
//
//  Built like the Customization Lab: a live stage at the top (the creature
//  in the practice arena, firing on its real timings), its two attacks, its
//  four stats as chips, its combat numbers as gauges, and one dock that
//  explains whatever was picked. Picking a stat lights the gauges it feeds;
//  picking the special fires it on the stage.
// ─────────────────────────────────────────────────────────────────────────────

/// What the dock is explaining.
enum _PickKind { stat, auto, special }

/// The combat numbers the gauges show, in order.
const _kGaugeOutputs = [
  AlchemonCombatOutput.hp,
  AlchemonCombatOutput.physAtk,
  AlchemonCombatOutput.special,
  AlchemonCombatOutput.elemAtk,
  AlchemonCombatOutput.physDef,
  AlchemonCombatOutput.elemDef,
  AlchemonCombatOutput.range,
];

String _gaugeLabel(AlchemonCombatOutput o) => switch (o) {
  AlchemonCombatOutput.hp => 'HP',
  AlchemonCombatOutput.physAtk => 'P-ATK',
  AlchemonCombatOutput.special => 'SPECIAL',
  AlchemonCombatOutput.elemAtk => 'E-ATK',
  AlchemonCombatOutput.physDef => 'P-DEF',
  AlchemonCombatOutput.elemDef => 'E-DEF',
  AlchemonCombatOutput.range => 'RANGE',
  AlchemonCombatOutput.attackInterval => 'ATTACKS',
  AlchemonCombatOutput.specialInterval => 'RECHARGE',
};

double _gaugeValue(AlchemonCombatStats s, AlchemonCombatOutput o) =>
    switch (o) {
      AlchemonCombatOutput.hp => s.maxHp.toDouble(),
      AlchemonCombatOutput.physAtk => s.physAtk.toDouble(),
      AlchemonCombatOutput.special => s.abilityAtk.toDouble(),
      AlchemonCombatOutput.elemAtk => s.elemAtk.toDouble(),
      AlchemonCombatOutput.physDef => s.physDef.toDouble(),
      AlchemonCombatOutput.elemDef => s.elemDef.toDouble(),
      AlchemonCombatOutput.range => s.attackRange,
      _ => 0,
    };

/// The numbers a perfected creature of [family] would have: top species
/// base, level 10, Potential 100. The gauges measure against it, so a full
/// bar means "as good as this family gets" (Enhancement can push past it).
final Map<String, AlchemonCombatStats> _perfectCache = {};
AlchemonCombatStats _perfectStats(String family) =>
    _perfectCache.putIfAbsent(family.toLowerCase(), () {
      const p = kAbilityStatPerfect;
      return deriveAlchemonCombatStats(
        member: CosmicPartyMember(
          instanceId: 'perfect',
          baseId: 'perfect',
          displayName: 'Perfect',
          element: 'Fire',
          family: family,
          level: CosmicBalance.maxCompanionLevel,
          statSpeed: p,
          statIntelligence: p,
          statStrength: p,
          statBeauty: p,
          slotIndex: 0,
          staminaBars: 1,
          staminaMax: 1,
        ),
      );
    });

class _BattleSheet extends StatefulWidget {
  const _BattleSheet({
    required this.instance,
    required this.creature,
    required this.family,
    required this.element,
    required this.liveStage,
  });

  final CreatureInstance instance;
  final Creature creature;
  final String family;
  final String element;
  final bool liveStage;

  @override
  State<_BattleSheet> createState() => _BattleSheetState();
}

class _BattleSheetState extends State<_BattleSheet> {
  AbilityPreviewGame? _game;
  bool _stageVisible = true;

  /// Off when the details' Battle tab is not the one showing: the tab is
  /// kept alive, and a Flame loop does not listen to TickerMode by itself.
  bool _tickersOn = true;
  _PickKind _kind = _PickKind.stat;
  AlchemonStat? _stat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickersOn = TickerMode.valuesOf(context).enabled;
    if (tickersOn != _tickersOn) {
      _tickersOn = tickersOn;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncEngine());
    }
    if (widget.liveStage && _game == null) {
      final game = AbilityPreviewGame(
        member: _summonedMember(context),
        homeZoom: _kStageZoom,
        followCompanion: true,
      );
      // Paused before it mounts: a GameWidget starts its loop the moment it
      // attaches, and the stage only runs once it is on screen.
      game.pauseEngine();
      _game = game;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncEngine());
    }
  }

  void _syncEngine() {
    final game = _game;
    if (game == null || !mounted) return;
    if (_stageVisible && _tickersOn) {
      game.resumeEngine();
    } else {
      game.pauseEngine();
    }
  }

  /// The creature as a summoned companion: constellation bonuses applied,
  /// its own sheet and visuals.
  CosmicPartyMember _summonedMember(BuildContext context) {
    final bonuses = context.read<ConstellationEffectsService>();
    final i = widget.instance;
    return CosmicPartyMember(
      instanceId: 'preview_${i.instanceId}',
      baseId: i.baseId,
      displayName: i.nickname ?? widget.creature.name,
      imagePath: 'assets/images/${widget.creature.image}',
      element: widget.element,
      family: widget.family,
      level: i.level,
      statSpeed: bonuses.applyCombatStatBonus('speed', i.statSpeed),
      statIntelligence: bonuses.applyCombatStatBonus(
        'intelligence',
        i.statIntelligence,
      ),
      statStrength: bonuses.applyCombatStatBonus('strength', i.statStrength),
      statBeauty: bonuses.applyCombatStatBonus('beauty', i.statBeauty),
      statSpeedPotential: i.statSpeedPotential,
      statIntelligencePotential: i.statIntelligencePotential,
      statStrengthPotential: i.statStrengthPotential,
      statBeautyPotential: i.statBeautyPotential,
      slotIndex: 0,
      staminaBars: 3,
      staminaMax: 3,
      spriteSheet: widget.creature.spriteData != null
          ? sheetFromCreature(widget.creature)
          : null,
      spriteVisuals: visualsFromInstance(widget.creature, widget.instance),
    );
  }

  Future<void> _openFullPreview(
    _CosmicBasicInfo basic,
    CosmicSpecialInfo special,
    String specialName,
  ) async {
    // Two arenas would run at once: the full view covers this one.
    _game?.pauseEngine();
    await AbilityPreviewScreen.open(
      context,
      AbilityPreviewSubject(
        member: _summonedMember(context),
        autoAttackName: basic.name,
        autoAttackDescription: basic.description,
        autoAttackIcon: basic.icon,
        specialName: specialName,
        specialSubtitle: special.subtitle,
        specialDescription: special.description,
        specialIcon: special.icon,
        accent: _elementAccentColor(widget.element),
      ),
    );
    if (mounted) _syncEngine();
  }

  void _pick(_PickKind kind, {AlchemonStat? stat}) {
    HapticFeedback.selectionClick();
    setState(() {
      _kind = kind;
      if (stat != null) _stat = stat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.family;
    final element = widget.element;
    final accent = _elementAccentColor(element);
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final readable = bracketReadableAccent(theme, color: accent);
    final bonuses = context.watch<ConstellationEffectsService>();
    final i = widget.instance;
    final ratings = {
      AlchemonStat.strength: bonuses.applyCombatStatBonus(
        'strength',
        i.statStrength,
      ),
      AlchemonStat.intelligence: bonuses.applyCombatStatBonus(
        'intelligence',
        i.statIntelligence,
      ),
      AlchemonStat.beauty: bonuses.applyCombatStatBonus('beauty', i.statBeauty),
      AlchemonStat.speed: bonuses.applyCombatStatBonus('speed', i.statSpeed),
    };
    final best = ratings.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    final stat = _stat ?? best;

    final stats = deriveAlchemonCombatStats(
      member: CosmicPartyMember(
        instanceId: i.instanceId,
        baseId: i.baseId,
        displayName: i.nickname ?? i.baseId,
        element: element,
        family: family,
        level: i.level,
        statStrength: ratings[AlchemonStat.strength]!,
        statIntelligence: ratings[AlchemonStat.intelligence]!,
        statBeauty: ratings[AlchemonStat.beauty]!,
        statSpeed: ratings[AlchemonStat.speed]!,
        slotIndex: 0,
        staminaBars: i.staminaBars,
        staminaMax: i.staminaMax,
      ),
    );
    final perfect = _perfectStats(family);
    final feeds = alchemonStatFeeds(family);
    final attackEvery = alchemonBasicAttackInterval(
      family: family,
      element: element,
      cooldownReduction: stats.cooldownReduction,
      physAtk: stats.physAtk,
    );
    final specialEvery = alchemonSpecialInterval(
      family: family,
      element: element,
      specialCooldownReduction: stats.specialCooldownReduction,
      abilityAtk: stats.abilityAtk,
    );
    final passive = isPassiveOnlyCosmicAbility(family, element);
    final role = _cosmicFamilyRole(family);
    final basic = _cosmicFamilyBasicInfo(family, element);
    final special = cosmicFamilySpecialInfo(family, element);
    final specialName = cosmicSpecialAbilityName(family, element);
    final boosts = _CombatBoostsCard.entriesFor(
      context,
      instance: i,
      creature: widget.creature,
      family: family,
    );

    // Which gauges the pick lights.
    bool lit(AlchemonCombatOutput o) => switch (_kind) {
      _PickKind.stat => feeds[o]!.containsKey(stat),
      _PickKind.auto =>
        o == AlchemonCombatOutput.physAtk || o == AlchemonCombatOutput.elemAtk,
      _PickKind.special => o == AlchemonCombatOutput.special,
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleLine(role: role, family: family, accent: readable),
          const SizedBox(height: 10),
          ViewportTickerGate(
            onVisibilityChanged: (visible) {
              _stageVisible = visible;
              _syncEngine();
            },
            child: _BattleStage(
              game: _game,
              accent: readable,
              onOpen: () => _openFullPreview(basic, special, specialName),
            ),
          ),
          const SizedBox(height: 10),
          _AbilityLine(
            kind: 'AUTO ATTACK',
            name: basic.name,
            icon: basic.icon,
            cadence: 'every ${_seconds(attackEvery)}',
            accent: readable,
            selected: _kind == _PickKind.auto,
            onTap: () => _pick(_PickKind.auto),
          ),
          const SizedBox(height: 6),
          _AbilityLine(
            kind: 'SPECIAL',
            name: specialName,
            icon: special.icon,
            cadence: passive ? 'passive' : 'every ${_seconds(specialEvery)}',
            accent: readable,
            selected: _kind == _PickKind.special,
            charge: passive ? null : _game,
            onTap: () {
              _pick(_PickKind.special);
              // Try it on the stage, when it is ready to go.
              final game = _game;
              if (!passive && game != null && game.specialReady) {
                game.castSpecial();
              }
            },
          ),
          const SizedBox(height: 16),
          _SheetHeader(
            'WHAT ITS STATS DO',
            trailing: 'tap one',
            palette: palette,
          ),
          Row(
            children: [
              for (final s in AlchemonStat.values) ...[
                if (s != AlchemonStat.values.first) const SizedBox(width: 6),
                Expanded(
                  child: _StatChip(
                    stat: s,
                    rating: ratings[s]!,
                    best: s == best,
                    selected: _kind == _PickKind.stat && s == stat,
                    accent: readable,
                    onTap: () => _pick(_PickKind.stat, stat: s),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final o in _kGaugeOutputs)
            _PowerGauge(
              label: _gaugeLabel(o),
              source: _gaugeSource(
                feeds[o]!,
                _kind == _PickKind.stat ? stat : null,
              ),
              value: _gaugeValue(stats, o),
              reference: _gaugeValue(perfect, o),
              accent: readable,
              lit: lit(o),
            ),
          const SizedBox(height: 10),
          _PickDock(
            accent: readable,
            child: switch (_kind) {
              _PickKind.stat => _StatDock(
                stat: stat,
                rating: ratings[stat]!,
                best: stat == best,
                family: family,
                ratings: ratings,
                stats: stats,
                attackEvery: attackEvery,
                raisedBy: _statBoostSources(context, stat),
                accent: readable,
              ),
              _PickKind.auto => _AbilityDock(
                title: basic.name,
                subtitle: 'Auto attack · every ${_seconds(attackEvery)}',
                description: basic.description,
                extraLines: const [
                  CosmicAbilityDescriptionLine(
                    label: 'Power',
                    body: 'P-ATK per hit, from Strength.',
                  ),
                  CosmicAbilityDescriptionLine(
                    label: 'Rate',
                    body: 'Speed; Strength too, until P-ATK reaches 41.',
                  ),
                ],
                accent: readable,
              ),
              _PickKind.special => _AbilityDock(
                title: specialName,
                subtitle: passive
                    ? special.subtitle
                    : '${special.subtitle} · every ${_seconds(specialEvery)}',
                description: special.description,
                extraLines: _specialScalingLines(family),
                accent: readable,
              ),
            },
          ),
          const SizedBox(height: 8),
          Text(
            'The same numbers in Survival, planet dungeons and Cosmic Space. '
            'Bars measure against a perfected ${family.toLowerCase()}. '
            'Survival\'s Guardian upgrades and run pickups add to them.',
            style: bracketText(context, 11, palette.muted),
            strutStyle: const StrutStyle(height: 1.35),
          ),
          if (boosts.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SheetHeader('BOOSTS', palette: palette),
            _CombatBoostsCard(entries: boosts),
          ],
        ],
      ),
    );
  }

  /// Where this creature's [stat] is raised beyond its species and level.
  List<String> _statBoostSources(BuildContext context, AlchemonStat stat) {
    final key = switch (stat) {
      AlchemonStat.strength => kStatStrength,
      AlchemonStat.intelligence => kStatIntelligence,
      AlchemonStat.beauty => kStatBeauty,
      AlchemonStat.speed => kStatSpeed,
    };
    final i = widget.instance;
    final sources = <String>[];
    for (final id in {i.natureId, i.natureId2}) {
      if (id == null || id.isEmpty) continue;
      final bonus =
          NatureCatalog.byId(
            id,
          )?.effect.getDouble('stat_${key}_bonus', fallback: 0) ??
          0;
      if (bonus != 0) sources.add('Nature $id ${_signedPercent(bonus)}');
    }
    final rank = switch (stat) {
      AlchemonStat.strength => i.statStrengthEnhancement,
      AlchemonStat.intelligence => i.statIntelligenceEnhancement,
      AlchemonStat.beauty => i.statBeautyEnhancement,
      AlchemonStat.speed => i.statSpeedEnhancement,
    };
    if (rank > 0) {
      sources.add(
        'Enhancement +${(rank * AlchemonStatSystem.enhancementBonusPerRank * 100).round()}%',
      );
    }
    final purity = classifyInstancePurity(i, species: widget.creature);
    final purityBonus = resolvePurityStatBonus(
      instanceId: i.instanceId,
      isElementallyPure: purity.isElementallyPure,
      isSpeciesPure: purity.isSpeciesPure,
    );
    if (!purityBonus.isNone && purityBonus.statKey == key) {
      sources.add('Purity +${(purityBonus.bonus * 100).round()}%');
    }
    final constellation = context
        .read<ConstellationEffectsService>()
        .getCombatStatBonusPercent(key);
    if (constellation > 0) sources.add('Constellation +$constellation%');
    return sources;
  }
}

/// How close the stage's camera sits: the Alchemon at its centre, big enough
/// to read, with the practice bodies round it in frame.
const double _kStageZoom = 0.68;
const double _kStageHeight = 220;

/// The stats behind a gauge; with a stat picked, that stat's share of it.
String _gaugeSource(Map<AlchemonStat, double?> feeds, AlchemonStat? picked) {
  if (picked != null && feeds.containsKey(picked)) {
    final share = feeds[picked];
    return share == null || share >= 0.999
        ? _statAbbrev(picked)
        : '${_statAbbrev(picked)} ${(share * 100).round()}%';
  }
  return _feedSource(feeds);
}

class _RoleLine extends StatelessWidget {
  const _RoleLine({
    required this.role,
    required this.family,
    required this.accent,
  });

  final _CosmicFamilyRole role;
  final String family;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final copy = FamilyCombatCopy.forName(family);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role.title.toUpperCase(),
          style: bracketText(
            context,
            13,
            accent,
            weight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        if (copy != null) ...[
          const SizedBox(height: 3),
          Text(
            '${copy.targets} ${copy.position}',
            style: bracketText(context, 11.5, palette.muted),
            strutStyle: const StrutStyle(height: 1.3),
          ),
        ],
      ],
    );
  }
}

/// The creature in the practice arena, firing on its real timings. Tap for
/// the full view.
class _BattleStage extends StatelessWidget {
  const _BattleStage({
    required this.game,
    required this.accent,
    required this.onOpen,
  });

  final AbilityPreviewGame? game;
  final Color accent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final g = game;
    return Semantics(
      button: true,
      label: 'Watch it fight, full screen',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: SizedBox(
          height: _kStageHeight,
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: accent.withValues(alpha: 0.75),
              bracketSize: 12,
              strokeWidth: 1.3,
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF080808)),
                  if (g != null) IgnorePointer(child: GameWidget(game: g)),
                  Positioned(
                    right: 8,
                    bottom: 7,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC080808),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.55),
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'FULL VIEW',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: accent,
                                fontSize: 9,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two attacks: what kind, its name, how often.
class _AbilityLine extends StatelessWidget {
  const _AbilityLine({
    required this.kind,
    required this.name,
    required this.icon,
    required this.cadence,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.charge,
  });

  final String kind;
  final String name;
  final IconData icon;
  final String cadence;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  /// The stage's game, for the special's live charge; null shows none.
  final AbilityPreviewGame? charge;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: selected ? palette.accentWash(accent) : palette.surfaceFill(),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.8)
                : palette.line.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: palette.isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind,
                    style: bracketText(
                      context,
                      9.5,
                      palette.muted,
                      weight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      14.5,
                      palette.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (charge != null) ...[
              _SpecialCharge(game: charge!, accent: accent),
              const SizedBox(width: 8),
            ],
            Text(
              cadence,
              style: bracketText(
                context,
                11.5,
                palette.ink.withValues(alpha: 0.85),
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The special's charge on the stage, read off the game a few times a
/// second while it runs.
class _SpecialCharge extends StatefulWidget {
  const _SpecialCharge({required this.game, required this.accent});

  final AbilityPreviewGame game;
  final Color accent;

  @override
  State<_SpecialCharge> createState() => _SpecialChargeState();
}

class _SpecialChargeState extends State<_SpecialCharge> {
  Timer? _timer;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || widget.game.paused || !widget.game.isLoaded) return;
      final p = widget.game.specialProgress;
      if ((p - _progress).abs() > 0.01) setState(() => _progress = p);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _ChargeRingPainter(
          progress: _progress,
          color: widget.accent,
          track: palette.line.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _ChargeRingPainter extends CustomPainter {
  _ChargeRingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 1.5;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = track,
    );
    if (progress >= 0.999) {
      canvas.drawCircle(c, r - 2.6, Paint()..color = color);
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.butt
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ChargeRingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.title, {required this.palette, this.trailing});

  final String title;
  final String? trailing;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: bracketText(
              context,
              10.5,
              palette.muted,
              weight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: palette.line.withValues(alpha: 0.4),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(
              trailing!.toUpperCase(),
              style: bracketText(
                context,
                9.5,
                palette.muted.withValues(alpha: 0.8),
                weight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One of the four stats: its rating, picked to see what it feeds.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.stat,
    required this.rating,
    required this.best,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AlchemonStat stat;
  final double rating;
  final bool best;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${_statName(stat)} ${AlchemonStatSystem.displayRating(rating)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? palette.accentWash(accent, darkAlpha: 0.2, lightAlpha: 0.12)
                : palette.surfaceFill(),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.85)
                  : palette.line.withValues(alpha: 0.5),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                _statAbbrev(stat),
                style: bracketText(
                  context,
                  10,
                  selected ? accent : palette.muted,
                  weight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${AlchemonStatSystem.displayRating(rating)}',
                style: bracketText(
                  context,
                  15,
                  palette.ink,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                best ? 'BEST' : ' ',
                style: bracketText(
                  context,
                  8.5,
                  accent,
                  weight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A combat number as a ten-cell gauge against a perfected creature of the
/// family, with the stats it comes from. Lit when the pick feeds it.
class _PowerGauge extends StatelessWidget {
  const _PowerGauge({
    required this.label,
    required this.source,
    required this.value,
    required this.reference,
    required this.accent,
    required this.lit,
  });

  final String label;
  final String source;
  final double value;
  final double reference;
  final Color accent;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final fraction = reference <= 0 ? 0.0 : value / reference;
    final dim = lit ? 1.0 : 0.38;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: dim,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                label,
                maxLines: 1,
                style: bracketText(
                  context,
                  10.5,
                  lit ? accent : palette.muted,
                  weight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            SizedBox(
              width: 62,
              child: Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: bracketText(
                  context,
                  9,
                  palette.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 7,
                child: CustomPaint(
                  painter: _CellGaugePainter(
                    fraction: fraction,
                    color: lit ? accent : palette.ink.withValues(alpha: 0.7),
                    track: palette.line.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${value.round()}',
                textAlign: TextAlign.right,
                style: bracketText(
                  context,
                  12,
                  palette.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ten cells, lit as far as the gauge is full, the last lit one only partly.
/// Past full (an Enhancement can carry a stat beyond a perfected one) the
/// last cell takes a bright edge.
class _CellGaugePainter extends CustomPainter {
  _CellGaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 10;
    const gap = 2.0;
    final w = (size.width - gap * (cells - 1)) / cells;
    final f = fraction.clamp(0.0, 1.0);
    final dim = Paint()..color = track;
    final lit = Paint();
    for (var i = 0; i < cells; i++) {
      final x = i * (w + gap);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), dim);
      final fill = (f * cells - i).clamp(0.0, 1.0);
      if (fill > 0) {
        lit.color = color.withValues(alpha: 0.55 + 0.45 * fill);
        canvas.drawRect(Rect.fromLTWH(x, 0, w * fill, size.height), lit);
      }
    }
    if (fraction > 1.0) {
      canvas.drawRect(
        Rect.fromLTWH(size.width - 2, -2, 2, size.height + 4),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_CellGaugePainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// The dock: one card that explains whatever was picked.
class _PickDock extends StatelessWidget {
  const _PickDock({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.6),
        bracketSize: 8,
      ),
      child: Container(
        color: palette.accentWash(accent, darkAlpha: 0.07, lightAlpha: 0.05),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

class _StatDock extends StatelessWidget {
  const _StatDock({
    required this.stat,
    required this.rating,
    required this.best,
    required this.family,
    required this.ratings,
    required this.stats,
    required this.attackEvery,
    required this.raisedBy,
    required this.accent,
  });

  final AlchemonStat stat;
  final double rating;
  final bool best;
  final String family;
  final Map<AlchemonStat, double> ratings;
  final AlchemonCombatStats stats;
  final double attackEvery;
  final List<String> raisedBy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final feeds = _statFeedsList(
      stat: stat,
      family: family,
      ratings: ratings,
      stats: stats,
      attackEvery: attackEvery,
    );
    return Column(
      key: ValueKey(stat),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_statName(stat).toUpperCase()} · ${AlchemonStatSystem.displayRating(rating)}${best ? ' · BEST' : ''}',
          style: bracketText(
            context,
            12,
            accent,
            weight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          feeds.isEmpty
              ? 'Nothing in a ${family.toLowerCase()}\'s fight.'
              : _capitalized(feeds.join(' · ')),
          style: bracketText(
            context,
            12.5,
            palette.ink,
            weight: FontWeight.w500,
          ),
          strutStyle: const StrutStyle(height: 1.4),
        ),
        if (raisedBy.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Raised by ${raisedBy.join(' · ')}',
            style: bracketText(context, 11.5, palette.muted),
          ),
        ],
      ],
    );
  }
}

String _capitalized(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// What [stat] feeds, in words, with this creature's numbers where one
/// number tells the story — from the shared stat contract.
List<String> _statFeedsList({
  required AlchemonStat stat,
  required String family,
  required Map<AlchemonStat, double> ratings,
  required AlchemonCombatStats stats,
  required double attackEvery,
}) {
  final feeds = alchemonStatFeeds(family);
  bool has(AlchemonCombatOutput o) => feeds[o]!.containsKey(stat);
  String share(AlchemonCombatOutput o) {
    final w = feeds[o]![stat];
    return w == null ? '' : ' ${(w * 100).round()}%';
  }

  final strengthMaxed = alchemonBasicAttackPowerFactor(stats.physAtk) >= 3.0;
  // Cadence counts from a weak creature's stat (kAbilityStatLow, 250):
  // below it, raising these does not change the timing yet. A Mystic's
  // recharge stats count only once they beat an average one (350).
  final speedCounts = ratings[AlchemonStat.speed]! > kAbilityStatLow;
  final rechargeFloor = family.toLowerCase() == 'mystic'
      ? 3.5
      : kAbilityStatLow;
  final rechargeCounts =
      cosmicFamilySpecialCooldownStat(
        family: family,
        speed: ratings[AlchemonStat.speed]!,
        intelligence: ratings[AlchemonStat.intelligence]!,
        strength: ratings[AlchemonStat.strength]!,
      ) >
      rechargeFloor;
  // A Mystic's recharge bottoms out at 60s; once SPECIAL has taken it
  // there, nothing else shortens it.
  final rechargeMaxed =
      family.toLowerCase() == 'mystic' &&
      alchemonSpecialInterval(
            family: family,
            element: 'Fire',
            specialCooldownReduction: stats.specialCooldownReduction,
            abilityAtk: stats.abilityAtk,
          ) <=
          60.0 + 1e-9;
  final rechargeNote = rechargeMaxed
      ? ' (maxed)'
      : rechargeCounts
      ? ''
      : ' (counts from ${AlchemonStatSystem.displayRating(rechargeFloor)})';
  return [
    if (has(AlchemonCombatOutput.physAtk))
      'auto-attack damage (P-ATK ${stats.physAtk})',
    if (has(AlchemonCombatOutput.elemAtk))
      'elemental effects (E-ATK ${stats.elemAtk})',
    if (has(AlchemonCombatOutput.special))
      'special power${share(AlchemonCombatOutput.special)}',
    if (has(AlchemonCombatOutput.hp)) 'HP',
    if (has(AlchemonCombatOutput.physDef) && has(AlchemonCombatOutput.elemDef))
      'both defences'
    else if (has(AlchemonCombatOutput.physDef))
      'P-DEF'
    else if (has(AlchemonCombatOutput.elemDef))
      'E-DEF',
    if (has(AlchemonCombatOutput.range)) 'reach (${stats.attackRange.round()})',
    if (stat == AlchemonStat.speed)
      'attack rate (every ${_seconds(attackEvery)}'
          '${speedCounts ? '' : ', counts from 250'})'
    else if (has(AlchemonCombatOutput.attackInterval))
      strengthMaxed ? 'attack rate (maxed)' : 'attack rate',
    if (feeds[AlchemonCombatOutput.specialInterval]![stat] != null)
      'special recharge${share(AlchemonCombatOutput.specialInterval)}'
          '$rechargeNote',
  ];
}

class _AbilityDock extends StatelessWidget {
  const _AbilityDock({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.extraLines,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String description;
  final List<CosmicAbilityDescriptionLine> extraLines;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Column(
      key: ValueKey(title),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: bracketText(context, 15, palette.ink, weight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: bracketText(
            context,
            11.5,
            palette.muted,
            weight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 9),
        _AbilityDescriptionText(
          description: description,
          extraLines: extraLines,
          accent: accent,
          textColor: palette.muted,
        ),
      ],
    );
  }
}
