// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shop_dao.dart';

// ignore_for_file: type=lint
mixin _$ShopDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $ShopPurchasesTable get shopPurchases => attachedDatabase.shopPurchases;
  ShopDaoManager get managers => ShopDaoManager(this);
}

class ShopDaoManager {
  final _$ShopDaoMixin _db;
  ShopDaoManager(this._db);
  $$ShopPurchasesTableTableManager get shopPurchases =>
      $$ShopPurchasesTableTableManager(_db.attachedDatabase, _db.shopPurchases);
}
