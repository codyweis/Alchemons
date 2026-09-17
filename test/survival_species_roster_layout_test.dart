import 'package:alchemons/games/cosmic_survival/cosmic_survival_screen.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every roster card, expanded, fits the height the carousel gives it — at a
/// card width as narrow as a small phone shows it, where the text wraps most.
void main() {
  const ids = ['Let', 'Pip', 'Mane', 'Horn', 'Mask', 'Wing', 'Kin', 'Mystic'];

  for (final width in const [250.0, 320.0]) {
    testWidgets('expanded cards fit at ${width.toInt()} wide', (tester) async {
      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final id in ids)
                    for (final withPath in const [false, true])
                      SizedBox(
                        width: width,
                        child: SurvivalSpeciesCardPreview(
                          familyId: id,
                          expanded: true,
                          owned: withPath ? _allOf(id) : const {},
                          selectedPathId: withPath ? _firstPath(id) : null,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

CreatureFamily _family(String id) => creatureFamilyFromStorage(id)!;

String _firstPath(String id) =>
    FamilyMasteryCatalog.treeFor(_family(id)).paths.first.id;

Set<String> _allOf(String id) => FamilyMasteryCatalog.treeFor(
  _family(id),
).paths.first.nodes.map((n) => n.id).toSet();
