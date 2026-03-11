import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ============================================================================
// NOTIFICATION BANNER SYSTEM
// ============================================================================

enum NotificationBannerType {
  eggReady,
  harvestReady,
  dailyReward,
  bossAvailable,
  eventActive,
  wildernessSpawn,
}

extension NotificationBannerTypeExtension on NotificationBannerType {
  String toKey() {
    return toString().split('.').last;
  }
}

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

class NotificationBannerWidget extends StatefulWidget {
  final NotificationBanner notification;
  final VoidCallback onDismiss;
  final VoidCallback? onExpand;
  final bool isExpanded;

  const NotificationBannerWidget({
    super.key,
    required this.notification,
    required this.onDismiss,
    this.onExpand,
    this.isExpanded = false,
  });

  @override
  State<NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<NotificationBannerWidget> {
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

  // --- Helpers ----------------------------------------------------------------

  ForgeTokens get _t {
    try {
      return ForgeTokens(context.read<FactionTheme>());
    } catch (_) {
      return ForgeTokens(FactionTheme.scorchForge());
    }
  }

  Color _getAccentColor() {
    final t = _t;
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return t.amberBright;
      case NotificationBannerType.harvestReady:
        return t.success;
      case NotificationBannerType.dailyReward:
        return const Color(0xFFB089FF);
      case NotificationBannerType.bossAvailable:
        return t.danger;
      case NotificationBannerType.eventActive:
        return t.teal;
      case NotificationBannerType.wildernessSpawn:
        return const Color(0xFFA3E635);
    }
  }

  IconData _getBannerIcon() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return Icons.science_rounded;
      case NotificationBannerType.harvestReady:
        return Icons.science_rounded;
      case NotificationBannerType.dailyReward:
        return Icons.auto_awesome_rounded;
      case NotificationBannerType.bossAvailable:
        return Icons.local_fire_department_rounded;
      case NotificationBannerType.eventActive:
        return Icons.stars_rounded;
      case NotificationBannerType.wildernessSpawn:
        return Icons.explore_rounded;
    }
  }

  // --- Drag handlers (for swipe-to-minimize) ----------------------------------

  void _handleDragStart(DragStartDetails details) {
    if (!widget.isExpanded) return;
    _isDragging = true;
    HapticFeedback.selectionClick();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.isExpanded) return;

    setState(() {
      // Only allow dragging to the right (minimize direction)
      _dragOffset = math.max(0, _dragOffset + details.delta.dx);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.isExpanded) return;

    const minimizeThreshold = 80.0;
    final shouldMinimize = _dragOffset > minimizeThreshold;

    _isDragging = false;

    if (shouldMinimize) {
      HapticFeedback.lightImpact();
      // Notify parent to collapse; snapping back will be handled by
      // the rebuild with isExpanded = false.
      widget.onExpand?.call();
      setState(() {
        _dragOffset = 0.0;
      });
    } else {
      // Just snap back - much cheaper than a custom spring animation
      HapticFeedback.selectionClick();
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  // --- UI pieces --------------------------------------------------------------

  Widget _buildCollapsedView() {
    final t = _t;
    final accent = _getAccentColor();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.bg3, t.bg2],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _ForgeScanlinePainter(
                  lineColor: Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: CustomPaint(
                painter: AlchemicalPatternPainter(
                  color: accent.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
          Center(child: Icon(_getBannerIcon(), color: accent, size: 24)),
          if (widget.notification.count > 1 &&
              widget.notification.type !=
                  NotificationBannerType.wildernessSpawn)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.bg0, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Center(
                  child: Text(
                    '${widget.notification.count}',
                    style: TextStyle(
                      color: t.bg0,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedView() {
    final t = _t;
    final accent = _getAccentColor();
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bg1, t.bg2],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
        border: Border.all(color: t.borderDim, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: CustomPaint(
                painter: _ForgeScanlinePainter(
                  lineColor: Colors.black.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 8,
            child: SizedBox(
              width: 36,
              height: 36,
              child: CustomPaint(
                painter: AlchemicalPatternPainter(
                  color: accent.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.bg3.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(_getBannerIcon(), color: accent, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.notification.title.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 2),
                                ],
                              ),
                            ),
                          ),
                          if (widget.notification.count > 1 &&
                              widget.notification.type !=
                                  NotificationBannerType.wildernessSpawn) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.65),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${widget.notification.count}',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.notification.subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.notification.subtitle!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onDismiss();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: t.bg3.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.borderDim.withValues(alpha: 0.9),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: t.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // We apply drag transform only when expanded (so minimized bubble stays put)
    final bool applyDrag = widget.isExpanded && _dragOffset > 0;

    return AnimatedSlide(
      offset: _isShown ? Offset.zero : const Offset(1.0, 0.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isShown ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isDragging) return;
            HapticFeedback.mediumImpact();
            if (widget.isExpanded) {
              widget.notification.onTap();
            } else {
              widget.onExpand?.call();
            }
          },
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: Transform.translate(
              offset: applyDrag ? Offset(_dragOffset, 0) : Offset.zero,
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                firstChild: _buildCollapsedView(),
                secondChild: _buildExpandedView(),
                crossFadeState: widget.isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                // Keep size transitions smooth
                sizeCurve: Curves.easeOut,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgeScanlinePainter extends CustomPainter {
  final Color lineColor;

  const _ForgeScanlinePainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (double y = 1; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForgeScanlinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

// ============================================================================
// ALCHEMICAL PATTERN PAINTER
// ============================================================================

class AlchemicalPatternPainter extends CustomPainter {
  final Color color;

  AlchemicalPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) / 3;

    canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    canvas.drawCircle(Offset(centerX, centerY), radius * 0.7, paint);

    final trianglePath = Path();
    trianglePath.moveTo(centerX, centerY - radius * 0.5);
    trianglePath.lineTo(centerX - radius * 0.43, centerY + radius * 0.25);
    trianglePath.lineTo(centerX + radius * 0.43, centerY + radius * 0.25);
    trianglePath.close();
    canvas.drawPath(trianglePath, paint);
  }

  @override
  bool shouldRepaint(covariant AlchemicalPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ============================================================================
// NOTIFICATION BANNER STACK
// ============================================================================

class NotificationBannerStack extends StatefulWidget {
  final List<NotificationBanner> notifications;

  const NotificationBannerStack({super.key, required this.notifications});

  @override
  State<NotificationBannerStack> createState() =>
      _NotificationBannerStackState();
}

class _NotificationBannerStackState extends State<NotificationBannerStack> {
  final List<NotificationBanner> _activeNotifications = [];
  final Set<String> _dismissedKeys = {};
  final Map<NotificationBannerType, bool> _expandedStates = {};
  bool _isLoadingDismissals = true;

  String _keyFor(NotificationBanner n) => '${n.type.toKey()}|${n.stateKey}';

  @override
  void initState() {
    super.initState();
    _loadDismissedNotifications();
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

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _activeNotifications
            .map(
              (notification) => NotificationBannerWidget(
                key: ValueKey('${notification.type}_${notification.stateKey}'),
                notification: notification,
                isExpanded: _expandedStates[notification.type] ?? false,
                onExpand: () => _toggleExpanded(notification.type),
                onDismiss: () => _removeBanner(notification),
              ),
            )
            .toList(),
      ),
    );
  }
}
