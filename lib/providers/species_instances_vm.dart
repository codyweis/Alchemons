import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:alchemons/database/alchemons_db.dart';

class SpeciesInstancesVM extends ChangeNotifier {
  final AlchemonsDatabase db;
  final String baseId;
  StreamSubscription<List<CreatureInstance>>? _sub;

  SpeciesInstancesVM(this.db, this.baseId) {
    _sub = db.creatureDao.watchInstancesBySpecies(baseId).listen((rows) {
      _instances = rows;
      notifyListeners();
    });
    _initCount();
  }

  static const int cap = 100;

  List<CreatureInstance> _instances = [];
  List<CreatureInstance> get instances => _instances;

  int _count = 0;
  int get count => _count;

  Future<void> _initCount() async {
    _count = await db.creatureDao.countBySpecies(baseId);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
