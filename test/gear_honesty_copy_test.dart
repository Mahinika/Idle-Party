import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/gear/gear_scorer.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/models/gear_set.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/proficiency.dart';
import 'package:idle_party/ui/character_equip_panel.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';

void main() {
  test('forge soft knee reduces next sheet % past the knee', () {
    expect(GameState.softForgeNextGain(0, 2), 2);
    expect(GameState.softForgeNextGain(40, 2), closeTo(0.7, 0.001));
    expect(GameState.softForgeNextGain(25, 2, softAt: 25), closeTo(0.7, 0.001));
  });

  test('forge mastery gain is 4', () {
    expect(GameLogic.forgeMasteryGain, 4);
  });

  test('menu forge alert uses HASTE not ATTACKSPEED', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 9, 30));
    state = state.copyWith(gold: 50000, attackSpeedBonus: 0, attackBonus: 200);
    // Force recommended toward haste if possible; else assert mapping helper.
    final alert = MenuAlerts.forgeAlert(state);
    expect(alert.reason.toUpperCase(), isNot(contains('ATTACKSPEED')));
    expect(
      alert.reason.contains('BEST'),
      isTrue,
    );
  });

  test('empty-slot fill ignores preferred-armor soft help', () {
    final hero = GameLogic.createInitialState(now: DateTime(2026, 9, 30))
        .heroes
        .first
        .copyWith(level: 20);
    // Tank STA×10: 2 STA → mass 20 / score ~20. Old preferred soft path
    // (nearLevel + mass≥16) would fill; score/ilvl floors must not.
    final plateNear = EquipmentItem(
      id: 'junk_plate',
      name: 'Junk Plate',
      slot: EquipmentSlot.wrist,
      rarity: LootRarity.common,
      armorType: ArmorType.plate,
      staminaBonus: 2,
      itemLevel: 9,
    );
    final score = GearScorer.specEquipScore(hero, plateNear);
    final mass = GearScorer.roleRelevantStatMass(hero, plateNear);
    expect(mass >= 16, isTrue);
    expect(score < 90, isTrue);
    expect(GearScorer.emptySlotWorthFilling(hero, plateNear, score), isFalse);
  });

  test('role mass counts mastery', () {
    final hero = GameLogic.createInitialState(now: DateTime(2026, 9, 30))
        .heroes
        .first;
    final withMastery = EquipmentItem(
      id: 'm',
      name: 'M',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      armorType: ArmorType.plate,
      masteryBonus: 20,
      itemLevel: 40,
    );
    final plain = withMastery.copyWith(masteryBonus: 0);
    expect(
      GearScorer.roleRelevantStatMass(hero, withMastery),
      greaterThan(GearScorer.roleRelevantStatMass(hero, plain)),
    );
  });

  test('4pc text can name role extras', () {
    expect(
      GearSets.fourPieceBonusText('sandy_plate', role: HeroRole.warrior),
      contains('+4 Armor'),
    );
    expect(
      GearSets.fourPieceBonusText('sandy_cloth', role: HeroRole.mage),
      contains('+2 SP'),
    );
  });

  test('hunter leather remains legal at 40 with mail preferred', () {
    final spec = HeroSpecs.def(HeroSpecId.beastMastery);
    expect(
      ClassProficiency.canEquipArmorForSpec(spec, 40, ArmorType.leather),
      isTrue,
    );
    expect(ClassProficiency.preferredArmor(spec, 40), ArmorType.mail);
  });

  test('dungeon heal label flips for bandage-only', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 9, 30));
    final bandage = GameLogic.createMarketBandage(salt: 3);
    final heroes = [
      for (var i = 0; i < state.heroes.length; i++)
        i == 0
            ? state.heroes[i].copyWith(
                equipped: {
                  ...state.heroes[i].equipped,
                  EquipmentSlot.consumable: bandage,
                },
              )
            : state.heroes[i].copyWith(
                equipped: {
                  for (final e in state.heroes[i].equipped.entries)
                    if (e.key != EquipmentSlot.consumable) e.key: e.value,
                },
              ),
    ];
    state = state.copyWith(heroes: heroes, gearStash: const []);
    expect(DungeonFlaskButton.healButtonLabel(state), 'BANDAGE');
    expect(DungeonFlaskButton.healConsumableCount(state), 1);
  });

  test('consumable slot label and charm word', () {
    expect(CharacterEquipPanel.slotLabels[EquipmentSlot.trinket], 'CHARM1');
    expect(
      CharacterEquipPanel.consumableSlotLabel(
        GameLogic.createMarketBandage(salt: 1),
      ),
      'BANDAGE',
    );
    expect(
      CharacterEquipPanel.consumableSlotLabel(
        GameLogic.createMarketFlask(salt: 1),
      ),
      'FLASK',
    );
  });

  test('AUTO MERGE footer notes powerScore and can list keeps', () {
    final plain = InventoryDock.mergeFooterHint(plainEnglish: true);
    expect(plain.toUpperCase(), isNot(contains('BIS')));
    final jargon = InventoryDock.mergeFooterHint(
      plainEnglish: false,
      keptCount: 2,
      keptNames: const ['Iron Cap', 'Hide Belt'],
    );
    expect(jargon.toLowerCase(), contains('powerscore'));
    expect(jargon, contains('Iron Cap'));
    expect(jargon, contains('Skips 2'));
  });

  test('apex class label helper maps deathKnight', () {
    expect(HeroSpecs.classLabel(HeroClassId.deathKnight), 'Death Knight');
  });
}
