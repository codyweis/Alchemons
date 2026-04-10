// lib/screens/boss_battle_screen.dart
//
// REDESIGNED BOSS BATTLE SCREEN
// Aesthetic: Scorched Forge — matches survival_game_screen redesign
// Dark metal, amber/gold reagent accents, monospace tactical typography
//
// NOTE (IMPORTANT):
// BossProgressNotifier stores progress using synthetic IDs:
//   boss_001 ... boss_017
// This screen uses that same key format when checking defeats / saving wins.
//
// SEQUENTIAL UNLOCK RULE:
// - Boss 1 is always unlocked
// - Boss N unlocks only after Boss (N-1) is defeated
//

import 'package:alchemons/data/boss_data.dart';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/providers/boss_provider.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/screens/boss/battle_screen.dart';
import 'package:alchemons/screens/boss/boss_base_command_screen.dart';
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/services/boss_upgrade_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'dart:math';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS  (shared aesthetic with survival_game_screen)
// ──────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg0 = Color(0xFF080A0E);
  static const bg1 = Color(0xFF0E1117);
  static const bg2 = Color(0xFF141820);
  static const bg3 = Color(0xFF1C2230);

  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const amberDim = Color(0xFF92400E);

  static const teal = Color(0xFF0EA5E9);

  static const textPrimary = Color(0xFFE8DCC8);
  static const textSecondary = Color(0xFF8A7B6A);
  static const textMuted = Color(0xFF4A3F35);

  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF16A34A);

  static const borderDim = Color(0xFF252D3A);
  static const borderMid = Color(0xFF3A3020);
  static const borderAccent = Color(0xFF6B4C20);
}

// ──────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY
// ──────────────────────────────────────────────────────────────────────────────

class _T {
  static const heading = TextStyle(
    fontFamily: 'monospace',
    color: _C.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  static const label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _EtchedDivider extends StatelessWidget {
  final String? label;
  const _EtchedDivider({this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _C.borderMid)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: _T.label),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: _C.borderMid)),
      ],
    );
  }
}

/// Corner-notch plate box
class _PlateBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final bool highlight;

  const _PlateBox({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accentColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _C.amber;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? accent.withValues(alpha: 0.55) : _C.borderDim,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 16)]
            : null,
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  left: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  right: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary / secondary forge button
class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool secondary;
  final Color? color;

  const _ForgeButton({
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.secondary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null || loading;
    final c = color ?? _C.amber;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: secondary ? 42 : 52,
        decoration: BoxDecoration(
          color: secondary ? Colors.transparent : (isDisabled ? _C.bg3 : c),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: secondary
                ? _C.borderAccent.withValues(alpha: 0.6)
                : (isDisabled ? _C.borderDim : c),
            width: 1,
          ),
          boxShadow: (!secondary && !isDisabled)
              ? [
                  BoxShadow(
                    color: c.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: secondary ? _C.textSecondary : _C.bg0,
                ),
              )
            else
              Icon(
                icon,
                size: secondary ? 15 : 17,
                color: secondary
                    ? _C.textSecondary
                    : (isDisabled ? _C.textMuted : _C.bg0),
              ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: secondary ? 11 : 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: secondary
                    ? _C.textSecondary
                    : (isDisabled ? _C.textMuted : _C.bg0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline stat cell used in boss details and history
class _FlatStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _FlatStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 11, color: color.withValues(alpha: 0.75)),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _T.label.copyWith(fontSize: 8, letterSpacing: 0.8),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.07);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────────────────────────────────────

String _bossProgressIdForOrder(int order) =>
    'boss_${order.toString().padLeft(3, '0')}';

String _dailyRematchKeyForBoss(int order) =>
    'boss_daily_rematch_date_utc_$order';

class _BossRematchScale {
  final double hpScale;
  final double atkScale;
  final double defScale;
  final double spdScale;
  final int hpFlat;
  final int atkFlat;
  final int defFlat;
  final int spdFlat;

  const _BossRematchScale({
    required this.hpScale,
    required this.atkScale,
    required this.defScale,
    required this.spdScale,
    required this.hpFlat,
    required this.atkFlat,
    required this.defFlat,
    required this.spdFlat,
  });
}

class _ScaleAnchor {
  final int order;
  final double value;
  const _ScaleAnchor(this.order, this.value);
}

double _lerpScale(double a, double b, double t) => a + ((b - a) * t);

double _scaleFromAnchors(int order, List<_ScaleAnchor> anchors) {
  if (anchors.isEmpty) return 1.0;
  if (order <= anchors.first.order) return anchors.first.value;
  for (var i = 0; i < anchors.length - 1; i++) {
    final left = anchors[i];
    final right = anchors[i + 1];
    if (order <= right.order) {
      final span = (right.order - left.order).toDouble();
      final t = span <= 0 ? 0.0 : (order - left.order) / span;
      return _lerpScale(left.value, right.value, t);
    }
  }
  return anchors.last.value;
}

// ──────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class BossBattleScreen extends StatefulWidget {
  const BossBattleScreen({super.key});
  @override
  State<BossBattleScreen> createState() => _BossBattleScreenState();
}

class _BossBattleScreenState extends State<BossBattleScreen>
    with TickerProviderStateMixin {
  late final PageController _bossPageController;
  double _bossPage = 0;
  bool _didInitialSync = false;
  bool _bossStoryCheckStarted = false;

  // Tracks which boss orders were rematched this session (so the cooldown
  // shows instantly without waiting for the FutureBuilder to re-query DB).
  final Set<int> _rematchedOrders = {};

  @override
  void initState() {
    super.initState();
    _bossPageController = PageController(viewportFraction: 0.88);
    _bossPageController.addListener(() {
      setState(() => _bossPage = _bossPageController.page ?? 0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowBossGauntletStoryIntro();
    });
  }

  Future<void> _maybeShowBossGauntletStoryIntro() async {
    if (_bossStoryCheckStarted || !mounted) return;
    _bossStoryCheckStarted = true;

    final db = context.read<AlchemonsDatabase>();
    final hasSeen = await db.settingsDao.hasSeenBossGauntletStoryIntro();
    if (hasSeen || !mounted) return;

    await LandscapeDialog.show(
      context,
      title: 'Alchemy is Power?',
      icon: Icons.science_rounded,
      typewriter: true,
      message:
          'Power does not wait for morality to agree.\n\n'
          'Break a warden, take the relic, and you begin to see the question beneath all of this: were these created to reveal reality, or to keep reality...real?',
    );

    if (!mounted) return;
    await db.settingsDao.setBossGauntletStoryIntroSeen();
  }

  @override
  void dispose() {
    _bossPageController.dispose();
    super.dispose();
  }

  bool _isUnlocked(BossProgressNotifier progress, int order) {
    if (order <= 1) return true;
    return progress.isBossDefeated(_bossProgressIdForOrder(order - 1));
  }

  int _highestUnlockedOrder(BossProgressNotifier progress) {
    for (int order = 2; order <= 17; order++) {
      if (!_isUnlocked(progress, order)) return order - 1;
    }
    return 17;
  }

  FactionTheme get _bossFactionTheme => FactionTheme.scorchForge();

  ThemeData get _bossThemeData => _bossFactionTheme
      .toMaterialTheme(ThemeData.dark().textTheme)
      .copyWith(scaffoldBackgroundColor: _C.bg0);

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<BossProgressNotifier>();
    final party = context.watch<SelectedPartyNotifier>();

    if (!progress.isLoaded) {
      return Theme(
        data: _bossThemeData,
        child: const Scaffold(
          backgroundColor: _C.bg0,
          body: Center(child: CircularProgressIndicator(color: _C.amber)),
        ),
      );
    }

    // Derive currentBoss from the carousel's visual page, not progress.currentBossOrder.
    // progress.currentBossOrder auto-advances on win, which would mismatch the
    // carousel position until the animation completes.
    final bosses = BossRepository.allBosses;
    final pageIndex = _bossPage.round().clamp(0, bosses.length - 1);
    final currentBoss = bosses.isNotEmpty ? bosses[pageIndex] : null;
    if (currentBoss == null) {
      return Theme(
        data: _bossThemeData,
        child: const Scaffold(
          backgroundColor: _C.bg0,
          body: Center(
            child: Text(
              'Boss not found',
              style: TextStyle(color: _C.textSecondary),
            ),
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didInitialSync) return;
      _didInitialSync = true;
      final targetOrder = _highestUnlockedOrder(progress);
      if (targetOrder != progress.currentBossOrder) {
        progress.setCurrentBoss(targetOrder);
      }
      if (_bossPageController.hasClients) {
        _bossPageController.jumpToPage(targetOrder - 1);
      }
    });

    return Theme(
      data: _bossThemeData,
      child: Scaffold(
        backgroundColor: _C.bg0,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(progress),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _buildBossCarousel(progress),
                      const SizedBox(height: 20),
                      _buildBossDetails(currentBoss, progress),
                      const SizedBox(height: 16),
                      _buildPartySection(party),
                      const SizedBox(height: 16),
                      _buildActionButtons(currentBoss, party, progress),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BossProgressNotifier progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _C.borderDim),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _C.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8, bottom: 1),
                      decoration: const BoxDecoration(
                        color: _C.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text('BOSS GAUNTLET', style: _T.heading),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('ELEMENTAL CHAMPIONS', style: _T.label),
              ],
            ),
          ),
          // Progress counter
          GestureDetector(
            onTap: () => _showBossHistory(progress),
            child: _PlateBox(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              accentColor: _C.amberBright,
              highlight: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: _C.amberBright,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${progress.totalBossesDefeated} / 17',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: _C.amberBright,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOSS CAROUSEL ───────────────────────────────────────────────────────────

  Widget _buildBossCarousel(BossProgressNotifier progress) {
    final bosses = BossRepository.allBosses;
    return Column(
      children: [
        const _EtchedDivider(label: 'SELECT TARGET'),
        const SizedBox(height: 14),
        SizedBox(
          height: 192,
          child: PageView.builder(
            controller: _bossPageController,
            itemCount: bosses.length,
            onPageChanged: (index) {
              final boss = bosses[index];
              final unlocked = _isUnlocked(progress, boss.order);
              if (!unlocked) {
                final targetOrder = _highestUnlockedOrder(progress);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_bossPageController.hasClients) {
                    _bossPageController.animateToPage(
                      (targetOrder - 1).clamp(0, bosses.length - 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                });
                _showToast(
                  'Defeat the previous boss to unlock.',
                  icon: Icons.lock_rounded,
                  color: _C.danger,
                );
                return;
              }
              progress.setCurrentBoss(boss.order);
            },
            itemBuilder: (context, index) {
              final boss = bosses[index];
              final distance = (index - _bossPage).abs().clamp(0.0, 1.0);
              final scale = 1.0 - (0.07 * distance);
              final opacity = 1.0 - (0.5 * distance);
              final bossKey = _bossProgressIdForOrder(boss.order);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _BossCarouselCard(
                    boss: boss,
                    isDefeated: progress.isBossDefeated(bossKey),
                    isUnlocked: _isUnlocked(progress, boss.order),
                    isCurrent: boss.order == progress.currentBossOrder,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Pip bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(bosses.length, (i) {
            final active = (i - _bossPage).abs() < 0.5;
            final boss = bosses[i];
            final defeated = progress.isBossDefeated(
              _bossProgressIdForOrder(boss.order),
            );
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              width: active ? 16 : 5,
              decoration: BoxDecoration(
                color: active
                    ? boss.elementColor
                    : (defeated
                          ? _C.success.withValues(alpha: 0.5)
                          : _C.borderAccent),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── BOSS DETAILS ────────────────────────────────────────────────────────────

  Widget _buildBossDetails(Boss boss, BossProgressNotifier progress) {
    final bossKey = _bossProgressIdForOrder(boss.order);
    final isEnraged = progress.isBossDefeated(bossKey);
    final bossProfile = BattleCombatant.fromBoss(boss);
    final gimmickSummary = BattleMove.bossGimmickSummaryForCombatant(
      bossProfile,
    );
    final rematchScale = _rematchScaleForOrder(boss.order);
    final dispHp = isEnraged
        ? (boss.hp * rematchScale.hpScale).round() + rematchScale.hpFlat
        : boss.hp;
    final dispAtk = isEnraged
        ? (boss.atk * rematchScale.atkScale).round() + rematchScale.atkFlat
        : boss.atk;
    final dispDef = isEnraged
        ? (boss.def * rematchScale.defScale).round() + rematchScale.defFlat
        : boss.def;
    final dispSpd = isEnraged
        ? (boss.spd * rematchScale.spdScale).round() + rematchScale.spdFlat
        : boss.spd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inline section label with element accent
        Row(
          children: [
            Container(
              width: 2,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: boss.elementColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Text('THREAT ANALYSIS', style: _T.label),
            if (isEnraged) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  '⚡ ENRAGED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFFF4444),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Flat stat row — no boxes
        Row(
          children: [
            _FlatStat(
              label: 'HP',
              value: '$dispHp',
              color: _C.danger,
              icon: Icons.favorite_rounded,
            ),
            _FlatStat(
              label: 'ATK',
              value: '$dispAtk',
              color: _C.amberBright,
              icon: Icons.flash_on_rounded,
            ),
            _FlatStat(
              label: 'DEF',
              value: '$dispDef',
              color: _C.teal,
              icon: Icons.shield_rounded,
            ),
            _FlatStat(
              label: 'SPD',
              value: '$dispSpd',
              color: const Color(0xFF34D399),
              icon: Icons.speed_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Abilities label
        Row(
          children: [
            Icon(
              boss.elementIcon,
              color: boss.elementColor.withValues(alpha: 0.7),
              size: 11,
            ),
            const SizedBox(width: 6),
            Text('ABILITIES', style: _T.label),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: boss.moveset.map((move) {
              final c = _moveColor(move.type);
              return Tooltip(
                message: move.description,
                triggerMode: TooltipTriggerMode.tap,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.bg0.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _C.borderAccent),
                ),
                textStyle: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: c.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_moveIcon(move.type), size: 11, color: c),
                      const SizedBox(width: 6),
                      Text(
                        move.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: c,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: boss.elementColor.withValues(alpha: 0.8),
              size: 12,
            ),
            const SizedBox(width: 6),
            Text('BOSS SPECIAL', style: _T.label),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: boss.elementColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: boss.elementColor.withValues(alpha: 0.32),
            ),
          ),
          child: Text(
            gimmickSummary,
            style: const TextStyle(
              color: _C.textPrimary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Color _moveColor(BossMoveType type) {
    switch (type) {
      case BossMoveType.singleTarget:
        return const Color(0xFFF97316);
      case BossMoveType.aoe:
        return _C.danger;
      case BossMoveType.buff:
        return _C.teal;
      case BossMoveType.debuff:
        return const Color(0xFFA855F7);
      case BossMoveType.heal:
        return _C.success;
      case BossMoveType.special:
        return _C.amberBright;
    }
  }

  IconData _moveIcon(BossMoveType type) {
    switch (type) {
      case BossMoveType.singleTarget:
        return Icons.person_rounded;
      case BossMoveType.aoe:
        return Icons.groups_rounded;
      case BossMoveType.buff:
        return Icons.arrow_upward_rounded;
      case BossMoveType.debuff:
        return Icons.arrow_downward_rounded;
      case BossMoveType.heal:
        return Icons.favorite_rounded;
      case BossMoveType.special:
        return Icons.auto_awesome_rounded;
    }
  }

  // ── PARTY SECTION ───────────────────────────────────────────────────────────

  Widget _buildPartySection(SelectedPartyNotifier party) {
    final db = context.watch<AlchemonsDatabase>();
    final repo = context.watch<CreatureCatalog>();
    final maxPartySize = SelectedPartyNotifier.defaultMaxSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inline section label
        Row(
          children: [
            Container(
              width: 2,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _C.amber,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const Text('ASSIGNED SQUAD', style: _T.label),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<CreatureInstance>>(
          stream: db.creatureDao.watchAllInstances(),
          builder: (context, snapshot) {
            final allInstances = snapshot.data ?? [];
            final selectedInstances = party.members
                .map(
                  (m) => allInstances
                      .where((inst) => inst.instanceId == m.instanceId)
                      .cast<CreatureInstance?>()
                      .firstOrNull,
                )
                .whereType<CreatureInstance>()
                .toList();

            // Count badge inline
            final isFull = selectedInstances.length == maxPartySize;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: _C.amber, size: 13),
                    const SizedBox(width: 6),
                    const Text('FIELD TEAM', style: _T.label),
                    const Spacer(),
                    Text(
                      '${selectedInstances.length} / $maxPartySize',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isFull ? _C.success : _C.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (selectedInstances.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.group_add_rounded,
                          color: _C.textMuted,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text('NO SQUAD ASSIGNED', style: _T.label),
                      ],
                    ),
                  )
                else
                  Row(
                    children: List.generate(maxPartySize, (i) {
                      final inst = i < selectedInstances.length
                          ? selectedInstances[i]
                          : null;
                      final creature = inst != null
                          ? repo.getCreatureById(inst.baseId)
                          : null;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                          child: inst == null || creature == null
                              ? _buildEmptySlot()
                              : _buildPartyMemberCard(inst, creature),
                        ),
                      );
                    }),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: _C.bg1,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _C.borderDim),
      ),
      child: const Center(
        child: Icon(Icons.add_rounded, color: _C.textMuted, size: 22),
      ),
    );
  }

  Widget _buildPartyMemberCard(CreatureInstance instance, Creature creature) {
    final bars = instance.staminaBars.clamp(0, instance.staminaMax);
    final maxBars = instance.staminaMax;
    final isEmpty = bars == 0;
    final isLow = bars == 1 && maxBars > 1;
    final staminaColor = isEmpty
        ? _C.danger
        : isLow
        ? const Color(0xFFF97316) // orange
        : _C.success;

    return FastLongPressDetector(
      onLongPress: () {
        final theme = FactionTheme.scorchForge();
        showQuickInstanceDialog(
          context: context,
          theme: theme,
          creature: creature,
          instance: instance,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _C.bg1,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isEmpty
                ? _C.danger.withValues(alpha: 0.5)
                : _C.borderAccent.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: InstanceSprite(
                creature: creature,
                instance: instance,
                size: 42,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              (instance.nickname ?? creature.name).toUpperCase(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: _C.textPrimary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _C.amberDim.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: _C.borderAccent),
              ),
              child: Text(
                'LV ${instance.level}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: _C.amberBright,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Stamina pips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(maxBars, (i) {
                final filled = i < bars;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? staminaColor
                        : staminaColor.withValues(alpha: 0.15),
                    border: Border.all(
                      color: staminaColor.withValues(alpha: filled ? 0.9 : 0.3),
                      width: 0.8,
                    ),
                  ),
                );
              }),
            ),
            if (isEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'NO STAMINA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _C.danger,
                  fontSize: 6,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── ACTION BUTTONS ──────────────────────────────────────────────────────────

  Widget _buildActionButtons(
    Boss boss,
    SelectedPartyNotifier party,
    BossProgressNotifier progress,
  ) {
    final hasTeam = party.members.isNotEmpty;
    final isUnlocked = _isUnlocked(progress, boss.order);
    final bossKey = _bossProgressIdForOrder(boss.order);
    final isDefeated = progress.isBossDefeated(bossKey);

    return FutureBuilder<(String?, int, int)>(
      future: () async {
        final db = context.read<AlchemonsDatabase>();
        final dateStr = await db.settingsDao.getSetting(
          _dailyRematchKeyForBoss(boss.order),
        );
        final refreshQty = await db.inventoryDao.getItemQty(
          InvKeys.bossRefresh,
        );
        final summonQty = await db.inventoryDao.getItemQty(InvKeys.bossSummon);
        return (dateStr, refreshQty, summonQty);
      }(),
      builder: (context, snapshot) {
        final todayUtc = DateTime.now()
            .toUtc()
            .toIso8601String()
            .split('T')
            .first;
        final dateStr = snapshot.data?.$1;
        final refreshQty = snapshot.data?.$2 ?? 0;
        final summonQty = snapshot.data?.$3 ?? 0;
        // Use local session flag for instant cooldown display after a win
        final rematchUsedToday =
            isDefeated &&
            (_rematchedOrders.contains(boss.order) || dateStr == todayUtc);
        final canBattle = hasTeam && isUnlocked && !rematchUsedToday;
        final countdownLabel = rematchUsedToday
            ? _formatUtcResetCountdown()
            : null;

        return Column(
          children: [
            _ForgeButton(
              label: !isUnlocked
                  ? 'Locked'
                  : rematchUsedToday
                  ? 'Reset in $countdownLabel'
                  : isDefeated
                  ? 'Rematch for Loot'
                  : 'Engage Boss',
              icon: !isUnlocked
                  ? Icons.lock_rounded
                  : isDefeated
                  ? null
                  : null,
              color: canBattle ? boss.elementColor : null,
              onTap: canBattle
                  ? () => _startBattle(boss, party, progress)
                  : null,
            ),
            const SizedBox(height: 10),
            _ForgeButton(
              label: hasTeam ? 'Change Squad' : 'Assign Squad',
              icon: hasTeam
                  ? Icons.swap_horiz_rounded
                  : Icons.group_add_rounded,
              loading: false,
              secondary: true,
              onTap: () async {
                await Navigator.push<List<PartyMember>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PartyPickerScreen(
                      showDeployConfirm: false,
                      teamStorageKey: 'saved_teams_boss',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ForgeButton(
              label: 'Boss Command',
              icon: Icons.settings_rounded,
              secondary: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BossBaseCommandScreen(),
                  ),
                );
              },
            ),
            // Use Recall Token button (shown only when rematch used & token available)
            // Boss Summon — fight again even when cooldown is active
            if (rematchUsedToday && summonQty > 0) ...[
              const SizedBox(height: 10),
              _ForgeButton(
                label: 'Use Boss Summon (×$summonQty)',
                icon: Icons.whatshot_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () async {
                  final db = context.read<AlchemonsDatabase>();
                  await db.inventoryDao.addItemQty(InvKeys.bossSummon, -1);
                  // Clear the daily lock so the normal flow runs
                  await db.settingsDao.setSetting(
                    _dailyRematchKeyForBoss(boss.order),
                    '',
                  );
                  _rematchedOrders.remove(boss.order);
                  if (mounted) setState(() {});
                  // Give the FutureBuilder a frame to settle, then start battle
                  await Future.microtask(() {});
                  if (mounted) _startBattle(boss, party, progress);
                },
              ),
            ],
            if (rematchUsedToday && refreshQty > 0) ...[
              const SizedBox(height: 10),
              _ForgeButton(
                label: 'Use Boss Summon Token (×$refreshQty)',
                icon: Icons.local_drink_rounded,
                color: const Color(0xFF1A237E),
                onTap: () async {
                  final db = context.read<AlchemonsDatabase>();
                  await db.inventoryDao.addItemQty(InvKeys.bossRefresh, -1);
                  await db.settingsDao.setSetting(
                    _dailyRematchKeyForBoss(boss.order),
                    '',
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
            // Locked / countdown sub-label
            if (!isUnlocked || rematchUsedToday) ...[
              const SizedBox(height: 8),
              Text(
                !isUnlocked
                    ? 'DEFEAT BOSS ${boss.order - 1} TO UNLOCK'
                    : 'DAILY REMATCH EXPENDED — RESETS 00:00 UTC',
                style: _T.label.copyWith(color: _C.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatUtcResetCountdown() {
    final nowUtc = DateTime.now().toUtc();
    final resetUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day + 1);
    final remaining = resetUtc.difference(nowUtc);
    return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
  }

  // ── BATTLE LOGIC (unchanged from original) ──────────────────────────────────

  Boss _toLateGameBoss(Boss base) {
    final s = _rematchScaleForOrder(base.order);
    return Boss(
      id: base.id,
      name: base.name,
      element: base.element,
      recommendedLevel: base.recommendedLevel < 10 ? 10 : base.recommendedLevel,
      hp: (base.hp * s.hpScale).round() + s.hpFlat,
      atk: (base.atk * s.atkScale).round() + s.atkFlat,
      def: (base.def * s.defScale).round() + s.defFlat,
      spd: (base.spd * s.spdScale).round() + s.spdFlat,
      moveset: base.moveset,
      tier: base.tier,
      order: base.order,
    );
  }

  _BossRematchScale _rematchScaleForOrder(int order) {
    // Dungeon rematches target endgame pressure:
    // early bosses are heavily elevated; late bosses are only slightly elevated.
    final hpScale = _scaleFromAnchors(order, const [
      _ScaleAnchor(1, 3.30),
      _ScaleAnchor(4, 2.25),
      _ScaleAnchor(8, 1.46),
      _ScaleAnchor(12, 1.02),
      _ScaleAnchor(17, 0.95),
    ]);
    final atkScale = _scaleFromAnchors(order, const [
      _ScaleAnchor(1, 1.42),
      _ScaleAnchor(4, 1.32),
      _ScaleAnchor(8, 1.20),
      _ScaleAnchor(12, 1.05),
      _ScaleAnchor(17, 1.00),
    ]);
    final defScale = _scaleFromAnchors(order, const [
      _ScaleAnchor(1, 1.32),
      _ScaleAnchor(4, 1.24),
      _ScaleAnchor(8, 1.14),
      _ScaleAnchor(12, 1.05),
      _ScaleAnchor(17, 1.00),
    ]);
    final spdScale = _scaleFromAnchors(order, const [
      _ScaleAnchor(1, 1.20),
      _ScaleAnchor(4, 1.16),
      _ScaleAnchor(8, 1.12),
      _ScaleAnchor(12, 1.07),
      _ScaleAnchor(17, 1.03),
    ]);
    final hpFlat = order <= 4 ? 40 : (order <= 8 ? 20 : 0);
    final atkFlat = order <= 4 ? 3 : (order <= 8 ? 2 : (order <= 12 ? 1 : 0));
    final defFlat = order <= 4 ? 2 : (order <= 8 ? 1 : 0);
    final spdFlat = order <= 6 ? 1 : 0;
    return _BossRematchScale(
      hpScale: hpScale,
      atkScale: atkScale,
      defScale: defScale,
      spdScale: spdScale,
      hpFlat: hpFlat,
      atkFlat: atkFlat,
      defFlat: defFlat,
      spdFlat: spdFlat,
    );
  }

  void _startBattle(
    Boss boss,
    SelectedPartyNotifier party,
    BossProgressNotifier progress,
  ) async {
    if (boss.element.toLowerCase() == 'blood') {
      final hasSeenFinale = await context
          .read<ConstellationService>()
          .hasSeenFinale();
      if (!hasSeenFinale) {
        if (mounted) {
          await _showBloodBossLockedPopup(boss);
        }
        return;
      }
    }

    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final staminaService = StaminaService(db);

    final instances = await db.creatureDao.listAllInstances();
    final selectedInstances = party.members
        .map(
          (m) => instances
              .where((inst) => inst.instanceId == m.instanceId)
              .cast<CreatureInstance?>()
              .firstOrNull,
        )
        .whereType<CreatureInstance>()
        .toList();

    if (selectedInstances.isEmpty) {
      _showToast(
        'No squad assigned.',
        icon: Icons.warning_rounded,
        color: _C.amberBright,
      );
      return;
    }

    final refreshedInstances = <CreatureInstance>[];
    for (final inst in selectedInstances) {
      final refreshed = await staminaService.refreshAndGet(inst.instanceId);
      if (refreshed == null) {
        _showToast(
          'Error checking stamina.',
          icon: Icons.error_rounded,
          color: _C.danger,
        );
        return;
      }
      refreshedInstances.add(refreshed);
    }

    final lowStamina = refreshedInstances
        .where((inst) => inst.staminaBars < 1)
        .toList();
    if (lowStamina.isNotEmpty) {
      final names = lowStamina
          .map((inst) {
            final c = repo.getCreatureById(inst.baseId);
            return c?.name ?? 'Unknown';
          })
          .take(2)
          .join(', ');
      _showToast(
        lowStamina.length == 1
            ? '$names needs rest.'
            : '${lowStamina.length} creatures need rest.',
        icon: Icons.battery_0_bar_rounded,
        color: _C.danger,
      );
      return;
    }

    for (final inst in refreshedInstances) {
      await db.creatureDao.updateStamina(
        instanceId: inst.instanceId,
        staminaBars: inst.staminaBars - 1,
        staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }

    final playerTeam = refreshedInstances
        .map((inst) {
          final creature = repo.getCreatureById(inst.baseId);
          if (creature == null) return null;
          return BattleCombatant.fromInstance(
            instance: inst,
            creature: creature,
          );
        })
        .whereType<BattleCombatant>()
        .toList();

    if (!mounted) return;
    // ── Apply Boss Command upgrade bonuses ────────────────────────────────
    final bossUpgradeState = context.read<BossUpgradeService>().state;
    for (final combatant in playerTeam) {
      bossUpgradeState.applyTo(
        getMaxHp: () => combatant.maxHp,
        setMaxHp: (v) => combatant.maxHp = v,
        getPhysAtk: () => combatant.physAtk,
        setPhysAtk: (v) => combatant.physAtk = v,
        getElemAtk: () => combatant.elemAtk,
        setElemAtk: (v) => combatant.elemAtk = v,
        getPhysDef: () => combatant.physDef,
        setPhysDef: (v) => combatant.physDef = v,
        getElemDef: () => combatant.elemDef,
        setElemDef: (v) => combatant.elemDef = v,
        getSpeed: () => combatant.speed,
        setSpeed: (v) => combatant.speed = v,
        getCurrentHp: () => combatant.currentHp,
        setCurrentHp: (v) => combatant.currentHp = v,
      );
    }

    final bossKey = _bossProgressIdForOrder(boss.order);
    final wasAlreadyDefeated = progress.isBossDefeated(bossKey);

    if (wasAlreadyDefeated) {
      final todayUtc = DateTime.now()
          .toUtc()
          .toIso8601String()
          .split('T')
          .first;
      final lastRematch = await db.settingsDao.getSetting(
        _dailyRematchKeyForBoss(boss.order),
      );
      if (lastRematch == todayUtc) {
        _showToast(
          'Daily rematch used. Try again tomorrow.',
          icon: Icons.schedule_rounded,
          color: _C.amberBright,
        );
        return;
      }
    }

    final bossForBattle = wasAlreadyDefeated ? _toLateGameBoss(boss) : boss;
    final bossMystic = repo.mysticByElement(bossForBattle.element);
    final bossCombatant = BattleCombatant.fromBoss(
      bossForBattle,
      mysticSpecies: bossMystic,
    );
    if (!mounted) return;
    final theme = context.read<FactionTheme>();

    final victory = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreenFlame(
          boss: bossCombatant,
          playerTeam: playerTeam,
          bossDisplayName: bossMystic?.name ?? boss.name,
          themeColor: theme.accent,
        ),
      ),
    );

    if (victory == true && mounted) {
      await progress.defeatBoss(bossKey, boss.order);

      final shouldShowBloodUnlockStory =
          !wasAlreadyDefeated && boss.order == 16;
      final shouldShowBloodVictoryStory =
          !wasAlreadyDefeated && boss.order == 17;

      // Advance the carousel to the newly unlocked boss when it's a first defeat.
      if (!wasAlreadyDefeated && _bossPageController.hasClients) {
        final nextPage = boss.order; // page index = order - 1 + 1 = order
        final bosses = BossRepository.allBosses;
        if (nextPage < bosses.length) {
          _bossPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
          );
        }
      }

      final registry = buildInventoryRegistry(db);

      if (!wasAlreadyDefeated) {
        final traitKey = BossLootKeys.traitKeyForElement(boss.element);
        final traitDef = registry[traitKey];
        if (traitDef != null) {
          final existing = await db.inventoryDao.getItemQty(traitKey);
          if (existing <= 0) {
            await db.inventoryDao.addItemQty(traitKey, 1);
            final meta =
                BossLootKeys.elementRewards[boss.element.toLowerCase()];
            if (mounted) {
              await showKeyItemUnlockDialog(
                context: context,
                itemName: traitDef.name,
                itemDescription: traitDef.description,
                itemIcon: meta?.traitIcon ?? Icons.vpn_key_rounded,
                elementColor: boss.elementColor,
                itemImagePath: boss.relicImagePath,
                theme: _bossFactionTheme,
              );
            }
          }
        }
      } else {
        final lootBoxKey = BossLootKeys.lootBoxKeyForElement(boss.element);
        final rewardRng = Random();
        final openedRewards = LootBoxConfig.rollBossLootBoxDropsForQuantity(
          lootBoxKey,
          1,
          rewardRng,
        );
        for (final reward in openedRewards) {
          await db.inventoryDao.addItemQty(reward.key, reward.value);
        }
        final powerupRewards = rollBossRiftPowerupRewards(rewardRng);
        for (final reward in powerupRewards) {
          await db.inventoryDao.addItemQty(reward.key, reward.value);
        }
        await db.settingsDao.setSetting(
          _dailyRematchKeyForBoss(boss.order),
          DateTime.now().toUtc().toIso8601String().split('T').first,
        );
        _rematchedOrders.add(boss.order);

        final currencyRewards = LootBoxConfig.rollBossRematchBonusCurrency(
          boss.order,
          rewardRng,
        );
        final silver = currencyRewards['silver'] ?? 0;
        final gold = currencyRewards['gold'] ?? 0;
        if (silver > 0) await db.currencyDao.addSilver(silver);
        if (gold > 0) await db.currencyDao.addGold(gold);

        final popupEntries = <LootOpeningEntry>[
          ...openedRewards.map((e) {
            final def = registry[e.key];
            return LootOpeningEntry(
              icon: def?.icon ?? Icons.inventory_2_rounded,
              name: def?.name ?? e.key,
              label: 'x${e.value}',
              color: _C.amber,
            );
          }),
          ...powerupRewards.map((e) {
            final type = alchemicalPowerupTypeFromInventoryKey(e.key);
            final def = registry[e.key];
            return LootOpeningEntry(
              icon: type?.icon ?? def?.icon ?? Icons.blur_on_rounded,
              name: type?.name ?? def?.name ?? e.key,
              label: 'x${e.value}',
              color: type?.color ?? _C.amberBright,
            );
          }),
          if (silver > 0)
            LootOpeningEntry(
              icon: Icons.monetization_on_rounded,
              label: '+$silver',
              color: const Color(0xFFB0BEC5),
            ),
          if (gold > 0)
            LootOpeningEntry(
              icon: Icons.stars_rounded,
              label: '+$gold',
              color: _C.amberBright,
            ),
        ];
        if (!mounted) return;
        await showLootOpeningDialog(
          context: context,
          entries: popupEntries,
          theme: _bossFactionTheme,
        );
      }

      if (shouldShowBloodUnlockStory && mounted) {
        await _showBloodBossUnlockStory();
      }

      if (shouldShowBloodVictoryStory && mounted) {
        await _showBloodBossVictoryStory();
      }

      _showToast(
        'VICTORY — ${boss.name.toUpperCase()} DEFEATED',
        icon: Icons.emoji_events_rounded,
        color: _C.success,
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _showBloodBossLockedPopup(Boss boss) async {
    if (!mounted) return;
    await LandscapeDialog.show(
      context,
      title: 'Summon From The Stars',
      message: 'The constellations still bar the entrance to the ${boss.name}.',
      typewriter: true,
      showIcon: false,
    );
  }

  Future<void> _showBloodBossUnlockStory() async {
    if (!mounted) return;
    await LandscapeDialog.show(
      context,
      title: 'Summon From The Stars',
      message:
          'The constellations do not guide the way to Sanguorath. They bar it.\n\n'
          'Only a summons drawn from the stars can open the entrance.',
      typewriter: true,
      showIcon: false,
    );
  }

  Future<void> _showBloodBossVictoryStory() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _C.bg1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: _C.borderDim),
          ),
          title: const Text(
            'THE LAST WARDEN?',
            style: TextStyle(
              fontFamily: 'monospace',
              color: _C.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          content: const Text(
            'This was never an ending. Only the final guard.\n\nBlood was not the secret, only the cost. Take the relic back. What waits at the altar is not resurrection, but the proof that a form can be made to continue.',
            style: TextStyle(
              fontFamily: 'monospace',
              color: _C.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: 0.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _C.amberBright,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showToast(
    String message, {
    IconData icon = Icons.info_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: _C.bg0, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: _C.bg0,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? _C.amber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  void _showBossHistory(BossProgressNotifier progress) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BossHistorySheet(
        progress: progress,
        onSelectBoss: (order) {
          progress.setCurrentBoss(order);
          _bossPageController.animateToPage(
            order - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// BOSS CAROUSEL CARD — extracted widget
// ──────────────────────────────────────────────────────────────────────────────

class _BossCarouselCard extends StatelessWidget {
  final Boss boss;
  final bool isDefeated;
  final bool isUnlocked;
  final bool isCurrent;

  const _BossCarouselCard({
    required this.boss,
    required this.isDefeated,
    required this.isUnlocked,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();
    final mystic = repo.mysticByElement(boss.element);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isCurrent
              ? boss.elementColor.withValues(alpha: 0.6)
              : _C.borderDim,
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: boss.elementColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Opacity(
          opacity: isUnlocked ? 1.0 : 0.3,
          child: Stack(
            children: [
              // Scanlines
              Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
              // Content
              Row(
                children: [
                  // Left — sprite zone
                  SizedBox(
                    width: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Elemental glow
                        Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                boss.elementColor.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                              radius: 0.75,
                            ),
                          ),
                        ),
                        // Sprite or icon
                        Builder(
                          builder: (_) {
                            final hasMysticSprite =
                                mystic != null && mystic.spriteData != null;
                            if (hasMysticSprite) {
                              final sheet = sheetFromCreature(mystic);
                              final visuals = visualsFromInstance(mystic, null);
                              return SizedBox(
                                width: 105,
                                height: 105,
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
                            return Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: boss.elementColor.withValues(
                                  alpha: 0.12,
                                ),
                                border: Border.all(
                                  color: boss.elementColor.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Icon(
                                boss.elementIcon,
                                color: boss.elementColor,
                                size: 30,
                              ),
                            );
                          },
                        ),
                        // Element badge — bottom
                        Positioned(
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: boss.elementColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: boss.elementColor.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              boss.element.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: boss.elementColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Separator
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    color: _C.borderDim,
                  ),
                  // Right — text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Enraged label (shown after first defeat)
                          if (isDefeated) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFDC2626,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: const Color(
                                    0xFFDC2626,
                                  ).withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                '⚡ ENRAGED',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFFFF4444),
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          // Name
                          Text(
                            (mystic?.name ?? boss.name).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: _C.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // Mini stats
                          Builder(
                            builder: (_) {
                              final dispHp = isDefeated
                                  ? (boss.hp * 1.7).round() + (boss.order * 40)
                                  : boss.hp;
                              final dispAtk = isDefeated
                                  ? (boss.atk * 1.45).round() + (boss.order * 2)
                                  : boss.atk;
                              final dispDef = isDefeated
                                  ? (boss.def * 1.45).round() + (boss.order * 2)
                                  : boss.def;
                              return Row(
                                children: [
                                  _MiniStatBadge(
                                    icon: Icons.favorite,
                                    value: '$dispHp',
                                    color: _C.danger,
                                  ),
                                  const SizedBox(width: 6),
                                  _MiniStatBadge(
                                    icon: Icons.flash_on,
                                    value: '$dispAtk',
                                    color: _C.amberBright,
                                  ),
                                  const SizedBox(width: 6),
                                  _MiniStatBadge(
                                    icon: Icons.shield,
                                    value: '$dispDef',
                                    color: _C.teal,
                                  ),
                                ],
                              );
                            },
                          ),
                          // Status badges
                          if (isDefeated) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _StatusBadge(
                                  label: 'DEFEATED',
                                  color: _C.success,
                                ),
                                const SizedBox(width: 6),
                                _StatusBadge(label: 'REMATCH', color: _C.amber),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Order badge — top right
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _C.bg0.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.borderAccent),
                  ),
                  child: Center(
                    child: Text(
                      '${boss.order}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: _C.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              // Lock overlay
              if (!isUnlocked)
                Positioned.fill(
                  child: Container(
                    color: _C.bg0.withValues(alpha: 0.55),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            color: _C.textSecondary,
                            size: 22,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'LOCKED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _C.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _MiniStatBadge({
    required this.icon,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// BOSS HISTORY BOTTOM SHEET
// ──────────────────────────────────────────────────────────────────────────────

class _BossHistorySheet extends StatelessWidget {
  final BossProgressNotifier progress;
  final void Function(int order) onSelectBoss;

  const _BossHistorySheet({required this.progress, required this.onSelectBoss});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: _C.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        border: Border(top: BorderSide(color: _C.borderAccent, width: 1.5)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: _C.borderAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.amberDim.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _C.borderAccent),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: _C.amberBright,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('GAUNTLET RECORD', style: _T.heading),
                      const SizedBox(height: 2),
                      Text(
                        '${progress.totalBossesDefeated} OF 17 CHAMPIONS FALLEN',
                        style: _T.label.copyWith(color: _C.textMuted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _C.bg2,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: _C.borderDim),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: _C.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COMPLETION', style: _T.label),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: _C.bg3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.totalBossesDefeated / 17,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _C.amberBright,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: _C.amberBright.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _C.borderDim),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              itemCount: BossRepository.allBosses.length,
              itemBuilder: (context, index) {
                final boss = BossRepository.allBosses[index];
                final bossKey = _bossProgressIdForOrder(boss.order);
                final defeated = progress.isBossDefeated(bossKey);
                final defeatCount = progress.getDefeatCount(bossKey);
                final isCurrent = boss.order == progress.currentBossOrder;
                final isUnlocked =
                    boss.order == 1 ||
                    progress.isBossDefeated(
                      _bossProgressIdForOrder(boss.order - 1),
                    );

                return _BossHistoryRow(
                  boss: boss,
                  defeated: defeated,
                  defeatCount: defeatCount,
                  isCurrent: isCurrent,
                  isUnlocked: isUnlocked,
                  onTap: isUnlocked ? () => onSelectBoss(boss.order) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BossHistoryRow extends StatelessWidget {
  final Boss boss;
  final bool defeated;
  final int defeatCount;
  final bool isCurrent;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const _BossHistoryRow({
    required this.boss,
    required this.defeated,
    required this.defeatCount,
    required this.isCurrent,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();
    final mystic = repo.mysticByElement(boss.element);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? boss.elementColor.withValues(alpha: 0.08) : _C.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isCurrent
                ? boss.elementColor.withValues(alpha: 0.45)
                : _C.borderDim,
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Order number
            SizedBox(
              width: 24,
              child: Text(
                '${boss.order}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: _C.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              width: 1,
              height: 28,
              color: _C.borderDim,
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
            // Status icon / relic image
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: defeated
                    ? _C.success.withValues(alpha: 0.15)
                    : boss.elementColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: defeated
                      ? _C.success.withValues(alpha: 0.5)
                      : boss.elementColor.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: defeated
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.asset(
                        boss.relicImagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.check_rounded,
                          color: _C.success,
                          size: 15,
                        ),
                      ),
                    )
                  : Icon(boss.elementIcon, color: boss.elementColor, size: 15),
            ),
            const SizedBox(width: 10),
            // Name + element
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (mystic?.name ?? boss.name).toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: _C.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        boss.element.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: boss.elementColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right badge
            if (!isUnlocked)
              const Icon(Icons.lock_rounded, color: _C.textMuted, size: 14)
            else if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: boss.elementColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: boss.elementColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: boss.elementColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              )
            else if (defeatCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: _C.success.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '×$defeatCount',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _C.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
