import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/onboarding/first_launch_account_flow.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/cloud_autosave_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The first-launch prompt in the bracket frame: the welcome question's two
/// answers, the sign-in form's cancel leading back to the question, and a
/// wrong password keeping the form open. The restore itself needs Firebase
/// and is not exercised here.
void main() {
  Future<List<bool>> pumpFlow(WidgetTester tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: _NoDb()),
          ChangeNotifierProvider<AccountService>(
            create: (_) => _WrongPassword(),
          ),
          ChangeNotifierProvider<AccountSessionService>(
            create: (_) => _NoSession(),
          ),
          Provider<AccountCloudSaveService>(create: (_) => _NoCloudSave()),
          ChangeNotifierProvider<CloudAutosaveService>(
            create: (_) => _NoAutosave(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      results.add(await runFirstLaunchAccountRestore(context)),
                  child: const Text('start'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets("I'M NEW returns false", (tester) async {
    final results = await pumpFlow(tester);
    expect(find.text('WELCOME, ALCHEMIST'), findsOneWidget);
    expect(find.text('I HAVE AN ACCOUNT'), findsOneWidget);

    await tester.tap(find.text("I'M NEW"));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(find.text('WELCOME, ALCHEMIST'), findsNothing);
  });

  testWidgets('cancelling sign-in returns to the welcome prompt', (
    tester,
  ) async {
    final results = await pumpFlow(tester);

    await tester.tap(find.text('I HAVE AN ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME, ALCHEMIST'), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.text("I'M NEW"));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('a wrong password keeps the sign-in open and says so', (
    tester,
  ) async {
    final results = await pumpFlow(tester);

    await tester.tap(find.text('I HAVE AN ACCOUNT'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'EMAIL'),
      'alchemist@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'PASSWORD'), 'nope');
    // The title says SIGN IN too; the button is the last.
    await tester.tap(find.text('SIGN IN').last);
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME, ALCHEMIST'), findsOneWidget);
  });
}

class _WrongPassword extends ChangeNotifier implements AccountService {
  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.error(const AccountException('Email or password is incorrect.'));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoSession extends ChangeNotifier implements AccountSessionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoCloudSave implements AccountCloudSaveService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoAutosave extends ChangeNotifier implements CloudAutosaveService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoDb implements AlchemonsDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
