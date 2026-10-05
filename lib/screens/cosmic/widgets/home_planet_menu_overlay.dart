// lib/screens/cosmic/widgets/home_planet_menu_overlay.dart
//
// The home base window, in the customization lab's language: the planet
// itself turning on a stage at the top (the real one, wearing what it
// wears), what the base is holding as a few readings and a ledger of its
// elements, and the one thing to do here — CUSTOMIZE — docked at the foot.
//
// The ship's own figures (fuel, the hold's tier) live on the ship console;
// only the astral shards in the hold are here, because DEPOSIT moves them
// into the bank this window reports.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';

import 'cosmic_overlay_chrome.dart';
import 'cosmic_panel_kit.dart';
import 'cosmic_screen_styles.dart';

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

const _accent = CosmicScreenStyles.amberBright;

class HomePlanetMenuOverlay extends StatelessWidget {
  const HomePlanetMenuOverlay({
    super.key,
    required this.homePlanet,
    required this.elementStorage,
    required this.stats,
    required this.onCustomize,
    required this.onClose,
    this.paintHome,
    this.wearing = const {},
  });

  final HomePlanet homePlanet;
  final ElementStorage elementStorage;
  final HomeBaseStats stats;
  final VoidCallback onCustomize;
  final VoidCallback onClose;

  /// Draws the real planet on the stage (CosmicGame.paintHomeShowcase).
  final HomeShowcasePainter? paintHome;

  /// What the planet is wearing: the active customization ids.
  final Set<String> wearing;

  @override
  Widget build(BuildContext context) {
    // Drop keys the game no longer knows — stale saves carry renamed or
    // removed elements, and `elementColor` renders those flat grey so they
    // read as real resources.
    final entries =
        elementStorage.stored.entries
            .where((e) => e.value > 0 && isKnownElement(e.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: context.soundAction(onClose),
        alpha: 0.96,
        child: GestureDetector(
          // The panel fills the screen; taps inside it must not reach the
          // dismiss backdrop underneath.
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Column(
            children: [
              PanelHeader(title: 'HOME BASE', onClose: onClose),
              _stage(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _readings(),
                    const SizedBox(height: 10),
                    PanelGauge(
                      label: 'STAR DUST',
                      labelWidth: 84,
                      fraction: stats.dustTotal > 0
                          ? stats.dustCollected / stats.dustTotal
                          : 0,
                      value:
                          '${panelFmt(stats.dustCollected)}/${panelFmt(stats.dustTotal)}',
                      color: CosmicScreenStyles.amberGlow,
                    ),
                    const SizedBox(height: 12),
                    PanelSectionHeader(
                      'ELEMENTS',
                      trailing: entries.isEmpty
                          ? null
                          : panelFmt(elementStorage.total),
                    ),
                    _ledger(entries),
                    const SizedBox(height: 14),
                    const PanelSectionHeader('WALLET'),
                    _wallet(),
                  ],
                ),
              ),
              _dock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage() {
    final color = homePlanet.activeColor;
    final name = premiumHomeColor(color)?.label ?? color;
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          Positioned.fill(
            child: HomeStage(
              paintHome: paintHome,
              wearing: wearing,
              color: color,
              scale: 1.2,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 8,
            child: Text(
              '${homePlanet.sizeTier.toUpperCase()} CLASS'
              '${name == null ? '' : '  ·  ${name.toUpperCase()}'}',
              style: panelLabel(10.5, panelPalette.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// What the base holds, and what the ship has brought it.
  Widget _readings() {
    final holdFull =
        stats.shardCapacity > 0 && stats.shardsCarried >= stats.shardCapacity;
    return PanelRow(
      children: [
        PanelReadout(
          label: 'ASTRAL BANKED',
          value: panelFmt(stats.astralBank),
          color: CosmicScreenStyles.astralShardColor,
          leading: const Icon(
            CosmicScreenStyles.astralShardIcon,
            size: 13,
            color: CosmicScreenStyles.astralShardColor,
          ),
        ),
        PanelReadout(
          label: 'IN THE HOLD',
          value: stats.shardCapacity > 0
              ? '${panelFmt(stats.shardsCarried)}/${panelFmt(stats.shardCapacity)}'
              : panelFmt(stats.shardsCarried),
          color: holdFull ? CosmicScreenStyles.danger : null,
        ),
        PanelReadout(
          label: 'GARRISON',
          value: '${stats.garrisonStationed}/${stats.garrisonSlots}',
          color:
              stats.garrisonSlots > 0 &&
                  stats.garrisonStationed >= stats.garrisonSlots
              ? CosmicScreenStyles.success
              : null,
        ),
      ],
    );
  }

  /// The element store as a ledger: each element's amount, with a bar
  /// against the largest so the shape of the store reads at a glance.
  Widget _ledger(List<MapEntry<String, double>> entries) {
    if (entries.isEmpty) {
      return Text(
        'NOTHING STORED YET',
        style: panelLabel(10.5, panelPalette.muted),
      );
    }
    final most = entries.first.value;
    Widget row(MapEntry<String, double> e) {
      final ink = elementInk(e.key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            PanelDot(ink),
            const SizedBox(width: 7),
            SizedBox(
              width: 62,
              child: Text(
                e.key.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: panelLabel(10, ink, spacing: 0.6),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: box.maxWidth * (e.value / most).clamp(0.04, 1.0),
                    height: 3,
                    color: ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              panelFmt(e.value),
              style: panelLabel(10.5, panelPalette.ink, spacing: 0.4),
            ),
          ],
        ),
      );
    }

    final half = (entries.length / 2).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(children: [for (final e in entries.take(half)) row(e)]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(children: [for (final e in entries.skip(half)) row(e)]),
        ),
      ],
    );
  }

  /// Account-wide money — not tied to this ship or this base.
  Widget _wallet() {
    return Wrap(
      spacing: 22,
      runSpacing: 8,
      children: [
        CoinAmount(kind: CoinKind.gold, amount: stats.gold, size: 13),
        CoinAmount(kind: CoinKind.silver, amount: stats.silver, size: 13),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.diamond_rounded,
              size: 14,
              color: Color(0xFFB388FF),
            ),
            const SizedBox(width: 5),
            Text(
              panelFmt(stats.soft),
              style: panelLabel(13, const Color(0xFFB388FF), spacing: 0.4),
            ),
            const SizedBox(width: 6),
            Text('SHARDS', style: panelLabel(9, panelPalette.muted)),
          ],
        ),
      ],
    );
  }

  Widget _dock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          top: BorderSide(color: _accent.withValues(alpha: 0.45), width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BracketButton(
          key: const ValueKey('home.customize'),
          label: 'CUSTOMIZE',
          height: 46,
          palette: panelPalette,
          accent: _accent,
          onTap: onCustomize,
        ),
      ),
    );
  }
}
