import 'dart:ui';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/screens/party_picker.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_access_service.dart';
import 'package:alchemons/widgets/glowing_icon.dart';
import 'package:alchemons/widgets/wilderness/countdown_badge.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/screens/scenes/scene_page.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final (primaryColor, _, accentColor) = getFactionColors(currentFaction);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0B0F14).withOpacity(0.96),
              const Color(0xFF0B0F14).withOpacity(0.92),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(accentColor),
              _buildPartyStatus(accentColor),
              Expanded(child: _buildExpeditionsList(accentColor)),
              _buildFooterInfo(accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _IconButton(
                icon: Icons.arrow_back_rounded,
                accentColor: accentColor,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BREEDING EXPEDITIONS',
                      style: _TextStyles.headerTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Discover wild creatures and breed with your party',
                      style: _TextStyles.headerSubtitle,
                    ),
                  ],
                ),
              ),
              GlowingIcon(
                icon: Icons.explore_rounded,
                color: accentColor,
                controller: _glowController,
                dialogTitle: "Breeding Expeditions",
                dialogMessage:
                    "Venture into diverse biomes to discover and research wild creatures. When encountering a wild creature, you can choose one member of your party to attempt to breed with it. Successfully breeding, will create an offspring to be extracted in the Incubator.",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyStatus(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _GlassContainer(
        accentColor: Colors.green.shade400,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.green.shade400.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.shade400.withOpacity(0.5),
                  ),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: Colors.green.shade400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Breeding Team Status', style: _TextStyles.labelText),
                    const SizedBox(height: 2),
                    Text(
                      'Select your party for breeding missions',
                      style: _TextStyles.hint,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.green.shade400,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpeditionsList(Color accentColor) {
    final db = context.read<AlchemonsDatabase>();
    final access = WildernessAccessService(db);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Breeding Grounds', style: _TextStyles.sectionTitle),
          ),

          // Mystic Valley
          FutureBuilder<bool>(
            future: access.canEnter('valley'),
            builder: (context, snap) {
              final available = snap.data ?? true;
              return Stack(
                children: [
                  _ExpeditionCard(
                    title: 'Mystic Valley Breeding Ground',
                    subtitle: 'Common & Uncommon Forest Creatures',
                    description:
                        'Lush woodland habitat home to gentle forest creatures. Perfect for beginners.',
                    difficulty: 'Beginner',
                    expectedRewards: const [
                      'Forest Offspring',
                      'Herb Materials',
                      'Basic Breeding XP',
                    ],
                    icon: Icons.eco_rounded,
                    statusColor: Colors.green,
                    isAvailable: available,
                    glowController: _glowController,
                    onTap: () =>
                        _onExpeditionTap(context, 'valley', valleyScene),
                  ),
                  if (!available)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: CountdownBadge(remaining: access.timeUntilReset),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Volcano Expedition
          FutureBuilder<bool>(
            future: access.canEnter('volcano'),
            builder: (context, snap) {
              final available = snap.data ?? true;
              return Stack(
                children: [
                  _ExpeditionCard(
                    title: 'Volcano Breeding Ground',
                    subtitle: 'Rare Fire & Earth Creatures',
                    description:
                        'A fiery volcanic landscape home to some of the rarest fire and earth-type creatures. Suitable for experienced breeders.',
                    difficulty: 'Advanced',
                    expectedRewards: const [
                      'Volcanic Offspring',
                      'Rare Minerals',
                      'Advanced Breeding XP',
                    ],
                    icon: Icons.whatshot_rounded,
                    statusColor: Colors.orange,
                    isAvailable: available,
                    glowController: _glowController,
                    onTap: () =>
                        _onExpeditionTap(context, 'volcano', volcanoScene),
                  ),
                  if (!available)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: CountdownBadge(remaining: access.timeUntilReset),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Swamp Expedition
          FutureBuilder<bool>(
            future: access.canEnter('swamp'),
            builder: (context, snap) {
              final available = snap.data ?? true;
              return Stack(
                children: [
                  _ExpeditionCard(
                    title: 'Swamp Breeding Ground',
                    subtitle: 'Uncommon & Rare Water Creatures',
                    description:
                        'Misty swamp habitat teeming with unique water-type creatures. Ideal for intermediate breeders.',
                    difficulty: 'Intermediate',
                    expectedRewards: const [
                      'Swamp Offspring',
                      'Rare Herbs',
                      'Intermediate Breeding XP',
                    ],
                    icon: Icons.water_rounded,
                    statusColor: Colors.blue,
                    isAvailable: available,
                    glowController: _glowController,
                    onTap: () => _onExpeditionTap(context, 'swamp', swampScene),
                  ),
                  if (!available)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: CountdownBadge(remaining: access.timeUntilReset),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // --- Sky Expedition (sky) ---
          FutureBuilder<bool>(
            future: access.canEnter('sky'),
            builder: (context, snap) {
              final available = snap.data ?? true;

              return Stack(
                children: [
                  _ExpeditionCard(
                    title: 'Sky Breeding Ground',
                    subtitle: 'Rare Air Creatures',
                    description:
                        'A high-altitude habitat filled with unique air-type creatures. Ideal for advanced breeders.',
                    difficulty: 'Advanced',
                    expectedRewards: const [
                      'Sky Offspring',
                      'Rare Clouds',
                      'Advanced Breeding XP',
                    ],
                    icon: Icons.cloud_rounded,
                    statusColor: Colors.blue,
                    isAvailable: available,
                    glowController: _glowController,
                    onTap: () => _onExpeditionTap(context, 'sky', skyScene),
                  ),
                  if (!available)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: CountdownBadge(remaining: access.timeUntilReset),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(Color accentColor) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            border: Border(
              top: BorderSide(color: accentColor.withOpacity(0.35)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: _TextStyles.mutedText,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Breeding grounds refresh daily at 00:00 UTC.',
                  style: _TextStyles.footerText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onExpeditionTap(
    BuildContext context,
    String biomeId,
    SceneDefinition scene,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final access = WildernessAccessService(db);
    final factions = context.read<FactionService>();

    var ok = await access.canEnter(biomeId);
    if (!ok && await factions.earthCanRefreshToday(biomeId)) {
      final use = await _showRefreshDialog(context);
      if (use == true) {
        await access.refreshWilderness(biomeId);
        await factions.earthMarkRefreshedToday(biomeId);

        if (!context.mounted) return;
        _showToast(
          context,
          'LandExplorer activated: breeding ground refreshed',
          Icons.forest_rounded,
          Colors.green.shade400,
        );
        ok = true;
      }
    }
    if (!ok) {
      final left = access.timeUntilReset();
      final hh = left.inHours;
      final mm = left.inMinutes.remainder(60);
      final ss = left.inSeconds.remainder(60);
      if (!context.mounted) return;
      _showToast(
        context,
        'Breeding ground refreshes in ${hh}h ${mm}m ${ss}s',
        Icons.schedule_rounded,
        Colors.orange.shade400,
      );
      return;
    }

    // Pick party
    if (!context.mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PartyPickerPage()),
    );

    if (result == null) return;

    final List<PartyMember> selectedParty = (result as List)
        .cast<PartyMember>();

    await access.markEntered(biomeId);

    // Go to the scene
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScenePage(scene: scene, party: selectedParty),
      ),
    );
  }

  Future<bool?> _showRefreshDialog(BuildContext context) {
    return showDialog<bool>(context: context, builder: (_) => _RefreshDialog());
  }

  void _showToast(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ==================== REUSABLE COMPONENTS ====================

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final AnimationController glowController;

  const _GlassContainer({
    required this.child,
    required this.accentColor,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedBuilder(
          animation: glowController,
          builder: (context, _) {
            final glow = 0.35 + glowController.value * 0.4;
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(glow * 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glow * 0.5),
                    blurRadius: 20 + glowController.value * 14,
                  ),
                ],
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(.35)),
        ),
        child: Icon(icon, color: _TextStyles.softText, size: 18),
      ),
    );
  }
}

class _ExpeditionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final String difficulty;
  final List<String> expectedRewards;
  final IconData icon;
  final MaterialColor statusColor;
  final VoidCallback onTap;
  final bool isAvailable;
  final AnimationController glowController;

  const _ExpeditionCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.difficulty,
    required this.expectedRewards,
    required this.icon,
    required this.statusColor,
    required this.onTap,
    required this.isAvailable,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isAvailable ? statusColor.shade400 : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedBuilder(
            animation: glowController,
            builder: (context, _) {
              final glow = isAvailable
                  ? 0.35 + glowController.value * 0.4
                  : 0.2;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(isAvailable ? 0.14 : 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cardColor.withOpacity(glow * 0.85),
                    width: 1.5,
                  ),
                  boxShadow: isAvailable
                      ? [
                          BoxShadow(
                            color: cardColor.withOpacity(glow * 0.5),
                            blurRadius: 20 + glowController.value * 14,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                cardColor.withOpacity(isAvailable ? 0.3 : 0.15),
                                Colors.transparent,
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardColor.withOpacity(
                                isAvailable ? 0.5 : 0.3,
                              ),
                            ),
                          ),
                          child: Icon(icon, color: cardColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: isAvailable
                                          ? _TextStyles.cardTitle
                                          : _TextStyles.cardTitleDisabled,
                                    ),
                                  ),
                                  _DifficultyBadge(
                                    difficulty: difficulty,
                                    isAvailable: isAvailable,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: isAvailable
                                    ? _TextStyles.cardSubtitle
                                    : _TextStyles.cardSubtitleDisabled,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(
                              isAvailable ? 0.15 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isAvailable
                                ? Icons.arrow_forward_rounded
                                : Icons.lock_rounded,
                            color: cardColor,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: isAvailable
                          ? _TextStyles.description
                          : _TextStyles.descriptionDisabled,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected Research Yields',
                          style: isAvailable
                              ? _TextStyles.rewardTitle
                              : _TextStyles.rewardTitleDisabled,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              isAvailable ? 0.04 : 0.02,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: expectedRewards.map((reward) {
                              return _RewardBadge(
                                text: reward,
                                color: statusColor,
                                isAvailable: isAvailable,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  final bool isAvailable;

  const _DifficultyBadge({required this.difficulty, required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAvailable
            ? badgeColor.withOpacity(0.2)
            : Colors.grey.shade700.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAvailable
              ? badgeColor.withOpacity(0.5)
              : Colors.grey.shade600.withOpacity(0.5),
        ),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: isAvailable ? badgeColor : Colors.grey.shade500,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getBadgeColor() {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green.shade400;
      case 'intermediate':
        return Colors.blue.shade400;
      case 'advanced':
        return Colors.orange.shade400;
      case 'expert':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }
}

class _RewardBadge extends StatelessWidget {
  final String text;
  final MaterialColor color;
  final bool isAvailable;

  const _RewardBadge({
    required this.text,
    required this.color,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isAvailable
            ? color.shade400.withOpacity(0.2)
            : Colors.grey.shade700.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAvailable
              ? color.shade400.withOpacity(0.5)
              : Colors.grey.shade600.withOpacity(0.5),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isAvailable ? color.shade400 : Colors.grey.shade500,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RefreshDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade400.withOpacity(0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forest_rounded,
                  color: Colors.green.shade400,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'LandExplorer',
                  style: TextStyle(
                    color: _TextStyles.softText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use today\'s instant refresh to reopen this ground?',
                  style: TextStyle(
                    color: _TextStyles.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.06),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                        ),
                        child: Text(
                          'Not now',
                          style: TextStyle(
                            color: _TextStyles.softText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Refresh',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

// ==================== TEXT STYLES ====================

class _TextStyles {
  static const softText = Color(0xFFE8EAED);
  static const mutedText = Color(0xFFB6C0CC);

  static const headerTitle = TextStyle(
    color: softText,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
  );

  static const headerSubtitle = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const sectionTitle = TextStyle(
    color: softText,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const labelText = TextStyle(
    color: softText,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const hint = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const cardTitle = TextStyle(
    color: softText,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  static const cardTitleDisabled = TextStyle(
    color: Color(0xFF7A8290),
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  static const cardSubtitle = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const cardSubtitleDisabled = TextStyle(
    color: Color(0xFF7A8290),
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const description = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const descriptionDisabled = TextStyle(
    color: Color(0xFF6A7380),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const rewardTitle = TextStyle(
    color: softText,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static const rewardTitleDisabled = TextStyle(
    color: Color(0xFF7A8290),
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static const footerText = TextStyle(
    color: mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}
