// lib/widgets/wilderness/device_selection_dialog.dart
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class DeviceSelectionDialog extends StatefulWidget {
  final Creature wildCreature;
  final String rarity;

  const DeviceSelectionDialog({
    super.key,
    required this.wildCreature,
    required this.rarity,
  });

  static Future<CatchDeviceType?> show(
    BuildContext context, {
    required Creature wildCreature,
    required String rarity,
  }) {
    return showDialog<CatchDeviceType>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          DeviceSelectionDialog(wildCreature: wildCreature, rarity: rarity),
    );
  }

  @override
  State<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<DeviceSelectionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  Map<CatchDeviceType, int> _availableDevices = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();

    _loadDevices();
  }

  Future<void> _loadDevices() async {
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
        _loading = false;
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

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 80 : 40,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 800 : 500,
            maxHeight: size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E27).withOpacity(0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Colors.green),
                )
              else
                Flexible(
                  child: isLandscape
                      ? _buildLandscapeDeviceGrid(theme)
                      : _buildPortraitDeviceList(theme),
                ),
              _buildCancelButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.green.withOpacity(0.3), width: 1),
        ),
      ),
      child: Text(
        'Choose which harvester to use',
        style: TextStyle(
          color: theme.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLandscapeDeviceGrid(FactionTheme theme) {
    if (_availableDevices.isEmpty) {
      return _buildEmptyState(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate number of columns based on available width
          final itemWidth = 240.0;
          final spacing = 12.0;
          final crossAxisCount = (constraints.maxWidth / (itemWidth + spacing))
              .floor()
              .clamp(2, 4);

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: _availableDevices.entries.map((entry) {
              return SizedBox(
                width:
                    (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
                    crossAxisCount,
                child: _buildDeviceCard(theme, entry.key, entry.value),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildPortraitDeviceList(FactionTheme theme) {
    if (_availableDevices.isEmpty) {
      return _buildEmptyState(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _availableDevices.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDeviceCard(theme, entry.key, entry.value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, color: theme.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No compatible devices',
            style: TextStyle(
              color: theme.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Purchase harvesters from the shop',
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

  Widget _buildDeviceCard(
    FactionTheme theme,
    CatchDeviceType device,
    int quantity,
  ) {
    final catchService = context.read<CatchService>();
    final chance = catchService.calculateCatchChance(device, widget.rarity);
    final isGuaranteed = device == CatchDeviceType.guaranteed;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context, device);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isGuaranteed
              ? Colors.amber.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isGuaranteed
                ? Colors.amber.withOpacity(0.6)
                : Colors.green.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon + Device name + quantity
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isGuaranteed
                        ? Colors.amber.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isGuaranteed
                        ? Icons.shield_rounded
                        : Icons.catching_pokemon_rounded,
                    color: isGuaranteed ? Colors.amber : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.label,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Owned: $quantity',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Capture chance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isGuaranteed
                    ? Colors.amber.withOpacity(0.15)
                    : Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isGuaranteed ? 'Guaranteed' : 'Capture Chance:',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!isGuaranteed)
                    Text(
                      '${(chance * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton(FactionTheme theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.textMuted.withOpacity(0.2), width: 1),
          ),
        ),
        child: Text(
          'CANCEL',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
