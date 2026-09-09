import 'package:flutter/widgets.dart';

final navigationSoundObserver = NavigationSoundObserver();

/// Opening and closing a route is navigation, not an event worth hearing.
///
/// This used to play uiPanelOpen on every dialog and uiPanelClose / uiBack on
/// every dismissal, on top of the tap that caused it — so a single "open a
/// sheet, close it again" made three sounds. The tap itself now carries a
/// haptic, and the observer stays only as the hook for any route that later
/// earns a sound of its own.
class NavigationSoundObserver extends NavigatorObserver {}
