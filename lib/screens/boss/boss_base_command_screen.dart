// lib/screens/boss/boss_base_command_screen.dart
//
// Boss Base Command — persistent boss-battle upgrade screen.
// Five squad upgrade categories purchased with silver.
// Follows the scorched-metal forge aesthetic.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/boss_upgrades.dart';
import 'package:alchemons/services/boss_upgrade_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg0 = Color(0xFF080A0E);
  static const bg2 = Color(0xFF141820);
  static const bg3 = Color(0xFF1C2230);
  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const textPrimary = Color(0xFFE8DCC8);
  static const textSecondary = Color(0xFF8A7B6A);
  static const textMuted = Color(0xFF4A3F35);
  static const danger = Color(0xFFC0392B);
  static const borderDim = Color(0xFF252D3A);
  static const borderMid = Color(0xFF3A3020);
}

class _T {
  static const TextStyle heading = TextStyle(
    fontFamily: 'monospace',
    color: _C.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );
  static const TextStyle label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
  static const TextStyle body = TextStyle(
    color: _C.textSecondary,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BossBaseCommandScreen extends StatefulWidget {
  const BossBaseCommandScreen({super.key});

  @override
  State<BossBaseCommandScreen> createState() => _BossBaseCommandScreenState();
}

class _BossBaseCommandScreenState extends State<BossBaseCommandScreen> {
  int _silverBalance = 0;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _loadSilver();
  }

  Future<void> _loadSilver() async {
    final db = context.read<AlchemonsDatabase>();
    final silver = await db.currencyDao.getSilverBalance();
    if (mounted) setState(() => _silverBalance = silver);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BossUpgradeService>(
      builder: (context, svc, _) {
        return Scaffold(
          backgroundColor: _C.bg0,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildUpgradeList(svc)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim, width: 1)),
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
                        color: _C.amberBright,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text('BOSS COMMAND', style: _T.heading),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('SQUAD POWER-UPS', style: _T.label),
              ],
            ),
          ),
          // Silver display
          _PlateBox(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            accentColor: const Color(0xFFC0C0C0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.paid_rounded,
                  color: Color(0xFFC0C0C0),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_silverBalance',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFC0C0C0),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Upgrade List ─────────────────────────────────────────────────────────

  Widget _buildUpgradeList(BossUpgradeService svc) {
    final state = svc.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EtchedDivider(label: 'SQUAD POWER-UPS'),
          const SizedBox(height: 12),
          Text(
            'Permanently boost your squad\'s combat stats for boss fights. '
            'Effects apply to all creatures in your party.',
            style: _T.body,
          ),
          const SizedBox(height: 16),
          ...kBossSquadUpgrades.map(
            (def) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UpgradeCard(
                name: def.name,
                description: def.description,
                icon: def.icon,
                color: def.color,
                currentLevel: state.getLevel(def.upgrade),
                maxLevel: def.maxLevel,
                nextCost: svc.nextCost(def.upgrade),
                bonusLabel: def.bonusLabel(state.getLevel(def.upgrade)),
                silverBalance: _silverBalance,
                purchasing: _purchasing,
                onUpgrade: () => _upgrade(svc, def.upgrade),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upgrade(
    BossUpgradeService svc,
    BossSquadUpgrade upgrade,
  ) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    final ok = await svc.upgradeSquadStat(upgrade);
    if (ok) await _loadSilver();
    if (mounted) {
      setState(() => _purchasing = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough silver!'),
            backgroundColor: _C.danger,
          ),
        );
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

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

class _PlateBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;

  const _PlateBox({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _C.amber;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _C.borderDim, width: 1),
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

class _LevelPips extends StatelessWidget {
  final int current;
  final int max;
  final Color color;

  const _LevelPips({
    required this.current,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < current;
        return Container(
          width: 14,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: filled ? color : _C.bg3,
            borderRadius: BorderRadius.circular(1),
            border: Border.all(
              color: filled ? color.withValues(alpha: 0.7) : _C.borderDim,
              width: 0.5,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int currentLevel;
  final int maxLevel;
  final int? nextCost;
  final String bonusLabel;
  final int silverBalance;
  final bool purchasing;
  final VoidCallback onUpgrade;

  const _UpgradeCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentLevel,
    required this.maxLevel,
    required this.nextCost,
    required this.bonusLabel,
    required this.silverBalance,
    required this.purchasing,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isMaxed = currentLevel >= maxLevel;
    final canAfford = nextCost != null && silverBalance >= nextCost!;

    return _PlateBox(
      accentColor: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: _T.body.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LevelPips(current: currentLevel, max: maxLevel, color: color),
              const SizedBox(width: 10),
              Text(
                bonusLabel,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: currentLevel > 0 ? color : _C.textMuted,
                ),
              ),
              const Spacer(),
              if (isMaxed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'MAXED',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: color,
                    ),
                  ),
                )
              else
                _ForgeButton(
                  label: '${nextCost ?? 0}',
                  icon: Icons.paid_rounded,
                  loading: purchasing,
                  onTap: (canAfford && !purchasing) ? onUpgrade : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  const _ForgeButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null || loading;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled ? _C.bg3 : _C.amber,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isDisabled ? _C.borderDim : _C.amber,
            width: 1,
          ),
          boxShadow: !isDisabled
              ? [
                  BoxShadow(
                    color: _C.amber.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.bg0),
              )
            else
              Icon(icon, size: 16, color: _C.bg0),
            const SizedBox(width: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: isDisabled ? _C.textMuted : _C.bg0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
