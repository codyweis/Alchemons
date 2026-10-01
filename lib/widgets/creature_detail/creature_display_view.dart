import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/creature_background_pref.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Full-screen viewer: the creature large on a backdrop of the player's
/// choosing, saved for this one specimen or for every one of its species.
/// Tapping the creature plays its elemental essence, as on its details.
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

  /// Saving for this specimen only, rather than its whole species. Only a
  /// specimen can be saved for on its own.
  late bool _forInstance = widget.instance != null;
  bool _saving = false;

  /// White and grey want dark chrome over them, and a shadow, not a glow,
  /// under the creature.
  bool get _lightBackdrop =>
      _selected.kind == CreatureBgKind.color &&
      _selected.color.computeLuminance() > 0.35;

  String get _displayName {
    final nick = widget.instance?.nickname?.trim();
    return nick != null && nick.isNotEmpty ? nick : widget.creature.name;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final accent = bracketReadableAccent(theme);
    // What sits over the backdrop follows the backdrop, not the app theme:
    // parchment ink over space, dark ink over white.
    final over = _lightBackdrop ? BracketPalette.light : BracketPalette.dark;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              // Filled: a plain colour has no size of its own, and the
              // switcher's default layout would shrink it to nothing.
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: CreatureBgLayer(
                key: ValueKey(_selected.id),
                option: _selected,
              ),
            ),
            // A soft fall-off top and bottom, so the chrome reads on any
            // backdrop without boxing the creature in.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      over.bg0.withValues(alpha: _lightBackdrop ? 0.45 : 0.7),
                      over.bg0.withValues(alpha: 0),
                      over.bg0.withValues(alpha: 0),
                      over.bg0.withValues(alpha: _lightBackdrop ? 0.3 : 0.55),
                    ],
                    stops: const [0, 0.16, 0.6, 1],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _Header(
                  name: _displayName,
                  subtitle: [
                    if (_displayName != widget.creature.name)
                      widget.creature.name,
                    ...widget.creature.types.take(2),
                  ].join('  ·  '),
                  palette: over,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(child: Center(child: _buildStage(size))),
                _BackdropPanel(
                  palette: palette,
                  accent: accent,
                  selected: _selected,
                  speciesName: widget.creature.name,
                  hasInstance: widget.instance != null,
                  forInstance: _forInstance,
                  saving: _saving,
                  onSelect: (o) => setState(() => _selected = o),
                  onScope: (v) => setState(() => _forInstance = v),
                  onSave: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStage(Size screen) {
    final sprite = widget.creature.spriteData;
    if (sprite == null) return const SizedBox.shrink();
    final side = (screen.shortestSide * 0.74).clamp(220.0, 500.0);
    final light = _lightBackdrop;

    final Widget body = widget.instance != null
        ? InstanceSprite(
            creature: widget.creature,
            instance: widget.instance!,
            size: side,
          )
        : CreatureSprite(
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
          );

    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Somewhere to stand: a soft pool at its feet, light on a dark
          // backdrop and shadow on a pale one. Never a ring.
          Positioned(
            left: side * 0.12,
            right: side * 0.12,
            top: side * 0.78,
            height: side * 0.16,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      (light ? Colors.black : Colors.white).withValues(
                        alpha: light ? 0.16 : 0.08,
                      ),
                      (light ? Colors.black : Colors.white).withValues(
                        alpha: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ElementalEssence(
            element: widget.creature.types.isEmpty
                ? null
                : widget.creature.types.first,
            dark: !light,
            maxGrains: 3000,
            child: body,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = context.read<AlchemonsDatabase>();
      final instance = widget.instance;
      if (_forInstance && instance != null) {
        await saveCreatureBgForInstance(
          db,
          instanceId: instance.instanceId,
          option: _selected,
        );
      } else {
        await saveCreatureBgForSpecies(
          db,
          baseId: widget.creature.id,
          option: _selected,
        );
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(_selected);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String subtitle;
  final BracketPalette palette;
  final VoidCallback onClose;

  const _Header({
    required this.name,
    required this.subtitle,
    required this.palette,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      20,
                      palette.ink,
                      weight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: context.soundAction(onClose),
              child: CustomPaint(
                painter: BracketFramePainter(
                  color: palette.line.withValues(alpha: 0.9),
                  bracketSize: 8,
                ),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  color: palette.chromeMutedFill(),
                  child: Icon(
                    AppIcons.close_rounded,
                    color: palette.muted,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chrome at the bottom: the backdrops, who the choice is for, and save.
class _BackdropPanel extends StatelessWidget {
  final BracketPalette palette;
  final Color accent;
  final CreatureBgOption selected;
  final String speciesName;
  final bool hasInstance;
  final bool forInstance;
  final bool saving;
  final ValueChanged<CreatureBgOption> onSelect;
  final ValueChanged<bool> onScope;
  final VoidCallback onSave;

  const _BackdropPanel({
    required this.palette,
    required this.accent,
    required this.selected,
    required this.speciesName,
    required this.hasInstance,
    required this.forInstance,
    required this.saving,
    required this.onSelect,
    required this.onScope,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.chromeFill(),
        border: Border(
          top: BorderSide(color: palette.line.withValues(alpha: 0.55)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      'BACKDROP',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: palette.line.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      selected.label,
                      style: bracketText(
                        context,
                        13,
                        palette.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: creatureBgOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 2),
                  itemBuilder: (context, i) {
                    final option = creatureBgOptions[i];
                    return CreatureBgTile(
                      option: option,
                      selected: option.id == selected.id,
                      onTap: () => onSelect(option),
                      accent: accent,
                      labelColor: palette.ink,
                      mutedColor: palette.muted,
                      lineColor: palette.line,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasInstance) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _ScopeChoice(
                              label: 'THIS ONE',
                              selected: forInstance,
                              palette: palette,
                              accent: accent,
                              onTap: () => onScope(true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ScopeChoice(
                              label: 'EVERY ${speciesName.toUpperCase()}',
                              selected: !forInstance,
                              palette: palette,
                              accent: accent,
                              onTap: () => onScope(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    _SaveButton(
                      label: saving
                          ? 'SAVING…'
                          : hasInstance
                          ? 'SAVE BACKDROP'
                          : 'SAVE FOR EVERY ${speciesName.toUpperCase()}',
                      enabled: !saving,
                      palette: palette,
                      accent: accent,
                      onTap: onSave,
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

class _ScopeChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback onTap;

  const _ScopeChoice({
    required this.label,
    required this.selected,
    required this.palette,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected ? accent : palette.line.withValues(alpha: 0.6),
          bracketSize: 7,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: selected
              ? palette.accentWash(accent, darkAlpha: 0.16, lightAlpha: 0.1)
              : Colors.transparent,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              color: selected ? palette.ink : palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback onTap;

  const _SaveButton({
    required this.label,
    required this.enabled,
    required this.palette,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(enabled ? onTap : null),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent,
            bracketSize: 10,
            strokeWidth: 1.3,
          ),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: palette.accentWash(accent, darkAlpha: 0.2, lightAlpha: 0.12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.check_rounded, size: 15, color: accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
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
}
