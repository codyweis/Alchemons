// lib/screens/cosmic/widgets/home_planet_menu_overlay.dart
//
// The home base panel: full-screen, with the base itself docked at the top and
// the actions docked at the bottom.
//
// It used to be a 360pt centred card that scrolled everything — identity, mix,
// storage, actions, close — as one long column, so on a landscape phone the
// actions were usually below the fold. Now only the middle scrolls; what the
// player came here to look at and what they came here to press are both always
// on screen.

import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'cosmic_overlay_chrome.dart';
import 'cosmic_screen_styles.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/coin_icon.dart';

String _fmt(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Everything the base panel reports that is not the element store itself.
/// Passed in as plain values so the panel stays dumb and renderable in a test.
class HomeBaseStats {
  const HomeBaseStats({
    this.gold = 0,
    this.silver = 0,
    this.soft = 0,
    this.shardsCarried = 0,
    this.shardCapacity = 0,
    this.astralBank = 0,
    this.dustCollected = 0,
    this.dustTotal = 0,
    this.garrisonStationed = 0,
    this.garrisonSlots = 0,
    this.fuel = 0,
    this.fuelCapacity = 0,
    this.cargoTierName = '',
  });

  final int gold;
  final int silver;
  final int soft;

  /// Shards in the ship's hold, and what the hold can take.
  final int shardsCarried;
  final int shardCapacity;

  /// Shards banked at the base.
  final int astralBank;

  final int dustCollected;
  final int dustTotal;

  final int garrisonStationed;
  final int garrisonSlots;

  /// Ship-side: fuel in the tank and what the tank holds.
  final double fuel;
  final double fuelCapacity;

  /// Ship-side: the cargo hold's tier name ('Void Hold', …).
  final String cargoTierName;
}

class HomePlanetMenuOverlay extends StatelessWidget {
  const HomePlanetMenuOverlay({
    super.key,
    required this.homePlanet,
    required this.elementStorage,
    required this.stats,
    required this.onCustomize,
    required this.onGarrison,
    required this.onClose,
  });

  final HomePlanet homePlanet;
  final ElementStorage elementStorage;
  final HomeBaseStats stats;
  final VoidCallback onCustomize;
  final VoidCallback onGarrison;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final col = homePlanet.blendedColor;
    // Drop keys the game no longer knows — stale saves carry renamed or
    // removed elements, and `elementColor` renders those flat grey so they read
    // as real resources.
    final storageEntries =
        elementStorage.stored.entries
            .where((e) => e.value > 0 && isKnownElement(e.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: onClose,
        alpha: 0.96,
        child: GestureDetector(
          // The panel fills the screen; taps inside it must not reach the
          // dismiss backdrop underneath.
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Column(
            children: [
              _topDock(context, col),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Grouped by where the thing actually lives: what the
                      // ship is carrying, what the base is holding, the dust
                      // hunt, and the account-wide wallet.
                      _shipHold(context),
                      const SizedBox(height: 12),
                      _baseVault(context, storageEntries),
                      const SizedBox(height: 12),
                      _starDust(context),
                      const SizedBox(height: 12),
                      _wallet(context),
                    ],
                  ),
                ),
              ),
              _bottomDock(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── TOP DOCK: the base itself ────────────────────────

  Widget _topDock(BuildContext context, Color col) {
    final font = appFontFamily(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          bottom: BorderSide(color: col.withValues(alpha: 0.45), width: 1.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _planetOrb(col, 58),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 13, color: col),
                    const SizedBox(width: 8),
                    Text(
                      'HOME BASE',
                      style: TextStyle(
                        fontFamily: font,
                        color: CosmicScreenStyles.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Text(
                    // The element mix used to live here. It no longer drives
                    // anything — `blendedColor` reads `activeColor`, not the
                    // deposit mix — so reporting a deposited total was telling
                    // the player about a number with no consequences.
                    '${homePlanet.sizeTier.toUpperCase()} CLASS'
                    '${homePlanet.activeSizeTier < homePlanet.sizeTierLevel ? '  ·  LARGER TIERS UNLOCKED' : ''}',
                    style: TextStyle(
                      fontFamily: font,
                      color: CosmicScreenStyles.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CosmicCloseButton(onTap: onClose),
        ],
      ),
    );
  }

  Widget _planetOrb(Color col, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Color.lerp(col, Colors.white, 0.55)!,
            col,
            Color.lerp(col, Colors.black, 0.55)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: col.withValues(alpha: 0.45), blurRadius: 18),
        ],
      ),
    );
  }

  // ── MIDDLE: what the base is holding ─────────────────

  /// What the ship is carrying right now — everything here is at risk if the
  /// ship dies, which is the whole reason it is separated from the vault.
  ///
  /// Note the two different "shards": `wallet_soft` is the game-wide currency
  /// the shop calls *Shards* and lives in the wallet below; the hold and the
  /// vault carry *astral* shards. Labelled apart on purpose.
  Widget _shipHold(BuildContext context) {
    final holdFull =
        stats.shardCapacity > 0 && stats.shardsCarried >= stats.shardCapacity;

    return _section(
      context,
      'SHIP HOLD',
      accent: CosmicScreenStyles.teal,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _stat(
            context,
            label: 'ASTRAL',
            value: stats.shardCapacity > 0
                ? '${_fmt(stats.shardsCarried)}/${_fmt(stats.shardCapacity)}'
                : _fmt(stats.shardsCarried),
            icon: CosmicScreenStyles.astralShardIcon,
            tint: holdFull
                ? const Color(0xFFE25544)
                : CosmicScreenStyles.astralShardColor,
          ),
          if (stats.fuelCapacity > 0)
            _stat(
              context,
              label: 'FUEL',
              value:
                  '${stats.fuel.toStringAsFixed(0)}/'
                  '${stats.fuelCapacity.toStringAsFixed(0)}',
              icon: AppIcons.local_fire_department_rounded,
              tint: CosmicScreenStyles.amberBright,
            ),
          if (stats.cargoTierName.isNotEmpty)
            _stat(
              context,
              label: 'HOLD',
              value: stats.cargoTierName.toUpperCase(),
              icon: AppIcons.inventory_2_rounded,
              tint: CosmicScreenStyles.textSecondary,
            ),
        ],
      ),
    );
  }

  /// What the base is holding: banked shards, the garrison, and the element
  /// store itself.
  Widget _baseVault(
    BuildContext context,
    List<MapEntry<String, double>> entries,
  ) {
    final font = appFontFamily(context);
    return _section(
      context,
      'BASE VAULT',
      accent: CosmicScreenStyles.amberBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat(
                context,
                label: 'ASTRAL BANKED',
                value: _fmt(stats.astralBank),
                icon: CosmicScreenStyles.astralShardIcon,
                tint: CosmicScreenStyles.astralShardColor,
              ),
              _stat(
                context,
                label: 'GARRISON',
                value: '${stats.garrisonStationed}/${stats.garrisonSlots}',
                icon: AppIcons.shield,
                tint: CosmicScreenStyles.teal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ELEMENTS STORED',
            style: TextStyle(
              fontFamily: font,
              color: CosmicScreenStyles.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              'No elements stored yet.',
              style: TextStyle(
                fontFamily: font,
                color: CosmicScreenStyles.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              // There is room now — show everything the base holds rather
              // than the first twelve.
              children: entries.map((e) {
                final ec = elementInk(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: ec.withValues(alpha: 0.10),
                    border: Border(left: BorderSide(color: ec, width: 2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.key.toUpperCase(),
                        style: TextStyle(
                          fontFamily: font,
                          color: ec,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _fmt(e.value),
                        style: TextStyle(
                          fontFamily: font,
                          color: CosmicScreenStyles.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Star dust is its own hunt — neither carried nor banked, just a count of
  /// how much of the cosmos you have swept.
  Widget _starDust(BuildContext context) {
    final font = appFontFamily(context);
    final pct = stats.dustTotal > 0
        ? (stats.dustCollected / stats.dustTotal).clamp(0.0, 1.0)
        : 0.0;
    const tint = CosmicScreenStyles.amberGlow;

    return _section(
      context,
      'STAR DUST',
      accent: tint,
      child: Row(
        children: [
          const Icon(AppIcons.auto_awesome, size: 15, color: tint),
          const SizedBox(width: 10),
          Text(
            '${_fmt(stats.dustCollected)} / ${_fmt(stats.dustTotal)}',
            style: TextStyle(
              fontFamily: font,
              color: CosmicScreenStyles.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 6,
              child: Row(
                // Stretch, or the childless ColoredBoxes get zero height.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: (pct * 1000).round().clamp(0, 1000),
                    child: const ColoredBox(color: tint),
                  ),
                  Expanded(
                    flex: ((1 - pct) * 1000).round().clamp(0, 1000),
                    child: const ColoredBox(
                      color: CosmicScreenStyles.borderDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontFamily: font,
              color: CosmicScreenStyles.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  /// Account-wide currency — not tied to this ship or this base.
  Widget _wallet(BuildContext context) {
    return _section(
      context,
      'WALLET',
      accent: CosmicScreenStyles.amber,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _stat(
            context,
            label: 'GOLD',
            value: _fmt(stats.gold),
            coin: CoinKind.gold,
            tint: CosmicScreenStyles.amberBright,
          ),
          _stat(
            context,
            label: 'SILVER',
            value: _fmt(stats.silver),
            coin: CoinKind.silver,
            tint: const Color(0xFFB0BEC5),
          ),
          _stat(
            context,
            label: 'SHARDS',
            value: _fmt(stats.soft),
            icon: AppIcons.diamond_rounded,
            tint: const Color(0xFFB388FF),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    CoinKind? coin,
    Color tint = CosmicScreenStyles.textSecondary,
  }) {
    final font = appFontFamily(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(left: BorderSide(color: tint, width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coin != null)
            CoinIcon(kind: coin, size: 14)
          else
            Icon(icon, size: 13, color: tint),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: font,
              color: CosmicScreenStyles.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: font,
              color: CosmicScreenStyles.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title, {
    required Widget child,
    Color? accent,
  }) {
    final a = accent ?? CosmicScreenStyles.amber;
    return Container(
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: CosmicScreenStyles.bg3,
              border: Border(
                bottom: BorderSide(color: CosmicScreenStyles.borderDim),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 10,
                  color: a,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: a,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  // ── BOTTOM DOCK: what you came here to press ─────────

  Widget _bottomDock(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          top: BorderSide(color: CosmicScreenStyles.borderMid, width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The two things you came here to do, side by side...
            Row(
              children: [
                Expanded(
                  child: _action(
                    context: context,
                    icon: AppIcons.auto_awesome,
                    label: 'CUSTOMIZE',
                    onTap: onCustomize,
                    primary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _action(
                    context: context,
                    icon: AppIcons.shield,
                    label: 'GARRISON',
                    onTap: onGarrison,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ...and leaving, stacked underneath so it never competes with
            // them for the same row.
            _action(
              context: context,
              icon: AppIcons.close_rounded,
              label: 'CLOSE',
              onTap: onClose,
              muted: true,
              height: 38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool muted = false,
    double height = 46,
  }) {
    final fg = primary
        ? CosmicScreenStyles.bg0
        : (muted
              ? CosmicScreenStyles.textMuted
              : CosmicScreenStyles.textSecondary);
    final edge = primary
        ? CosmicScreenStyles.amberGlow
        : (muted
              ? CosmicScreenStyles.borderMid
              : CosmicScreenStyles.borderAccent.withValues(alpha: 0.7));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: primary ? CosmicScreenStyles.amber : Colors.transparent,
          border: Border.all(color: edge, width: primary ? 1 : 0.9),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: CosmicScreenStyles.amber.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
