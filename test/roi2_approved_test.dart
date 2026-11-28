import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_offer.dart';
import 'package:idle_party/core/clock_guard.dart';
import 'package:idle_party/core/day_clock.dart';
import 'package:idle_party/core/day_migrate.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/live_event.dart';
import 'package:idle_party/core/loot_pipeline.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/core/remote_tune.dart';
import 'package:idle_party/core/save_codec.dart';
import 'package:idle_party/core/save_flush_gate.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/roi2_persist.dart';

void main() {
  tearDown(() {
    DayClock.debugOffsetMinutes = null;
    ClockGuard.debugUptimeMs = null;
    RemoteTune.reset();
  });

  test('welcome floor is minutes away, capped at 30, still times 3', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 1));
    final rate = GoldIncome.hubGoldPerMinute(state);
    final base = rate * 10;
    final ten = AdOffer.welcomeExtraGold(state, base, minutesAway: 10);
    expect(ten, rate * 20);
    final hour = AdOffer.welcomeExtraGold(state, rate * 60, minutesAway: 60);
    expect(hour, rate * 120);
    expect(AdOffer.welcomeCardMinMinutes, 5);
  });

  test('VIP auto welcome waits for 5 minutes; plain Ad-free does not auto', () {
    final now = DateTime.utc(2026, 8, 21, 12);
    final vip = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      autoCaveOnLeave: false,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
        adFree: true,
        roi2: const Roi2Persist(vipPass: true, vipPerkSplit: true),
      ),
    );
    final short = OfflineProgress.applyOfflineProgress(
      vip,
      const Duration(minutes: 4),
    );
    final plainShort = OfflineProgress.applyOfflineProgress(
      vip.copyWith(metaDepth: vip.metaDepth.copyWith(adFree: false)),
      const Duration(minutes: 4),
    );
    expect(short.goldGained, plainShort.goldGained);
  });

  test('old ad_free save is grandfathered; a new purchase is not', () {
    final fresh = GameLogic.createInitialState();
    final oldJson = fresh.toJson();
    (oldJson['metaDepth'] as Map<String, dynamic>)['adFree'] = true;
    (oldJson['metaDepth'] as Map<String, dynamic>).remove('roi2');
    final loaded = GameLogic.stateFromJson(oldJson);
    expect(loaded.metaDepth.adFree, isTrue);
    expect(loaded.metaDepth.hasVipPerks, isTrue);
    expect(loaded.metaDepth.roi2.vipPass, isTrue);

    final bought = ShopBilling.applyPurchase(
      fresh,
      ShopCatalog.byId['ad_free']!,
      now: DateTime.utc(2026, 11, 1),
    );
    expect(bought.metaDepth.adFree, isTrue);
    expect(bought.metaDepth.hasVipPerks, isFalse);
    expect(bought.metaDepth.roi2.vipPerkSplit, isTrue);
    final round = GameLogic.stateFromJson(bought.toJson());
    expect(round.metaDepth.adFree, isTrue);
    expect(round.metaDepth.roi2.vipPass, isFalse);
    expect(round.metaDepth.roi2.vipPerkSplit, isTrue);
    expect(round.metaDepth.hasVipPerks, isFalse);
  });

  test('roi2 fields round-trip and a missing map stays loadable', () {
    final state = GameLogic.createInitialState().copyWith(
      metaDepth: GameLogic.createInitialState().metaDepth.copyWith(
        roi2: const Roi2Persist(
          vipPass: true,
          vipPerkSplit: true,
          goldLanternReady: true,
          highestWallMs: 50,
          lastSessionWallMs: 40,
          lastSessionUptimeMs: 30,
          dayKeysAreLocal: true,
          tzOffsetMinutes: 60,
          tzHonoredDay: '2026-11-01',
          tzPinnedDay: '2026-11-01',
          dailyRefillHoldUntilMs: 9,
          clockJumpSuppressDay: '2026-11-02',
          consentPrompted: true,
          batterySaver: true,
          readableType: true,
          lastGoodSnapshotMs: 8,
        ),
      ),
    );
    final back = GameLogic.stateFromJson(state.toJson());
    final roi = back.metaDepth.roi2;
    expect(roi.vipPass, isTrue);
    expect(roi.goldLanternReady, isTrue);
    expect(roi.highestWallMs, 50);
    expect(roi.lastSessionUptimeMs, 30);
    expect(roi.dayKeysAreLocal, isTrue);
    expect(roi.tzOffsetMinutes, 60);
    expect(roi.clockJumpSuppressDay, '2026-11-02');
    expect(roi.consentPrompted, isTrue);
    expect(roi.batterySaver, isTrue);
    expect(roi.readableType, isTrue);
    expect(roi.lastGoodSnapshotMs, 8);

    final legacy = GameLogic.createInitialState().toJson();
    (legacy['metaDepth'] as Map<String, dynamic>).remove('roi2');
    final old = GameLogic.stateFromJson(legacy);
    expect(old.metaDepth.roi2.vipPass, isFalse);
  });

  test('day migration rewrites today and holds when the zone date differs', () {
    DayClock.debugOffsetMinutes = -480;
    final now = DateTime.utc(2026, 11, 2, 3);
    final utcToday = '2026-11-02';
    final state = GameLogic.createInitialState(now: now).copyWith(
      lastDailyDate: utcToday,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
        dailyVaultDate: utcToday,
        wispGiftUtcDay: '2026-10-01',
      ),
    );
    final migrated = DayMigrate.apply(state, now);
    expect(migrated.metaDepth.roi2.dayKeysAreLocal, isTrue);
    expect(migrated.lastDailyDate, '2026-11-01');
    expect(migrated.metaDepth.dailyVaultDate, '2026-11-01');
    expect(migrated.metaDepth.wispGiftUtcDay, '2026-10-01');
    expect(migrated.metaDepth.roi2.dailyRefillHoldUntilMs, greaterThan(0));
    expect(DayMigrate.apply(migrated, now), migrated);
  });

  test('a second time-zone change the same day keeps the pinned day', () {
    final now = DateTime.utc(2026, 11, 2, 12);
    DayClock.debugOffsetMinutes = 0;
    var roi = DayClock.noteZone(const Roi2Persist(), now);
    DayClock.debugOffsetMinutes = 60;
    roi = DayClock.noteZone(roi, now);
    final pinned = roi.tzPinnedDay;
    DayClock.debugOffsetMinutes = 120;
    roi = DayClock.noteZone(roi, now);
    expect(roi.tzPinnedDay, pinned);
    expect(DayClock.effective(roi, now), pinned);
  });

  test('clock set backwards credits nothing; a day jump past uptime skips refill', () {
    expect(
      ClockGuard.evaluate(
        nowMs: 1000,
        highestWallMs: 5000,
        uptimeMs: 100,
        lastUptimeMs: 50,
        lastWallMs: 5000,
        dayJump: 0,
      ),
      ClockVerdict.clockBack,
    );
    expect(
      ClockGuard.evaluate(
        nowMs: 10 * 24 * 3600 * 1000,
        highestWallMs: 1000,
        uptimeMs: 2000,
        lastUptimeMs: 1000,
        lastWallMs: 1000,
        dayJump: 9,
      ),
      ClockVerdict.skipDailyRefill,
    );
    expect(
      ClockGuard.evaluate(
        nowMs: 90 * 1000,
        highestWallMs: 1000,
        uptimeMs: 80 * 1000,
        lastUptimeMs: 10 * 1000,
        lastWallMs: 1000,
        dayJump: 0,
      ),
      ClockVerdict.ok,
    );
  });

  test('save flush waits inside the window and writes immediately when asked', () {
    expect(
      SaveFlushGate.delayMs(nowMs: 1000, lastWriteMs: 0, immediate: false),
      0,
    );
    expect(
      SaveFlushGate.delayMs(nowMs: 1500, lastWriteMs: 1000, immediate: false),
      1500,
    );
    expect(
      SaveFlushGate.delayMs(nowMs: 1500, lastWriteMs: 1000, immediate: true),
      0,
    );
  });

  test('live event and first-boss drop stay off; wisp cadence ignores remote', () {
    expect(LiveEvent.scaleGold(40, DateTime.utc(2026, 1, 1)), 40);
    expect(RemoteTune.guaranteedFirstBossDrop, isFalse);
    expect(RemoteTune.wispDailyCap, 8);
    expect(RemoteTune.wispIntervalMs, 480 * 1000);
    RemoteTune.apply(dailyCap: 3, intervalSec: 90, fromRemote: true);
    expect(RemoteTune.wispDailyCap, 8);
    expect(RemoteTune.wispIntervalMs, 480 * 1000);
    expect(RemoteTune.liveEventActive(DateTime.utc(2026, 1, 1)), isFalse);
  });

  test('guaranteed blue drop only when the flag is on for the first boss', () {
    final state = GameLogic.createInitialState();
    expect(GameLogic.firstBossPending(state), isTrue);
    final off = LootPipeline.killPayout(
      state: state,
      enemyRole: EnemyRole.boss,
    );
    expect(off.drops, isNotEmpty);
    RemoteTune.apply(guaranteedFirstBoss: true);
    final on = LootPipeline.killPayout(
      state: state,
      enemyRole: EnemyRole.boss,
    );
    expect(on.drops.single.equipment, isNotNull);
    expect(on.drops.single.rarity.index, greaterThanOrEqualTo(2));
  });

  test('encodeGameJson matches json of the same map', () async {
    debugEncodeOnIsolate = true;
    addTearDown(() => debugEncodeOnIsolate = false);
    final map = GameLogic.createInitialState().toJson();
    final encoded = await encodeGameJson(map);
    final back = GameLogic.importSaveJson(encoded);
    expect(back, isNotNull);
    expect(back!.partyName, GameLogic.createInitialState().partyName);
  });

  test('daily vault at key 20, tithe 10, camp 0 is 161', () {
    expect(Keystone.dailyVaultEssence(20), 96);
    expect(10 * GameLogic.dawnTitheEssencePerLevel, 50);
    expect(GameLogic.sanctuaryCost(0), 15);
    expect(96 + 50 + 15, 161);
  });
}
