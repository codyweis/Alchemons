// The survival lobby at rest: what one idle frame, one roster swipe frame and
// one scroll frame ask of the UI thread and of the GPU, on a mid-game save at
// the phone's size.
//
// A probe, not a gate: the expectations are loose ceilings on what it measured
// on 2026-10-02, so a regression shows, and it prints everything it counts.
// Since the lobby's rebuild the same day its stage (the orb, the ship on its
// orbit) is live, so the lobby never goes fully idle: an idle frame repaints
// the stage and nothing else.
// Widget tests never rasterise, so the GPU side is counted rather than timed
// (the method is test/fusion_screen_budget_test.dart's): the whole tree is
// painted once more into a canvas that tallies what it is asked to draw,
// with BoxShadows switched back on (flutter_test turns them off, which hides
// every shadow blur from a census).
//
//   flutter test test/survival_lobby_budget_probe_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

/// Tallies what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurred = 0;

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (n, e) => n + e.value);

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && (a.maskFilter != null || a.imageFilter != null)) {
        blurred++;
      }
    }
    switch (key) {
      case 'getSaveCount':
        return 1;
      case 'getLocalClipBounds' || 'getDestinationClipBounds':
        return Rect.largest;
      case 'getTransform':
        return Matrix4.identity().storage;
    }
    return null;
  }
}

/// Paints a tree straight into a [_CensusCanvas]: every child, through every
/// repaint boundary, without touching the real layer tree.
class _CensusContext extends PaintingContext {
  _CensusContext(this.census, this.layers)
    : super(ContainerLayer(), Rect.largest);

  final _CensusCanvas census;
  final Map<String, int> layers;

  @override
  Canvas get canvas => census;

  @override
  void paintChild(RenderObject child, Offset offset) =>
      child.paint(this, offset);

  @override
  void addLayer(Layer layer) => _count(layer);

  @override
  void pushLayer(
    ContainerLayer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    _count(childLayer);
    painter(this, offset);
  }

  void _count(Layer l) {
    final k = l.runtimeType.toString();
    layers[k] = (layers[k] ?? 0) + 1;
  }
}

/// What one pumped frame re-did.
class _Work {
  int rebuilt = 0;
  int painted = 0;
  final Map<String, int> rebuiltByType = {};
  final Map<String, int> paintedByType = {};

  @override
  String toString() =>
      'rebuilt $rebuilt $rebuiltByType\n  painted $painted $paintedByType';
}

Future<_Work> _countFrame(
  WidgetTester tester,
  Future<void> Function() frame,
) async {
  final w = _Work();
  debugOnRebuildDirtyWidget = (element, _) {
    w.rebuilt++;
    final k = element.widget.runtimeType.toString();
    w.rebuiltByType[k] = (w.rebuiltByType[k] ?? 0) + 1;
  };
  debugOnProfilePaint = (ro) {
    w.painted++;
    final k = ro.runtimeType.toString();
    w.paintedByType[k] = (w.paintedByType[k] ?? 0) + 1;
  };
  try {
    await frame();
  } finally {
    debugOnRebuildDirtyWidget = null;
    debugOnProfilePaint = null;
  }
  return w;
}

({_CensusCanvas census, Map<String, int> layers}) _census(WidgetTester t) {
  final census = _CensusCanvas();
  final layers = <String, int>{};
  final ctx = _CensusContext(census, layers);
  debugDisableShadows = false;
  try {
    for (final view in t.binding.renderViews) {
      view.paint(ctx, Offset.zero);
    }
  } finally {
    debugDisableShadows = true;
  }
  return (census: census, layers: layers);
}

/// Draw calls each on-screen CustomPainter issues, by painter type: which
/// painters the census's draws come from.
Map<String, int> _drawsByPainter(WidgetTester tester) {
  final out = <String, int>{};
  void visit(RenderObject ro) {
    if (ro is RenderCustomPaint) {
      for (final p in [ro.painter, ro.foregroundPainter]) {
        if (p == null) continue;
        final c = _CensusCanvas();
        p.paint(c, ro.size);
        final k = '${p.runtimeType}';
        out[k] = (out[k] ?? 0) + c.draws;
      }
    }
    ro.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return out;
}

void main() {
  // Real glyph metrics, so text wraps (and the header fits) as on the phone;
  // the test font's square glyphs overflow the header row.
  setUpAll(loadLobbyFonts);

  testWidgets('the survival lobby at rest, swiped and scrolled', (
    tester,
  ) async {
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);

    final save = await LobbySave.create(tester);

    // ── Opening: the frame the lobby first appears in ──────────────────
    // The screen opens on a spinner (_Phase.intro) until the intro check's
    // database reads come back, then shows the lobby; the high score, the
    // balances, the ship skin and the quality setting each land later with
    // a setState of their own.
    await tester.pumpWidget(save.app());
    _Work? firstLobbyFrame;
    var firstFrameMicros = 0;
    var spinnerFrames = 0;
    for (var i = 0; i < 60 && !lobbyShown(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      final sw = Stopwatch()..start();
      final w = await _countFrame(
        tester,
        () => tester.pump(const Duration(milliseconds: 16)),
      );
      sw.stop();
      if (lobbyShown()) {
        firstLobbyFrame = w;
        firstFrameMicros = sw.elapsedMicroseconds;
      } else {
        spinnerFrames++;
      }
    }
    expect(lobbyShown(), isTrue);
    // What happens after the lobby is up: whole-screen rebuilds as the
    // late loads land.
    var lateScreenRebuilds = 0;
    var lateWidgets = 0;
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      final w = await _countFrame(
        tester,
        () => tester.pump(const Duration(milliseconds: 16)),
      );
      lateWidgets += w.rebuilt;
      if ((w.rebuiltByType['CosmicSurvivalScreen'] ?? 0) > 0) {
        lateScreenRebuilds++;
      }
    }
    final portraits = find.byType(Image).evaluate().length;
    var imagesResolved = 0;
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element, onError: (_, _) {});
        imagesResolved++;
      }
    });
    await settleLobby(tester, 12);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // ── Idle ────────────────────────────────────────────────────────────
    final scheduledWhenIdle = SchedulerBinding.instance.hasScheduledFrame;
    final tickers = SchedulerBinding.instance.transientCallbackCount;
    final idle = await _countFrame(
      tester,
      () => tester.pump(const Duration(milliseconds: 16)),
    );
    final idleCensus = _census(tester);
    final byPainter = _drawsByPainter(tester);

    // ── One frame mid-swipe on the roster ───────────────────────────────
    final pager = find.byType(PageView);
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final swipe = await _countFrame(tester, () async {
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    });
    await gesture.up();
    await settleLobby(tester, 12);
    // Back to the first card.
    await tester.fling(pager, const Offset(400, 0), 1500);
    await settleLobby(tester, 12);

    // ── Tapping a roster card open ──────────────────────────────────────
    // The tap rebuilds the roster only; the card is laid out at its full
    // height while the frame round it grows over 160 ms.
    await tester.tap(find.byKey(const ValueKey('species-card-Let')));
    final expandTap = await _countFrame(
      tester,
      () => tester.pump(const Duration(milliseconds: 16)),
    );
    final expandMid = await _countFrame(
      tester,
      () => tester.pump(const Duration(milliseconds: 48)),
    );
    await settleLobby(tester, 12);
    // The card is laid out at its full height and revealed: no overflow.
    final expandOverflow = tester.takeException();

    // ── One frame mid-scroll, with the card open so the lobby scrolls ────
    // Within the scroll's range: past either end, Android stretches the
    // whole page, which repaints everything and measures the stretch.
    final scroll = lobbyScroll(tester);
    final extent = scroll.position.maxScrollExtent;
    // ignore: avoid_print
    print('lobby scroll extent: $extent');
    scroll.position.jumpTo(extent * 0.3);
    await tester.pump(const Duration(milliseconds: 16));
    final scrolled = await _countFrame(tester, () async {
      scroll.position.jumpTo(extent * 0.6);
      await tester.pump(const Duration(milliseconds: 16));
    });
    scroll.position.jumpTo(0);
    await settleLobby(tester, 12);

    await tester.tap(find.byKey(const ValueKey('species-card-Let')));
    await settleLobby(tester, 12);
    tester.takeException();

    // ignore: avoid_print
    print(
      '\nSURVIVAL LOBBY PROBE (475x751 @3x)\n'
      'portraits built: $portraits, decoded for the census: $imagesResolved\n'
      'spinner frames before the lobby: $spinnerFrames\n'
      'first lobby frame: ${firstFrameMicros / 1000} ms in a debug widget '
      'test (not raster), ${firstLobbyFrame?.rebuilt} widgets built, '
      '${firstLobbyFrame?.painted} render objects painted\n'
      'next 15 frames: $lateScreenRebuilds whole-screen rebuilds, '
      '$lateWidgets widgets rebuilt in all\n'
      'idle: frame scheduled after settle = $scheduledWhenIdle, '
      'transient callbacks (tickers) = $tickers\n'
      'idle frame: $idle\n'
      'idle census: draws ${idleCensus.census.draws}, '
      'blurred ${idleCensus.census.blurred}, '
      'saveLayer ${idleCensus.census.counts['saveLayer'] ?? 0}\n'
      '  ${idleCensus.census.counts}\n  ${idleCensus.layers}\n'
      'draws by CustomPainter: $byPainter\n'
      'swipe frame: $swipe\n'
      'scroll frame: $scrolled\n'
      'expand tap frame: $expandTap\n'
      'expand mid-animation frame: $expandMid\n'
      'expand overflowed mid-animation: ${expandOverflow != null}\n',
    );

    // Only the stage ticks; an idle frame repaints it and nothing else.
    expect(tickers, 1);
    expect(idle.rebuilt, 0);
    expect(idle.painted, lessThanOrEqualTo(3));
    // Scrolling moves the page's layer instead of re-recording it.
    expect(scrolled.painted, lessThanOrEqualTo(6));
    // Opening a card rebuilds the roster, not the screen, and never
    // overflows on the way.
    expect(expandTap.rebuilt, lessThan(180));
    expect(expandOverflow, isNull);
    // Loose ceilings on what was measured, so a regression shows.
    expect(idleCensus.census.draws, lessThan(260));
    expect(idleCensus.census.blurred, 0);
    expect(idleCensus.census.counts['saveLayer'] ?? 0, 0);

    await save.dispose(tester);
  });
}
