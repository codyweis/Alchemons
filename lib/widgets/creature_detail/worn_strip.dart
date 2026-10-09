// lib/widgets/creature_detail/worn_strip.dart
//
// WHAT IT WEARS: one row on both details views — its alchemy effect, drawn
// and named and lit from below while worn, then one plus that opens the
// costumes it fits (worn costumes show on the sprite itself).
//
// It replaced two text rows ("Effect · None · none owned ›", "Costumes · …")
// that said the same thing in words and showed nothing.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/utils/alchemy_effect_apply.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/costume/costume_color_sheet.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/inventory_item_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class WornStrip extends StatelessWidget {
  const WornStrip({
    super.key,
    required this.instance,
    required this.creatureName,
    this.onChanged,
    this.height = 54,
  });

  final CreatureInstance instance;
  final String creatureName;

  /// After something goes on or comes off, for a host that holds its own
  /// copy of the instance rather than watching it.
  final VoidCallback? onChanged;

  final double height;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final palette = BracketPalette.of(context);
    final accent = bracketReadableAccent(context.read<FactionTheme>());
    final fitted = [
      for (final costume in FamilyCostume.values)
        if (costume.fits(instance.baseId)) costume,
    ];
    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        final owned = <String, int>{
          for (final item in snapshot.data ?? const <InventoryItem>[])
            if (item.qty > 0) item.key: item.qty,
        };
        final effects = [
          for (final e in owned.entries)
            if (InvKeys.alchemyEffectFor(e.key) != null &&
                // Costumes have a square of their own.
                FamilyCostume.ofItem(e.key) == null)
              e,
        ];
        final worn = WornCostumes.on(instance.baseId, instance.costumes);
        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _EffectTile(
                  instance: instance,
                  creatureName: creatureName,
                  owned: effects,
                  palette: palette,
                  accent: accent,
                  onChanged: onChanged,
                ),
              ),
              if (fitted.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _CostumesTile(
                    instance: instance,
                    creatureName: creatureName,
                    fitted: fitted,
                    worn: worn,
                    owned: {for (final c in fitted) c: owned[c.itemKey] ?? 0},
                    palette: palette,
                    accent: accent,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The fill and light every square shares: lit from below when worn.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.lit,
    required this.palette,
    required this.accent,
    required this.onTap,
    required this.child,
  });

  final bool lit;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : context.soundAction(() {
              HapticFeedback.selectionClick();
              onTap!();
            }),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: lit ? accent : palette.line,
          strokeWidth: 1.2,
        ),
        child: Container(
          color: lit
              ? palette.accentWash(accent, darkAlpha: 0.12)
              : palette.surfaceMutedFill(),
          child: child,
        ),
      ),
    );
  }
}

// ── The effect ──────────────────────────────────────────────────────────────

class _EffectTile extends StatelessWidget {
  const _EffectTile({
    required this.instance,
    required this.creatureName,
    required this.owned,
    required this.palette,
    required this.accent,
    required this.onChanged,
  });

  final CreatureInstance instance;
  final String creatureName;
  final List<MapEntry<String, int>> owned;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final registry = buildInventoryRegistry(context.read<AlchemonsDatabase>());
    final wornKey = InvKeys.alchemyItemFor(instance.alchemyEffect);
    final wornName = wornKey == null ? null : registry[wornKey]?.name;
    final count = owned.fold(0, (a, e) => a + e.value);
    // A worn effect can always be opened, to swap it or take it off.
    final canPick = owned.isNotEmpty || wornKey != null;
    return LayoutBuilder(
      builder: (context, box) {
        final art = box.maxHeight - 12;
        return _Slot(
          lit: wornKey != null,
          palette: palette,
          accent: accent,
          onTap: canPick
              ? () => _pick(context, registry, wornKey, wornName)
              : () => showGameSnack(
                  context,
                  'No effects owned. The shop sells them under Cosmetics.',
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                // Nothing owned: no empty box, the words say it.
                if (wornKey != null || owned.isNotEmpty) ...[
                  SizedBox.square(
                    dimension: art,
                    child: wornKey != null
                        ? InventoryItemArtwork(inventoryKey: wornKey, size: art)
                        : Icon(
                            AppIcons.add_rounded,
                            size: 20,
                            color: palette.muted,
                          ),
                  ),
                  const SizedBox(width: 8),
                ] else
                  const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count > 0 ? 'EFFECT · $count OWNED' : 'EFFECT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: palette.muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wornName ?? (owned.isEmpty ? 'None owned' : 'None'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bracketText(
                          context,
                          13,
                          wornName != null ? palette.ink : palette.muted,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pick(
    BuildContext context,
    Map<String, InventoryItemDef> registry,
    String? wornKey,
    String? wornName,
  ) async {
    // An item key to apply, or the empty string to take the worn one off.
    const takeOff = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetCtx) => _EffectSheet(
        creatureName: creatureName,
        owned: owned,
        registry: registry,
        wornKey: wornKey,
        wornName: wornName,
        palette: palette,
        accent: accent,
        onPick: (key) => Navigator.of(sheetCtx).pop(key),
        onTakeOff: () => Navigator.of(sheetCtx).pop(takeOff),
      ),
    );
    if (picked == null || !context.mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final String message;
    if (picked == takeOff) {
      await removeAlchemyEffect(db, instanceId: instance.instanceId);
      message = 'Returned ${wornName ?? 'the effect'} to your inventory';
    } else {
      if (!await applyAlchemyEffect(
        db,
        instanceId: instance.instanceId,
        itemKey: picked,
      )) {
        return;
      }
      message = 'Applied ${registry[picked]?.name ?? 'the effect'}';
    }
    onChanged?.call();
    if (context.mounted) showGameSnack(context, message);
  }
}

class _EffectSheet extends StatelessWidget {
  const _EffectSheet({
    required this.creatureName,
    required this.owned,
    required this.registry,
    required this.wornKey,
    required this.wornName,
    required this.palette,
    required this.accent,
    required this.onPick,
    required this.onTakeOff,
  });

  final String creatureName;
  final List<MapEntry<String, int>> owned;
  final Map<String, InventoryItemDef> registry;
  final String? wornKey, wornName;
  final BracketPalette palette;
  final Color accent;
  final ValueChanged<String> onPick;
  final VoidCallback onTakeOff;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final cards = [
      if (wornKey != null) (wornKey!, 0, true),
      for (final e in owned)
        if (e.key != wornKey) (e.key, e.value, false),
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EFFECT · ${creatureName.toUpperCase()}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: palette.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              if (wornName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Applying another returns $wornName to your inventory.',
                  style: bracketText(context, 12, palette.muted),
                ),
              ],
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 8.0;
                  final across = box.maxWidth >= 420 ? 4 : 3;
                  final w = (box.maxWidth - gap * (across - 1)) / across;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final (key, qty, worn) in cards)
                        SizedBox(
                          width: w,
                          child: _Slot(
                            lit: worn,
                            palette: palette,
                            accent: accent,
                            onTap: worn ? null : () => onPick(key),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: Column(
                                children: [
                                  InventoryItemArtwork(
                                    inventoryKey: key,
                                    size: 52,
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 30,
                                    child: Text(
                                      registry[key]?.name ?? key,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: bracketText(
                                        context,
                                        11.5,
                                        palette.ink,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    worn ? 'WORN' : '×$qty',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: worn ? accent : palette.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (wornKey != null) ...[
                const SizedBox(height: 14),
                BracketButton(
                  label: 'TAKE OFF',
                  onTap: onTakeOff,
                  palette: palette,
                  accent: accent,
                  primary: false,
                  height: 42,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── The costumes ────────────────────────────────────────────────────────────

/// One plus for every costume it fits: what it wears shows on the sprite,
/// so the square only opens the list. Lit while it wears any.
class _CostumesTile extends StatelessWidget {
  const _CostumesTile({
    required this.instance,
    required this.creatureName,
    required this.fitted,
    required this.worn,
    required this.owned,
    required this.palette,
    required this.accent,
    required this.onChanged,
  });

  final CreatureInstance instance;
  final String creatureName;
  final List<FamilyCostume> fitted;
  final WornCostumes worn;
  final Map<FamilyCostume, int> owned;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final wearing = fitted.any(worn.wears);
    final any = wearing || owned.values.any((n) => n > 0);
    return _Slot(
      lit: wearing,
      palette: palette,
      accent: accent,
      onTap: any
          ? () => _open(context)
          : () => showGameSnack(
              context,
              'No costumes owned. The shop sells them under Cosmetics.',
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Icon(
              AppIcons.add_rounded,
              size: 20,
              color: wearing ? palette.ink : palette.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COSTUMES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: palette.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wearing
                        ? '${fitted.where(worn.wears).length} worn'
                        : (any ? 'None' : 'None owned'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      13,
                      wearing ? palette.ink : palette.muted,
                      weight: FontWeight.w700,
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

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<(_CostumeAction, FamilyCostume)>(
      context: context,
      backgroundColor: palette.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetCtx) {
        void pop(_CostumeAction a, FamilyCostume c) =>
            Navigator.of(sheetCtx).pop((a, c));
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'COSTUMES · ${creatureName.toUpperCase()}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Worn beside its effect, all at once if you like.',
                  style: bracketText(sheetCtx, 12, palette.muted),
                ),
                const SizedBox(height: 12),
                for (final costume in fitted) ...[
                  _CostumeRow(
                    costume: costume,
                    wearing: worn.wears(costume),
                    color: worn.colorOf(costume),
                    owned: owned[costume] ?? 0,
                    palette: palette,
                    accent: accent,
                    onAction: (a) => pop(a, costume),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    final (act, costume) = picked;
    final db = context.read<AlchemonsDatabase>();
    final String message;
    switch (act) {
      case _CostumeAction.off:
        if (!await takeOffCostume(
          db,
          instanceId: instance.instanceId,
          costume: costume,
        )) {
          return;
        }
        message = 'Returned ${costume.title} to your inventory';
      case _CostumeAction.wear || _CostumeAction.recolor:
        final recolor = act == _CostumeAction.recolor;
        final color = await pickCostumeColor(
          context,
          instance: instance,
          costume: costume,
          confirmLabel: recolor
              ? 'SAVE COLOR'
              : 'WEAR ${costume.noun.toUpperCase()}',
        );
        if (color == null || !context.mounted) return;
        if (!await wearCostume(
          db,
          instanceId: instance.instanceId,
          costume: costume,
          color: color,
        )) {
          return;
        }
        final noun = costume.noun;
        message = recolor
            ? '${noun[0].toUpperCase()}${noun.substring(1)} color saved'
            : 'Wearing ${costume.title}';
    }
    onChanged?.call();
    if (context.mounted) showGameSnack(context, message);
  }
}

enum _CostumeAction { wear, recolor, off }

/// One costume in the list: what it is, and what can be done with it.
class _CostumeRow extends StatelessWidget {
  const _CostumeRow({
    required this.costume,
    required this.wearing,
    required this.color,
    required this.owned,
    required this.palette,
    required this.accent,
    required this.onAction,
  });

  final FamilyCostume costume;
  final bool wearing;
  final Color color;
  final int owned;
  final BracketPalette palette;
  final Color accent;
  final ValueChanged<_CostumeAction> onAction;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, _CostumeAction a, {bool primary = true}) =>
        BracketButton(
          label: label,
          onTap: () => onAction(a),
          palette: palette,
          accent: accent,
          primary: primary,
          height: 34,
        );
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: wearing ? accent : palette.line,
        strokeWidth: 1.2,
      ),
      child: Container(
        color: wearing
            ? palette.accentWash(accent, darkAlpha: 0.12)
            : palette.surfaceMutedFill(),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 44,
              child: CostumeGlyph(
                costume: costume,
                color: wearing ? color : null,
                opacity: wearing || owned > 0 ? 1 : 0.35,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // The shop's long names don't fit beside the buttons.
                    '${costume.noun[0].toUpperCase()}${costume.noun.substring(1)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      13.5,
                      wearing || owned > 0 ? palette.ink : palette.muted,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    wearing
                        ? 'Wearing'
                        : owned > 0
                        ? '×$owned owned'
                        : 'None owned',
                    style: bracketText(context, 11.5, palette.muted),
                  ),
                ],
              ),
            ),
            if (wearing) ...[
              button('COLOR', _CostumeAction.recolor),
              const SizedBox(width: 6),
              button('TAKE OFF', _CostumeAction.off, primary: false),
            ] else if (owned > 0)
              button('WEAR', _CostumeAction.wear),
          ],
        ),
      ),
    );
  }
}

/// A costume on its own, still, in [color] (its own when null).
class CostumeGlyph extends StatelessWidget {
  const CostumeGlyph({
    super.key,
    required this.costume,
    this.color,
    this.opacity = 1,
  });

  final FamilyCostume costume;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _CostumeGlyphPainter(costume, color, opacity)),
  );
}

class _CostumeGlyphPainter extends CustomPainter {
  _CostumeGlyphPainter(this.costume, this.color, this.opacity);

  final FamilyCostume costume;
  final Color? color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // The nose is a small bead on a card made for a whole face; on its
    // own square it is drawn up to read beside the hat and the glasses.
    final r =
        size.shortestSide / 2 * (costume == FamilyCostume.nose ? 1.5 : 0.86);
    CostumePaint.paintPreview(
      canvas,
      costume,
      size.center(Offset.zero),
      r,
      0,
      opacity: opacity,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_CostumeGlyphPainter old) =>
      old.costume != costume || old.color != color || old.opacity != opacity;
}
