import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const Duration kFastLongPressTimeout = Duration(milliseconds: 250);

class FastLongPressDetector extends StatelessWidget {
  final Widget child;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final HitTestBehavior behavior;

  const FastLongPressDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.deferToChild,
  });

  @override
  Widget build(BuildContext context) {
    if (onLongPress == null) {
      return GestureDetector(behavior: behavior, onTap: onTap, child: child);
    }

    final gestures = <Type, GestureRecognizerFactory>{
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: kFastLongPressTimeout,
              debugOwner: this,
            ),
            (instance) {
              instance.onLongPress = onLongPress;
            },
          ),
    };

    if (onTap != null) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(debugOwner: this),
            (instance) {
              instance.onTap = onTap;
            },
          );
    }

    return RawGestureDetector(
      behavior: behavior,
      gestures: gestures,
      child: child,
    );
  }
}
