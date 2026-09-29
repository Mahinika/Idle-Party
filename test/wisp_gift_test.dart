import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/wisp_gift.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('watch gold is at least 10× keep gold on a fresh save', () {
    final state = GameLogic.createInitialState();
    final keep = WispGift.keepGold(state);
    final watch = WispGift.watchGold(state);
    expect(watch, greaterThanOrEqualTo(keep * 10));
  });

  test('grant watch adds gold only and clears pending', () {
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        wispPendingWatchGold: 5000,
        wispPendingKeepGold: 500,
        adGoldUntilMs: now + 1000,
      ),
    );
    final beforeGold = state.gold;
    final goldUntilBefore = state.metaDepth.adGoldUntilMs;
    state = WispGift.grantWatchReward(state);
    expect(state.gold, beforeGold + 5000);
    expect(state.metaDepth.wispPendingWatchGold, 0);
    expect(state.metaDepth.adGoldUntilMs, goldUntilBefore);
  });

  test('grant watch never starts Gold Rush', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        wispPendingWatchGold: 100,
        adGoldUntilMs: 0,
      ),
    );
    state = WispGift.grantWatchReward(state);
    expect(state.metaDepth.adGoldUntilMs, 0);
    expect(state.gold, greaterThan(0));
  });

  test('debug cadence does not stop after six claims', () {
    final now = DateTime.utc(2026, 9, 28, 12);
    var md = MetaDepthState.empty.copyWith(
      wispUnlocked: true,
      wispGiftUtcDay: WispGift.utcDayKey(now),
      wispGiftClaimsToday: 6,
    );
    expect(WispGift.unlimitedToday, isTrue);
    expect(WispGift.canTapToday(md, now: now), isTrue);
    expect(WispGift.intervalMs, 20 * 1000);
  });

  test('on wisp tap locks pending watch amount', () {
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: WispGift.unlockOnFirstEnter(state.metaDepth, nowMs: now),
    );
    final watch = WispGift.watchGold(state);
    final keep = WispGift.keepGold(state);
    final goldBefore = state.gold;
    state = WispGift.onWispTapped(state, nowMs: now);
    expect(state.gold, goldBefore + keep);
    expect(state.metaDepth.wispPendingWatchGold, watch);
    expect(state.metaDepth.wispGiftClaimsToday, 1);
  });

  test('missed wisp pushes next spawn', () {
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        wispUnlocked: true,
        wispNextSpawnMs: now - 1,
      ),
    );
    state = WispGift.onWispMissed(state, nowMs: now);
    expect(
      state.metaDepth.wispNextSpawnMs,
      now + WispGift.intervalMs,
    );
  });

  test('old save JSON defaults wisp fields to zero', () {
    final md = MetaDepthState.fromJson(<String, dynamic>{});
    expect(md.wispUnlocked, isFalse);
    expect(md.wispGiftClaimsToday, 0);
    expect(md.wispPendingWatchGold, 0);
  });

  test('watch button label is gold only', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(wispPendingWatchGold: 2500),
    );
    expect(WispGift.watchButtonLabel(state), '2,500 GOLD');
  });

  test('endgame sandy farm still pays a wallet-worth watch pile', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      gold: 900000,
      ascensionLevel: 4,
      dungeonId: 'sandy',
      highestDungeonCleared: 14,
      highestFloorCleared: 9,
      hardmodeLevel: 11,
      currentRoom: const DungeonRoom(
        floorNumber: 9,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 9,
        enemyCount: 3,
      ),
    );
    final sandyOnly = WispGift.floorGold(
      state,
      dungeonId: 'sandy',
      floor: 9,
    );
    final watch = WispGift.watchGold(state);
    // Old math was ~30× sandy floor (~10–15k). New floor is ~4% wallet.
    expect(watch, greaterThanOrEqualTo(state.gold ~/ WispGift.watchWalletDivisor));
    expect(watch, greaterThan(sandyOnly * 30));
    expect(WispGift.keepGold(state), greaterThan(sandyOnly * WispGift.keepFloorMul));
  });

  test('KEY dial alone does not inflate hub WISP gold', () {
    var base = GameLogic.createInitialState();
    base = base.copyWith(
      gold: 10000,
      dungeonId: 'sandy',
      highestDungeonCleared: 2,
      hardmodeLevel: 0,
      currentRoom: const DungeonRoom(
        floorNumber: 5,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 5,
        enemyCount: 2,
      ),
    );
    final dialed = base.copyWith(hardmodeLevel: 15);
    expect(WispGift.watchGold(dialed), WispGift.watchGold(base));
  });
}
