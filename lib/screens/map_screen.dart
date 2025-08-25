// lib/screens/map_screen.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/screens/party_picker.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_access_service.dart';
import 'package:alchemons/widgets/wilderness/countdown_badge.dart';
import 'package:flutter/material.dart';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/screens/scenes/scene_page.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildPartyStatus(context),
            Expanded(child: _buildExpeditionsList(context)),
            _buildFooterInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        border: Border(bottom: BorderSide(color: Colors.indigo[200]!)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.indigo[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.indigo[600],
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breeding Expeditions',
                  style: TextStyle(
                    color: Colors.indigo[800],
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Discover wild creatures and breed with your party',
                  style: TextStyle(
                    color: Colors.indigo[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.indigo[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.explore_rounded,
              color: Colors.indigo[600],
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyStatus(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green[100]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.groups_rounded,
              color: Colors.green[600],
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breeding Team Status',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Select your party for wild creature breeding missions',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.green[400],
            size: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildExpeditionsList(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final access = WildernessAccessService(db);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breeding Grounds',
            style: TextStyle(
              color: Colors.indigo[700],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // --- Mystic Valley (valley) ---
          FutureBuilder<bool>(
            future: access.canEnter('valley'),
            builder: (context, snap) {
              final available = snap.data ?? true;

              // Card with a badge overlay when locked
              return Stack(
                children: [
                  _ExpeditionCard(
                    title: 'Mystic Valley Breeding Ground',
                    subtitle: 'Common & Uncommon Forest Creatures',
                    description:
                        'Lush woodland habitat home to gentle forest creatures. Perfect for beginners…',
                    difficulty: 'Beginner',
                    expectedRewards: const [
                      'Forest Offspring',
                      'Herb Materials',
                      'Basic Breeding XP',
                    ],
                    icon: Icons.eco_rounded,
                    statusColor: Colors.green,
                    isAvailable: available,
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
          // --- Volcano Expedition (volcano) ---
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
                    statusColor: Colors.red,
                    isAvailable: available,
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
          _ExpeditionCard(
            title: 'Desert Mirage Oasis',
            subtitle: 'Legendary Fire & Sun Creatures',
            description:
                'Scorching desert oasis where legendary fire-type creatures gather. Only the most skilled breeders can handle these powerful wild mons.',
            difficulty: 'Expert',
            expectedRewards: [
              'Legendary Offspring',
              'Solar Crystals',
              'Master Breeding XP',
            ],
            icon: Icons.wb_sunny_rounded,
            statusColor: Colors.orange,
            onTap: () =>
                _showUnavailable(context, 'Oasis location being tracked'),
            isAvailable: false,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey[600], size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Breeding grounds refresh daily at 00:00 UTC. Party selection required for all breeding missions.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
      final use = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('LandExplorer'),
          content: const Text(
            'Use today’s instant refresh to reopen this ground?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
      if (use == true) {
        // If your service lacks this, implement it to clear the daily gate
        await access.refreshWilderness(biomeId);
        await factions.earthMarkRefreshedToday(biomeId);

        _showCustomSnackBar(
          context,
          'LandExplorer activated: breeding ground refreshed',
          Icons.forest_rounded,
          Colors.green.shade600,
        );
        ok = true;
      }
    }
    if (!ok) {
      final left = access.timeUntilReset();
      final hh = left.inHours;
      final mm = left.inMinutes.remainder(60);
      final ss = left.inSeconds.remainder(60);
      _showCustomSnackBar(
        context,
        'Breeding ground refreshes in ${hh}h ${mm}m ${ss}s',
        Icons.schedule_rounded,
        Colors.orange[600]!,
      );
      return;
    }

    // Pick party
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

  void _showUnavailable(BuildContext context, String reason) {
    _showCustomSnackBar(
      context,
      reason,
      Icons.construction_rounded,
      Colors.amber[600]!,
    );
  }

  void _showCustomSnackBar(
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
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAvailable
              ? Colors.white.withOpacity(0.95)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable ? statusColor[200]! : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: statusColor[100]!,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAvailable ? statusColor[50] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isAvailable ? statusColor[600] : Colors.grey[500],
                    size: 20,
                  ),
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
                              style: TextStyle(
                                color: isAvailable
                                    ? statusColor[800]
                                    : Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _buildDifficultyBadge(),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isAvailable
                              ? statusColor[600]
                              : Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAvailable)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: statusColor,
                      size: 14,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.grey[500],
                      size: 14,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              description,
              style: TextStyle(
                color: isAvailable ? Colors.grey[700] : Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            // Expected rewards section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expected Research Yields',
                  style: TextStyle(
                    color: isAvailable ? Colors.indigo[700] : Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.grey[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: expectedRewards.map((reward) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? statusColor[100]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isAvailable
                                ? statusColor[200]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          reward,
                          style: TextStyle(
                            color: isAvailable
                                ? statusColor[700]
                                : Colors.grey[500],
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge() {
    MaterialColor badgeColor;
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        badgeColor = Colors.green;
        break;
      case 'advanced':
        badgeColor = Colors.orange;
        break;
      case 'expert':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAvailable ? badgeColor[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAvailable ? badgeColor[300]! : Colors.grey[300]!,
        ),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: isAvailable ? badgeColor[700] : Colors.grey[500],
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
