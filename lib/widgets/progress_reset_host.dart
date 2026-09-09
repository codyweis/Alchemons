import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/progress_reset_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Tears down the game and its providers before changing the save. Also runs
/// before game services start on launch when a reset needs recovery.
class ProgressResetHost extends StatefulWidget {
  const ProgressResetHost({
    super.key,
    required this.db,
    required this.buildGame,
  });
  final AlchemonsDatabase db;
  final Future<Widget> Function() buildGame;
  @override
  State<ProgressResetHost> createState() => _ProgressResetHostState();
}

class _ProgressResetHostState extends State<ProgressResetHost> {
  Widget? _game;
  Object? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    ProgressResetService.requests.addListener(_restart);
    _restart();
  }

  Future<void> _restart() async {
    if (_running) return;
    _running = true;
    setState(() {
      _game = null;
      _error = null;
    });
    // Let the old provider tree dispose its timers/subscriptions first.
    await WidgetsBinding.instance.endOfFrame;
    try {
      Widget? preparedGame;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(ProgressResetService.pendingKey)) {
        await FirebaseAuth.instance.authStateChanges().first;
        await ProgressResetService(
          widget.db,
          beforeLocalReset: PushNotificationService().cancelAll,
          prepareFreshSave: () async {
            preparedGame = await widget.buildGame();
          },
        ).resume();
      }
      final game = preparedGame ?? await widget.buildGame();
      if (mounted) setState(() => _game = game);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _running = false;
    }
  }

  Future<void> _signIn(BuildContext dialogContext) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final submitted = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Sign in to finish your reset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Use the same account that started this reset.'),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
    final emailValue = email.text.trim();
    final passwordValue = password.text;
    // Dialog fields finish unmounting before their controllers are disposed.
    await WidgetsBinding.instance.endOfFrame;
    email.dispose();
    password.dispose();
    if (submitted != true || !mounted) return;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailValue,
        password: passwordValue,
      );
      await _restart();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) =>
      _game ??
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Builder(
                builder: (recoveryContext) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error == null) const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _error == null
                            ? 'Preparing your game…'
                            : 'Could not finish preparing your game.\n$_error',
                        textAlign: TextAlign.center,
                      ),
                      if (_error != null)
                        TextButton(
                          onPressed: _restart,
                          child: const Text('Retry'),
                        ),
                      if (_error != null)
                        TextButton(
                          onPressed: () => _signIn(recoveryContext),
                          child: const Text('Sign In'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    ProgressResetService.requests.removeListener(_restart);
    super.dispose();
  }
}
