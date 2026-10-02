// lib/widgets/fx/codex_stage.dart
//
// THE CODEX'S STAGE: one thing at a time under dark glass — an element's
// orb, or a species — and what it does.
//
//   Tap it and it comes apart into its element and gathers back, as an
//   Alchemon does on its details ([EssenceField]).
//
//   Play a formula and its two makers stand either side, pour together into
//   one cloud as the fusion chamber's merge does ([FusionParticleField]),
//   and what they make gathers out of the bloom ([EssenceField.reveal]).
//
// Plain Dart bodies and fields on one ticker, which only runs while
// something moves: an orb turning, a play. A species at rest is a still
// picture and costs nothing.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Something the stage can show: what it is made of, and how it looks at
/// rest.
abstract class CodexBody {
  /// The element it comes apart into ('Fire'…).
  String get element;

  /// Its light, for the merge's glow.
  Color get color;

  /// Not yet known: shown, never played.
  bool get locked;

  /// Whether it moves at rest, and so needs the ticker.
  bool get turns;

  /// Its grains as they stand at rest time [t], centred on it.
  SpecimenGrains grainsAt(double t);

  /// Paints it at rest round [c]. [opacity] is how solid it is while a
  /// field crosses over to its grains; [grains] false leaves those to the
  /// field. [fade] dims all of it, [scale] draws it smaller (a formula's
  /// makers).
  void paint(
    Canvas canvas,
    Offset c,
    double t, {
    double opacity = 1,
    bool grains = true,
    double fade = 1,
    double scale = 1,
  });
}

/// An element, as its orb.
class OrbBody implements CodexBody {
  OrbBody(this.element, {required double radius, this.locked = false})
    : orb = ElementOrb(
        EssenceElement.of(element),
        radius: radius,
        locked: locked,
      );

  final ElementOrb orb;

  @override
  final String element;

  @override
  final bool locked;

  @override
  Color get color => orb.color;

  @override
  bool get turns => true;

  @override
  SpecimenGrains grainsAt(double t) => orb.grainsAt(t);

  @override
  void paint(
    Canvas canvas,
    Offset c,
    double t, {
    double opacity = 1,
    bool grains = true,
    double fade = 1,
    double scale = 1,
  }) {
    if (scale == 1) {
      orb.paint(canvas, c, t, opacity: opacity, grains: grains, fade: fade);
      return;
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    orb.paint(
      canvas,
      Offset.zero,
      t,
      opacity: opacity,
      grains: grains,
      fade: fade,
    );
    canvas.restore();
  }
}

/// A species, as its portrait — and the grains it was read into.
class PortraitBody implements CodexBody {
  PortraitBody._(
    this._image,
    this._grains,
    this.element,
    this.color,
    this.locked,
  );

  final ui.Image _image;
  final SpecimenGrains _grains;

  @override
  final String element;

  @override
  final Color color;

  @override
  final bool locked;

  @override
  bool get turns => false;

  static const double _ratio = 2;
  static final Map<String, Future<PortraitBody?>> _cache = {};

  /// Reads the portrait at [asset] at [height] logical px tall. Null if it
  /// would not load.
  static Future<PortraitBody?> load(
    String asset, {
    required double height,
    required String element,
    required Color color,
    bool locked = false,
  }) {
    final key = '$asset|${height.round()}|$element|$locked';
    return _cache[key] ??= _read(asset, height, element, color, locked);
  }

  static Future<PortraitBody?> _read(
    String asset,
    double height,
    String element,
    Color color,
    bool locked,
  ) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetHeight: (height * _ratio).round(),
      );
      final image = (await codec.getNextFrame()).image;
      // A locked one is only ever a shadow: nothing to read.
      var grains = SpecimenGrains.points(
        Float32List(0),
        Float32List(0),
        Uint8List(0),
        const [],
        1,
      );
      if (!locked) {
        final rgba = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (rgba != null) {
          grains = SpecimenGrains.fromRgba(
            rgba.buffer.asUint8List(),
            image.width,
            image.height,
            pixelRatio: _ratio,
            maxGrains: 2200,
            tones: 16,
          );
        }
      }
      return PortraitBody._(image, grains, element, color, locked);
    } catch (_) {
      return null;
    }
  }

  static final Paint _p = Paint()..filterQuality = FilterQuality.medium;
  static const ColorFilter _shadow = ColorFilter.mode(
    Color(0xFF2E3440),
    BlendMode.srcIn,
  );

  @override
  SpecimenGrains grainsAt(double t) => _grains;

  @override
  void paint(
    Canvas canvas,
    Offset c,
    double t, {
    double opacity = 1,
    bool grains = true,
    double fade = 1,
    double scale = 1,
  }) {
    final a = (opacity * fade).clamp(0.0, 1.0);
    if (a <= 0) return;
    final w = _image.width / _ratio * scale;
    final h = _image.height / _ratio * scale;
    _p
      ..color = Color.fromRGBO(0, 0, 0, a)
      ..colorFilter = locked ? _shadow : null;
    canvas.drawImageRect(
      _image,
      Rect.fromLTWH(0, 0, _image.width.toDouble(), _image.height.toDouble()),
      Rect.fromCenter(center: c, width: w, height: h),
      _p,
    );
    _p.colorFilter = null;
  }
}

/// What the stage is asked to do. The sheet showing it owns one.
class CodexStageController extends ChangeNotifier {
  CodexBody? _subject;
  _Ask? _ask;
  Object? _playing;
  bool _busy = false;

  /// What is on the stage, or will be once a play ends.
  CodexBody? get subject => _subject;

  /// Whether a play is running.
  bool get busy => _busy;

  /// The formula playing now, as it was handed to [combine].
  Object? get playing => _playing;

  /// Puts [body] on the stage; with [reveal], its element gathers into it.
  void show(CodexBody body, {bool reveal = false}) {
    _subject = body;
    _ask = _Ask.show(body, reveal: reveal);
    notifyListeners();
  }

  /// It comes apart into its element and back.
  void play() {
    _ask = const _Ask.play();
    notifyListeners();
  }

  /// [a] and [b] fuse, and [result] gathers out of them and stays on.
  /// [tag] names the formula, for whoever is lighting its row.
  void combine(
    CodexBody a,
    CodexBody b,
    CodexBody result, {
    Object? tag,
    VoidCallback? onDone,
  }) {
    _subject = result;
    _ask = _Ask.combine(a, b, result, tag: tag, onDone: onDone);
    notifyListeners();
  }

  void _setBusy(bool busy, [Object? tag]) {
    if (_busy == busy && _playing == tag) return;
    _busy = busy;
    _playing = tag;
    notifyListeners();
  }
}

enum _AskKind { show, play, combine }

class _Ask {
  const _Ask.play()
    : kind = _AskKind.play,
      body = null,
      reveal = false,
      a = null,
      b = null,
      tag = null,
      onDone = null;

  const _Ask.show(CodexBody this.body, {required this.reveal})
    : kind = _AskKind.show,
      a = null,
      b = null,
      tag = null,
      onDone = null;

  const _Ask.combine(
    CodexBody this.a,
    CodexBody this.b,
    CodexBody this.body, {
    this.tag,
    this.onDone,
  }) : kind = _AskKind.combine,
       reveal = false;

  final _AskKind kind;
  final CodexBody? body, a, b;
  final bool reveal;
  final Object? tag;
  final VoidCallback? onDone;
}

enum _Mode { rest, essence, combo }

/// The stage. Size it; it draws round its centre.
class CodexStage extends StatefulWidget {
  const CodexStage({super.key, required this.controller, this.onTap});

  final CodexStageController controller;

  /// Called on a tap that did not start a play (a locked subject, or one
  /// already running).
  final VoidCallback? onTap;

  @override
  State<CodexStage> createState() => _CodexStageState();
}

class _CodexStageState extends State<CodexStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;

  _Mode _mode = _Mode.rest;
  CodexBody? _subject;
  double _rest = 0;

  // A play.
  EssenceField? _field;
  double _t = 0;

  // A formula.
  CodexBody? _a, _b, _from;
  FusionParticleField? _merge;
  EssenceField? _reveal;
  double _comboT = 0;
  Object? _tag;
  VoidCallback? _onDone;
  bool _landed = false;
  Size _size = Size.zero;

  /// The makers drawn this much of the subject's size.
  static const double _makerScale = 0.62;

  /// They stand, then pour; the bloom is where what they make begins.
  static const double _standFor = 0.45;
  static const double _revealFrom = 2.3;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onAsk);
    _onAsk();
  }

  @override
  void didUpdateWidget(CodexStage old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onAsk);
      widget.controller.addListener(_onAsk);
      _onAsk();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onAsk);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onAsk() {
    final ask = widget.controller._ask;
    if (ask == null) return;
    widget.controller._ask = null;
    switch (ask.kind) {
      case _AskKind.show:
        _finishCombo(notify: false);
        _subject = ask.body;
        _rest = 0;
        _mode = _Mode.rest;
        _field = null;
        widget.controller._setBusy(false);
        if (ask.reveal && !(ask.body!.locked)) {
          _startEssence(reveal: true);
        }
      case _AskKind.play:
        if (_mode != _Mode.rest) return;
        _startEssence();
      case _AskKind.combine:
        _finishCombo(notify: false);
        _from = _mode == _Mode.rest ? _subject : null;
        _a = ask.a;
        _b = ask.b;
        _subject = ask.body;
        _tag = ask.tag;
        _onDone = ask.onDone;
        _merge = null;
        _reveal = null;
        _field = null;
        _comboT = 0;
        _landed = false;
        _mode = _Mode.combo;
        HapticFeedback.selectionClick();
        widget.controller._setBusy(true, _tag);
    }
    _wake();
  }

  void _startEssence({bool reveal = false}) {
    final s = _subject;
    if (s == null || s.locked) return;
    final grains = s.grainsAt(_rest);
    if (grains.length == 0) return;
    _field = EssenceField(grains, EssenceElement.of(s.element))
      ..reveal = reveal;
    _t = reveal ? EssenceField.revealStart : 0;
    _mode = _Mode.essence;
    _landed = false;
    if (!reveal) HapticFeedback.lightImpact();
    widget.controller._setBusy(true);
  }

  void _finishCombo({bool notify = true}) {
    if (_mode != _Mode.combo) return;
    final done = _onDone;
    _a = _b = _from = null;
    _merge = null;
    _reveal = null;
    _onDone = null;
    _tag = null;
    _mode = _Mode.rest;
    _rest = 0;
    if (notify) {
      widget.controller._setBusy(false);
      done?.call();
    }
  }

  void _wake() {
    final moving = _mode != _Mode.rest || (_subject?.turns ?? false);
    if (moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!moving && _ticker.isActive) {
      _ticker.stop();
    }
    _frame.value++;
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    switch (_mode) {
      case _Mode.rest:
        _rest += dt;
      case _Mode.essence:
        _t += dt;
        if (!_landed && _t > 2.2) {
          _landed = true;
          HapticFeedback.lightImpact();
        }
        if (_t >= EssenceField.duration) {
          _field = null;
          _mode = _Mode.rest;
          widget.controller._setBusy(false);
        }
      case _Mode.combo:
        _stepCombo(dt);
    }
    _wake();
  }

  Offset get _centre => _size.center(Offset.zero);
  double get _spread => math.min(_size.width * 0.28, 120);
  Offset get _leftAt => _centre - Offset(_spread, 0);
  Offset get _rightAt => _centre + Offset(_spread, 0);

  double get _mergeT => FusionParticleField.standTime + (_comboT - _standFor);

  void _stepCombo(double dt) {
    _comboT += dt;
    if (_merge == null && _comboT >= _standFor && _size != Size.zero) {
      final a = _a!, b = _b!;
      final ga = a.grainsAt(_comboT), gb = b.grainsAt(_comboT);
      if (ga.length == 0 || gb.length == 0) {
        _finishCombo();
        return;
      }
      _merge = FusionParticleField(
        specimens: [ga, gb],
        centres: [_leftAt, _rightAt],
        scales: const [_makerScale, _makerScale],
        core: _centre,
        coreRadius: _coreRadius,
        colors: [a.color, b.color],
      );
    }
    if (_merge != null && _reveal == null && _mergeT >= _revealFrom) {
      final s = _subject!;
      final grains = s.grainsAt(0);
      if (grains.length == 0) {
        _finishCombo();
        return;
      }
      _reveal = EssenceField(grains, EssenceElement.of(s.element))
        ..reveal = true;
    }
    if (_reveal != null) {
      final rt = _revealT;
      if (!_landed && rt > 2.2) {
        _landed = true;
        HapticFeedback.lightImpact();
      }
      if (rt >= EssenceField.duration) _finishCombo();
    }
  }

  double get _revealT => EssenceField.revealStart + (_mergeT - _revealFrom);

  double get _coreRadius => math.min(_size.height * 0.2, 46);

  void _paint(Canvas canvas, Size size) {
    _size = size;
    final c = _centre;
    switch (_mode) {
      case _Mode.rest:
        _subject?.paint(canvas, c, _rest);
      case _Mode.essence:
        final f = _field!;
        _subject?.paint(
          canvas,
          c,
          _rest,
          opacity: EssenceField.spriteOpacity(_t),
          grains: false,
        );
        f.paint(canvas, c, _t);
      case _Mode.combo:
        _paintCombo(canvas, c);
    }
  }

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void _paintCombo(Canvas canvas, Offset c) {
    final a = _a, b = _b;
    if (a == null || b == null) return;
    final merge = _merge;
    if (merge == null) {
      // The two makers come up either side as what was there goes.
      final u = _smooth(_comboT / _standFor);
      _from?.paint(canvas, c, _rest, fade: 1 - u);
      a.paint(canvas, _leftAt, _comboT, opacity: u, scale: _makerScale);
      b.paint(canvas, _rightAt, _comboT, opacity: u, scale: _makerScale);
      return;
    }
    final mt = _mergeT;
    // Their glass goes as the merge takes their grains.
    final hold = 1 - _smooth((mt - FusionParticleField.standTime) / 0.14);
    if (hold > 0) {
      a.paint(
        canvas,
        _leftAt,
        _comboT,
        opacity: hold,
        grains: false,
        scale: _makerScale,
      );
      b.paint(
        canvas,
        _rightAt,
        _comboT,
        opacity: hold,
        grains: false,
        scale: _makerScale,
      );
    }
    final reveal = _reveal;
    if (reveal != null) {
      final rt = _revealT;
      _subject?.paint(
        canvas,
        c,
        0,
        opacity: EssenceField.spriteOpacity(rt),
        grains: false,
      );
      reveal.paint(canvas, c, rt);
    }
    if (mt < FusionParticleField.duration) {
      merge.paint(canvas, mt, back: true);
      merge.paint(canvas, mt, back: false);
    }
  }

  void _onTap() {
    final s = _subject;
    if (_mode == _Mode.rest && s != null && !s.locked) {
      _startEssence();
      _wake();
      return;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: CustomPaint(painter: _StagePainter(this), size: Size.infinite),
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.state) : super(repaint: state._frame);

  final _CodexStageState state;

  @override
  void paint(Canvas canvas, Size size) => state._paint(canvas, size);

  @override
  bool shouldRepaint(_StagePainter old) => old.state != state;
}
