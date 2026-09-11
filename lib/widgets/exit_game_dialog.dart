import 'package:flutter/material.dart';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// Shows the "leave the game" confirmation for the app shell.
///
/// Resolves to `true` only when the player deliberately confirms; a tap on the
/// barrier or a STAY resolves to `null`/`false`, so the caller's
/// `if (result == true)` guard keeps its original meaning.
Future<bool?> showExitGameDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => const ExitGameDialog(),
  );
}

/// The exit confirmation, in the forge language the rest of the app speaks:
/// a dark panel with a hairline amber edge, an uppercase letter-spaced plate,
/// a muted STAY and an amber EXIT.
///
/// It replaces a bare Material [AlertDialog] that took its ground from the
/// faction surface and its buttons from stock Material — light-ish, rounded,
/// sentence-case, and the last screen in the app still styled that way.
class ExitGameDialog extends StatelessWidget {
  const ExitGameDialog({super.key});

  // Same ink the cosmic/altar/rite screens use. Kept local so a general shell
  // widget does not have to reach into a cosmic-specific style class.
  static const _bg0 = Color(0xFF060606);
  static const _bg1 = Color(0xFF0D0D0D);
  static const _bg2 = Color(0xFF121212);
  static const _bg3 = Color(0xFF1A1A1A);
  static const _amber = Color(0xFFC4A35A);
  static const _textPrimary = Color(0xFFE8DFC8);
  static const _textSecondary = Color(0xFFB5A98A);
  static const _borderDim = Color(0xFF2E2A23);
  static const _borderMid = Color(0xFF4A4032);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bg3, _bg1, _bg0],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _amber.withValues(alpha: 0.62),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 12),
              Container(height: 1, color: _borderDim),
              const SizedBox(height: 12),
              _body(context),
              const SizedBox(height: 16),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: 0.11),
            border: Border.all(color: _amber.withValues(alpha: 0.34)),
          ),
          child: const Icon(AppIcons.logout_rounded, color: _amber, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EXIT ALCHEMONS?',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'CLOSE THE LABORATORY',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: _amber.withValues(alpha: 0.82),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: _bg2.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _borderDim),
      ),
      child: Text(
        'Are you sure you want to leave the game?',
        style: TextStyle(
          fontFamily: appFontFamily(context),
          color: _textSecondary,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _button(
            context,
            label: 'STAY',
            onTap: () => Navigator.of(context).pop(false),
            fill: _bg2.withValues(alpha: 0.82),
            border: _borderMid,
            ink: _textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _button(
            context,
            label: 'EXIT',
            icon: AppIcons.logout_rounded,
            onTap: () => Navigator.of(context).pop(true),
            fill: _amber.withValues(alpha: 0.12),
            border: _amber.withValues(alpha: 0.6),
            ink: _amber,
          ),
        ),
      ],
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    required Color fill,
    required Color border,
    required Color ink,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: context.soundAction(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: ink, size: 15),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
