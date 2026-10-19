import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every race and bout keeps a record, each once', () {
    final ids = [for (final e in kTrialsEvents) e.id];
    expect(ids.length, 18);
    expect(ids.toSet().length, ids.length);
    expect(trialsEvent('open')!.mark, TrialsMark.time);
    expect(trialsEvent('clear_night')!.mark, TrialsMark.stars);
    expect(trialsEvent('asteroid_run')!.mark, TrialsMark.time);
  });

  test('a time beats a slower one, stars beat fewer', () {
    var r = const TrialsRecords();
    expect(r.beats('open', 38100), isTrue);
    r = r.withRecord('open', const TrialsRecord(value: 38100, by: 'Firemane'));
    expect(r.beats('open', 37860), isTrue);
    expect(r.beats('open', 38100), isFalse);
    expect(r.beats('open', 39000), isFalse);
    r = r.withRecord(
      'mirror_lake',
      const TrialsRecord(value: 80, by: 'Icekin'),
    );
    expect(r.beats('mirror_lake', 81), isTrue);
    expect(r.beats('mirror_lake', 79), isFalse);
    expect(r.beats('no_such_race', 1), isFalse);
    expect(trialsEvent('open')!.show(37860), '37.86s');
  });

  test('records keep through the save, and junk is dropped', () async {
    SharedPreferences.setMockInitialValues({});
    final r = const TrialsRecords().withRecord(
      'star',
      const TrialsRecord(value: 52340, by: 'Lightwing', baseId: 'LW1', at: 7),
    );
    await r.save();
    final back = await TrialsRecords.load();
    expect(back.best['star']!.value, 52340);
    expect(back.best['star']!.by, 'Lightwing');
    expect(back.best['star']!.baseId, 'LW1');
    expect(back.published, {'star': 52340});
    expect(
      TrialsRecords.deserialise('{"star":{"v":"x"},"nope":{"v":1}}').best,
      isEmpty,
    );
    expect(TrialsRecords.deserialise('not json').best, isEmpty);
  });

  test("a friend's Trials read back as published, bounded", () {
    const card = TrialsCard(
      won: {'copper': 3, 'silver': 1},
      best: {'open': 37860, 'clear_night': 92},
    );
    final back = TrialsCard.fromJson(card.toJson())!;
    expect(back.won, card.won);
    expect(back.best, card.best);
    expect(TrialsCard.fromJson(null), isNull);
    expect(TrialsCard.fromJson({'won': {}, 'best': {}}), isNull);
    final junk = TrialsCard.fromJson({
      'won': {'copper': 'three', 'silver': -2, 'gold': 2},
      'best': {'open': 1e12},
    })!;
    expect(junk.won, {'gold': 2});
    expect(junk.best, isEmpty);
    final card2 = FriendCard.fromJson('u', {
      'name': 'Pat',
      'trials': card.toJson(),
    });
    expect(card2.trials!.best['open'], 37860);
  });

  test("the contests' keepsakes come with the cups now, and stay earned", () {
    KeepsakeLedger ledger({String contests = '', String races = ''}) =>
        KeepsakeLedger.from(
          starsRaw: '',
          contestsRaw: contests,
          racesRaw: races,
          bred: const {},
          speciesName: (id) => id,
        );
    expect(ledger().owns('victory_arch'), isFalse);
    // The Gold Cup's three races won: its own cup and the Speed keepsake.
    final gold = ledger(races: '{"copper":3,"silver":3,"gold":3}');
    expect(gold.owns('gold_cup'), isTrue);
    expect(gold.owns('victory_arch'), isTrue);
    expect(gold.owns('titan_anvil'), isFalse);
    // The gem cups each bring theirs.
    final gems = ledger(
      races: '{"copper":3,"silver":3,"ruby":3,"sapphire":3,"emerald":3}',
    );
    expect(gems.owns('titan_anvil'), isTrue);
    expect(gems.owns('crown_mirror'), isTrue);
    expect(gems.owns('prism_orrery'), isTrue);
    // A contest mastered before they were retired keeps its keepsake.
    final old = ledger(contests: '{"beauty":5}');
    expect(old.owns('crown_mirror'), isTrue);
  });
}
