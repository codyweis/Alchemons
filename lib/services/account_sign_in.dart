import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/cloud_autosave_service.dart';
import 'package:alchemons/services/save_generation_service.dart';
import 'package:alchemons/services/save_restore_reload_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// What signing in did to the game on this device.
enum SignInResult {
  /// It was already the account's game, and this its active device.
  alreadyHere,

  /// The account's save replaced the game here.
  restored,

  /// The account had no save; the game here became it.
  savedHere,
}

/// Signs in and makes this device the account's device: the account's save
/// replaces the game here, or, when the account has none yet, the game here
/// becomes its save. The sign-in screens warn about the replacement before
/// this runs.
///
/// Anything that fails once the password is accepted signs back out, so being
/// signed in always means this device plays the account; trying again starts
/// over. Errors carry a message for the player.
Future<SignInResult> signInAndBringSave(
  BuildContext context, {
  required String email,
  required String password,
}) async {
  final account = context.read<AccountService>();
  final session = context.read<AccountSessionService>();
  final cloudSave = context.read<AccountCloudSaveService>();
  final autosave = context.read<CloudAutosaveService>();
  final db = context.read<AlchemonsDatabase>();

  await account.signIn(email: email, password: password);
  final uid = account.user!.uid;
  try {
    final result = await autosave.hold(() async {
      await session.refresh();
      final owner = await SaveGenerationService.owner(db);
      if (owner == uid && session.state.activeOnThisDevice) {
        return SignInResult.alreadyHere;
      }
      final snapshot = await cloudSave.getSnapshot(uid);
      if (snapshot == null) {
        if (owner != null && owner != uid) {
          throw const AccountException(
            'This account has no save yet, and the game on this device '
            'belongs to another account. Sign into that account, or reset '
            'progress to start a new game.',
          );
        }
        await session.claimCurrentDevice(force: true);
        return SignInResult.savedHere;
      }
      final saveCode = await cloudSave.downloadSaveCode(uid);
      await SaveTransferService(
        db,
      ).importSaveCode(saveCode, ownerAccountId: uid);
      if (context.mounted) await reloadStateAfterSaveRestore(context);
      // A fresh device identity only once the save is in: rotating first
      // left a failed download with this device silently deactivated.
      await session.rotateCurrentDeviceId();
      await session.claimCurrentDevice(force: true);
      await session.refresh();
      return SignInResult.restored;
    });
    if (result == SignInResult.savedHere) unawaited(autosave.save());
    return result;
  } catch (_) {
    try {
      await account.signOut();
    } catch (error) {
      debugPrint('Sign-out after a failed sign-in failed: $error');
    }
    rethrow;
  }
}

/// A sign-in failure in words for the dialog that stays open on it.
String signInErrorText(Object error) => switch (error) {
  AccountException() ||
  AccountCloudSaveException() ||
  AccountSessionException() ||
  SaveTransferException() => error.toString(),
  StateError(:final message) => message,
  _ => 'Sign in failed: $error',
};
