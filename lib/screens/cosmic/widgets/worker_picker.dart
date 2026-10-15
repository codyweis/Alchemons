// lib/screens/cosmic/widgets/worker_picker.dart
//
// Choosing an Alchemon for a job in the Works. Every Alchemon that could
// take it, best first by what it would actually do there, with that figure
// on its case: a miner's rate, a courier's load and run, a scavenger's find
// and trip, a presser's rate. A miner must be of its planet's element.
// Those in the ship's party or the garrison are shown but cannot be taken;
// one already at work can, and leaves its old job.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/works.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'cosmic_overlay_chrome.dart';
import 'cosmic_panel_kit.dart';
import 'cosmic_screen_styles.dart';
import 'works_panels.dart' show jobFigure, jobReads, jobScore;

/// What an Alchemon brings to a job, read from its record.
WorkerProfile workerProfileOf(CreatureInstance inst, String element) =>
    WorkerProfile(
      instanceId: inst.instanceId,
      element: element,
      speed: inst.statSpeed,
      intelligence: inst.statIntelligence,
      strength: inst.statStrength,
      harvestRate: computeHarvestRatePerMinute(inst),
    );

class WorkerPicker extends StatefulWidget {
  const WorkerPicker({
    super.key,
    required this.job,
    this.element,
    this.distance = 0,
    this.pressTier = 1,
    this.refineTier = 1,
    this.blocked = const {},
    this.atWork = const {},
    this.current,
  });

  final WorkJob job;

  /// A miner's planet: only Alchemons of this element can mine it.
  final String? element;

  /// How far a courier would fly, for its run.
  final double distance;
  final int pressTier;
  final int refineTier;

  /// Alchemons that cannot be taken, and why ("IN PARTY").
  final Map<String, String> blocked;

  /// Alchemons at work now, and where ("COURIER · FIRE").
  final Map<String, String> atWork;

  /// Who is in the slot now.
  final String? current;

  @override
  State<WorkerPicker> createState() => _WorkerPickerState();
}

class _Candidate {
  _Candidate(this.inst, this.species, this.profile, this.score);
  final CreatureInstance inst;
  final Creature? species;
  final WorkerProfile profile;
  final double score;
}

class _WorkerPickerState extends State<WorkerPicker> {
  List<_Candidate>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final instances = await db.creatureDao.getAllInstances();
    final out = <_Candidate>[];
    for (final inst in instances) {
      final species = catalog.getCreatureById(inst.baseId);
      final element = (species?.types.isNotEmpty ?? false)
          ? species!.types.first
          : 'Earth';
      if (widget.job == WorkJob.miner &&
          widget.element != null &&
          element != widget.element) {
        continue;
      }
      final p = workerProfileOf(inst, element);
      out.add(
        _Candidate(
          inst,
          species,
          p,
          jobScore(
            widget.job,
            p,
            distance: widget.distance,
            pressTier: widget.pressTier,
          ),
        ),
      );
    }
    out.sort((a, b) {
      final ab = widget.blocked.containsKey(a.inst.instanceId) ? 1 : 0;
      final bb = widget.blocked.containsKey(b.inst.instanceId) ? 1 : 0;
      if (ab != bb) return ab - bb;
      return b.score.compareTo(a.score);
    });
    if (mounted) setState(() => _all = out);
  }

  @override
  Widget build(BuildContext context) {
    void close() {
      HapticFeedback.lightImpact();
      Navigator.of(context).maybePop();
    }

    final all = _all;
    final title = widget.job == WorkJob.miner && widget.element != null
        ? 'CHOOSE A ${widget.element!.toUpperCase()} MINER'
        : 'CHOOSE A ${widget.job.label}';
    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: close,
        alpha: 0.97,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(title: title, onClose: close),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  'BEST FIRST · THIS JOB READS ${jobReads(widget.job)}',
                  style: panelLabel(9, panelPalette.muted, spacing: 1),
                ),
              ),
              Expanded(
                child: all == null
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : all.isEmpty
                    ? Center(
                        child: Text(
                          widget.job == WorkJob.miner
                              ? 'NO ${widget.element?.toUpperCase()} ALCHEMONS'
                              : 'NO ALCHEMONS',
                          style: panelLabel(11, panelPalette.muted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 128,
                              mainAxisExtent: 104,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: all.length,
                        itemBuilder: (context, i) => _tile(all[i], i == 0),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(_Candidate c, bool best) {
    final id = c.inst.instanceId;
    final blockedWhy = widget.blocked[id];
    final working = widget.atWork[id];
    final current = widget.current == id;
    final ink = elementInk(c.profile.element);
    final enabled = blockedWhy == null && !current;
    final name = c.inst.nickname ?? c.species?.name ?? c.inst.baseId;
    return GestureDetector(
      key: ValueKey('workerPicker.$id'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? context.soundAction(() => Navigator.of(context).pop(id))
          : null,
      child: Opacity(
        opacity: enabled || current ? 1 : 0.4,
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: (current || best ? CosmicScreenStyles.amberBright : ink)
                .withValues(alpha: current || best ? 0.85 : 0.35),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            color: panelPalette.bg1.withValues(alpha: 0.6),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: c.species == null || c.species!.spriteData == null
                      ? Center(child: PanelDot(ink, size: 14))
                      : InstanceSprite(
                          creature: c.species!,
                          instance: c.inst,
                          size: 40,
                        ),
                ),
                const SizedBox(height: 3),
                Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelLabel(9, ink, spacing: 0.4),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    jobFigure(
                      widget.job,
                      c.profile,
                      distance: widget.distance,
                      pressTier: widget.pressTier,
                      refineTier: widget.refineTier,
                    ),
                    style: panelLabel(9.5, panelPalette.ink, spacing: 0.3),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    current
                        ? 'HERE NOW'
                        : blockedWhy ?? working ?? 'LV ${c.inst.level}',
                    style: panelLabel(
                      8,
                      current
                          ? CosmicScreenStyles.amberBright
                          : working != null
                          ? CosmicScreenStyles.teal
                          : panelPalette.muted,
                      spacing: 0.5,
                    ),
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
