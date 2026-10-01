// lib/screens/black_market_screen.dart
//
// THE BLACK MARKET — a lamplit stall that opens at night.
//
// Two tabs over the stall's painting: BUY (the week's vials and deals) and
// SELL (elemental resources, two for a silver). Every surface is smoked glass
// in the bracket-frame language with the lamp's amber as its accent, so it
// reads as the same game as the details and the exchange, at night. It is
// always the dark palette: the painting is.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/debug_settings_service.dart';

class BlackMarketScreen extends StatefulWidget {
  final Color accent;

  const BlackMarketScreen({super.key, required this.accent});

  @override
  State<BlackMarketScreen> createState() => _BlackMarketScreenState();
}

/// The lamp's light: the market's one accent.
const Color _kLamp = Color(0xFFFFB74D);
const Color _kDanger = Color(0xFFE57373);

/// Night, whatever the app's theme: the stall is painted dark.
const BracketPalette _p = BracketPalette.dark;

/// Smoked glass over the painting.
const Color _kGlass = Color(0xD90B0A10);

Color _vialRarityColor(VialRarity r) => switch (r) {
  VialRarity.common => _p.muted,
  VialRarity.uncommon => const Color(0xFF34D399),
  VialRarity.rare => const Color(0xFF60A5FA),
  VialRarity.legendary => const Color(0xFFFFB020),
  VialRarity.mythic => const Color(0xFFE879F9),
};

/// A vial's price is in gold only at the top end (as the service prices it).
CoinKind _vialCoin(ExtractionVial vial) =>
    vial.rarity == VialRarity.legendary ? CoinKind.gold : CoinKind.silver;

/// Two resources fetch a silver; this matches the shop's resources-to-gold
/// rate (5,000 resources is 2,500 silver).
int _resourcePrice(int quantity) => quantity ~/ 2;

class _BlackMarketScreenState extends State<BlackMarketScreen> {
  /// Resource key -> how much of it is on the table.
  final Map<String, int> _selling = {};
  int _tab = 0; // 0 buy, 1 sell
  Timer? _clock;

  int get _cut =>
      _selling.values.fold(0, (sum, qty) => sum + _resourcePrice(qty));
  int get _sellingCount => _selling.values.fold(0, (sum, qty) => sum + qty);

  @override
  void initState() {
    super.initState();
    // The header counts down to closing and to the restock.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<BlackMarketService>();
    final canSell = context
        .watch<ConstellationEffectsService>()
        .canSellResources();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ui/blackmarket.png',
              fit: BoxFit.cover,
            ),
          ),
          // One pool of lamplight over the table; the room falls into
          // shadow, and the foot of the screen darkens under its controls.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.05,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(market),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: BracketTabs(
                    labels: const ['BUY', 'SELL'],
                    icons: const [
                      AppIcons.shopping_bag_rounded,
                      AppIcons.sell_rounded,
                    ],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                    palette: _p,
                    accent: _kLamp,
                  ),
                ),
                Expanded(
                  child: _tab == 0
                      ? _buildBuy(market)
                      : canSell
                      ? _buildSell()
                      : _buildLocked(),
                ),
                if (_tab == 1 && canSell) _buildSellFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────

  Widget _buildHeader(BlackMarketService market) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.chevron_left_rounded,
            palette: _p,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BLACK MARKET',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _p.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _hoursLine(market),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _kLamp.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _Purse(),
        ],
      ),
    );
  }

  static String _span(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}D';
    if (d.inHours >= 1) return '${d.inHours}H ${d.inMinutes % 60}M';
    return '${d.inMinutes.clamp(1, 59)}M';
  }

  /// When it shuts.
  String _hoursLine(BlackMarketService market) {
    final close = market.getTimeUntilClose();
    return close == Duration.zero
        ? 'OPEN ALL HOURS'
        : 'CLOSES IN ${_span(close)}';
  }

  /// When the stock turns over: Monday, local.
  static String _restockLine() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final restock = today.add(Duration(days: 8 - now.weekday));
    return 'RESTOCKS IN ${_span(restock.difference(now))}';
  }

  // ── buy ───────────────────────────────────────────────────────────────

  Widget _buildBuy(BlackMarketService market) {
    if (market.dailyOffers.isEmpty && market.dailyVials.isEmpty) {
      return _Notice(
        icon: AppIcons.schedule_rounded,
        title: 'Laying out the wares…',
        line: 'Give me a moment.',
      );
    }
    final vials = market.dailyVials;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        if (vials.isNotEmpty) ...[
          _SectionLabel("THIS WEEK'S VIALS", trailing: _restockLine()),
          const SizedBox(height: 10),
          for (var row = 0; row < vials.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: row + col < vials.length
                        ? _VialLot(
                            vial: vials[row + col],
                            sold: market.isPurchased(vials[row + col].id),
                            onOpen: () => _showVialDetails(vials[row + col]),
                            onBuy: () => _buyVial(vials[row + col], market),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 22),
        ],
        if (market.dailyOffers.isNotEmpty) ...[
          const _SectionLabel('DEALS'),
          const SizedBox(height: 10),
          for (final offer in market.dailyOffers) ...[
            _DealRow(
              offer: offer,
              sold: market.isPurchased(offer.id),
              onBuy: () => _handlePurchase(offer, market),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Future<bool> _buyVial(
    ExtractionVial vial,
    BlackMarketService marketService,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final coin = _vialCoin(vial);
    final costType = coin.name;
    final price = vial.price!;
    final currencies = await db.currencyDao.getAllCurrencies();
    final available = currencies[costType] ?? 0;

    if (available < price) {
      if (mounted) context.sound(SoundCue.uiDenied);
      _toast('Not enough $costType.', icon: AppIcons.warning_rounded);
      return false;
    }

    if (!mounted) return false;
    final confirmed = await showBracketConfirm(
      context,
      palette: _p,
      accent: _kLamp,
      icon: AppIcons.science_rounded,
      title: 'BUY ${vial.name.toUpperCase()}',
      message:
          '${vial.group.displayName} · ${vial.rarity.badgeLabel}. '
          'It goes straight into your inventory.',
      amounts: [(coin, price)],
      amountsLabel: 'COSTS',
      confirmLabel: 'BUY',
    );
    if (!confirmed || !mounted) return false;

    if (coin == CoinKind.gold) {
      await db.currencyDao.addGold(-price);
    } else {
      await db.currencyDao.addSilver(-price);
    }
    await db.inventoryDao.addVial(vial.name, vial.group, vial.rarity, qty: 1);
    // Marked so the lot shows as sold.
    await marketService.purchaseOffer(vial.id);
    if (!mounted) return false;
    context.sound(SoundCue.purchaseSuccess);
    HapticFeedback.heavyImpact();
    _toast(
      '${vial.name} added to your inventory.',
      icon: AppIcons.check_circle_rounded,
      accent: _kLamp,
    );
    return true;
  }

  void _showVialDetails(ExtractionVial vial) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) {
        final market = dialogContext.watch<BlackMarketService>();
        final db = dialogContext.read<AlchemonsDatabase>();
        final sold = market.isPurchased(vial.id);
        final coin = _vialCoin(vial);
        final rarityColor = _vialRarityColor(vial.rarity);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: vial.group.color.withValues(alpha: 0.85),
              bracketSize: 14,
              strokeWidth: 1.3,
            ),
            child: Container(
              color: _p.bg1,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExtractionVialOrb(vial: vial, size: 170),
                  const SizedBox(height: 14),
                  Text(
                    vial.name,
                    textAlign: TextAlign.center,
                    style: bracketText(
                      dialogContext,
                      18,
                      _p.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vial.group.displayName.toUpperCase()}  ·  '
                    '${vial.rarity.badgeLabel.toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: rarityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<Map<String, int>>(
                    stream: db.currencyDao.watchAllCurrencies(),
                    builder: (context, snap) {
                      final held = (snap.data ?? const {})[coin.name] ?? 0;
                      final canAfford = held >= (vial.price ?? 0);
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CoinAmount(
                                kind: coin,
                                amount: vial.price ?? 0,
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'YOU HAVE ${formatCoins(held)}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: canAfford ? _p.muted : _kDanger,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          BracketButton(
                            label: sold
                                ? 'SOLD'
                                : canAfford
                                ? 'BUY VIAL'
                                : 'NOT ENOUGH ${coin.name.toUpperCase()}',
                            icon: sold ? AppIcons.check_rounded : null,
                            enabled: !sold && canAfford,
                            palette: _p,
                            accent: _kLamp,
                            onTap: () async {
                              final bought = await _buyVial(vial, market);
                              if (bought && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePurchase(
    DailyOffer offer,
    BlackMarketService marketService,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final cost = DebugSettingsService.priced(offer.cost);
    final currencies = await db.currencyDao.getAllCurrencies();
    for (final entry in cost.entries) {
      if ((currencies[entry.key] ?? 0) < entry.value) {
        if (mounted) context.sound(SoundCue.uiDenied);
        _toast('Not enough ${entry.key}.', icon: AppIcons.warning_rounded);
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await showBracketConfirm(
      context,
      palette: _p,
      accent: _kLamp,
      icon: offer.icon,
      title: offer.name.toUpperCase(),
      message: offer.description,
      amounts: [
        for (final e in cost.entries)
          if (CoinKind.tryFromToken(e.key) case final kind?) (kind, e.value),
      ],
      amountsLabel: 'COSTS',
      confirmLabel: 'BUY',
    );
    if (!confirmed || !mounted) return;

    for (final entry in cost.entries) {
      if (entry.key == 'gold') {
        await db.currencyDao.addGold(-entry.value);
      } else if (entry.key == 'silver') {
        await db.currencyDao.addSilver(-entry.value);
      }
    }
    if (offer.rewardType == 'currency') {
      for (final entry in offer.reward.entries) {
        if (entry.key == 'gold') {
          await db.currencyDao.addGold(entry.value as int);
        } else if (entry.key == 'silver') {
          await db.currencyDao.addSilver(entry.value as int);
        }
      }
    } else if (offer.rewardType == 'resources') {
      for (final entry in offer.reward.entries) {
        await db.currencyDao.addResource(entry.key, entry.value as int);
      }
    }

    await marketService.purchaseOffer(offer.id);
    if (!mounted) return;
    context.sound(SoundCue.purchaseSuccess);
    HapticFeedback.heavyImpact();
    _toast(
      '${offer.name} bought.',
      icon: AppIcons.check_circle_rounded,
      accent: _kLamp,
    );
  }

  // ── sell ──────────────────────────────────────────────────────────────

  Widget _buildLocked() {
    return const _Notice(
      icon: AppIcons.lock_rounded,
      title: 'Not taking resources today.',
      line:
          'Unlock "Valuable Resources" in the Extraction tree to sell '
          'resources here.',
    );
  }

  Widget _buildSell() {
    return StreamBuilder<Map<String, int>>(
      stream: context
          .read<AlchemonsDatabase>()
          .currencyDao
          .watchResourceBalances(),
      builder: (context, snapshot) {
        final balances = snapshot.data ?? const <String, int>{};
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            Row(
              children: [
                const Expanded(child: _SectionLabel('ON THE TABLE')),
                if (_selling.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: context.soundAction(() {
                      setState(_selling.clear);
                      HapticFeedback.lightImpact();
                    }),
                    child: Text(
                      'CLEAR',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _kDanger,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '“Two of anything for a silver. No haggling.”',
              style: bracketText(
                context,
                12,
                _p.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            for (final resource in ElementResources.all) ...[
              _ResourceLot(
                resource: resource,
                held: balances[resource.settingsKey] ?? 0,
                quantity: _selling[resource.settingsKey] ?? 0,
                onChanged: (qty) => setState(() {
                  if (qty <= 0) {
                    _selling.remove(resource.settingsKey);
                  } else {
                    _selling[resource.settingsKey] = qty;
                  }
                }),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSellFooter() {
    final cut = _cut;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _kGlass,
        border: Border(top: BorderSide(color: _p.line.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'YOUR CUT',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _kLamp,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
                if (_sellingCount > 0)
                  Text(
                    'FOR ${formatCoins(_sellingCount)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _p.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                const Spacer(),
                CoinAmount(kind: CoinKind.silver, amount: cut, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            BracketButton(
              label: 'MAKE THE TRADE',
              icon: AppIcons.sell_rounded,
              enabled: cut > 0,
              palette: _p,
              accent: _kLamp,
              onTap: _confirmResourceSale,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResourceSale() async {
    if (_selling.isEmpty) return;
    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.canSellResources()) {
      _toast('Currently obstructed.', icon: AppIcons.lock_rounded);
      return;
    }
    // Read before the table is cleared: the message used to say "for 0".
    final count = _sellingCount;
    final kinds = _selling.length;
    final cut = _cut;

    final confirmed = await showBracketConfirm(
      context,
      palette: _p,
      accent: _kLamp,
      icon: AppIcons.sell_rounded,
      title: 'MAKE THE TRADE',
      message:
          'Sell ${formatCoins(count)} resources '
          '($kinds ${kinds == 1 ? 'kind' : 'kinds'})?',
      amounts: [(CoinKind.silver, cut)],
      warning: 'This cannot be undone.',
      confirmLabel: 'SELL',
    );
    if (!confirmed || !mounted) return;

    final db = context.read<AlchemonsDatabase>();
    for (final entry in _selling.entries) {
      await db.currencyDao.addResource(entry.key, -entry.value);
    }
    await db.currencyDao.addSilver(cut);
    if (!mounted) return;
    setState(_selling.clear);
    context.sound(SoundCue.currencyGain);
    HapticFeedback.heavyImpact();
    _toast(
      'Sold ${formatCoins(count)} resources for ${formatCoins(cut)} silver.',
      icon: AppIcons.check_circle_rounded,
      accent: _kLamp,
    );
  }

  void _toast(String msg, {IconData? icon, Color accent = _kDanger}) {
    if (!mounted) return;
    showGameSnack(context, msg, icon: icon, accent: accent);
  }
}

// ── pieces ──────────────────────────────────────────────────────────────

/// Gold and silver held, top right.
class _Purse extends StatelessWidget {
  const _Purse();

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, snap) {
        final curr = snap.data ?? const {'gold': 0, 'silver': 0};
        return CustomPaint(
          painter: BracketFramePainter(
            color: _p.line.withValues(alpha: 0.9),
            bracketSize: 7,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: _kGlass,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CoinAmount(kind: CoinKind.gold, amount: curr['gold'] ?? 0),
                const SizedBox(height: 3),
                CoinAmount(kind: CoinKind.silver, amount: curr['silver'] ?? 0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            color: _kLamp,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: _p.line.withValues(alpha: 0.7)),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Text(
            trailing!,
            style: TextStyle(
              fontFamily: 'monospace',
              color: _p.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

/// What the market says when there is nothing to show.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.line});

  final IconData icon;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: _kLamp.withValues(alpha: 0.6),
            bracketSize: 12,
            strokeWidth: 1.2,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            color: _kGlass,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34, color: _kLamp.withValues(alpha: 0.8)),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: bracketText(
                    context,
                    16,
                    _p.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  line,
                  textAlign: TextAlign.center,
                  style: bracketText(context, 12.5, _p.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a lot as gone.
class _SoldTag extends StatelessWidget {
  const _SoldTag();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BracketFramePainter(
        color: _kDanger.withValues(alpha: 0.85),
        bracketSize: 5,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _kDanger.withValues(alpha: 0.12),
        child: Text(
          'SOLD',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _kDanger,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}

/// One of the week's vials, held up to the lamp.
class _VialLot extends StatelessWidget {
  const _VialLot({
    required this.vial,
    required this.sold,
    required this.onOpen,
    required this.onBuy,
  });

  final ExtractionVial vial;
  final bool sold;
  final VoidCallback onOpen;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _vialRarityColor(vial.rarity);
    return Opacity(
      opacity: sold ? 0.55 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(onOpen),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: vial.group.color.withValues(alpha: sold ? 0.35 : 0.8),
            bracketSize: 10,
            strokeWidth: 1.2,
          ),
          child: Container(
            color: _kGlass,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: ExtractionVialOrb(vial: vial, size: 104)),
                const SizedBox(height: 10),
                Text(
                  vial.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(
                    context,
                    13,
                    _p.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vial.rarity.badgeLabel.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: rarityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CoinAmount(
                            kind: _vialCoin(vial),
                            amount: vial.price ?? 0,
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (sold)
                      const _SoldTag()
                    else
                      SizedBox(
                        width: 58,
                        child: BracketButton(
                          label: 'BUY',
                          height: 30,
                          palette: _p,
                          accent: _kLamp,
                          onTap: onBuy,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A deal: what it costs, what it gets you.
class _DealRow extends StatelessWidget {
  const _DealRow({
    required this.offer,
    required this.sold,
    required this.onBuy,
  });

  final DailyOffer offer;
  final bool sold;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final gets = <Widget>[
      if (offer.rewardType == 'currency')
        for (final e in offer.reward.entries)
          if (CoinKind.tryFromToken(e.key) case final kind?)
            CoinAmount(kind: kind, amount: e.value as int, size: 12),
      if (offer.rewardType == 'resources')
        for (final e in offer.reward.entries)
          _ResourceAmount(resourceKey: e.key, amount: e.value as int),
    ];

    return Opacity(
      opacity: sold ? 0.55 : 1,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: (sold ? _p.line : _kLamp).withValues(alpha: 0.7),
          bracketSize: 10,
          strokeWidth: 1.1,
        ),
        child: Container(
          color: _kGlass,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CustomPaint(
                painter: BracketFramePainter(
                  color: _kLamp.withValues(alpha: 0.6),
                  bracketSize: 6,
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  color: _kLamp.withValues(alpha: 0.08),
                  child: Icon(offer.icon, size: 22, color: _kLamp),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.name,
                      style: bracketText(
                        context,
                        14,
                        _p.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.description,
                      style: bracketText(context, 12, _p.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final e in DebugSettingsService.priced(
                          offer.cost,
                        ).entries)
                          if (CoinKind.tryFromToken(e.key) case final kind?)
                            CoinAmount(kind: kind, amount: e.value, size: 12),
                        if (gets.isNotEmpty) ...[
                          Icon(
                            AppIcons.arrow_forward_rounded,
                            size: 12,
                            color: _p.muted,
                          ),
                          ...gets,
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (sold)
                const _SoldTag()
              else
                SizedBox(
                  width: 64,
                  child: BracketButton(
                    label: 'BUY',
                    height: 34,
                    palette: _p,
                    accent: _kLamp,
                    onTap: onBuy,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A resource and how much, for a deal's reward.
class _ResourceAmount extends StatelessWidget {
  const _ResourceAmount({required this.resourceKey, required this.amount});

  final String resourceKey;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final resource = ElementResources.all
        .where((r) => r.settingsKey == resourceKey)
        .firstOrNull;
    if (resource == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElementResourceGlyph.of(resource, size: 15),
        const SizedBox(width: 3),
        Text(
          formatCoins(amount),
          style: TextStyle(
            fontFamily: 'monospace',
            color: resource.color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// One resource, and how much of it to put on the table.
class _ResourceLot extends StatelessWidget {
  const _ResourceLot({
    required this.resource,
    required this.held,
    required this.quantity,
    required this.onChanged,
  });

  final ElementResource resource;
  final int held;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selling = quantity > 0;
    final qty = quantity.clamp(0, held);
    return Opacity(
      opacity: held == 0 ? 0.5 : 1,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selling
              ? resource.color.withValues(alpha: 0.9)
              : _p.line.withValues(alpha: 0.7),
          bracketSize: 10,
          strokeWidth: selling ? 1.3 : 1,
        ),
        child: Container(
          color: _kGlass,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 36,
                    child: Center(
                      child: ElementResourceGlyph.of(resource, size: 30),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.biomeLabel.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _p.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          held == 0
                              ? 'None held'
                              : selling
                              ? '${formatCoins(qty)} of ${formatCoins(held)}'
                              : '${formatCoins(held)} held',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: selling ? resource.color : _p.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selling)
                    CoinAmount(
                      kind: CoinKind.silver,
                      amount: _resourcePrice(qty),
                      size: 15,
                    ),
                ],
              ),
              if (held > 0) ...[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: resource.color,
                    inactiveTrackColor: _p.line.withValues(alpha: 0.6),
                    thumbColor: resource.color,
                    overlayColor: resource.color.withValues(alpha: 0.12),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: qty.toDouble(),
                    min: 0,
                    max: held.toDouble(),
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
                Row(
                  children: [
                    for (final (label, share) in const [
                      ('NONE', 0.0),
                      ('¼', 0.25),
                      ('½', 0.5),
                      ('ALL', 1.0),
                    ]) ...[
                      Expanded(
                        child: _QtyChip(
                          label: label,
                          active: qty == (held * share).round(),
                          color: resource.color,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged((held * share).round());
                          },
                        ),
                      ),
                      if (share < 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  const _QtyChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: Border.all(
            color: active ? color : _p.line.withValues(alpha: 0.8),
            width: active ? 1.2 : 0.8,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: active ? _p.ink : _p.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
