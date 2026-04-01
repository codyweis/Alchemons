import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum NavSection { home, creatures, shop, breed, inventory }

class BottomNav extends StatefulWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    this.theme,
    this.isDisabled = false, // external lock still supported
  });

  final NavSection current;
  final ValueChanged<NavSection> onSelect;
  final FactionTheme? theme;
  final bool isDisabled;

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> with TickerProviderStateMixin {
  static const List<NavSection> _navSections = <NavSection>[
    NavSection.inventory,
    NavSection.creatures,
    NavSection.home,
    NavSection.breed,
    NavSection.shop,
  ];
  static const double _dragActivationDistance = 12;

  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  static bool _navIconsCached = false;
  int? _activePointer;
  Offset? _dragStart;
  bool _isSlidingAcrossNav = false;
  NavSection? _lastDraggedSection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_navIconsCached) {
      _navIconsCached = true;
      _precacheNavIcons();
    }
  }

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _expandController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _precacheNavIcons() async {
    const paths = <String>[
      'assets/images/ui/inventorylight.png',
      'assets/images/ui/inventorydark.png',
      'assets/images/ui/dexicon_light.png',
      'assets/images/ui/dexicon.png',
      'assets/images/ui/homeicon2.png',
      'assets/images/ui/extrastorage.png',
      'assets/images/ui/shopicon2.png',
    ];

    for (final path in paths) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (e) {
        debugPrint('Failed to precache bottom nav icon $path: $e');
      }
    }
  }

  Future<void> _handleTap(
    NavSection section, {
    required bool isDisabled,
  }) async {
    if (isDisabled) {
      try {
        HapticFeedback.heavyImpact();

        // Check tutorial state to determine the appropriate message
        final db = context.read<AlchemonsDatabase>();
        final extractionPending =
            await db.settingsDao.getSetting('tutorial_extraction_pending') ==
            '1';
        final extractionTutorialComplete = await db.settingsDao
            .hasCompletedExtractionTutorial();
        final fieldTutorialComplete = await db.settingsDao
            .hasCompletedFieldTutorial();

        String message;
        IconData iconData;

        if (extractionPending ||
            (!extractionTutorialComplete && !fieldTutorialComplete)) {
          // State 1: Extraction pending (starter granted, waiting for extraction)
          message = 'Please extract your vial from the Extraction Chamber!';
          iconData = Icons.science_rounded;
        } else if (!fieldTutorialComplete) {
          // State 2: Extraction done, field tutorial not started
          message = 'Please tap the Field icon to begin your first expedition';
          iconData = Icons.explore_rounded;
        } else {
          // State 3: Both tutorials done, generic nav lock (shouldn't happen normally)
          message = 'Navigation locked';
          iconData = Icons.lock_outline;
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(iconData, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 76),
            duration: const Duration(seconds: 2),
            showCloseIcon: true,
          ),
        );
      } catch (_) {}
      return;
    }
    HapticFeedback.lightImpact();
    widget.onSelect(section);
  }

  void _handlePointerDown(PointerDownEvent event, {required bool isDisabled}) {
    if (isDisabled || _activePointer != null) return;
    _activePointer = event.pointer;
    _dragStart = event.localPosition;
    _isSlidingAcrossNav = false;
    _lastDraggedSection = widget.current;
  }

  void _handlePointerMove(
    PointerMoveEvent event, {
    required double width,
    required bool isDisabled,
  }) {
    if (isDisabled || event.pointer != _activePointer || width <= 0) return;

    final dragStart = _dragStart;
    if (dragStart == null) return;

    if (!_isSlidingAcrossNav) {
      final delta = event.localPosition - dragStart;
      if (delta.distanceSquared <
          _dragActivationDistance * _dragActivationDistance) {
        return;
      }
      _isSlidingAcrossNav = true;
    }

    final nextSection = _sectionForDx(event.localPosition.dx, width);
    if (nextSection == null || nextSection == _lastDraggedSection) return;

    _lastDraggedSection = nextSection;
    if (nextSection == widget.current) return;

    HapticFeedback.selectionClick();
    widget.onSelect(nextSection);
  }

  void _resetPointerTracking([int? pointer]) {
    if (pointer != null && pointer != _activePointer) return;
    _activePointer = null;
    _dragStart = null;
    _isSlidingAcrossNav = false;
    _lastDraggedSection = null;
  }

  NavSection? _sectionForDx(double dx, double width) {
    if (_navSections.isEmpty || width <= 0) return null;
    final clampedDx = dx.clamp(0.0, width - 0.001);
    final slotWidth = width / _navSections.length;
    final index = (clampedDx / slotWidth).floor();
    if (index < 0 || index >= _navSections.length) return null;
    return _navSections[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = theme?.isDark ?? true;
    final db = context.read<AlchemonsDatabase>();

    // watch the nav lock flag from settings; defaults to '0' if unset
    return StreamBuilder<String?>(
      stream: db.settingsDao.watchSetting('nav_locked_until_extraction_ack'),
      builder: (context, snap) {
        final lockedByFlow = (snap.data ?? '0') == '1';
        final isDisabled = widget.isDisabled || lockedByFlow;

        return Container(
          decoration: BoxDecoration(color: theme?.surfaceAlt),
          clipBehavior: Clip.none,
          child: SizedBox(
            height: 60,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) =>
                      _handlePointerDown(event, isDisabled: isDisabled),
                  onPointerMove: (event) => _handlePointerMove(
                    event,
                    width: constraints.maxWidth,
                    isDisabled: isDisabled,
                  ),
                  onPointerUp: (event) => _resetPointerTracking(event.pointer),
                  onPointerCancel: (event) =>
                      _resetPointerTracking(event.pointer),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavButton(
                          section: NavSection.inventory,
                          icon: 'assets/images/ui/inventorylight.png',
                          label: 'INVENTORY',
                          theme: theme,
                          isDisabled: isDisabled,
                        ),
                        _buildNavButton(
                          section: NavSection.creatures,
                          icon: isDark
                              ? 'assets/images/ui/dexicon_light.png'
                              : 'assets/images/ui/dexicon.png',
                          label: 'CREATURES',
                          theme: theme,
                          isDisabled: isDisabled,
                        ),
                        _buildNavButton(
                          section: NavSection.home,
                          icon: 'assets/images/ui/homeicon2.png',
                          label: 'HOME',
                          theme: theme,
                          isDisabled: isDisabled,
                        ),
                        _buildNavButton(
                          section: NavSection.breed,
                          icon: 'assets/images/ui/extrastorage.png',
                          label: 'FUSION',
                          theme: theme,
                          isDisabled: isDisabled,
                        ),
                        _buildNavButton(
                          section: NavSection.shop,
                          icon: 'assets/images/ui/shopicon2.png',
                          label: 'SHOP',
                          theme: theme,
                          isDisabled: isDisabled,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required NavSection section,
    required dynamic icon, // IconData | String (asset path)
    required String label,
    required FactionTheme? theme,
    required bool isDisabled,
  }) {
    final isActive = widget.current == section;
    final double opacity = isDisabled ? 0.5 : 1.0;

    final Color? iconColor = null;
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final bool shouldExpand = isActive && !isDisabled;

        final size = shouldExpand
            ? (48.0 + (_expandAnimation.value * 32))
            : 48.0;
        final verticalOffset = shouldExpand
            ? -(_expandAnimation.value * 30)
            : 0.0;
        final iconSize = shouldExpand
            ? (40.0 + (_expandAnimation.value * 40))
            : 55.0;

        return Transform.translate(
          offset: Offset(0, verticalOffset),
          child: GestureDetector(
            onTap: () => _handleTap(section, isDisabled: isDisabled),
            child: SizedBox(
              width: size,
              height: size,
              child: Opacity(
                opacity: opacity,
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon is IconData)
                        Icon(icon, color: iconColor, size: iconSize)
                      else if (icon is String)
                        SizedBox(
                          width: iconSize,
                          height: iconSize,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: Image.asset(
                              gaplessPlayback: true,
                              icon,
                              fit: BoxFit.contain,
                              color: iconColor,
                              colorBlendMode: BlendMode.modulate,
                            ),
                          ),
                        ),
                      if (shouldExpand)
                        Opacity(
                          opacity: _expandAnimation.value,
                          child: Text(
                            label,
                            style: TextStyle(
                              color: (theme?.text ?? Colors.white).withValues(
                                alpha: opacity,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
