import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

Future<void> reloadStateAfterSaveRestore(BuildContext context) async {
  final factionService = context.read<FactionService>();
  final shopService = context.read<ShopService>();
  final blackMarketService = context.read<BlackMarketService>();
  final survivalUpgradeService = context.read<SurvivalUpgradeService>();

  await factionService.reloadFromStorage();
  await shopService.reloadFromStorage();
  await blackMarketService.reloadFromStorage();
  await survivalUpgradeService.load();
}
