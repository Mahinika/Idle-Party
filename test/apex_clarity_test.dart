import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/apex_forge.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/game_storage.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/core/save_swap.dart';
import 'package:idle_party/models/apex_craft.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';
import 'package:idle_party/ui/shell/craft_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the same craft goal keeps the meter and a pinned material', () {
    var state = _goal(progress: 40, mat: 'shard_sandy');
    state = GameLogic.setApexCraftGoal(
      state,
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
    );
    expect(state.metaDepth.apexTargetProgress, 40);
    expect(state.metaDepth.apexTargetMatId, 'shard_sandy');
    expect(state.metaDepth.apexCraftSlot, 'weapon');
  });

  test('pinning the auto target keeps progress; a different mat resets it', () {
    var state = _goal(progress: 40);
    final auto = GameLogic.resolveApexTargetMatId(state);
    expect(auto, ApexCraft.shardAnyId);
    state = GameLogic.setApexTargetMat(state, auto!);
    expect(state.metaDepth.apexTargetMatId, auto);
    expect(state.metaDepth.apexTargetProgress, 40);

    state = GameLogic.setApexTargetMat(state, ApexCraft.slagId);
    expect(state.metaDepth.apexTargetMatId, ApexCraft.slagId);
    expect(state.metaDepth.apexTargetProgress, 0);
  });

  test(
    'a second craft or upgrade does not replace the success toast',
    () async {
      final mats = _pile(40);
      final director = GameDirector.preview(
        initialState: _fresh().copyWith(craftMaterials: mats),
      );
      addTearDown(director.dispose);
      await director.boot();

      director.craftApex(
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
      );
      expect(director.toast, contains('Crafted'));
      final toast = director.toast;
      director.craftApex(
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
      );
      expect(director.toast, toast);
      expect(director.toast, isNot(contains('Missing mats')));

      final id = ApexCraft.pieceId(
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
      );
      director.upgradeApex(id);
      director.upgradeApex(id);
      expect(director.toast, contains('Apex upgraded'));
      final upgraded = director.toast;
      director.upgradeApex(id);
      expect(director.toast, upgraded);
      expect(director.toast, isNot(contains('Cannot upgrade')));
    },
  );

  test('weapon gate names itself instead of missing materials', () async {
    final director = GameDirector.preview(
      initialState: _fresh().copyWith(craftMaterials: _pile(40)),
    );
    addTearDown(director.dispose);
    await director.boot();
    director.craftApex(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.head,
    );
    expect(director.toast, 'Craft weapon R1 first for this class/role.');
  });

  test('vault equip stays inside a full bag and keeps the taken-off piece', () {
    final apex = _blade();
    final worn = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.common,
      battleNumber: 1,
    ).copyWith(id: 'worn_sword');
    final cap = GameLogic.maxGearStashFor(_fresh());
    final fillers = [
      for (var i = 0; i < cap; i++)
        GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.common,
          battleNumber: 1,
        ).copyWith(id: 'fill_$i'),
    ];
    var state = _wear(_fresh().copyWith(gearStash: fillers), worn);
    state = state.copyWith(apexVault: [apex]);
    expect(state.gearStash.length, cap);

    state = GameLogic.equipFromApexVault(state, apex.id);
    expect(state.heroes.first.itemIn(EquipmentSlot.weapon)!.isApex, isTrue);
    expect(state.gearStash.length, cap);
    expect(state.gearStash.any((g) => g.id == 'worn_sword'), isTrue);
    expect(state.gearStash.any((g) => g.id == 'fill_0'), isFalse);
    expect(state.apexVault.any((g) => g.id == apex.id), isFalse);
  });

  test('a bag-only piece upgrades in the bag and survives reload', () {
    final blade = _blade();
    var state = _fresh().copyWith(
      gearStash: [blade],
      craftMaterials: _pile(40),
    );
    expect(GameLogic.canUpgradeApex(state, blade.id), isTrue);
    expect(
      GameLogic.canCraftApex(
        state,
        classId: HeroClassId.warrior,
        role: SpecRoleTag.tank,
        slot: EquipmentSlot.weapon,
      ),
      isFalse,
    );

    state = GameLogic.upgradeApex(state, blade.id);
    expect(state.gearStash.single.apexRank, 2);
    expect(state.apexVault, isEmpty);
    expect(
      state.heroes.first.itemIn(EquipmentSlot.weapon)?.isApex,
      isNot(true),
    );

    final loaded = GameLogic.stateFromJson(state.toJson());
    expect(loaded.gearStash.single.apexRank, 2);
    expect(loaded.gearStash.single.id, blade.id);
  });

  test('an old save keeps the higher rank on the hero who wore the piece', () {
    final low = _blade(rank: 1);
    final high = _blade(rank: 3);
    final state = _wear(_fresh(), low).copyWith(apexVault: [high]);
    final loaded = GameLogic.stateFromJson(state.toJson());
    final worn = loaded.heroes.first.itemIn(EquipmentSlot.weapon)!;
    expect(worn.apexRank, 3);
    expect(worn.itemLevel, high.itemLevel);
    expect(loaded.apexVault.where((g) => g.id == high.id), isEmpty);

    final again = GameLogic.stateFromJson(loaded.toJson());
    expect(
      again.heroes.first.itemIn(EquipmentSlot.weapon)!.apexRank,
      worn.apexRank,
    );
    expect(again.apexVault.length, loaded.apexVault.length);
    expect(again.gearStash.length, loaded.gearStash.length);
  });

  test('same rank with different stats is not guessed away', () {
    final left = _blade();
    final right = left.copyWith(
      strengthBonus: left.strengthBonus + 4,
      staminaBonus: left.staminaBonus - 4,
    );
    final state = _fresh().copyWith(apexVault: [left, right]);
    final loaded = GameLogic.stateFromJson(state.toJson());
    final copies = loaded.apexVault.where((g) => g.id == left.id).toList();
    expect(copies, hasLength(2));
    expect(copies.map((g) => g.strengthBonus).toSet(), {
      left.strengthBonus,
      right.strengthBonus,
    });

    final twice = GameLogic.normalizeApexDuplicates(loaded);
    expect(twice.apexVault.length, loaded.apexVault.length);
  });

  test('an exact duplicate collapses and the equipped copy stays', () {
    final blade = _blade();
    final state = _wear(_fresh(), blade).copyWith(apexVault: [blade]);
    final loaded = GameLogic.stateFromJson(state.toJson());
    expect(loaded.heroes.first.itemIn(EquipmentSlot.weapon)!.apexRank, 1);
    expect(loaded.apexVault.where((g) => g.id == blade.id), isEmpty);
    final again = GameLogic.normalizeApexDuplicates(loaded);
    expect(identical(again, loaded), isTrue);
  });

  test('upgrade spends on the worn piece, not a worse vault twin', () {
    final worn = _blade(rank: 1);
    final twin = worn.copyWith(
      strengthBonus: worn.strengthBonus + 3,
      staminaBonus: worn.staminaBonus - 3,
    );
    var state = _wear(
      _fresh(),
      worn,
    ).copyWith(apexVault: [twin], craftMaterials: _pile(40));
    state = GameLogic.upgradeApex(state, worn.id);
    expect(state.heroes.first.itemIn(EquipmentSlot.weapon)!.apexRank, 2);
    expect(state.apexVault.single.apexRank, 1);
    expect(state.apexVault.single.strengthBonus, twin.strengthBonus);
  });

  test('a long clear still names every craft material', () {
    final lines = floorClearPayoffLines(
      clearLine:
          'F2 CLEAR · +999g · +999 XP · +9e · ${'Ashen Vault Blade' * 3}',
      matGrants: const ['shard_sandy', 'core_tank', 'apex_slag', 'shard_sandy'],
    );
    expect(lines, hasLength(2));
    expect(lines.last, '+2 Sandy Shard · Aegis Core · Apex Slag');
    expect(lines.last.length, greaterThan(20));
  });

  test('hub rest reports no craft materials', () {
    final hub = _fresh().copyWith(autoCaveOnLeave: false);
    final result = OfflineProgress.applyOfflineProgress(
      hub,
      const Duration(minutes: 2),
    );
    expect(result.wasInDungeon, isFalse);
    expect(result.materialsGained, isEmpty);
    expect(result.materialsLine, isEmpty);
    expect(result.state.craftMaterials, hub.craftMaterials);
  });

  test(
    'offline boss catch-up reports the materials the save actually gained',
    () {
      final room = const DungeonRoom(
        floorNumber: 2,
        roomIndex: 0,
        type: RoomType.boss,
        enemyLevel: 1,
        enemyCount: 1,
      );
      final boss = GameLogic.createEnemyGroup(room, dungeonId: 'sandy').first;
      final weak = boss.copyWith(
        currentHp: 1,
        stats: boss.stats.copyWith(flatMaxHp: 1, flatAttack: 0),
      );
      final start = _goal(progress: 80, mat: ApexCraft.slagId).copyWith(
        inDungeon: true,
        dungeonId: 'sandy',
        currentRoom: room,
        dungeonFloor: [room],
        enemies: [weak],
      );
      final result = OfflineProgress.applyOfflineProgress(
        start,
        const Duration(seconds: 25),
      );
      expect(
        result.materialsGained,
        ApexForge.materialGain(start, result.state),
      );
      expect(result.materialsGained[ApexCraft.slagId], greaterThanOrEqualTo(1));
      expect(result.materialsLine, contains('Apex Slag'));
      expect(result.hasSummary, isTrue);
    },
  );

  testWidgets('CRAFT on a small phone persists the goal and keeps the meter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final director = GameDirector.preview(
      initialState: _goal(progress: 40).copyWith(craftMaterials: _pile(40)),
    );
    try {
      await director.boot();

      await tester.pumpWidget(_phone(director, textScale: 1.4));
      await tester.pump();

      expect(director.state.metaDepth.apexCraftClassId, 'warrior');
      expect(director.state.metaDepth.apexTargetProgress, 40);
      expect(find.text('CRAFT R1'), findsOneWidget);
      expect(find.textContaining('Crafts at AL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('MAIN'));
      await tester.pump();
      expect(director.state.metaDepth.apexTargetProgress, 40);

      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pump();
      await tester.tap(find.text('CRAFT R1'));
      await tester.pump();
      expect(director.toast, contains('Crafted'));
      expect(find.text('UPGRADE → R2'), findsOneWidget);
      expect(find.textContaining('Now ·'), findsOneWidget);
      expect(find.textContaining('Next ·'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -80));
      await tester.pump();
      await tester.tap(find.text('UPGRADE → R2'));
      await tester.pump();
      expect(director.toast, contains('Apex upgraded'));
      expect(director.toast, isNot(contains('Cannot upgrade')));
      expect(tester.takeException(), isNull);
    } finally {
      director.dispose();
    }
  });

  testWidgets('a bag piece shows UPGRADE, and a mismatch names the reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final blade = _blade();
    final foreign = ApexCraft.buildItem(
      classId: HeroClassId.deathKnight,
      role: SpecRoleTag.tank,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 0,
    );
    final director = GameDirector.preview(
      initialState: _goal().copyWith(
        gearStash: [blade],
        apexVault: [foreign],
        craftMaterials: _pile(40),
      ),
    );
    try {
      await director.boot();

      await tester.pumpWidget(_phone(director, textScale: 1.4));
      await tester.pump();

      expect(find.text('UPGRADE → R2'), findsOneWidget);
      expect(find.textContaining('· in bag'), findsOneWidget);
      expect(find.text('CRAFT R1'), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pump();
      await tester.tap(find.text('SHOW').last);
      await tester.pump();
      expect(find.text('No matching hero in party'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await tester.pump();
      await tester.tap(find.text('UPGRADE → R2'));
      await tester.pump();
      expect(director.state.gearStash.single.apexRank, 2);
      expect(tester.takeException(), isNull);
    } finally {
      director.dispose();
    }
  });

  testWidgets('Welcome Back shows the offline material line', (tester) async {
    final director = GameDirector.preview(initialState: _fresh());
    try {
      await director.boot();
      final summary = OfflineProgressResult(
        state: director.state,
        secondsApplied: 120,
        secondsAway: 120,
        goldGained: 12,
        essenceGained: 0,
        roomsCleared: 1,
        highestFloorDelta: 0,
        bossDelta: 1,
        wasInDungeon: true,
        materialsGained: const {'shard_sandy': 2, 'apex_slag': 1},
      );
      expect(
        summary.materialsLine,
        'Craft materials · Apex Slag · 2 Sandy Shard',
      );
      director.uiFeedback.presentOffline(summary);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOfflineProgressDialog(context, director),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(summary.materialsLine), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      director.dispose();
    }
  });

  testWidgets('opening CRAFT with no goal saves the party default', (
    tester,
  ) async {
    final director = GameDirector.preview(initialState: _fresh());
    try {
      await director.boot();
      expect(director.state.metaDepth.apexCraftClassId, isEmpty);

      await tester.pumpWidget(_phone(director, textScale: 1.4));
      await tester.pump();
      expect(director.state.metaDepth.apexCraftClassId, 'warrior');
      expect(director.state.metaDepth.apexCraftRoleTag, 'tank');
      expect(director.state.metaDepth.apexCraftSlot, 'weapon');
      expect(director.state.metaDepth.apexTargetProgress, 0);
      expect(find.text('Need the materials above.'), findsOneWidget);
      expect(find.textContaining('Any boss fills the meter'), findsWidgets);
      expect(find.textContaining('Crystal Spire'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      director.dispose();
    }
  });

  testWidgets('pinning the shown material on a small phone keeps the meter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final director = GameDirector.preview(initialState: _goal(progress: 40));
    try {
      await director.boot();
      await tester.pumpWidget(_phone(director, textScale: 1.4));
      await tester.pump();
      await tester.tap(find.textContaining('Zone Shards (any)'));
      await tester.pump();
      expect(director.state.metaDepth.apexTargetMatId, ApexCraft.shardAnyId);
      expect(director.state.metaDepth.apexTargetProgress, 40);
      expect(tester.takeException(), isNull);
    } finally {
      director.dispose();
    }
  });

  test('load keeps the away clock when an exact Apex duplicate collapses', () {
    final away = DateTime.utc(2026, 11, 7, 8);
    final blade = _blade();
    final duplicate = _awaySave(away, vault: [blade, blade]);
    final single = _awaySave(away, vault: [blade]);
    final loaded = GameLogic.importSaveJson(
      GameLogic.exportSaveJson(duplicate),
    )!;
    final probe = GameLogic.importSaveJson(GameLogic.exportSaveJson(single))!;

    expect(loaded.lastUpdated, away);
    expect(probe.lastUpdated, away);
    expect(loaded.gold, duplicate.gold);
    expect(loaded.metaDepth.adFree, isTrue);
    expect(loaded.apexVault.where((g) => g.id == blade.id), hasLength(1));

    const elapsed = Duration(hours: 2);
    final dupAway = OfflineProgress.applyOfflineProgress(loaded, elapsed);
    final oneAway = OfflineProgress.applyOfflineProgress(probe, elapsed);
    expect(dupAway.secondsApplied, 7200);
    expect(oneAway.secondsApplied, 7200);
    expect(dupAway.goldGained, oneAway.goldGained);
    expect(dupAway.goldGained, greaterThan(0));
    expect(dupAway.essenceGained, oneAway.essenceGained);

    final again = GameLogic.stateFromJson(loaded.toJson());
    expect(again.lastUpdated, loaded.lastUpdated);
    expect(again.apexVault.length, loaded.apexVault.length);
    expect(again.gold, loaded.gold);
    expect(again.metaDepth.adFree, isTrue);
  });

  test(
    'a lower rank with a proc or affix is not replaced by a plain higher rank',
    () {
      final plain = _blade(rank: 3);
      final legacy = _blade(rank: 1).copyWith(
        effectId: GearEffectId.lifesteal,
        effectValue: 40,
        affixPrefixId: 'of_the_leech',
        affixSuffixId: 'warded',
      );
      final loaded = GameLogic.stateFromJson(
        _fresh().copyWith(apexVault: [plain, legacy]).toJson(),
      );
      final copies = loaded.apexVault.where((g) => g.id == plain.id).toList();
      expect(copies, hasLength(2));
      expect(
        copies.any(
          (g) =>
              g.apexRank == 1 &&
              g.effectId == GearEffectId.lifesteal &&
              g.effectValue == 40 &&
              g.affixPrefixId == 'of_the_leech' &&
              g.affixSuffixId == 'warded',
        ),
        isTrue,
      );
      expect(
        copies.any((g) => g.apexRank == 3 && g.effectId == GearEffectId.none),
        isTrue,
      );

      final sameRank = _blade();
      final affixed = sameRank.copyWith(affixSuffixId: 'warded');
      final kept = GameLogic.stateFromJson(
        _fresh().copyWith(apexVault: [sameRank, affixed]).toJson(),
      );
      expect(kept.apexVault.where((g) => g.id == sameRank.id), hasLength(2));

      final covered = _blade(
        rank: 1,
      ).copyWith(effectId: GearEffectId.lifesteal, effectValue: 40);
      final newer = _blade(
        rank: 3,
      ).copyWith(effectId: GearEffectId.lifesteal, effectValue: 40);
      final collapsed = GameLogic.stateFromJson(
        _fresh().copyWith(apexVault: [covered, newer]).toJson(),
      );
      final left = collapsed.apexVault.where((g) => g.id == newer.id).toList();
      expect(left, hasLength(1));
      expect(left.single.apexRank, 3);
      expect(left.single.effectValue, 40);
    },
  );

  test(
    'journal restore loads the duplicate save without eating the away clock',
    () async {
      final away = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      final blade = _blade();
      final duplicate = _awaySave(away, vault: [blade, blade]);
      final single = _awaySave(away, vault: [blade]);
      final storage = InMemoryGameStorage();
      final json = GameLogic.exportSaveJson(duplicate);
      await storage.writeActiveRaw(json);
      await storage.writeExtra(GameStorage.stagingKey, json);
      await storage.writeExtra(GameStorage.holdKey, json);
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);

      final restored = GameLogic.importSaveJson(
        (await storage.loadActiveRaw())!,
      )!;
      expect(restored.lastUpdated, away);
      expect(restored.gold, duplicate.gold);
      expect(restored.metaDepth.adFree, isTrue);
      expect(restored.apexVault.where((g) => g.id == blade.id), hasLength(1));

      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot(deferCombatLoop: true);
      final summary = director.offlineSummary;
      expect(summary, isNotNull);
      expect(summary!.secondsApplied, greaterThan(3600));
      expect(summary.goldGained, greaterThan(0));

      final probe = InMemoryGameStorage();
      await probe.writeActiveRaw(GameLogic.exportSaveJson(single));
      final other = GameDirector(probe, enableSpatialLoop: false);
      addTearDown(other.dispose);
      await other.boot(deferCombatLoop: true);
      expect(other.offlineSummary!.secondsApplied, summary.secondsApplied);
      expect(other.offlineSummary!.goldGained, summary.goldGained);
      expect(director.state.metaDepth.adFree, isTrue);
      expect(director.state.gold, greaterThan(duplicate.gold));
    },
  );
}

GameState _awaySave(DateTime away, {required List<EquipmentItem> vault}) {
  return _fresh().copyWith(
    lastUpdated: away,
    gold: 40,
    autoCaveOnLeave: false,
    inDungeon: false,
    apexVault: vault,
    metaDepth: const MetaDepthState(adFree: true),
  );
}

GameState _fresh() => GameLogic.createInitialState(now: DateTime.now());

GameState _goal({int progress = 0, String mat = ''}) {
  return _fresh().copyWith(
    metaDepth: MetaDepthState(
      apexCraftClassId: 'warrior',
      apexCraftRoleTag: 'tank',
      apexCraftSlot: 'weapon',
      apexTargetMatId: mat,
      apexTargetProgress: progress,
    ),
  );
}

EquipmentItem _blade({int rank = 1}) => ApexCraft.buildItem(
  classId: HeroClassId.warrior,
  role: SpecRoleTag.tank,
  slot: EquipmentSlot.weapon,
  rank: rank,
  ascensionLevel: 0,
);

GameState _wear(GameState state, EquipmentItem item) {
  final roster = [...state.heroRoster];
  final hero = roster.first;
  final gear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
  gear[item.slot] = item;
  roster[0] = hero.copyWith(equipped: gear);
  return state.copyWith(heroRoster: roster);
}

Map<String, int> _pile(int count) => {
  for (final mat in ApexCraft.materials)
    if (mat.id != ApexCraft.shardAnyId) mat.id: count,
};

Widget _phone(GameDirector director, {required double textScale}) {
  return MaterialApp(
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: Scaffold(body: CraftOverlay(director: director)),
  );
}
