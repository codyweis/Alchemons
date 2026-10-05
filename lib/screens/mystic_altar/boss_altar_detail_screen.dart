// lib/screens/mystic_altar/boss_altar_detail_screen.dart
//
// ONE MYSTIC'S ALTAR. The Mystic stands in the middle as a ghost of grains;
// round it, a seat for every kind of its element. Tap a seat to give one of
// that kind — it flies in, and its share of the Mystic fills with colour.
// With every seat given (and, for Blood, every other Mystic awake), the rite
// is held, and performed: the offerings and the relic pour into a knot, the
// knot bursts, and the Mystic comes out of it as its element and gathers
// into itself. Awake, it is sealed into a cultivation and the altar is left.
//
// The field (AltarRiteField) draws all of it; this screen owns the save, the
// clock and the words.

import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/screens/mystic_altar/altar_chrome.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/screens/mystic_altar/altar_rite_field.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/mystic_ritual_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// One of the sixteen Mystics Blood's rite needs awake.
class _Witness {
  const _Witness(this.entry, this.awake);
  final AltarEntry entry;
  final bool awake;
}

/// Where the rite is.
enum _Rite { waiting, performing, awake, sealing }

class BossAltarDetailScreen extends StatefulWidget {
  final AltarEntry boss;
  const BossAltarDetailScreen({super.key, required this.boss});

  @override
  State<BossAltarDetailScreen> createState() => _BossAltarDetailScreenState();
}

class _BossAltarDetailScreenState extends State<BossAltarDetailScreen>
    with SingleTickerProviderStateMixin {
  AltarRiteField? _field;
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Duration _last = Duration.zero;

  List<Creature> _species = [];
  Creature? _mystic;
  final Map<String, String?> _placed = {};
  List<_Witness> _witnesses = const [];
  bool _hasRelic = false;
  bool _loading = true;
  bool _storyCheckStarted = false;

  _Rite _rite = _Rite.waiting;
  bool _committing = false;

  /// What the rite left: whether this was the Mystic's first waking, which
  /// Mystics are now awake, and where its cultivation went.
  bool _firstAwakening = true;
  Set<String> _awakeAfter = {};
  bool _inChamber = true;

  /// The rite's haptic beats already felt.
  int _beat = 0;

  AltarEntry get _boss => widget.boss;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState(first: true);
      _maybeShowBossRelicStoryIntro();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _loadState({bool first = false}) async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();

    final traitKey = BossLootKeys.traitKeyForElement(_boss.element);
    final qty = await db.inventoryDao.getItemQty(traitKey);
    final relicPlaced = (await db.altarDao.getRelicPlacedIds([
      _boss.id,
    ])).contains(_boss.id);
    final placements = await db.altarDao.getPlacementsForBoss(_boss.id);
    final mystic = catalog.mysticByElement(_boss.element);
    final species = catalog
        .byType(_boss.element)
        .where((s) => s.id != mystic?.id)
        .toList();
    final available = <String, int>{};
    for (final sp in species) {
      final all = await db.creatureDao.listInstancesBySpecies(sp.id);
      available[sp.id] = all.where((i) => !i.locked).length;
    }
    final witnesses = <_Witness>[];
    if (_isBloodBoss) {
      for (final e in kAltarEntries.where((b) => b.order < 17)) {
        final v = await db.settingsDao.getSetting('altar_summoned_${e.id}');
        witnesses.add(_Witness(e, v != null && v.trim().isNotEmpty));
      }
    }
    final placed = <String, String?>{for (final sp in species) sp.id: null};
    for (final p in placements) {
      placed[p.speciesId] = p.instanceId;
    }
    if (!mounted) return;

    var field = _field;
    if (first || field == null) {
      field = AltarRiteField(
        element: _boss.element,
        offerings: [for (final sp in species) RiteOffering(sp)],
      );
      _readGrains(field, mystic);
    }
    for (final o in field.offerings) {
      o
        ..given = placed[o.species.id] != null
        ..available = available[o.species.id] ?? 0;
    }
    field.relicSet = relicPlaced || qty > 0;

    setState(() {
      _field = field;
      _hasRelic = relicPlaced || qty > 0;
      _mystic = mystic;
      _species = species;
      _witnesses = witnesses;
      _placed
        ..clear()
        ..addAll(placed);
      _loading = false;
    });
  }

  Future<void> _readGrains(AltarRiteField field, Creature? mystic) async {
    final relic = AltarGrains.relic(_boss, width: 40);
    if (mystic != null) {
      field.mystic = await AltarGrains.creature(
        mystic,
        width: AltarRiteField.mysticWidth.round(),
        maxGrains: 2600,
        tones: 14,
      );
    }
    field.relic = await relic;
    for (final o in field.offerings) {
      o.grains = await AltarGrains.creature(
        o.species,
        width: 72,
        maxGrains: 620,
        tones: 12,
      );
    }
  }

  Future<void> _maybeShowBossRelicStoryIntro() async {
    if (_storyCheckStarted || !mounted) return;
    _storyCheckStarted = true;

    final db = context.read<AlchemonsDatabase>();
    final hasSeen = await db.settingsDao.hasSeenBossRelicScreenStoryIntro();
    if (!hasSeen && mounted) {
      await LandscapeDialog.show(
        context,
        title: 'A Relic Is Not A Trophy',
        message:
            'It is what remains when form fails. Not the creature, not its beauty, but the instruction that endured beneath both.\n\n'
            'Is creation discovery or concealment, is beauty truth made visible, or a veil drawn over something worse.',
      );

      if (!mounted) return;
      await db.settingsDao.setBossRelicScreenStoryIntroSeen();
    }

    if (!_isBloodBoss || !mounted) return;
    final hasSeenBloodIntro =
        await db.settingsDao.getSetting(
          'blood_mystic_relic_story_intro_seen_v1',
        ) ==
        '1';
    if (hasSeenBloodIntro || !mounted) return;

    await LandscapeDialog.show(
      context,
      title: 'Not A Return',
      message:
          'A relic does not bring something back. It gives the surviving instruction a body again.\n\n'
          'If the mystics were made to guard what this world could not bear, then Sanguorath is what remains when sacrifice itself is taught to take shape.',
    );

    if (!mounted) return;
    await db.settingsDao.setSetting(
      'blood_mystic_relic_story_intro_seen_v1',
      '1',
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  bool get _isBloodBoss => _boss.element.toLowerCase() == 'blood';

  int get _givenCount => _placed.values.where((v) => v != null).length;

  bool get _allGiven =>
      _species.isNotEmpty && _species.every((s) => _placed[s.id] != null);

  int get _witnessesAwake => _witnesses.where((w) => w.awake).length;

  bool get _allWitnessed =>
      !_isBloodBoss ||
      (_witnesses.isNotEmpty && _witnesses.every((w) => w.awake));

  bool get _canSummon =>
      _hasRelic &&
      _allGiven &&
      _allWitnessed &&
      _rite == _Rite.waiting &&
      !_committing;

  String get _relicName =>
      BossLootKeys.elementRewards[_boss.element.toLowerCase()]?.traitName ??
      'relic';

  String get _mysticName => _mystic?.name ?? _boss.name;

  /// A kind's name, with its rarity when another kind on this altar shares
  /// it (Blood asks for two Bloodmasks).
  String _kindName(Creature sp) =>
      _species.where((s) => s.name == sp.name).length > 1
      ? '${sp.name} · ${sp.rarity}'
      : sp.name;

  void _snack(String msg) {
    if (!mounted) return;
    final accent = altarAccent(_boss.element);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: altarBody(context, color: AltarTone.parchment),
          ),
          backgroundColor: const Color(0xFF0B0812),
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shape: Border(
            left: BorderSide(color: accent.withValues(alpha: 0.75), width: 2),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── the clock ─────────────────────────────────────────────────────────────

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final f = _field;
    if (f == null) return;
    f.time += dt;
    for (final o in f.offerings) {
      if (o.giving < 1) {
        final was = o.giving;
        o.giving = math.min(1, o.giving + dt / 1.9);
        if (was < 0.72 && o.giving >= 0.72) {
          // It lands in the Mystic.
          HapticFeedback.mediumImpact();
          context.sound(
            SoundCue.forElement(_boss.element) ?? SoundCue.uiConfirm,
          );
        }
      }
    }
    switch (_rite) {
      case _Rite.waiting:
        break;
      case _Rite.performing:
      case _Rite.awake:
        f.summon += dt;
        f.charge = math.max(0, f.charge - dt);
        _riteBeats(f.summon);
        if (_rite == _Rite.performing &&
            f.summon >= AltarRiteField.formEnd + 0.15) {
          setState(() => _rite = _Rite.awake);
          HapticFeedback.heavyImpact();
          context.sound(SoundCue.altarAwake);
        }
      case _Rite.sealing:
        f.summon += dt;
        f.seal = math.min(1, f.seal + dt / 1.35);
        if (f.seal >= 1) _leave();
    }
    _clock.value = f.time;
  }

  /// The rite is felt: the knot's quickening pulse, then the burst. It is
  /// heard as one cue from its first beat, scored to these same times (pour,
  /// knot, the burst at knotEnd), so the burst cannot drift from its knot.
  void _riteBeats(double s) {
    const beats = [0.0, 1.0, 1.6, 2.05, 2.4, AltarRiteField.knotEnd];
    while (_beat < beats.length && s >= beats[_beat]) {
      final last = _beat == beats.length - 1;
      if (last) {
        HapticFeedback.heavyImpact();
      } else if (_beat == 0) {
        HapticFeedback.mediumImpact();
        context.sound(SoundCue.altarRite);
      } else {
        HapticFeedback.lightImpact();
      }
      _beat++;
    }
  }

  // ── giving an offering ────────────────────────────────────────────────────

  void _onTapUp(TapUpDetails d) {
    final f = _field;
    if (f == null) return;
    if (_rite == _Rite.performing && f.summon > AltarRiteField.knotEnd) {
      // A tap hurries the waking along, once the knot has burst.
      f.summon = math.max(f.summon, AltarRiteField.formEnd - 0.4);
      return;
    }
    if (_rite != _Rite.waiting || _committing) return;
    final i = f.seatAt(d.localPosition);
    if (i == null) return;
    final o = f.offerings[i];
    if (o.given) {
      _snack('${o.species.name} is given.');
      return;
    }
    _give(o.species);
  }

  Future<void> _give(Creature sp) async {
    if (_placed[sp.id] != null) return;
    final db = context.read<AlchemonsDatabase>();
    final all = await db.creatureDao.listInstancesBySpecies(sp.id);
    final avail = all.where((i) => !i.locked).toList()
      ..sort((a, b) => _potential(b).compareTo(_potential(a)));
    if (avail.isEmpty) {
      _snack('You have no unlocked ${sp.name} to give.');
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<CreatureInstance>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      builder: (_) => _OfferingSheet(
        species: sp,
        title: _kindName(sp),
        instances: avail,
        element: _boss.element,
        mysticName: _mysticName,
      ),
    );
    if (picked == null || !mounted) return;

    // Genetic Potential and nature pass on; current Power, level and
    // Enhancement are its own training and do not.
    final snapshot = jsonEncode({
      'natureId': picked.natureId,
      'natureId2': picked.natureId2,
      'scaleVersion': 2,
      'speedPotential': picked.statSpeedPotential,
      'intelligencePotential': picked.statIntelligencePotential,
      'strengthPotential': picked.statStrengthPotential,
      'beautyPotential': picked.statBeautyPotential,
    });

    setState(() => _committing = true);
    try {
      await MysticRitualService(db).commit(
        bossId: _boss.id,
        speciesId: sp.id,
        instanceId: picked.instanceId,
        snapshotJson: snapshot,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _committing = false);
        _snack(
          'The offering could not be given. Reopen the altar to check your specimen.',
        );
      }
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final o = _field?.offerings.firstWhere((o) => o.species.id == sp.id);
    setState(() {
      _committing = false;
      _placed[sp.id] = picked.instanceId;
      if (o != null) {
        o
          ..given = true
          ..giving = 0
          ..available = math.max(0, o.available - 1);
      }
    });
  }

  static double _potential(CreatureInstance i) =>
      i.statSpeedPotential +
      i.statIntelligencePotential +
      i.statStrengthPotential +
      i.statBeautyPotential;

  // ── the rite ──────────────────────────────────────────────────────────────

  Future<void> _perform() async {
    if (!_canSummon) return;
    final f = _field;
    final target = _mystic;
    if (f == null || target == null) return;
    setState(() => _committing = true);
    final db = context.read<AlchemonsDatabase>();
    final before = await db.settingsDao.getSetting(
      'altar_summoned_${_boss.id}',
    );
    final first = before == null || before.trim().isEmpty;
    bool inChamber;
    try {
      inChamber = await MysticRitualService(db).summon(
        bossId: _boss.id,
        element: _boss.element,
        targetSpeciesId: target.id,
        requiredSpecies: _species.map((s) => s.id).toSet(),
        payload: (placements) =>
            _payload(target, _boss, _deriveFromSacrifices(placements)),
      );
    } catch (e) {
      debugPrint('Summon error: $e');
      if (mounted) {
        setState(() => _committing = false);
        f.charge = 0;
        _snack(
          'The rite could not be completed. Your offerings remain; reopen the altar and try again.',
        );
      }
      return;
    }
    final awake = <String>{};
    for (final e in kAltarEntries) {
      final v = await db.settingsDao.getSetting('altar_summoned_${e.id}');
      if (v != null && v.trim().isNotEmpty) awake.add(e.id);
    }
    if (!mounted) return;
    setState(() {
      _committing = false;
      _firstAwakening = first;
      _awakeAfter = awake;
      _inChamber = inChamber;
      _rite = _Rite.performing;
      _beat = 0;
      f.summon = 0;
    });
  }

  void _depart() {
    final f = _field;
    if (f == null || _rite != _Rite.awake) return;
    HapticFeedback.mediumImpact();
    context.sound(SoundCue.altarSeal);
    setState(() => _rite = _Rite.sealing);
  }

  bool _leaving = false;

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final db = context.read<AlchemonsDatabase>();
    if (await db.settingsDao.getSetting('campaign_mystic_presence_seen_v1') !=
            '1' &&
        mounted) {
      final entry = campaignEntries.firstWhere((e) => e.id == 'mystic');
      await LandscapeDialog.show(
        context,
        title: entry.title,
        message: entry.text,
        barrierDismissible: false,
      );
      await db.settingsDao.setSetting('campaign_mystic_presence_seen_v1', '1');
    }
    if (!mounted) return;
    if (_isBloodBoss &&
        await db.settingsDao.getSetting('blood_mystic_space_hint_seen_v1') !=
            '1' &&
        mounted) {
      await LandscapeDialog.show(
        context,
        title: 'Carry It Outward',
        message:
            'Do not keep it here.\n\nThe stars are not above this world. They are part of the seal. Bring the blood mystic outward, where the last offering can be witnessed.',
      );
      await db.settingsDao.setSetting('blood_mystic_space_hint_seen_v1', '1');
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Parses placement snapshots and returns the dominant nature plus averaged
  /// genetic Potential. Mystic rituals reward strong sacrifices with a modest
  /// +10 Potential lift without inheriting current Power or Enhancement.
  Map<String, dynamic> _deriveFromSacrifices(List<AltarPlacement> placements) {
    final natureCounts = <String, int>{};
    double totalSpeed = 0;
    double totalIntelligence = 0;
    double totalStrength = 0;
    double totalBeauty = 0;
    int count = 0;

    for (final p in placements) {
      if (p.snapshotJson == null) continue;
      try {
        final snap = jsonDecode(p.snapshotJson!) as Map<String, dynamic>;
        for (final natureId in [snap['natureId'], snap['natureId2']]) {
          if (natureId is String && natureId.isNotEmpty) {
            natureCounts[natureId] = (natureCounts[natureId] ?? 0) + 1;
          }
        }
        final version = (snap['scaleVersion'] as num?)?.toInt() ?? 1;
        double potential(String key, String legacyKey) {
          final direct = snap[key] as num?;
          if (direct != null) {
            return AlchemonStatSystem.normalizePotential(
              direct,
              legacyScale: version < 2 && direct <= 5,
            ).toDouble();
          }
          // Placements made before the Potential migration only retained a
          // current 0-5 stat snapshot. Convert it once for save compatibility.
          final legacy = (snap[legacyKey] as num?)?.toDouble() ?? 3.0;
          return AlchemonStatSystem.normalizePotential(
            legacy,
            legacyScale: true,
          ).toDouble();
        }

        totalSpeed += potential('speedPotential', 'speed');
        totalIntelligence += potential('intelligencePotential', 'intelligence');
        totalStrength += potential('strengthPotential', 'strength');
        totalBeauty += potential('beautyPotential', 'beauty');
        count++;
      } catch (_) {
        // Malformed snapshot — skip, defaults will be used.
      }
    }

    // Dominant nature = most common; ties are broken by first encountered.
    final dominantNatures = natureCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const mysticBonus = 10.0;
    double avg(double total) =>
        count > 0 ? (total / count + mysticBonus).clamp(1.0, 100.0) : 75.0;

    return {
      'natureId': dominantNatures.isEmpty ? null : dominantNatures.first.key,
      'natureId2': dominantNatures.length < 2 ? null : dominantNatures[1].key,
      'speed': avg(totalSpeed),
      'intelligence': avg(totalIntelligence),
      'strength': avg(totalStrength),
      'beauty': avg(totalBeauty),
    };
  }

  Map<String, dynamic> _payload(
    Creature sp,
    AltarEntry boss,
    Map<String, dynamic> sacrificePayload,
  ) => {
    'baseId': sp.id,
    'rarity': 'Mythic',
    'source': 'boss_summon',
    'bossId': boss.id,
    'bossName': boss.name,
    'element': boss.element,
    'isPrismaticSkin': false,
    'genetics': {},
    if (sacrificePayload['natureId'] != null)
      'natureId': sacrificePayload['natureId'],
    if (sacrificePayload['natureId2'] != null)
      'natureId2': sacrificePayload['natureId2'],
    'stats': {
      'speed': 0.0,
      'intelligence': 0.0,
      'strength': 0.0,
      'beauty': 0.0,
    },
    'statPotentials': {
      'scaleVersion': 2,
      'speed': sacrificePayload['speed'],
      'intelligence': sacrificePayload['intelligence'],
      'strength': sacrificePayload['strength'],
      'beauty': sacrificePayload['beauty'],
    },
    'lineage': {
      'generationDepth': 0,
      'factionLineage': {},
      'elementLineage': {boss.element.toLowerCase(): 1},
      'familyLineage': {},
    },
  };

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final f = _field;
    return PopScope(
      canPop: _rite == _Rite.waiting && !_committing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _rite == _Rite.awake) _depart();
      },
      child: Scaffold(
        backgroundColor: AltarTone.void0,
        body: LayoutBuilder(
          builder: (context, box) {
            final pad = MediaQuery.paddingOf(context);
            final size = box.biggest;
            const headerH = 62.0;
            final panelH = (_isBloodBoss ? 262.0 : 200.0) + pad.bottom;
            final stage = Rect.fromLTRB(
              0,
              pad.top + headerH,
              size.width,
              math.max(pad.top + headerH + 160, size.height - panelH),
            );
            f?.layout(stage);
            f?.sealTo = Offset(size.width / 2, size.height + 60);
            final calm = _rite == _Rite.waiting;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onTapUp,
                    child: RepaintBoundary(
                      child: f == null
                          ? const SizedBox()
                          : CustomPaint(
                              painter: _RitePainter(f, stage, repaint: _clock),
                            ),
                    ),
                  ),
                ),
                if (f != null && calm && !_loading) ..._seatLabels(f),
                if (f != null && _mystic != null && !calm) _sprite(f),
                Positioned(
                  left: 0,
                  right: 0,
                  top: pad.top,
                  height: headerH,
                  child: _fade(calm, _header()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: panelH,
                  child: _fade(
                    calm,
                    _loading ? const SizedBox() : _panel(pad.bottom),
                  ),
                ),
                if (_rite == _Rite.awake || _rite == _Rite.sealing)
                  Positioned.fill(child: _awakeCard(stage, pad.bottom)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fade(bool shown, Widget child) => IgnorePointer(
    ignoring: !shown,
    child: AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: const Duration(milliseconds: 380),
      child: child,
    ),
  );

  List<Widget> _seatLabels(AltarRiteField f) {
    return [
      for (var i = 0; i < f.offerings.length; i++)
        Builder(
          builder: (context) {
            final o = f.offerings[i];
            final at = f.seatCentre(i) + const Offset(0, 34);
            final given = o.given;
            final none = !given && o.available == 0;
            final dup =
                _species.where((s) => s.name == o.species.name).length > 1;
            return Positioned(
              left: at.dx - 60,
              top: at.dy,
              width: 120,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text(
                      o.species.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: altarMono(
                        9,
                        given
                            ? altarInk(_boss.element)
                            : none
                            ? AltarTone.muted.withValues(alpha: 0.7)
                            : AltarTone.parchmentDim,
                        spacing: 1.2,
                      ),
                    ),
                    if (dup)
                      Text(
                        o.species.rarity.toUpperCase(),
                        style: altarMono(
                          8,
                          AltarTone.parchmentDim.withValues(alpha: 0.8),
                          spacing: 1.2,
                          weight: FontWeight.w600,
                        ),
                      ),
                    if (!given)
                      Text(
                        none ? 'NONE HELD' : '${o.available} HELD',
                        style: altarMono(
                          8,
                          AltarTone.muted.withValues(alpha: none ? 0.6 : 0.9),
                          spacing: 1.2,
                          weight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
    ];
  }

  Widget _sprite(AltarRiteField f) {
    final m = _mystic!;
    if (m.spriteData == null) return const SizedBox();
    final sheet = sheetFromCreature(m);
    final r = f.mysticRect;
    return Positioned.fromRect(
      rect: r,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: _clock,
          builder: (context, _, child) {
            var o = AltarRiteField.spriteOpacity(f.summon);
            if (f.seal > 0) o *= 1 - (f.seal / 0.12).clamp(0.0, 1.0);
            // Below a hair it is not painted, and the sheet can still load.
            return Opacity(opacity: o.clamp(0.01, 1.0), child: child);
          },
          child: CreatureSprite(
            spritePath: sheet.path,
            totalFrames: sheet.totalFrames,
            rows: sheet.rows,
            frameSize: sheet.frameSize,
            stepTime: sheet.stepTime,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final ink = altarInk(_boss.element);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.chevron_left_rounded,
            palette: altarPalette,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${_boss.element.toUpperCase()} ALTAR',
              style: altarMono(11.5, AltarTone.parchmentDim, spacing: 2.8),
            ),
          ),
          Text(
            _hasRelic ? _relicName.toUpperCase() : 'NO RELIC',
            style: altarMono(
              10.5,
              _hasRelic ? ink : AltarTone.muted,
              spacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(double bottomInset) {
    final accent = altarAccent(_boss.element);
    final total = _species.length;
    final given = _givenCount;
    final status = !_hasRelic
        ? 'The $_relicName is not on the altar.'
        : !_allGiven
        ? 'Tap a seat to give one of each kind: $given of $total given. '
              'What is given passes its potential to $_mysticName.'
        : !_allWitnessed
        ? 'Every offering is given. The rite needs all sixteen Mystics '
              'awake: $_witnessesAwake of 16.'
        : 'Every offering is given. The rite can be performed.';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF2040307), Color(0x00040307)],
          stops: [0.62, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 14, 24, 16 + bottomInset),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _mysticName,
                      maxLines: 1,
                      style: altarName(context, 30),
                    ),
                  ),
                ),
                Text(
                  '$given / $total',
                  style: altarMono(
                    12,
                    _allGiven ? altarInk(_boss.element) : AltarTone.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Text(
                status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: altarBody(context),
              ),
            ),
            if (_isBloodBoss) ...[
              const SizedBox(height: 10),
              _WitnessRow(witnesses: _witnesses),
            ],
            const SizedBox(height: 14),
            AltarHoldButton(
              label: 'HOLD TO PERFORM THE RITE',
              holdingLabel: 'THE RITE BEGINS',
              accent: accent,
              seconds: 1.6,
              enabled: _canSummon,
              onProgress: (v) => _field?.charge = v,
              onComplete: _perform,
            ),
          ],
        ),
      ),
    );
  }

  /// The waking, named: what woke, how many now are, and where it went.
  Widget _awakeCard(Rect stage, double bottomInset) {
    final ink = altarInk(_boss.element);
    final count = _awakeAfter.length;
    return IgnorePointer(
      ignoring: _rite != _Rite.awake,
      child: AnimatedOpacity(
        opacity: _rite == _Rite.awake ? 1 : 0,
        duration: Duration(milliseconds: _rite == _Rite.awake ? 900 : 300),
        child: Column(
          children: [
            SizedBox(height: stage.top - 6),
            Text(
              _firstAwakening ? 'MYSTIC AWAKENED' : 'MYSTIC SUMMONED',
              textAlign: TextAlign.center,
              style: altarMono(12, ink, spacing: 4.2),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomInset),
              child: Column(
                children: [
                  Text(
                    _mysticName,
                    textAlign: TextAlign.center,
                    style: altarName(context, 40),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_boss.element.toUpperCase()} MYSTIC',
                    style: altarMono(10.5, AltarTone.parchmentDim, spacing: 3),
                  ),
                  if (_firstAwakening) ...[
                    const SizedBox(height: 18),
                    _AwakeDots(awake: _awakeAfter, current: _boss.id),
                    const SizedBox(height: 8),
                    Text(
                      '$count OF 17 AWAKE',
                      style: altarMono(10.5, AltarTone.gold, spacing: 2.4),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _inChamber
                        ? 'Sealed as a cultivation in your Chamber. It is ready in an hour.'
                        : 'Your Chamber is full, so its cultivation waits in Cold Storage. It cultivates for an hour.',
                    textAlign: TextAlign.center,
                    style: altarBody(context),
                  ),
                  const SizedBox(height: 18),
                  BracketButton(
                    label: 'SEAL AND DEPART',
                    palette: altarPalette,
                    accent: altarAccent(_boss.element),
                    height: 50,
                    onTap: _depart,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RitePainter extends CustomPainter {
  _RitePainter(this.field, this.stage, {required super.repaint});

  final AltarRiteField field;
  final Rect stage;

  @override
  void paint(Canvas canvas, Size size) => field.paint(canvas, size, stage);

  @override
  bool shouldRepaint(_RitePainter old) =>
      old.field != field || old.stage != stage;
}

/// Blood's witnesses: the sixteen, each a bead of its element, lit once its
/// Mystic is awake.
class _WitnessRow extends StatelessWidget {
  const _WitnessRow({required this.witnesses});

  final List<_Witness> witnesses;

  @override
  Widget build(BuildContext context) {
    final awake = witnesses.where((w) => w.awake).length;
    return Row(
      children: [
        Text('WITNESSES', style: altarMono(9.5, AltarTone.muted, spacing: 2)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final w in witnesses)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: w.awake
                        ? altarAccent(w.entry.element)
                        : const Color(0xFF231E2E),
                    border: Border.all(
                      color: w.awake
                          ? altarRamp(w.entry.element)[3].withValues(alpha: 0.6)
                          : AltarTone.ash.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          '$awake / 16',
          style: altarMono(11, awake >= 16 ? AltarTone.blood : AltarTone.muted),
        ),
      ],
    );
  }
}

/// The seventeen, in altar order: the awake ones lit in their element, the
/// one just woken brightest.
class _AwakeDots extends StatelessWidget {
  const _AwakeDots({required this.awake, required this.current});

  final Set<String> awake;
  final String current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final e in kAltarEntries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: e.id == current ? 11 : 8,
              height: e.id == current ? 11 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: awake.contains(e.id)
                    ? altarAccent(e.element)
                    : const Color(0xFF231E2E),
                border: Border.all(
                  color: e.id == current
                      ? AltarTone.parchment
                      : awake.contains(e.id)
                      ? altarRamp(e.element)[3].withValues(alpha: 0.5)
                      : AltarTone.ash.withValues(alpha: 0.45),
                  width: e.id == current ? 1.4 : 0.8,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THE OFFERING SHEET
// ─────────────────────────────────────────────────────────────────────────────

/// Choose which specimen to give, then hold to give it. Best potential first:
/// the Mystic takes the average of what it is given.
class _OfferingSheet extends StatefulWidget {
  const _OfferingSheet({
    required this.species,
    required this.title,
    required this.instances,
    required this.element,
    required this.mysticName,
  });

  final Creature species;
  final String title;
  final List<CreatureInstance> instances;
  final String element;
  final String mysticName;

  @override
  State<_OfferingSheet> createState() => _OfferingSheetState();
}

class _OfferingSheetState extends State<_OfferingSheet> {
  CreatureInstance? _chosen;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final accent = altarAccent(widget.element);
    final chosen = _chosen;
    final listH = math.min(
      media.size.height * 0.46,
      widget.instances.length * 78.0,
    );
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.7),
        bracketSize: 16,
        strokeWidth: 1.2,
      ),
      child: Container(
        color: const Color(0xFA0B0812),
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + media.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AN OFFERING',
              style: altarMono(10.5, altarInk(widget.element), spacing: 2.4),
            ),
            const SizedBox(height: 4),
            Text(widget.title, style: altarName(context, 24)),
            const SizedBox(height: 6),
            Text(
              'The one you give leaves your collection for good. '
              '${widget.mysticName} takes the average potential of its '
              'offerings, and their most common nature.',
              style: altarBody(context, size: 12.5),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: listH,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: widget.instances.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final inst = widget.instances[i];
                  return _SpecimenTile(
                    species: widget.species,
                    instance: inst,
                    accent: accent,
                    chosen: identical(inst, chosen),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _chosen = inst);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            AltarHoldButton(
              label: chosen == null
                  ? 'CHOOSE ONE TO GIVE'
                  : 'HOLD TO GIVE ${(chosen.nickname ?? widget.species.name).toUpperCase()}',
              holdingLabel: 'GIVING',
              accent: accent,
              seconds: 1.0,
              enabled: chosen != null,
              onComplete: () => Navigator.of(context).pop(chosen),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecimenTile extends StatelessWidget {
  const _SpecimenTile({
    required this.species,
    required this.instance,
    required this.accent,
    required this.chosen,
    required this.onTap,
  });

  final Creature species;
  final CreatureInstance instance;
  final Color accent;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nature = instance.natureId;
    final pots = [
      ('SPD', instance.statSpeedPotential),
      ('INT', instance.statIntelligencePotential),
      ('STR', instance.statStrengthPotential),
      ('BEA', instance.statBeautyPotential),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: chosen ? accent : altarPalette.line.withValues(alpha: 0.6),
          bracketSize: 9,
          strokeWidth: chosen ? 1.3 : 1,
        ),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: chosen
              ? accent.withValues(alpha: 0.1)
              : altarPalette.surfaceMutedFill(),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: Image.asset(
                  'assets/images/${species.image}',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instance.nickname ?? species.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: altarBody(
                        context,
                        color: AltarTone.parchment,
                        size: 14,
                      ),
                    ),
                    Text(
                      'LV ${instance.level}${nature == null ? '' : '  ·  ${nature.toUpperCase()}'}',
                      style: altarMono(9.5, AltarTone.muted, spacing: 1.4),
                    ),
                  ],
                ),
              ),
              for (final (label, v) in pots)
                SizedBox(
                  width: 36,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        v.round().toString(),
                        style: altarMono(
                          13,
                          v >= 80
                              ? AltarTone.gold
                              : AltarTone.parchment.withValues(alpha: 0.9),
                          spacing: 0.5,
                        ),
                      ),
                      Text(
                        label,
                        style: altarMono(
                          7.5,
                          AltarTone.muted,
                          spacing: 1,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
