// lib/widgets/animations/loot_open_popup.dart
//
// A loot box opened from the inventory. The rewards gather into their rows
// out of grains of their own color (reward_reveal.dart) — the same arrival
// as the end of a survival run. A tap anywhere brings them all in at once.

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/reward_reveal.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

export 'package:alchemons/widgets/animations/reward_reveal.dart'
    show LootOpeningEntry, RewardArt, showRewardDetail;

Future<void> showLootOpeningDialog({
  required BuildContext context,
  required List<LootOpeningEntry> entries,
  String title = 'REWARDS',
  FactionTheme? theme,
}) async {
  if (entries.isEmpty) return;
  final dialogTheme = theme ?? context.read<FactionTheme>();
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, __) => Provider<FactionTheme>.value(
      value: dialogTheme,
      child: Theme(
        data: dialogTheme.toMaterialTheme(Theme.of(context).textTheme),
        child: _LootDialog(entries: entries, title: title),
      ),
    ),
  );
}

class _LootDialog extends StatefulWidget {
  const _LootDialog({required this.entries, required this.title});

  final List<LootOpeningEntry> entries;
  final String title;

  @override
  State<_LootDialog> createState() => _LootDialogState();
}

class _LootDialogState extends State<_LootDialog>
    with SingleTickerProviderStateMixin {
  static const _delay = Duration(milliseconds: 250);

  final _reveal = GlobalKey<RewardRevealState>();
  late final AnimationController _collect = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    // COLLECT comes up as the last reward is settling.
    final arrive =
        _delay + RewardReveal.lengthFor(widget.entries.length) * 0.75;
    Future.delayed(arrive, () {
      if (mounted) _collect.forward();
    });
  }

  @override
  void dispose() {
    _collect.dispose();
    super.dispose();
  }

  void _finish() {
    _reveal.currentState?.finish();
    _collect.forward();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ForgeTokens(context.read<FactionTheme>());
    const palette = BracketPalette.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _finish,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: tokens.amberBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: palette.lineSoft),
                    const SizedBox(height: 10),
                    Text(
                      'TAP FOR DETAILS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    RewardReveal(
                      key: _reveal,
                      entries: widget.entries,
                      delay: _delay,
                      onTap: (e) => showRewardDetail(context, e),
                    ),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _collect,
                      child: BracketButton(
                        label: 'COLLECT',
                        palette: palette,
                        accent: tokens.amberBright,
                        height: 50,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
