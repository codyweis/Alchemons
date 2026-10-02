// lib/screens/mystic_altar/altar_chrome.dart
//
// The altar's words and buttons, in the bracket language the market and the
// rift use: dark in either theme, monospace labels, element colour only as
// an accent. The one control of its own is the hold — setting a relic,
// giving an offering and performing the rite each cost something that does
// not come back, so each is held rather than tapped, and letting go early
// spends nothing.

import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const BracketPalette altarPalette = BracketPalette.dark;

/// A small capitals label: overlines, counts, button words.
TextStyle altarMono(
  double size,
  Color color, {
  double spacing = 1.8,
  FontWeight weight = FontWeight.w800,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: 1.25,
);

/// A Mystic's name.
TextStyle altarName(BuildContext context, double size) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: AltarTone.parchment,
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      height: 1.1,
    );

/// Plain sentences under it.
TextStyle altarBody(BuildContext context, {Color? color, double size = 13}) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: color ?? AltarTone.parchmentDim,
      fontSize: size,
      height: 1.45,
    );

/// Hold to do something that cannot be undone. The bracket fills as it is
/// held; let go early and it drains away, nothing done. [onProgress] reports
/// the fill, so the altar can answer the hold as it happens.
class AltarHoldButton extends StatefulWidget {
  const AltarHoldButton({
    super.key,
    required this.label,
    required this.holdingLabel,
    required this.accent,
    required this.onComplete,
    this.onProgress,
    this.seconds = 1.2,
    this.enabled = true,
    this.height = 50,
  });

  final String label, holdingLabel;
  final Color accent;
  final VoidCallback onComplete;
  final ValueChanged<double>? onProgress;
  final double seconds;
  final bool enabled;
  final double height;

  @override
  State<AltarHoldButton> createState() => _AltarHoldButtonState();
}

class _AltarHoldButtonState extends State<AltarHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.seconds * 1000).round()),
    reverseDuration: const Duration(milliseconds: 320),
  );
  int _ticks = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_done) {
        _done = true;
        HapticFeedback.heavyImpact();
        widget.onComplete();
      }
    });
  }

  void _changed() {
    widget.onProgress?.call(_c.value);
    // A tick at each third, so the hold is felt as well as seen.
    final ticks = (_c.value * 3).floor();
    if (_c.status == AnimationStatus.forward && ticks > _ticks && ticks < 3) {
      HapticFeedback.lightImpact();
    }
    _ticks = ticks;
  }

  @override
  void didUpdateWidget(AltarHoldButton old) {
    super.didUpdateWidget(old);
    // A fresh label is a fresh hold (the next offering, say).
    if (old.label != widget.label) {
      _done = false;
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    if (!widget.enabled || _done) return;
    HapticFeedback.selectionClick();
    _c.forward();
  }

  void _up() {
    if (_done) return;
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            return CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: accent.withValues(alpha: 0.55 + 0.45 * v),
                bracketSize: 11,
                strokeWidth: 1.3,
              ),
              child: Container(
                height: widget.height,
                color: altarPalette.accentWash(accent, darkAlpha: 0.1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.08),
                              accent.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        v > 0 ? widget.holdingLabel : widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: altarMono(
                          13,
                          Color.lerp(AltarTone.parchment, Colors.white, v)!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
