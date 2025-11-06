// lib/battle/battle_bootstrap.dart
import 'package:alchemons/battle/arena_bridge.dart';
import 'package:alchemons/battle/battle_game_core.dart';
import 'package:alchemons/battle/floating_overlay_arena_adapter.dart';
import 'package:flutter/material.dart';

class BattleBootstrap with ChangeNotifier {
  late final BattleState state;
  late final TurnController turn;
  late final CombatResolver combat;
  late final SimpleAIPlanner ai;
  late final FloatingOverlayArenaAdapter arena;
  late final ArenaBridge bridge;
  final Size arenaSize;

  BattleBootstrap(
    this.arenaSize, {
    required List<BattleCreature> playerTeam10,
    required List<BattleCreature> aiTeam10,
  }) {
    // 1) Normalize teams by cloning (don't rely on mutating incoming objects)
    final pAll = _cloneTeamAs(playerTeam10, teamIndex: 0);
    final aAll = _cloneTeamAs(aiTeam10, teamIndex: 1);

    // 2) Start 1v1 on field, rest to bench
    final pField = <BattleCreature>[
      pAll.first.copyWith(onField: true, bubble: null),
    ];
    final aField = <BattleCreature>[
      aAll.first.copyWith(onField: true, bubble: null),
    ];
    final pBench = pAll
        .skip(1)
        .map((c) => c.copyWith(onField: false, bubble: null))
        .toList();
    final aBench = aAll
        .skip(1)
        .map((c) => c.copyWith(onField: false, bubble: null))
        .toList();

    state = BattleState(
      playerBench: pBench,
      aiBench: aBench,
      playerField: pField,
      aiField: aField,
      zoneP: TargetZone(Offset(120, arenaSize.height - 80), 90, 60, 30),
      zoneA: TargetZone(Offset(arenaSize.width - 120, 80), 90, 60, 30),
    );

    turn = TurnController(state);
    combat = CombatResolver(state);
    ai = SimpleAIPlanner();
    arena = FloatingOverlayArenaAdapter(size: arenaSize);

    // Wire up arena to notify bootstrap when things change
    arena.addListener(() {
      notifyListeners();
    });

    bridge = ArenaBridge(
      arena: arena,
      state: state,
      turn: turn,
      combat: combat,
      ai: ai,
    );
  }

  // Force-team clone (prevents accidental team==0 on AI)
  List<BattleCreature> _cloneTeamAs(
    List<BattleCreature> src, {
    required int teamIndex,
  }) {
    return src.map((c) => c.copyWith(team: teamIndex, bubble: null)).toList();
  }

  void start() {
    print('🎮 BattleBootstrap.start() - Arena size: $arenaSize');
    print(
      '🎮 Player field: ${state.playerField.length}, AI field: ${state.aiField.length}',
    );
    bridge.startMatch();
    print('🎮 Bubbles spawned: ${arena.allBubbles().length}');
    for (final b in arena.allBubbles()) {
      print('   - ${b.element} (team ${b.team}) at ${b.pos}');
    }
  }

  // per-frame from Ticker
  void tick(double dtSeconds) {
    arena.step(dtSeconds);
    bridge.tick(dtSeconds);
    notifyListeners();
  }
}
