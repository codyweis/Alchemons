import 'dart:async';

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:flutter/material.dart';

/// Where a task sends you. Some places are tabs in the shell, the rest are
/// screens pushed over it, and the Go button has to handle both.
enum TaskDestination {
  shop(section: NavSection.shop),
  inventory(section: NavSection.inventory),
  creatures(section: NavSection.creatures),
  enhance(),
  harvest(),
  rite(),
  constellation(),
  profile();

  const TaskDestination({this.section});

  /// Null for a pushed screen.
  final NavSection? section;
}

/// What has to be true before a task is worth showing.
///
/// Each mirrors the gate on the real entry point, so a task cannot advertise
/// a button that is not there.
enum TaskGate {
  /// Always reachable.
  always,

  /// The forge opens with the Elemental Creator.
  enhanceUnlocked,

  /// The altar appears once any relic is held or placed.
  anyRelic,

}

/// A place in the game the player may not know exists.
///
/// These are not achievements. An achievement records something you managed;
/// a task points at a door. So they pay a flat rate, they are marked done by
/// arriving — the arrival IS the lesson — and they leave the list once seen,
/// because a checklist of places you have already been is furniture.
class OnboardingTask {
  const OnboardingTask({
    required this.id,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.destination,
    this.gate = TaskGate.always,
  });

  final String id;
  final String title;

  /// One line on what the place is FOR. The title says where; this says why
  /// you would ever go.
  final String blurb;
  final IconData icon;
  final TaskDestination destination;

  /// Whether this place exists for the player yet.
  ///
  /// A task is an advertisement, and advertising a door that will not open
  /// is worse than saying nothing — it is the spoiler-and-dead-control
  /// problem the Survival dock button already had. Locked tasks are absent,
  /// not greyed, and they appear when the place does.
  final TaskGate gate;

  /// Set when the player arrives. The reward is not paid here — arriving
  /// earns it, the journal is where it is collected.
  String get settingKey => 'task_seen_$id';

  String get claimedKey => 'task_claimed_$id';
}

/// The same for every task. Enough to matter early, not enough to be worth
/// farming — and they cannot be farmed anyway, since a task can only be
/// earned once.
const int kTaskSilverReward = 100;

const List<OnboardingTask> kOnboardingTasks = [
  OnboardingTask(
    id: 'shop',
    title: 'Visit the market',
    blurb: 'Spend silver and gold on devices, keys and consumables.',
    icon: AppIcons.storefront_rounded,
    destination: TaskDestination.shop,
  ),
  OnboardingTask(
    id: 'inventory',
    title: 'Open your inventory',
    blurb: 'Everything you are carrying, and what each piece of it does.',
    icon: AppIcons.inventory_2_rounded,
    destination: TaskDestination.inventory,
  ),
  OnboardingTask(
    id: 'battle_tab',
    title: 'Read an Alchemon',
    blurb: 'Each specimen has a battle profile — its family decides how it '
        'fights.',
    icon: AppIcons.pets_rounded,
    destination: TaskDestination.creatures,
  ),
  OnboardingTask(
    id: 'enhance',
    title: 'Find the forge',
    blurb: 'Sacrifice spare specimens for levels, or infuse a stat directly.',
    icon: AppIcons.auto_awesome_rounded,
    destination: TaskDestination.enhance,
    gate: TaskGate.enhanceUnlocked,
  ),
  OnboardingTask(
    id: 'harvest',
    title: 'Visit harvest',
    blurb: 'Send a harvester out and pull elemental matter from the wild.',
    icon: AppIcons.science_rounded,
    destination: TaskDestination.harvest,
  ),
  OnboardingTask(
    id: 'rite',
    title: 'Approach the altar',
    blurb: 'The rite turns what you have gathered into something rarer.',
    icon: AppIcons.auto_fix_high_rounded,
    destination: TaskDestination.rite,
    gate: TaskGate.anyRelic,
  ),
  OnboardingTask(
    id: 'constellation',
    title: 'Look up',
    blurb: 'Constellation points buy permanent upgrades to everything else.',
    icon: AppIcons.nights_stay_rounded,
    // Ungated, because its button on the home screen is ungated. This was
    // wrongly gated on the ship: constellation_points_widget.dart holds two
    // widgets, and the ship check belongs to the OTHER one — the orb that
    // opens cosmic space. The upgrade tree has always been open.
    destination: TaskDestination.constellation,
  ),
  OnboardingTask(
    id: 'profile',
    title: 'Check your profile',
    blurb: 'Your faction, your records, and the settings for this save.',
    icon: AppIcons.person_rounded,
    destination: TaskDestination.profile,
  ),
];

/// Where a task is in its short life.
enum TaskState {
  /// Not visited. Shows a GO button.
  todo,

  /// Visited, reward not taken. Shows a COLLECT button.
  earned,

  /// Collected. Gone from the list.
  claimed,
}

/// Records arrivals, and pays for them when the player comes back to collect.
///
/// Paying on arrival was simpler but silent: the reward landed while the
/// player was busy looking at a room they had never seen, so the one thing
/// they were supposed to notice was the thing they missed. Earning and
/// collecting are separate now, the same way achievements work here.
class OnboardingTaskService {
  const OnboardingTaskService(this.db);

  final AlchemonsDatabase db;

  /// Whether the place this task points at exists yet.
  ///
  /// Each check mirrors the real entry point's own condition; if one of
  /// those moves, this is the second place to change, which is why the
  /// mirroring is named rather than inlined.
  Future<bool> unlocked(OnboardingTask task, {ShopService? shop}) async {
    switch (task.gate) {
      case TaskGate.always:
        return true;
      case TaskGate.enhanceUnlocked:
        // Mirrors the dock's lockEnhance.
        return shop?.hasElementalCreatorUnlocked() ?? false;
      case TaskGate.anyRelic:
        // Mirrors the home screen's _hasAnyRelic: held, or already placed.
        for (final entry in kAltarEntries) {
          final qty = await db.inventoryDao.getItemQty(
            BossLootKeys.traitKeyForElement(entry.element),
          );
          if (qty > 0) return true;
        }
        final placed = await db.altarDao.getRelicPlacedIds(
          kAltarEntries.map((e) => e.id).toList(),
        );
        return placed.isNotEmpty;
    }
  }

  Future<TaskState> stateOf(OnboardingTask task) async {
    if (await db.settingsDao.getSetting(task.claimedKey) == '1') {
      return TaskState.claimed;
    }
    if (await db.settingsDao.getSetting(task.settingKey) == '1') {
      return TaskState.earned;
    }
    return TaskState.todo;
  }

  /// Every task still worth showing, with its state. Claimed ones are gone,
  /// and so are ones whose place does not exist yet.
  Future<List<(OnboardingTask, TaskState)>> outstanding({
    ShopService? shop,
  }) async {
    final rows = <(OnboardingTask, TaskState)>[];
    for (final task in kOnboardingTasks) {
      final state = await stateOf(task);
      if (state == TaskState.claimed) continue;
      // An earned reward is always collectable, even if the gate somehow
      // closed behind them — the player did the thing.
      if (state == TaskState.todo && !await unlocked(task, shop: shop)) {
        continue;
      }
      rows.add((task, state));
    }
    return rows;
  }

  /// How many rewards are sitting uncollected — what the home badge counts.
  /// Gates do not apply: an earned reward is earned.
  Future<int> readyCount() async {
    var n = 0;
    for (final task in kOnboardingTasks) {
      if (await stateOf(task) == TaskState.earned) n++;
    }
    return n;
  }

  /// Marks [id] arrived at. Returns true only the first time, which is what
  /// the arrival notification hangs off.
  ///
  /// Safe to call from a screen's initState on every visit: the second call
  /// is a no-op.
  Future<bool> markVisited(String id) async {
    final matches = kOnboardingTasks.where((t) => t.id == id);
    if (matches.isEmpty) return false;
    final task = matches.first;
    if (await db.settingsDao.getSetting(task.settingKey) == '1') return false;
    await db.settingsDao.setSetting(task.settingKey, '1');
    return true;
  }

  /// Pays for an earned task, once.
  Future<bool> claim(String id) async {
    final matches = kOnboardingTasks.where((t) => t.id == id);
    if (matches.isEmpty) return false;
    final task = matches.first;
    if (await stateOf(task) != TaskState.earned) return false;
    await db.settingsDao.setSetting(task.claimedKey, '1');
    await db.currencyDao.addSilver(kTaskSilverReward);
    return true;
  }

  /// Marks an arrival and, if it was the first, says so.
  ///
  /// Every destination calls this from initState, so the wording and the
  /// timing live here rather than being written out eight times and drifting
  /// apart. The frame callback matters: initState is too early to put
  /// anything on screen.
  static void recordArrival(BuildContext context, String taskId) {
    final db = context.read<AlchemonsDatabase>();
    unawaited(() async {
      final earned = await OnboardingTaskService(db).markVisited(taskId);
      if (!earned || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showGameSnack(
          context,
          'Task complete — $kTaskSilverReward silver to collect',
          icon: AppIcons.check_circle_rounded,
          // Tapping the notification takes them to it, rather than telling
          // them where to go and leaving them to find it.
          action: SnackBarAction(
            label: 'Collect',
            onPressed: () {
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CampaignJournalScreen(),
                ),
              );
            },
          ),
        );
      });
    }());
  }

  Future<int> claimAll() async {
    var paid = 0;
    for (final task in kOnboardingTasks) {
      if (await claim(task.id)) paid++;
    }
    return paid;
  }
}
