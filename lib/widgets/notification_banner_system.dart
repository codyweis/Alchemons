// lib/widgets/notification_banner_system.dart

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
  final VoidCallback onTap;

  NotificationBanner({
    required this.type,
    required this.title,
    this.subtitle,
    this.count = 1,
    required this.onTap,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationBanner &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
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
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _hasBeenShown = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.5),
      ),
    );

    // Show initially, then collapse after 3 seconds
    _slideController.forward().then((_) {
      if (mounted && !_hasBeenShown) {
        setState(() => _hasBeenShown = true);
        Future.delayed(const Duration(seconds: 3), _collapseIfExpanded);
      }
    });
  }

  void _collapseIfExpanded() {
    if (mounted && widget.isExpanded && widget.onExpand != null) {
      widget.onExpand!();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getBannerColor() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return const Color(0xFF8B4513); // Alchemical bronze
      case NotificationBannerType.harvestReady:
        return const Color(0xFF2E7D32); // Deep emerald
      case NotificationBannerType.dailyReward:
        return const Color(0xFF6A1B9A); // Mystic purple
      case NotificationBannerType.bossAvailable:
        return const Color(0xFFB71C1C); // Crimson
      case NotificationBannerType.eventActive:
        return const Color(0xFF1565C0); // Sapphire blue
    }
  }

  Color _getAccentColor() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return const Color(0xFFFFD700); // Gold shimmer
      case NotificationBannerType.harvestReady:
        return const Color(0xFF4CAF50); // Bright green
      case NotificationBannerType.dailyReward:
        return const Color(0xFFAB47BC); // Bright purple
      case NotificationBannerType.bossAvailable:
        return const Color(0xFFFF5252); // Bright red
      case NotificationBannerType.eventActive:
        return const Color(0xFF42A5F5); // Bright blue
    }
  }

  IconData _getBannerIcon() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return Icons.egg_rounded;
      case NotificationBannerType.harvestReady:
        return Icons.science_rounded; // Changed to alchemy flask
      case NotificationBannerType.dailyReward:
        return Icons.auto_awesome_rounded; // Sparkle/magic
      case NotificationBannerType.bossAvailable:
        return Icons.local_fire_department_rounded;
      case NotificationBannerType.eventActive:
        return Icons.stars_rounded;
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
                _getAccentColor().withOpacity(0.3),
                Colors.transparent,
              ],
              stops: [
                _shimmerController.value - 0.3,
                _shimmerController.value,
                _shimmerController.value + 0.3,
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
        final scale = 1.0 + (_pulseController.value * 0.1);
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
                  color: _getAccentColor().withOpacity(0.4),
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
                // Shimmer effect
                ClipOval(child: _buildShimmerEffect()),

                // Icon
                Center(
                  child: Icon(_getBannerIcon(), color: Colors.white, size: 28),
                ),

                // Count badge
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
          // Shimmer effect background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: _buildShimmerEffect(),
            ),
          ),

          // Alchemical pattern overlay
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

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container
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

                // Text content
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

                // Close button
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
    final content = GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (widget.isExpanded) {
          widget.notification.onTap();
          widget.onDismiss();
        } else {
          widget.onExpand?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
        child: widget.isExpanded ? _buildExpandedView() : _buildCollapsedView(),
      ),
    );

    // Only allow swipe to minimize when expanded
    if (widget.isExpanded) {
      return SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: Key('notification_${widget.notification.type}'),
            direction: DismissDirection.endToStart,
            dismissThresholds: const {DismissDirection.endToStart: 0.3},
            onDismissed: (direction) {
              HapticFeedback.lightImpact();
              widget.onExpand?.call(); // Collapse it
            },
            confirmDismiss: (direction) async {
              // Always confirm so we can handle it in onDismissed
              return true;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Icon(
                Icons.minimize_rounded,
                color: Colors.white.withOpacity(0.6),
                size: 24,
              ),
            ),
            child: content,
          ),
        ),
      );
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: content),
    );
  }
}

// ============================================================================
// ALCHEMICAL PATTERN PAINTER (decorative background)
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

    // Draw alchemical circles and symbols
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) / 3;

    // Outer circle
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);

    // Inner circle
    canvas.drawCircle(Offset(centerX, centerY), radius * 0.7, paint);

    // Triangle (alchemical symbol for fire/transformation)
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
// NOTIFICATION BANNER STACK (manages multiple banners)
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
  final Set<NotificationBannerType> _dismissedTypes = {};
  final Map<NotificationBannerType, bool> _expandedStates = {};
  bool _isLoadingDismissals = true;

  @override
  void initState() {
    super.initState();
    _loadDismissedNotifications();
  }

  Future<void> _loadDismissedNotifications() async {
    try {
      final db = context.read<AlchemonsDatabase>();
      final dismissals = await (db.select(db.notificationDismissals)).get();

      setState(() {
        _dismissedTypes.clear();
        for (final dismissal in dismissals) {
          // Convert string back to enum
          final type = NotificationBannerType.values.firstWhere(
            (t) => t.toKey() == dismissal.notificationType,
            orElse: () => NotificationBannerType.eggReady,
          );
          _dismissedTypes.add(type);
        }
        _isLoadingDismissals = false;
      });

      // Now add active notifications that haven't been dismissed
      _updateActiveNotifications();
    } catch (e) {
      debugPrint('Error loading dismissed notifications: $e');
      setState(() => _isLoadingDismissals = false);
    }
  }

  void _updateActiveNotifications() {
    bool needsUpdate = false;

    // Add new notifications that aren't already active AND haven't been dismissed
    for (final notification in widget.notifications) {
      final bool isAlreadyActive = _activeNotifications.any(
        (n) => n.type == notification.type,
      );

      final bool hasBeenDismissed = _dismissedTypes.contains(notification.type);

      if (!isAlreadyActive && !hasBeenDismissed) {
        _activeNotifications.add(notification);
        _expandedStates[notification.type] = true; // Start new banners expanded
        needsUpdate = true;
      }
    }

    // Remove notifications that are no longer in the parent list
    final toRemove = _activeNotifications
        .where(
          (active) => !widget.notifications.any((n) => n.type == active.type),
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

  Future<void> _removeBanner(NotificationBannerType type) async {
    if (!mounted) return;

    try {
      final db = context.read<AlchemonsDatabase>();

      // Save dismissal to database
      await db
          .into(db.notificationDismissals)
          .insertOnConflictUpdate(
            NotificationDismissalsCompanion.insert(
              notificationType: type.toKey(),
              dismissedAtUtcMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      setState(() {
        _activeNotifications.removeWhere((n) => n.type == type);
        _expandedStates.remove(type);
        _dismissedTypes.add(type);
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
                key: ValueKey(notification.type),
                notification: notification,
                isExpanded: _expandedStates[notification.type] ?? false,
                onExpand: () => _toggleExpanded(notification.type),
                onDismiss: () => _removeBanner(notification.type),
              ),
            )
            .toList(),
      ),
    );
  }
}
