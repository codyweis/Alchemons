// Profile titles: owned and worn, kept in one settings row; made titles
// open to all; achievement titles read off the achievement's collected flag
// (lib/models/profile_titles.dart).

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
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

  group('made titles', () {
    test('every color and word can be worn with nothing owned', () async {
      for (final c in TitleColour.values) {
        for (final w in TitleWord.values) {
          final made = MadeTitle(c, w);
          expect(await ProfileTitles.wear(db, made.id), isTrue);
          final state = await ProfileTitles.load(db);
          expect(state.worn, made.id);
          expect(state.wornMade, made);
          expect(state.owned, isEmpty, reason: 'made titles are never kept');
        }
      }
    });

    test('are a color then a word', () {
      expect(
        ProfileTitles.nameOf(
          const MadeTitle(TitleColour.red, TitleWord.fuser).id,
        ),
        'Red Fuser',
      );
      expect(
        ProfileTitles.nameOf(
          const MadeTitle(TitleColour.brown, TitleWord.mystery).id,
        ),
        'Brown Mystery',
      );
    });

    test('an id that is not a whole color and word is not one', () async {
      for (final id in [
        'made.red',
        'made.pink.fuser',
        'made.red.fusers',
        'made.red.fuser.x',
        'red.fuser',
      ]) {
        expect(MadeTitle.fromId(id), isNull, reason: id);
        expect(await ProfileTitles.wear(db, id), isFalse, reason: id);
      }
    });

    test('a worn one survives a granted title', () async {
      final id = const MadeTitle(TitleColour.blue, TitleWord.cosmic).id;
      await ProfileTitles.wear(db, id);
      await ProfileTitles.grant(db, 'a');
      final state = await ProfileTitles.load(db);
      expect(state.worn, id);
      expect(state.owned, {'a'});
    });
  });

  group('achievement titles', () {
    test('one for each fusion family, each on a real achievement', () {
      final ids = {for (final a in campaignAchievements) a.id};
      expect(
        {for (final t in kAchievementTitles.values) t.$1},
        {for (final f in kFusionFamilies) 'fuse_${f}_5'},
      );
      for (final t in kAchievementTitles.values) {
        expect(ids, contains(t.$1));
      }
    });

    test('can be worn once the achievement is collected', () async {
      expect(await ProfileTitles.wear(db, 'family.let'), isFalse);
      expect((await ProfileTitles.load(db)).earned, isEmpty);

      await db.settingsDao.setSetting(
        CampaignJournalService.claimKey('fuse_let_5'),
        '1',
      );
      final state = await ProfileTitles.load(db);
      expect(state.earned, {'family.let'});
      expect(state.owned, isEmpty, reason: 'read off the flag, never kept');

      expect(await ProfileTitles.wear(db, 'family.let'), isTrue);
      expect((await ProfileTitles.load(db)).worn, 'family.let');
      expect(ProfileTitles.nameOf('family.let'), 'Let Lover');
      expect(ProfileTitles.forAchievement('fuse_let_5'), (
        'family.let',
        'Let Lover',
      ));
      expect(ProfileTitles.forAchievement('collection_10'), isNull);
    });

    test('are listed first among the titles to earn', () {
      expect(
        ProfileTitles.earnable().take(kAchievementTitles.length),
        kAchievementTitles.keys,
      );
    });
  });
}
