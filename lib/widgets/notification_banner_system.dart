import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

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
}

class NotificationBannerWidget extends StatefulWidget {
  final NotificationBanner notification;
  final VoidCallback onDismiss;

  const NotificationBannerWidget({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0), // Start off-screen right
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    _controller.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  Color _getBannerColor() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return const Color.fromARGB(255, 122, 8, 8); // Golden/yellow
      case NotificationBannerType.harvestReady:
        return const Color(0xFF4CAF50); // Green
      case NotificationBannerType.dailyReward:
        return const Color(0xFF9C27B0); // Purple
      case NotificationBannerType.bossAvailable:
        return const Color(0xFFF44336); // Red
      case NotificationBannerType.eventActive:
        return const Color(0xFF2196F3); // Blue
    }
  }

  IconData _getBannerIcon() {
    switch (widget.notification.type) {
      case NotificationBannerType.eggReady:
        return Icons.egg_rounded;
      case NotificationBannerType.harvestReady:
        return Icons.agriculture_rounded;
      case NotificationBannerType.dailyReward:
        return Icons.card_giftcard_rounded;
      case NotificationBannerType.bossAvailable:
        return Icons.warning_rounded;
      case NotificationBannerType.eventActive:
        return Icons.event_rounded;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.notification.onTap();
            _dismiss();
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getBannerColor(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(-2, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getBannerIcon(), color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.notification.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (widget.notification.count > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
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
                    if (widget.notification.subtitle != null)
                      Text(
                        widget.notification.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

  @override
  void initState() {
    super.initState();
    _activeNotifications.addAll(widget.notifications);
  }

  @override
  void didUpdateWidget(NotificationBannerStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Add new notifications
    for (final notification in widget.notifications) {
      if (!_activeNotifications.contains(notification)) {
        _activeNotifications.add(notification);
      }
    }
  }

  void _removeBanner(int index) {
    setState(() {
      _activeNotifications.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeNotifications.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _activeNotifications
            .asMap()
            .entries
            .map(
              (entry) => NotificationBannerWidget(
                notification: entry.value,
                onDismiss: () => _removeBanner(entry.key),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================================
// IMPROVED IDLE CARDS (replacing the old dropdowns)
// ============================================================================

class IdleActivityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color accentColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const IdleActivityCard({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    required this.accentColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1A1A).withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// IMPROVED HOME CONTENT
// ============================================================================

class ImprovedHomeContent extends StatefulWidget {
  final FactionTheme theme;
  final AnimationController breathingController;

  const ImprovedHomeContent({
    super.key,
    required this.theme,
    required this.breathingController,
  });

  @override
  State<ImprovedHomeContent> createState() => _ImprovedHomeContentState();
}

class _ImprovedHomeContentState extends State<ImprovedHomeContent> {
  final List<NotificationBanner> _notifications = [];

  @override
  void initState() {
    super.initState();
    // Example: Add notifications when conditions are met
    _checkForNotifications();
  }

  void _checkForNotifications() {
    // This would be called from your game state
    // Example notifications:

    // Uncomment to test:
    // _notifications.add(NotificationBanner(
    //   type: NotificationBannerType.eggReady,
    //   title: 'EGG READY',
    //   subtitle: 'Tap to hatch',
    //   count: 2,
    //   onTap: () {
    //     // Navigate to incubator
    //   },
    // ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Stats card (your existing one)
              _buildStatsCard(),

              const SizedBox(height: 16),

              // IMPROVED: Idle Activity Cards Row
              Row(
                children: [
                  Expanded(
                    child: IdleActivityCard(
                      icon: Icons.egg_rounded,
                      title: 'INCUBATOR',
                      status: 'IDLE',
                      accentColor: widget.theme.accent,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // Navigate to incubator
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: IdleActivityCard(
                      icon: Icons.agriculture_rounded,
                      title: 'HARVEST',
                      status: 'EXTRACTING',
                      accentColor: const Color(0xFF4CAF50),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // Navigate to harvest
                      },
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '2',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Your existing KPI cards (incubate/harvest expandable)
              _IncubateHarvestRow(
                theme: widget.theme,
                breathing: widget.breathingController,
              ),

              const SizedBox(height: 12),

              // Resource cards
              ResourceCollectionWidget(theme: widget.theme),

              const SizedBox(height: 16),
            ],
          ),
        ),

        // Notification banner stack (floats on top)
        NotificationBannerStack(notifications: _notifications),
      ],
    );
  }

  Widget _buildStatsCard() {
    // Your existing stats card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A1A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Stats Card'),
    );
  }
}

// ============================================================================
// PLACEHOLDER CLASSES (replace with your actual implementations)
// ============================================================================

class FactionTheme {
  final Color accent;
  final Color text;
  final Color textMuted;
  final Color accentSoft;

  FactionTheme({
    required this.accent,
    required this.text,
    required this.textMuted,
    required this.accentSoft,
  });

  BoxDecoration chipDecoration({required Color rim}) {
    return BoxDecoration(
      color: const Color(0xFF2A1A1A).withOpacity(0.6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: rim.withOpacity(0.3), width: 1.5),
    );
  }
}

// Your existing _IncubateHarvestRow widget goes here
class _IncubateHarvestRow extends StatelessWidget {
  final FactionTheme theme;
  final AnimationController breathing;

  const _IncubateHarvestRow({required this.theme, required this.breathing});

  @override
  Widget build(BuildContext context) {
    // Your existing implementation
    return const Placeholder(fallbackHeight: 80);
  }
}

class ResourceCollectionWidget extends StatelessWidget {
  final FactionTheme theme;

  const ResourceCollectionWidget({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    // Your existing implementation
    return const Placeholder(fallbackHeight: 120);
  }
}
