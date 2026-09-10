import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/widgets/chronal_catalyst_glyph.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The countdown on a running Chronal Catalyst.
///
/// A boost the player cannot see is a boost they will not believe in, and
/// this one is invisible by nature — it changes a number on a screen they are
/// not looking at when they start a cultivation. So it gets a clock, and the
/// clock explains itself when tapped.
///
/// Absent entirely when nothing is running, rather than greyed out: the
/// header is crowded and an inert chip is worse than no chip.
class HalfCultivationChip extends StatefulWidget {
  const HalfCultivationChip({super.key});

  @override
  State<HalfCultivationChip> createState() => _HalfCultivationChipState();
}

class _HalfCultivationChipState extends State<HalfCultivationChip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // One second is the smallest unit the label shows. Started only while a
    // boost is live — see the build's early return.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      context.read<TimedBoostService>().pruneExpired();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// "23h 41m" while there is a while to go, "41m 12s" once it is close —
  /// seconds are noise at the top of a day and the whole point at the end.
  static String formatRemaining(Duration left) {
    final h = left.inHours;
    final m = left.inMinutes.remainder(60);
    final s = left.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final boosts = context.watch<TimedBoostService>();
    if (!boosts.halfCultivationActive) return const SizedBox.shrink();
    final theme = context.watch<FactionTheme>();
    final left = boosts.halfCultivationRemaining;
    const accent = Color(0xFF7BE1E8);

    return GestureDetector(
      onTap: context.soundAction(() => _explain(context, left)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.55),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.hourglass_bottom_rounded,
              size: 13,
              color: accent,
            ),
            const SizedBox(width: 5),
            Text(
              formatRemaining(left),
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _explain(BuildContext context, Duration left) {
    final theme = context.read<FactionTheme>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        title: Row(
          children: [
            // The same glyph the shop sells it with, so the countdown in the
            // header and the item on the shelf are recognisably one thing.
            const ChronalCatalystGlyph(size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chronal Catalyst',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: theme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Every cultivation you start right now takes half as long.\n\n'
          'It runs for ${formatRemaining(left)} more, and it keeps running '
          'while the app is closed. Cultivations already under way keep the '
          'time they were given when they started.',
          style: TextStyle(
            fontFamily: appFontFamily(context),
            color: theme.textMuted,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: context.soundAction(() => Navigator.of(ctx).pop()),
            child: Text(
              'Got it',
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: theme.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
