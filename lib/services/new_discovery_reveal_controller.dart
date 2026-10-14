import 'dart:async';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/widgets/fx/card_dissolve.dart' show CardPicture;
import 'package:alchemons/widgets/fx/codex_stage.dart' show PortraitBody;
import 'package:alchemons/widgets/fx/discovery_filing.dart';
import 'package:alchemons/widgets/fx/essence_rim.dart' show RimColor;
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:flutter/material.dart';

// Coordinates the filing-away when a new alchemon is discovered via
// extraction. The card comes apart into its sand, the app switches to the
// creatures tab, and the sand pours into the new species' cell in the
// catalog, settling on its shadow until the portrait comes up through it
// (DiscoveryFiling).

/// A new discovery waiting to be filed: where its card stood, and the sand
/// it was made of.
///
/// The batch ceremony needs exactly this: it cannot file a card at the
/// moment the card is dismissed, because that would switch sections in the
/// middle of the run. It notes each new discovery as it goes and files them
/// all once the last card is done, the sand gathering where each card stood.
class DiscoveryFlight {
  const DiscoveryFlight({
    required this.species,
    required this.from,
    this.color = RimColor.element,
    this.seed = 0,
  });

  final Creature species;

  /// Where its card stood on the screen.
  final Rect from;
  final RimColor color;
  final int seed;
}

class NewDiscoveryReveal {
  NewDiscoveryReveal._();
  static final NewDiscoveryReveal instance = NewDiscoveryReveal._();

  /// GlobalKey on the revealed species' own cell in the catalog, set by the
  /// catalog while a reveal is pending. The sand pours into this once the
  /// catalog has laid it out, so it lands on the entry rather than on the
  /// tab button that merely leads to it.
  GlobalKey? revealTileKey;

  /// GlobalKey on the CREATURES nav button; set by [BottomNav].
  GlobalKey? databaseNavKey;

  /// Section-switch callback registered by MainShell.
  void Function(NavSection section)? onSwitchSection;

  /// Watched by CreaturesScreen. Non-null while a reveal should play.
  final ValueNotifier<String?> pendingRevealCreatureId = ValueNotifier(null);

  /// How far the revealed cell's portrait has come up through its sand: 0
  /// while the cell is still its shadow, 1 once the portrait stands. Driven
  /// by the filing; 1 whenever none is playing.
  final ValueNotifier<double> revealFill = ValueNotifier(1);

  Rect? _rectOf(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Where whatever [key] is on stands on the screen, for filing it later.
  Rect? rectOf(GlobalKey key) => _rectOf(key);

  /// Starts the species' portrait being read into grains, so it is there
  /// by the time the card is put away.
  void prepare(Creature species) => unawaited(_portrait(species));

  Future<PortraitBody?> _portrait(Creature species) => catalogPortrait(species)
      .timeout(const Duration(milliseconds: 300), onTimeout: () => null)
      .catchError((Object _) => null);

  void _revealOnly(String creatureId) {
    revealFill.value = 1;
    // Pending first — see the note in [_file].
    pendingRevealCreatureId.value = creatureId;
    onSwitchSection?.call(NavSection.creatures);
  }

  /// The card on [cardBoundaryKey] files itself away: it comes apart, and
  /// its sand pours into the species' cell in the catalog.
  ///
  /// True once the filing is standing in for the card: remove the card's
  /// route straight away, in the same frame. False when the card could not
  /// be pictured; the catalog still opens on the species, so just close it.
  Future<bool> playFilingAway({
    required BuildContext context,
    required GlobalKey cardBoundaryKey,
    required Creature species,
    RimColor color = RimColor.element,
    Color barrier = const Color(0x00000000),
    bool reduced = false,
    int seed = 0,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final card = overlay == null || databaseNavKey == null
        ? null
        : await CardPicture.take(context, cardBoundaryKey);
    final portrait = card == null ? null : await _portrait(species);
    if (card == null || overlay == null || !overlay.mounted) {
      card?.dispose();
      _revealOnly(species.id);
      return false;
    }
    unawaited(
      _file(
        overlay,
        DiscoveryFlight(
          species: species,
          from: card.rect,
          color: color,
          seed: seed,
        ),
        card: card,
        portrait: portrait,
        barrier: barrier,
        reduced: reduced,
      ),
    );
    return true;
  }

  /// Files several new species one after another, each one's sand gathering
  /// where its card stood and pouring into its own cell, the next waiting
  /// for the last to stand.
  ///
  /// The section switch happens once, on the first entry. Everything after
  /// it is the catalog scrolling from one new entry to the next.
  Future<void> playFilingSequence({
    required BuildContext context,
    required List<DiscoveryFlight> flights,
    bool reduced = false,
  }) async {
    for (final flight in flights) {
      if (!context.mounted) return;
      // The batch hands over its navigator's own context, which sits above
      // that navigator's overlay, so an ancestor lookup alone never finds
      // one (and every batch discovery used to skip straight to the reveal).
      final overlay =
          Overlay.maybeOf(context, rootOverlay: true) ??
          Navigator.maybeOf(context, rootNavigator: true)?.overlay;
      if (overlay == null) {
        _revealOnly(flight.species.id);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        continue;
      }
      final portrait = await _portrait(flight.species);
      if (!context.mounted || !overlay.mounted) return;
      await _file(overlay, flight, portrait: portrait, reduced: reduced);
      if (!context.mounted) return;
      // Let the portrait sit before moving on, so each entry reads as its
      // own arrival rather than the grid jumping between them.
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<void> _file(
    OverlayState overlay,
    DiscoveryFlight flight, {
    CardPicture? card,
    PortraitBody? portrait,
    Color barrier = const Color(0x00000000),
    bool reduced = false,
  }) {
    // No wait for the catalog. The overlay, the card's removal and the
    // section switch all land in one frame, which shows the card still
    // standing; the sand's clock starts on the frame after, so building the
    // catalog costs neither a frozen card nor its first moments. The cell is
    // looked up every frame while the catalog scrolls it into view.
    //
    // ORDER MATTERS: the pending id goes up before the section switch.
    //
    // MainShell fires the first-visit database tutorial when it arrives at
    // the creatures section, and it suppresses that when a reveal is in
    // flight — but it reads the pending id to decide, and the switch used to
    // happen while that id was still null. So the very first extraction
    // opened the tutorial on top of the extraction result, and the dismissal
    // meant for the result closed the tutorial instead, stranding the result
    // on screen. Setting it first is what makes that check able to see
    // anything.
    revealFill.value = 0;
    pendingRevealCreatureId.value = flight.species.id;
    final done = DiscoveryFiling.play(
      overlay: overlay,
      species: flight.species,
      from: flight.from,
      card: card,
      portrait: portrait?.grainsAt(0),
      color: flight.color,
      barrier: barrier,
      reduced: reduced,
      seed: flight.seed,
      cell: () => _rectOf(revealTileKey),
      fallback: () => _rectOf(databaseNavKey),
      onFill: (f) => revealFill.value = f,
    );
    onSwitchSection?.call(NavSection.creatures);
    return done.whenComplete(() {
      revealFill.value = 1;
      revealTileKey = null;
    });
  }
}
