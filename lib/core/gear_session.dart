import 'package:flutter/foundation.dart';

import '../models/loot.dart';

/// Ephemeral GEAR sheet state — not a destination, not saved.
class GearSession extends ChangeNotifier {
  String? _selectedItemId;
  String? _combineA;
  String? _combineB;
  int _equipHeroIndex = 0;
  int _abilityHeroIndex = 0;
  EquipmentSlot? _bagSlotFilter;
  int _bagFiltersScrollNonce = 0;

  String? get selectedItemId => _selectedItemId;
  String? get combineA => _combineA;
  String? get combineB => _combineB;
  int get equipHeroIndex => _equipHeroIndex;
  int get abilityHeroIndex => _abilityHeroIndex;
  EquipmentSlot? get bagSlotFilter => _bagSlotFilter;
  int get bagFiltersScrollNonce => _bagFiltersScrollNonce;

  void selectItem(String? id) {
    _selectedItemId = _selectedItemId == id ? null : id;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedItemId == null) return;
    _selectedItemId = null;
    notifyListeners();
  }

  set equipHeroIndex(int index) {
    if (_equipHeroIndex == index) return;
    _equipHeroIndex = index;
    notifyListeners();
  }

  set abilityHeroIndex(int index) {
    if (_abilityHeroIndex == index) return;
    _abilityHeroIndex = index;
    notifyListeners();
  }

  void setBagSlotFilter(EquipmentSlot? slot) {
    _bagSlotFilter = slot;
    _selectedItemId = null;
    notifyListeners();
  }

  void clearBagSlotFilter() {
    if (_bagSlotFilter == null) return;
    _bagSlotFilter = null;
    notifyListeners();
  }

  void bumpBagFiltersScroll() {
    _bagFiltersScrollNonce++;
    notifyListeners();
  }

  /// Load the merge slots. Returns true once both slots are filled.
  bool putInCombinator(String id) {
    if (_combineA == id) {
      _combineA = null;
      notifyListeners();
      return false;
    }
    if (_combineB == id) {
      _combineB = null;
      notifyListeners();
      return false;
    }
    if (_combineA == null) {
      _combineA = id;
    } else if (_combineB == null) {
      _combineB = id;
    } else {
      _combineA = _combineB;
      _combineB = id;
    }
    final ready = _combineA != null && _combineB != null;
    notifyListeners();
    return ready;
  }

  void clearCombineA() {
    _combineA = null;
    notifyListeners();
  }

  void clearCombineB() {
    _combineB = null;
    notifyListeners();
  }

  void clearCombine() {
    _combineA = null;
    _combineB = null;
    _selectedItemId = null;
    notifyListeners();
  }

  void dropMissingIds(Set<String> liveIds) {
    var changed = false;
    if (_selectedItemId != null && !liveIds.contains(_selectedItemId)) {
      _selectedItemId = null;
      changed = true;
    }
    if (_combineA != null && !liveIds.contains(_combineA)) {
      _combineA = null;
      changed = true;
    }
    if (_combineB != null && !liveIds.contains(_combineB)) {
      _combineB = null;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
