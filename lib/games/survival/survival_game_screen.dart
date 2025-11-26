import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/survival/components/debug_teams_picker.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/games/survival/survival_party_picker.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurvivalGameScreen extends StatefulWidget {
  const SurvivalGameScreen({super.key});

  @override
  State<SurvivalGameScreen> createState() => _SurvivalGameScreenState();
}

class _SurvivalGameScreenState extends State<SurvivalGameScreen> {
  SurvivalHoardGame? _game;
  bool _isLoading = false;

  late final PageController _familyPageController;
  double _familyPage = 0;

  @override
  void initState() {
    super.initState();
    _familyPageController = PageController(viewportFraction: 0.78);
    _familyPageController.addListener(() {
      setState(() {
        _familyPage = _familyPageController.page ?? 0;
      });
    });
  }

  Future<void> _openDebugTeamPicker() async {
    if (_isLoading) return;

    final party = await Navigator.of(context).push<List<PartyMember>>(
      MaterialPageRoute(builder: (_) => const SurvivalDebugTeamPickerScreen()),
    );

    if (party == null || !mounted) return;

    setState(() {
      _game = SurvivalHoardGame(party: party, onGameOver: _handleGameOver);
    });
  }

  @override
  void dispose() {
    _familyPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    if (_game != null) {
      return _buildGameView(theme);
    }

    return _buildFormationPrompt(theme);
  }

  Widget _buildBackButton(FactionTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                'Leave Game?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Your progress will be lost.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Leave'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildFormationPrompt(FactionTheme theme) {
    return ParticleBackgroundScaffold(
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        'Endless Survival',
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Survive waves of elemental particles',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // NEW: family/species carousel
                      _buildFamilyCarousel(theme),

                      const SizedBox(height: 32),

                      // Game Mechanics Section
                      _buildMechanicsSection(theme),

                      const SizedBox(height: 24),

                      // Strategy Tips Section
                      _buildStrategySection(theme),

                      const SizedBox(height: 32),

                      // Start Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _openFormationSelector,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: theme.surface,
                            disabledForegroundColor: theme.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.group_rounded, size: 24),
                          label: Text(
                            _isLoading ? 'Preparing...' : 'Assemble Your Team',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _isLoading ? null : _openDebugTeamPicker,

                          label: const Text(
                            'Pick Prebuilt Team',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlchemyOrb(FactionTheme theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 3),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.accent.withOpacity(0.8),
                  theme.accent.withOpacity(0.4),
                  theme.accent.withOpacity(0.1),
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating outer ring
                Transform.rotate(
                  angle: value * 6.28, // Full rotation
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Counter-rotating inner ring
                Transform.rotate(
                  angle: -value * 6.28,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withOpacity(0.4),
                        width: 1.5,
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

  Widget _buildMechanicsSection(FactionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'How It Works',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMechanicItem(
            theme,
            Icons.waves_rounded,
            'Endless Waves',
            'Enemies spawn continuously with increasing difficulty',
          ),
          const SizedBox(height: 12),
          _buildMechanicItem(
            theme,
            Icons.trending_up_rounded,
            'Escalating Challenge',
            'Enemy speed, health, and spawn rate increase over time',
          ),
        ],
      ),
    );
  }

  Widget _buildStrategySection(FactionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Strategic Tips',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStrategyTip(
            theme,
            '1',
            'Balance your team',
            'Mix damage dealers with support creatures for survivability',
          ),

          const SizedBox(height: 12),
          _buildStrategyTip(
            theme,
            '2',
            'Breed Powerful Alchemons',
            'Different alchemons have unique strengths and abilities. Genetics play a key role in maximizing potential.',
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicItem(
    FactionTheme theme,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyTip(
    FactionTheme theme,
    String number,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    FactionTheme theme,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: theme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Survival Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Test your team against endless waves',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFormationSelector() async {
    final formationSlots = await Navigator.of(context).push<Map<int, String>>(
      MaterialPageRoute(
        builder: (_) => const SurvivalFormationSelectorScreen(),
      ),
    );

    if (formationSlots != null && mounted) {
      bool useDebugTeam = false;

      assert(() {
        // HOLD down 3 fingers or enable a toggle later — for now always true
        useDebugTeam = true;
        return true;
      }());

      if (formationSlots != null && mounted) {
        await _startGameWithFormation(formationSlots);
      }
    }
  }

  void _handleGameOver() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(
          'Wave survived: ${_game?.timeElapsed.toStringAsFixed(1)}s\n'
          'Score: ${_game?.score ?? 0}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              setState(() {
                _game = null; // go back to formation screen
              });
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // leave survival mode screen
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverlay() {
    return ValueListenableBuilder<SurvivalGameStats>(
      valueListenable: _game!.statsNotifier,
      builder: (context, stats, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withOpacity(0.7), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('TIME', stats.formattedTime, Colors.white),
              const SizedBox(height: 4),
              _buildStatRow('KILLS', stats.kills.toString(), Colors.redAccent),
              const SizedBox(height: 4),
              _buildStatRow(
                'SCORE',
                stats.score.toString(),
                Colors.yellowAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildGameView(FactionTheme theme) {
    return ParticleBackgroundScaffold(
      body: Scaffold(
        backgroundColor: Colors.black.withOpacity(.6),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GameWidget(
                game: _game!,
                backgroundBuilder: (context) =>
                    Container(color: Colors.transparent),
              ),
            ),

            // Alchemical choices overlay (center)
            if (_game != null) _buildAlchemyOverlay(),

            // Stats Overlay (Top Right)
            Align(
              alignment: Alignment.topRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: _buildStatsOverlay(),
                ),
              ),
            ),

            // Top bar (Back Button, Top Left)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [_buildBackButton(theme)]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlchemyOverlay() {
    return ValueListenableBuilder<AlchemyChoiceState?>(
      valueListenable: _game!.alchemyChoiceNotifier,
      builder: (context, state, child) {
        if (state == null) return const SizedBox.shrink();

        final theme = context.watch<FactionTheme>();

        return Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                theme.accent.withOpacity(0.9),
                                theme.accent.withOpacity(0.2),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alchemical Surge',
                                style: TextStyle(
                                  color: theme.text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Choose how to transmute your power this wave.',
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Option cards
                    ...state.options.map(
                      (opt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _AlchemyOptionCard(
                          theme: theme,
                          label: opt.label,
                          description: opt.description,
                          onTap: () => _game!.applyAlchemyChoice(opt),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Tip: these choices stack over time — experiment with different synergies.',
                      style: TextStyle(
                        color: theme.textMuted.withOpacity(0.9),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startGameWithFormation(Map<int, String> formationSlots) async {
    if (_isLoading) return;

    // Validate formation
    if (!SurvivalFormationHelper.isFormationValid(formationSlots)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid formation - please try again'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = context.read<AlchemonsDatabase>();
      final catalog = context.read<CreatureCatalog>();

      // Build party with formation positions
      final party = await SurvivalFormationHelper.buildPartyFromFormation(
        formationSlots: formationSlots,
        db: db,
        catalog: catalog,
      );

      if (party.length < 4) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load all team members'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _game = SurvivalHoardGame(
              party: party,
              onGameOver: _handleGameOver,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting game: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFamilyCarousel(FactionTheme theme) {
    final families = _familyInfos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Alchemon Species',
              style: TextStyle(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Each species has a distinct role and shines with different powerups.',
          style: TextStyle(color: theme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _familyPageController,
            itemCount: families.length,
            itemBuilder: (context, index) {
              final info = families[index];
              final distance = (index - _familyPage).abs().clamp(0.0, 1.0);
              final scale = 1.0 - (0.08 * distance);
              final opacity = 1.0 - (0.4 * distance);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _buildFamilyCard(theme, info),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(families.length, (index) {
            final isActive = (index - _familyPage).abs() < 0.5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: isActive ? 20 : 8,
              decoration: BoxDecoration(
                color: isActive ? theme.accent : theme.accent.withOpacity(0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFamilyCard(FactionTheme theme, _FamilyInfo info) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.accent.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Silhouetted sprite with mystical aurora
          Expanded(
            flex: 4,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Aurora glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          theme.accent.withOpacity(0.7),
                          theme.accent.withOpacity(0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                  // Outer orbit ring
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Inner ring
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  // Silhouette sprite
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(info.assetPath, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Text details
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.role,
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  info.description,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_fix_high_rounded,
                      size: 14,
                      color: theme.accent.withOpacity(0.9),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Best with: ${info.bestPowerups}',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Updated _AlchemyOptionCard with dynamic coloring
// Updated _AlchemyOptionCard with 4 category colors
class _AlchemyOptionCard extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _AlchemyOptionCard({
    required this.theme,
    required this.label,
    required this.description,
    required this.onTap,
  });

  Color _getOptionColor() {
    // Transmute options (stat modifications)
    if (label.contains('Transmute')) {
      return const Color(0xFF9C27B0); // Purple for Transmute
    }

    // Empower options (ability boosts)
    if (label.contains('Empower')) {
      return const Color(0xFFFF5722); // Deep Orange for Empower
    }

    // Deploy options
    if (label.contains('Deploy') || label.contains('Extra')) {
      return const Color(0xFF03A9F4); // Cyan for Deploy
    }

    // Default: Heal Orb
    return const Color(0xFF4CAF50); // Green for Heal/Default
  }

  IconData _getIconForCategory() {
    if (label.contains('Transmute')) {
      return Icons.swap_horiz_rounded; // Transmute icon
    } else if (label.contains('Empower')) {
      return Icons.bolt_rounded; // Empower icon
    } else if (label.contains('Deploy') || label.contains('Extra')) {
      return Icons.add_circle_outline_rounded; // Deploy icon
    }
    return Icons.favorite_rounded; // Heal orb icon
  }

  @override
  Widget build(BuildContext context) {
    final optionColor = _getOptionColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.surface.withOpacity(0.95),
                theme.surface.withOpacity(0.75),
              ],
            ),
            border: Border.all(color: optionColor.withOpacity(0.7), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: optionColor.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left accent stripe with category color
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [optionColor, optionColor.withOpacity(0.2)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with colored icon
                    Row(
                      children: [
                        // Category icon with color
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: optionColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _getIconForCategory(),
                            size: 16,
                            color: optionColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: optionColor.withOpacity(0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyInfo {
  final String id;
  final String name;
  final String role;
  final String description;
  final String bestPowerups;
  final String assetPath;

  const _FamilyInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.bestPowerups,
    required this.assetPath,
  });
}

const List<_FamilyInfo> _familyInfos = [
  _FamilyInfo(
    id: 'Let',
    name: 'Let',
    role: 'Meteor Caster',
    description:
        'Drops heavy AoE meteors to erase clustered waves. Shines in swarm and boss add phases.',
    bestPowerups: 'Int Transmute, Empower Meteor, Extra Deploy',
    assetPath: 'assets/images/creatures/common/LET01_firelet.png',
  ),
  _FamilyInfo(
    id: 'Pip',
    name: 'Pip',
    role: 'Ricochet Marksman',
    description:
        'Projectiles that bounce between enemies, turning tight packs into free value.',
    bestPowerups: 'Speed/Int Transmute, Empower Ricochet',
    assetPath: 'assets/images/creatures/uncommon/PIP01_firepip.png',
  ),
  _FamilyInfo(
    id: 'Mane',
    name: 'Mane',
    role: 'Zone Control',
    description:
        'Lays down hazards that melt anything standing in them. Great for choke points and attrition waves.',
    bestPowerups: 'Int/Beauty Transmute, Empower Hazards',
    assetPath: 'assets/images/creatures/uncommon/MAN03_earthmane.png',
  ),
  _FamilyInfo(
    id: 'Mask',
    name: 'Mask',
    role: 'Debuff / Control',
    description:
        'Twists the battlefield with debuffs and crowd control, making tough waves manageable.',
    bestPowerups: 'Beauty Transmute, Empower Special, Extra Deploy',
    assetPath: 'assets/images/creatures/rare/MAS01_firemask.png',
  ),
  _FamilyInfo(
    id: 'Horn',
    name: 'Horn',
    role: 'Frontline Tank',
    description: 'Bulky guardians that hold the line.',
    bestPowerups: 'Transmute (HP/def), Extra Deploy, Empower Special',
    assetPath: 'assets/images/creatures/rare/HOR01_firehorn.png',
  ),
  _FamilyInfo(
    id: 'Wing',
    name: 'Wing',
    role: 'Agile Ranged DPS',
    description:
        'Fast fliers that shred from a distance. Excel at focusing down priorities and kiting elite threats.',
    bestPowerups: 'Speed & Int Transmute, Empower Special',
    assetPath: 'assets/images/creatures/legendary/WIN01_firewing.png',
  ),

  _FamilyInfo(
    id: 'Kin',
    name: 'Kin',
    role: 'Healer & Support',
    description:
        'Restores your orb and allies, with powerful team-wide surges at higher ranks.',
    bestPowerups: 'Int/Beauty Transmute, Empower Heal',
    assetPath: 'assets/images/creatures/legendary/KIN01_firekin.png',
  ),

  // _FamilyInfo(
  //   id: 'Mystic',
  //   name: 'Mystic',
  //   role: 'Orbital Sustain',
  //   description:
  //       'Orbiting projectiles and lifesteal fields that keep your frontline alive while dealing chip damage.',
  //   bestPowerups: 'Int/Speed Transmute, Empower Orbitals',
  //   assetPath: 'assets/alchemons/families/mystic.png',
  // ),
];
