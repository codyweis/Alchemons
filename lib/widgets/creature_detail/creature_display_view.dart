import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_background_pref.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// Full-screen viewer that enlarges a creature sprite and lets the user pick a
/// background. The picked bg can be persisted for this species (all instances)
/// or for this specific captured instance.
class CreatureDisplayView extends StatefulWidget {
  final Creature creature;
  final CreatureInstance? instance;
  final CreatureBgOption initialBg;

  const CreatureDisplayView({
    super.key,
    required this.creature,
    this.instance,
    this.initialBg = defaultCreatureBg,
  });

  /// Returns the saved option, or null if the user closed without saving.
  static Future<CreatureBgOption?> show(
    BuildContext context, {
    required Creature creature,
    CreatureInstance? instance,
    CreatureBgOption initialBg = defaultCreatureBg,
  }) {
    return showDialog<CreatureBgOption>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => CreatureDisplayView(
        creature: creature,
        instance: instance,
        initialBg: initialBg,
      ),
    );
  }

  @override
  State<CreatureDisplayView> createState() => _CreatureDisplayViewState();
}

class _CreatureDisplayViewState extends State<CreatureDisplayView> {
  late CreatureBgOption _selected = widget.initialBg;
  bool _saving = false;
  CreatureBgOption? _savedOption;
  String? _savedMsg;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final hasInstance = widget.instance != null;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CreatureBgLayer(option: _selected),
            Center(child: _buildSprite(size)),
            Positioned(
              top: padding.top + 8,
              right: 8,
              child: _CloseButton(
                onTap: () => Navigator.of(context).pop(_savedOption),
              ),
            ),
            if (_savedMsg != null)
              Positioned(
                top: padding.top + 14,
                left: 0,
                right: 0,
                child: Center(child: _SavedToast(message: _savedMsg!)),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: padding.bottom + 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SaveButtonsRow(
                    hasInstance: hasInstance,
                    saving: _saving,
                    onSaveSpecies: _saveSpecies,
                    onSaveInstance: hasInstance ? _saveInstance : null,
                  ),
                  const SizedBox(height: 10),
                  _BackgroundPicker(
                    options: creatureBgOptions,
                    selectedId: _selected.id,
                    onSelect: (option) => setState(() => _selected = option),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSpecies() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = context.read<AlchemonsDatabase>();
      await saveCreatureBgForSpecies(
        db,
        baseId: widget.creature.id,
        option: _selected,
      );
      _savedOption = _selected;
      _flashSavedMessage('Saved for all ${widget.creature.name}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveInstance() async {
    if (_saving) return;
    final instance = widget.instance;
    if (instance == null) return;
    setState(() => _saving = true);
    try {
      final db = context.read<AlchemonsDatabase>();
      await saveCreatureBgForInstance(
        db,
        instanceId: instance.instanceId,
        option: _selected,
      );
      _savedOption = _selected;
      _flashSavedMessage('Saved for this one');
      if (!mounted) return;
      Navigator.of(context).pop(_savedOption);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _flashSavedMessage(String msg) {
    setState(() => _savedMsg = msg);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _savedMsg = null);
    });
  }

  Widget _buildSprite(Size screen) {
    final sprite = widget.creature.spriteData;
    if (sprite == null) return const SizedBox.shrink();

    final maxSide = (screen.shortestSide * 0.78).clamp(220.0, 520.0);

    if (widget.instance != null) {
      return SizedBox(
        width: maxSide,
        height: maxSide,
        child: InstanceSprite(
          creature: widget.creature,
          instance: widget.instance!,
          size: maxSide,
        ),
      );
    }

    return SizedBox(
      width: maxSide,
      height: maxSide,
      child: CreatureSprite(
        spritePath: sprite.spriteSheetPath,
        totalFrames: sprite.totalFrames,
        rows: sprite.rows,
        frameSize: Vector2(
          sprite.frameWidth.toDouble(),
          sprite.frameHeight.toDouble(),
        ),
        stepTime: sprite.frameDurationMs / 1000.0,
        scale: scaleFromGenes(widget.creature.genetics),
        saturation: satFromGenes(widget.creature.genetics),
        brightness: briFromGenes(widget.creature.genetics),
        hueShift: hueFromGenes(widget.creature.genetics),
        isPrismatic: widget.creature.isPrismaticSkin,
      ),
    );
  }
}

class _BackgroundPicker extends StatelessWidget {
  final List<CreatureBgOption> options;
  final String selectedId;
  final ValueChanged<CreatureBgOption> onSelect;

  const _BackgroundPicker({
    required this.options,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final option = options[i];
          return CreatureBgSwatch(
            option: option,
            selected: option.id == selectedId,
            onTap: () => onSelect(option),
          );
        },
      ),
    );
  }
}

class _SaveButtonsRow extends StatelessWidget {
  final bool hasInstance;
  final bool saving;
  final VoidCallback onSaveSpecies;
  final VoidCallback? onSaveInstance;

  const _SaveButtonsRow({
    required this.hasInstance,
    required this.saving,
    required this.onSaveSpecies,
    required this.onSaveInstance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _SaveButton(
              label: 'Save for species',
              enabled: !saving,
              onTap: onSaveSpecies,
            ),
          ),
          if (hasInstance) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _SaveButton(
                label: 'Save for this one',
                enabled: !saving,
                onTap: onSaveInstance ?? () {},
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SaveButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedToast extends StatelessWidget {
  final String message;
  const _SavedToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.check_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: const Icon(
          AppIcons.close_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
