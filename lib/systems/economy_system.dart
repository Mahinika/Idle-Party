import '../managers/caps_manager.dart';

/// EconomySystem manages gold, spending, and item shop logic.
///
/// Update order: step 9.
class EconomySystem {
  final CapsManager capsManager;
  double _gold = 0.0;
  final List<Map<String, dynamic>> _itemCatalogue = [];

  EconomySystem({required this.capsManager});

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _itemCatalogue
      ..clear()
      ..addAll(data);
  }

  double get gold => _gold;

  void update(double deltaTime) {
    // Passive income could be added here in future.
  }

  void addGold(double amount) {
    _gold += amount;
  }

  /// Attempt to spend gold; returns true on success.
  bool spendGold(double amount) {
    if (_gold < amount) return false;
    _gold -= amount;
    return true;
  }

  /// Look up item cost from catalogue.
  double itemCost(String itemId) {
    try {
      final item = _itemCatalogue.firstWhere(
        (i) => i['id'] == itemId,
      );
      return (item['cost'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
