// lib/providers/selected_party_notifier.dart
import 'package:flutter/foundation.dart';
import '../models/wilderness.dart'; // PartyMember

// lib/providers/selected_party_notifier.dart
import 'package:flutter/foundation.dart';
import '../models/wilderness.dart'; // PartyMember

class SelectedPartyNotifier extends ChangeNotifier {
  static const maxSize = 4; // ⬅️ changed from 3 to 4

  final List<PartyMember> _members = [];
  List<PartyMember> get members => List.unmodifiable(_members);

  bool contains(String instanceId) =>
      _members.any((m) => m.instanceId == instanceId);

  bool get isFull => _members.length >= maxSize;

  /// Replace the party with a new list (up to [maxSize]).
  /// Used by PartyPicker to prune "ghost" members that no longer exist in the DB.
  void setMembers(List<PartyMember> members) {
    _members
      ..clear()
      ..addAll(members.take(maxSize));
    notifyListeners();
  }

  /// Optional helper if you ever want to prune based on a known set of valid IDs.
  void pruneToExisting(Set<String> existingInstanceIds) {
    final before = _members.length;
    _members.removeWhere((m) => !existingInstanceIds.contains(m.instanceId));
    if (_members.length != before) {
      notifyListeners();
    }
  }

  void toggle(String instanceId) {
    final i = _members.indexWhere((m) => m.instanceId == instanceId);

    // If already present, remove it.
    if (i >= 0) {
      _members.removeAt(i);
      notifyListeners();
      return;
    }

    // If full, do nothing.
    if (_members.length >= maxSize) {
      return;
    }

    // Otherwise add as a new member.
    _members.add(PartyMember(instanceId: instanceId));
    notifyListeners();
  }

  void clear() {
    _members.clear();
    notifyListeners();
  }
}
