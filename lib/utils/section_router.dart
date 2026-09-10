import 'package:alchemons/widgets/nav_bar.dart';

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
  void Function(NavSection section)? onSwitchSection;

  bool get available => onSwitchSection != null;

  void go(NavSection section) => onSwitchSection?.call(section);
}
