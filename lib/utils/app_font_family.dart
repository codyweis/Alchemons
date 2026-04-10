import 'package:flutter/material.dart';

String? appFontFamily(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return textTheme.bodyMedium?.fontFamily ??
      textTheme.bodyLarge?.fontFamily ??
      textTheme.titleMedium?.fontFamily;
}
