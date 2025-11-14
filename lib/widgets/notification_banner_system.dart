import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:alchemons/database/alchemons_db.dart';
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

class _NotificationBannerWidgetState extends State<NotificationBannerWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _expandController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _springController; // New controller for spring-back
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _hasBeenShown = false;
  bool _wasExpanded = false;

  // Drag state
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    // Slide-in animation (initial appearance)
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Expand/collapse animation
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isExpanded ? 1.0 : 0.0,
    );

    // Spring-back controller (separate from slide-in)
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Shimmer effect - slower for better performance
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Pulse effect - only for collapsed state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.6),
      ),
    );

    _wasExpanded = widget.isExpanded;

    // Initial slide-in
    _slideController.forward().then((_) {
      if (mounted && !_hasBeenShown) {
        setState(() => _hasBeenShown = true);
        Future.delayed(const Duration(seconds: 3), _autoCollapse);
      }
    });

    // Start pulse only if collapsed
    if (!widget.isExpanded) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(NotificationBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate expand/collapse transitions
    if (widget.isExpanded != _wasExpanded) {
      _wasExpanded = widget.isExpanded;

      if (widget.isExpanded) {
        _dragOffset = 0.0;
        _isDragging = false;
        _expandController.forward();
        _pulseController.stop();
        _pulseController.value = 0.0;
      } else {
        // When collapsing, ensure smooth transition
        if (_dragOffset == 0.0) {
          _expandController.reverse().then((_) {
            if (mounted && !widget.isExpanded) {
              _pulseController.repeat(reverse: true);
            }
          });
        }
      }
    }
  }

  void _autoCollapse() {
    if (mounted && widget.isExpanded && widget.onExpand != null) {
      widget.onExpand!();
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (!widget.isExpanded) return;

    setState(() {
      _isDragging = true;
    });
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

    setState(() {
      _isDragging = false;
    });

    if (shouldMinimize) {
      // Trigger minimize with smooth animation
      HapticFeedback.lightImpact();
      _animateMinimize();
    } else {
      // Spring back with elastic animation
      HapticFeedback.selectionClick();
      _animateSpringBack();
    }
  }

  void _animateMinimize() {
    // Animate both the drag offset AND the expand controller together
    final dragAnimation =
        Tween<double>(
          begin: _dragOffset,
          end: 300.0, // Slide off screen
        ).animate(
          CurvedAnimation(
            parent: _springController,
            curve: Curves.easeOutCubic,
          ),
        );

    final collapseAnimation =
        Tween<double>(begin: _expandController.value, end: 0.0).animate(
          CurvedAnimation(
            parent: _springController,
            curve: Curves.easeOutCubic,
          ),
        );

    void dragListener() {
      if (mounted) {
        setState(() {
          _dragOffset = dragAnimation.value;
        });
      }
    }

    void collapseListener() {
      if (mounted) {
        _expandController.value = collapseAnimation.value;
      }
    }

    dragAnimation.addListener(dragListener);
    collapseAnimation.addListener(collapseListener);

    _springController.forward(from: 0.0).then((_) {
      dragAnimation.removeListener(dragListener);
      collapseAnimation.removeListener(collapseListener);
      if (mounted) {
        setState(() {
          _dragOffset = 0.0;
        });
        _springController.value = 0.0;

        // Now notify parent that we're collapsed
        widget.onExpand?.call();
      }
    });
  }

  void _animateSpringBack() {
    if (_dragOffset == 0) return;

    final animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );

    void listener() {
      if (mounted) {
        setState(() {
          _dragOffset = animation.value;
        });
      }
    }

    animation.addListener(listener);

    _springController.forward(from: 0.0).then((_) {
      animation.removeListener(listener);
      if (mounted) {
        setState(() {
          _dragOffset = 0.0;
        });
        _springController.value = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _expandController.dispose();
    _springController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getBannerColor() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return const Color(0xFF8B4513);
      case NotificationBannerType.harvestReady:
        return const Color(0xFF2E7D32);
      case NotificationBannerType.dailyReward:
        return const Color(0xFF6A1B9A);
      case NotificationBannerType.bossAvailable:
        return const Color(0xFFB71C1C);
      case NotificationBannerType.eventActive:
        return const Color(0xFF1565C0);
      case NotificationBannerType.wildernessSpawn:
        return const Color(0xFF1B5E20);
    }
  }

  Color _getAccentColor() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return const Color(0xFFFFD700);
      case NotificationBannerType.harvestReady:
        return const Color(0xFF4CAF50);
      case NotificationBannerType.dailyReward:
        return const Color(0xFFAB47BC);
      case NotificationBannerType.bossAvailable:
        return const Color(0xFFFF5252);
      case NotificationBannerType.eventActive:
        return const Color(0xFF42A5F5);
      case NotificationBannerType.wildernessSpawn:
        return const Color(0xFF66BB6A);
    }
  }

  IconData _getBannerIcon() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return Icons.egg_rounded;
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

  Widget _buildShimmerEffect() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                _getAccentColor().withOpacity(0.2),
                Colors.transparent,
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedView() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.08);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _getBannerColor(),
              shape: BoxShape.circle,
              border: Border.all(
                color: _getAccentColor().withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getAccentColor().withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(-2, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipOval(child: _buildShimmerEffect()),
                Center(
                  child: Icon(_getBannerIcon(), color: Colors.white, size: 28),
                ),
                if (widget.notification.count > 1)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getAccentColor(),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.notification.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedView() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: _getBannerColor(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        border: Border.all(
          color: _getAccentColor().withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getAccentColor().withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(-3, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: _buildShimmerEffect(),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: CustomPaint(
                painter: AlchemicalPatternPainter(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getAccentColor().withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getBannerIcon(),
                    color: _getAccentColor(),
                    size: 24,
                  ),
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
                              widget.notification.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 2),
                                ],
                              ),
                            ),
                          ),
                          if (widget.notification.count > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getAccentColor(),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${widget.notification.count}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.notification.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.notification.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 2),
                            ],
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
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
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

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
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
            child: AnimatedBuilder(
              animation: _expandController,
              builder: (context, child) {
                Widget bannerWidget;

                if (_expandController.value == 0.0) {
                  bannerWidget = _buildCollapsedView();
                } else if (_expandController.value == 1.0) {
                  bannerWidget = _buildExpandedView();
                } else {
                  // During transition
                  bannerWidget = Opacity(
                    opacity: 0.7 + (_expandController.value * 0.3),
                    child: Transform.scale(
                      scale: 0.9 + (_expandController.value * 0.1),
                      alignment: Alignment.centerRight,
                      child: _expandController.value > 0.5
                          ? _buildExpandedView()
                          : _buildCollapsedView(),
                    ),
                  );
                }

                // Apply drag transformation when expanded
                if (widget.isExpanded && _dragOffset > 0) {
                  final normalizedDrag = (_dragOffset / 300.0).clamp(0.0, 1.0);
                  final opacity = 1.0 - (normalizedDrag * 0.6);
                  final scale = 1.0 - (normalizedDrag * 0.2);

                  bannerWidget = Transform.translate(
                    offset: Offset(_dragOffset, 0),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.centerRight,
                      child: Opacity(opacity: opacity, child: bannerWidget),
                    ),
                  );
                }

                return bannerWidget;
              },
            ),
          ),
        ),
      ),
    );
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
