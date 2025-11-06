// lib/widgets/wilderness/encounter_overlay.dart
//
// Streamlined landscape-only overlay for encounters
// - Compact party strip at top showing sprites, stamina, and beauty
// - Direct action buttons (no engagement dialog)
// - Minimal padding, maximum space efficiency

import 'dart:ui';
import 'dart:convert';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/wilderness/device_selection_dialog.dart';

class EncounterOverlay extends StatefulWidget {
  final WildEncounter encounter;
  final List<PartyMember> party;
  final ValueChanged<bool>? onClosedWithResult;
  final ValueChanged<Creature>? onPartyCreatureSelected;

  const EncounterOverlay({
    super.key,
    required this.encounter,
    required this.party,
    this.onClosedWithResult,
    this.onPartyCreatureSelected,
  });

  @override
  State<EncounterOverlay> createState() => _EncounterOverlayState();
}

class _EncounterOverlayState extends State<EncounterOverlay>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close([bool success = false]) {
    if (!_open) return;
    _toggle();
    widget.onClosedWithResult?.call(success);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width * 0.32;
    final panelHeight = size.height * 0.88;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_open,
          child: Stack(
            children: [
              if (_open)
                GestureDetector(
                  onTap: _toggle,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return Container(
                        color: Colors.black.withOpacity(
                          0.25 * _controller.value,
                        ),
                      );
                    },
                  ),
                ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                right: _open ? 12 : -panelWidth - 32,
                top: (size.height - panelHeight) / 2,
                width: panelWidth,
                height: panelHeight,
                child: _GlassPanel(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      color: Colors.white.withOpacity(0.75),
                      child: _EncounterPanel(
                        encounter: widget.encounter,
                        party: widget.party,
                        onMinimize: _toggle,
                        onExit: (success) => _close(success),
                        onPartyCreatureSelected:
                            widget.onPartyCreatureSelected!,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          right: 12,
          bottom: 20,
          child: _OverlayOrb(open: _open, onTap: _toggle),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                color: Color(0x33000000),
                offset: Offset(0, 8),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.20),
                Colors.white.withOpacity(0.08),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _OverlayOrb extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  const _OverlayOrb({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        child: Image(
          image: const AssetImage('assets/images/ui/breedicon.png'),
          width: open ? 24 : 56,
          height: open ? 24 : 56,
        ),
      ),
    );
  }
}

// -------------------------
// Streamlined Panel
// -------------------------
class _EncounterPanel extends StatefulWidget {
  final WildEncounter encounter;
  final List<PartyMember> party;
  final VoidCallback onMinimize;
  final ValueChanged<bool> onExit;
  final ValueChanged<Creature> onPartyCreatureSelected;

  const _EncounterPanel({
    required this.encounter,
    required this.party,
    required this.onMinimize,
    required this.onExit,
    required this.onPartyCreatureSelected,
  });

  @override
  State<_EncounterPanel> createState() => _EncounterPanelState();
}

class _EncounterPanelState extends State<_EncounterPanel> {
  String? _chosenInstanceId;
  bool _busy = false;
  String _status = 'Choose your approach';

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();
    final wildCreature = repo.getCreatureById(widget.encounter.wildBaseId);

    if (wildCreature == null) {
      return Center(
        child: Text('Unknown creature: ${widget.encounter.wildBaseId}'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  _status,
                  style: TextStyle(
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onMinimize,
                icon: const Icon(Icons.keyboard_arrow_right_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Compact Party Strip
          _PartyStrip(
            party: widget.party,
            chosenInstanceId: _chosenInstanceId,
            onSelect: (id) => _onSelectPartyCreature(id),
          ),

          // Direct Action Buttons
          _ActionButtons(
            canAct: !_busy,
            onBreed: !_busy ? () => _handleBreed(context) : null,
            onCapture: !_busy
                ? () => _handleCapture(context, wildCreature)
                : null,
            onRun: () => widget.onExit(false),
          ),
        ],
      ),
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

    setState(() => _chosenInstanceId = instanceId);
    widget.onPartyCreatureSelected.call(hydrated);
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

      final totalLuck = widget.party.fold<double>(0, (a, m) => a + m.luck);
      final p = wilderness.computeBreedChance(
        base: widget.encounter.baseBreedChance,
        partyLuck: totalLuck,
        matchupMult: 1.0,
      );

      final spent = await wilderness.trySpendForAttempt(_chosenInstanceId!);
      if (spent == null) {
        setState(() => _status = 'Too tired… needs rest');
        return;
      }

      final success = wilderness.rollSuccess(p);
      if (success) {
        // Build sprites & colors
        final repo = ctx.read<CreatureCatalog>();

        final speciesA = repo.getCreatureById(instance!.baseId);
        final speciesB = repo.getCreatureById(widget.encounter.wildBaseId);

        Color colorOf(Creature? c, Color fallback) =>
            c != null && c.types.isNotEmpty
            ? BreedConstants.getTypeColor(c.types.first)
            : fallback;

        final colorA = colorOf(speciesA, Theme.of(ctx).colorScheme.primary);
        final colorB = colorOf(speciesB, Theme.of(ctx).colorScheme.secondary);

        // Party sprite (InstanceSprite already handles genetics/prismatic)
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

        // Wild sprite: prefer hydrated genetics if you have them on the encounter
        Widget wildSprite() {
          final hydrated = repo.getCreatureById(widget.encounter.wildBaseId);
          if (hydrated?.spriteData != null) {
            final sheet = sheetFromCreature(hydrated!);
            final visuals = visualsFromInstance(
              hydrated,
              null,
            ); // from Creature.genetics
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

        widget.onExit(true);

        // Run the cinematic, and put your egg-placement inside `task`
        await showAlchemyFusionCinematic<void>(
          context: ctx,
          leftSprite: partySprite(),
          rightSprite: wildSprite(),
          leftColor: colorA,
          rightColor: colorB,
          minDuration: const Duration(milliseconds: 1800),
          task: () async {
            // whatever you previously did on success:
            await _placeWildEgg(ctx, widget.encounter.wildBaseId);
          },
        );

        if (!mounted) return;
        setState(() => _status = 'Success! Egg created');
      } else {
        setState(() => _status = 'Failed… Try capturing?');
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
        widget.onExit(true);
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

  Future<void> _placeWildEgg(BuildContext ctx, String baseId) async {
    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureCatalog>();
    final randomizer = WildCreatureRandomizer();

    final baseCreature = repo.getCreatureById(baseId);
    if (baseCreature == null) return;

    // Keep your existing wild randomization
    final randomized = randomizer.randomizeWildCreature(baseCreature);

    // Hatch timing stays the same
    final rarityKey = randomized.rarity.toLowerCase();
    final baseHatchDelay =
        BreedConstants.rarityHatchTimes[rarityKey] ??
        const Duration(minutes: 10);
    final hatchAtUtc = DateTime.now().toUtc().add(baseHatchDelay);

    // NEW: unified payload
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

// -------------------------------------
// Compact Party Strip (horizontal scroll)
// -------------------------------------
class _PartyStrip extends StatelessWidget {
  final List<PartyMember> party;
  final String? chosenInstanceId;
  final ValueChanged<String> onSelect;
  const _PartyStrip({
    required this.party,
    required this.chosenInstanceId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: party.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final m = party[i];
          final selected = m.instanceId == chosenInstanceId;
          return _CompactPartyCard(
            instanceId: m.instanceId,
            selected: selected,
            onTap: () => onSelect(m.instanceId),
          );
        },
      ),
    );
  }
}

// -------------------------------------
// Compact party card: sprite + stamina + beauty
// -------------------------------------
class _CompactPartyCard extends StatelessWidget {
  final String instanceId;
  final bool selected;
  final VoidCallback onTap;
  const _CompactPartyCard({
    required this.instanceId,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    return FutureBuilder<CreatureInstance?>(
      future: db.creatureDao.getInstance(instanceId),
      builder: (context, snap) {
        final inst = snap.data;
        final base = inst == null ? null : repo.getCreatureById(inst.baseId);

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 64,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: selected ? Colors.green : Colors.indigo.shade200,
                width: selected ? 2.5 : 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.green.shade200, blurRadius: 6)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Instance sprite placeholder
                // Beauty stat
                Text(
                  inst?.statBeauty.toStringAsFixed(2) ?? '--',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                inst != null
                    ? InstanceSprite(creature: base!, instance: inst, size: 36)
                    : Container(
                        width: 36,
                        height: 36,
                        color: Colors.grey.shade300,
                      ),
                // Stamina
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------
// Direct action buttons (no dialog)
// -------------------------------------
class _ActionButtons extends StatelessWidget {
  final bool canAct;
  final VoidCallback? onBreed;
  final VoidCallback? onCapture;
  final VoidCallback onRun;
  const _ActionButtons({
    required this.canAct,
    required this.onBreed,
    required this.onCapture,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: canAct ? onBreed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Breed',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: canAct ? onCapture : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Capture',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onRun,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.indigo.shade700,
              side: BorderSide(color: Colors.indigo.shade300),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Run',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
