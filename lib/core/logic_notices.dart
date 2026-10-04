/// One-shot receipts from the rules layer to whoever shows toasts.
///
/// Some rules run deep inside a call chain (a bag that unsticks itself while
/// a room completes, craft mats a boss dropped) and the player still needs a
/// toast for it. These used to be six loose mutable statics on `GameLogic`
/// that [GameDirector] had to zero out by hand in five places — miss one and
/// the next automatic pass reports a sale that already happened.
///
/// Now every reader *takes* its receipt: reading clears it. A caller that
/// already told the player something calls the same take and drops the value.
library;

/// What a bag cleanup pass actually did.
class BagCleanupReceipt {
  const BagCleanupReceipt({
    this.sold = 0,
    this.goldGained = 0,
    this.scrapped = 0,
    this.essenceGained = 0,
    this.merged = 0,
    this.goldSpent = 0,
  });

  final int sold;
  final int goldGained;
  final int scrapped;
  final int essenceGained;

  /// Junk pairs combined while the bag cleaned itself.
  final int merged;

  /// Gold those combines spent. A floor clear can still toast a gain.
  final int goldSpent;

  bool get isEmpty => sold == 0 && scrapped == 0 && merged == 0;

  /// Player line for one cleanup pass. Empty when nothing happened.
  String? get combatLine {
    final bits = <String>[
      if (sold > 0) 'sold $sold (+${goldGained}g)',
      if (scrapped > 0) 'scrap $scrapped (+${essenceGained}e)',
      if (merged > 0) 'merged $merged (-${goldSpent}g)',
    ];
    if (bits.isEmpty) return null;
    return 'Bag unstuck · ${bits.join(' · ')}';
  }
}

abstract final class LogicNotices {
  static BagCleanupReceipt _bag = const BagCleanupReceipt();
  static List<String> _craftMats = const <String>[];
  static List<String> _metaPayoffs = const <String>[];
  static String? _floorLootLine;
  static String? _floorEquipLine;
  static int _questReady = 0;

  /// Reads and clears what the last auto-sell / disassemble pass cleared out.
  static BagCleanupReceipt takeBagCleanup() {
    final out = _bag;
    _bag = const BagCleanupReceipt();
    return out;
  }

  static void recordAutoSell({required int sold, required int gold}) {
    _bag = BagCleanupReceipt(
      sold: sold,
      goldGained: gold,
      scrapped: _bag.scrapped,
      essenceGained: _bag.essenceGained,
      merged: _bag.merged,
      goldSpent: _bag.goldSpent,
    );
  }

  static void recordDisassemble({required int scrapped, required int essence}) {
    _bag = BagCleanupReceipt(
      sold: _bag.sold,
      goldGained: _bag.goldGained,
      scrapped: scrapped,
      essenceGained: essence,
      merged: _bag.merged,
      goldSpent: _bag.goldSpent,
    );
  }

  static void recordAutoMerge({required int merged, required int goldSpent}) {
    if (merged <= 0 && goldSpent <= 0) return;
    _bag = BagCleanupReceipt(
      sold: _bag.sold,
      goldGained: _bag.goldGained,
      scrapped: _bag.scrapped,
      essenceGained: _bag.essenceGained,
      merged: merged,
      goldSpent: goldSpent,
    );
  }

  /// Craft mats a boss just granted (`matId`s, may repeat).
  static List<String> takeCraftMats() {
    final out = _craftMats;
    _craftMats = const <String>[];
    return out;
  }

  static void startCraftMats() => _craftMats = <String>[];

  static void addCraftMat(String matId) {
    _craftMats = <String>[..._craftMats, matId];
  }

  /// Meta payoff lines ("Season 2026-08 · +14e") waiting for a toast.
  static List<String> takeMetaPayoffs() {
    final out = _metaPayoffs;
    _metaPayoffs = const <String>[];
    return out;
  }

  static void setMetaPayoffs(List<String> lines) =>
      _metaPayoffs = List<String>.unmodifiable(lines);

  static void addMetaPayoffs(List<String> lines) {
    if (lines.isEmpty) return;
    _metaPayoffs = List<String>.unmodifiable([..._metaPayoffs, ...lines]);
  }

  /// Short loot grant summary from floor clear ([LootGrantResult.summaryLine]).
  static String? takeFloorLootLine() {
    final out = _floorLootLine;
    _floorLootLine = null;
    return out;
  }

  static void recordFloorLootLine(String line) {
    if (line.isEmpty) return;
    _floorLootLine = line;
  }

  /// Post-floor auto-equip summary (`Equipped N · M kept in bag`).
  static String? takeFloorEquipLine() {
    final out = _floorEquipLine;
    _floorEquipLine = null;
    return out;
  }

  /// Slots that just became claimable (from [MissionBoard.applyMissionProgress]).
  static int takeQuestReady() {
    final out = _questReady;
    _questReady = 0;
    return out;
  }

  static void recordQuestReady(int count) {
    if (count <= 0) return;
    _questReady += count;
  }

  /// Test/reset hook — drops every pending receipt.
  static void reset() {
    _bag = const BagCleanupReceipt();
    _craftMats = const <String>[];
    _metaPayoffs = const <String>[];
    _floorLootLine = null;
    _floorEquipLine = null;
    _questReady = 0;
  }
}
