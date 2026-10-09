part of 'feeding_screen.dart';

// The tray under the stage: XP · ORBS · SOULS, one page at a time. (In
// code the XP tray is [_Tray.kin]: spare Alchemons of the same species.)

/// Tall enough for the tallest page, so switching never reflows the stage.
const double _kTrayPageHeight = 150;

class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.trays,
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.child,
  });

  final List<_Tray> trays;
  final _Tray selected;
  final Map<_Tray, int> counts;
  final ValueChanged<_Tray> onSelect;
  final Widget child;

  static String _name(_Tray t) => switch (t) {
    _Tray.kin => 'XP',
    _Tray.orbs => 'ORBS',
    _Tray.souls => 'SOULS',
  };

  static Color _accent(_Tray t) => switch (t) {
    _Tray.kin => _kGold,
    _Tray.orbs => _kAccent,
    _Tray.souls => _kSoul,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trays.length > 1)
            BracketTabs(
              labels: [for (final t in trays) '${_name(t)}  ${counts[t] ?? 0}'],
              selected: trays.indexOf(selected),
              onSelect: (i) => onSelect(trays[i]),
              palette: _kPalette,
              accent: _accent(selected),
            )
          else
            // Kin alone: nothing to switch between, so a label, not a tab.
            Row(
              children: [
                Text(
                  'XP',
                  style: _mono(
                    11,
                    _kGold,
                    weight: FontWeight.w900,
                    spacing: 1.6,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${counts[_Tray.kin] ?? 0} SPARE',
                  style: _mono(10, _kPalette.muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(height: 1, color: _kPalette.lineSoft),
                ),
              ],
            ),
          const SizedBox(height: 10),
          SizedBox(height: _kTrayPageHeight, child: child),
        ],
      ),
    );
  }
}

extension _TrayPages on _FeedingScreenState {
  // ─────────────────────────────── KIN ───────────────────────────────

  Widget _buildKinPage(
    Creature creature,
    CreatureInstance inst,
    List<CreatureInstance> kin,
    int lockedKin,
  ) {
    final maxed = inst.level >= AlchemonStatSystem.maxLevel;
    final canRead = _canReadPotential;
    final Widget body;
    if (maxed) {
      body = _QuietNote(
        _orbsSeen ? 'Level 10. Orbs still raise its stats.' : 'Level 10.',
      );
    } else if (kin.isEmpty) {
      body = _QuietNote(
        'No other ${creature.name} to give'
        '${lockedKin > 0 ? ' · $lockedKin locked' : ''}',
      );
    } else {
      final order = _kin.toList();
      body = ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: kin.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final k = kin[i];
          final chosen = _kin.contains(k.instanceId);
          final key = _kinKeys.putIfAbsent(k.instanceId, GlobalKey.new);
          return AnimatedBuilder(
            animation: _pourController,
            builder: (context, child) {
              final pour = _pour;
              final gone = pour != null && chosen
                  ? pour.kinGone(
                      order.indexOf(k.instanceId),
                      _pourController.value,
                    )
                  : 0.0;
              return Opacity(opacity: 1 - gone, child: child);
            },
            child: _KinCard(
              key: key,
              creature: creature,
              instance: k,
              chosen: chosen,
              potentials: canRead
                  ? [
                      for (final t in AlchemicalPowerupType.values)
                        (
                          t.color,
                          AlchemonStatSystem.normalizePotential(
                            _FeedingScreenState._potentialValueOf(k, t),
                          ),
                        ),
                    ]
                  : null,
              onTap: () => _toggleKin(k.instanceId),
              onLongPress: () => showQuickInstanceDialog(
                context: context,
                theme: context.read<FactionTheme>(),
                creature: creature,
                instance: k,
              ),
            ),
          );
        },
      );
    }
    final n = _kin.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        const SizedBox(height: 10),
        BracketButton(
          label: n == 0 ? 'CHOOSE SPARES FOR XP' : 'SACRIFICE $n FOR XP',
          palette: _kPalette,
          accent: _kGold,
          enabled: n > 0 && !_busy && !maxed,
          onTap: () => _sacrifice(inst, creature),
        ),
      ],
    );
  }

  // ─────────────────────────────── ORBS ───────────────────────────────

  Widget _buildOrbPage(
    Creature creature,
    CreatureInstance inst,
    Map<String, int> inventory,
    int silver,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DRAG AN ORB ONTO ${creature.name.toUpperCase()}',
          textAlign: TextAlign.center,
          style: _mono(
            9.5,
            _kPalette.muted,
            weight: FontWeight.w700,
            spacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final type in AlchemicalPowerupType.values)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final rank = _FeedingScreenState._rankOf(inst, type);
                      final silverCost =
                          AlchemonStatSystem.enhancementSilverForNextRank(rank);
                      return _OrbTile(
                        key: type == AlchemicalPowerupType.speed
                            ? _firstOrbKey
                            : null,
                        type: type,
                        held: inventory[type.inventoryKey] ?? 0,
                        cost: AlchemonStatSystem.orbCostForNextRank(rank),
                        silverCost: silverCost,
                        silverShort: silver < silverCost,
                        maxed: rank >= AlchemonStatSystem.maxEnhancementRank,
                        usable: _canApplyOrb(inst, inventory, silver, type),
                        launching: _launchingType == type,
                        onDragStarted: () {
                          HapticFeedback.selectionClick();
                          _dismissDragHint();
                          _set(() {
                            _draggingType = type;
                            _draggingKind = _InfusionKind.orb;
                          });
                        },
                        onDragFinished: () {
                          if (!mounted) return;
                          _set(() {
                            _draggingType = null;
                            _draggingKind = null;
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── SOULS ───────────────────────────────

  Widget _buildSoulPage(CreatureInstance inst, int held, int silver) {
    final stat = _soulStat;
    final cost = stat == null ? 0 : _soulCost(inst, stat);
    final potential = stat == null ? 0 : _potentialOf(inst, stat);
    final maxed = stat != null && potential >= AlchemonStatSystem.maxPotential;
    final affordable = stat != null && silver >= cost;
    final ready = stat != null && held > 0 && !maxed && affordable && !_busy;
    final tint = stat?.color ?? _kSoul;
    final canRead = _canReadPotential;

    final String status;
    Color statusColor = _kPalette.muted;
    if (held == 0) {
      status = 'No Potential Souls held.';
    } else if (stat == null) {
      status = 'Choose a Potential.';
      statusColor = _kPalette.ink;
    } else if (maxed) {
      status = '${_short(stat)} Potential is at 100.';
    } else if (!affordable) {
      status = 'Needs ${formatCoins(cost)} Silver.';
      statusColor = _kDanger;
    } else if (_soulArmed) {
      status = 'Drag the soul onto it.';
      statusColor = tint;
    } else {
      status = canRead
          ? 'P$potential, raised for ${formatCoins(cost)} Silver.'
          : 'Raised for ${formatCoins(cost)} Silver.';
      statusColor = _kPalette.ink;
    }

    const orbSize = 70.0;
    final sphere = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, lerped, _) => AnimatedBuilder(
        animation: _soulSwapController,
        builder: (context, child) => Transform.scale(
          // Pinch in and back out: the soul re-forming as another stat.
          scale: 1 - 0.16 * math.sin(math.pi * _soulSwapController.value),
          child: child,
        ),
        child: PotentialSoulSphere(
          size: orbSize,
          tint: lerped ?? tint,
          animate: _soulArmed,
        ),
      ),
    );
    final soulColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _soulArmed ? 1 : 0.42,
          child: sphere,
        ),
        const SizedBox(height: 6),
        Text(
          '$held HELD',
          style: _mono(9.5, held > 0 ? _kPalette.ink : _kPalette.muted),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: orbSize + 10,
          child: !_soulArmed || stat == null
              ? soulColumn
              : Draggable<_InfusionPayload>(
                  data: _InfusionPayload(_InfusionKind.soul, stat),
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  onDragStarted: () {
                    HapticFeedback.selectionClick();
                    _set(() {
                      _draggingType = stat;
                      _draggingKind = _InfusionKind.soul;
                    });
                  },
                  onDragEnd: (d) {
                    if (!mounted) return;
                    if (!d.wasAccepted) HapticFeedback.lightImpact();
                    _set(() {
                      _draggingType = null;
                      _draggingKind = null;
                    });
                  },
                  feedback: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: PotentialSoulSphere(
                      size: orbSize * 1.18,
                      tint: tint,
                      animate: true,
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.18, child: soulColumn),
                  child: soulColumn,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final type in AlchemicalPowerupType.values) ...[
                    if (type.index > 0) const SizedBox(width: 6),
                    Expanded(child: _soulChip(inst, type, canRead)),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                status,
                maxLines: 2,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: ready ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !ready,
                  child: BracketButton(
                    label: _soulArmed ? 'CANCEL' : 'CONFIRM',
                    palette: _kPalette,
                    accent: tint,
                    primary: !_soulArmed,
                    height: 36,
                    onTap: () {
                      if (_soulArmed) {
                        HapticFeedback.selectionClick();
                      } else {
                        HapticFeedback.mediumImpact();
                      }
                      _set(() => _soulArmed = !_soulArmed);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _soulChip(
    CreatureInstance inst,
    AlchemicalPowerupType type,
    bool canRead,
  ) {
    final selected = _soulStat == type;
    final potential = _potentialOf(inst, type);
    final maxed = potential >= AlchemonStatSystem.maxPotential;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _busy
          ? null
          : () {
              HapticFeedback.selectionClick();
              if (_soulStat != type) _soulSwapController.forward(from: 0);
              _set(() {
                // Re-tapping the armed stat disarms, so there is always a
                // way back out of a committed soul.
                if (_soulStat == type && _soulArmed) {
                  _soulArmed = false;
                } else {
                  _soulStat = type;
                  _soulArmed = false;
                }
              });
            },
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected ? type.color : _kPalette.line.withValues(alpha: 0.6),
          bracketSize: 6,
          strokeWidth: selected ? 1.3 : 1,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: selected
              ? type.color.withValues(alpha: 0.14)
              : _kPalette.surfaceMutedFill(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _short(type),
                style: _mono(
                  10.5,
                  selected ? type.color : _kPalette.ink,
                  weight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                maxed ? 'MAX' : (canRead ? 'P$potential' : '—'),
                style: _mono(
                  9,
                  maxed ? _kGold : _kPalette.muted,
                  weight: FontWeight.w700,
                  spacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One spare kin in the tray.
class _KinCard extends StatelessWidget {
  const _KinCard({
    super.key,
    required this.creature,
    required this.instance,
    required this.chosen,
    required this.potentials,
    required this.onTap,
    required this.onLongPress,
  });

  final Creature creature;
  final CreatureInstance instance;
  final bool chosen;

  /// (color, Potential) per stat, for those who can read it.
  final List<(Color, int)>? potentials;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: chosen ? _kGold : _kPalette.line.withValues(alpha: 0.55),
          bracketSize: 8,
          strokeWidth: chosen ? 1.4 : 1,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 76,
          color: chosen
              ? _kGold.withValues(alpha: 0.12)
              : _kPalette.surfaceMutedFill(darkAlpha: 0.4),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: InstanceSprite(
                    creature: creature,
                    instance: instance,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'LV ${instance.level}',
                style: _mono(
                  10.5,
                  chosen ? _kGold : _kPalette.ink,
                  spacing: 0.6,
                ),
              ),
              if (potentials != null) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (color, value) in potentials!)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Text(
                          '$value',
                          style: _mono(
                            8.5,
                            color.withValues(alpha: 0.9),
                            spacing: 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A Power Orb in the tray: picked up and dropped on the specimen.
class _OrbTile extends StatelessWidget {
  const _OrbTile({
    super.key,
    required this.type,
    required this.held,
    required this.cost,
    required this.silverCost,
    required this.silverShort,
    required this.maxed,
    required this.usable,
    required this.launching,
    required this.onDragStarted,
    required this.onDragFinished,
  });

  final AlchemicalPowerupType type;
  final int held;
  final int cost;
  final int silverCost;
  final bool silverShort;
  final bool maxed;
  final bool usable;

  /// Lifting away to fly into the specimen.
  final bool launching;
  final VoidCallback onDragStarted;
  final VoidCallback onDragFinished;

  Widget _caption({required bool ghost}) {
    final enough = !maxed && held >= cost;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          maxed ? 'MAX' : 'COST $cost',
          style: _mono(
            11.5,
            maxed ? _kGold : (enough ? type.color : _kPalette.muted),
            weight: FontWeight.w900,
            spacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        if (!maxed)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CoinIcon(kind: CoinKind.silver, size: 10),
              const SizedBox(width: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatCoins(silverCost),
                    style: _mono(
                      9.5,
                      silverShort ? _kDanger : _kPalette.muted,
                      spacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 2),
        Text(
          ghost ? 'IN HAND' : '$held HELD',
          style: _mono(
            9,
            ghost ? type.color : _kPalette.muted,
            weight: FontWeight.w700,
            spacing: 0.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - 16).clamp(34.0, 58.0)
            : 58.0;
        final tile = TweenAnimationBuilder<double>(
          tween: Tween(end: launching ? 1 : 0),
          duration: Duration(milliseconds: launching ? 170 : 0),
          curve: Curves.easeIn,
          builder: (context, lt, child) => Transform.translate(
            offset: Offset(0, -lt * 22),
            child: Opacity(
              opacity: (1 - lt * 1.8).clamp(0.0, 1.0),
              child: child,
            ),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: usable ? 1 : 0.34,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PowerOrb(type: type, size: size, lit: usable),
                _caption(ghost: false),
              ],
            ),
          ),
        );
        if (!usable) return tile;
        return Draggable<_InfusionPayload>(
          data: _InfusionPayload(_InfusionKind.orb, type),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: onDragStarted,
          onDragEnd: (d) {
            if (!d.wasAccepted) HapticFeedback.lightImpact();
            onDragFinished();
          },
          feedback: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: PowerOrb(type: type, size: size * 1.2, lit: true),
          ),
          // Where it came from: a faint pool of its color, not a hoop.
          childWhenDragging: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      type.color.withValues(alpha: 0.16),
                      type.color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              _caption(ghost: true),
            ],
          ),
          child: tile,
        );
      },
    );
  }
}
