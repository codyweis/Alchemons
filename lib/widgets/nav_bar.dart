import 'dart:async';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/nav_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum NavSection { home, creatures, shop, breed, inventory }

/// How far the open tab's icon stands above the top of the dock.
///
/// The dock is 60 high; the open tab's icon grows to 80 and is lifted 30, so
/// it reaches about 40 above the dock's edge. A tab whose content ends in a
/// full-width control keeps that much clear, or the icon sits on it.
const double kDockIconRise = 40;

class BottomNav extends StatefulWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    this.theme,
    this.faction,
    this.isDisabled = false, // external lock still supported
  });

  final NavSection current;
  final ValueChanged<NavSection> onSelect;
  final FactionTheme? theme;

  /// Whose Let the dock is drawn in.
  final FactionId? faction;
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
  late final AnimationController _tutorialPulseController;

  /// The faction whose dock sheets have been loaded, once they have.
  FactionId? _precachedFor;
  bool _precached = false;
  int? _activePointer;
  Offset? _dragStart;
  bool _isSlidingAcrossNav = false;
  NavSection? _lastDraggedSection;

  final GlobalKey _creaturesIconKey = GlobalKey(debugLabel: 'nav-creatures');

  /// Whether any chamber has finished and is waiting to be extracted.
  ///
  /// Readiness is a moment in time, not a row change, so watching the slots is
  /// only half of it — the stream says nothing when a timer simply elapses.
  /// The ticker is what notices that, and it is slow because a chamber being
  /// ready ten seconds late costs nothing.
  bool _cultivationReady = false;
  StreamSubscription<List<IncubatorSlot>>? _slotSub;
  StreamSubscription<bool>? _extractionTutorialSub;
  StreamSubscription<bool>? _fieldTutorialSub;
  Timer? _readyTicker;
  List<IncubatorSlot> _slots = const [];
  bool _extractionComplete = false;
  bool _fieldTutorialComplete = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNavLets();
    _slotSub ??= context
        .read<AlchemonsDatabase>()
        .incubatorDao
        .watchSlots()
        .listen((slots) {
          _slots = slots;
          _refreshCultivationReady();
        });
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    _extractionTutorialSub ??= settings.watchExtractionTutorialState().listen((
      value,
    ) {
      if (mounted && value != _extractionComplete) {
        setState(() => _extractionComplete = value);
      }
    });
    _fieldTutorialSub ??= settings.watchFieldTutorialState().listen((value) {
      if (mounted && value != _fieldTutorialComplete) {
        setState(() => _fieldTutorialComplete = value);
      }
    });
    _readyTicker ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshCultivationReady(),
    );
  }

  void _refreshCultivationReady() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final ready = _slots.any(
      (s) => s.eggId != null && (s.hatchAtUtcMs ?? 0) <= now,
    );
    if (mounted && ready != _cultivationReady) {
      setState(() => _cultivationReady = ready);
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
    _tutorialPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    NewDiscoveryReveal.instance.databaseNavKey = _creaturesIconKey;
  }

  @override
  void didUpdateWidget(BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _expandController.forward(from: 0.0);
    }
    if (oldWidget.faction != widget.faction) _precacheNavLets();
  }

  @override
  void dispose() {
    _slotSub?.cancel();
    _extractionTutorialSub?.cancel();
    _fieldTutorialSub?.cancel();
    _readyTicker?.cancel();
    _expandController.dispose();
    _tutorialPulseController.dispose();
    if (identical(
      NewDiscoveryReveal.instance.databaseNavKey,
      _creaturesIconKey,
    )) {
      NewDiscoveryReveal.instance.databaseNavKey = null;
    }
    super.dispose();
  }

  /// Loads the faction's Let sheets (and bakes the Alchemized and Transmuted
  /// ones) before the dock first draws them, so they do not pop in.
  void _precacheNavLets() {
    if (_precached && _precachedFor == widget.faction) return;
    _precached = true;
    _precachedFor = widget.faction;
    precacheNavLets(context.read<CreatureCatalog>(), widget.faction);
  }

  Future<void> _handleTap(
    NavSection section, {
    required bool isDisabled,
  }) async {
    if (isDisabled) {
      context.sound(SoundCue.uiDenied);
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

        if (extractionPending ||
            (!extractionTutorialComplete && !fieldTutorialComplete)) {
          // State 1: Extraction pending (starter granted, waiting for extraction)
          message = 'Extract your vial in Cultivations first';
        } else if (!fieldTutorialComplete) {
          // State 2: Extraction done, field tutorial not started
          message =
              'Tap Field on the home screen to begin your first expedition';
        } else {
          // State 3: Both tutorials done, generic nav lock (shouldn't happen normally)
          message = 'Navigation locked';
        }

        if (!mounted) return;

        showGameSnack(
          context,
          message,
          duration: const Duration(seconds: 2),
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
                          icon: NavEmblemKind.inventory,
                          label: 'INVENTORY',
                          theme: theme,
                          isDisabled: isDisabled,
                        ),
                        _buildNavButton(
                          section: NavSection.creatures,
                          icon: NavEmblemKind.creatures,
                          label: 'CREATURES',
                          theme: theme,
                          isDisabled: isDisabled,
                          iconKey: _creaturesIconKey,
                        ),
                        _buildNavButton(
                          section: NavSection.home,
                          icon: NavEmblemKind.home,
                          label: 'HOME',
                          theme: theme,
                          isDisabled: isDisabled,
                          highlight:
                              _extractionComplete &&
                              !_fieldTutorialComplete &&
                              widget.current != NavSection.home,
                        ),
                        _buildNavButton(
                          section: NavSection.breed,
                          icon: NavEmblemKind.fusion,
                          label: 'FUSION',
                          theme: theme,
                          isDisabled: isDisabled,
                          showDot: _cultivationReady,
                        ),
                        _buildNavButton(
                          section: NavSection.shop,
                          icon: NavEmblemKind.shop,
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

  /// A chamber is waiting. Not scaled with the icon, but placed by its size so
  /// it rides the emblem's upper-right shoulder instead of the box's corner.
  Widget _withDot(bool show, double size, Widget icon) {
    if (!show) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: size * 0.20 - 5.5,
          top: size * 0.20 - 5.5,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: const Color(0xFF34D399),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0B0E13), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required NavSection section,
    required NavEmblemKind icon,
    required String label,
    required FactionTheme? theme,
    required bool isDisabled,
    Key? iconKey,
    bool showDot = false,
    bool highlight = false,
  }) {
    final isActive = widget.current == section;
    final double opacity = isDisabled ? 0.5 : 1.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_expandAnimation, _tutorialPulseController]),
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

        final tutorialPulse = highlight
            ? Curves.easeInOut.transform(_tutorialPulseController.value)
            : 0.0;
        return Transform.translate(
          offset: Offset(0, verticalOffset),
          child: GestureDetector(
            onTap: context.soundAction(
              () => _handleTap(section, isDisabled: isDisabled),
            ),
            child: Container(
              width: size,
              height: size,
              decoration: highlight
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (theme?.accent ?? Colors.amber).withValues(
                          alpha: 0.55 + tutorialPulse * 0.4,
                        ),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (theme?.accent ?? Colors.amber).withValues(
                            alpha: 0.18 + tutorialPulse * 0.28,
                          ),
                          blurRadius: 10 + tutorialPulse * 12,
                          spreadRadius: tutorialPulse * 3,
                        ),
                      ],
                    )
                  : null,
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
                      _withDot(
                        showDot,
                        iconSize,
                        NavEmblem(
                          key: iconKey,
                          kind: icon,
                          faction: widget.faction,
                          size: iconSize,
                          // Only the open tab moves.
                          animate: isActive && !isDisabled,
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
