// lib/widgets/trade/trade_origin.dart
//
// Who an Alchemon came from, in words, for wherever its origin is shown:
// "Traded to you by Sam · Oct 11, 2026", and the owner it began with when
// that was someone else; "Fused with Sam · Oct 12, 2026" for one two
// friends fused.

import 'package:alchemons/models/trade.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Oct 11, 2026, in local time.
String tradeDate(int utcMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true).toLocal();
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// [p] as lines of its origin. [owner]: whose it is now, by name, or null
/// for the player's own.
List<String> tradeOriginLines(TradeProvenance? p, {String? owner}) {
  if (p == null) return const [];
  final last = p.last;
  final fused = p.fused;
  return [
    if (fused != null)
      last == null
          ? 'Fused with ${fused.withName} · ${tradeDate(fused.atMs)}'
          : 'Fused by ${fused.byName} and ${fused.withName} · '
                '${tradeDate(fused.atMs)}',
    if (last != null) ...[
      'Traded to ${owner ?? 'you'} by ${last.fromName} · '
          '${tradeDate(last.atMs)}',
      if (p.steps.length > 1 && p.firstName != last.fromName)
        'First owner: ${p.firstName}',
    ],
  ];
}
