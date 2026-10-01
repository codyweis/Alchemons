import 'package:alchemons/screens/shop/gold_vault.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _packs = [
  GoldPackDefinition(
    productId: 'cache',
    title: 'Gold Cache',
    subtitle: 'a',
    goldAmount: 25,
    badge: 'STARTER',
  ),
  GoldPackDefinition(
    productId: 'stash',
    title: 'Gold Stash',
    subtitle: 'b',
    goldAmount: 75,
    badge: 'POPULAR',
  ),
  GoldPackDefinition(
    productId: 'vault',
    title: 'Gold Vault',
    subtitle: 'c',
    goldAmount: 200,
    badge: 'VALUE',
  ),
];

List<GoldVaultOffer> _offers({
  bool priced = true,
  String? pending,
  List<double> prices = const [0.99, 2.99, 4.99],
}) => [
  for (var i = 0; i < _packs.length; i++)
    GoldVaultOffer(
      pack: _packs[i],
      price: priced ? '\$${prices[i]}' : null,
      rawPrice: priced ? prices[i] : null,
      pending: _packs[i].productId == pending,
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  required List<GoldVaultOffer> offers,
  bool needsAccount = false,
  void Function(String)? onBuy,
  VoidCallback? onSignIn,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GoldVaultDeck(
            offers: offers,
            needsAccount: needsAccount,
            onBuy: onBuy ?? (_) {},
            onSignIn: onSignIn ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test('bonus is gold per unit of money against the smallest pack', () {
    final b = GoldVaultOffer.bonuses(_offers());
    expect(b[0], 0);
    // 75 / 2.99 vs 25 / 0.99: very slightly worse, so no bonus.
    expect(b[1], -1);
    // 200 / 4.99 vs 25 / 0.99.
    expect(b[2], 59);
  });

  test('no bonus without the store prices', () {
    expect(GoldVaultOffer.bonuses(_offers(priced: false)), [null, null, null]);
  });

  testWidgets('opens on the popular pack and buys the one chosen', (
    tester,
  ) async {
    final bought = <String>[];
    await _pump(tester, offers: _offers(), onBuy: bought.add);

    expect(find.text('GOLD STASH'), findsOneWidget);
    await tester.tap(find.text('BUY · \$2.99'));
    expect(bought, ['stash']);

    await tester.tap(find.text('200'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('GOLD VAULT'), findsOneWidget);
    await tester.tap(find.text('BUY · \$4.99'));
    expect(bought, ['stash', 'vault']);
    // The best-value tag sits on the pack that really is the best value.
    expect(find.text('BEST VALUE'), findsOneWidget);
    expect(find.text('+59% GOLD'), findsOneWidget);
  });

  testWidgets('signed out, the button leads to signing in', (tester) async {
    var signIns = 0;
    final bought = <String>[];
    await _pump(
      tester,
      offers: _offers(),
      needsAccount: true,
      onBuy: bought.add,
      onSignIn: () => signIns++,
    );
    await tester.tap(find.text('SIGN IN TO BUY'));
    expect(signIns, 1);
    expect(bought, isEmpty);
  });

  testWidgets('nothing can be bought without a price or while pending', (
    tester,
  ) async {
    final bought = <String>[];
    await _pump(tester, offers: _offers(priced: false), onBuy: bought.add);
    await tester.tap(find.text('UNAVAILABLE'));
    expect(bought, isEmpty);

    await _pump(tester, offers: _offers(pending: 'stash'), onBuy: bought.add);
    await tester.tap(find.text('CONFIRMING…'));
    expect(bought, isEmpty);
  });
}
