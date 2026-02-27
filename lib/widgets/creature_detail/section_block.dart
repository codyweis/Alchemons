import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

/// Forge-style section block.
/// [theme] is accepted for API compatibility but visual style uses Forge tokens.
class SectionBlock extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final String title;
  final Widget child;
  final Color? accentColor;

  const SectionBlock({
    super.key,
    this.theme,
    required this.title,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ForgeSection(title: title, accentColor: accentColor, child: child);
  }
}
