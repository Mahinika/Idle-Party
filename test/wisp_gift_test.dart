import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
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
    expect(md.wispBossHold, isFalse);
  });

  test('first boss holds the lantern until the tap', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      inDungeon: true,
      metaDepth: WispGift.armAfterFirstBoss(state.metaDepth, nowMs: now),
    );
    expect(state.metaDepth.wispBossHold, isTrue);
    expect(state.metaDepth.wispUnlocked, isTrue);
    expect(state.metaDepth.wispNextSpawnMs, now);
    expect(
      WispGift.wipeNextLanternLine(
        state,
        now: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      ),
      'Gold lantern is in the cave. Tap it.',
    );

    final director = GameDirector.preview(initialState: state);
    await director.boot();
    if (!director.state.inDungeon) {
      director.enterDungeon();
    }
    expect(director.state.metaDepth.wispBossHold, isTrue);
    director.tickWisp(deltaMs: 20000);
    expect(director.isWispVisible, isTrue);
    director.tickWisp(deltaMs: 60000);
    expect(director.isWispVisible, isTrue);

    director.tapWispGift();
    expect(director.state.metaDepth.wispBossHold, isFalse);
    expect(director.isWispVisible, isFalse);
  });

  test('a lantern already tapped today is not held after the boss', () {
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        wispUnlocked: true,
        wispGiftUtcDay: WispGift.utcDayKey(
          DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
        ),
        wispGiftClaimsToday: 1,
        wispNextSpawnMs: now + 600000,
      ),
    );
    final armed = WispGift.armAfterFirstBoss(state.metaDepth, nowMs: now);
    expect(armed.wispBossHold, isFalse);
    expect(armed.wispNextSpawnMs, now + 600000);
  });

  test('watch button label is gold only', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(wispPendingWatchGold: 2500),
    );
    expect(WispGift.watchButtonLabel(state), '2,500 GOLD');
  });

  test('keep button label uses pending keep gold', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(wispPendingKeepGold: 16600),
    );
    expect(WispGift.keepButtonLabel(state), '16.6k GOLD');
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
    expect(
      WispGift.keepGold(state),
      greaterThan(sandyOnly * WispGift.keepFloorCount(state)),
    );
  });

  test('fresh watch is ten early floors, not a floor-10 jackpot', () {
    final state = GameLogic.createInitialState();
    final floor1 = WispGift.floorGold(state, dungeonId: 'sandy', floor: 1);
    final floor10 = WispGift.floorGold(state, dungeonId: 'sandy', floor: 10);
    expect(WispGift.earnedReferenceFloor(state), 1);
    expect(WispGift.watchFloorCount(state), WispGift.watchFloorsFresh);
    expect(WispGift.keepFloorCount(state), 1);
    expect(WispGift.keepGold(state), floor1);
    expect(WispGift.watchGold(state), floor1 * WispGift.watchFloorsFresh);
    expect(WispGift.watchGold(state), lessThan(floor10 * 30));
  });

  test('watch gold grows from a new party to a long save', () {
    final fresh = GameLogic.createInitialState();
    final mid = fresh.copyWith(
      ascensionLevel: 3,
      highestDungeonCleared: 5,
      highestFloorCleared: 6,
      dungeonId: 'hell',
      gold: 0,
      currentRoom: const DungeonRoom(
        floorNumber: 6,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 6,
        enemyCount: 2,
      ),
    );
    final late = fresh.copyWith(
      ascensionLevel: 20,
      highestDungeonCleared: 14,
      highestFloorCleared: 25,
      dungeonId: 'veil',
      gold: 0,
      currentRoom: const DungeonRoom(
        floorNumber: 25,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 25,
        enemyCount: 3,
      ),
    );
    final freshWatch = WispGift.watchGold(fresh);
    final midWatch = WispGift.watchGold(mid);
    final lateWatch = WispGift.watchGold(late);
    expect(midWatch, greaterThan(freshWatch * 3));
    expect(lateWatch, greaterThan(midWatch * 3));
    expect(WispGift.watchFloorCount(late), WispGift.watchFloorsCap);
    expect(WispGift.earnedReferenceFloor(late), 25);
  });

  test('wipe line names next lantern when schedule is armed', () {
    final now = DateTime.utc(2026, 11, 1, 12, 0);
    final nowMs = now.millisecondsSinceEpoch;
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      inDungeon: true,
      metaDepth: state.metaDepth.copyWith(
        wispUnlocked: true,
        wispNextSpawnMs: nowMs + 5 * 60 * 1000,
        wispGiftUtcDay: WispGift.utcDayKey(now),
        wispGiftClaimsToday: 1,
      ),
    );
    expect(
      WispGift.wipeNextLanternLine(state, now: now),
      contains('Next gold lantern in ~5 min'),
    );
    expect(
      WispGift.wipeNextLanternLine(state, now: now),
      contains('left today'),
    );
    expect(
      WispGift.wipeNextLanternLine(
        state.copyWith(inGauntlet: true),
        now: now,
      ),
      isNull,
    );
  });

  test('gauntlet floor does not raise the wisp pile', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      ascensionLevel: 4,
      highestDungeonCleared: 14,
      highestFloorCleared: 9,
      dungeonId: 'sandy',
      gold: 0,
      currentRoom: const DungeonRoom(
        floorNumber: 9,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 9,
        enemyCount: 3,
      ),
    );
    final deep = state.copyWith(
      currentRoom: const DungeonRoom(
        floorNumber: 80,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 80,
        enemyCount: 4,
      ),
      highestFloorCleared: 80,
    );
    expect(WispGift.watchGold(deep), WispGift.watchGold(state));
    expect(WispGift.earnedReferenceFloor(deep), 9);
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
