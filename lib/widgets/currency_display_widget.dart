// lib/widgets/currency_display_widget.dart
//
// What the player holds, live: the shared bracket purse (CoinPurse) fed from
// the currency table. It replaced a pair of bevelled gradient pills that
// folded to abbreviations on tap — the last currency on screen that did not
// read the same as the market's and the exchange's.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CurrencyDisplayWidget extends StatefulWidget {
  const CurrencyDisplayWidget({super.key, this.fill});

  /// Behind the figures; the palette's surface when left out.
  final Color? fill;

  @override
  State<CurrencyDisplayWidget> createState() => _CurrencyDisplayWidgetState();
}

class _CurrencyDisplayWidgetState extends State<CurrencyDisplayWidget> {
  // Held, so a rebuild of the screen around it does not open a new query.
  late final Stream<Map<String, int>> _currencies = context
      .read<AlchemonsDatabase>()
      .currencyDao
      .watchAllCurrencies();

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return StreamBuilder<Map<String, int>>(
      stream: _currencies,
      builder: (context, snap) {
        final c = snap.data ?? const {'gold': 0, 'silver': 0};
        return CoinPurse(
          gold: c['gold'] ?? 0,
          silver: c['silver'] ?? 0,
          palette: palette,
          fill: widget.fill,
        );
      },
    );
  }
}
