// lib/screens/cosmic/widgets/load_hold_panel.dart
//
// LOAD THE HOLD: home storage into the ship. Gates take only what the ship
// carries, so this is where a gate's pattern gets packed — one FILL per
// sealed gate the ship has found, or element by element by hand. The bar at
// the top is the hold as it will leave: what it already carries, then what
// is being added, in each element's colour, with the shares a gate reads.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/hold_loading.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cosmic_overlay_chrome.dart';
import 'cosmic_panel_kit.dart';
import 'cosmic_screen_styles.dart';

/// A sealed gate the ship has found, and the pattern it wants.
class GatePattern {
  const GatePattern({required this.planetName, required this.recipe});
  final String planetName;
  final PlanetRecipe recipe;
}

/// What LOAD sends back: units per element, and whether the hold's cargo
/// goes back to storage before they go in.
typedef HoldLoadPlan = ({Map<String, int> units, bool emptyFirst});

const _accent = CosmicScreenStyles.amberBright;

/// How much one tap of a stepper moves.
const int _step = 5;

class LoadHoldPanel extends StatefulWidget {
  const LoadHoldPanel({
    super.key,
    required this.stored,
    required this.hold,
    required this.patterns,
    required this.onLoad,
    this.capacity = ElementMeter.maxCapacityUnits,
  });

  /// Home storage.
  final Map<String, double> stored;

  /// What the hold carries now.
  final Map<String, double> hold;
  final int capacity;
  final List<GatePattern> patterns;
  final ValueChanged<HoldLoadPlan> onLoad;

  @override
  State<LoadHoldPanel> createState() => _LoadHoldPanelState();
}

class _LoadHoldPanelState extends State<LoadHoldPanel> {
  final Map<String, int> _plan = {};
  bool _emptyFirst = false;

  /// The pattern the plan was filled from, while it is unchanged.
  String? _fromPattern;

  double get _holdTotal =>
      widget.hold.values.fold(0.0, (s, v) => s + (v > 0 ? v : 0));

  int get _planned => _plan.values.fold(0, (s, v) => s + v);

  /// What the hold carries before the plan goes in.
  double get _base => _emptyFirst ? 0 : _holdTotal;

  int get _room => (widget.capacity - _base - _planned).floor().clamp(0, 9999);

  /// What can be taken of [element]: storage, plus the hold's own cargo when
  /// it goes back first.
  double _have(String element) =>
      (widget.stored[element] ?? 0) +
      (_emptyFirst ? (widget.hold[element] ?? 0) : 0);

  List<String> get _elements {
    final keys = <String>{
      for (final e in widget.stored.entries)
        if (e.value >= 1 && isKnownElement(e.key)) e.key,
      if (_emptyFirst)
        for (final e in widget.hold.entries)
          if (e.value >= 1 && isKnownElement(e.key)) e.key,
      ..._plan.keys,
    };
    final list = keys.toList()..sort((a, b) => _have(b).compareTo(_have(a)));
    return list;
  }

  void _bump(String element, int by) {
    final now = _plan[element] ?? 0;
    final most = _have(element).floor();
    var next = now + by;
    if (by > 0) next = next.clamp(0, now + _room).clamp(0, most);
    if (next < 0) next = 0;
    if (next == now) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _fromPattern = null;
      if (next == 0) {
        _plan.remove(element);
      } else {
        _plan[element] = next;
      }
    });
  }

  void _all(String element) {
    final now = _plan[element] ?? 0;
    final most = _have(element).floor();
    final next = (now + _room).clamp(0, most);
    HapticFeedback.selectionClick();
    setState(() {
      _fromPattern = null;
      if (next <= 0) {
        _plan.remove(element);
      } else {
        _plan[element] = next;
      }
    });
  }

  Map<String, int>? _patternPlan(GatePattern p) => planGateLoad(
    p.recipe,
    addElementMaps(widget.stored, widget.hold),
    capacity: widget.capacity,
  );

  void _fill(GatePattern p) {
    final plan = _patternPlan(p);
    if (plan == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _plan
        ..clear()
        ..addAll(plan);
      _emptyFirst = _holdTotal > 0;
      _fromPattern = p.planetName;
    });
  }

  void _clear() {
    HapticFeedback.selectionClick();
    setState(() {
      _plan.clear();
      _emptyFirst = false;
      _fromPattern = null;
    });
  }

  void _load() {
    if (_planned <= 0) return;
    widget.onLoad((units: Map.of(_plan), emptyFirst: _emptyFirst));
  }

  @override
  Widget build(BuildContext context) {
    void close() {
      HapticFeedback.lightImpact();
      Navigator.of(context).maybePop();
    }

    final elements = _elements;
    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: close,
        alpha: 0.96,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Column(
            children: [
              PanelHeader(title: 'LOAD SHIP', onClose: close),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: _HoldBar(
                  hold: _emptyFirst ? const {} : widget.hold,
                  plan: _plan,
                  capacity: widget.capacity,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  children: [
                    if (widget.patterns.isNotEmpty) ...[
                      const PanelSectionHeader('GATE PATTERNS'),
                      for (final p in widget.patterns) _patternRow(p),
                      const SizedBox(height: 12),
                    ],
                    PanelSectionHeader(
                      'FROM STORAGE',
                      trailing: '${panelFmt(_room)} ROOM',
                    ),
                    if (elements.isEmpty)
                      Text(
                        'NOTHING STORED YET',
                        style: panelLabel(10.5, panelPalette.muted),
                      )
                    else
                      for (final e in elements) _elementRow(e),
                    if (_emptyFirst) ...[
                      const SizedBox(height: 10),
                      Text(
                        'THE SHIP\'S CARGO GOES BACK TO STORAGE FIRST',
                        style: panelLabel(9.5, _accent.withValues(alpha: 0.8)),
                      ),
                    ],
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

  Widget _patternRow(GatePattern p) {
    final plan = _patternPlan(p);
    final chosen = _fromPattern == p.planetName;
    final shares = p.recipe.components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          PanelDot(elementInk(p.recipe.planetElement), size: 9),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.planetName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelLabel(11, panelPalette.ink, spacing: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    for (final s in shares)
                      '${s.key.toUpperCase()} ${s.value.round()}%',
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelLabel(9, panelPalette.muted, spacing: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 124,
            child: BracketButton(
              key: ValueKey('loadHold.fill.${p.recipe.planetElement}'),
              label: chosen ? 'FILLED' : (plan == null ? 'NOT ENOUGH' : 'FILL'),
              height: 34,
              palette: panelPalette,
              accent: elementInk(p.recipe.planetElement),
              primary: false,
              enabled: plan != null && !chosen,
              onTap: () => _fill(p),
            ),
          ),
        ],
      ),
    );
  }

  Widget _elementRow(String e) {
    final ink = elementInk(e);
    final planned = _plan[e] ?? 0;
    final have = _have(e);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          PanelDot(ink),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              e.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: panelLabel(10.5, ink, spacing: 0.6),
            ),
          ),
          Text(
            panelFmt(have - planned),
            style: panelLabel(10, panelPalette.muted, spacing: 0.4),
          ),
          const SizedBox(width: 10),
          _StepButton(
            key: ValueKey('loadHold.less.$e'),
            label: '−',
            enabled: planned > 0,
            onTap: () => _bump(e, -_step),
          ),
          SizedBox(
            width: 44,
            child: Text(
              planned == 0 ? '—' : panelFmt(planned),
              textAlign: TextAlign.center,
              style: panelLabel(
                12,
                planned == 0 ? panelPalette.muted : panelPalette.ink,
                spacing: 0.4,
              ),
            ),
          ),
          _StepButton(
            key: ValueKey('loadHold.more.$e'),
            label: '+',
            enabled: _room > 0 && planned < have.floor(),
            onTap: () => _bump(e, _step),
          ),
          const SizedBox(width: 6),
          _StepButton(
            key: ValueKey('loadHold.all.$e'),
            label: 'ALL',
            wide: true,
            enabled: _room > 0 && planned < have.floor(),
            onTap: () => _all(e),
          ),
        ],
      ),
    );
  }

  Widget _dock() {
    final planned = _planned;
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
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: BracketButton(
                key: const ValueKey('loadHold.clear'),
                label: 'CLEAR',
                height: 46,
                palette: panelPalette,
                accent: _accent,
                primary: false,
                enabled: planned > 0 || _emptyFirst,
                onTap: _clear,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BracketButton(
                key: const ValueKey('loadHold.load'),
                label: planned > 0 ? 'LOAD ${panelFmt(planned)}' : 'LOAD',
                height: 46,
                palette: panelPalette,
                accent: _accent,
                enabled: planned > 0,
                onTap: _load,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.wide = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final ink = enabled ? panelPalette.ink : panelPalette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? context.soundAction(onTap) : null,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: panelPalette.line.withValues(alpha: enabled ? 0.7 : 0.3),
          bracketSize: 5,
        ),
        child: Container(
          width: wide ? 40 : 30,
          height: 30,
          alignment: Alignment.center,
          color: panelPalette.bg1.withValues(alpha: 0.6),
          child: Text(
            label,
            style: panelLabel(wide ? 9.5 : 14, ink, spacing: wide ? 0.8 : 0),
          ),
        ),
      ),
    );
  }
}

/// The hold as it will leave: what it carries (dim), what is going in
/// (lit), then the room left, with each element's share of the whole.
class _HoldBar extends StatelessWidget {
  const _HoldBar({
    required this.hold,
    required this.plan,
    required this.capacity,
  });

  final Map<String, double> hold;
  final Map<String, int> plan;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final after = <String, double>{};
    for (final e in hold.entries) {
      if (e.value > 0) after[e.key] = e.value;
    }
    for (final e in plan.entries) {
      after[e.key] = (after[e.key] ?? 0) + e.value;
    }
    final total = after.values.fold(0.0, (s, v) => s + v);
    final shares = after.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('CARGO', style: panelLabel(10.5, panelPalette.muted)),
            const Spacer(),
            Text(
              '${panelFmt(total)}/${panelFmt(capacity)}',
              style: panelLabel(
                11,
                total >= capacity - 0.5 ? _accent : panelPalette.ink,
                spacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 12,
          width: double.infinity,
          child: CustomPaint(
            painter: _HoldBarPainter(
              hold: hold,
              plan: plan,
              capacity: capacity.toDouble(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 14,
          child: total <= 0
              ? Text('EMPTY', style: panelLabel(9, panelPalette.muted))
              : Wrap(
                  spacing: 12,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (final s in shares.take(5))
                      Text(
                        '${s.key.toUpperCase()} '
                        '${(s.value / total * 100).round()}%',
                        style: panelLabel(9, elementInk(s.key), spacing: 0.5),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HoldBarPainter extends CustomPainter {
  _HoldBarPainter({
    required this.hold,
    required this.plan,
    required this.capacity,
  });

  final Map<String, double> hold;
  final Map<String, int> plan;
  final double capacity;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = panelPalette.lineSoft;
    canvas.drawRect(Offset.zero & size, bg);
    var x = 0.0;
    void seg(String e, double units, double alpha) {
      if (units <= 0) return;
      final w = size.width * (units / capacity);
      canvas.drawRect(
        Rect.fromLTWH(x, 0, w, size.height),
        Paint()..color = elementColor(e).withValues(alpha: alpha),
      );
      x += w;
    }

    final held = hold.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in held) {
      seg(e.key, e.value, 0.42);
    }
    final going = plan.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in going) {
      seg(e.key, e.value.toDouble(), 0.95);
    }
    // Ten ticks, so a share can be read against the gate's percentages.
    final tick = Paint()..color = CosmicScreenStyles.bg0.withValues(alpha: 0.7);
    for (var i = 1; i < 10; i++) {
      final tx = size.width * i / 10;
      canvas.drawRect(Rect.fromLTWH(tx - 0.5, 0, 1, size.height), tick);
    }
  }

  @override
  bool shouldRepaint(_HoldBarPainter old) => true;
}
