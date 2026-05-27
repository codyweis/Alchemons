// lib/widgets/wilderness/device_selection_dialog.dart
import 'package:alchemons/constants/design_tokens.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// Resolves the shop artwork for a harvester device via its inventory key.
String? _harvesterAsset(CatchDeviceType device) {
  for (final offer in ShopService.allOffers) {
    if (offer.inventoryKey == device.inventoryKey) return offer.assetName;
  }
  return null;
}

// Capture dialog renders over dark scene backdrops — always dark.
const _palette = BracketPalette.dark;
const _amber = Color(0xFFE4C16A);
const _success = Color(0xFF22C55E);

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
      if (qty > 0) deviceMap[device] = qty;
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
        child: CustomPaint(
          painter: BracketFramePainter(
            color: _amber.withValues(alpha: 0.85),
            bracketSize: 13,
            strokeWidth: 1.35,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? 800 : 500,
              maxHeight: size.height * 0.9,
            ),
            color: _palette.surfaceFill(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      color: _amber,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Flexible(
                    child: isLandscape
                        ? _buildLandscapeDeviceGrid()
                        : _buildPortraitDeviceList(),
                  ),
                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: _palette.bg0,
        border: Border(
          bottom: BorderSide(color: _palette.lineSoft.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 30, color: _amber),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select harvester',
                  style: bracketText(
                    context,
                    16,
                    _palette.ink,
                    weight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose a device to capture the specimen.',
                  style: bracketText(
                    context,
                    11.5,
                    _palette.muted,
                    weight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          _PickerCloseButton(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeDeviceGrid() {
    if (_availableDevices.isEmpty) return _buildEmptyState();
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
                child: _buildDeviceCard(entry.key, entry.value),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildPortraitDeviceList() {
    if (_availableDevices.isEmpty) return _buildEmptyState();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _availableDevices.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildDeviceCard(entry.key, entry.value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.inventory_2_outlined,
            color: _palette.muted,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'No compatible devices',
            style: bracketText(
              context,
              13,
              _palette.ink,
              weight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Purchase harvesters from the shop to stock your field kit.',
            style: bracketText(
              context,
              12,
              _palette.muted,
              weight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(CatchDeviceType device, int quantity) {
    final catchService = context.read<CatchService>();
    final chance = catchService.calculateCatchChance(device, widget.rarity);
    final isGuaranteed = device == CatchDeviceType.guaranteed;
    final accent = isGuaranteed ? _amber : _success;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context, device);
      },
      child: CustomPaint(
        painter: BracketFramePainter(
          color: accent.withValues(alpha: 0.75),
          bracketSize: 8,
          strokeWidth: 1.1,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            border: Border.all(
              color: _palette.lineSoft.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _DeviceThumb(device: device, accent: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.label,
                          style: bracketText(
                            context,
                            13,
                            _palette.ink,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Owned · $quantity',
                          style: bracketText(
                            context,
                            11,
                            _palette.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AppIcons.chevron_right_rounded,
                    color: accent,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                color: _palette.bg0.withValues(alpha: 0.6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CAPTURE RATE',
                      style: bracketText(
                        context,
                        10,
                        _palette.muted,
                        weight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (!isGuaranteed)
                      Text(
                        '${(chance * 100).toStringAsFixed(0)}%',
                        style: bracketText(
                          context,
                          12,
                          _success,
                          weight: FontWeight.w800,
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(
                            AppIcons.check_circle_rounded,
                            color: _amber,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'GUARANTEED',
                            style: bracketText(
                              context,
                              10,
                              _amber,
                              weight: FontWeight.w800,
                              letterSpacing: 0.6,
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
      ),
    );
  }

  Widget _buildCancelButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _palette.bg0,
        border: Border(
          top: BorderSide(color: _palette.lineSoft.withValues(alpha: 0.7)),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: BracketFramePainter(
            color: _palette.line.withValues(alpha: 0.7),
            bracketSize: 8,
            strokeWidth: 1.1,
          ),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            color: _palette.surfaceMutedFill(),
            child: Text(
              'Cancel',
              style: bracketText(
                context,
                13,
                _palette.muted,
                weight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading thumbnail for a harvester card — uses the shop artwork when
/// available, falling back to a device icon.
class _DeviceThumb extends StatelessWidget {
  const _DeviceThumb({required this.device, required this.accent});

  final CatchDeviceType device;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final asset = _harvesterAsset(device);
    final isGuaranteed = device == CatchDeviceType.guaranteed;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _palette.bg0,
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(3),
      child: asset != null
          ? Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Icon(
                isGuaranteed
                    ? AppIcons.shield_rounded
                    : AppIcons.catching_pokemon_rounded,
                color: accent,
                size: 20,
              ),
            )
          : Icon(
              isGuaranteed
                  ? AppIcons.shield_rounded
                  : AppIcons.catching_pokemon_rounded,
              color: accent,
              size: 20,
            ),
    );
  }
}

class _PickerCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PickerCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: _palette.line.withValues(alpha: 0.7),
          bracketSize: 6,
          strokeWidth: 1,
        ),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          color: _palette.surfaceMutedFill(),
          child: Icon(
            AppIcons.close_rounded,
            color: _palette.muted,
            size: AppIcon.sm,
          ),
        ),
      ),
    );
  }
}
