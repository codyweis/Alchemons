import 'package:alchemons/services/cold_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fusion_harness.dart';

// Cold storage grows while the fusion tab sits open — a pair was refused for
// want of room, the player bought an upgrade — and the tab says so at once,
// rather than only after the app is restarted.
void main() {
  testWidgets('an upgrade to cold storage lifts "full" without a restart', (
    tester,
  ) async {
    final h = await FusionHarness.pump(
      tester,
      p1: 'fh',
      p2: 'wh',
      busy: 4,
      storageFull: true,
    );
    expect(find.text('CHAMBERS AND COLD STORAGE FULL'), findsOneWidget);
    expect(find.text('ALL FULL'), findsOneWidget);

    await tester.runAsync(() => ColdStorageService.setCapacity(h.db, 10));
    await h.settle(8);

    expect(find.text('CHAMBERS AND COLD STORAGE FULL'), findsNothing);
    expect(find.text('ALL FULL'), findsNothing);
    expect(find.text('FUSE'), findsOneWidget);
    await h.dispose();
  });
}
