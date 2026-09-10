import 'package:flutter/material.dart';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/widgets/app_icons.dart';

import 'cosmic_screen_styles.dart';

/// The departure confirmation.
///
/// Two shapes, one widget: a red manifest of what the hold is about to spill
/// when something is unbanked, and a quiet all-clear when it isn't. The old
/// version warned in both cases, which taught players to ignore it.
class LeaveExpeditionDialog extends StatelessWidget {
  const LeaveExpeditionDialog({
    super.key,
    required this.cargoUnits,
    required this.cargoBreakdown,
    required this.unbankedShards,
    required this.bankedShards,
  });

  /// Meter contents, in the meter's own units (out of [ElementMeter.maxCapacity]).
  final double cargoUnits;
  final Map<String, double> cargoBreakdown;
  final int unbankedShards;

  /// Home planet vault balance, or null when there is no home planet yet.
  final int? bankedShards;

  bool get _hasCargo => cargoUnits >= 0.5;
  bool get _hasShards => unbankedShards > 0;
  bool get _atRisk => _hasCargo || _hasShards;

  static String _grouped(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _atRisk
        ? CosmicScreenStyles.danger
        : CosmicScreenStyles.amber;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CosmicScreenStyles.bg3,
                CosmicScreenStyles.bg1,
                CosmicScreenStyles.bg0,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: accent.withValues(alpha: 0.62),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, accent),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: CosmicScreenStyles.borderMid.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              if (_atRisk) ...[
                _manifest(context),
                const SizedBox(height: 10),
              ],
              _safeNote(context),
              const SizedBox(height: 16),
              _actions(context, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Color accent) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.11),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
          ),
          child: Icon(
            _atRisk
                ? AppIcons.warning_amber_rounded
                : AppIcons.logout_rounded,
            color: accent,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LEAVE EXPEDITION?',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _atRisk ? 'THE HOLD IS STILL LOADED' : 'THE HOLD IS EMPTY',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: accent.withValues(alpha: 0.82),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// What departure actually costs, itemised with the amounts on board.
  Widget _manifest(BuildContext context) {
    final sorted = cargoBreakdown.entries.where((e) => e.value >= 0.5).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = sorted.take(3).toList();
    final rest = sorted.length - shown.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: CosmicScreenStyles.danger.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPILLED INTO THE VOID',
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: CosmicScreenStyles.danger,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 9),
          if (_hasShards)
            _lossRow(
              context,
              icon: CosmicScreenStyles.astralShardIcon,
              tint: CosmicScreenStyles.astralShardColor,
              headline: '${_grouped(unbankedShards)} unbanked Astral Shards',
              detail: 'Carried in the ship wallet, never deposited.',
            ),
          if (_hasShards && _hasCargo) const SizedBox(height: 8),
          if (_hasCargo)
            _lossRow(
              context,
              icon: AppIcons.science_rounded,
              tint: CosmicScreenStyles.teal,
              headline:
                  '${cargoUnits.round()} of '
                  '${ElementMeter.maxCapacity.round()} cargo units',
              detail: 'Never reaches your element stores or your planet.',
              chips: [
                for (final e in shown)
                  if (isKnownElement(e.key))
                    '${e.key} ${e.value.round()}'
                  else
                    '${e.value.round()}',
                if (rest > 0) '+$rest more',
              ],
              chipTints: [
                for (final e in shown) elementInk(e.key),
                if (rest > 0) CosmicScreenStyles.textMuted,
              ],
            ),
          const SizedBox(height: 10),
          Text(
            bankedShards == null
                ? 'Nothing can be banked until you build a home planet from '
                      'the ship console.'
                : 'Fly home and DEPOSIT ALL first to keep any of it.',
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: CosmicScreenStyles.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lossRow(
    BuildContext context, {
    required IconData icon,
    required Color tint,
    required String headline,
    required String detail,
    List<String> chips = const [],
    List<Color> chipTints = const [],
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            border: Border.all(color: tint.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: tint, size: 14),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textMuted,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < chips.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CosmicScreenStyles.bg0.withValues(alpha: 0.7),
                          border: Border.all(
                            color: chipTints[i].withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          chips[i],
                          style: TextStyle(
                            fontFamily: appFontFamily(context),
                            color: chipTints[i],
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The reassurance half — the list of things leaving does *not* cost.
  Widget _safeNote(BuildContext context) {
    final vault = bankedShards == null
        ? 'your element stores'
        : 'your element stores, the home vault '
              '(${_grouped(bankedShards!)} shards)';
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.check_circle_rounded,
            color: CosmicScreenStyles.success.withValues(alpha: 0.85),
            size: 15,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STAYS BANKED',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: CosmicScreenStyles.success.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _atRisk
                      ? 'Everything else is saved: $vault, your home planet, '
                            'star charts and dust, ship upgrades, fuel, ammo '
                            'and your party.'
                      : 'Nothing is at risk. $vault, your home planet, star '
                            'charts and dust, ship upgrades, fuel, ammo and '
                            'your party are all saved and waiting when you '
                            'return.',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: CosmicScreenStyles.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Color accent) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: context.soundAction(
              () => Navigator.of(context).pop(false),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: CosmicScreenStyles.bg2.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: CosmicScreenStyles.borderMid),
              ),
              child: Text(
                'STAY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: context.soundAction(() => Navigator.of(context).pop(true)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.logout_rounded, color: accent, size: 15),
                  const SizedBox(width: 7),
                  Text(
                    'LEAVE',
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
