import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/core/play_games_bridge.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/shop_hub_offer.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shop offer stamp', () {
    test('a modern epoch survives reload and keeps entitlements', () {
      final start = DateTime.utc(2026, 11, 6, 15).millisecondsSinceEpoch;
      expect(start, greaterThan(999999999999));
      final state = GameLogic.createInitialState().copyWith(
        bossVictories: 1,
        metaDepth: const MetaDepthState(
          adFree: true,
          shopLongAway: true,
          grantedShopPurchaseIds: ['supporter_qol'],
        ).copyWith(shopOfferStartedMs: start),
      );
      final loaded = GameLogic.importSaveJson(GameLogic.exportSaveJson(state));
      expect(loaded, isNotNull);
      expect(loaded!.metaDepth.shopOfferStartedMs, start);
      expect(loaded.metaDepth.adFree, isTrue);
      expect(loaded.metaDepth.shopLongAway, isTrue);
      expect(loaded.metaDepth.grantedShopPurchaseIds, ['supporter_qol']);
      expect(
        ShopHubOffer.windowOpen(loaded, now: DateTime.utc(2026, 11, 6, 16)),
        isTrue,
      );
      final expired = ShopHubOffer.ensureWindow(
        loaded,
        now: DateTime.utc(2026, 11, 8),
      );
      expect(expired.metaDepth.shopOfferStartedMs, start);
      expect(expired.metaDepth.adFree, isTrue);
    });

    test('a missing stamp stays unset and does not drop ad-free', () {
      final start = DateTime.utc(2026, 11, 6, 15).millisecondsSinceEpoch;
      final state = GameLogic.createInitialState().copyWith(
        metaDepth: MetaDepthState(shopOfferStartedMs: start, adFree: true),
      );
      final map =
          jsonDecode(GameLogic.exportSaveJson(state)) as Map<String, dynamic>;
      (map['metaDepth'] as Map).remove('shopOfferStartedMs');
      final legacy = GameLogic.stateFromJson(map);
      expect(legacy.metaDepth.shopOfferStartedMs, 0);
      expect(legacy.metaDepth.adFree, isTrue);
    });

    test('negative stamps become zero and a pre-2001 value is kept', () {
      final negative = MetaDepthState.fromJson({
        'shopOfferStartedMs': -8,
        'adFree': true,
      });
      expect(negative.shopOfferStartedMs, 0);
      expect(negative.adFree, isTrue);
      final old = MetaDepthState.fromJson({
        'shopOfferStartedMs': 999999999999,
        'shopLongAway': true,
      });
      expect(old.shopOfferStartedMs, 999999999999);
      expect(old.shopLongAway, isTrue);
    });
  });

  group('cloud payload', () {
    test('empty is missing and junk is a failed read', () {
      expect(PlayGamesBridge.decodeCloudPayload(null).kind, CloudReadKind.empty);
      expect(PlayGamesBridge.decodeCloudPayload('').kind, CloudReadKind.empty);
      expect(
        PlayGamesBridge.decodeCloudPayload('{').kind,
        CloudReadKind.failed,
      );
      expect(
        PlayGamesBridge.decodeCloudPayload('[]').kind,
        CloudReadKind.failed,
      );
      final local = _progress(life: 40, floor: 2);
      final ready = PlayGamesBridge.decodeCloudPayload(
        GameLogic.exportSaveJson(local),
      );
      expect(ready.kind, CloudReadKind.ready);
      expect(ready.state!.lifetimeGoldEarned, 40);
      expect(ready.state!.metaDepth.adFree, isFalse);
    });

    test('a failed read blocks a later upload until a confirmed read', () async {
      addTearDown(PlayGamesBridge.debugResetCloudHooks);
      PlayGamesBridge.debugLoadCloud = () async => const CloudRead.failed();
      expect((await PlayGamesBridge.loadCloud()).kind, CloudReadKind.failed);
      expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
      var uploads = 0;
      PlayGamesBridge.debugSaveCloud = (state) async {
        uploads++;
        return true;
      };
      expect(await PlayGamesBridge.saveCloud(_progress(life: 9)), isFalse);
      expect(uploads, 0);
      PlayGamesBridge.debugLoadCloud = () async => const CloudRead.empty();
      expect((await PlayGamesBridge.loadCloud()).kind, CloudReadKind.empty);
      expect(PlayGamesBridge.cloudWriteBlocked, isFalse);
    });
  });

  group('conflict', () {
    test('clock-only callers keep the stamp rules', () {
      expect(
        PlayGamesScores.resolveConflict(localMs: 200000, cloudMs: 100000),
        CloudConflict.preferLocal,
      );
      expect(
        PlayGamesScores.resolveConflict(localMs: 100000, cloudMs: 200000),
        CloudConflict.preferCloud,
      );
      expect(
        PlayGamesScores.resolveConflict(localMs: 100000, cloudMs: 100030),
        CloudConflict.askUser,
      );
    });

    test('a rolled-back clock cannot replace a further local save', () {
      final local = _progress(life: 500, floor: 8, level: 6, stamp: 1000);
      final cloud = _progress(life: 120, floor: 3, level: 2, stamp: 900000);
      expect(
        PlayGamesScores.resolveConflict(
          localMs: local.metaDepth.cloudSaveUpdatedMs,
          cloudMs: cloud.metaDepth.cloudSaveUpdatedMs,
          local: local,
          cloud: cloud,
        ),
        CloudConflict.preferLocal,
      );
    });

    test('a further cloud save with a newer stamp is preferred', () {
      final local = _progress(life: 80, floor: 2, stamp: 1000);
      final cloud = _progress(life: 400, floor: 9, level: 5, stamp: 200000);
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 1000,
          cloudMs: 200000,
          local: local,
          cloud: cloud,
        ),
        CloudConflict.preferCloud,
      );
    });

    test('an older cloud save stays off this device', () {
      final local = _progress(life: 400, floor: 9, stamp: 300000);
      final cloud = _progress(life: 80, floor: 2, stamp: 1000);
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 300000,
          cloudMs: 1000,
          local: local,
          cloud: cloud,
        ),
        CloudConflict.preferLocal,
      );
    });

    test('equal progress asks, even when the cloud stamp is far ahead', () {
      final local = _progress(life: 200, floor: 4, level: 3, stamp: 100000);
      final cloud = _progress(life: 200, floor: 4, level: 3, stamp: 100030);
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 100000,
          cloudMs: 100030,
          local: local,
          cloud: cloud,
        ),
        CloudConflict.askUser,
      );
      final aheadClock = _progress(life: 200, floor: 4, level: 3, stamp: 800000);
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 100000,
          cloudMs: 800000,
          local: local,
          cloud: aheadClock,
        ),
        CloudConflict.askUser,
      );
    });

    test('spent essence is not progress and ad-free is not dropped silently', () {
      final local = _progress(life: 200, floor: 4, stamp: 1000, essence: 3);
      final cloud = _progress(life: 200, floor: 4, stamp: 900000, essence: 40);
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 1000,
          cloudMs: 900000,
          local: local,
          cloud: cloud,
        ),
        CloudConflict.askUser,
      );
      final owned = _progress(life: 50, floor: 2, stamp: 1000, adFree: true);
      final richer = _progress(life: 900, floor: 12, stamp: 900000);
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 1000,
          cloudMs: 900000,
          local: owned,
          cloud: richer,
        ),
        CloudConflict.askUser,
      );
    });
  });

  group('director cloud', () {
    tearDown(PlayGamesBridge.debugResetCloudHooks);

    test('a failed read does not upload or opt in', () async {
      final local = _progress(life: 320, floor: 6, adFree: true);
      final director = _hold(local);
      addTearDown(director.dispose);
      var uploads = 0;
      _hook(
        read: () => const CloudRead.failed(),
        onSave: (_) => uploads++,
      );
      expect(await director.signInPlayGames(), isTrue);
      expect(uploads, 0);
      expect(director.state.lifetimeGoldEarned, 320);
      expect(director.state.metaDepth.adFree, isTrue);
      expect(director.state.metaDepth.playGamesOptIn, isFalse);
      expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
      expect(await director.backupToPlayGames(), isFalse);
      expect(uploads, 0);
      expect(await director.restoreFromPlayGames(), isFalse);
      expect(director.state.lifetimeGoldEarned, 320);
    });

    test('a confirmed empty cloud may upload this device', () async {
      final local = _progress(life: 15, floor: 1);
      final director = _hold(local);
      addTearDown(director.dispose);
      GameState? uploaded;
      _hook(read: () => const CloudRead.empty(), onSave: (state) => uploaded = state);
      expect(await director.signInPlayGames(), isTrue);
      final sent = uploaded;
      expect(sent, isNotNull);
      expect(sent!.lifetimeGoldEarned, 15);
      expect(sent.metaDepth.playGamesOptIn, isTrue);
      expect(director.state.metaDepth.playGamesOptIn, isTrue);
      expect(PlayGamesBridge.cloudWriteBlocked, isFalse);
    });

    test('malformed cloud is not treated as missing', () async {
      final local = _progress(life: 44, floor: 2);
      final director = _hold(local);
      addTearDown(director.dispose);
      var uploads = 0;
      _hook(
        read: () => PlayGamesBridge.decodeCloudPayload('{"nope"'),
        onSave: (_) => uploads++,
      );
      expect(await director.signInPlayGames(), isTrue);
      expect(uploads, 0);
      expect(director.state.lifetimeGoldEarned, 44);
      expect(director.lastCloudRead.kind, CloudReadKind.failed);
    });

    test('rollback keeps local and a newer cloud can replace it', () async {
      final local = _progress(life: 500, floor: 8, level: 6, stamp: 1000);
      final olderLookingCloud = _progress(
        life: 90,
        floor: 2,
        stamp: 900000,
      );
      final director = _hold(local);
      addTearDown(director.dispose);
      var uploads = 0;
      _hook(
        read: () => CloudRead.ready(olderLookingCloud),
        onSave: (_) => uploads++,
      );
      expect(await director.signInPlayGames(), isTrue);
      expect(director.signInRestoredCloud, isFalse);
      expect(uploads, 0);
      expect(director.state.lifetimeGoldEarned, 500);
      expect(
        director.peekCloudConflict(olderLookingCloud),
        CloudConflict.preferLocal,
      );
      expect(await director.restoreFromPlayGames(), isFalse);
      expect(director.state.lifetimeGoldEarned, 500);

      final newer = _progress(life: 800, floor: 11, level: 8, stamp: 200000);
      PlayGamesBridge.debugLoadCloud = () async => CloudRead.ready(newer);
      expect(await director.restoreFromPlayGames(), isTrue);
      expect(director.state.lifetimeGoldEarned, 800);
      expect(director.hasDisplacedDeviceSave, isTrue);
      expect(await director.restoreDisplacedDeviceSave(), isTrue);
      expect(director.state.lifetimeGoldEarned, 500);
      expect(director.state.metaDepth.adFree, isFalse);
      expect(await director.restoreDisplacedDeviceSave(), isTrue);
      expect(director.state.lifetimeGoldEarned, 800);
    });

    test('equal stamps ask and do not install until the player says so', () async {
      final local = _progress(life: 200, floor: 4, level: 3, stamp: 100000);
      final cloud = _progress(
        life: 200,
        floor: 4,
        level: 3,
        stamp: 100040,
      ).copyWith(partyName: 'Cloud Party');
      final director = _hold(local);
      addTearDown(director.dispose);
      _hook(read: () => CloudRead.ready(cloud), onSave: (_) {});
      expect(await director.restoreFromPlayGames(), isFalse);
      expect(director.state.lifetimeGoldEarned, 200);
      expect(director.state.partyName, isNot('Cloud Party'));
      expect(
        await director.restoreFromPlayGames(force: true, alreadyRead: cloud),
        isTrue,
      );
      expect(director.state.partyName, 'Cloud Party');
      expect(
        director.state.metaDepth.cloudSaveUpdatedMs,
        greaterThan(100040),
      );
      expect(director.hasDisplacedDeviceSave, isTrue);
    });

    test('a fresh device takes a real cloud save and does not upload over it', () async {
      final fresh = GameLogic.createInitialState();
      final cloud = _progress(life: 70, floor: 3, level: 4, stamp: 5000);
      final director = _hold(fresh);
      addTearDown(director.dispose);
      var uploads = 0;
      _hook(read: () => CloudRead.ready(cloud), onSave: (_) => uploads++);
      expect(await director.signInPlayGames(), isTrue);
      expect(director.signInRestoredCloud, isTrue);
      expect(uploads, 0);
      expect(director.state.lifetimeGoldEarned, 70);
      expect(director.state.highestFloorCleared, 3);
    });

    test('a future stamp is not rewound by a later save', () async {
      final future = DateTime.utc(2090).millisecondsSinceEpoch;
      final local = _progress(life: 10, floor: 1, stamp: future);
      final director = _hold(local);
      addTearDown(director.dispose);
      expect(await director.debugTryPersist(), isTrue);
      expect(director.state.metaDepth.cloudSaveUpdatedMs, future);
      expect(director.state.lifetimeGoldEarned, 10);
    });

    test('offline credit does not undo a cloud restore', () async {
      final local = _progress(life: 500, floor: 8, level: 6, stamp: 1000);
      final cloud = _progress(life: 900, floor: 12, level: 9, stamp: 400000);
      final director = _hold(local);
      addTearDown(director.dispose);
      director.debugStampAway(lastUpdatedAgo: const Duration(hours: 3));
      final gate = Completer<void>();
      director.debugAwayCreditPause = gate.future;
      final resume = director.debugResumeFromBackground();
      _hook(read: () => CloudRead.ready(cloud), onSave: (_) {});
      try {
        expect(await director.restoreFromPlayGames(), isTrue);
        expect(director.state.lifetimeGoldEarned, 900);
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
      await resume;
      expect(director.state.lifetimeGoldEarned, 900);
      expect(director.state.highestFloorCleared, 12);
      expect(director.offlineSummary, isNull);
    });
  });

  group('offline clock', () {
    test('a backward clock does not rewind the save or pay the gap', () {
      final saved = GameLogic.createInitialState().copyWith(
        gold: 40,
        lifetimeGoldEarned: 40,
        lastUpdated: DateTime.utc(2026, 11, 6, 12),
      );
      final result = OfflineProgress.applyOfflineProgress(
        saved,
        const Duration(hours: -5),
      );
      expect(result.secondsApplied, 0);
      expect(result.goldGained, 0);
      expect(result.state.gold, 40);
      expect(result.state.lifetimeGoldEarned, 40);
      expect(result.state.lastUpdated, saved.lastUpdated);
    });
  });
}

GameState _progress({
  int life = 0,
  int floor = 0,
  int level = 1,
  int stamp = 0,
  int essence = 0,
  bool adFree = false,
}) {
  final base = GameLogic.createInitialState();
  final roster = [
    for (var i = 0; i < base.heroRoster.length; i++)
      i == 0 ? base.heroRoster[i].copyWith(level: level) : base.heroRoster[i],
  ];
  return base.copyWith(
    lifetimeGoldEarned: life,
    highestFloorCleared: floor,
    essence: essence,
    heroRoster: roster,
    metaDepth: base.metaDepth.copyWith(
      cloudSaveUpdatedMs: stamp,
      adFree: adFree,
    ),
  );
}

GameDirector _hold(GameState state) {
  final director = GameDirector.preview(initialState: state);
  director.debugHoldSave(state);
  return director;
}

void _hook({
  required CloudRead Function() read,
  required void Function(GameState state) onSave,
}) {
  PlayGamesBridge.debugSignIn = () async => true;
  PlayGamesBridge.debugLoadCloud = () async => read();
  PlayGamesBridge.debugSaveCloud = (state) async {
    onSave(state);
    return true;
  };
}
