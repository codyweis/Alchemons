import 'package:flutter/material.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';

/// Canonical amber-rhythm section box used across battle UIs.
///
/// A small color swatch + uppercase title, a 1px divider, then the content.
/// Established in the creature_detail battle tab; promoted here so boss
/// battle screens share the same visual language.
class BattleSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;

  const BattleSection({
    super.key,
    required this.title,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 10, color: color),
            const SizedBox(width: 7),
            Text(
              title.toUpperCase(),
              style: ft.sectionTitle.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(height: 1, color: fc.borderDim),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
