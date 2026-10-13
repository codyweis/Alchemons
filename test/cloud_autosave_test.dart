import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/cloud_autosave_service.dart';
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Autosave sends the game up only from the account's active device, and only
/// when something in it changed: the time a backup was packed doesn't count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ({CloudAutosaveService autosave, _FakeCloudSave cloud, AlchemonsDatabase db})
  build({bool active = true}) {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final cloud = _FakeCloudSave();
    final autosave = CloudAutosaveService(
      db: db,
      account: _FakeAccount(),
      session: _FakeSession(active: active),
      cloudSave: cloud,
    );
    addTearDown(() async {
      autosave.dispose();
      await db.close();
    });
    return (autosave: autosave, cloud: cloud, db: db);
  }

  test('uploads once, then again only when the game changes', () async {
    final (:autosave, :cloud, :db) = build();

    expect(await autosave.save(), isTrue);
    expect(cloud.uploads, hasLength(1));
    expect(autosave.savedAt, isNotNull);

    expect(await autosave.save(), isTrue);
    expect(cloud.uploads, hasLength(1));

    await db.settingsDao.setSetting('autosave_test.changed', '1');
    expect(await autosave.save(), isTrue);
    expect(cloud.uploads, hasLength(2));

    expect(await autosave.save(force: true), isTrue);
    expect(cloud.uploads, hasLength(3));
  });

  test('the game leaving the screen saves it', () async {
    final (:autosave, :cloud, db: _) = build();

    autosave.didChangeAppLifecycleState(AppLifecycleState.paused);
    // The same upload, joined.
    await autosave.save();

    expect(cloud.uploads, hasLength(1));
  });

  test('never saves from a device the account is not active on', () async {
    final (:autosave, :cloud, db: _) = build(active: false);

    expect(autosave.enabled, isFalse);
    expect(await autosave.save(force: true), isFalse);
    autosave.didChangeAppLifecycleState(AppLifecycleState.paused);

    expect(cloud.uploads, isEmpty);
  });

  test('holds still while a sign-in replaces the game', () async {
    final (:autosave, :cloud, db: _) = build();

    await autosave.hold(() async {
      expect(await autosave.save(force: true), isFalse);
    });
    expect(cloud.uploads, isEmpty);

    expect(await autosave.save(), isTrue);
    expect(cloud.uploads, hasLength(1));
  });

  test('a failed upload is reported and not counted as saved', () async {
    final (:autosave, :cloud, db: _) = build();
    cloud.failNext = true;

    expect(await autosave.save(), isFalse);
    expect(autosave.error, 'Cloud save service is temporarily unavailable.');
    expect(autosave.savedAt, isNull);

    expect(await autosave.save(), isTrue);
    expect(autosave.error, isNull);
    expect(cloud.uploads, hasLength(1));
  });
}

class _FakeUser implements User {
  @override
  String get uid => 'account-a';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAccount extends ChangeNotifier implements AccountService {
  @override
  bool get isSignedIn => true;
  @override
  User? get user => _FakeUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSession extends ChangeNotifier implements AccountSessionService {
  _FakeSession({required this.active});

  final bool active;

  @override
  String? get deviceId => 'here';
  @override
  AccountSessionState get state => active
      ? const AccountSessionState.active(activeDeviceId: 'here')
      : const AccountSessionState.inactive(activeDeviceId: 'elsewhere');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeCloudSave implements AccountCloudSaveService {
  final uploads = <String>[];
  bool failNext = false;

  @override
  Future<AccountCloudSaveSnapshot> uploadSave({
    required String uid,
    required String sourceDeviceId,
    required String saveCode,
  }) async {
    if (failNext) {
      failNext = false;
      throw const AccountCloudSaveException(
        'Cloud save service is temporarily unavailable.',
      );
    }
    uploads.add(saveCode);
    return AccountCloudSaveSnapshot(revision: uploads.length, updatedAt: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
