// lib/providers/selected_party_notifier.dart
import 'package:flutter/foundation.dart';
import '../models/wilderness.dart'; // PartyMember

class SelectedPartyNotifier extends ChangeNotifier {
  static const maxSize = 3;

  final List<PartyMember> _members = [];
  List<PartyMember> get members => List.unmodifiable(_members);

  bool contains(String instanceId) =>
      _members.any((m) => m.instanceId == instanceId);

  bool get isFull => _members.length >= maxSize;

  void toggle(String instanceId, {double luck = 0.0}) {
    final i = _members.indexWhere((m) => m.instanceId == instanceId);
    if (i >= 0) {
      _members.removeAt(i);
    } else {
      if (_members.length < maxSize) {
        _members.add(PartyMember(instanceId: instanceId, luck: luck));
      }
    }
    notifyListeners();
  }

  void clear() {
    _members.clear();
    notifyListeners();
  }
}
