import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showAppSnack(
  String message, {
  bool isError = false,
  BuildContext? fallbackContext,
}) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    final messenger = rootScaffoldMessengerKey.currentState;
    final context = rootScaffoldMessengerKey.currentContext ?? fallbackContext;
    if (messenger == null || !messenger.mounted || context == null) return;
    if (!context.mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = isError
        ? colorScheme.errorContainer
        : colorScheme.inverseSurface;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onInverseSurface;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
        ),
      );
  });
}
