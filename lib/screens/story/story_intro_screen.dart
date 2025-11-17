// lib/screens/story/story_intro_screen.dart

import 'dart:async';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/creature_showcase_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class StoryIntroScreen extends StatefulWidget {
  const StoryIntroScreen({super.key});

  @override
  State<StoryIntroScreen> createState() => _StoryIntroScreenState();
}

class _StoryIntroScreenState extends State<StoryIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pageTransitionController;

  int _currentPage = 0;
  bool _isSkipping = false;
  bool _isTransitioning = false;
  Timer? _skipTimer;
  Timer? _autoAdvanceTimer;

  final List<StoryPage> _storyPages = AlchemonsStory.allPages;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
      value: 1.0, // Start fully visible
    );

    // Start with fade in
    _fadeController.forward();

    // Start auto-advance timer
    _startAutoAdvanceTimer();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageTransitionController.dispose();
    _skipTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _startAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && !_isTransitioning) {
        _nextPage();
      }
    });
  }

  void _cancelAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
  }

  void _nextPage() {
    if (_isTransitioning) return; // Prevent double-taps during transition

    // Cancel current timer since user manually advanced or auto-advance triggered
    _cancelAutoAdvanceTimer();

    if (_currentPage < _storyPages.length - 1) {
      HapticFeedback.lightImpact();
      _isTransitioning = true;

      // Fade out current page
      _pageTransitionController.reverse().then((_) {
        if (mounted) {
          // Change page while invisible
          setState(() => _currentPage++);

          // Fade in new page
          _pageTransitionController.forward().then((_) {
            _isTransitioning = false;

            // Don't auto-advance on loading screen
            final currentPage = _storyPages[_currentPage];
            if (currentPage.type != StoryPageType.loading) {
              _startAutoAdvanceTimer();
            }
          });
        }
      });
    } else {
      _completeStory();
    }
  }

  void _previousPage() {
    if (_isTransitioning) return;

    // Cancel auto-advance when going backwards
    _cancelAutoAdvanceTimer();

    if (_currentPage > 0) {
      HapticFeedback.lightImpact();
      _isTransitioning = true;

      _pageTransitionController.reverse().then((_) {
        if (mounted) {
          setState(() => _currentPage--);
          _pageTransitionController.forward().then((_) {
            _isTransitioning = false;
            // Restart auto-advance timer
            _startAutoAdvanceTimer();
          });
        }
      });
    }
  }

  void _completeStory() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true); // Return true to indicate completion
  }

  void _onSkipStart() {
    setState(() => _isSkipping = true);
    HapticFeedback.mediumImpact();

    _skipTimer = Timer(const Duration(seconds: 2), () {
      if (_isSkipping) {
        _skipToLoading();
      }
    });
  }

  void _skipToLoading() {
    // Cancel timers
    _cancelAutoAdvanceTimer();
    _skipTimer?.cancel();

    setState(() => _isSkipping = false);

    // Find the loading page index
    final loadingIndex = _storyPages.indexWhere(
      (page) => page.type == StoryPageType.loading,
    );

    if (loadingIndex != -1 && loadingIndex != _currentPage) {
      HapticFeedback.mediumImpact();
      _isTransitioning = true;

      // Fade out current page
      _pageTransitionController.reverse().then((_) {
        if (mounted) {
          // Jump to loading screen
          setState(() => _currentPage = loadingIndex);

          // Fade in loading screen
          _pageTransitionController.forward().then((_) {
            _isTransitioning = false;
            // Loading screen will handle completion
          });
        }
      });
    }
  }

  void _onSkipCancel() {
    setState(() => _isSkipping = false);
    _skipTimer?.cancel();
    _skipTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = _storyPages[_currentPage];
    final isLoadingPage = currentPage.type == StoryPageType.loading;

    return Scaffold(
      backgroundColor: currentPage.backgroundColor ?? Colors.black,
      body: GestureDetector(
        onTap: isLoadingPage ? null : _nextPage, // ← Disabled on loading
        onLongPressStart: isLoadingPage
            ? null
            : (_) => _onSkipStart(), // ← Disabled
        onLongPressEnd: isLoadingPage ? null : (_) => _onSkipCancel(),
        onLongPressCancel: isLoadingPage ? null : _onSkipCancel,
        child: Stack(
          children: [
            // Background with subtle animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              color: currentPage.backgroundColor ?? Colors.black,
            ),

            // Page content with sequential fade transition
            Center(
              child: FadeTransition(
                opacity: _pageTransitionController,
                child: _buildPageContent(
                  currentPage,
                  key: ValueKey(_currentPage),
                ),
              ),
            ),

            // Skip indicator (only shown when holding)
            if (_isSkipping)
              Positioned(
                top: 60,
                right: 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(StoryPage page, {Key? key}) {
    return Container(
      key: key,
      child: switch (page.type) {
        StoryPageType.quote => _buildQuotePage(page),
        StoryPageType.narrative => _buildNarrativePage(page),
        StoryPageType.creatureReveal => _buildCreatureRevealPage(page),
        StoryPageType.elementIntro => _buildElementIntroPage(page),
        StoryPageType.loading => _buildLoadingPage(page),
      },
    );
  }

  Widget _buildQuotePage(StoryPage page) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              page.mainText,
              style: GoogleFonts.crimsonText(
                fontSize: 22,
                height: 1.6,
                color: page.textColor ?? Colors.white,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrativePage(StoryPage page) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              page.mainText,
              style: GoogleFonts.cinzelDecorative(
                fontSize: 26,
                height: 1.8,
                color: page.textColor ?? Colors.white,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatureRevealPage(StoryPage page) {
    // We'll show a creature here - you can customize which one
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Creature showcase goes here
          // For now, placeholder
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 80,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            '...',
            style: GoogleFonts.robotoMono(
              fontSize: 18,
              color: Colors.white70,
              letterSpacing: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementIntroPage(StoryPage page) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              page.mainText,
              style: GoogleFonts.cinzelDecorative(
                fontSize: 24,
                height: 1.8,
                color: page.textColor ?? Colors.white,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPage(StoryPage page) {
    return _LoadingScreen(
      text: page.mainText,
      backgroundImagePath: page.backgroundImagePath,
      onComplete: _completeStory,
    );
  }
}

// Separate stateful widget for loading screen
class _LoadingScreen extends StatefulWidget {
  final String text;
  final String? backgroundImagePath;
  final VoidCallback onComplete;

  const _LoadingScreen({
    required this.text,
    this.backgroundImagePath,
    required this.onComplete,
  });

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen> {
  double _progress = 0.0;
  String _statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  Future<void> _startLoading() async {
    try {
      // Step 1: Precache navbar icons (15%)
      await _loadNavbarAssets();

      // Step 2: Precache creature sprites (25%)
      await _precacheCreatureAssets();

      // Step 3: Warm up database (30%)
      await _warmupDatabase();

      // Step 4: Initialize services (20%)
      await _initializeServices();

      // Step 5: Final prep (10%)
      await _finalizeLoading();

      // Complete
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error during loading: $e');
      // Even if loading fails, complete the story
      if (mounted) {
        widget.onComplete();
      }
    }
  }

  Future<void> _loadNavbarAssets() async {
    if (!mounted) return;
    setState(() {
      _statusText = 'Loading interface assets...';
      _progress = 0.05;
    });

    // ✨ Seen in BottomNav and first Home frame / side dock
    const uiPaths = <String>[
      // bottom nav
      'assets/images/ui/inventorylight.png',
      'assets/images/ui/inventorydark.png',
      'assets/images/ui/dexicon_light.png',
      'assets/images/ui/dexicon.png',
      'assets/images/ui/homeicon2.png',
      'assets/images/ui/breedicon.png',
      'assets/images/ui/shopicon2.png',

      // header/avatar + quick actions likely visible immediately
      'assets/images/ui/profileicon.png',
      'assets/images/ui/map.png',
      'assets/images/ui/enhanceicon.png',
      'assets/images/ui/fieldicon.png',
      'assets/images/ui/competeicon.png',
      'assets/images/ui/extractionicon.png',
    ];

    // Match BottomNav's icon sizes (inactive ≈ 55, expanded tops out around ~80–120)
    const inactive = Size(55, 55);
    const expanded = Size(120, 120);

    for (final path in uiPaths) {
      final provider = AssetImage(path);
      try {
        await precacheImage(provider, context, size: inactive);
        await precacheImage(provider, context, size: expanded);
      } catch (e) {
        debugPrint('Failed to precache $path: $e');
      }
    }

    if (!mounted) return;
    setState(() => _progress = 0.15);
  }

  Future<void> _precacheCreatureAssets() async {
    if (!mounted) return;
    setState(() {
      _statusText = 'Loading creature database...';
      _progress = 0.20;
    });

    try {
      final catalog = context.read<CreatureCatalog>();
      final db = context.read<AlchemonsDatabase>();

      // Get discovered creatures (these are most likely to be viewed)
      final playerCreatures = await db.creatureDao.getAllCreatures();
      final discoveredIds = playerCreatures
          .where((p) => p.discovered)
          .map((p) => p.id)
          .toSet();

      // Get user's creature instances (these are guaranteed to be viewed)
      final instances = await db.creatureDao.listAllInstances();
      final ownedIds = instances.map((i) => i.baseId).toSet();

      // Combine discovered + owned, prioritizing owned
      final priorityIds = [...ownedIds, ...discoveredIds];

      if (!mounted) return;
      setState(() {
        _statusText = 'Preparing specimens...';
        _progress = 0.25;
      });

      // Precache priority creatures (discovered/owned)
      int cached = 0;
      for (final id in priorityIds.take(20)) {
        // Limit to first 20 to keep loading reasonable
        final creature = catalog.getCreatureById(id);
        if (creature?.spriteData != null) {
          try {
            final provider = AssetImage(creature!.spriteData!.spriteSheetPath);
            await precacheImage(provider, context);
            cached++;

            if (!mounted) return;
            // Update progress smoothly through this section
            final subProgress = (cached / 20.0) * 0.20; // 20% of total
            setState(() => _progress = 0.25 + subProgress);
          } catch (e) {
            debugPrint('Failed to precache sprite for $id: $e');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _statusText = 'Specimen assets loaded...';
        _progress = 0.40;
      });
    } catch (e) {
      debugPrint('Error precaching creature assets: $e');
      if (!mounted) return;
      setState(() => _progress = 0.40);
    }
  }

  Future<void> _warmupDatabase() async {
    if (!mounted) return;
    setState(() {
      _statusText = 'Accessing specimen database...';
      _progress = 0.45;
    });

    try {
      final db = context.read<AlchemonsDatabase>();

      // Warm up common queries
      await db.creatureDao.listAllInstances();
      if (!mounted) return;
      setState(() => _progress = 0.52);

      await db.creatureDao.getAllCreatures();
      if (!mounted) return;
      setState(() => _progress = 0.58);

      await db.incubatorDao.watchSlots().first;
      if (!mounted) return;
      setState(() => _progress = 0.64);

      await db.biomeDao.watchBiomes().first;
      if (!mounted) return;
      setState(() => _progress = 0.70);
    } catch (e) {
      debugPrint('Database warmup error: $e');
    }
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;
    setState(() {
      _statusText = 'Initializing research systems...';
      _progress = 0.75;
    });

    // Give services time to initialize
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    setState(() => _progress = 0.82);

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    setState(() => _progress = 0.90);
  }

  Future<void> _finalizeLoading() async {
    if (!mounted) return;
    setState(() {
      _statusText = 'Preparing laboratory...';
      _progress = 0.92;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _statusText = 'Ready';
      _progress = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image or solid color
        if (widget.backgroundImagePath != null)
          Positioned.fill(
            child: Image.asset(
              widget.backgroundImagePath!,
              fit: BoxFit.fitHeight,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF0A0A0A));
              },
            ),
          )
        else
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0A))),

        // Dark overlay
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

        // Loading UI
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Main text
                Text(
                  widget.text,
                  style: GoogleFonts.robotoMono(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Status text
                Text(
                  _statusText,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.cyan.shade400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Percentage
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: GoogleFonts.robotoMono(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
