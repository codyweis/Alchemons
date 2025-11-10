// lib/widgets/wilderness/encounter_overlay.dart
//
// Modern split-HUD layout for wild encounters
// - Top-right: Wild creature portrait with stats
// - Bottom-right: Compact party strip
// - Center-right: Action buttons
// - Clean, game-like presentation optimized for landscape

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:alchemons/widgets/starter_granted_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/wilderness/device_selection_dialog.dart';

class EncounterOverlay extends StatefulWidget {
  final WildEncounter encounter;
  final List<PartyMember> party;
  final ValueChanged<bool>? onClosedWithResult;
  final ValueChanged<Creature>? onPartyCreatureSelected;
  final VoidCallback? onPreRollShake;

  const EncounterOverlay({
    super.key,
    required this.encounter,
    required this.party,
    this.onClosedWithResult,
    this.onPartyCreatureSelected,
    this.onPreRollShake,
  });

  @override
  State<EncounterOverlay> createState() => _EncounterOverlayState();
}

class _EncounterOverlayState extends State<EncounterOverlay>
    with TickerProviderStateMixin {
  bool _visible = false;
  String? _chosenInstanceId;
  bool _busy = false;
  String _status = 'Select a party member to act';

  late final AnimationController _slideController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    // Auto-show on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _show();
    });
  }

  void _show() {
    setState(() => _visible = true);
    _slideController.forward();
    _fadeController.forward();
  }

  void _hide([bool success = false]) {
    _slideController.reverse().then((_) {
      if (mounted) {
        widget.onClosedWithResult?.call(success);
      }
    });
    _fadeController.reverse();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();
    final wildCreature = repo.getCreatureById(widget.encounter.wildBaseId);

    if (wildCreature == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Dimmed backdrop

        // Center: Wild creature name title
        AnimatedBuilder(
          animation: _slideController,
          builder: (_, __) {
            final slide = Curves.easeOutCubic.transform(_slideController.value);
            return Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: slide,
                child: _WildCreatureTitle(
                  creature: wildCreature,
                  rarity: widget.encounter.rarity,
                  status: _status,
                ),
              ),
            );
          },
        ),

        // Top-right: Party HUD
        AnimatedBuilder(
          animation: _slideController,
          builder: (_, __) {
            final slide = Curves.easeOutCubic.transform(_slideController.value);
            return Positioned(
              top: 16,
              right: 16 - (300 * (1 - slide)),
              child: Opacity(
                opacity: slide,
                child: _PartyHUD(
                  party: widget.party,
                  chosenInstanceId: _chosenInstanceId,
                  onSelect: _onSelectPartyCreature,
                ),
              ),
            );
          },
        ),

        // Bottom: Action buttons row
        AnimatedBuilder(
          animation: _slideController,
          builder: (_, __) {
            final slide = Curves.easeOutCubic.transform(_slideController.value);
            return Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: slide,
                child: Transform.translate(
                  offset: Offset(0, 100 * (1 - slide)),
                  child: _ActionPanel(
                    isPartySelected: _chosenInstanceId != null,
                    status: _status,
                    canAct: !_busy,
                    onBreed: !_busy ? () => _handleBreed(context) : null,
                    onCapture: !_busy
                        ? () => _handleCapture(context, wildCreature)
                        : null,
                    onRun: () => _hide(false),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _onSelectPartyCreature(String instanceId) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    final instRow = await db.creatureDao.getInstance(instanceId);
    if (instRow == null) return;

    final baseCreature = repo.getCreatureById(instRow.baseId);
    if (baseCreature == null) return;

    final hydrated = baseCreature.copyWith(
      genetics: decodeGenetics(instRow.geneticsJson),
      nature: instRow.natureId != null
          ? NatureCatalog.byId(instRow.natureId!)
          : baseCreature.nature,
      isPrismaticSkin:
          instRow.isPrismaticSkin || (baseCreature.isPrismaticSkin ?? false),
    );
    setState(() {
      _status = 'Selected ${hydrated.name}. Choose an action.';
      _chosenInstanceId = instanceId;
    });

    widget.onPartyCreatureSelected?.call(hydrated);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleBreed(BuildContext ctx) async {
    if (_chosenInstanceId == null) {
      setState(() => _status = 'Select a partner first');
      return;
    }

    setState(() => _busy = true);

    try {
      final db = ctx.read<AlchemonsDatabase>();
      final wilderness = WildernessService(db, ctx.read<StaminaService>());
      final instance = await db.creatureDao.getInstance(_chosenInstanceId!);

      // beauty determines luck
      final totalLuck = instance != null
          ? (instance.statBeauty / 100.0) // e.g., 25 beauty = 0.25 luck
          : 0.0;
      final p = wilderness.computeBreedChance(
        base: widget.encounter.baseBreedChance,
        partyLuck: totalLuck,
        matchupMult: 1.0,
      );

      final spent = await wilderness.trySpendForAttempt(_chosenInstanceId!);
      if (spent == null) {
        setState(() => _status = 'Out of stamina!');
        return;
      }

      widget.onPreRollShake?.call();
      HapticFeedback.mediumImpact();
      setState(() => _status = 'Calibrating alchemical matrix…');
      await Future.delayed(
        const Duration(milliseconds: 650),
      ); // short suspense beat

      final success = wilderness.rollSuccess(p);
      if (success) {
        final repo = ctx.read<CreatureCatalog>();

        final speciesA = repo.getCreatureById(instance!.baseId);
        final speciesB = repo.getCreatureById(widget.encounter.wildBaseId);

        Color colorOf(Creature? c, Color fallback) =>
            c != null && c.types.isNotEmpty
            ? BreedConstants.getTypeColor(c.types.first)
            : fallback;

        final colorA = colorOf(speciesA, Theme.of(ctx).colorScheme.primary);
        final colorB = colorOf(speciesB, Theme.of(ctx).colorScheme.secondary);

        Widget partySprite() {
          return SizedBox(
            width: 120,
            height: 120,
            child: InstanceSprite(
              creature: speciesA!,
              instance: instance,
              size: 72,
            ),
          );
        }

        Widget wildSprite() {
          final hydrated = repo.getCreatureById(widget.encounter.wildBaseId);
          if (hydrated?.spriteData != null) {
            final sheet = sheetFromCreature(hydrated!);
            final visuals = visualsFromInstance(hydrated, null);
            return SizedBox(
              width: 120,
              height: 120,
              child: CreatureSprite(
                spritePath: sheet.path,
                totalFrames: sheet.totalFrames,
                rows: sheet.rows,
                frameSize: sheet.frameSize,
                stepTime: sheet.stepTime,
                scale: visuals.scale,
                saturation: visuals.saturation,
                brightness: visuals.brightness,
                hueShift: visuals.hueShiftDeg,
                isPrismatic: visuals.isPrismatic,
                tint: visuals.tint,
              ),
            );
          }

          if (speciesB?.spriteData != null) {
            final sheet = sheetFromCreature(speciesB!);
            return SizedBox(
              width: 120,
              height: 120,
              child: CreatureSprite(
                spritePath: sheet.path,
                totalFrames: sheet.totalFrames,
                rows: sheet.rows,
                frameSize: sheet.frameSize,
                stepTime: sheet.stepTime,
              ),
            );
          }

          return Icon(
            Icons.pets,
            color: Colors.white.withOpacity(.8),
            size: 64,
          );
        }

        _hide(true);

        await showAlchemyFusionCinematic<void>(
          context: ctx,
          leftSprite: partySprite(),
          rightSprite: wildSprite(),
          leftColor: colorA,
          rightColor: colorB,
          minDuration: const Duration(milliseconds: 1800),
          task: () async {
            await _breedWithWild(ctx, instance, speciesB);
          },
        );

        if (!mounted) return;
        setState(() => _status = 'Successfully fused.');
      } else {
        setState(() => _status = 'Failed… try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleCapture(BuildContext ctx, dynamic wildCreature) async {
    setState(() => _busy = true);

    try {
      final selectedDevice = await DeviceSelectionDialog.show(
        ctx,
        wildCreature: wildCreature,
        rarity: widget.encounter.rarity,
      );

      if (selectedDevice == null || !mounted) {
        setState(() => _busy = false);
        return;
      }

      final catchService = ctx.read<CatchService>();
      final success = await catchService.attemptCatch(
        device: selectedDevice,
        target: wildCreature,
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        setState(() => _status = 'Captured!');

        await _placeWildEgg(ctx, widget.encounter.wildBaseId);

        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _hide(true);
      } else {
        HapticFeedback.lightImpact();
        setState(() => _status = 'Capture failed!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Breed owned instance with wild creature using BreedingServiceV2
  Future<void> _breedWithWild(
    BuildContext ctx,
    db.CreatureInstance ownedParent,
    Creature? wildCreature,
  ) async {
    if (wildCreature == null) return;

    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureCatalog>();
    final randomizer = WildCreatureRandomizer();

    // Get dependencies for BreedingServiceV2
    final engine = ctx.read<BreedingEngine>();
    final payloadFactory = EggPayloadFactory(repo);

    // Create breeding service
    final breedingService = BreedingServiceV2(
      gameData: ctx.read<GameDataService>(),
      db: db,
      engine: engine,
      payloadFactory: payloadFactory,
      wildRandomizer: randomizer,
    );

    // Use proper wild breeding flow
    final result = await breedingService.breedWithWild(
      ownedParent,
      wildCreature,
    );

    if (!result.success) {
      if (mounted) {
        setState(() => _status = 'Breeding failed: ${result.message}');
      }
    }
  }

  /// Capture wild creature (for the Capture button)
  Future<void> _placeWildEgg(BuildContext ctx, String baseId) async {
    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureCatalog>();
    final randomizer = WildCreatureRandomizer();

    final baseCreature = repo.getCreatureById(baseId);
    if (baseCreature == null) return;

    final randomized = randomizer.randomizeWildCreature(baseCreature);

    final rarityKey = randomized.rarity.toLowerCase();
    final baseHatchDelay =
        BreedConstants.rarityHatchTimes[rarityKey] ??
        const Duration(minutes: 10);
    final hatchAtUtc = DateTime.now().toUtc().add(baseHatchDelay);

    final factory = EggPayloadFactory(repo);
    final payload = factory.createWildCapturePayload(randomized);
    final payloadJson = payload.toJsonString();

    final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';
    final free = await db.incubatorDao.firstFreeSlot();

    if (free == null) {
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: randomized.id,
        rarity: randomized.rarity,
        remaining: baseHatchDelay,
        payloadJson: payloadJson,
      );
    } else {
      await db.incubatorDao.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: randomized.id,
        rarity: randomized.rarity,
        hatchAtUtc: hatchAtUtc,
        payloadJson: payloadJson,
      );
    }
  }
}

// ==========================================
// WILD CREATURE TITLE (Center top)
// ==========================================
class _WildCreatureTitle extends StatelessWidget {
  final Creature creature;
  final String rarity;
  final String status;

  const _WildCreatureTitle({
    required this.creature,
    required this.rarity,
    required this.status,
  });

  Color get _rarityColor {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade700;
      case 'uncommon':
        return Colors.green.shade600;
      case 'rare':
        return Colors.blue.shade600;
      case 'epic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 2),
          margin: const EdgeInsets.only(left: 250, right: 250, bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        // Classification Rank badge (was Rarity)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _rarityColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _rarityColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '${rarity.toUpperCase()}', // Added 'RANK'
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8, // Increased for a more technical look
            ),
          ),
        ),
        const SizedBox(height: 1),
        // Creature designation (was name)
        _DigitalAnimatedText(
          // <--- NEW WIDGET
          text: creature.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// UTILITY: Digital Animated Text
// ==========================================
class _DigitalAnimatedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const _DigitalAnimatedText({
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  __DigitalAnimatedTextState createState() => __DigitalAnimatedTextState();
}

class __DigitalAnimatedTextState extends State<_DigitalAnimatedText> {
  String _displayText = '';
  late Timer _timer;
  int _currentIndex = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    // Shorter interval for fast "glitchy" type-in effect
    final interval = widget.duration.inMilliseconds ~/ widget.text.length;

    _timer = Timer.periodic(
      Duration(milliseconds: interval > 0 ? interval : 1),
      (timer) {
        if (_currentIndex < widget.text.length) {
          // Add one correct character
          _displayText = widget.text.substring(0, _currentIndex + 1);

          // Add 1-3 random, glitchy characters at the end
          final glitchLength = _random.nextInt(3) + 1;
          for (int i = 0; i < glitchLength; i++) {
            _displayText += String.fromCharCode(
              _random.nextInt(26) + 65,
            ); // Random uppercase letter
          }

          _currentIndex++;
        } else {
          // Animation finished, set final text and stop timer
          _displayText = widget.text;
          timer.cancel();
        }
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show the finished text at the very end
    final display = _currentIndex >= widget.text.length
        ? widget.text
        : _displayText;

    return Text(
      display,
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ==========================================
// PARTY HUD (Top-right) - Clean design
// ==========================================
class _PartyHUD extends StatelessWidget {
  final List<PartyMember> party;
  final String? chosenInstanceId;
  final ValueChanged<String> onSelect;

  const _PartyHUD({
    required this.party,
    required this.chosenInstanceId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      // --- Wrapping with SingleChildScrollView for horizontal scrolling ---
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < party.length; i++) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color.fromARGB(
                      255,
                      255,
                      255,
                      255,
                    ).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: _PartyMemberCard(
                  member: party[i],
                  selected: party[i].instanceId == chosenInstanceId,
                  onTap: () => onSelect(party[i].instanceId),
                ),
              ),
              if (i < party.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartyMemberCard extends StatelessWidget {
  final PartyMember member;
  final bool selected;
  final VoidCallback onTap;

  const _PartyMemberCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    return FutureBuilder<CreatureInstance?>(
      future: db.creatureDao.getInstance(member.instanceId),
      builder: (context, snap) {
        final inst = snap.data;
        final base = inst == null ? null : repo.getCreatureById(inst.baseId);

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 75,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: selected
                  ? Border.all(color: const Color(0xFF00FF88), width: 2)
                  : null,
              borderRadius: BorderRadius.circular(4),
              boxShadow: selected
                  ? [
                      const BoxShadow(
                        color: Color(0x8800FF88),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Beauty stat - only show when selected
                if (selected) ...[
                  Text(
                    'Beauty ${inst?.statBeauty.toStringAsFixed(2) ?? '--'}',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 16, 17, 17),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Sprite
                if (inst != null && base != null)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: InstanceSprite(
                      creature: base,
                      instance: inst,
                      size: 40,
                    ),
                  )
                else
                  const SizedBox(width: 48, height: 48),
                const SizedBox(height: 6),

                if (inst != null)
                  StaminaBar(current: inst.staminaBars, max: inst.staminaMax),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// ACTION PANEL (Bottom) - Horizontal row
// ==========================================
class _ActionPanel extends StatelessWidget {
  final String status;
  final bool canAct;
  final VoidCallback? onBreed;
  final VoidCallback? onCapture;
  final VoidCallback onRun;
  final bool isPartySelected;

  const _ActionPanel({
    required this.status,
    required this.canAct,
    required this.onBreed,
    required this.onCapture,
    required this.onRun,
    required this.isPartySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _ActionButton(
              disabled: !isPartySelected,
              label: 'ATTEMPT ALCHEMICAL FUSION', // Changed text
              icon: Icons.auto_fix_high, // Changed icon for a mystical look
              color: const Color.fromARGB(255, 16, 42, 16),
              onPressed: canAct ? onBreed : null,
            ),
            const SizedBox(width: 10),
            _ActionButton(
              label: 'HARVEST PROTOCOL', // Changed text
              icon: Icons.science, // Changed icon for a scientific look
              color: const Color.fromARGB(255, 46, 3, 3),
              onPressed: canAct ? onCapture : null,
            ),
            const SizedBox(width: 10),
            _ActionButton(
              label: 'MAP', // Changed text
              icon: Icons.exit_to_app, // Changed icon
              color: const Color.fromARGB(255, 22, 20, 20),
              onPressed: onRun,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool disabled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.outlined = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || disabled;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? const Color(0xFF3A3A4E) : color,
        foregroundColor: isDisabled ? Colors.white38 : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: isDisabled ? 0 : 4,
        shadowColor: isDisabled ? Colors.transparent : color.withOpacity(0.4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
