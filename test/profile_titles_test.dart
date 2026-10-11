// Profile titles: owned and worn, kept in one settings row
// (lib/models/profile_titles.dart).

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a fresh save owns and wears nothing', () async {
    final state = await ProfileTitles.load(db);
    expect(state.owned, isEmpty);
    expect(state.worn, isNull);
  });

  test('granted titles are owned, once each, and not worn', () async {
    await ProfileTitles.grant(db, 'a');
    await ProfileTitles.grant(db, 'b');
    await ProfileTitles.grant(db, 'a');
    final state = await ProfileTitles.load(db);
    expect(state.owned, {'a', 'b'});
    expect(state.worn, isNull);
  });

  test('only an owned title can be worn, and it can be taken off', () async {
    await ProfileTitles.grant(db, 'a');
    expect(await ProfileTitles.wear(db, 'nope'), isFalse);
    expect((await ProfileTitles.load(db)).worn, isNull);

    expect(await ProfileTitles.wear(db, 'a'), isTrue);
    expect((await ProfileTitles.load(db)).worn, 'a');

    // Granting another keeps the one worn.
    await ProfileTitles.grant(db, 'b');
    expect((await ProfileTitles.load(db)).worn, 'a');

    expect(await ProfileTitles.wear(db, null), isTrue);
    expect((await ProfileTitles.load(db)).worn, isNull);
    expect((await ProfileTitles.load(db)).owned, {'a', 'b'});
  });

  test('a row it cannot read is no titles, never a throw', () async {
    for (final raw in [
      '{oops',
      '[]',
      '7',
      '{"owned": "a", "worn": 3}',
      '{"owned": [1, null, ""], "worn": "a"}',
    ]) {
      await db.settingsDao.setSetting(ProfileTitles.settingKey, raw);
      final state = await ProfileTitles.load(db);
      expect(state.owned, isEmpty, reason: raw);
      expect(state.worn, isNull, reason: raw);
    }
  });

  test('a worn title that is not owned is taken off on reading', () {
    final state = ProfileTitleState.decode('{"owned": ["a"], "worn": "b"}');
    expect(state.owned, {'a'});
    expect(state.worn, isNull);
  });

  test("a title's words are its Athanor piece's name", () {
    const piece = AthanorPiece(
      id: 'x.title',
      name: 'Keeper of Embers',
      description: 'A title.',
      kind: AthanorPieceKind.title,
      rarity: AthanorRarity.rare,
      grantRef: 'title.embers',
    );
    const effect = AthanorPiece(
      id: 'x.aura',
      name: 'Not a title',
      description: 'An aura.',
      kind: AthanorPieceKind.alchemyEffect,
      rarity: AthanorRarity.common,
      grantRef: 'title.embers.not',
    );
    const batches = [
      AthanorBatch(
        id: 'x',
        name: 'X',
        description: 'A batch.',
        pieces: [effect],
        capstone: piece,
      ),
    ];
    expect(
      ProfileTitles.nameOf('title.embers', batches: batches),
      'Keeper of Embers',
    );
    expect(ProfileTitles.nameOf('title.embers.not', batches: batches), isNull);
    expect(ProfileTitles.nameOf('unknown', batches: batches), isNull);
  });
}
