import 'package:alchemons/audio/audio.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/constants/design_tokens.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ============================================================================
// HOME NOTICES
// ============================================================================
//
// The home screen's "something is ready" slips: a cultivation to extract, a
// harvest to collect, wild Alchemons to go and find. Each is a bracket slip in
// the same chrome as the rest of the game, with a small symbol in grains so
// the three read apart even folded down to a tab: a sphere (the cultivation),
// a stream pouring onto a heap (the harvest), a ring with a lit point in it
// (the wild map's circle with something detected). The grains are a fixed
// scatter painted once; nothing here ticks.

/// The names are stored in notification_dismissals rows (see [toKey]), so a
/// rename would bring back every banner a player has already dismissed.
enum NotificationBannerType { eggReady, harvestReady, wildernessSpawn }

extension NotificationBannerTypeExtension on NotificationBannerType {
  String toKey() => name;
}

/// Each notice's colour, readable on the theme's ground. The dock buttons
/// that open the same screens wear their dot in it ([HomeNoticeDot]).
Color homeNoticeAccent(NotificationBannerType type, {required bool dark}) =>
    switch (type) {
      // A ready cultivation's gold heartbeat.
      NotificationBannerType.eggReady =>
        dark ? const Color(0xFFE4C16A) : const Color(0xFF9A6B12),
      // The Harvest screen's own "chamber full" green.
      NotificationBannerType.harvestReady =>
        dark ? const Color(0xFF8FD99F) : const Color(0xFF2E7D45),
      NotificationBannerType.wildernessSpawn =>
        dark ? const Color(0xFF7CC6E0) : const Color(0xFF1F6A84),
    };

class NotificationBanner {
  final NotificationBannerType type;
  final String title;
  final String? subtitle;
  final int count;
  final String stateKey;
  final VoidCallback onTap;

  NotificationBanner({
    required this.type,
    required this.title,
    this.subtitle,
    this.count = 1,
    required this.onTap,
    this.stateKey = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationBanner &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          stateKey == other.stateKey;

  @override
  int get hashCode => Object.hash(type, stateKey);
}

BracketPalette _paletteOf(BuildContext context) {
  try {
    return BracketPalette.of(context);
  } catch (_) {
    return BracketPalette.dark;
  }
}

class NotificationBannerWidget extends StatefulWidget {
  final NotificationBanner notification;
  final VoidCallback onDismiss;
  final VoidCallback? onExpand;
  final bool isExpanded;

  /// Which edge the stack is docked to: it slides in from there, and a swipe
  /// back toward it folds the notice down.
  final bool onRight;

  const NotificationBannerWidget({
    super.key,
    required this.notification,
    required this.onDismiss,
    this.onExpand,
    this.isExpanded = false,
    this.onRight = true,
  });

  @override
  State<NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<NotificationBannerWidget> {
  static const double _expandedWidth = 272;
  static const double _tabSize = 50;

  // Drag state
  double _dragOffset = 0.0;
  bool _isDragging = false;

  // Initial slide-in
  bool _isShown = false;

  @override
  void initState() {
    super.initState();

    // Trigger implicit slide/fade in on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isShown = true);
      }
    });
  }

  // --- Drag handlers (swipe toward the edge to fold) --------------------------

  void _handleDragStart(DragStartDetails details) {
    if (!widget.isExpanded) return;
    _isDragging = true;
    HapticFeedback.selectionClick();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.isExpanded) return;

    setState(() {
      // Only toward the docked edge.
      final next = _dragOffset + details.delta.dx;
      _dragOffset = widget.onRight ? math.max(0, next) : math.min(0, next);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.isExpanded) return;

    const minimizeThreshold = 80.0;
    final shouldMinimize = _dragOffset.abs() > minimizeThreshold;

    _isDragging = false;

    if (shouldMinimize) {
      HapticFeedback.lightImpact();
      // The parent folds it; the rebuild with isExpanded = false shows the tab.
      widget.onExpand?.call();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() => _dragOffset = 0.0);
  }

  // --- UI pieces --------------------------------------------------------------

  Widget _frame({
    required Color accent,
    required BracketPalette palette,
    required Widget child,
    double bracketSize = 9,
  }) {
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.85),
        bracketSize: bracketSize,
        strokeWidth: 1.2,
      ),
      child: ColoredBox(color: palette.chromeFill(), child: child),
    );
  }

  Widget _buildCollapsedView(BracketPalette palette, Color accent) {
    final n = widget.notification;
    // A wilderness count is grains on the ground, not things to act on.
    final showCount =
        n.count > 1 && n.type != NotificationBannerType.wildernessSpawn;
    return _frame(
      accent: accent,
      palette: palette,
      bracketSize: 8,
      child: SizedBox(
        width: _tabSize,
        height: _tabSize,
        child: Stack(
          children: [
            Center(
              child: _NoticeSigil(
                type: n.type,
                accent: accent,
                dark: palette.isDark,
                size: 36,
              ),
            ),
            if (showCount)
              Positioned(
                right: 5,
                bottom: 3,
                child: Text(
                  '${n.count}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent,
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView(BracketPalette palette, Color accent) {
    final n = widget.notification;
    return SizedBox(
      width: _expandedWidth,
      child: _frame(
        accent: accent,
        palette: palette,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
          child: Row(
            children: [
              _NoticeSigil(
                type: n.type,
                accent: accent,
                dark: palette.isDark,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      n.title.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (n.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        n.subtitle!,
                        style: bracketText(context, 12, palette.muted),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: context.soundAction(() {
                  HapticFeedback.lightImpact();
                  widget.onDismiss();
                }),
                child: SizedBox(
                  width: AppTap.min,
                  height: AppTap.min,
                  child: Center(
                    child: Icon(
                      AppIcons.close_rounded,
                      color: palette.muted,
                      size: 16,
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

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final accent = homeNoticeAccent(
      widget.notification.type,
      dark: palette.isDark,
    );
    final onRight = widget.onRight;
    final edge = onRight ? Alignment.topRight : Alignment.topLeft;

    return AnimatedSlide(
      offset: _isShown ? Offset.zero : Offset(onRight ? 1.0 : -1.0, 0.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isShown ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: context.soundAction(() {
            if (_isDragging) return;
            HapticFeedback.mediumImpact();
            if (widget.isExpanded) {
              widget.notification.onTap();
            } else {
              widget.onExpand?.call();
            }
          }),
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: Padding(
            padding: EdgeInsets.only(
              left: onRight ? 0 : 12,
              right: onRight ? 12 : 0,
              top: 4,
              bottom: 4,
            ),
            child: Transform.translate(
              offset: Offset(widget.isExpanded ? _dragOffset : 0, 0),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                firstChild: _buildCollapsedView(palette, accent),
                secondChild: _buildExpandedView(palette, accent),
                crossFadeState: widget.isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                sizeCurve: Curves.easeOut,
                alignment: edge,
                // The default pins the outgoing child to the incoming one's
                // width, which squeezes the slip into the tab's 50px while
                // it fades. Pinned to the edge only, each keeps its own size
                // and the size animation's clip does the rest.
                layoutBuilder: (top, topKey, bottom, bottomKey) => Stack(
                  clipBehavior: Clip.none,
                  alignment: edge,
                  children: [
                    Positioned(
                      key: bottomKey,
                      top: 0,
                      right: onRight ? 0 : null,
                      left: onRight ? null : 0,
                      child: bottom,
                    ),
                    KeyedSubtree(key: topKey, child: top),
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

// ============================================================================
// THE GRAIN SYMBOLS
// ============================================================================

class _Grain {
  const _Grain(this.x, this.y, this.r, this.light);

  /// Position in the symbol's box, -1..1 on each axis.
  final double x, y;

  /// Radius as a fraction of the box's half-size.
  final double r;

  /// How lit the grain is, 0..1.
  final double light;
}

/// A cultivation: a sphere of grains, heavier at the rim the way the
/// chambers' spheres are, lit from the upper left, with a bright knot at the
/// heart for the ready heartbeat.
final List<_Grain> _sphereGrains = () {
  final rng = math.Random(7);
  const lx = -0.55, ly = -0.6;
  final lz = math.sqrt(1 - lx * lx - ly * ly);
  final out = <_Grain>[];
  while (out.length < 150) {
    final x = rng.nextDouble() * 2 - 1;
    final y = rng.nextDouble() * 2 - 1;
    final d2 = x * x + y * y;
    if (d2 > 1) continue;
    if (rng.nextDouble() > 0.3 + 0.7 * math.sqrt(d2)) continue;
    final z = math.sqrt(1 - d2);
    final lambert = math.max(0.0, x * lx + y * ly + z * lz);
    out.add(
      _Grain(
        x * 0.8,
        y * 0.8,
        0.035 + 0.03 * rng.nextDouble(),
        0.15 + 0.75 * lambert,
      ),
    );
  }
  for (var i = 0; i < 12; i++) {
    final a = rng.nextDouble() * math.pi * 2;
    final d = math.sqrt(rng.nextDouble()) * 0.17;
    out.add(
      _Grain(
        math.cos(a) * d,
        math.sin(a) * d,
        0.045 + 0.025 * rng.nextDouble(),
        1,
      ),
    );
  }
  return out;
}();

/// A harvest: a few motes falling onto a low heap, the heap brightest where
/// they land. The stream stops short of the heap and the heap is wide and
/// flat, or the two read as one shape (a little tree).
final List<_Grain> _harvestGrains = () {
  final rng = math.Random(19);
  final out = <_Grain>[];
  // The falling motes, sparser and a touch wider toward the bottom.
  for (var i = 0; i < 14; i++) {
    final t = rng.nextDouble();
    final y = -0.82 + t * 0.92;
    out.add(
      _Grain(
        (rng.nextDouble() - 0.5) * (0.05 + 0.12 * t),
        y,
        0.028 + 0.02 * rng.nextDouble(),
        0.4 + 0.45 * t,
      ),
    );
  }
  // The heap, under the curve top(x) = 0.78 − 0.3·(1 − (x/0.86)²).
  while (out.length < 14 + 130) {
    final x = (rng.nextDouble() * 2 - 1) * 0.86;
    final top = 0.78 - 0.3 * (1 - (x / 0.86) * (x / 0.86));
    final y = 0.78 - rng.nextDouble() * (0.78 - top);
    final nearTop = 1 - ((y - top) / math.max(0.05, 0.78 - top));
    final nearMiddle = 1 - x.abs() / 0.86;
    out.add(
      _Grain(
        x,
        y,
        0.035 + 0.03 * rng.nextDouble(),
        0.12 + 0.5 * nearTop * nearTop + 0.35 * nearMiddle,
      ),
    );
  }
  // A few thrown up where the stream meets the heap.
  for (var i = 0; i < 8; i++) {
    final a = -math.pi * (0.1 + 0.8 * rng.nextDouble());
    final d = 0.1 + 0.16 * rng.nextDouble();
    out.add(
      _Grain(
        math.cos(a) * d,
        0.46 + math.sin(a) * d * 0.6,
        0.025 + 0.015 * rng.nextDouble(),
        0.75,
      ),
    );
  }
  return out;
}();

/// Wild Alchemons: the wild map's faint sand circle with one point in it lit,
/// the way a realm looks when something has been detected there.
final List<_Grain> _wildGrains = () {
  final rng = math.Random(31);
  final out = <_Grain>[];
  for (var i = 0; i < 90; i++) {
    final a = rng.nextDouble() * math.pi * 2;
    final d = 0.72 + (rng.nextDouble() - 0.5) * 0.16;
    out.add(
      _Grain(
        math.cos(a) * d,
        math.sin(a) * d,
        0.032 + 0.028 * rng.nextDouble(),
        0.35 + 0.4 * rng.nextDouble(),
      ),
    );
  }
  for (var i = 0; i < 26; i++) {
    final a = rng.nextDouble() * math.pi * 2;
    final d = math.sqrt(rng.nextDouble()) * 0.58;
    out.add(
      _Grain(
        math.cos(a) * d,
        math.sin(a) * d,
        0.025 + 0.02 * rng.nextDouble(),
        0.08 + 0.12 * rng.nextDouble(),
      ),
    );
  }
  const cx = 0.2, cy = -0.16;
  for (var i = 0; i < 16; i++) {
    final a = rng.nextDouble() * math.pi * 2;
    final d = math.pow(rng.nextDouble(), 1.4) * 0.16;
    out.add(
      _Grain(
        cx + math.cos(a) * d,
        cy + math.sin(a) * d,
        0.035 + 0.035 * (1 - d / 0.16),
        1 - d / 0.2,
      ),
    );
  }
  return out;
}();

class _NoticeSigil extends StatelessWidget {
  const _NoticeSigil({
    required this.type,
    required this.accent,
    required this.dark,
    required this.size,
  });

  final NotificationBannerType type;
  final Color accent;
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Its own layer, so the slide-in and the fold do not repaint the grains.
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _NoticeSigilPainter(type, accent, dark)),
      ),
    );
  }
}

class _NoticeSigilPainter extends CustomPainter {
  _NoticeSigilPainter(this.type, this.accent, this.dark);

  final NotificationBannerType type;
  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final grains = switch (type) {
      NotificationBannerType.eggReady => _sphereGrains,
      NotificationBannerType.harvestReady => _harvestGrains,
      NotificationBannerType.wildernessSpawn => _wildGrains,
    };
    final half = size.shortestSide / 2;
    final centre = size.center(Offset.zero);
    // Unlit grains sink into the ground; lit ones run to the accent and, on
    // the dark theme, a little past it toward cream.
    final lit = dark
        ? Color.lerp(accent, const Color(0xFFFFF4DC), 0.35)!
        : accent;
    final dim = accent.withValues(alpha: dark ? 0.22 : 0.28);
    final paint = Paint();
    for (final g in grains) {
      paint.color = Color.lerp(dim, lit, g.light.clamp(0.0, 1.0))!;
      canvas.drawCircle(
        centre + Offset(g.x, g.y) * half,
        math.max(0.6, g.r * half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NoticeSigilPainter old) =>
      old.type != type || old.accent != accent || old.dark != dark;
}

/// The dot a dock button wears while there is something ready behind it, in
/// the colour of the notice for the same thing.
class HomeNoticeDot extends StatelessWidget {
  const HomeNoticeDot({super.key, required this.color, this.size = 11});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: BracketPalette.dark.bg0, width: 1.6),
      ),
    );
  }
}

// ============================================================================
// NOTIFICATION BANNER STACK
// ============================================================================

class NotificationBannerStack extends StatefulWidget {
  final List<NotificationBanner> notifications;

  /// Where the stack sits until the player moves it, from the top of the
  /// screen. Home passes the space under its featured specimen; left out, it
  /// starts at the top.
  final double? restTop;

  const NotificationBannerStack({
    super.key,
    required this.notifications,
    this.restTop,
  });

  @override
  State<NotificationBannerStack> createState() =>
      _NotificationBannerStackState();
}

class _NotificationBannerStackState extends State<NotificationBannerStack> {
  final List<NotificationBanner> _activeNotifications = [];
  final Set<String> _dismissedKeys = {};
  final Map<NotificationBannerType, bool> _expandedStates = {};
  bool _isLoadingDismissals = true;

  // ── Where the stack sits ──────────────────────────────────────────────
  //
  // Wherever it starts, it covers something on a phone, so the player needs
  // to be able to put it somewhere else. Moving it is a long press and a
  // drag: tap already expands a notice and a horizontal swipe already folds
  // one, so a plain pan had nowhere to go without taking one of those away.
  static const _prefsSideKey = 'home_banner_right_side';

  /// Measured from [NotificationBannerStack.restTop]. A new key, because
  /// the old one counted from the top of the screen — where the stack used
  /// to start, on top of the player's coins.
  static const _prefsDyKey = 'home_banner_dy_v2';

  /// How long the press has to be held before the stack lifts.
  ///
  /// Well under the 500ms Flutter default and under the app's own 250ms
  /// fast timeout: picking a banner up should feel immediate. Not lower
  /// than this, though — a deliberate tap can run past 100ms, and a pick-up
  /// that steals taps would break expanding a banner.
  static const _pickUpDelay = Duration(milliseconds: 150);

  bool _onRight = true;
  double _dy = 0;
  bool _dragging = false;
  double _liveDx = 0;
  double _liveDy = 0;

  Future<void> _loadPlacement() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onRight = prefs.getBool(_prefsSideKey) ?? true;
      _dy = prefs.getDouble(_prefsDyKey) ?? 0;
    });
  }

  Future<void> _savePlacement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsSideKey, _onRight);
    await prefs.setDouble(_prefsDyKey, _dy);
  }

  void _cancelDrag() {
    if (!_dragging && _liveDx == 0 && _liveDy == 0) return;
    setState(() {
      _dragging = false;
      _liveDx = 0;
      _liveDy = 0;
    });
  }

  void _pickUp() {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragging = true;
      _liveDx = 0;
      _liveDy = 0;
    });
  }

  /// [fromOrigin] is measured from where the press started, so it is the
  /// live offset outright rather than something to accumulate.
  void _dragTo(Offset fromOrigin) {
    setState(() {
      _liveDx = fromOrigin.dx;
      _liveDy = fromOrigin.dy;
    });
  }

  void _drop(
    double screenWidth,
    double minDy,
    double maxDy,
    double releasedAtX,
  ) {
    // Whichever half it was released in, so a short nudge across the middle
    // still switches sides and a long drag that ends up back where it
    // started does not.
    final side = releasedAtX > screenWidth / 2;
    setState(() {
      _onRight = side;
      _dy = (_dy + _liveDy).clamp(minDy, maxDy);
      _dragging = false;
      _liveDx = 0;
      _liveDy = 0;
    });
    HapticFeedback.selectionClick();
    unawaited(_savePlacement());
  }

  String _keyFor(NotificationBanner n) => '${n.type.toKey()}|${n.stateKey}';

  @override
  void initState() {
    super.initState();
    _loadDismissedNotifications();
    unawaited(_loadPlacement());
  }

  Future<void> _loadDismissedNotifications() async {
    try {
      final db = context.read<AlchemonsDatabase>();
      final dismissals = await (db.select(db.notificationDismissals)).get();

      if (!mounted) return;

      setState(() {
        _dismissedKeys.clear();
        for (final dismissal in dismissals) {
          _dismissedKeys.add(dismissal.notificationType);
        }
        _isLoadingDismissals = false;
      });

      _updateActiveNotifications();
    } catch (e) {
      debugPrint('Error loading dismissed notifications: $e');
      if (mounted) {
        setState(() => _isLoadingDismissals = false);
      }
    }
  }

  void _updateActiveNotifications() {
    if (!mounted) return;

    bool needsUpdate = false;

    for (final notification in widget.notifications) {
      final key = _keyFor(notification);

      if (_dismissedKeys.contains(key)) continue;

      _activeNotifications.removeWhere((n) => n.type == notification.type);
      _activeNotifications.add(notification);
      _expandedStates[notification.type] ??= true;
      needsUpdate = true;
    }

    final toRemove = _activeNotifications
        .where(
          (active) =>
              !widget.notifications.any((n) => _keyFor(n) == _keyFor(active)),
        )
        .toList();

    if (toRemove.isNotEmpty) {
      for (final notification in toRemove) {
        _activeNotifications.remove(notification);
        _expandedStates.remove(notification.type);
      }
      needsUpdate = true;
    }

    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(NotificationBannerStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isLoadingDismissals) {
      _updateActiveNotifications();
    }
  }

  Future<void> _removeBanner(NotificationBanner banner) async {
    if (!mounted) return;

    final type = banner.type;
    final key = _keyFor(banner);

    try {
      final db = context.read<AlchemonsDatabase>();

      await db
          .into(db.notificationDismissals)
          .insertOnConflictUpdate(
            NotificationDismissalsCompanion.insert(
              notificationType: key,
              dismissedAtUtcMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      if (!mounted) return;

      setState(() {
        _activeNotifications.removeWhere((n) => _keyFor(n) == key);
        _expandedStates.remove(type);
        _dismissedKeys.add(key);
      });
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
    }
  }

  void _toggleExpanded(NotificationBannerType type) {
    if (mounted) {
      setState(() {
        _expandedStates[type] = !(_expandedStates[type] ?? false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDismissals || _activeNotifications.isEmpty) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final highest = media.padding.top + 8;
    final baseTop = math.max(widget.restTop ?? highest, highest);
    // Kept on screen whatever was stored: a rotation or a smaller device
    // must not strand the banners past the bottom edge, and it can still be
    // lifted all the way to the top.
    final minDy = highest - baseTop;
    final maxDy = (media.size.height - baseTop - 140).clamp(minDy, 4000.0);
    final top = (_dy + _liveDy).clamp(minDy, maxDy) + baseTop;

    return Positioned(
      top: top,
      left: _onRight ? null : 0,
      right: _onRight ? 0 : null,
      child: RawGestureDetector(
        // Hold to pick up. Tap and horizontal swipe belong to the banner
        // itself, so this is the one gesture left that cannot be mistaken
        // for either — and it goes through the recognizer directly because
        // GestureDetector gives no way to shorten the hold.
        gestures: <Type, GestureRecognizerFactory>{
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: _pickUpDelay,
                  debugOwner: this,
                ),
                (instance) {
                  instance.onLongPressStart = (_) => _pickUp();
                  instance.onLongPressMoveUpdate = (d) =>
                      _dragTo(d.offsetFromOrigin);
                  instance.onLongPressEnd = (d) => _drop(
                    media.size.width,
                    minDy,
                    maxDy,
                    d.globalPosition.dx,
                  );
                  instance.onLongPressCancel = _cancelDrag;
                },
              ),
        },
        child: Transform.translate(
          offset: Offset(_liveDx, 0),
          child: AnimatedScale(
            // A small lift, so a picked-up stack looks picked up.
            scale: _dragging ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 140),
            alignment: _onRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: _onRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: _activeNotifications
                  .map(
                    (notification) => NotificationBannerWidget(
                      key: ValueKey(
                        '${notification.type}_${notification.stateKey}',
                      ),
                      notification: notification,
                      isExpanded: _expandedStates[notification.type] ?? false,
                      onRight: _onRight,
                      onExpand: () => _toggleExpanded(notification.type),
                      onDismiss: () => _removeBanner(notification),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
