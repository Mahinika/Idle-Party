import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/coupon_codes.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/play_store_update_io.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/core/shop_store.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeded heal crits are deterministic', () {
    final first = _healGains(41);
    final again = _healGains(41);
    final other = _healGains(42);
    expect(first, again);
    expect(first, isNot(equals(other)));
    expect(first.toSet().length, greaterThan(1));

    final flat = _oneHeal(spellCrit: 0, seed: 1);
    final crit = _oneHeal(spellCrit: 100, seed: 1);
    expect(crit, greaterThan(flat));
  });

  test('heal crit rolls stay off the combat rng', () {
    GameLogic.random = math.Random(7);
    final before = GameLogic.random.nextInt(1 << 30);
    GameLogic.random = math.Random(7);
    addTearDown(() => GameLogic.random = math.Random());
    final caster = _actor('caster', hp: 100, maxHp: 100);
    final world = _world(<SpatialActor>[caster]);

    List<int> rolls(double elapsed) {
      world.combatElapsed = elapsed;
      final rng = AbilityEffectRunner.healCritRng(world, caster);
      return List<int>.generate(8, (_) => rng.nextInt(100));
    }

    expect(rolls(1.25), rolls(1.25));
    expect(rolls(1.25), isNot(equals(rolls(9.5))));
    expect(GameLogic.random.nextInt(1 << 30), before);
  });

  test('activity and main lock portrait', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:screenOrientation="portrait"'));
    final main = File('lib/main.dart').readAsStringSync();
    expect(
      main,
      contains('SystemChrome.setPreferredOrientations'),
    );
    expect(main, contains('DeviceOrientation.portraitUp'));
    expect(main.indexOf('setPreferredOrientations'), lessThan(main.indexOf('runApp')));
  });

  test('flexible Play update is true only after install starts', () async {
    var starts = 0;
    var completes = 0;
    final denied = await runFlexiblePlayUpdate(
      offer: const PlayUpdateOffer(updateAvailable: true, flexibleAllowed: true),
      start: () async {
        starts++;
        return AppUpdateResult.userDeniedUpdate;
      },
      complete: () async => completes++,
    );
    expect(denied, isFalse);
    expect(starts, 1);
    expect(completes, 0);

    final missing = await runFlexiblePlayUpdate(
      offer: const PlayUpdateOffer(
        updateAvailable: false,
        flexibleAllowed: true,
      ),
      start: () async => AppUpdateResult.success,
      complete: () async => fail('complete should not run'),
    );
    expect(missing, isFalse);

    final installed = await runFlexiblePlayUpdate(
      offer: const PlayUpdateOffer(updateAvailable: true, flexibleAllowed: true),
      start: () async => AppUpdateResult.success,
      complete: () async => completes++,
    );
    expect(installed, isTrue);
    expect(completes, 1);

    final failed = await runFlexiblePlayUpdate(
      offer: const PlayUpdateOffer(updateAvailable: true, flexibleAllowed: true),
      start: () async => throw StateError('play down'),
      complete: () async => fail('complete should not run'),
    );
    expect(failed, isFalse);
  });

  test('failed slot migration is retried on the next boot', () async {
    SharedPreferences.setMockInitialValues({});
    final store = _MigrationStore();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final prefs = await SharedPreferences.getInstance();
    final raw = GameLogic.exportSaveJson(
      GameLogic.createInitialState(now: DateTime.utc(2026, 1, 2)),
    );
    await prefs.setString('idle_party_save_v2', raw);
    final storage = SharedPreferencesGameStorage(preferences: prefs);

    await storage.load();
    expect(prefs.getBool('idle_party_slots_ready'), isNot(true));
    await prefs.reload();
    expect(prefs.getString('idle_party_save_slot_0'), isNull);
    expect(prefs.getString('idle_party_save_v2'), raw);

    store.failSlotWrites = false;
    final loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(prefs.getBool('idle_party_slots_ready'), isTrue);
    expect(prefs.getInt('idle_party_active_slot'), 0);
    expect(prefs.getString('idle_party_save_slot_0'), raw);
  });

  test('a slot copy without the active index does not mark migration done', () async {
    SharedPreferences.setMockInitialValues({});
    final store = _ActiveIndexStore();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final prefs = await SharedPreferences.getInstance();
    final raw = GameLogic.exportSaveJson(
      GameLogic.createInitialState(now: DateTime.utc(2026, 1, 3)),
    );
    await prefs.setString('idle_party_save_v2', raw);
    final storage = SharedPreferencesGameStorage(preferences: prefs);
    await storage.load();
    await prefs.reload();
    expect(prefs.getString('idle_party_save_slot_0'), raw);
    expect(prefs.getInt('idle_party_active_slot'), isNull);
    expect(prefs.getBool('idle_party_slots_ready'), isNot(true));

    store.failActive = false;
    final loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(prefs.getInt('idle_party_active_slot'), 0);
    expect(prefs.getBool('idle_party_slots_ready'), isTrue);
  });

  test('stateFromJson quest dates follow debugNow across UTC midnight', () {
    final before = DateTime.utc(2026, 11, 22, 23, 59);
    final after = DateTime.utc(2026, 11, 23, 0, 1);
    final previousNow = GameLogic.debugNow;
    final previousRandom = GameLogic.random;
    GameLogic.debugNow = before;
    addTearDown(() {
      GameLogic.debugNow = previousNow;
      GameLogic.random = previousRandom;
    });

    final bare = GameLogic.createInitialState(now: before).toJson()
      ..['missions'] = <dynamic>[];
    final rebuilt = GameLogic.stateFromJson(bare);
    expect(rebuilt.metaDepth.dailyQuestDate, '2026-11-22');
    expect(rebuilt.metaDepth.questWeekKey, GameLogic.isoWeekKey(before));

    GameLogic.debugNow = after;
    final nextDay = GameLogic.stateFromJson(bare);
    expect(nextDay.metaDepth.dailyQuestDate, '2026-11-23');
    expect(nextDay.metaDepth.questWeekKey, GameLogic.isoWeekKey(after));
    expect(nextDay.metaDepth.questWeekKey, isNot(rebuilt.metaDepth.questWeekKey));

    final rolled = GameLogic.stateFromJson(rebuilt.toJson());
    expect(rolled.metaDepth.dailyQuestDate, '2026-11-23');
  });

  test('clipboard import keeps this device Play flags and the coupon', () async {
    final clock = DateTime.utc(2026, 11, 22, 12);
    final device = _withShop(
      GameLogic.createInitialState(now: clock),
      adFree: true,
      shopPermScrolls: AdBoost.permAtk,
      purchaseIds: const ['device-receipt'],
    );
    final pasted = _withShop(
      GameLogic.createInitialState(now: clock),
      gold: 12345,
      adFree: false,
      paidSeasonPass: true,
      shopLongAway: true,
      cinderPouchDoubled: true,
      shopBagBonusSlots: 4,
      shopPermScrolls: AdBoost.permAll,
      purchaseIds: const ['pasted-receipt'],
    );

    final stripped = PlayGamesScores.clipboardImport(
      imported: pasted,
      device: device,
    );
    expect(stripped.gold, 12345);
    expect(stripped.metaDepth.adFree, isTrue);
    expect(stripped.metaDepth.paidSeasonPass, isFalse);
    expect(stripped.metaDepth.shopLongAway, isFalse);
    expect(stripped.metaDepth.cinderPouchDoubled, isFalse);
    expect(stripped.metaDepth.shopBagBonusSlots, 0);
    expect(stripped.metaDepth.shopPermScrolls, AdBoost.permAtk);
    expect(stripped.metaDepth.grantedShopPurchaseIds, ['device-receipt']);
    expect(
      stripped.metaDepth.redeemedCoupons,
      isNot(contains(CouponCodes.foreverScrolls)),
    );

    final couponSave = CouponCodes.redeem(
      _withShop(GameLogic.createInitialState(now: clock), gold: 80),
      CouponCodes.foreverScrolls,
    ).state;
    expect(couponSave.metaDepth.shopPermScrolls, AdBoost.permAll);
    final withCoupon = PlayGamesScores.clipboardImport(
      imported: couponSave,
      device: device,
    );
    expect(withCoupon.gold, 80);
    expect(withCoupon.metaDepth.adFree, isTrue);
    expect(withCoupon.metaDepth.shopPermScrolls, AdBoost.permAll);
    expect(
      withCoupon.metaDepth.redeemedCoupons,
      contains(CouponCodes.foreverScrolls),
    );

    final parsed = GameLogic.importSaveJson(GameLogic.exportSaveJson(pasted));
    expect(parsed!.metaDepth.paidSeasonPass, isTrue);
    expect(parsed.metaDepth.grantedShopPurchaseIds, ['pasted-receipt']);

    final cloud = PlayGamesScores.withKeptOwnership(
      chosen: pasted,
      other: device,
    );
    expect(cloud.metaDepth.adFree, isTrue);
    expect(cloud.metaDepth.paidSeasonPass, isTrue);

    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(device);
    final before = ShopStore.debugClipboardRestoreCalls;
    final ok = await director.importSaveJson(GameLogic.exportSaveJson(pasted));
    expect(ok, isTrue);
    expect(director.state.gold, 12345);
    expect(director.state.metaDepth.adFree, isTrue);
    expect(director.state.metaDepth.paidSeasonPass, isFalse);
    expect(director.state.metaDepth.shopPermScrolls, AdBoost.permAtk);
    expect(
      director.state.metaDepth.grantedShopPurchaseIds,
      ['device-receipt'],
    );
    expect(ShopStore.debugClipboardRestoreCalls, before + 1);
  });

  test('a purchase id is kept past the old 64 cap', () {
    final now = DateTime.utc(2026, 11, 22, 8);
    final item = ShopCatalog.byId['ad_free']!;
    var state = GameLogic.createInitialState(now: now);
    for (var i = 0; i < 70; i++) {
      state = ShopBilling.applyTrackedPurchase(
        state,
        item,
        purchaseId: 'id-$i',
        now: now,
      );
    }
    expect(state.metaDepth.grantedShopPurchaseIds, hasLength(70));
    expect(state.metaDepth.grantedShopPurchaseIds.first, 'id-0');
    expect(ShopBilling.alreadyGranted(state, 'id-0'), isTrue);
    final again = ShopBilling.applyTrackedPurchase(
      state,
      item,
      purchaseId: 'id-0',
      now: now,
    );
    expect(identical(again, state), isTrue);
    final round = GameLogic.stateFromJson(state.toJson());
    expect(round.metaDepth.grantedShopPurchaseIds, hasLength(70));
    expect(ShopBilling.alreadyGranted(round, 'id-0'), isTrue);
  });

  test('friend claim rules and client stay atomic', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('getAfter('));
    expect(rules, contains('existsAfter('));
    expect(rules, contains('request.auth.uid'));
    expect(rules, contains('authUid'));
    expect(rules, contains('ownerUid'));
    expect(rules, contains('claims <= 30'));
    final client = File(
      'lib/core/friend_referral_store_io.dart',
    ).readAsStringSync();
    expect(client, isNot(contains('_claimApart')));
    expect(client, contains('runTransaction'));
    expect(client, contains('lastClaimUid'));
    expect(client, contains("'authUid': uid"));
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:dataExtractionRules='));
    final privacy = File('docs/PRIVACY.md').readAsStringSync();
    expect(privacy, contains('Android backup does not restore'));
    expect(privacy, contains('Play Games cloud save'));
    final ignore = File('.gitignore').readAsStringSync();
    expect(ignore, contains('docs/competitor_research/**/*.png'));
    expect(ignore, contains('docs/competitor_research/**/logcat*'));
    expect(
      File('docs/competitor_research/brick_inc_idle_breaker.md').existsSync(),
      isTrue,
    );
    expect(
      Directory('docs/competitor_research/brick_inc_idle_breaker').existsSync(),
      isFalse,
    );
  });
}

List<int> _healGains(int seed) {
  final rng = math.Random(seed);
  final gains = <int>[];
  for (var i = 0; i < 24; i++) {
    gains.add(_oneHeal(spellCrit: 45, seed: seed, rng: rng));
  }
  return gains;
}

int _oneHeal({required int spellCrit, required int seed, math.Random? rng}) {
  final caster = _actor('caster', hp: 100, maxHp: 100);
  caster
    ..spellCrit = spellCrit
    ..spellPower = 80
    ..attack = 20;
  final ally = _actor('ally', hp: 40, maxHp: 400);
  final world = _world(<SpatialActor>[caster, ally]);
  final before = ally.hp;
  AbilityEffectRunner.debugHealLowest(
    world,
    caster,
    ally,
    rng ?? math.Random(seed),
  );
  return ally.hp - before;
}

SpatialActor _actor(String id, {required int hp, required int maxHp}) {
  return SpatialActor(
    id: id,
    name: id,
    team: SpatialTeam.hero,
    x: 1,
    y: 1,
    hp: hp,
    maxHp: maxHp,
    attack: 10,
    defense: 0,
    moveSpeed: 1,
    attackRange: 1.2,
    attackCooldown: 1,
  );
}

SpatialWorld _world(List<SpatialActor> heroes) {
  return SpatialWorld(
    map: TileMap(
      cols: 3,
      rows: 3,
      tiles: List<TileKind>.filled(9, TileKind.floor),
      spawnPoints: const [(1, 1)],
      exitPoint: (2, 1),
      enemySpawns: const <(int, int)>[],
    ),
    heroes: heroes,
    enemies: <SpatialActor>[],
    projectiles: <SpatialProjectile>[],
    groundLoot: <GroundLoot>[],
    isTreasure: false,
  );
}

GameState _withShop(
  GameState state, {
  int? gold,
  bool? adFree,
  bool? paidSeasonPass,
  bool? shopLongAway,
  bool? cinderPouchDoubled,
  int? shopBagBonusSlots,
  int? shopPermScrolls,
  List<String>? purchaseIds,
}) {
  return state.copyWith(
    gold: gold,
    lifetimeGoldEarned: gold,
    metaDepth: state.metaDepth.copyWith(
      adFree: adFree,
      paidSeasonPass: paidSeasonPass,
      shopLongAway: shopLongAway,
      cinderPouchDoubled: cinderPouchDoubled,
      shopBagBonusSlots: shopBagBonusSlots,
      shopPermScrolls: shopPermScrolls,
      grantedShopPurchaseIds: purchaseIds,
    ),
  );
}

class _MigrationStore extends InMemorySharedPreferencesStore {
  _MigrationStore() : super.empty();

  bool failSlotWrites = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final blocked = key.endsWith('idle_party_save_slot_0') ||
        key.endsWith('idle_party_active_slot') ||
        key.endsWith('idle_party_slots_ready');
    if (failSlotWrites && blocked) return false;
    return super.setValue(valueType, key, value);
  }
}

class _ActiveIndexStore extends InMemorySharedPreferencesStore {
  _ActiveIndexStore() : super.empty();

  bool failActive = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final blocked = key.endsWith('idle_party_active_slot') ||
        key.endsWith('idle_party_slots_ready');
    if (failActive && blocked) return false;
    return super.setValue(valueType, key, value);
  }
}
