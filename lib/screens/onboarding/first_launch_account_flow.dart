// lib/screens/onboarding/first_launch_account_flow.dart
//
// First-launch "do you already have an account?" flow.
//
// Returning players can sign in and restore their cloud backup here, which
// overwrites the fresh local save and lets them skip the story intro + faction
// picker entirely. New players fall through to the normal onboarding.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/save_restore_reload_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _WelcomeChoice { newPlayer, returning }

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

Future<_WelcomeChoice?> _showWelcomeDialog(BuildContext context) {
  return showDialog<_WelcomeChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final t = ForgeTokens(context.read<FactionTheme>());
      return AlertDialog(
        backgroundColor: t.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.borderAccent, width: 1),
        ),
        title: Text('Welcome, Alchemist', style: _heading(t)),
        content: Text(
          'Do you already have an Alchemons account?\n\n'
          'Sign in to restore your cloud backup onto this device, or start a '
          'fresh journey.',
          style: _body(t),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _WelcomeChoice.newPlayer),
            child: Text(
              "I'M NEW",
              style: _label(t).copyWith(color: t.textMuted),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _WelcomeChoice.returning),
            child: Text(
              'I HAVE AN ACCOUNT',
              style: _label(t).copyWith(color: t.amberBright),
            ),
          ),
        ],
      );
    },
  );
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
      throw const AccountException('Sign in failed. Please try again.');
    }

    final snapshot = await cloudSave.getSnapshot(uid);
    if (snapshot == null) {
      throw const AccountCloudSaveException(
        'No cloud backup found for this account. Start a new journey and back '
        'up from your profile.',
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
    _snack('Account restored. Welcome back!');
    return true;
  } on AccountException catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack(error.message, isError: true);
    return false;
  } on AccountCloudSaveException catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack(error.message, isError: true);
    return false;
  } on SaveTransferException catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack(error.message, isError: true);
    return false;
  } catch (error) {
    if (context.mounted) _dismissProgressDialog(context);
    _snack('Restore failed: $error', isError: true);
    return false;
  }
}

Future<_Credentials?> _showCredentialDialog(BuildContext context) {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var obscure = true;

  return showDialog<_Credentials>(
    context: context,
    builder: (context) {
      final t = ForgeTokens(context.read<FactionTheme>());
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: t.bg2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: t.borderAccent, width: 1),
            ),
            title: Text('Sign In', style: _heading(t)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: TextStyle(color: t.textPrimary),
                    decoration: _inputDecoration(t, 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autocorrect: false,
                    style: TextStyle(color: t.textPrimary),
                    decoration: _inputDecoration(
                      t,
                      'Password',
                      suffix: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? AppIcons.visibility_rounded
                              : AppIcons.visibility_off_rounded,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCEL',
                  style: _label(t).copyWith(color: t.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  _Credentials(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  ),
                ),
                child: Text(
                  'SIGN IN',
                  style: _label(t).copyWith(color: t.amberBright),
                ),
              ),
            ],
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
    builder: (context) {
      final t = ForgeTokens(context.read<FactionTheme>());
      return AlertDialog(
        backgroundColor: t.bg2,
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(t.amberBright),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: _label(t))),
          ],
        ),
      );
    },
  );
}

void _dismissProgressDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

void _snack(String message, {bool isError = false}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? const Color(0xFFC0392B) : null,
    ),
  );
}

InputDecoration _inputDecoration(ForgeTokens t, String label, {Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: t.textSecondary),
    suffixIcon: suffix,
    filled: true,
    fillColor: t.bg1,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.borderMid),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.amberBright),
    ),
  );
}

TextStyle _heading(ForgeTokens t) => TextStyle(
  color: t.textPrimary,
  fontSize: 18,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.5,
);

TextStyle _body(ForgeTokens t) =>
    TextStyle(color: t.textSecondary, fontSize: 14, height: 1.4);

TextStyle _label(ForgeTokens t) => TextStyle(
  color: t.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
);

class _Credentials {
  final String email;
  final String password;
  const _Credentials({required this.email, required this.password});
}
