import 'dart:async';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/battle_arena_art.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/models/battle_arenas.dart';
import 'package:alchemons/models/battle_record.dart';
import 'package:alchemons/models/battle_room.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/screens/battle/battle_how_to.dart';
import 'package:alchemons/screens/battle/battle_lobby_screen.dart';
import 'package:alchemons/screens/battle/battle_screen.dart';
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart' show stadiumSprite;
import 'package:alchemons/screens/stadium/stadium_screen.dart'
    show stadiumMemberOf;
import 'package:alchemons/services/battle_room_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/battle/battle_arena_preview.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter, elementLight;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE BATTLE HUB
//
//  Where a battle is set up: the arena you host in, shown live (the free
//  one or any bought; one not yet owned can be bought here), the four you
//  bring, the four the computer brings to match them, your record, BATTLE —
//  or WITH A FRIEND, live (battle_lobby_screen.dart).
//  The page is [BattleHubPanel]: the Trials show it under their BATTLE, the
//  developer tools under this screen's header.
// ─────────────────────────────────────────────────────────────────────────────

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bg = Color(0xFF09090B);
const Color _bg1 = Color(0xFF131316);

/// The four last brought to a battle (kept under [kBattleTeamKey]), or, for
/// a save that has never battled, its four strongest that can. None with no
/// save to read (the Trials under some tests).
Future<List<CosmicPartyMember>> loadBattleTeam(BuildContext context) async {
  final db = context.read<AlchemonsDatabase?>();
  final catalog = context.read<CreatureCatalog?>();
  if (db == null || catalog == null) return const [];
  final ids = (await db.settingsDao.getSetting(kBattleTeamKey) ?? '')
      .split(',')
      .where((id) => id.isNotEmpty)
      .toList();
  final insts = <CreatureInstance>[];
  for (final id in ids) {
    final inst = await db.creatureDao.getInstance(id);
    if (inst != null) insts.add(inst);
  }
  if (insts.isEmpty) {
    final all = await db.creatureDao.getAllInstances();
    double power(CreatureInstance i) =>
        i.statSpeed + i.statStrength + i.statIntelligence + i.statBeauty;
    final able = all.where((i) {
      final f = catalog.getCreatureById(i.baseId)?.mutationFamily ?? '';
      return f.isNotEmpty && f.toLowerCase() != 'mystic';
    }).toList()..sort((a, b) => power(b).compareTo(power(a)));
    insts.addAll(able.take(kBattleTeamSize));
  }
  if (!context.mounted) return const [];
  return [
    for (var i = 0; i < insts.length; i++)
      stadiumMemberOf(context, insts[i], slot: i),
  ];
}

/// The picker for the four brought to a battle, starting from [current]:
/// the four picked, kept for next time, or null when nothing was picked.
Future<List<CosmicPartyMember>?> pickBattleTeam(
  BuildContext context,
  List<CosmicPartyMember> current,
) async {
  final picked = await Navigator.push<List<PartyMember>>(
    context,
    MaterialPageRoute(
      builder: (_) => PartyPickerScreen(
        showDeployConfirm: false,
        enforceUniqueSpecies: false,
        allowMystics: false,
        maxSelections: kBattleTeamSize,
        initialSelection: [for (final m in current) m.instanceId],
        teamStorageKey: 'saved_teams_battle',
        confirmLabel: 'Done',
      ),
    ),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return null;
  await context.read<AlchemonsDatabase>().settingsDao.setSetting(
    kBattleTeamKey,
    [for (final m in picked) m.instanceId].join(','),
  );
  if (!context.mounted) return null;
  return loadBattleTeam(context);
}

class BattleHubScreen extends StatelessWidget {
  const BattleHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          SizedBox(height: pad.top + 6),
          _header(context),
          Expanded(
            child: BattleHubPanel(
              buttonPadding: EdgeInsets.fromLTRB(14, 10, 14, pad.bottom + 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: SizedBox(
      height: 56,
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back,
            onTap: () => Navigator.of(context).pop(),
            palette: BracketPalette.dark,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'BATTLE',
                  style: bracketText(
                    context,
                    16,
                    _brassHot,
                    weight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'TWO AT A TIME FROM FOUR',
                  style: bracketText(
                    context,
                    9.5,
                    _muted,
                    weight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const CurrencyDisplayWidget(palette: BracketPalette.dark),
        ],
      ),
    ),
  );
}

/// The hub's page under its header, which the Trials' BATTLE shows too:
/// the arena live under your record and RULES, the arena row (one not yet
/// owned is bought from it), your four, the computer's four, and BATTLE.
class BattleHubPanel extends StatefulWidget {
  const BattleHubPanel({
    super.key,
    this.stageHeight,
    this.shut,
    this.leaveLabel = 'BACK TO THE HUB',
    this.onTeam,
    this.afterBattle,
    this.contentPadding = const EdgeInsets.fromLTRB(14, 6, 14, 16),
    this.buttonPadding = const EdgeInsets.fromLTRB(14, 10, 14, 12),
    this.buttonHeight = 52,
  });

  /// How tall the live arena stands; null is about a quarter of the
  /// screen.
  final double? stageHeight;

  /// Why a battle cannot be started yet (the Trials open battles with the
  /// gem cups), or null when it can.
  final String? shut;

  /// The result card's way out.
  final String leaveLabel;

  /// Told the four whenever they change: the Trials' ladder fights with
  /// the same four.
  final ValueChanged<List<CosmicPartyMember>>? onTeam;

  /// After each fight, back on the page (the Trials put their music back).
  final VoidCallback? afterBattle;

  final EdgeInsets contentPadding;
  final EdgeInsets buttonPadding;
  final double buttonHeight;

  @override
  State<BattleHubPanel> createState() => _BattleHubPanelState();
}

class _BattleHubPanelState extends State<BattleHubPanel> {
  List<CosmicPartyMember> _team = const [];
  List<CosmicPartyMember> _rival = const [];
  int _rivalSeed = Random().nextInt(1 << 30);
  String _arena = kDefaultBattleArena;
  Set<String> _owned = {kDefaultBattleArena};
  BattleRecord _record = const BattleRecord();
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(first: true));
  }

  AlchemonsDatabase get _db => context.read<AlchemonsDatabase>();

  Future<void> _load({bool first = false}) async {
    final settings = _db.settingsDao;
    final team = await loadBattleTeam(context);
    final arena = await chosenBattleArena(settings);
    final owned = await ownedBattleArenas(settings);
    final record = await BattleRecord.load(settings);
    if (!mounted) return;
    setState(() {
      _team = team;
      _arena = arena;
      _owned = owned;
      _record = record;
      _rival = _rollRival();
      _loading = false;
    });
    widget.onTeam?.call(team);
    // The first time a battle is opened, once the page is up: the rules.
    if (first && widget.shut == null) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) await maybeShowBattleHowTo(context);
    }
  }

  List<CosmicPartyMember> _rollRival() => _team.isEmpty
      ? const []
      : battleRivalFor(
          context.read<CreatureCatalog>(),
          _team,
          seed: _rivalSeed,
        );

  Future<void> _changeTeam() async {
    if (_starting) return;
    final picked = await pickBattleTeam(context, _team);
    if (picked == null || !mounted) return;
    await _load();
  }

  void _newRival() {
    HapticFeedback.selectionClick();
    setState(() {
      _rivalSeed++;
      _rival = _rollRival();
    });
  }

  Future<void> _tapArena(BattleArena arena) async {
    if (_owned.contains(arena.id)) {
      HapticFeedback.selectionClick();
      await chooseBattleArena(_db.settingsDao, arena.id);
      if (mounted) setState(() => _arena = arena.id);
      return;
    }
    final buy = await showBracketConfirm(
      context,
      palette: BracketPalette.dark,
      accent: kBattleBrass,
      title: arena.title.toUpperCase(),
      message: arena.line,
      amounts: [(CoinKind.gold, arena.gold)],
      amountsLabel: 'COSTS',
      confirmLabel: 'BUY',
    );
    if (!buy || !mounted) return;
    final ok = await context.read<ShopService>().purchase(arena.offerId);
    if (!mounted) return;
    if (!ok) {
      showGameSnack(context, 'Not enough gold.');
      return;
    }
    HapticFeedback.mediumImpact();
    await chooseBattleArena(_db.settingsDao, arena.id);
    final owned = await ownedBattleArenas(_db.settingsDao);
    if (!mounted) return;
    setState(() {
      _owned = owned;
      _arena = arena.id;
    });
    showGameSnack(context, '${arena.title} unlocked');
  }

  Future<void> _battle() async {
    if (_team.isEmpty || _starting || widget.shut != null) return;
    _starting = true;
    try {
      HapticFeedback.mediumImpact();
      // Not seen yet (the page opened before it could ask): the rules first.
      await maybeShowBattleHowTo(context);
      if (!mounted) return;
      // The arena on the stage flies into the fight, and back after.
      final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
      final from = box == null || !box.hasSize
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await Navigator.of(context).push(
        BattleScreen.route(
          BattleScreen(
            team: _team,
            rival: _rival,
            arena: _arena,
            leaveLabel: widget.leaveLabel,
            onFinished: _recordResult,
            fromRect: from,
          ),
        ),
      );
      if (mounted) widget.afterBattle?.call();
    } finally {
      _starting = false;
    }
  }

  final GlobalKey _stageKey = GlobalKey();

  Future<void> _recordResult(int? winner, double at) async {
    final record = _record.after(winner);
    await record.save(_db.settingsDao);
    if (mounted) setState(() => _record = record);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.expand();
    final size = MediaQuery.sizeOf(context);
    final arena = battleArenaOf(_arena);
    final shut = widget.shut;
    // Battling a friend, live: for a player signed in with friends.
    final rooms = context.watch<BattleRoomService?>();
    final withFriends = shut == null && rooms != null && rooms.available;
    final invites = withFriends ? rooms.invites : const <BattleRoom>[];
    final invite = invites.isEmpty ? null : invites.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: widget.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stage(context, arena, size),
                const SizedBox(height: 14),
                _label(context, 'ARENA', trailing: 'YOU HOST IN IT'),
                const SizedBox(height: 8),
                _arenaRow(context),
                const SizedBox(height: 18),
                _label(context, 'YOUR FOUR', action: ('CHANGE', _changeTeam)),
                const SizedBox(height: 8),
                _teamRow(context),
                const SizedBox(height: 18),
                _label(
                  context,
                  'AGAINST THE COMPUTER',
                  action: ('NEW RIVAL', _newRival),
                ),
                const SizedBox(height: 8),
                _rivalRow(context),
              ],
            ),
          ),
        ),
        // Why not yet, over the button that says so.
        if (shut != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              shut,
              textAlign: TextAlign.center,
              style: bracketText(context, 12.5, _ink.withValues(alpha: .8)),
            ),
          ),
        if (invite != null && rooms != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _inviteSlip(context, rooms, invite),
          ),
        Padding(
          padding: widget.buttonPadding,
          child: Row(
            children: [
              if (withFriends) ...[
                Expanded(
                  child: BracketButton(
                    key: const ValueKey('battle.friend'),
                    label: 'WITH A FRIEND',
                    enabled: !_starting,
                    onTap: _withFriend,
                    palette: BracketPalette.dark,
                    accent: kBattleBrass,
                    primary: false,
                    height: widget.buttonHeight,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: BracketButton(
                  key: const ValueKey('battle.start'),
                  label: shut != null ? 'LOCKED' : 'BATTLE',
                  enabled: _team.isNotEmpty && shut == null,
                  onTap: _battle,
                  palette: BracketPalette.dark,
                  accent: kBattleBrass,
                  height: widget.buttonHeight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// WITH A FRIEND: a room in your arena, and its lobby (INVITE there).
  Future<void> _withFriend() async {
    if (_starting) return;
    _starting = true;
    try {
      HapticFeedback.selectionClick();
      await BattleLobbyScreen.host(context);
      if (mounted) {
        widget.afterBattle?.call();
        await _load();
      }
    } finally {
      _starting = false;
    }
  }

  /// A friend's invitation to battle, waiting: JOIN or DECLINE.
  Widget _inviteSlip(
    BuildContext context,
    BattleRoomService rooms,
    BattleRoom room,
  ) => CustomPaint(
    foregroundPainter: BracketFramePainter(
      color: kBattleBrass.withValues(alpha: 0.6),
    ),
    child: Container(
      color: _bg1,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${room.nameOf(room.host).toUpperCase()} ASKS YOU TO BATTLE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(
                context,
                10,
                _ink,
                weight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final (label, join) in const [
            ('DECLINE', false),
            ('JOIN', true),
          ])
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                HapticFeedback.selectionClick();
                if (!join) {
                  await rooms.decline(room);
                  return;
                }
                await BattleLobbyScreen.open(context, room.id);
                if (mounted) {
                  widget.afterBattle?.call();
                  await _load();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Text(
                  label,
                  style: bracketText(
                    context,
                    10,
                    join ? kBattleBrass : _muted,
                    weight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _label(
    BuildContext context,
    String text, {
    String? trailing,
    (String, VoidCallback)? action,
  }) => Row(
    children: [
      Text(
        text,
        style: bracketText(
          context,
          10,
          _muted,
          weight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
      const Spacer(),
      if (trailing != null)
        Text(
          trailing,
          style: bracketText(
            context,
            8.5,
            _muted.withValues(alpha: 0.7),
            weight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      if (action != null)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action.$2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              action.$1,
              style: bracketText(
                context,
                10,
                kBattleBrass,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),
    ],
  );

  /// The chosen arena, live, with its name over it; the record and RULES
  /// along its top.
  Widget _stage(BuildContext context, BattleArena arena, Size size) {
    final h = widget.stageHeight ?? (size.height * 0.26).clamp(150.0, 260.0);
    return SizedBox(
      height: h,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: kBattleBrass.withValues(alpha: 0.7),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BattleArenaPreview(key: _stageKey, arena: arena.id),
            Positioned(
              left: 12,
              right: 2,
              top: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _record.played == 0
                          ? 'NO BATTLES YET'
                          : 'WON ${_record.wins} · LOST ${_record.losses}'
                                '${_record.draws > 0 ? ' · DRAWN ${_record.draws}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        9.5,
                        _muted,
                        weight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showBattleHowTo(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'RULES',
                        style: bracketText(
                          context,
                          10,
                          kBattleBrass,
                          weight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    arena.title.toUpperCase(),
                    style: bracketText(
                      context,
                      14,
                      _ink,
                      weight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    arena.line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(context, 11, _muted).copyWith(
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arenaRow(BuildContext context) => Row(
    children: [
      for (var i = 0; i < kBattleArenas.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: _arenaTile(context, kBattleArenas[i])),
      ],
    ],
  );

  Widget _arenaTile(BuildContext context, BattleArena arena) {
    final owned = _owned.contains(arena.id);
    final chosen = arena.id == _arena;
    return GestureDetector(
      key: ValueKey('battle.arena.${arena.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapArena(arena),
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: chosen
                    ? kBattleBrass.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: owned ? 1 : 0.45,
                    child: BattleArenaPreview(arena: arena.id, live: false),
                  ),
                  if (!owned)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinIcon(kind: CoinKind.gold, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${arena.gold}',
                            style: bracketText(
                              context,
                              11,
                              _ink,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            arena.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bracketText(
              context,
              8,
              chosen ? kBattleBrass : _muted,
              weight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamRow(BuildContext context) => Row(
    children: [
      for (var i = 0; i < kBattleTeamSize; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _changeTeam,
            child: i < _team.length
                ? BattleCase(member: _team[i], height: 104)
                : const BattleEmptyCase(height: 104),
          ),
        ),
      ],
    ],
  );

  Widget _rivalRow(BuildContext context) => Row(
    children: [
      for (var i = 0; i < kBattleTeamSize; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: i < _rival.length
              ? BattleCase(member: _rival[i], height: 84, rival: true)
              : const BattleEmptyCase(height: 84),
        ),
      ],
    ],
  );
}

/// One Alchemon in a lit specimen case: its element's light, its sprite,
/// its level, its name engraved under it.
class BattleCase extends StatelessWidget {
  const BattleCase({
    super.key,
    required this.member,
    required this.height,
    this.rival = false,
  });

  final CosmicPartyMember member;
  final double height;
  final bool rival;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: CaseLightPainter(
              color: elementLight(member.element),
              strength: rival ? 0.65 : 1,
            ),
            child: Stack(
              children: [
                Center(
                  child: SizedBox.square(
                    dimension: height * 0.58,
                    child: stadiumSprite(member, height * 0.58),
                  ),
                ),
                Positioned(
                  left: 5,
                  top: 4,
                  child: Text(
                    'LV ${member.level}',
                    style: bracketText(
                      context,
                      8,
                      _muted,
                      weight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 18,
          color: _bg1,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            member.displayName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bracketText(
              context,
              8,
              rival ? kBattleSilver : _ink,
              weight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    ),
  );
}

class BattleEmptyCase extends StatelessWidget {
  const BattleEmptyCase({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    color: _bg1,
    alignment: Alignment.center,
    child: Icon(AppIcons.add, color: _muted.withValues(alpha: 0.5), size: 18),
  );
}
