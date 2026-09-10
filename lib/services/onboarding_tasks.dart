import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:flutter/widgets.dart';

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
  });

  final String id;
  final String title;

  /// One line on what the place is FOR. The title says where; this says why
  /// you would ever go.
  final String blurb;
  final IconData icon;
  final TaskDestination destination;

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
  ),
  OnboardingTask(
    id: 'harvest',
    title: 'Visit extraction',
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
  ),
  OnboardingTask(
    id: 'constellation',
    title: 'Look up',
    blurb: 'Constellation points buy permanent upgrades to everything else.',
    icon: AppIcons.nights_stay_rounded,
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

  Future<TaskState> stateOf(OnboardingTask task) async {
    if (await db.settingsDao.getSetting(task.claimedKey) == '1') {
      return TaskState.claimed;
    }
    if (await db.settingsDao.getSetting(task.settingKey) == '1') {
      return TaskState.earned;
    }
    return TaskState.todo;
  }

  /// Every task still worth showing, with its state. Claimed ones are gone.
  Future<List<(OnboardingTask, TaskState)>> outstanding() async {
    final rows = <(OnboardingTask, TaskState)>[];
    for (final task in kOnboardingTasks) {
      final state = await stateOf(task);
      if (state != TaskState.claimed) rows.add((task, state));
    }
    return rows;
  }

  /// How many rewards are sitting uncollected — what the home badge counts.
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
          'Task complete — collect $kTaskSilverReward silver in Achievements',
          icon: AppIcons.check_circle_rounded,
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
