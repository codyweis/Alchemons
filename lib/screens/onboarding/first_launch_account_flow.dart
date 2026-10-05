// lib/screens/onboarding/first_launch_account_flow.dart
//
// First-launch "do you already have an account?" flow.
//
// Returning players can sign in and restore their cloud backup here, which
// overwrites the fresh local save and lets them skip the story intro + faction
// picker entirely. New players fall through to the normal onboarding.
//
// The very first thing a new player sees, so it speaks in the game's bracket
// frame (story_dialog.dart / bracket_controls.dart) on the dark ground, the
// same in every faction theme — the player has not picked one yet.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/save_restore_reload_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _WelcomeChoice { newPlayer, returning }

const _palette = BracketPalette.dark;

/// Shows the first-launch account prompt and, if the player chooses to sign in
/// and restore an existing account, performs the restore.
///
/// Returns `true` if a cloud save was restored (caller should skip the tutorial
/// / faction picker), or `false` if the player is new (or backed out).
Future<bool> runFirstLaunchAccountRestore(BuildContext context) async {
  while (true) {
    if (!context.mounted) return false;
    final choice = await _showWelcomeDialog(context);
    if (choice != _WelcomeChoice.returning) {
      // New player, or dismissed — proceed with normal onboarding.
      return false;
    }

    if (!context.mounted) return false;
    final restored = await _attemptRestore(context);
    if (restored) return true;
    // Sign-in / restore failed or was cancelled — return to the welcome
    // prompt so the player can retry or choose to start fresh.
  }
}

Future<_WelcomeChoice?> _showWelcomeDialog(BuildContext context) async {
  final answer = await showStoryDialog(
    context,
    beats: const [
      StoryBeat(
        title: 'Welcome, Alchemist',
        message:
            'Already have an Alchemons account? Sign in to bring your cloud '
            'backup to this device, or start fresh.',
      ),
    ],
    primaryLabel: 'I HAVE AN ACCOUNT',
    secondaryLabel: "I'M NEW",
  );
  return switch (answer) {
    true => _WelcomeChoice.returning,
    false => _WelcomeChoice.newPlayer,
    null => null,
  };
}

/// Signs in and restores the account's cloud backup. Returns `true` on success.
Future<bool> _attemptRestore(BuildContext context) async {
  final creds = await _showCredentialDialog(context);
  if (creds == null || !context.mounted) return false;

  final account = context.read<AccountService>();
  final session = context.read<AccountSessionService>();
  final cloudSave = context.read<AccountCloudSaveService>();
  final db = context.read<AlchemonsDatabase>();

  _showProgressDialog(context, 'RESTORING ACCOUNT');
  try {
    await account.signIn(email: creds.email, password: creds.password);
    final uid = account.user?.uid;
    if (uid == null) {
      throw const AccountException('Sign-in failed. Try again.');
    }

    final snapshot = await cloudSave.getSnapshot(uid);
    if (snapshot == null) {
      throw const AccountCloudSaveException(
        'No cloud backup on this account. Start fresh, then back up from '
        'your profile.',
      );
    }

    await session.rotateCurrentDeviceId();
    final saveCode = await cloudSave.downloadSaveCode(uid);
    await SaveTransferService(db).importSaveCode(saveCode, ownerAccountId: uid);

    if (!context.mounted) return false;
    await reloadStateAfterSaveRestore(context);
    await session.claimCurrentDevice(force: true);
    await session.refresh();

    if (context.mounted) _dismissProgressDialog(context);
    _snack(context.mounted ? context : null, 'Account restored. Welcome back');
    return true;
  } on AccountException catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack(context.mounted ? context : null, error.message, isError: true);
    return false;
  } on AccountCloudSaveException catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack(context.mounted ? context : null, error.message, isError: true);
    return false;
  } on SaveTransferException catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack(context.mounted ? context : null, error.message, isError: true);
    return false;
  } catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack(
      context.mounted ? context : null,
      'Restore failed: $error',
      isError: true,
    );
    return false;
  }
}

Future<_Credentials?> _showCredentialDialog(BuildContext context) {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var obscure = true;

  return showDialog<_Credentials>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) {
      final accent = storyDialogAccent(StoryDialogKind.info);
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return _BracketDialogFrame(
            accent: accent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _title('SIGN IN'),
                  const SizedBox(height: 8),
                  Text(
                    'Use the email and password from your account.',
                    style: bracketText(
                      context,
                      13,
                      _palette.ink.withValues(alpha: 0.85),
                    ).copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _BracketField(
                    controller: emailController,
                    label: 'EMAIL',
                    accent: accent,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _BracketField(
                    controller: passwordController,
                    label: 'PASSWORD',
                    accent: accent,
                    obscureText: obscure,
                    suffix: IconButton(
                      onPressed: context.soundAction(
                        () => setDialogState(() => obscure = !obscure),
                      ),
                      icon: Icon(
                        obscure
                            ? AppIcons.visibility_rounded
                            : AppIcons.visibility_off_rounded,
                        color: _palette.muted,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: BracketButton(
                          label: 'CANCEL',
                          primary: false,
                          height: 42,
                          palette: _palette,
                          accent: accent,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BracketButton(
                          label: 'SIGN IN',
                          height: 42,
                          palette: _palette,
                          accent: accent,
                          onTap: () => Navigator.pop(
                            context,
                            _Credentials(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showProgressDialog(BuildContext context, String title) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) {
      final accent = storyDialogAccent(StoryDialogKind.info);
      return _BracketDialogFrame(
        accent: accent,
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _title(title)),
          ],
        ),
      );
    },
  );
}

void _dismissProgressDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

/// The game's top notification. Falls back to the root messenger's context
/// when the flow's own context was torn down by the restore's reload.
void _snack(BuildContext? context, String message, {bool isError = false}) {
  final target = context ?? rootScaffoldMessengerKey.currentContext;
  if (target == null || !target.mounted) return;
  showGameSnack(
    target,
    message,
    accent: storyDialogAccent(
      isError ? StoryDialogKind.danger : StoryDialogKind.success,
    ),
    duration: Duration(seconds: isError ? 5 : 3),
  );
}

Widget _title(String text) => Text(
  text.toUpperCase(),
  style: TextStyle(
    fontFamily: 'monospace',
    color: _palette.ink,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.8,
  ),
);

/// The story dialog's frame, for dialogs it cannot express (a form, a
/// spinner): bracket corners in [accent] around the dark ground.
class _BracketDialogFrame extends StatelessWidget {
  const _BracketDialogFrame({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: landscape ? 40 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: landscape ? 560 : 420),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.9),
            bracketSize: 14,
            strokeWidth: 1.3,
          ),
          child: Container(
            color: _palette.bg1,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A square-cornered text field on the darker ground: hairline in the
/// palette's line colour, the accent when focused.
class _BracketField extends StatelessWidget {
  const _BracketField({
    required this.controller,
    required this.label,
    required this.accent,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final Color accent;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: false,
      cursorColor: accent,
      style: bracketText(context, 14, _palette.ink, weight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'monospace',
          color: _palette.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'monospace',
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        suffixIcon: suffix,
        isDense: true,
        filled: true,
        fillColor: _palette.bg0,
        enabledBorder: border(_palette.line),
        focusedBorder: border(accent),
      ),
    );
  }
}

class _Credentials {
  final String email;
  final String password;
  const _Credentials({required this.email, required this.password});
}
