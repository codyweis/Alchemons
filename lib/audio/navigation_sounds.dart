import 'package:flutter/widgets.dart';
import 'package:alchemons/audio/audio.dart';

final navigationSoundObserver = NavigationSoundObserver();

/// Route feedback includes dialogs dismissed by back or by their barrier.
class NavigationSoundObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && route is PopupRoute) {
      navigator?.context.sound(SoundCue.uiPanelOpen);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      navigator?.context.sound(
        route is PopupRoute ? SoundCue.uiPanelClose : SoundCue.uiBack,
      );
    }
  }
}
