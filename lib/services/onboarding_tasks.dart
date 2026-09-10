import 'package:alchemons/database/alchemons_db.dart';
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

  String get settingKey => 'task_seen_$id';
}

/// Paid on arrival, the same for every task. Enough to matter early, not
/// enough to be worth farming — and they cannot be farmed anyway.
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

/// Records arrivals and pays for them.
class OnboardingTaskService {
  const OnboardingTaskService(this.db);

  final AlchemonsDatabase db;

  Future<Set<String>> completed() async {
    final done = <String>{};
    for (final task in kOnboardingTasks) {
      if (await db.settingsDao.getSetting(task.settingKey) == '1') {
        done.add(task.id);
      }
    }
    return done;
  }

  Future<List<OnboardingTask>> outstanding() async {
    final done = await completed();
    return [for (final t in kOnboardingTasks) if (!done.contains(t.id)) t];
  }

  /// Marks [id] arrived at and pays the reward, once.
  ///
  /// Safe to call from a screen's initState on every visit: the second call
  /// is a no-op, so the payment cannot be repeated.
  Future<bool> markVisited(String id) async {
    final matches = kOnboardingTasks.where((t) => t.id == id);
    if (matches.isEmpty) return false;
    final task = matches.first;
    if (await db.settingsDao.getSetting(task.settingKey) == '1') return false;
    await db.settingsDao.setSetting(task.settingKey, '1');
    await db.currencyDao.addSilver(kTaskSilverReward);
    return true;
  }
}
