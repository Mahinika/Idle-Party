import '../../models/loot.dart';
import '../../models/proficiency.dart';
import '../game_state.dart';
import 'gear_equip.dart';
import 'gear_scorer.dart';

/// Finish a 2H ↔ 1H+off-hand swap in one equip so BAG/TODAY do not split the set.
abstract final class GearWeaponSet {
  /// After a stash equip, fill the empty half of a 1H+off-hand set from the bag.
  static GameState completeAfterEquip(GameState state, int heroIndex) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) return state;
    final hero = state.heroes[heroIndex];
    final wep = hero.itemIn(EquipmentSlot.weapon);
    final oh = hero.itemIn(EquipmentSlot.offHand);

    if (wep != null &&
        !ClassProficiency.weaponBlocksOffHand(wep) &&
        oh == null) {
      final pair = GearScorer.bestPairingOffHand(hero, state.gearStash);
      if (pair != null) {
        return GearEquip.equipFromStash(
          state,
          pair.item.id,
          heroIndex: heroIndex,
          intoSlot: EquipmentSlot.offHand,
        );
      }
    }

    if (oh != null && wep == null) {
      final mh = GearScorer.bestPairingOneHand(hero, state.gearStash);
      if (mh != null) {
        return GearEquip.equipFromStash(
          state,
          mh.item.id,
          heroIndex: heroIndex,
          intoSlot: EquipmentSlot.weapon,
        );
      }
    }

    return state;
  }
}
