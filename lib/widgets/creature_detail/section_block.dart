import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

class SectionBlock extends StatelessWidget {
  final FactionTheme theme;
  final String title;
  final Widget child;

  const SectionBlock({
    required this.theme,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.border),
          ),
          child: child,
        ),
      ],
    );
  }
}
