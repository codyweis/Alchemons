// The wild encounter's top band must not land on itself.
//
// It used to be three separately-positioned boxes sharing one strip of sky,
// spaced by a guessed symmetric inset. With a full party the inset ate both
// sides down to about 200px, the field-status Row had no flexible child, and
// so the Spacer between its two labels collapsed to zero — FIELD STATUS and
// STABILITY ran together and the overflow painted OUTSIDE the card, under the
// party strip. In portrait the whole card sat under the strip.
//
// The band lays the identity and the strip out together now. These pin the
// arithmetic on a phone and a tablet, in both orientations, so the next
// guessed number is caught here rather than in a screenshot.

import 'package:alchemons/games/wilderness/encounter_top_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real party strip, which needs a database behind it. Only
/// its footprint matters here, and the strip is forced to exactly this width
/// by the band itself.
const Key _stripKey = Key('party-strip');
const Key _identityKey = Key('identity');

Future<void> _pump(
  WidgetTester tester, {
  required Size surface,
  int partyCount = 4,
  List<WildPotentialReading>? potentials,
  double? breedChance = 0.95,
  String status = 'Select a party ally to begin fusion.',
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final stripWidth = partyStripWidthFor(partyCount);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kEncounterHudEdgePad,
                    kEncounterHudEdgePad,
                    kEncounterHudEdgePad,
                    0,
                  ),
                  child: WildEncounterTopHud(
                    key: _identityKey,
                    name: 'AIRLET',
                    rarity: 'common',
                    status: status,
                    breedChance: breedChance,
                    potentials: potentials,
                    partyStripWidth: partyCount == 0 ? 0 : stripWidth,
                    partyStrip: partyCount == 0
                        ? null
                        : Container(key: _stripKey, height: 62),
                    // The type-in would leave a half-scanned name mid-pump.
                    animateName: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The identity block is the only thing in the band carrying the name.
Rect _identityRect(WidgetTester tester) =>
    tester.getRect(find.text('AIRLET').hitTestable(at: Alignment.topLeft));

void main() {
  testWidgets('phone portrait: identity clears the party strip', (
    tester,
  ) async {
    await _pump(tester, surface: const Size(412, 915));

    final strip = tester.getRect(find.byKey(_stripKey));
    final name = _identityRect(tester);

    // 412 - 16 padding - 74 Exit gutter - 258 strip - 12 gap leaves 52px:
    // nowhere near enough, so the identity goes underneath.
    expect(strip.overlaps(name), isFalse);
    expect(name.top, greaterThanOrEqualTo(strip.bottom));
    expect(name.left, greaterThanOrEqualTo(0));
    expect(name.right, lessThanOrEqualTo(412));
  });

  testWidgets('phone landscape: identity sits between the two HUDs', (
    tester,
  ) async {
    await _pump(tester, surface: const Size(915, 412));

    final strip = tester.getRect(find.byKey(_stripKey));
    final name = _identityRect(tester);

    expect(strip.overlaps(name), isFalse);
    // Beside the strip, not under it.
    expect(name.top, lessThan(strip.bottom));
    // Clear of the Exit button's corner.
    expect(
      name.left,
      greaterThanOrEqualTo(kEncounterHudEdgePad + kEncounterHudLeftGutter),
    );
    expect(name.right, lessThanOrEqualTo(strip.left - kEncounterHudGap));
  });

  testWidgets('tablet landscape: identity stays a label, not a banner', (
    tester,
  ) async {
    await _pump(tester, surface: const Size(1112, 834));

    final strip = tester.getRect(find.byKey(_stripKey));
    final slate = tester.getRect(find.byType(WildEncounterTopHud));

    expect(strip.right, lessThanOrEqualTo(1112 - kEncounterHudEdgePad));
    expect(slate.width, 1112 - 2 * kEncounterHudEdgePad);
    expect(
      _identityRect(tester).overlaps(strip),
      isFalse,
      reason: 'the name must never reach the party strip',
    );
  });

  testWidgets('tablet portrait keeps them side by side', (tester) async {
    await _pump(tester, surface: const Size(834, 1112));
    final strip = tester.getRect(find.byKey(_stripKey));
    final name = _identityRect(tester);
    expect(strip.overlaps(name), isFalse);
    expect(name.top, lessThan(strip.bottom));
  });

  testWidgets('a long status does not push the stability figure out', (
    tester,
  ) async {
    // The exact case that used to overflow: a full party, a narrow lane and
    // two labels with no flexible child between them.
    await _pump(
      tester,
      surface: const Size(915, 412),
      status:
          'Harvester failed to secure the specimen and the field has '
          'destabilised badly.',
    );

    final slate = tester.getRect(find.byType(WildEncounterTopHud));
    final stability = tester.getRect(find.text('95.0%'));
    expect(stability.right, lessThanOrEqualTo(slate.right));
    expect(
      tester.getRect(find.byKey(_stripKey)).overlaps(stability),
      isFalse,
      reason: 'the stability figure used to render under the party strip',
    );
  });

  group('the Potential readout is gated', () {
    testWidgets('absent entirely without the Wild Potential Scanner', (
      tester,
    ) async {
      await _pump(tester, surface: const Size(915, 412));

      // Not a dash, not a placeholder, not a label — nothing.
      for (final label in ['SPD', 'INT', 'STR', 'BEA', 'Potential', '—']) {
        expect(
          find.textContaining(label),
          findsNothing,
          reason: '"$label" leaked past the gate',
        );
      }
    });

    testWidgets('four aligned cells once it is unlocked', (tester) async {
      await _pump(
        tester,
        surface: const Size(915, 412),
        potentials: const [
          (label: 'SPD', value: 76),
          (label: 'INT', value: 34),
          (label: 'STR', value: 45),
          (label: 'BEA', value: 67),
        ],
      );

      expect(find.text('SPD'), findsOneWidget);
      expect(find.text('76'), findsOneWidget);
      // Equal columns: the four cells share one baseline and one bar.
      final tops = [
        'SPD',
        'INT',
        'STR',
        'BEA',
      ].map((l) => tester.getRect(find.text(l)).top).toSet();
      expect(tops.length, 1, reason: 'the four cells must sit on one line');
      // And the readout sits above the status line, inside the same slate.
      expect(
        tester.getRect(find.text('SPD')).bottom,
        lessThan(tester.getRect(find.text('95.0%')).top),
      );
    });
  });

  testWidgets('no party strip still keeps the Exit corner clear', (
    tester,
  ) async {
    await _pump(tester, surface: const Size(412, 915), partyCount: 0);
    expect(
      _identityRect(tester).left,
      greaterThanOrEqualTo(kEncounterHudEdgePad + kEncounterHudLeftGutter),
    );
  });

  test('the reserved gutter matches the strip the band is given', () {
    expect(partyStripWidthFor(0), 0);
    expect(partyStripWidthFor(1), kPartyCardWidth + 2 * kPartyStripPadding);
    expect(partyStripWidthFor(4), 4 * 56 + 3 * 6 + 16);
  });

  // The tutorial callout sits above the party strip and is wider than it.
  //
  // The strip is forced into a box sized to its cards, so the callout used
  // to run off the right of the screen showing one word. Letting it overflow
  // that box instead broke selection outright — the strip's own taps stopped
  // landing — so the room is reserved, and the label scales down rather than
  // overflowing whatever it is given.
  group('party strip gutter', () {
    test('a plain strip reserves exactly its cards', () {
      for (var n = 0; n <= 4; n++) {
        expect(partyStripGutterFor(n), partyStripWidthFor(n));
      }
    });

    test('the callout widens a strip too narrow to hold it', () {
      // One member is the tutorial case, and the worst one.
      expect(partyStripWidthFor(1), lessThan(kPartyStripCalloutWidth));
      expect(
        partyStripGutterFor(1, withCallout: true),
        kPartyStripCalloutWidth,
      );
    });

    test('a strip already wider than the callout is left alone', () {
      final wide = partyStripWidthFor(4);
      expect(wide, greaterThan(kPartyStripCalloutWidth));
      expect(partyStripGutterFor(4, withCallout: true), wide);
    });

    test('no party means no gutter, callout or not', () {
      expect(partyStripGutterFor(0, withCallout: true), 0);
    });
  });
}
