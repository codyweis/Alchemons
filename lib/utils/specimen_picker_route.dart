import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:flutter/material.dart';

Future<CreatureInstance?> showSpecimenPickerRoute({
  required BuildContext context,
  required FactionTheme theme,
  required String searchHint,
  required String prefsScopeKey,
  List<String> selectedInstanceIds = const [],
  List<String> allowedPrimaryTypes = const [],
  FutureOr<bool> Function(CreatureInstance instance)? onWillSelectInstance,
}) {
  return Navigator.of(context).push<CreatureInstance>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => AllSpecimensPage(
        theme: theme,
        instancePrefsScopeKey: prefsScopeKey,
        popOnSelect: true,
        searchHint: searchHint,
        selectedInstanceIds: selectedInstanceIds,
        allowedPrimaryTypes: allowedPrimaryTypes,
        onWillSelectInstance: onWillSelectInstance,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    ),
  );
}
