// Add this as a new widget class at the bottom of nursery_tab.dart:

import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:flutter/material.dart';

class ExtractionDialog extends StatefulWidget {
  final IncubatorSlot slot;
  final Color primaryColor;
  final bool isUndiscovered;
  final bool showAirPredict;
  final VoidCallback onExtract;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;

  const ExtractionDialog({
    required this.slot,
    required this.primaryColor,
    required this.isUndiscovered,
    required this.showAirPredict,
    required this.onExtract,
    required this.onDiscard,
    required this.onCancel,
  });

  @override
  State<ExtractionDialog> createState() => ExtractionDialogState();
}

class ExtractionDialogState extends State<ExtractionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<String>? _extractParentTypes() {
    try {
      if (widget.slot.payloadJson == null || widget.slot.payloadJson!.isEmpty) {
        return null;
      }
      final payload =
          jsonDecode(widget.slot.payloadJson!) as Map<String, dynamic>;
      final parentage = payload['parentage'] as Map<String, dynamic>?;

      if (parentage != null) {
        final parent1 = parentage['parentA'] as Map<String, dynamic>?;
        final parent2 = parentage['parentB'] as Map<String, dynamic>?;

        final types = <String>[];

        if (parent1 != null) {
          final p1Types = parent1['types'] as List<dynamic>?;
          if (p1Types != null && p1Types.isNotEmpty) {
            types.add(p1Types.first.toString());
          }
        }

        if (parent2 != null) {
          final p2Types = parent2['types'] as List<dynamic>?;
          if (p2Types != null && p2Types.isNotEmpty) {
            types.add(p2Types.first.toString());
          }
        }

        return types.isNotEmpty ? types : null;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parentTypes = _extractParentTypes();
    final rarityColor = BreedConstants.getRarityColor(
      widget.slot.rarity ?? 'common',
    );

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sacred Geometry Animation Container
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        // Particle system background
                        if (parentTypes != null && parentTypes.isNotEmpty)
                          Positioned.fill(
                            child: AlchemyBrewingParticleSystem(
                              parentATypeId: parentTypes[0],
                              parentBTypeId: parentTypes.length > 1
                                  ? parentTypes[1]
                                  : null,
                              particleCount: 60,
                              speedMultiplier: 0.2,
                              fusion: true, // Show fusion animation
                            ),
                          ),

                        // Glow overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Rarity Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: rarityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: rarityColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    'Ready to extract',
                    style: TextStyle(
                      color: rarityColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Undiscovered badge (Air faction only)
                if (widget.showAirPredict && widget.isUndiscovered) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.teal.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 16,
                          color: Colors.teal.shade300,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'UNDISCOVERED',
                          style: TextStyle(
                            color: Colors.teal.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Extract Button
                    _buildActionButton(
                      'EXTRACT',
                      Icons.biotech_rounded,
                      Colors.green,
                      widget.onExtract,
                      isPrimary: true,
                    ),
                    const SizedBox(width: 12),
                    // Cancel Button
                    _buildActionButton(
                      'CANCEL',
                      Icons.close_rounded,
                      Colors.grey,
                      widget.onCancel,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Discard Button (smaller, destructive)
                TextButton.icon(
                  onPressed: widget.onDiscard,
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Discard Specimen',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isPrimary ? 24 : 20,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isPrimary ? color.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(isPrimary ? 0.3 : 0.5),
            width: 2,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
