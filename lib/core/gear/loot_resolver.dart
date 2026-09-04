import '../../models/loot.dart';
import '../economy_service.dart';
import '../game_state.dart';
import '../loot_pipeline.dart';
import '../meta_systems.dart';
import 'gear_cleanup.dart';
import 'gear_stash.dart';

/// Receipt for one [LootResolver.grant] pass (floor clear, pickup batch, …).
class LootGrantResult {
  const LootGrantResult({
    this.goldGained = 0,
    this.essenceGained = 0,
    this.gearStashed = 0,
    this.gearAutoSold = 0,
    this.gearAutoDisassembled = 0,
    this.overflowEssence = 0,
    this.itemLabels = const <String>[],
  });

  final int goldGained;
  final int essenceGained;
  final int gearStashed;
  final int gearAutoSold;
  final int gearAutoDisassembled;
  final int overflowEssence;

  /// Short combat labels for gear that landed in BAG (clear toast).
  final List<String> itemLabels;

  bool get isEmpty =>
      goldGained == 0 &&
      essenceGained == 0 &&
      gearStashed == 0 &&
      gearAutoSold == 0 &&
      gearAutoDisassembled == 0 &&
      overflowEssence == 0 &&
      itemLabels.isEmpty;

  LootGrantResult merge(LootGrantResult other) {
    final labels = <String>[...itemLabels];
    for (final name in other.itemLabels) {
      if (labels.length >= 4) break;
      if (name.isNotEmpty && !labels.contains(name)) labels.add(name);
    }
    return LootGrantResult(
      goldGained: goldGained + other.goldGained,
      essenceGained: essenceGained + other.essenceGained,
      gearStashed: gearStashed + other.gearStashed,
      gearAutoSold: gearAutoSold + other.gearAutoSold,
      gearAutoDisassembled: gearAutoDisassembled + other.gearAutoDisassembled,
      overflowEssence: overflowEssence + other.overflowEssence,
      itemLabels: labels,
    );
  }

  /// Short player-facing line for floor-clear toasts.
  String summaryLine() {
    final bits = <String>[];
    if (itemLabels.isNotEmpty) {
      bits.add(itemLabels.take(3).join(', '));
    } else if (gearStashed > 0) {
      bits.add('$gearStashed gear');
    }
    if (gearAutoSold > 0) bits.add('$gearAutoSold sold');
    if (gearAutoDisassembled > 0) bits.add('$gearAutoDisassembled scrapped');
    if (goldGained > 0) bits.add('+$goldGained g');
    if (essenceGained > 0) bits.add('+$essenceGained e');
    if (overflowEssence > 0) bits.add('+$overflowEssence e overflow');
    if (bits.isEmpty) return '';
    return bits.join(' · ');
  }
}

/// Applies rolled loot drops to wallet / bag / filters.
abstract final class LootResolver {
  static ({GameState state, List<LootDrop> resolved, LootGrantResult receipt})
  grant(GameState state, List<LootDrop> drops) {
    var next = state;
    final resolved = <LootDrop>[];
    var receipt = const LootGrantResult();

    for (final drop in drops) {
      final item = drop.equipment;
      if (item == null) {
        if (LootPipeline.isWalletGoldDrop(drop)) {
          final gained = EconomyService.applyGoldGain(next, drop.amount);
          if (gained > 0) {
            next = next.copyWith(
              gold: next.gold + gained,
              lifetimeGoldEarned: next.lifetimeGoldEarned + gained,
            );
            receipt = receipt.merge(LootGrantResult(goldGained: gained));
          }
          resolved.add(
            drop.copyWith(outcome: LootOutcome.gold, essenceGained: 0),
          );
          continue;
        }
        final essence = LootPipeline.lootEssenceValue(drop);
        next = next.copyWith(essence: next.essence + essence);
        receipt = receipt.merge(LootGrantResult(essenceGained: essence));
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: essence),
        );
        continue;
      }

      if (GearCleanup.shouldAutoSellOnPickup(next, item)) {
        final value = LootPipeline.equipmentGoldValue(item);
        next = next.copyWith(
          gold: next.gold + value,
          lifetimeGoldEarned: next.lifetimeGoldEarned + value,
        );
        receipt = receipt.merge(
          LootGrantResult(goldGained: value, gearAutoSold: 1),
        );
        resolved.add(
          drop.copyWith(outcome: LootOutcome.gold, essenceGained: 0),
        );
        continue;
      }

      if (GearCleanup.shouldAutoDisassembleOnPickup(next, item)) {
        final value = LootPipeline.equipmentEssenceValue(item);
        next = next.copyWith(essence: next.essence + value);
        receipt = receipt.merge(
          LootGrantResult(essenceGained: value, gearAutoDisassembled: 1),
        );
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: value),
        );
        continue;
      }

      final stashed = GearStash.stashEquipmentDetailed(next, item);
      next = stashed.state;
      final label = item.combatPopLabel.isNotEmpty
          ? item.combatPopLabel
          : item.name;
      receipt = receipt.merge(
        LootGrantResult(
          gearStashed: 1,
          overflowEssence: stashed.overflowEssence,
          essenceGained: stashed.overflowEssence,
          itemLabels: label.isNotEmpty ? <String>[label] : const <String>[],
        ),
      );
      resolved.add(
        drop.copyWith(
          outcome: LootOutcome.stashed,
          essenceGained: stashed.overflowEssence,
        ),
      );
    }

    next = MetaSystems.registerItemDrops(next, drops);
    next = GearCleanup.unstickBagIfNeeded(next);
    return (state: next, resolved: resolved, receipt: receipt);
  }
}
