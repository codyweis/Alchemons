// A raid clear advances only the raid that was fought. The space screen keeps
// rotating raids while a fight runs, so by the time the guardian falls the
// stored raid can be another planet's, or the same planet a tier on.

import 'package:alchemons/services/raid_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a clear of the raid that was fought advances it', () async {
    final service = RaidService();
    await service.forceSummon('Fire', const ['Fire']);
    await service.markLevelCleared(element: 'Fire', level: 1, level3Clears: 0);
    expect((await service.load())!.level, 2);
  });

  test("a clear of another planet's raid leaves the stored one", () async {
    final service = RaidService();
    await service.forceSummon('Fire', const ['Fire']);
    await service.markLevelCleared(element: 'Air', level: 1, level3Clears: 0);
    expect((await service.load())!.level, 1);
  });

  test('a clear of an earlier tier is not counted twice', () async {
    final service = RaidService();
    await service.forceSummon('Fire', const ['Fire']);
    await service.markLevelCleared(element: 'Fire', level: 1, level3Clears: 0);
    await service.markLevelCleared(element: 'Fire', level: 1, level3Clears: 0);
    expect((await service.load())!.level, 2);
  });
}
