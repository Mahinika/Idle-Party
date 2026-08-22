import 'dart:math';

import '../../models/loot.dart';
import '../../models/proficiency.dart';
import '../game_state.dart';
import 'gear_equip.dart';
import 'gear_scorer.dart';

/// BiS assignment planning and Auto Equip passes.
abstract final class GearBiSPlanner {
  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
  planBiSAssignments(GameState state) {
    final signature = gearPlanSignature(state);
    final cached = _bisPlan;
    if (cached != null && signature == _bisPlanSignature) return cached;
    final plan =
        List<
          ({int heroIndex, EquipmentSlot slot, String itemId, int delta})
        >.unmodifiable(computeBiSAssignments(state));
    _bisPlanSignature = signature;
    _bisPlan = plan;
    return plan;
  }

  static int _bisPlanSignature = 0;

  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>?
  _bisPlan;

  static int gearPlanSignature(GameState state) {
    var h = state.gearStash.length * 31 + state.heroes.length;
    for (final item in state.gearStash) {
      h = (h * 33) ^ item.id.hashCode ^ item.effectiveItemLevel;
    }
    for (final hero in state.heroes) {
      h = (h * 33) ^ hero.specId.index ^ (hero.level * 7);
      for (final entry in hero.equipped.entries) {
        h = (h * 33) ^ entry.key.index ^ entry.value.id.hashCode;
      }
    }
    return h & 0x3FFFFFFF;
  }

  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
  computeBiSAssignments(GameState state) {
    final stashById = <String, EquipmentItem>{
      for (final item in state.gearStash) item.id: item,
    };
    if (stashById.isEmpty) return const [];

    final reserved = <String>{};
    final plan =
        <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];
    final filledSlots = <String>{};

    String slotKey(int heroIndex, EquipmentSlot slot) =>
        '$heroIndex:${slot.name}';

    for (var round = 0; round < 6; round++) {
      final proposals =
          <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];

      for (var hi = 0; hi < state.heroes.length; hi++) {
        final hero = state.heroes[hi];
        String? plannedWeaponId;
        for (final p in plan) {
          if (p.heroIndex == hi && p.slot == EquipmentSlot.weapon) {
            plannedWeaponId = p.itemId;
            break;
          }
        }
        final plannedWeapon = plannedWeaponId == null
            ? hero.itemIn(EquipmentSlot.weapon)
            : stashById[plannedWeaponId] ?? hero.itemIn(EquipmentSlot.weapon);
        final blocksOffHand = ClassProficiency.weaponBlocksOffHand(
          plannedWeapon,
        );

        for (final group in GearScorer.equipSlotGroups()) {
          if (blocksOffHand &&
              group.length == 1 &&
              group.first == EquipmentSlot.offHand &&
              !ClassProficiency.prefersOneHandAndShield(hero.spec)) {
            continue;
          }

          final available = <EquipmentItem>[
            for (final item in state.gearStash)
              if (!reserved.contains(item.id)) item,
          ];
          final pairing = state.gearStash;

          final scored = <({EquipmentItem item, int score})>[];
          for (final item in available) {
            if (!GearEquip.equipTargetsFor(item).any(group.contains)) continue;
            var best = -999999;
            for (final slot in group) {
              if (filledSlots.contains(slotKey(hi, slot))) continue;
              if (!GearEquip.canHeroReceive(hero, item, slot: slot)) continue;
              best = max(
                best,
                GearScorer.slotEquipScore(
                  hero,
                  item,
                  slot: slot,
                  pairingStash: pairing,
                ),
              );
            }
            if (best > -999999) {
              scored.add((item: item, score: best));
            }
          }
          scored.sort((a, b) => b.score.compareTo(a.score));

          final slots = [...group]
            ..sort((a, b) {
              final sa = filledSlots.contains(slotKey(hi, a))
                  ? 999999
                  : GearScorer.slotEquipScore(
                      hero,
                      hero.itemIn(a),
                      slot: a,
                      pairingStash: pairing,
                    );
              final sb = filledSlots.contains(slotKey(hi, b))
                  ? 999999
                  : GearScorer.slotEquipScore(
                      hero,
                      hero.itemIn(b),
                      slot: b,
                      pairingStash: pairing,
                    );
              return sa.compareTo(sb);
            });

          final usedLocal = <String>{};
          for (final slot in slots) {
            if (filledSlots.contains(slotKey(hi, slot))) continue;
            final cur = hero.itemIn(slot);
            final curScore = GearScorer.slotEquipScore(
              hero,
              cur,
              slot: slot,
              pairingStash: pairing,
            );
            for (final entry in scored) {
              if (usedLocal.contains(entry.item.id)) continue;
              if (reserved.contains(entry.item.id)) continue;
              if (!GearEquip.canHeroReceive(hero, entry.item, slot: slot)) {
                continue;
              }
              final sc = GearScorer.slotEquipScore(
                hero,
                entry.item,
                slot: slot,
                pairingStash: pairing,
              );
              if (GearScorer.isMeaningfulEquipUpgrade(
                hero: hero,
                item: entry.item,
                worn: cur,
                curScore: curScore,
                newScore: sc,
                slotEmpty: cur == null,
              )) {
                usedLocal.add(entry.item.id);
                proposals.add((
                  heroIndex: hi,
                  slot: slot,
                  itemId: entry.item.id,
                  delta: sc - curScore,
                ));
                break;
              }
            }
          }
        }
      }

      if (proposals.isEmpty) break;

      final bestByItem =
          <
            String,
            ({int heroIndex, EquipmentSlot slot, String itemId, int delta})
          >{};
      for (final p in proposals) {
        final prev = bestByItem[p.itemId];
        if (prev == null || p.delta > prev.delta) {
          bestByItem[p.itemId] = p;
        }
      }

      final bestBySlot =
          <
            String,
            ({int heroIndex, EquipmentSlot slot, String itemId, int delta})
          >{};
      for (final p in bestByItem.values) {
        final key = slotKey(p.heroIndex, p.slot);
        final prev = bestBySlot[key];
        if (prev == null || p.delta > prev.delta) {
          bestBySlot[key] = p;
        }
      }

      var added = 0;
      final winners = bestBySlot.values.toList()
        ..sort((a, b) => b.delta.compareTo(a.delta));
      final claimedThisRound = <String>{};
      for (final w in winners) {
        if (reserved.contains(w.itemId)) continue;
        if (claimedThisRound.contains(w.itemId)) continue;
        final key = slotKey(w.heroIndex, w.slot);
        if (filledSlots.contains(key)) continue;
        reserved.add(w.itemId);
        claimedThisRound.add(w.itemId);
        filledSlots.add(key);
        plan.add(w);
        added++;

        if (w.slot == EquipmentSlot.weapon) {
          final heroNow = state.heroes[w.heroIndex];
          final wornW = heroNow.itemIn(EquipmentSlot.weapon);
          EquipmentItem? incoming;
          for (final g in state.gearStash) {
            if (g.id == w.itemId) {
              incoming = g;
              break;
            }
          }
          if (incoming != null &&
              ClassProficiency.weaponBlocksOffHand(wornW) &&
              !ClassProficiency.weaponBlocksOffHand(incoming)) {
            final ohKey = slotKey(w.heroIndex, EquipmentSlot.offHand);
            if (!filledSlots.contains(ohKey) &&
                heroNow.itemIn(EquipmentSlot.offHand) == null) {
              final paired = GearScorer.bestPairingOffHand(heroNow, [
                for (final g in state.gearStash)
                  if (!reserved.contains(g.id) &&
                      !claimedThisRound.contains(g.id))
                    g,
              ], excludeItemId: w.itemId);
              if (paired != null) {
                reserved.add(paired.item.id);
                claimedThisRound.add(paired.item.id);
                filledSlots.add(ohKey);
                plan.add((
                  heroIndex: w.heroIndex,
                  slot: EquipmentSlot.offHand,
                  itemId: paired.item.id,
                  delta: paired.score,
                ));
                added++;
              }
            }
          }
        }
      }
      if (added == 0) break;
    }

    return plan;
  }

  static GameState autoEquipBetterGear(GameState state) {
    var next = state;
    for (var pass = 0; pass < 8; pass++) {
      final beforeLen = next.gearStash.length;
      next = autoEquipPass(next);
      if (next.gearStash.length >= beforeLen) {
        break;
      }
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState autoEquipPass(GameState state) {
    var next = state;
    final plan = planBiSAssignments(next);
    final ordered = [...plan]
      ..sort((a, b) {
        final aw = a.slot == EquipmentSlot.weapon ? 0 : 1;
        final bw = b.slot == EquipmentSlot.weapon ? 0 : 1;
        return aw.compareTo(bw);
      });

    for (final emptySlotsOnly in [true, false]) {
      for (final step in ordered) {
        final hero = next.heroes[step.heroIndex];
        final slotEmpty = hero.itemIn(step.slot) == null;
        if (emptySlotsOnly != slotEmpty) continue;

        EquipmentItem? item;
        for (final g in next.gearStash) {
          if (g.id == step.itemId) {
            item = g;
            break;
          }
        }
        if (item == null) continue;
        if (!GearEquip.canHeroReceive(hero, item, slot: step.slot)) continue;
        final beforeLen = next.gearStash.length;
        next = GearEquip.equipFromStash(
          next,
          step.itemId,
          heroIndex: step.heroIndex,
          intoSlot: step.slot,
        );
        if (next.gearStash.length >= beforeLen) {
          continue;
        }
      }
    }
    return next;
  }
}
