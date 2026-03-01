// lib/widgets/wilderness/device_selection_dialog.dart
import 'package:alchemons/models/creature.dart';
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
    final t = ForgeTokens(context.watch<FactionTheme>());
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
            color: t.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: t.borderAccent, width: 1),
            boxShadow: [
              BoxShadow(
                color: t.amber.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(t),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(
                    color: t.amber,
                    strokeWidth: 2,
                  ),
                )
              else
                Flexible(
                  child: isLandscape
                      ? _buildLandscapeDeviceGrid(t)
                      : _buildPortraitDeviceList(t),
                ),
              _buildCancelButton(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ForgeTokens t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: t.bg2,
        border: Border(bottom: BorderSide(color: t.borderDim)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: t.amber, shape: BoxShape.circle),
          ),
          Text(
            'SELECT HARVESTER',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeDeviceGrid(ForgeTokens t) {
    if (_availableDevices.isEmpty) return _buildEmptyState(t);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const itemWidth = 240.0;
          const spacing = 10.0;
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
                child: _buildDeviceCard(t, entry.key, entry.value),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildPortraitDeviceList(ForgeTokens t) {
    if (_availableDevices.isEmpty) return _buildEmptyState(t);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _availableDevices.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildDeviceCard(t, entry.key, entry.value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(ForgeTokens t) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, color: t.borderAccent, size: 36),
          const SizedBox(height: 12),
          Text(
            'NO COMPATIBLE DEVICES',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Purchase harvesters from the shop',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textMuted,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ForgeTokens t, CatchDeviceType device, int quantity) {
    final catchService = context.read<CatchService>();
    final chance = catchService.calculateCatchChance(device, widget.rarity);
    final isGuaranteed = device == CatchDeviceType.guaranteed;
    final accentColor = isGuaranteed ? t.amberBright : t.success;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context, device);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: t.bg2,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(
                    isGuaranteed
                        ? Icons.shield_rounded
                        : Icons.catching_pokemon_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'OWNED  $quantity',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textMuted, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: t.borderDim),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isGuaranteed ? 'CAPTURE RATE' : 'CAPTURE RATE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (!isGuaranteed)
                    Text(
                      '${(chance * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: t.amberBright,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'GUARANTEED',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.amberBright,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton(ForgeTokens t) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.bg2,
          border: Border(top: BorderSide(color: t.borderDim)),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
        ),
        child: Text(
          'CANCEL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            color: t.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
