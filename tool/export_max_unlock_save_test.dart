/// Writes a fully unlocked AL20 / Lv100 save for local playtest.
///
///   flutter test tool/export_max_unlock_save_test.dart --reporter expanded
@Tags(['store_shots'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/blessing_constellation.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/relic_ids.dart';
import 'package:idle_party/models/achievement_def.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/ui/first_session_tips.dart';

const _outPath = 'tool/out/max_unlock_save.json';

const _kitSlots = <EquipmentSlot>[
  EquipmentSlot.weapon,
  EquipmentSlot.offHand,
  EquipmentSlot.ranged,
  EquipmentSlot.head,
  EquipmentSlot.neck,
  EquipmentSlot.shoulder,
  EquipmentSlot.chest,
  EquipmentSlot.waist,
  EquipmentSlot.legs,
  EquipmentSlot.boots,
  EquipmentSlot.wrist,
  EquipmentSlot.hands,
  EquipmentSlot.cloak,
  EquipmentSlot.ring,
  EquipmentSlot.ring2,
  EquipmentSlot.trinket,
  EquipmentSlot.trinket2,
];

const _activeSpecs = <HeroSpecId>[
  HeroSpecId.protection,
  HeroSpecId.discipline,
  HeroSpecId.fire,
  HeroSpecId.combat,
  HeroSpecId.beastMastery,
];

PartyHero _maxHero(PartyHero h) {
  final spec = HeroSpecs.def(h.specId);
  final equipped = <EquipmentSlot, EquipmentItem>{...h.equipped};
  for (final slot in _kitSlots) {
    final item = EquipmentFactory.create(
      slot: slot,
      rarity: LootRarity.legendary,
      battleNumber: 90,
      bias: spec.gearAffinity,
      roleTag: spec.roleTag,
      lootSpecId: h.specId,
      dungeonId: 'veil',
      ascensionLevel: GameLogic.maxAscensionLevel,
      hardmodeLevel: 20,
    );
    equipped[item.slot] = item;
  }
  return h.copyWith(
    level: GameLogic.maxHeroLevel,
    xp: 0,
    equipped: equipped,
  );
}

GameState maxUnlockState() {
  var state = GameLogic.createInitialState(
    now: DateTime.utc(2026, 8, 29, 12),
    partySpecs: const [
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.fire,
    ],
  );

  state = state.copyWith(
    ascensionLevel: GameLogic.maxAscensionLevel,
    highestDungeonCleared: DungeonCatalog.all.last.number,
    highestFloorCleared: 40,
    bossVictories: 40,
    rogueUnlocked: true,
    gold: 5_000_000,
    lifetimeGoldEarned: 50_000_000,
    essence: 8_000,
    attackBonus: 80,
    defenseBonus: 80,
    vitalityBonus: 80,
    moveSpeedBonus: 20,
    attackSpeedBonus: 20,
    critBonus: 20,
    sanctuaryGoldLevel: 20,
    sanctuaryPowerLevel: 20,
    sanctuaryVitalityLevel: 20,
    godHandLevel: 12,
    soulboundFragments: 80,
    inDungeon: false,
    inGauntlet: false,
    inRift: false,
    inGreaterRift: false,
    dungeonId: 'veil',
    hardmodeLevel: 20,
    seenTips: [for (final t in FirstSessionTips.tips) t.id],
    seenChangelogVersion: MetaSystems.currentVersion,
    achievements: [for (final a in AchievementCatalog.all) a.id],
    unlockedRelics: const [
      RelicIds.warBanner,
      RelicIds.ironWard,
      RelicIds.phoenixEmber,
      RelicIds.godHandFocus,
      RelicIds.chamberLuck,
      RelicIds.ironWill,
    ],
    metaDepth: state.metaDepth.copyWith(
      partySlot5Unlocked: true,
      ascendBlessings: GameLogic.maxAscensionLevel,
      lifetimeAscends: GameLogic.maxAscensionLevel,
      ascendStreak: 5,
      bestAscendStreak: 5,
      titles: AscendTitles.byAl.values.toList(),
      activeTitle: AscendTitles.byAl[GameLogic.maxAscensionLevel] ?? '',
      zoneTrophies: [for (final d in DungeonCatalog.all) d.id],
      prestigePurchases: [for (final i in PrestigeShopCatalog.all) i.id],
      stashBonusSlots: 8,
      combinatorLuck: 5,
      godHandCdLevel: 8,
      torchKeepLevel: 5,
      legacyPoints: 8,
      petRosterCapBonus: 6,
      dailyEssenceBonusLevel: 5,
      gauntletGoldBonusLevel: 5,
      marketDiscountLevel: 5,
      filterSpanLevel: 5,
      offlineHighlightBonus: 3,
      highestHardmodeCleared: 20,
      gauntletBestFloor: 50,
      lifetimeGauntletFloors: 80,
      claimedGauntletMilestones: GauntletMilestones.floors
          .map(GauntletMilestones.claimId)
          .toList(),
      riftBestTier: 20,
      riftPreferredTier: 20,
      lifetimeRiftClears: 30,
      claimedRiftMilestones: const ['r5', 'r10', 'r20'],
      grBestTier: 15,
      grPreferredTier: 15,
      lifetimeGrClears: 20,
      claimedGrMilestones: const ['gr5', 'gr10', 'gr20'],
      claimedWillRanks: [
        for (final t in WillRanks.claimableThresholds) '$t',
      ],
      bountyRung: 5,
      lifetimeFloorClears: 400,
      lifetimeBossKills: 80,
      sanctuaryXpLevel: 20,
      sanctuaryGoldPrestige: 5,
      sanctuaryPowerPrestige: 5,
      sanctuaryVitalityPrestige: 5,
      sanctuaryXpPrestige: 5,
      godHandSmashCount: 200,
      constellationStarterGranted: true,
      constellationPointsEarned: 8,
      constellationPointsSpent: 0,
      constellationNodes: const [],
      freshPrestige: false,
      pendingHeroReveals: const [],
      worldBossTickets: 3,
    ),
  );

  state = GameLogic.syncSpecUnlocks(state);
  state = BlessingConstellation.ensure(state);

  final pets = [
    for (var i = 0; i < PetCatalog.all.length; i++)
      Pet(
        id: 'max_${PetCatalog.all[i].id}',
        name: PetCatalog.all[i].name,
        attackBonus: PetCatalog.all[i].baseAttack,
        level: 12,
        speciesId: PetCatalog.all[i].id,
        rarity: PetRarity.legendary,
        passive: PetCatalog.all[i].passive,
        affinityDungeonId: PetCatalog.all[i].affinityDungeonId,
        bondLevel: 10,
        frame: PetFrame.crystal,
        passivePerLevel: PetCatalog.all[i].passivePerLevel,
      ),
  ];

  final roster = [for (final h in state.heroRoster) _maxHero(h)];
  state = state.copyWith(
    heroRoster: roster,
    ownedPets: pets,
    activePet: pets.first,
    metaDepth: state.metaDepth.copyWith(
      unlockedSpecs: [for (final s in HeroSpecs.all) s.id.name],
      pendingHeroReveals: const [],
      favoritePetSpecies: pets.first.speciesId,
    ),
  );

  final bySpec = <HeroSpecId, PartyHero>{
    for (final h in state.heroRoster) h.specId: h,
  };
  final activeIds = [
    for (final spec in _activeSpecs)
      if (bySpec[spec] != null) bySpec[spec]!.id,
  ];
  state = GameLogic.setActiveParty(state, activeIds);

  return state.copyWith(
    heroRoster: [
      for (final h in state.heroRoster)
        h.copyWith(currentHp: state.effectiveHeroMaxHp(h)),
    ],
  );
}

void main() {
  test('export max-unlock save json', () {
    final out = File(_outPath);
    out.parent.createSync(recursive: true);
    final state = maxUnlockState();
    out.writeAsStringSync(GameLogic.exportSaveJson(state));

    expect(state.heroes.every((h) => h.level == GameLogic.maxHeroLevel), isTrue);
    expect(state.heroes.length, 5);
    expect(GameLogic.endgameUnlocked(state), isTrue);
    expect(state.ascensionLevel, GameLogic.maxAscensionLevel);
    expect(state.highestDungeonCleared, DungeonCatalog.all.last.number);
    expect(state.metaDepth.unlockedSpecs, hasLength(HeroSpecs.all.length));
    expect(state.inDungeon, isFalse);

    final imported = GameLogic.importSaveJson(out.readAsStringSync());
    expect(imported, isNotNull);
    expect(GameLogic.endgameUnlocked(imported!), isTrue);
    expect(imported.heroes.length, 5);
    // ignore: avoid_print
    print('wrote ${out.path} (${out.lengthSync()} bytes)');
  });
}
