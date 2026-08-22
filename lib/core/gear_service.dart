import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import 'game_state.dart';
import 'gear/gear_bis_planner.dart';
import 'gear/gear_cleanup.dart';
import 'gear/gear_equip.dart';
import 'gear/gear_scorer.dart';
import 'gear/gear_stash.dart';
import 'gear/loot_resolver.dart';

export 'gear/loot_resolver.dart' show LootGrantResult, LootResolver;

/// Facade for gear inventory — delegates to `lib/core/gear/*` modules.
///
/// Public static API names are unchanged so [GameLogic] call sites stay stable.
abstract final class GearService {
  // --- Stash ---
  static const int maxGearStash = GearStash.maxGearStash;

  static int maxGearStashFor(GameState state) =>
      GearStash.maxGearStashFor(state);

  static const double bagWarnFraction = GearStash.bagWarnFraction;
  static const double bagJamFraction = GearStash.bagJamFraction;

  static int bagWarnAt(int cap) => GearStash.bagWarnAt(cap);
  static int bagJamAt(int cap) => GearStash.bagJamAt(cap);
  static bool isBagWarning(GameState state) => GearStash.isBagWarning(state);
  static bool isBagJammed(GameState state) => GearStash.isBagJammed(state);

  static GameState stashEquipment(GameState state, EquipmentItem item) =>
      GearStash.stashEquipment(state, item);

  static GameState clampStashToCap(GameState state) =>
      GearStash.clampStashToCap(state);

  static ({GameState state, int overflowEssence, String? overflowName})
  stashEquipmentDetailed(GameState state, EquipmentItem item) =>
      GearStash.stashEquipmentDetailed(state, item);

  static EquipmentItem? findGear(GameState state, String id) =>
      GearStash.findGear(state, id);

  static EquipmentItem? findStashGear(GameState state, String id) =>
      GearStash.findStashGear(state, id);

  static ({int heroIndex, EquipmentSlot slot})? findEquippedLocation(
    GameState state,
    String id,
  ) => GearStash.findEquippedLocation(state, id);

  static GameState removeGear(GameState state, String id) =>
      GearStash.removeGear(state, id);

  // --- Equip ---
  static GameState unequipIllegalGear(GameState state) =>
      GearEquip.unequipIllegalGear(state);

  static List<EquipmentSlot> equipTargetsFor(EquipmentItem item) =>
      GearEquip.equipTargetsFor(item);

  static bool canHeroReceive(
    PartyHero hero,
    EquipmentItem item, {
    required EquipmentSlot slot,
  }) => GearEquip.canHeroReceive(hero, item, slot: slot);

  static GameState equipFromStash(
    GameState state,
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) => GearEquip.equipFromStash(
    state,
    itemId,
    heroIndex: heroIndex,
    intoSlot: intoSlot,
  );

  static GameState unequipSlot(
    GameState state,
    EquipmentSlot slot, {
    int heroIndex = 0,
  }) => GearEquip.unequipSlot(state, slot, heroIndex: heroIndex);

  // --- Scoring ---
  static List<List<EquipmentSlot>> equipSlotGroups() =>
      GearScorer.equipSlotGroups();

  static int slotEquipScore(
    PartyHero hero,
    EquipmentItem? item, {
    required EquipmentSlot slot,
    List<EquipmentItem>? pairingStash,
  }) => GearScorer.slotEquipScore(
    hero,
    item,
    slot: slot,
    pairingStash: pairingStash,
  );

  static int bestPairingOffHandScore(
    PartyHero hero,
    List<EquipmentItem> stash, {
    String? excludeItemId,
  }) => GearScorer.bestPairingOffHandScore(
    hero,
    stash,
    excludeItemId: excludeItemId,
  );

  static ({EquipmentItem item, int score})? bestPairingOffHand(
    PartyHero hero,
    List<EquipmentItem> stash, {
    String? excludeItemId,
  }) => GearScorer.bestPairingOffHand(
    hero,
    stash,
    excludeItemId: excludeItemId,
  );

  static int specEquipScore(PartyHero hero, EquipmentItem item) =>
      GearScorer.specEquipScore(hero, item);

  static int itemBudgetScore(PartyHero hero, EquipmentItem item) =>
      GearScorer.itemBudgetScore(hero, item);

  static int roleEquipScore(
    HeroRole role,
    EquipmentItem item, {
    HeroSpecId? specId,
    int level = 60,
    double critMul = 1.0,
  }) => GearScorer.roleEquipScore(
    role,
    item,
    specId: specId,
    level: level,
    critMul: critMul,
  );

  static const int critScoreSoftSheet = GearScorer.critScoreSoftSheet;
  static const int critScoreHardSheet = GearScorer.critScoreHardSheet;

  static int sheetCritForEquip(PartyHero hero) =>
      GearScorer.sheetCritForEquip(hero);

  static double critScoreMul(PartyHero hero) => GearScorer.critScoreMul(hero);

  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
    EquipmentSlot intoSlot,
  })
  compareForHero(
    PartyHero hero,
    EquipmentItem candidate, {
    EquipmentSlot? intoSlot,
    List<EquipmentItem>? pairingStash,
  }) => GearScorer.compareForHero(
    hero,
    candidate,
    intoSlot: intoSlot,
    pairingStash: pairingStash,
  );

  static double roleRelevantStatMass(PartyHero hero, EquipmentItem item) =>
      GearScorer.roleRelevantStatMass(hero, item);

  static bool emptySlotWorthFilling(
    PartyHero hero,
    EquipmentItem item,
    int score,
  ) => GearScorer.emptySlotWorthFilling(hero, item, score);

  static bool isMeaningfulEquipUpgrade({
    required PartyHero hero,
    required EquipmentItem item,
    required int curScore,
    required int newScore,
    required bool slotEmpty,
    EquipmentItem? worn,
  }) => GearScorer.isMeaningfulEquipUpgrade(
    hero: hero,
    item: item,
    curScore: curScore,
    newScore: newScore,
    slotEmpty: slotEmpty,
    worn: worn,
  );

  // --- BiS / Auto Equip ---
  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
  planBiSAssignments(GameState state) =>
      GearBiSPlanner.planBiSAssignments(state);

  static int gearPlanSignature(GameState state) =>
      GearBiSPlanner.gearPlanSignature(state);

  static GameState autoEquipBetterGear(GameState state) =>
      GearBiSPlanner.autoEquipBetterGear(state);

  static String formatDelta(int value) {
    if (value > 0) return '+$value';
    if (value < 0) return '$value';
    return '0';
  }

  // --- Cleanup / merge / sell ---
  static int combineCost(
    EquipmentItem primary,
    EquipmentItem secondary, {
    int combinatorLuck = 0,
  }) => GearCleanup.combineCost(
    primary,
    secondary,
    combinatorLuck: combinatorLuck,
  );

  static bool canCombine(EquipmentItem primary, EquipmentItem secondary) =>
      GearCleanup.canCombine(primary, secondary);

  static LootRarity mergedRarity(LootRarity primary, LootRarity secondary) =>
      GearCleanup.mergedRarity(primary, secondary);

  static EquipmentItem mergeEquipment(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) => GearCleanup.mergeEquipment(primary, secondary);

  static EquipmentItem previewCombine(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) => GearCleanup.previewCombine(primary, secondary);

  static GameState combineGear(
    GameState state, {
    required String primaryId,
    required String secondaryId,
  }) => GearCleanup.combineGear(
    state,
    primaryId: primaryId,
    secondaryId: secondaryId,
  );

  static GameState sellGear(GameState state, String itemId) =>
      GearCleanup.sellGear(state, itemId);

  static GameState sellGearForGold(GameState state, String itemId) =>
      GearCleanup.sellGearForGold(state, itemId);

  static ({GameState state, List<LootDrop> resolved}) applyLootDrops(
    GameState state,
    List<LootDrop> drops,
  ) {
    final result = LootResolver.grant(state, drops);
    return (state: result.state, resolved: result.resolved);
  }

  static ({GameState state, List<LootDrop> resolved, LootGrantResult receipt})
  grantLoot(GameState state, List<LootDrop> drops) => LootResolver.grant(
    state,
    drops,
  );

  static GameState unstickBagIfNeeded(GameState state) =>
      GearCleanup.unstickBagIfNeeded(state);

  static GameState cleanBagJunk(
    GameState state, {
    bool unstickBag = false,
    bool mergeFirst = true,
  }) => GearCleanup.cleanBagJunk(
    state,
    unstickBag: unstickBag,
    mergeFirst: mergeFirst,
  );

  static bool shouldKeepInBag(GameState state, EquipmentItem item) =>
      GearCleanup.shouldKeepInBag(state, item);

  static bool shouldKeepWhenCleaning(
    GameState state,
    EquipmentItem item, {
    required bool forSell,
    bool unstickBag = false,
  }) => GearCleanup.shouldKeepWhenCleaning(
    state,
    item,
    forSell: forSell,
    unstickBag: unstickBag,
  );

  static ({GameState state, int merges}) autoMergeJunk(
    GameState state, {
    int maxMerges = 40,
  }) => GearCleanup.autoMergeJunk(state, maxMerges: maxMerges);

  static GameState autoSellJunk(GameState state, {bool unstickBag = false}) =>
      GearCleanup.autoSellJunk(state, unstickBag: unstickBag);

  static GameState autoDisassembleJunk(
    GameState state, {
    bool unstickBag = false,
  }) => GearCleanup.autoDisassembleJunk(state, unstickBag: unstickBag);

  static String rarityFilterLabel(int rarityIndex) =>
      GearCleanup.rarityFilterLabel(rarityIndex);

  // --- Loadouts ---
  static const int baseMaxLoadouts = GearCleanup.baseMaxLoadouts;
  static const int maxLoadoutBonus = GearCleanup.maxLoadoutBonus;
  static const int maxLoadouts = GearCleanup.maxLoadouts;

  static int maxLoadoutsFor(GameState state) =>
      GearCleanup.maxLoadoutsFor(state);

  static GameState saveLoadout(
    GameState state, {
    required String id,
    required String name,
  }) => GearCleanup.saveLoadout(state, id: id, name: name);

  static GameState deleteLoadout(GameState state, String id) =>
      GearCleanup.deleteLoadout(state, id);

  static ({GameState state, int skipped}) applyLoadout(
    GameState state,
    String id,
  ) => GearCleanup.applyLoadout(state, id);
}
