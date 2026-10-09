import 'package:flutter/material.dart';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

import 'cosmic_screen_styles.dart';

/// The departure confirmation, asked the way every leave/exit question is
/// ([showBracketConfirm]).
///
/// Two shapes: when something is unbanked it is red and lists what is lost
/// with the amounts on board; when the hold is empty it is quiet and says
/// nothing is lost. The old version warned in both cases, which taught
/// players to ignore it.
Future<bool> showLeaveExpeditionConfirm(
  BuildContext context, {
  required double cargoUnits,
  required Map<String, double> cargoBreakdown,
  required int unbankedShards,
  required int? bankedShards,
}) {
  final details = LeaveExpeditionDetails(
    cargoUnits: cargoUnits,
    cargoBreakdown: cargoBreakdown,
    unbankedShards: unbankedShards,
    bankedShards: bankedShards,
  );
  return showBracketConfirm(
    context,
    palette: BracketPalette.dark,
    accent: details.atRisk ? kLeaveDangerAccent : kLeaveQuietAccent,
    title: 'LEAVE EXPEDITION?',
    message: details.message,
    details: details.atRisk ? details : null,
    cancelLabel: 'STAY',
    confirmLabel: 'LEAVE',
  );
}

/// What leaving costs, itemised, and what it keeps. Shown under the
/// question only when something is unbanked.
class LeaveExpeditionDetails extends StatelessWidget {
  const LeaveExpeditionDetails({
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

  static const _palette = BracketPalette.dark;

  bool get _hasCargo => cargoUnits >= 0.5;
  bool get _hasShards => unbankedShards > 0;
  bool get atRisk => _hasCargo || _hasShards;

  String get message => atRisk
      ? 'Anything still in the hold is lost.'
      : 'The hold is empty, so nothing is lost. Everything is saved for '
            'when you return.';

  @override
  Widget build(BuildContext context) {
    final sorted = cargoBreakdown.entries.where((e) => e.value >= 0.5).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = sorted.take(3).toList();
    final rest = sorted.length - shown.length;

    final kept = bankedShards == null
        ? 'Element stores'
        : 'Element stores, the home vault (${formatCoins(bankedShards!)} '
              'shards)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(context, 'LOST'),
        const SizedBox(height: 8),
        if (_hasShards)
          _lossRow(
            context,
            tint: CosmicScreenStyles.astralShardColor,
            headline: '${formatCoins(unbankedShards)} unbanked Astral Shards',
            detail: 'Carried in the ship wallet, never deposited.',
          ),
        if (_hasShards && _hasCargo) const SizedBox(height: 10),
        if (_hasCargo)
          _lossRow(
            context,
            tint: CosmicScreenStyles.teal,
            headline:
                '${cargoUnits.round()} of '
                '${ElementMeter.maxCapacity.round()} cargo units',
            detail: 'Never reaches your element stores or your planet.',
            parts: [
              for (final e in shown)
                (
                  isKnownElement(e.key)
                      ? '${e.key} ${e.value.round()}'
                      : '${e.value.round()}',
                  elementInk(e.key),
                ),
              if (rest > 0) ('+$rest more', _palette.muted),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          bankedShards == null
              ? 'Nothing can be banked until you build a home planet from '
                    'the ship console.'
              : 'Fly home and DEPOSIT ALL first to keep it.',
          style: bracketText(context, 12, _palette.muted),
        ),
        const SizedBox(height: 14),
        _label(context, 'KEPT'),
        const SizedBox(height: 8),
        Text(
          '$kept, your home planet, star charts and dust, ship upgrades, '
          'fuel, ammo and your party.',
          style: bracketText(context, 12, _palette.muted),
          strutStyle: const StrutStyle(height: 1.35),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            color: _palette.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _palette.lineSoft)),
      ],
    );
  }

  /// One loss: a small mark in its color, what it is, and where it went.
  Widget _lossRow(
    BuildContext context, {
    required Color tint,
    required String headline,
    required String detail,
    List<(String, Color)> parts = const [],
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(width: 6, height: 6, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: bracketText(
                  context,
                  13,
                  _palette.ink,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(detail, style: bracketText(context, 11.5, _palette.muted)),
              if (parts.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    for (final (text, color) in parts)
                      Text(
                        text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
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
}
