// lib/widgets/wilderness/encounter_action_dialog.dart
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum EncounterAction { breed, capture }

class EncounterActionDialog extends StatefulWidget {
  final Creature wildCreature;
  final WildEncounter encounter;
  final List<PartyMember> party;
  final double breedChance;

  const EncounterActionDialog({
    super.key,
    required this.wildCreature,
    required this.encounter,
    required this.party,
    required this.breedChance,
  });

  static Future<EncounterAction?> show(
    BuildContext context, {
    required Creature wildCreature,
    required WildEncounter encounter,
    required List<PartyMember> party,
    required double breedChance,
  }) {
    return showDialog<EncounterAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EncounterActionDialog(
        wildCreature: wildCreature,
        encounter: encounter,
        party: party,
        breedChance: breedChance,
      ),
    );
  }

  @override
  State<EncounterActionDialog> createState() => _EncounterActionDialogState();
}

class _EncounterActionDialogState extends State<EncounterActionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  Map<CatchDeviceType, int> _availableDevices = {};
  bool _loadingDevices = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();

    _loadAvailableDevices();
  }

  Future<void> _loadAvailableDevices() async {
    final catchService = context.read<CatchService>();
    final usableDevices = await catchService.getUsableDevices(
      widget.wildCreature,
    );
    final deviceMap = <CatchDeviceType, int>{};

    for (final device in usableDevices) {
      final qty = await catchService.getDeviceCount(device);
      if (qty > 0) {
        deviceMap[device] = qty;
      }
    }

    if (mounted) {
      setState(() {
        _availableDevices = deviceMap;
        _loadingDevices = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 60 : 40,
          vertical: 24,
        ),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? 900 : 500,
              maxHeight: size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.accent.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(theme),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        if (isLandscape)
                          _buildLandscapeLayout(theme)
                        else
                          _buildPortraitLayout(theme),
                        const SizedBox(height: 20),
                        _buildFleeButton(theme),
                      ],
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

  Widget _buildLandscapeLayout(FactionTheme theme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildBreedOption(theme)),
          const SizedBox(width: 16),
          Expanded(child: _buildCatchOption(theme)),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(FactionTheme theme) {
    return Column(
      children: [
        _buildBreedOption(theme),
        const SizedBox(height: 12),
        _buildCatchOption(theme),
      ],
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.accent.withOpacity(0.3), width: 1),
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.wildCreature.name.toUpperCase(),
            style: TextStyle(
              color: theme.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your approach:',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreedOption(FactionTheme theme) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, EncounterAction.breed),
      child: Container(
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'BREED',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Attempt crossbreeding with your party',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Success:',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(widget.breedChance * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatchOption(FactionTheme theme) {
    if (_loadingDevices) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.textMuted.withOpacity(0.3), width: 2),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_availableDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.textMuted.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, color: theme.textMuted, size: 32),
            const SizedBox(height: 12),
            Text(
              'No compatible harvesters',
              style: TextStyle(
                color: theme.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Visit the shop to purchase devices',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.pop(context, EncounterAction.capture),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CAPTURE',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use a harvesting device',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ..._buildDeviceList(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDeviceList(FactionTheme theme) {
    return _availableDevices.entries.map((entry) {
      final catchService = context.read<CatchService>();
      final chance = catchService.calculateCatchChance(
        entry.key,
        widget.encounter.rarity,
      );

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key.label,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'x${entry.value}',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(chance * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFleeButton(FactionTheme theme) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.textMuted.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app_rounded, color: theme.textMuted, size: 16),
            const SizedBox(width: 8),
            Text(
              'Back',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor() {
    switch (widget.encounter.rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return Colors.green;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.amber;
      default:
        return Colors.white;
    }
  }
}
