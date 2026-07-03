import 'rune_system.dart';

class Item {
  final String id;
  final String name;
  final String slot; // "Weapon", "Offhand", "Chest", etc.
  final double attackBoost;
  final double defenseBoost;
  final String rarity;
  final double goldValue;
  final List<Rune> socketedRunes = [];
  final int maxSockets;

  Item({
    required this.id,
    required this.name,
    required this.slot,
    required this.attackBoost,
    required this.defenseBoost,
    required this.rarity,
    required this.goldValue,
    this.maxSockets = 2,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      slot: json['slot'] as String,
      attackBoost: (json['attack_boost'] as num).toDouble(),
      defenseBoost: (json['defense_boost'] as num).toDouble(),
      rarity: json['rarity'] as String,
      goldValue: (json['gold_value'] as num).toDouble(),
      maxSockets: json['slot'] == 'Weapon' ? 2 : 1, // Weapons have 2 sockets, others 1
    );
  }
}

class InventorySystem {
  final List<Item> _items = [];
  final Map<String, Map<String, Item>> _equippedItems = {}; // heroId -> {slot -> Item}

  InventorySystem();

  List<Item> get items => List.unmodifiable(_items);

  void addItem(Item item) {
    _items.add(item);
  }

  bool removeItem(Item item) {
    return _items.remove(item);
  }

  /// Equips an item from inventory onto a hero.
  /// If an item was already in that slot, it is unequipped back to inventory.
  bool equipItem(String heroId, Item item) {
    if (!_items.contains(item)) return false;

    // Unequip current slot if occupied
    unequipItem(heroId, item.slot);

    _items.remove(item);
    _equippedItems.putIfAbsent(heroId, () => {})[item.slot] = item;
    return true;
  }

  /// Unequips an item from a slot, moving it back to inventory.
  Item? unequipItem(String heroId, String slot) {
    final heroEquipped = _equippedItems[heroId];
    if (heroEquipped == null || !heroEquipped.containsKey(slot)) return null;

    final item = heroEquipped.remove(slot);
    if (item != null) {
      _items.add(item);
    }
    return item;
  }

  List<Item> getEquippedItems(String heroId) {
    final heroEquipped = _equippedItems[heroId];
    if (heroEquipped == null) return [];
    return heroEquipped.values.toList();
  }

  Item? getEquippedItemInSlot(String heroId, String slot) {
    return _equippedItems[heroId]?[slot];
  }

  /// Adds a rune to an item's sockets.
  bool socketRuneInItem(Item item, Rune rune) {
    if (item.socketedRunes.length >= item.maxSockets) {
      return false;
    }
    item.socketedRunes.add(rune);
    return true;
  }

  /// Clears all runes from an item.
  List<Rune> unsocketAllRunes(Item item) {
    final runes = List<Rune>.from(item.socketedRunes);
    item.socketedRunes.clear();
    return runes;
  }

  double getHeroAttackBoost(String heroId) {
    final equipped = getEquippedItems(heroId);
    return equipped.fold(0.0, (sum, item) => sum + item.attackBoost);
  }

  double getHeroDefenseBoost(String heroId) {
    final equipped = getEquippedItems(heroId);
    return equipped.fold(0.0, (sum, item) => sum + item.defenseBoost);
  }

  /// Resets inventory state (e.g. on hard reset or prestige based on game rules).
  void clearAll() {
    _items.clear();
    _equippedItems.clear();
  }
}
