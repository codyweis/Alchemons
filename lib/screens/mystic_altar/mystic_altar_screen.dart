import 'package:alchemons/services/onboarding_tasks.dart';
import 'dart:async';
import 'package:alchemons/audio/audio.dart';
// lib/screens/mystic_altar/mystic_altar_screen.dart
//
// MYSTIC ALTAR — Spinning Relic Wheel hub.
// A 3‑D turntable of boss altars that you spin to select.
// Empty relic slot → tap to commit the key item → slot glows → portal into ritual.

import 'dart:math' as math;

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/mystic_altar/boss_altar_detail_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFF060912);
  static const surface = Color(0xFF111320);
  static const muted = Color(0xFF4A3F6B);
  static const gold = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const locked = Color(0xFF374151);
  static const voidBright = Color(0xFF7C3AED);
  static const voidGlow = Color(0xFFAB78FF);

  // Ivory/cream rite-style palette — borders and chrome stay neutral so
  // element color only appears as a small accent (dot, icon tint, text).
  static const ivory = Color(0xFFE8DFC8);
  static const ivoryDim = Color(0xFFB5A98A);
  static const ivoryMuted = Color(0xFF6B6050);
}

TextStyle _titleStyle(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

TextStyle _display(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) => _titleStyle(
  context,
  size,
  color,
  weight: weight,
  letterSpacing: letterSpacing,
  fontStyle: fontStyle,
);

TextStyle _body(
  BuildContext context,
  double size,
  Color color, {
  double height = 1.5,
  FontWeight weight = FontWeight.w400,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
  );
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
  final Set<String> _ritualCompleted = {};

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
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'rite');
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
    final bosses = kAltarEntries;

    final qtys = <String, int>{};
    final placed = <String, int>{};
    final req = <String, int>{};

    final mysticNames = <String, String>{};
    final completed = <String>{};

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
      final summonedValue = await db.settingsDao.getSetting(
        'altar_summoned_${boss.id}',
      );
      if (summonedValue != null && summonedValue.trim().isNotEmpty) {
        completed.add(boss.id);
      }
    }

    final relicIds = await db.altarDao.getRelicPlacedIds(
      bosses.map((b) => b.id).toList(),
    );
    relicIds.addAll(completed);

    if (mounted) {
      setState(() {
        _keyItemQtys = qtys;
        _placedCounts = placed;
        _requiredCounts = req;
        _mysticNames = mysticNames;
        _relicPlaced
          ..clear()
          ..addAll(relicIds);
        _ritualCompleted
          ..clear()
          ..addAll(completed);
        _loading = false;
      });
    }
  }

  // ── wheel math ────────────────────────────────────────────────────────────

  int get _n => kAltarEntries.length;
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

  Future<void> _handleTap(AltarEntry boss) async {
    final hasKey = (_keyItemQtys[boss.id] ?? 0) > 0;
    final relicSet = _relicPlaced.contains(boss.id);
    final ritualComplete = _ritualCompleted.contains(boss.id);
    final unlocked = hasKey || relicSet || ritualComplete;

    if (!unlocked) {
      HapticFeedback.lightImpact();
      _snack(
        'Defeat the ${boss.element} planet guardian to earn the ${_traitName(boss)}.',
      );
      return;
    }

    if (!_relicPlaced.contains(boss.id)) {
      await _doPlaceRelic(boss);
    } else {
      _navigate(boss);
    }
  }

  Future<void> _doPlaceRelic(AltarEntry boss) async {
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
    final traitKey = BossLootKeys.traitKeyForElement(boss.element);
    final consumed = await db.inventoryDao.consumeItem(traitKey, qty: 1);
    if (!consumed) {
      _snack('Obtain the ${_traitName(boss)} to unlock.');
      return;
    }
    await db.altarDao.setRelicPlaced(boss.id);
    setState(() {
      _relicPlaced.add(boss.id);
      _keyItemQtys[boss.id] = math.max(0, (_keyItemQtys[boss.id] ?? 0) - 1);
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
  /// 2. Centre well grows, spins up into a vortex, then "explodes"
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

  void _navigate(AltarEntry boss) {
    Navigator.push(
      context,
      _PortalRoute(child: BossAltarDetailScreen(boss: boss)),
    ).then((_) => _loadState());
  }

  String _traitName(AltarEntry boss) =>
      BossLootKeys.elementRewards[boss.element.toLowerCase()]?.traitName ??
      'Key Item';

  void _snack(String msg) {
    if (!mounted) return;
    final boss = kAltarEntries[_selectedIdx];
    final elColor = boss.elementColor;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.error_outline_rounded,
              color: elColor.withValues(alpha: 0.95),
              size: 17,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: _C.ivory,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B0D14),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: Border(
          left: BorderSide(color: elColor.withValues(alpha: 0.72), width: 2),
          top: BorderSide(color: elColor.withValues(alpha: 0.28), width: 1),
          bottom: BorderSide(color: elColor.withValues(alpha: 0.20), width: 1),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bosses = kAltarEntries;

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
                            keyQtys: _keyItemQtys,
                            placed: _placedCounts,
                            required: _requiredCounts,
                            relicPlaced: _relicPlaced,
                            ritualCompleted: _ritualCompleted,
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
                          keyQty: _keyItemQtys[bosses[_selectedIdx].id] ?? 0,
                          placedCount:
                              _placedCounts[bosses[_selectedIdx].id] ?? 0,
                          requiredCount:
                              _requiredCounts[bosses[_selectedIdx].id] ?? 0,
                          relicPlaced: _relicPlaced.contains(
                            bosses[_selectedIdx].id,
                          ),
                          ritualComplete: _ritualCompleted.contains(
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
  const _Header({required this.bgCtrl, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _BackBracketButton(
            onTap: () {
              HapticFeedback.lightImpact();
              onBack();
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mystic Altar',
                  style: _display(context, 24, _C.ivory, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  'Spin the wheel and wake the chosen relic.',
                  style: _display(
                    context,
                    13,
                    _C.ivoryMuted,
                    fontStyle: FontStyle.italic,
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
  static const int _baseSpiralLevel = 1;
  static const double _spiralSpeedStep = 0.08;

  final List<AltarEntry> bosses;
  final Map<String, int> keyQtys, placed, required;
  final Set<String> relicPlaced;
  final Set<String> ritualCompleted;
  final double Function(int) depthOf, angleOf;
  final int selected;
  final AnimationController bgCtrl;
  final AnimationController relicFlashCtrl;
  final String? relicFlashBossId;
  final void Function(AltarEntry) onTap;
  final AnimationController portalCtrl;
  final bool portalDiscovered;

  const _SpinningWheel({
    required this.bosses,
    required this.keyQtys,
    required this.placed,
    required this.required,
    required this.relicPlaced,
    required this.ritualCompleted,
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
        final spiralLevel = _baseSpiralLevel + ritualCompleted.length;
        final baseSpiralSpeed = 1.0 + spiralLevel * _spiralSpeedStep;

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
              left: cx - 46,
              top: cy - 46,
              // Only portalCtrl now: the eye runs its own clock, so this
              // subtree no longer rebuilds on every background frame.
              child: AnimatedBuilder(
                animation: portalCtrl,
                builder: (_, __) {
                  // Baseline is level 1; every completed ritual wakes the
                  // altar a little more. Portal discovery still surges on top.
                  final p = portalCtrl.value;
                  final growScale = 1.0 + p * 2.5; // 1× → 3.5×
                  // Fade-out near the end of the portal anim (explosion)
                  final opacity = p > 0.85
                      ? (1.0 - ((p - 0.85) / 0.15)).clamp(0.0, 1.0)
                      : 1.0;
                  return Transform.scale(
                    scale: growScale,
                    child: Opacity(
                      opacity: opacity,
                      child: _AltarEye(
                        rate: baseSpiralSpeed * (1.0 + p * 7.0),
                        surge: p,
                      ),
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

    final hasKey = (keyQtys[boss.id] ?? 0) > 0;
    final ritualComplete = ritualCompleted.contains(boss.id);
    final rp = relicPlaced.contains(boss.id) || ritualComplete;
    final unlocked = hasKey || rp || ritualComplete;
    final pc = placed[boss.id] ?? 0;
    final rc = required[boss.id] ?? 0;
    final complete = !ritualComplete && unlocked && rc > 0 && pc >= rc;

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
                      ritualComplete: ritualComplete,
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
  final AltarEntry boss;
  final double size, pulse;
  final bool isSelected, unlocked, complete, relicPlaced, ritualComplete;
  final bool hasKey;
  final int placed, required;

  const _BossNode({
    required this.boss,
    required this.size,
    required this.pulse,
    required this.isSelected,
    required this.unlocked,
    required this.complete,
    required this.relicPlaced,
    required this.ritualComplete,
    required this.hasKey,
    required this.placed,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    final elColor = boss.elementColor;

    // ── relic-placed: image shows through with a subtle inner tint ────
    if (relicPlaced && unlocked) {
      final awakenedPulse = ritualComplete ? pulse : 0.0;
      final echoPulse = 1.0 - awakenedPulse;
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (ritualComplete)
            Transform.scale(
              scale: 1.16 + awakenedPulse * 0.34,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: elColor.withValues(
                      alpha: (0.42 - awakenedPulse * 0.26).clamp(0.08, 0.42),
                    ),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: elColor.withValues(alpha: 0.20 + echoPulse * 0.16),
                      blurRadius: 22 + awakenedPulse * 18,
                      spreadRadius: 2 + awakenedPulse * 4,
                    ),
                  ],
                ),
              ),
            ),
          if (ritualComplete)
            Transform.scale(
              scale: 1.03 + echoPulse * 0.18,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: elColor.withValues(alpha: 0.10 + echoPulse * 0.22),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          Transform.scale(
            scale: ritualComplete ? 1.0 + awakenedPulse * 0.045 : 1.0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    elColor.withValues(
                      alpha: ritualComplete
                          ? 0.24 + awakenedPulse * 0.22
                          : 0.18,
                    ),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: (ritualComplete ? elColor : _C.ivoryDim).withValues(
                    alpha: ritualComplete
                        ? 0.66 + awakenedPulse * 0.28
                        : isSelected
                        ? 0.85
                        : 0.45,
                  ),
                  width: ritualComplete || isSelected ? 1.6 : 1.0,
                ),
                boxShadow: ritualComplete
                    ? [
                        BoxShadow(
                          color: elColor.withValues(
                            alpha: 0.14 + awakenedPulse * 0.20,
                          ),
                          blurRadius: 14 + awakenedPulse * 12,
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                boss.relicImagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(boss.elementIcon, color: elColor, size: size * 0.44),
              ),
            ),
          ),
          if (ritualComplete)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.success,
                  border: Border.all(color: _C.bg, width: 1.4),
                ),
                child: Icon(
                  AppIcons.check_rounded,
                  color: Colors.white,
                  size: size * 0.15,
                ),
              ),
            )
          else if (required > 0)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: required > 0 ? placed / required : 0.0,
                strokeWidth: 1.6,
                backgroundColor: _C.ivoryMuted.withValues(alpha: 0.18),
                color: complete
                    ? _C.success
                    : _C.ivoryDim.withValues(alpha: 0.7),
              ),
            ),
        ],
      );
    }

    // ── default (no relic) — neutral chrome, element color is accent ──
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked
                ? Colors.white.withValues(alpha: isSelected ? 0.05 : 0.03)
                : Colors.black.withValues(alpha: 0.18),
            border: Border.all(
              color: unlocked
                  ? _C.ivoryDim.withValues(alpha: isSelected ? 0.85 : 0.35)
                  : _C.ivoryMuted.withValues(alpha: 0.25),
              width: isSelected ? 1.6 : 0.9,
            ),
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
                  unlocked ? boss.elementIcon : AppIcons.lock_outline_rounded,
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
                hasKey ? AppIcons.key_rounded : AppIcons.add_rounded,
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
  final AltarEntry boss;
  final String mysticName;
  final int keyQty, placedCount, requiredCount;
  final bool relicPlaced, ritualComplete;
  final AnimationController bgCtrl;
  final VoidCallback onEnter;

  const _InfoPanel({
    required this.boss,
    required this.mysticName,
    required this.keyQty,
    required this.placedCount,
    required this.requiredCount,
    required this.relicPlaced,
    required this.ritualComplete,
    required this.bgCtrl,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final elColor = boss.elementColor;
    final hasKey = keyQty > 0;
    final unlocked = hasKey || relicPlaced || ritualComplete;
    final complete =
        !ritualComplete &&
        unlocked &&
        placedCount >= requiredCount &&
        requiredCount > 0;
    final tn =
        BossLootKeys.elementRewards[boss.element.toLowerCase()]?.traitName ??
        'Key Item';

    final ctaLabel = ritualComplete
        ? 'Ritual complete'
        : unlocked
        ? (complete
              ? 'Perform ritual'
              : (relicPlaced ? 'Enter altar' : 'Place relic'))
        : 'Locked';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_C.bg.withValues(alpha: 0.92), _C.bg.withValues(alpha: 0.0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked
                      ? RadialGradient(
                          colors: [
                            elColor.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        )
                      : null,
                  color: unlocked ? null : Colors.white.withValues(alpha: 0.03),
                  border: Border.all(
                    color: _C.ivoryDim.withValues(
                      alpha: unlocked ? 0.55 : 0.20,
                    ),
                    width: 1.0,
                  ),
                ),
                child: relicPlaced && unlocked
                    ? ClipOval(
                        child: Image.asset(
                          boss.relicImagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(boss.elementIcon, color: elColor, size: 20),
                        ),
                      )
                    : Icon(
                        boss.elementIcon,
                        color: unlocked
                            ? elColor
                            : Colors.white.withValues(alpha: 0.4),
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mysticName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _display(
                    context,
                    20,
                    unlocked ? _C.ivory : _C.ivoryMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _PanelActionButton(
                onTap: context.soundTap(onEnter),
                label: ctaLabel,
                enabled: unlocked,
                color: ritualComplete ? elColor : null,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Row 2: status line ─────────────────────────────────────
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor(elColor, unlocked, complete),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _statusText(unlocked, complete, tn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    context,
                    13,
                    _statusColor(elColor, unlocked, complete),
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          // ── Row 3: full-width progress bar (only when relevant) ─────
          if (unlocked && requiredCount > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: (placedCount / requiredCount).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(
                    complete ? _C.success : elColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusText(bool unlocked, bool complete, String tn) {
    if (ritualComplete) return '$tn remains awake in the altar';
    if (!unlocked) {
      return 'Defeat the ${boss.element} planet guardian to earn the $tn';
    }
    if (complete) return 'The ritual can begin';
    if (placedCount > 0) {
      return '$placedCount of $requiredCount offerings are placed';
    }
    if (relicPlaced) return 'The relic is set. Enter the altar';
    return 'Place $tn to begin';
  }

  Color _statusColor(Color el, bool unlocked, bool complete) {
    if (ritualComplete) return el;
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
  final AltarEntry boss;
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
    return FadeTransition(
      opacity: _s,
      child: Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(_s),
          child: _RitualDialogSurface(
            accent: elColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RelicPreviewMark(boss: widget.boss, color: elColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Place relic',
                              style: _display(
                                context,
                                18,
                                _C.ivory,
                                weight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.traitName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _body(
                                context,
                                12,
                                _C.ivoryMuted,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Commit the ${widget.traitName} to the ${widget.boss.name} altar and open the ritual chamber.',
                    style: _body(context, 13, _C.ivoryDim, height: 1.55),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _Btn(
                          label: 'Return',
                          color: _C.ivoryMuted,
                          onTap: context.soundTap(widget.onCancel),
                          primary: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Btn(
                          label: 'Place relic',
                          color: elColor,
                          onTap: context.soundTap(widget.onConfirm),
                          primary: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RelicPreviewMark extends StatelessWidget {
  const _RelicPreviewMark({required this.boss, required this.color});

  final AltarEntry boss;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.16),
                  const Color(0xFF05060A).withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.56)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.24),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              boss.relicImagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(boss.elementIcon, color: color, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _RitualDialogSurface extends StatelessWidget {
  const _RitualDialogSurface({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerBracketPainter(
        color: accent.withValues(alpha: 0.66),
        bracketSize: 18,
        strokeWidth: 1.2,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D14).withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.42), width: 1),
            bottom: BorderSide(color: accent.withValues(alpha: 0.24), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
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
  final bool primary;
  const _Btn({
    required this.label,
    required this.color,
    required this.onTap,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: context.soundAction(() {
      HapticFeedback.lightImpact();
      onTap();
    }),
    child: CustomPaint(
      painter: _CornerBracketPainter(
        color: color.withValues(alpha: primary ? 0.72 : 0.34),
        bracketSize: 10,
        strokeWidth: 1.1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        color: primary
            ? color.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.025),
        child: Center(
          child: Text(
            label,
            style: _display(
              context,
              13,
              primary ? color : _C.ivoryDim,
              weight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    ),
  );
}

class _BackBracketButton extends StatelessWidget {
  const _BackBracketButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundAction(onTap),
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _CornerBracketPainter(
            color: _C.ivoryMuted.withValues(alpha: 0.4),
            bracketSize: 8,
            strokeWidth: 1.0,
          ),
          child: const Icon(
            AppIcons.chevron_left_rounded,
            color: _C.ivoryDim,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PanelActionButton extends StatelessWidget {
  const _PanelActionButton({
    required this.onTap,
    required this.label,
    required this.enabled,
    this.color,
  });

  final VoidCallback onTap;
  final String label;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? _C.ivoryDim;
    return GestureDetector(
      onTap: context.soundAction(onTap),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 42, minWidth: 112),
        child: CustomPaint(
          painter: _CornerBracketPainter(
            color: (enabled ? accent : _C.ivoryMuted).withValues(
              alpha: enabled ? 0.55 : 0.28,
            ),
            bracketSize: 10,
            strokeWidth: 1.1,
          ),
          child: Container(
            alignment: Alignment.center,
            color: Colors.white.withValues(alpha: 0.03),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: _display(
                context,
                13,
                enabled ? (color ?? _C.ivory) : _C.ivoryMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({
    required this.color,
    required this.bracketSize,
    required this.strokeWidth,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
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

/// The altar's core: a void well that beats, and pulls the dark in toward it.
///
/// This was a three-armed spiral, which read as clipart at any size and
/// carried two MaskFilter.blur calls per frame — animating constantly, behind
/// a turning wheel, a starfield and fourteen nodes. A pulse says the same
/// thing about the altar being awake without drawing a galaxy, and the glow
/// is layered flat discs.
class _AltarEye extends StatefulWidget {
  const _AltarEye({
    required this.rate,
    required this.surge,
    this.size = 92,
  });

  /// How fast the altar is running: it wakes a little with every completed
  /// ritual, and surges hard while a portal is being discovered.
  final double rate;

  /// 0..1 portal discovery, which brightens and swells the core.
  final double surge;

  final double size;

  @override
  State<_AltarEye> createState() => _AltarEyeState();
}

class _AltarEyeState extends State<_AltarEye> with GlyphClockLease {
  /// Phase is integrated rather than derived from a controller's value.
  ///
  /// The old eye took `bgCtrl.value * speedMul`, which sawtooths — it snapped
  /// back every time the controller looped, and jumps by however much
  /// speedMul is not a whole number. A rotating spiral could absorb that; a
  /// field of motes cannot, they would teleport. Integrating a rate against a
  /// monotonic clock has no seam, and it also lets the portal surge ramp the
  /// speed up without the phase lurching.
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  double? _lastSeconds;

  @override
  bool get wantsClock => true;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    GlyphClock.instance.seconds.addListener(_tick);
  }

  void _tick() {
    final now = GlyphClock.instance.seconds.value;
    // Clamped so a dropped frame or a backgrounded app cannot jump the field.
    final dt = _lastSeconds == null
        ? 0.0
        : (now - _lastSeconds!).clamp(0.0, 0.1);
    _lastSeconds = now;
    _phase.value += dt * widget.rate;
  }

  @override
  void dispose() {
    GlyphClock.instance.seconds.removeListener(_tick);
    releaseGlyphClock();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        willChange: true,
        isComplex: false,
        painter: _VoidPulsePainter(phase: _phase, surge: widget.surge),
      ),
    );
  }
}

class _VoidPulsePainter extends CustomPainter {
  _VoidPulsePainter({required this.phase, required this.surge})
    : super(repaint: phase);

  final ValueListenable<double> phase;
  final double surge;

  /// Reused across every frame. No MaskFilter anywhere in here.
  static final Paint _p = Paint();

  /// Seconds per heartbeat at rate 1.
  static const double _beat = 2.4;

  /// Everything here is dots. An earlier pass drew the pulse as stroked rings
  /// and put radial filaments round the core, and the whole thing read as
  /// linework — the one thing the altar core should not look like.
  static const int _motes = 26;
  static const int _waveDots = 20;

  double get _t => phase.value;

  /// Golden-ratio spacing. A plain `i * k % 1` hash put every third mote at
  /// almost the same angle and almost the same phase, so they travelled in
  /// visible little clumps of three.
  static double _h(int i, int salt) =>
      (i * 0.6180339887 + salt * 0.3178) % 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);

    final beat = (_t / _beat) % 1.0;
    final breathe = 0.5 + 0.5 * math.sin(_t / _beat * math.pi * 2);

    // Turning the canvas rather than every offset: at rest this is a slow
    // drift, at full surge the whole well is spinning.
    if (surge > 0.001) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(_t * surge * 1.6);
      canvas.translate(-c.dx, -c.dy);
    }

    _waves(canvas, c, s, beat);
    _intake(canvas, c, s);

    if (surge > 0.001) canvas.restore();

    // The core stays put — a spinning point is just a point, and it is the
    // one thing that should look steady while everything round it tears up.
    _core(canvas, c, s, breathe);
  }

  /// The beat going out, thrown as a ring of motes rather than drawn as a
  /// circle. Two waves a half-beat apart so the altar never looks stopped,
  /// and both radius and dot size are jittered per mote — a perfectly even
  /// ring reads as a graphic no matter how many dots are in it.
  void _waves(Canvas canvas, Offset c, double s, double beat) {
    for (var w = 0; w < 2; w++) {
      final p = (beat + w * 0.5) % 1.0;
      final e = Curves.easeOutCubic.transform(p);
      final fade = (1 - p) * (0.62 + 0.30 * surge);
      if (fade <= 0.02) continue;
      final r = s * (0.11 + 0.37 * e);
      for (var i = 0; i < _waveDots; i++) {
        final a =
            i * math.pi * 2 / _waveDots +
            w * 0.16 +
            // Barely turns at rest; the portal surge whips it round.
            _t * (0.07 + surge * 1.1) +
            (_h(i, w + 3) - 0.5) * 0.11;
        final rr = r * (1 + (_h(i, w) - 0.5) * 0.18);
        canvas.drawCircle(
          c + Offset(math.cos(a) * rr, math.sin(a) * rr),
          s * (0.019 - 0.010 * e) * (0.65 + 0.7 * _h(i, w + 11)),
          _p..color = _C.voidGlow.withValues(alpha: fade),
        );
      }
    }
  }

  /// The dark being drawn in. Each mote accelerates as it falls and is
  /// swallowed at the well — a slight curl, but well short of a full turn, so
  /// it reads as an eddy rather than a pinwheel.
  void _intake(Canvas canvas, Offset c, double s) {
    final bright = Color.lerp(_C.voidGlow, Colors.white, 0.35)!;
    for (var i = 0; i < _motes; i++) {
      final p = (_t * 0.26 + _h(i, 1)) % 1.0;
      final pull = Curves.easeInCubic.transform(p);
      final dist = s * (0.47 - 0.39 * pull);
      // The curl is what makes the surge read as a spin rather than just a
      // faster heartbeat. At rest it is an eddy — well under a half turn on
      // the way in. At full surge each mote wraps more than a full turn
      // before the well takes it, and with the phase already running eight
      // times faster the field becomes a vortex.
      final a = _h(i, 2) * math.pi * 2 + p * (1.5 + surge * 7.0);
      final fade =
          (p < 0.14 ? p / 0.14 : 1.0) * (p > 0.88 ? (1 - p) / 0.12 : 1.0);
      if (fade <= 0.02) continue;
      canvas.drawCircle(
        c + Offset(math.cos(a) * dist, math.sin(a) * dist),
        s * (0.011 + 0.012 * (1 - pull)) * (0.7 + 0.6 * _h(i, 5)),
        _p..color = bright.withValues(alpha: (0.55 + 0.35 * surge) * fade),
      );
    }
  }

  void _core(Canvas canvas, Offset c, double s, double breathe) {
    final r = s * (0.082 + 0.018 * breathe) * (1 + 0.35 * surge);
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        c,
        r * (1 + 0.62 * i),
        _p
          ..color = _C.voidBright.withValues(
            alpha: ((0.16 + 0.10 * surge) * (0.7 + 0.3 * breathe)) / i,
          ),
      );
    }
    canvas.drawCircle(c, r, _p..color = _C.voidGlow.withValues(alpha: 0.92));
    canvas.drawCircle(
      c,
      r * 0.44,
      _p..color = Colors.white.withValues(alpha: 0.85 + 0.15 * breathe),
    );
  }

  @override
  bool shouldRepaint(covariant _VoidPulsePainter old) =>
      old.phase != phase || old.surge != surge;
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
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: _scale.value,
              child: SizedBox(
                width: 320,
                child: _RitualDialogSurface(
                  accent: _C.voidGlow,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // The same core the altar shows, so the popup
                            // is plainly about that thing.
                            const _AltarEye(rate: 1.6, surge: 0.5, size: 66),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Arcane portal',
                                    style: _display(
                                      context,
                                      18,
                                      _C.ivory,
                                      weight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Discovered',
                                    style: _body(
                                      context,
                                      12,
                                      _C.voidGlow,
                                      height: 1.2,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.025),
                            border: Border(
                              left: BorderSide(
                                color: _C.voidGlow.withValues(alpha: 0.66),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'A rift to the arcane realm has opened on the expedition map.\n\nBase stats and potentials have increased across all wilderness biomes.',
                            style: _body(
                              context,
                              12,
                              _C.ivoryDim,
                              height: 1.48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 150,
                            child: _Btn(
                              label: 'Continue',
                              color: _C.voidGlow,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onDismiss();
                              },
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
