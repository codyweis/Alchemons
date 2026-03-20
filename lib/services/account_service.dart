import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AccountException implements Exception {
  final String message;

  const AccountException(this.message);

  @override
  String toString() => message;
}

class AccountService extends ChangeNotifier {
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authSub;
  User? _user;
  bool _initialized = false;
  bool _configured = false;
  String? _configurationError;

  AccountService() {
    unawaited(_bootstrap());
  }

  bool get initialized => _initialized;
  bool get isConfigured => _configured;
  bool get isSignedIn => _user != null;
  User? get user => _user;
  String? get configurationError => _configurationError;
  String get displayName => _user?.displayName?.trim().isNotEmpty == true
      ? _user!.displayName!.trim()
      : 'NO NAME SET';
  String get email => _user?.email ?? '';

  Future<void> _bootstrap() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _auth = FirebaseAuth.instance;
      _user = _auth!.currentUser;
      _configured = true;
      _configurationError = null;

      _authSub = _auth!.authStateChanges().listen((user) {
        _user = user;
        notifyListeners();
      });
    } catch (error, stack) {
      debugPrint('AccountService bootstrap failed: $error');
      debugPrintStack(stackTrace: stack);
      _configured = false;
      _configurationError =
          'Firebase Auth is not configured yet. Add your Firebase app config before using account transfer.';
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final auth = _requireAuth();
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final nextName = displayName.trim();
      if (nextName.isNotEmpty) {
        await credential.user?.updateDisplayName(nextName);
        await credential.user?.reload();
      }
      _user = auth.currentUser;
      notifyListeners();
    } on FirebaseAuthException catch (error) {
      throw AccountException(_friendlyAuthError(error));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    try {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = auth.currentUser;
      notifyListeners();
    } on FirebaseAuthException catch (error) {
      throw AccountException(_friendlyAuthError(error));
    }
  }

  Future<void> signOut() async {
    final auth = _requireAuth();
    await auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> updateDisplayName(String nextName) async {
    final user = _requireSignedInUser();
    final trimmed = nextName.trim();
    if (trimmed.isEmpty) {
      throw const AccountException('Display name cannot be empty.');
    }
    try {
      await user.updateDisplayName(trimmed);
      await user.reload();
      _user = _auth?.currentUser;
      notifyListeners();
    } on FirebaseAuthException catch (error) {
      throw AccountException(_friendlyAuthError(error));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _requireSignedInUserWithEmail();
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AccountException(_friendlyAuthError(error));
    }
  }

  Future<void> deleteAccount({
    required String currentPassword,
  }) async {
    final user = _requireSignedInUserWithEmail();
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      await user.delete();
      _user = null;
      notifyListeners();
    } on FirebaseAuthException catch (error) {
      throw AccountException(_friendlyAuthError(error));
    }
  }

  FirebaseAuth _requireAuth() {
    if (!_initialized) {
      throw const AccountException('Account service is still loading.');
    }
    if (!_configured || _auth == null) {
      throw AccountException(
        _configurationError ?? 'Firebase Auth is not available.',
      );
    }
    return _auth!;
  }

  User _requireSignedInUser() {
    final user = _requireAuth().currentUser;
    if (user == null) {
      throw const AccountException('Sign in first to manage this account.');
    }
    return user;
  }

  User _requireSignedInUserWithEmail() {
    final user = _requireSignedInUser();
    if (user.email == null || user.email!.isEmpty) {
      throw const AccountException(
        'This account does not have an email/password login.',
      );
    }
    return user;
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'email-already-in-use':
        return 'That email is already tied to an account.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase yet.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'wrong-password':
        return 'Password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'requires-recent-login':
        return 'Sign in again before changing this account.';
      case 'network-request-failed':
        return 'Network connection failed.';
      case 'internal-error':
        final details = error.message?.trim();
        if (details != null && details.isNotEmpty) {
          return 'Firebase internal error: $details';
        }
        return 'Firebase internal error. This is usually a project/app configuration issue.';
      default:
        final details = error.message?.trim();
        if (details != null && details.isNotEmpty) {
          return '${error.code}: $details';
        }
        return 'Account request failed (${error.code}).';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
