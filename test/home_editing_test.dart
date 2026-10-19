import 'package:alchemons/models/home_biome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const decor = HomePiece(id: 'gilded_throne#0', kind: 'gilded_throne', x: .5);
  const keepsake = HomePiece(id: 'ember_torch#0', kind: 'ember_torch', x: .2);

  test('shelving keepsakes preserves decor and scenery across a save', () {
    final layout = const HomeBiomeLayout()
        .withPlaced([...HomeRealm.valley.defaultPieces, decor, keepsake])
        .copyWith(
          residents: [
            HomeResident(instanceId: 'guest', x: .2, beside: keepsake.spawnId),
          ],
        );
    final saved = HomeBiomeLayout.fromJson(layout.putKeepsakesAway().toJson());
    expect(saved.keepsakes, isEmpty);
    expect(saved.decor.single.id, decor.id);
    expect(saved.scenery.length, layout.scenery.length);
    expect(saved.residents.single.beside, isNull);
  });

  test('resetting scenery preserves decor and keepsakes across a save', () {
    final layout = const HomeBiomeLayout().withPlaced([decor, keepsake]);
    final saved = HomeBiomeLayout.fromJson(layout.resetScenery().toJson());
    expect(saved.decor.single.id, decor.id);
    expect(saved.keepsakes.single.id, keepsake.id);
    expect(
      saved.scenery.map((p) => p.id),
      HomeRealm.valley.defaultPieces.map((p) => p.id),
    );
  });

  test(
    'buying a trial keeps residents and keepsakes attached after saving',
    () {
      final trial = decor.copyWith(id: 'try:${decor.id}');
      final guest = keepsake.copyWith(beside: () => trial.spawnId);
      final layout = const HomeBiomeLayout()
          .withPlaced([trial, guest])
          .copyWith(
            residents: [
              HomeResident(instanceId: 'guest', x: .55, beside: trial.spawnId),
            ],
          );
      final saved = HomeBiomeLayout.fromJson(
        layout.renamePiece(trial, decor.id).toJson(),
      );
      expect(saved.residents.single.beside, decor.spawnId);
      expect(saved.keepsakes.single.beside, decor.spawnId);
      expect(
        saved
            .spawnPoints((_) => false)
            .where((p) => p.beside == decor.spawnId)
            .length,
        2,
      );
      final moved = saved
          .replacePiece(decor.copyWith(x: .6))
          .carryBeside(decor.spawnId, .1);
      expect(moved.keepsakes.single.x, closeTo(.3, 1e-9));
      expect(moved.residents.single.x, closeTo(.65, 1e-9));
    },
  );

  for (final pieceHost in [false, true]) {
    for (final seam in [false, true]) {
      test(
        'moving ${pieceHost ? 'a keepsake' : 'a resident'} and companion avoids neighbors${seam ? ' across the seam' : ''}',
        () {
          const base = HomeBiomeLayout(pieces: {'valley': []});
          final gap = base.gap(HomeDepth.front);
          final origin = seam ? .99 : .2;
          final host = HomeResident(instanceId: 'host', x: origin);
          final piece = keepsake.copyWith(x: origin);
          final id = pieceHost ? piece.spawnId : host.spawnId;
          final layout = base
              .withPlaced([if (pieceHost) piece])
              .copyWith(
                residents: [
                  if (!pieceHost) host,
                  HomeResident(
                    instanceId: 'guest',
                    x: (origin + gap * .39) % 1,
                    beside: id,
                  ),
                  const HomeResident(instanceId: 'neighbor', x: .7),
                ],
              );
          final requested = .7 - gap * 1.1;
          final x = pieceHost
              ? layout.freeSpotForPiece(piece, requested, movingGroup: true)!
              : layout.freeSpotNear(host, requested, movingGroup: true)!;
          final moved =
              (pieceHost
                      ? layout.replacePiece(piece.copyWith(x: x))
                      : layout.replace(host.copyWith(x: x)))
                  .carryBeside(id, x - origin);
          final guest = moved.residents.firstWhere(
            (r) => r.instanceId == 'guest',
          );
          final distance = (guest.x - .7 + .5) % 1 - .5;
          expect(distance.abs(), greaterThanOrEqualTo(gap - 1e-9));
          // Sending just the host to a different row must not reserve room
          // for companions that will stay behind.
          final other = host.copyWith(depth: HomeDepth.back);
          expect(
            layout.freeSpotNear(other, requested),
            closeTo(requested, 1e-9),
          );
        },
      );
    }
  }
}
