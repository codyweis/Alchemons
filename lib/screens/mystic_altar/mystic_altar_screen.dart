// lib/screens/mystic_altar/mystic_altar_screen.dart
//
// MYSTIC ALTAR — Spinning Relic Wheel hub.
// A 3‑D turntable of boss altars that you spin to select.
// Empty relic slot → tap to commit the key item → slot glows → portal into ritual.

import 'dart:math' as math;

import 'package:alchemons/data/boss_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/providers/boss_provider.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/mystic_altar/boss_altar_detail_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFF060912);
  static const surface = Color(0xFF111320);
  static const text = Color(0xFFE8E0FF);
  static const muted = Color(0xFF4A3F6B);
  static const sub = Color(0xFF8C7BB5);
  static const gold = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const locked = Color(0xFF374151);
  static const void_ = Color(0xFF1A1040);
  static const voidBright = Color(0xFF7C3AED);
  static const voidGlow = Color(0xFFAB78FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MysticAltarScreen extends StatefulWidget {
  const MysticAltarScreen({super.key});

  @override
  State<MysticAltarScreen> createState() => _MysticAltarScreenState();
}

class _MysticAltarScreenState extends State<MysticAltarScreen>
    with TickerProviderStateMixin {
  // animations
  late final AnimationController _bgCtrl;

  // wheel
  double _wheelOffset = 0.0;
  int _selectedIdx = 0;
  late final AnimationController _snapCtrl;
  late Animation<double> _snapAnim;

  // per-boss "relic placed" visual flag (persists during session)
  final Set<String> _relicPlaced = {};

  // relic placement flash animation
  late final AnimationController _relicFlashCtrl;
  String? _relicFlashBossId;

  // arcane portal discovery animation
  late final AnimationController _portalCtrl; // 0→1 over ~3s
  bool _portalDiscovered = false;

  // data
  Map<String, int> _keyItemQtys = {};
  Map<String, int> _placedCounts = {};
  Map<String, int> _requiredCounts = {};
  Map<String, String> _mysticNames = {};
  bool _loading = true;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _relicFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _portalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _snapAnim = AlwaysStoppedAnimation(_wheelOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadState());
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _snapCtrl.dispose();
    _relicFlashCtrl.dispose();
    _portalCtrl.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _loadState() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final bosses = BossRepository.allBosses;

    final qtys = <String, int>{};
    final placed = <String, int>{};
    final req = <String, int>{};

    final mysticNames = <String, String>{};

    for (final boss in bosses) {
      final tk = BossLootKeys.traitKeyForElement(boss.element);
      qtys[boss.id] = await db.inventoryDao.getItemQty(tk);
      final pls = await db.altarDao.getPlacementsForBoss(boss.id);
      placed[boss.id] = pls.length;
      final mc = catalog.mysticByElement(boss.element);
      mysticNames[boss.id] = mc?.name ?? boss.name;
      req[boss.id] = catalog
          .byType(boss.element)
          .where((s) => s.id != mc?.id)
          .length;
    }

    final relicIds = await db.altarDao.getRelicPlacedIds(
      bosses.map((b) => b.id).toList(),
    );

    if (mounted) {
      setState(() {
        _keyItemQtys = qtys;
        _placedCounts = placed;
        _requiredCounts = req;
        _mysticNames = mysticNames;
        _relicPlaced
          ..clear()
          ..addAll(relicIds);
        _loading = false;
      });
    }
  }

  // ── wheel math ────────────────────────────────────────────────────────────

  int get _n => BossRepository.allBosses.length;
  double _bossAngle(int i) => _norm(_wheelOffset + (i / _n) * math.pi * 2);
  double _norm(double a) {
    while (a > math.pi) {
      a -= math.pi * 2;
    }
    while (a < -math.pi) {
      a += math.pi * 2;
    }
    return a;
  }

  double _depth(int i) => (math.cos(_bossAngle(i)) + 1) / 2;

  void _onPanUpdate(DragUpdateDetails d) {
    _snapCtrl.stop();
    setState(() {
      _wheelOffset += d.delta.dx * 0.013;
      _updateSel();
    });
  }

  void _onPanEnd(DragEndDetails _) => _snapToSel();

  void _updateSel() {
    double minD = double.infinity;
    for (int i = 0; i < _n; i++) {
      final d = _bossAngle(i).abs();
      if (d < minD) {
        minD = d;
        _selectedIdx = i;
      }
    }
  }

  void _snapToSel() {
    double t = -(_selectedIdx / _n) * math.pi * 2;
    while ((t - _wheelOffset) > math.pi) {
      t -= math.pi * 2;
    }
    while ((t - _wheelOffset) < -math.pi) {
      t += math.pi * 2;
    }
    final from = _wheelOffset;
    _snapCtrl.reset();
    _snapAnim = Tween<double>(begin: from, end: t).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutBack),
    )..addListener(() => setState(() => _wheelOffset = _snapAnim.value));
    _snapCtrl.forward();
  }

  // ── interaction ───────────────────────────────────────────────────────────

  Future<void> _handleTap(Boss boss) async {
    final progress = context.read<BossProgressNotifier>();
    final defeated = progress.isBossDefeated(boss.id);
    final hasKey = (_keyItemQtys[boss.id] ?? 0) > 0;
    final unlocked = defeated && hasKey;

    if (!unlocked) {
      HapticFeedback.lightImpact();
      _snack(
        defeated
            ? 'Obtain the ${_traitName(boss)} to unlock.'
            : 'Defeat ${boss.name} first.',
      );
      return;
    }

    if (!_relicPlaced.contains(boss.id)) {
      await _doPlaceRelic(boss);
    } else {
      _navigate(boss);
    }
  }

  Future<void> _doPlaceRelic(Boss boss) async {
    final tn = _traitName(boss);
    HapticFeedback.mediumImpact();
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => _RelicPlaceDialog(
            boss: boss,
            traitName: tn,
            onCancel: () => Navigator.pop(ctx, false),
            onConfirm: () => Navigator.pop(ctx, true),
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    final db = context.read<AlchemonsDatabase>();
    await db.altarDao.setRelicPlaced(boss.id);
    setState(() {
      _relicPlaced.add(boss.id);
      _relicFlashBossId = boss.id;
    });
    HapticFeedback.heavyImpact();
    _relicFlashCtrl.forward(from: 0);

    // ── Check if ALL relics are now placed → Arcane Portal Discovery ──
    if (_relicPlaced.length >= _n) {
      await _triggerArcanePortalDiscovery(db);
    } else {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _navigate(boss);
    }
  }

  /// Plays the full arcane-portal discovery animation sequence:
  /// 1. Wheel spins faster
  /// 2. Centre swirl grows, speeds up, then "explodes"
  /// 3. Screen flashes white
  /// 4. Popup: "ARCANE PORTAL DISCOVERED"
  /// 5. Persists unlock flag
  Future<void> _triggerArcanePortalDiscovery(AlchemonsDatabase db) async {
    // Persist the unlock immediately
    await db.settingsDao.setSetting('arcane_portal_unlocked', '1');

    // Spin the wheel rapidly during the animation
    void spinWheel() {
      if (!mounted) return;
      // Accelerate: slow at start, fast in middle, ease off near end
      final p = _portalCtrl.value;
      final speed = 0.05 + p * 0.25; // ramps up from 0.05 → 0.30 rad/frame
      setState(() => _wheelOffset += speed);
    }

    _portalCtrl.addListener(spinWheel);

    // Begin the portal animation (drives wheel spin-up + swirl expansion)
    setState(() => _portalDiscovered = true);

    // Wait for the animation to finish
    await _portalCtrl.forward(from: 0).orCancel.catchError((_) {});
    _portalCtrl.removeListener(spinWheel);
    if (!mounted) return;

    // Show the discovery popup
    HapticFeedback.heavyImpact();
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => _ArcanePortalPopup(onDismiss: () => Navigator.pop(ctx)),
    );

    if (mounted) setState(() => _portalDiscovered = false);
  }

  void _navigate(Boss boss) {
    Navigator.push(
      context,
      _PortalRoute(child: BossAltarDetailScreen(boss: boss)),
    ).then((_) => _loadState());
  }

  String _traitName(Boss boss) =>
      BossLootKeys.elementRewards[boss.element.toLowerCase()]?.traitName ??
      'Key Item';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
        backgroundColor: _C.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bosses = BossRepository.allBosses;
    final progress = context.watch<BossProgressNotifier>();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: AlchemicalParticleBackground(backgroundColor: _C.bg),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) =>
                  CustomPaint(painter: _StarfieldPainter(t: _bgCtrl.value)),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _C.voidBright,
                      strokeWidth: 1.5,
                    ),
                  )
                : Column(
                    children: [
                      _Header(
                        bgCtrl: _bgCtrl,
                        onBack: () => VoidPortal.pop(context),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          behavior: HitTestBehavior.opaque,
                          child: _SpinningWheel(
                            bosses: bosses,
                            progress: progress,
                            keyQtys: _keyItemQtys,
                            placed: _placedCounts,
                            required: _requiredCounts,
                            relicPlaced: _relicPlaced,
                            depthOf: _depth,
                            angleOf: _bossAngle,
                            selected: _selectedIdx,
                            bgCtrl: _bgCtrl,
                            relicFlashCtrl: _relicFlashCtrl,
                            relicFlashBossId: _relicFlashBossId,
                            onTap: _handleTap,
                            portalCtrl: _portalCtrl,
                            portalDiscovered: _portalDiscovered,
                          ),
                        ),
                      ),
                      if (bosses.isNotEmpty) ...[
                        _InfoPanel(
                          boss: bosses[_selectedIdx],
                          mysticName:
                              _mysticNames[bosses[_selectedIdx].id] ??
                              bosses[_selectedIdx].name,
                          progress: progress,
                          keyQty: _keyItemQtys[bosses[_selectedIdx].id] ?? 0,
                          placedCount:
                              _placedCounts[bosses[_selectedIdx].id] ?? 0,
                          requiredCount:
                              _requiredCounts[bosses[_selectedIdx].id] ?? 0,
                          relicPlaced: _relicPlaced.contains(
                            bosses[_selectedIdx].id,
                          ),
                          bgCtrl: _bgCtrl,
                          onEnter: () => _handleTap(bosses[_selectedIdx]),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AnimationController bgCtrl;
  final VoidCallback onBack;
  const _Header({
    required this.bgCtrl,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _C.void_.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _C.voidBright.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _C.sub,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MYSTIC ALTAR',
                  style: GoogleFonts.cinzelDecorative(
                    color: _C.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'SPIN · SELECT · SUMMON',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _C.muted,
                    fontSize: 8,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPINNING WHEEL
// ─────────────────────────────────────────────────────────────────────────────

class _SpinningWheel extends StatelessWidget {
  final List<Boss> bosses;
  final BossProgressNotifier progress;
  final Map<String, int> keyQtys, placed, required;
  final Set<String> relicPlaced;
  final double Function(int) depthOf, angleOf;
  final int selected;
  final AnimationController bgCtrl;
  final AnimationController relicFlashCtrl;
  final String? relicFlashBossId;
  final void Function(Boss) onTap;
  final AnimationController portalCtrl;
  final bool portalDiscovered;

  const _SpinningWheel({
    required this.bosses,
    required this.progress,
    required this.keyQtys,
    required this.placed,
    required this.required,
    required this.relicPlaced,
    required this.depthOf,
    required this.angleOf,
    required this.selected,
    required this.bgCtrl,
    required this.relicFlashCtrl,
    required this.relicFlashBossId,
    required this.onTap,
    required this.portalCtrl,
    required this.portalDiscovered,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final cx = w / 2, cy = h * 0.46;
        final rx = w * 0.35, ry = h * 0.20;

        final sorted = List.generate(bosses.length, (i) => i)
          ..sort((a, b) => depthOf(a).compareTo(depthOf(b)));

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: bgCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _WheelTrackPainter(
                    cx: cx,
                    cy: cy,
                    rx: rx,
                    ry: ry,
                    t: bgCtrl.value,
                  ),
                ),
              ),
            ),
            for (final i in sorted) _buildNode(i, cx, cy, rx, ry),
            // Centre eye — grows & spins faster during portal discovery
            Positioned(
              left: cx - 34,
              top: cy - 34,
              child: AnimatedBuilder(
                animation: Listenable.merge([bgCtrl, portalCtrl]),
                builder: (_, __) {
                  // During portal discovery, the swirl grows from 68→200px
                  // and its rotation speed multiplier goes from 1× → 8×
                  final p = portalCtrl.value;
                  final growScale = 1.0 + p * 2.5; // 1× → 3.5×
                  final speedMul = 1.0 + p * 7.0; // 1× → 8×
                  final effectiveT = bgCtrl.value * speedMul;
                  // Fade-out near the end of the portal anim (explosion)
                  final opacity = p > 0.85
                      ? (1.0 - ((p - 0.85) / 0.15)).clamp(0.0, 1.0)
                      : 1.0;
                  return Transform.scale(
                    scale: growScale,
                    child: Opacity(
                      opacity: opacity,
                      child: _AltarEye(t: effectiveT),
                    ),
                  );
                },
              ),
            ),
            // White flash overlay during explosion phase
            if (portalDiscovered)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: portalCtrl,
                  builder: (_, __) {
                    // Flash starts at 80% of animation and peaks at 90%
                    final p = portalCtrl.value;
                    final flashAlpha = p > 0.80
                        ? (p > 0.90
                                  ? (1.0 - ((p - 0.90) / 0.10))
                                  : ((p - 0.80) / 0.10))
                              .clamp(0.0, 1.0)
                        : 0.0;
                    return IgnorePointer(
                      child: Container(
                        color: Colors.white.withValues(alpha: flashAlpha * 0.9),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNode(int i, double cx, double cy, double rx, double ry) {
    final boss = bosses[i];
    final angle = angleOf(i);
    final depth = depthOf(i);
    final x = cx + rx * math.sin(angle);
    final y = cy + ry * math.cos(angle);
    final scale = 0.48 + 0.52 * depth;
    final opacity = (0.18 + 0.82 * depth).clamp(0.0, 1.0);
    final nodeSize = 60.0 * scale;
    final isSel = i == selected;

    final defeated = progress.isBossDefeated(boss.id);
    final hasKey = (keyQtys[boss.id] ?? 0) > 0;
    final unlocked = defeated && hasKey;
    final pc = placed[boss.id] ?? 0;
    final rc = required[boss.id] ?? 0;
    final complete = unlocked && rc > 0 && pc >= rc;
    final rp = relicPlaced.contains(boss.id);

    final isFlashing = boss.id == relicFlashBossId;

    return Positioned(
      left: x - nodeSize / 2,
      top: y - nodeSize / 2,
      child: GestureDetector(
        onTap: () => onTap(boss),
        child: AnimatedBuilder(
          animation: isFlashing
              ? Listenable.merge([bgCtrl, relicFlashCtrl])
              : bgCtrl,
          builder: (_, __) {
            final pulse = (math.sin(bgCtrl.value * math.pi * 2) + 1) / 2;
            final ft = isFlashing ? relicFlashCtrl.value : 0.0;
            final flashScale = 1.0 + 0.26 * math.sin(ft * math.pi);
            final ring1Scale = 1.0 + ft * 2.2;
            final ring1Op = (1.0 - ft).clamp(0.0, 1.0);
            final ft2 = ((ft - 0.18) / 0.82).clamp(0.0, 1.0);
            final ring2Scale = 1.0 + ft2 * 1.8;
            final ring2Op = (1.0 - ft2).clamp(0.0, 1.0) * 0.50;
            return Opacity(
              opacity: opacity,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Flash burst ring 1
                  if (ring1Op > 0.01)
                    Transform.scale(
                      scale: ring1Scale,
                      child: Container(
                        width: nodeSize,
                        height: nodeSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: boss.elementColor.withValues(
                              alpha: ring1Op * 0.95,
                            ),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  // Flash burst ring 2
                  if (ring2Op > 0.01)
                    Transform.scale(
                      scale: ring2Scale,
                      child: Container(
                        width: nodeSize,
                        height: nodeSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: boss.elementColor.withValues(alpha: ring2Op),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: isFlashing ? flashScale : 1.0,
                    child: _BossNode(
                      boss: boss,
                      size: nodeSize,
                      isSelected: isSel,
                      unlocked: unlocked,
                      complete: complete,
                      relicPlaced: rp,
                      defeated: defeated,
                      hasKey: hasKey,
                      placed: pc,
                      required: rc,
                      pulse: pulse,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOSS NODE
// ─────────────────────────────────────────────────────────────────────────────

class _BossNode extends StatelessWidget {
  final Boss boss;
  final double size, pulse;
  final bool isSelected, unlocked, complete, relicPlaced, defeated, hasKey;
  final int placed, required;

  const _BossNode({
    required this.boss,
    required this.size,
    required this.pulse,
    required this.isSelected,
    required this.unlocked,
    required this.complete,
    required this.relicPlaced,
    required this.defeated,
    required this.hasKey,
    required this.placed,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    final elColor = boss.elementColor;

    // ── relic-placed: vivid glow halo ──────────────────────────────────
    if (relicPlaced && unlocked) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Bloom glow behind disc
          Container(
            width: size + 4,
            height: size + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: elColor.withValues(alpha: 0.50 + pulse * 0.38),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          // Main disc — vivid and bright
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: elColor.withValues(alpha: 0.28 + pulse * 0.16),
              border: Border.all(
                color: elColor.withValues(alpha: 0.75 + pulse * 0.20),
                width: isSelected ? 2.5 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: elColor.withValues(alpha: 0.55 + pulse * 0.30),
                  blurRadius: 22,
                  spreadRadius: 3,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              boss.relicImagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(boss.elementIcon, color: elColor, size: size * 0.44),
            ),
          ),
          // Progress ring
          if (required > 0)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: required > 0 ? placed / required : 0.0,
                strokeWidth: 2.0,
                backgroundColor: elColor.withValues(alpha: 0.06),
                color: complete ? _C.success : elColor.withValues(alpha: 0.60),
              ),
            ),
        ],
      );
    }

    // ── default (no relic) ───────────────────────────────────────────────
    final glowC = complete ? elColor : (hasKey ? _C.gold : elColor);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer glow ring (selected only)
        if (isSelected && unlocked)
          Container(
            width: size + 20 + pulse * 8,
            height: size + 20 + pulse * 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: glowC.withValues(alpha: 0.18 + pulse * 0.24),
                width: 1.0,
              ),
            ),
          ),

        // Main disc
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked
                ? elColor.withValues(alpha: 0.10)
                : _C.surface.withValues(alpha: 0.45),
            border: Border.all(
              color: unlocked
                  ? elColor.withValues(
                      alpha: isSelected ? (0.55 + pulse * 0.30) : 0.22,
                    )
                  : _C.locked.withValues(alpha: 0.22),
              width: isSelected ? 2.0 : 0.8,
            ),
            boxShadow: (isSelected && unlocked)
                ? [
                    BoxShadow(
                      color: glowC.withValues(alpha: 0.30 + pulse * 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              unlocked
                  ? elColor.withValues(alpha: 0.60)
                  : _C.locked.withValues(alpha: 0.55),
              BlendMode.srcIn,
            ),
            child: Opacity(
              opacity: unlocked ? 0.55 : 0.30,
              child: Image.asset(
                boss.relicImagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  unlocked ? boss.elementIcon : Icons.lock_outline_rounded,
                  color: unlocked ? elColor : _C.locked.withValues(alpha: 0.45),
                  size: size * (unlocked ? 0.38 : 0.33),
                ),
              ),
            ),
          ),
        ),

        // Progress ring
        if (unlocked && required > 0)
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: required > 0 ? placed / required : 0.0,
              strokeWidth: 2.0,
              backgroundColor: elColor.withValues(alpha: 0.06),
              color: complete ? _C.success : elColor.withValues(alpha: 0.50),
            ),
          ),

        // Key badge (bottom-right)
        if (unlocked)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasKey ? _C.gold : _C.surface.withValues(alpha: 0.8),
                border: Border.all(
                  color: hasKey ? _C.gold : _C.muted,
                  width: 0.7,
                ),
              ),
              child: Icon(
                hasKey ? Icons.key_rounded : Icons.add_rounded,
                color: hasKey ? Colors.black87 : _C.muted,
                size: size * 0.13,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final Boss boss;
  final String mysticName;
  final BossProgressNotifier progress;
  final int keyQty, placedCount, requiredCount;
  final bool relicPlaced;
  final AnimationController bgCtrl;
  final VoidCallback onEnter;

  const _InfoPanel({
    required this.boss,
    required this.mysticName,
    required this.progress,
    required this.keyQty,
    required this.placedCount,
    required this.requiredCount,
    required this.relicPlaced,
    required this.bgCtrl,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final elColor = boss.elementColor;
    final defeated = progress.isBossDefeated(boss.id);
    final hasKey = keyQty > 0;
    final unlocked = defeated && hasKey;
    final complete =
        unlocked && placedCount >= requiredCount && requiredCount > 0;
    final tn =
        BossLootKeys.elementRewards[boss.element.toLowerCase()]?.traitName ??
        'Key Item';

    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) {
        final p = (math.sin(bgCtrl.value * math.pi * 2) + 1) / 2;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: _C.surface.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unlocked
                  ? elColor.withValues(alpha: 0.18 + p * 0.20)
                  : _C.muted.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: complete
                ? [
                    BoxShadow(
                      color: elColor.withValues(alpha: 0.14 + p * 0.14),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? elColor.withValues(alpha: 0.12)
                      : _C.locked.withValues(alpha: 0.08),
                  border: Border.all(
                    color: unlocked
                        ? elColor.withValues(alpha: 0.35 + p * 0.25)
                        : _C.locked.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                ),
                child: relicPlaced && unlocked
                    ? ClipOval(
                        child: Image.asset(
                          boss.relicImagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(boss.elementIcon, color: elColor, size: 22),
                        ),
                      )
                    : Icon(
                        boss.elementIcon,
                        color: unlocked
                            ? elColor
                            : _C.locked.withValues(alpha: 0.45),
                        size: 22,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mysticName.toUpperCase(),
                      style: GoogleFonts.cinzelDecorative(
                        color: unlocked ? elColor : _C.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _statusColor(elColor, unlocked, complete),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _statusText(unlocked, complete, tn),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _statusColor(elColor, unlocked, complete),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    if (unlocked && requiredCount > 0) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: List.generate(requiredCount.clamp(0, 10), (
                          i,
                        ) {
                          final f = i < placedCount;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.2,
                              ),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: f
                                      ? (complete ? _C.success : elColor)
                                            .withValues(alpha: 0.85)
                                      : elColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onEnter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? elColor.withValues(alpha: 0.14 + p * 0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: unlocked
                          ? elColor.withValues(alpha: 0.50)
                          : _C.muted.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    unlocked
                        ? (complete
                              ? 'SUMMON'
                              : (relicPlaced ? 'ENTER' : 'PLACE'))
                        : 'LOCKED',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: unlocked
                          ? elColor
                          : _C.muted.withValues(alpha: 0.35),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusText(bool unlocked, bool complete, String tn) {
    final def = progress.isBossDefeated(boss.id);
    if (!def) return 'DEFEAT ${boss.name.toUpperCase()} FIRST';
    if (!unlocked) return 'KEY REQUIRED: ${tn.toUpperCase()}';
    if (complete) return 'ALL OFFERINGS SET — READY TO SUMMON';
    if (placedCount > 0) {
      return '$placedCount / $requiredCount OFFERINGS COMMITTED';
    }
    if (relicPlaced) return 'RELIC PLACED — ENTER THE ALTAR';
    return 'PLACE ${tn.toUpperCase()} TO BEGIN';
  }

  Color _statusColor(Color el, bool unlocked, bool complete) {
    if (!unlocked) return _C.muted;
    if (complete) return _C.success;
    if (placedCount > 0) return _C.gold;
    if (keyQty > 0) return el;
    return _C.muted;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RELIC PLACE DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _RelicPlaceDialog extends StatefulWidget {
  final Boss boss;
  final String traitName;
  final VoidCallback onCancel, onConfirm;
  const _RelicPlaceDialog({
    required this.boss,
    required this.traitName,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<_RelicPlaceDialog> createState() => _RelicPlaceDialogState();
}

class _RelicPlaceDialogState extends State<_RelicPlaceDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _s = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elColor = widget.boss.elementColor;
    return ScaleTransition(
      scale: _s,
      child: Dialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: elColor.withValues(alpha: 0.55), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: elColor.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.gold.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _C.gold.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.gold.withValues(alpha: 0.30),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      widget.boss.relicImagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.key_rounded,
                        color: _C.gold,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PLACE RELIC',
                    style: GoogleFonts.cinzelDecorative(
                      color: _C.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Commit the ${widget.traitName} to the ${widget.boss.name} altar and open the ritual chamber.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _C.sub,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _Btn(
                          label: 'CANCEL',
                          color: _C.muted,
                          onTap: widget.onCancel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Btn(
                          label: 'COMMIT',
                          color: elColor,
                          onTap: widget.onConfirm,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WHEEL TRACK PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _WheelTrackPainter extends CustomPainter {
  final double cx, cy, rx, ry, t;
  const _WheelTrackPainter({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Elliptical orbit track
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..color = _C.voidBright.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    // Outer faint dashes
    const segs = 28;
    final outerRx = rx + 12, outerRy = ry + 8;
    final dashPaint = Paint()
      ..color = _C.voidBright.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i < segs; i++) {
      final a0 = (i / segs) * math.pi * 2 + t * math.pi * 0.5;
      final a1 = a0 + (math.pi * 2 / segs) * 0.45;
      final path = Path();
      const steps = 6;
      for (int s = 0; s <= steps; s++) {
        final a = a0 + (a1 - a0) * s / steps;
        final px = cx + outerRx * math.sin(a);
        final py = cy + outerRy * math.cos(a);
        if (s == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, dashPaint);
    }
    // Centre nebula
    canvas.drawCircle(
      Offset(cx, cy),
      32,
      Paint()
        ..color = _C.voidBright.withValues(
          alpha: 0.04 + 0.03 * math.sin(t * math.pi * 2),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(_WheelTrackPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// ALTAR EYE (centre ornament)
// ─────────────────────────────────────────────────────────────────────────────

class _AltarEye extends StatelessWidget {
  final double t;
  const _AltarEye({required this.t});

  @override
  Widget build(BuildContext context) {
    final p = (math.sin(t * math.pi * 2) + 1) / 2;
    return SizedBox(
      width: 68,
      height: 68,
      child: CustomPaint(
        painter: _SwirlPainter(t: t, pulse: p),
      ),
    );
  }
}

class _SwirlPainter extends CustomPainter {
  final double t;
  final double pulse;
  const _SwirlPainter({required this.t, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // ── Soft core bloom (no background, just the glow) ─────────────────
    canvas.drawCircle(
      center,
      size.width * 0.18 + pulse * 4,
      Paint()
        ..color = _C.voidBright.withValues(alpha: 0.18 + pulse * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Spiral arms ───────────────────────────────────────────────────
    // 3 arms, evenly spaced, each sweeps 300°, tapered tip→outer
    const arms = 3;
    const sweepRad = math.pi * (300 / 180);
    const steps = 55;

    for (int arm = 0; arm < arms; arm++) {
      final armOffset = (arm / arms) * math.pi * 2;

      // Draw arm as individual short segments so we can taper width + opacity
      for (int s = 0; s < steps; s++) {
        final fracA = s / steps;
        final fracB = (s + 1) / steps;

        final rA = size.width * 0.04 + fracA * size.width * 0.44;
        final rB = size.width * 0.04 + fracB * size.width * 0.44;

        final angleA = t * math.pi * 2 + armOffset + fracA * sweepRad;
        final angleB = t * math.pi * 2 + armOffset + fracB * sweepRad;

        final pA = Offset(
          cx + rA * math.cos(angleA),
          cy + rA * math.sin(angleA),
        );
        final pB = Offset(
          cx + rB * math.cos(angleB),
          cy + rB * math.sin(angleB),
        );

        // Taper: thin+dim at core, thick+bright at outer tip
        final opacity = (0.05 + fracA * 0.85).clamp(0.0, 1.0);
        final strokeW = 0.5 + fracA * 2.8;

        canvas.drawLine(
          pA,
          pB,
          Paint()
            ..color = _C.voidGlow.withValues(
              alpha: opacity * (0.55 + pulse * 0.45),
            )
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round,
        );

        // Thin white shimmer on outer half only
        if (fracA > 0.5) {
          final shimmerOp = ((fracA - 0.5) * 2 * 0.35 * (0.3 + pulse * 0.5))
              .clamp(0.0, 1.0);
          canvas.drawLine(
            pA,
            pB,
            Paint()
              ..color = Colors.white.withValues(alpha: shimmerOp)
              ..strokeWidth = strokeW * 0.35
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // ── Hot centre dot ────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      3.0 + pulse * 1.6,
      Paint()
        ..color = _C.voidGlow.withValues(alpha: 0.80 + pulse * 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      center,
      1.4,
      Paint()..color = Colors.white.withValues(alpha: 0.85 + pulse * 0.15),
    );
  }

  @override
  bool shouldRepaint(_SwirlPainter old) => old.t != t || old.pulse != pulse;
}

// ─────────────────────────────────────────────────────────────────────────────
// STARFIELD
// ─────────────────────────────────────────────────────────────────────────────

class _StarfieldPainter extends CustomPainter {
  final double t;
  _StarfieldPainter({required this.t});

  static final _rng = math.Random(77);
  static final _stars = List.generate(
    80,
    (_) => Offset(_rng.nextDouble(), _rng.nextDouble()),
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final b = 0.12 + 0.55 * ((math.sin(t * math.pi * 2 + i * 1.73) + 1) / 2);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        0.4 + (i % 3) * 0.4,
        Paint()..color = _C.voidGlow.withValues(alpha: b),
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// ARCANE PORTAL POPUP
// ─────────────────────────────────────────────────────────────────────────────

class _ArcanePortalPopup extends StatefulWidget {
  final VoidCallback onDismiss;
  const _ArcanePortalPopup({required this.onDismiss});

  @override
  State<_ArcanePortalPopup> createState() => _ArcanePortalPopupState();
}

class _ArcanePortalPopupState extends State<_ArcanePortalPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0420),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.voidBright, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _C.voidBright.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: _C.voidGlow.withValues(alpha: 0.3),
                      blurRadius: 80,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Swirl icon
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _SwirlPainter(t: _ctrl.value * 2, pulse: 0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ARCANE PORTAL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzelDecorative(
                        color: _C.voidGlow,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'DISCOVERED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzelDecorative(
                        color: _C.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'A rift to the arcane realm has opened\non the expedition map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _C.sub,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onDismiss();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _C.voidBright.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _C.voidBright.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'CONTINUE',
                          style: GoogleFonts.cinzelDecorative(
                            color: _C.voidGlow,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PORTAL ROUTE
// ─────────────────────────────────────────────────────────────────────────────

class _PortalRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  _PortalRoute({required this.child})
    : super(
        pageBuilder: (_, __, ___) => child,
        transitionDuration: const Duration(milliseconds: 650),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.18, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      );
}
