import 'package:flutter/widgets.dart';

/// Returns an adaptive cross-axis count for grid layouts based on the
/// available width.  [phoneCols] is the default column count used on phones;
/// the function scales up from there on wider screens (tablets / iPads).
int responsiveCrossAxisCount(BuildContext context, {int phoneCols = 3}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1024) return phoneCols + 3; // large iPad landscape
  if (width >= 768) return phoneCols + 2;  // iPad portrait / small landscape
  if (width >= 600) return phoneCols + 1;  // large phones / small tablets
  return phoneCols;
}
