import 'package:flutter/material.dart';

class Silhouette extends StatelessWidget {
  final Widget child;
  final bool enabled;
  const Silhouette({super.key, required this.child, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!enabled) return child;
    final color = theme.brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
        : Colors.black.withOpacity(0.8);
    // SRC_IN = use the child's alpha as a mask, fill with black.
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: child,
    );
  }
}
