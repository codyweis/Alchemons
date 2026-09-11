import 'package:alchemons/widgets/nav_bar.dart';

/// Which of a destination's own modes to land in, for the tabs that have
/// more than one thing behind them.
///
/// [none] means "wherever that tab was left", which is what every in-app
/// "Go" button wants. A deep link does not have that luxury: it names a
/// specific thing the player was told is waiting, so it has to say which.
enum SectionFocus {
  none,

  /// The breed tab's cultivations side — the vials in progress.
  cultivations,
}

/// Lets a pushed screen ask the shell to change tab.
///
/// The shell owns the tab index and nothing above it can reach that, so a
/// "Go" button on a pushed screen has no way to land on Shop or Inventory.
/// The discovery reveal already needed this and solved it with a callback on
/// a singleton; this is the same trick, named for what it does, so the two
/// uses do not have to share one field.
class SectionRouter {
  SectionRouter._();
  static final SectionRouter instance = SectionRouter._();

  /// Set by the shell in initState, cleared when it goes away.
  void Function(NavSection section, {SectionFocus focus})? onSwitchSection;

  /// A request that arrived before the shell existed.
  ///
  /// A notification tap can cold-start the app, and the launch payload is
  /// read while the widget tree is still being built. Dropping it on the
  /// floor is how a deep link turns into "it just opens the game", so it
  /// waits here until the shell calls [drainPending].
  (NavSection, SectionFocus)? _pending;

  bool get available => onSwitchSection != null;

  void go(NavSection section, {SectionFocus focus = SectionFocus.none}) {
    final handler = onSwitchSection;
    if (handler == null) {
      _pending = (section, focus);
      return;
    }
    handler(section, focus: focus);
  }

  /// Replays a request that was made before the shell could route it.
  /// Safe to call on every launch; it does nothing when nothing is waiting.
  void drainPending() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    onSwitchSection?.call(pending.$1, focus: pending.$2);
  }
}
