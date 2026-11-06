import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/core/play_games_bridge.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/save_progress.dart';
import 'package:idle_party/core/save_swap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PlayGamesBridge.debugResetCloudHooks);
  tearDown(PlayGamesBridge.debugResetCloudHooks);

  group('device copy durability', () {
    test(
      'a failed active write keeps both the live file and the device copy',
      () async {
        final local = _progress(life: 500, floor: 8);
        final cloud = _progress(life: 80, floor: 2);
        final director = _hold(local);
        addTearDown(director.dispose);
        final storage = director.debugStorage as InMemoryGameStorage;
        storage.failNextActiveWrite = true;
        expect(
          await director.restoreFromPlayGames(force: true, alreadyRead: cloud),
          isFalse,
        );
        expect(director.state.lifetimeGoldEarned, 500);
        final active = GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        );
        final parked = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(active!.lifetimeGoldEarned, 500);
        expect(parked!.lifetimeGoldEarned, 500);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      },
    );

    test('a failed swap does not overwrite the only device copy', () async {
      final local = _progress(life: 500, floor: 8);
      final cloud = _progress(life: 80, floor: 2);
      final director = _hold(local);
      addTearDown(director.dispose);
      expect(
        await director.restoreFromPlayGames(force: true, alreadyRead: cloud),
        isTrue,
      );
      final storage = director.debugStorage as InMemoryGameStorage;
      storage.failNextActiveWrite = true;
      expect(await director.restoreDisplacedDeviceSave(), isFalse);
      expect(director.state.lifetimeGoldEarned, 80);
      final parked = GameLogic.importSaveJson(
        (await storage.loadDisplacedSave())!,
      );
      expect(parked!.lifetimeGoldEarned, 500);
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);
    });

    test(
      'a crash after the swap commits still recovers the other file',
      () async {
        final storage = InMemoryGameStorage();
        final device = _progress(life: 500, floor: 8);
        final current = _progress(life: 80, floor: 2);
        final merged = _progress(life: 500, floor: 8, adFree: true);
        await storage.writeActiveRaw(GameLogic.exportSaveJson(merged));
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(device),
        );
        await storage.writeExtra(
          GameStorage.stagingKey,
          GameLogic.exportSaveJson(merged),
        );
        await storage.writeExtra(
          GameStorage.holdKey,
          GameLogic.exportSaveJson(current),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-commit');
        await SaveSwap.recover(storage);
        final active = GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        );
        final parked = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(active!.lifetimeGoldEarned, 500);
        expect(active.metaDepth.adFree, isTrue);
        expect(parked!.lifetimeGoldEarned, 80);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      },
    );

    test(
      'a crash before the swap commits leaves the device copy alone',
      () async {
        final storage = InMemoryGameStorage();
        final device = _progress(life: 500, floor: 8);
        final current = _progress(life: 80, floor: 2);
        final merged = _progress(life: 500, floor: 9);
        await storage.writeActiveRaw(GameLogic.exportSaveJson(current));
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(device),
        );
        await storage.writeExtra(
          GameStorage.stagingKey,
          GameLogic.exportSaveJson(merged),
        );
        await storage.writeExtra(
          GameStorage.holdKey,
          GameLogic.exportSaveJson(current),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-commit');
        await SaveSwap.recover(storage);
        final active = GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        );
        final parked = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(active!.lifetimeGoldEarned, 80);
        expect(parked!.lifetimeGoldEarned, 500);
      },
    );
  });

  group('paid ownership', () {
    test(
      'a level-1 paid save is not replaced until the player chooses',
      () async {
        final local = GameLogic.createInitialState().copyWith(
          metaDepth: const MetaDepthState(adFree: true),
        );
        expect(SaveProgress.isReplaceable(local), isFalse);
        expect(PlayGamesScores.hasPaidOwnership(local), isTrue);
        final cloud = _progress(life: 80, floor: 4, level: 3);
        final director = _hold(local);
        addTearDown(director.dispose);
        _hook(read: () => CloudRead.ready(cloud));
        expect(await director.signInPlayGames(), isTrue);
        expect(director.signInRestoredCloud, isFalse);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(director.state.lifetimeGoldEarned, 0);
        expect(await director.restoreFromPlayGames(), isFalse);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(await director.restoreFromPlayGames(force: true), isTrue);
        expect(director.state.lifetimeGoldEarned, 80);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(director.hasDisplacedDeviceSave, isTrue);
      },
    );

    test(
      'explicit cloud and device copies keep ownership and not materials',
      () async {
        final local = _progress(life: 20, floor: 1).copyWith(
          metaDepth: _progress(life: 20, floor: 1).metaDepth.copyWith(
            adFree: true,
            cinders: 10,
            adTickets: 4,
            grantedShopPurchaseIds: const ['ad_free'],
          ),
        );
        final cloudBase = _progress(life: 400, floor: 9, level: 6);
        final cloud = cloudBase.copyWith(
          metaDepth: cloudBase.metaDepth.copyWith(
            paidSeasonPass: true,
            cinders: 3,
            adTickets: 1,
            grantedShopPurchaseIds: const ['season_pass_premium'],
          ),
        );
        final director = _hold(local);
        addTearDown(director.dispose);
        expect(
          await director.restoreFromPlayGames(force: true, alreadyRead: cloud),
          isTrue,
        );
        expect(director.state.lifetimeGoldEarned, 400);
        expect(director.state.metaDepth.cinders, 3);
        expect(director.state.metaDepth.adTickets, 1);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(director.state.metaDepth.paidSeasonPass, isTrue);
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          containsAll(['ad_free', 'season_pass_premium']),
        );
        expect(await director.restoreDisplacedDeviceSave(), isTrue);
        expect(director.state.lifetimeGoldEarned, 20);
        expect(director.state.metaDepth.cinders, 10);
        expect(director.state.metaDepth.adTickets, 4);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(director.state.metaDepth.paidSeasonPass, isTrue);
      },
    );
  });

  group('upload fail-closed', () {
    test('a cold start cannot upload before a confirmed read', () async {
      var uploads = 0;
      PlayGamesBridge.debugSaveCloud = (_) async {
        uploads++;
        return true;
      };
      expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
      expect(await PlayGamesBridge.saveCloud(_progress(life: 5)), isFalse);
      expect(uploads, 0);
    });

    test(
      'signed-out and unavailable block, and a restart blocks again',
      () async {
        var uploads = 0;
        PlayGamesBridge.debugSaveCloud = (_) async {
          uploads++;
          return true;
        };
        PlayGamesBridge.debugLoadCloud = () async =>
            const CloudRead.signedOut();
        expect(
          (await PlayGamesBridge.loadCloud()).kind,
          CloudReadKind.signedOut,
        );
        expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
        expect(await PlayGamesBridge.saveCloud(_progress(life: 5)), isFalse);
        PlayGamesBridge.debugLoadCloud = () async =>
            const CloudRead.unavailable();
        expect(
          (await PlayGamesBridge.loadCloud()).kind,
          CloudReadKind.unavailable,
        );
        expect(await PlayGamesBridge.saveCloud(_progress(life: 5)), isFalse);
        PlayGamesBridge.debugLoadCloud = () async => const CloudRead.empty();
        expect((await PlayGamesBridge.loadCloud()).kind, CloudReadKind.empty);
        expect(PlayGamesBridge.cloudWriteBlocked, isFalse);
        PlayGamesBridge.debugResetCloudHooks();
        PlayGamesBridge.debugSaveCloud = (_) async {
          uploads++;
          return true;
        };
        expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
        expect(await PlayGamesBridge.saveCloud(_progress(life: 5)), isFalse);
        expect(uploads, 0);
      },
    );

    test('an account change during the commit aborts the upload', () async {
      var account = 'alpha';
      var uploads = 0;
      PlayGamesBridge.debugAccountId = () async => account;
      PlayGamesBridge.debugLoadCloud = () async => const CloudRead.empty();
      PlayGamesBridge.debugBeforeCloudCommit = () async {
        account = 'beta';
      };
      PlayGamesBridge.debugSaveCloud = (_) async {
        uploads++;
        return true;
      };
      expect(await PlayGamesBridge.saveCloud(_progress(life: 12)), isFalse);
      expect(uploads, 0);
      expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
    });

    test('a failed re-read during the commit aborts the upload', () async {
      var uploads = 0;
      PlayGamesBridge.debugLoadCloud = () async => const CloudRead.empty();
      PlayGamesBridge.debugBeforeCloudCommit = () async {
        PlayGamesBridge.debugLoadCloud = () async => const CloudRead.failed();
        await PlayGamesBridge.loadCloud();
      };
      PlayGamesBridge.debugSaveCloud = (_) async {
        uploads++;
        return true;
      };
      expect(await PlayGamesBridge.saveCloud(_progress(life: 12)), isFalse);
      expect(uploads, 0);
    });

    test('automatic upload does not overwrite a different snapshot', () async {
      final cloud = _progress(life: 9, floor: 1);
      final local = _progress(life: 40, floor: 4);
      PlayGamesBridge.debugLoadCloud = () async => CloudRead.ready(cloud);
      var uploads = 0;
      PlayGamesBridge.debugSaveCloud = (_) async {
        uploads++;
        return true;
      };
      expect(await PlayGamesBridge.loadCloud(), isNotNull);
      expect(await PlayGamesBridge.saveCloud(local), isFalse);
      expect(uploads, 0);
      expect(await PlayGamesBridge.saveCloud(local, explicit: true), isTrue);
      expect(uploads, 1);
    });

    test(
      'automatic upload may continue a snapshot this device just wrote',
      () async {
        final local = _progress(life: 15, floor: 2);
        GameState? sent;
        PlayGamesBridge.debugLoadCloud = () async => const CloudRead.empty();
        PlayGamesBridge.debugSaveCloud = (state) async {
          sent = state;
          return true;
        };
        expect(await PlayGamesBridge.saveCloud(local), isTrue);
        final first = sent;
        expect(first, isNotNull);
        PlayGamesBridge.debugLoadCloud = () async => CloudRead.ready(first!);
        final moved = first!.copyWith(lifetimeGoldEarned: 16);
        expect(await PlayGamesBridge.saveCloud(moved), isTrue);
        PlayGamesBridge.debugLoadCloud = () async =>
            CloudRead.ready(_progress(life: 999, floor: 20));
        expect(await PlayGamesBridge.saveCloud(moved), isFalse);
      },
    );
  });

  group('purchase during restore', () {
    test(
      'a grant that arrives during the copy lands on the committed file',
      () async {
        final local = _progress(life: 40, floor: 2);
        final cloud = _progress(life: 300, floor: 7, level: 5);
        final director = _hold(local);
        addTearDown(director.dispose);
        final storage = director.debugStorage as InMemoryGameStorage;
        final gate = Completer<void>();
        storage.pauseBeforeNextWrite = gate.future;
        final install = director.restoreFromPlayGames(
          force: true,
          alreadyRead: cloud,
        );
        var spins = 0;
        while (!storage.writeEntered && spins < 40) {
          await Future<void>.delayed(Duration.zero);
          spins++;
        }
        expect(storage.writeEntered, isTrue);
        final grant = director.debugGrantShopPurchase(
          'ad_free',
          purchaseId: 'order-1',
        );
        await Future<void>.delayed(Duration.zero);
        expect(director.state.metaDepth.adFree, isFalse);
        gate.complete();
        expect(await install, isTrue);
        expect(await grant, isTrue);
        expect(director.state.lifetimeGoldEarned, 300);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(director.state.metaDepth.grantedShopPurchaseIds, ['order-1']);
        final durable = await storage.load();
        expect(durable!.lifetimeGoldEarned, 300);
        expect(durable.metaDepth.adFree, isTrue);
        expect(durable.metaDepth.grantedShopPurchaseIds, contains('order-1'));
      },
    );

    test(
      'a grant that commits first is still on the file after restore',
      () async {
        final local = _progress(life: 40, floor: 2);
        final cloud = _progress(life: 300, floor: 7, level: 5);
        final director = _hold(local);
        addTearDown(director.dispose);
        final storage = director.debugStorage as InMemoryGameStorage;
        final gate = Completer<void>();
        storage.pauseBeforeNextWrite = gate.future;
        final grant = director.debugGrantShopPurchase(
          'ad_free',
          purchaseId: 'order-2',
        );
        var spins = 0;
        while (!storage.writeEntered && spins < 40) {
          await Future<void>.delayed(Duration.zero);
          spins++;
        }
        expect(storage.writeEntered, isTrue);
        final install = director.restoreFromPlayGames(
          force: true,
          alreadyRead: cloud,
        );
        gate.complete();
        expect(await grant, isTrue);
        expect(await install, isTrue);
        expect(director.state.lifetimeGoldEarned, 300);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          contains('order-2'),
        );
        final parked = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(parked!.metaDepth.adFree, isTrue);
        expect(parked.lifetimeGoldEarned, 40);
      },
    );
  });

  group('no partial dominance', () {
    test('an untouched starter is replaceable and a CAMP upgrade is not', () {
      expect(SaveProgress.blockers(GameLogic.createInitialState()), isEmpty);
      final camp = GameLogic.createInitialState().copyWith(
        metaDepth: const MetaDepthState(sanctuaryXpLevel: 3),
      );
      expect(SaveProgress.isReplaceable(camp), isFalse);
      expect(
        SaveProgress.blockers(camp),
        contains('metaDepth.sanctuaryXpLevel'),
      );
    });

    test('equal clocks ask, and a partial payload is not cloud-ahead', () {
      final local = _progress(life: 40, floor: 2, stamp: 1000);
      final same = local.copyWith(
        lastUpdated: DateTime.utc(1999),
        metaDepth: local.metaDepth.copyWith(cloudSaveUpdatedMs: 900000),
      );
      expect(
        PlayGamesScores.compareSaveProgress(local, same),
        SaveProgressRelation.tie,
      );
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 1000,
          cloudMs: 900000,
          local: local,
          cloud: same,
        ),
        CloudConflict.askUser,
      );
      final camp = local.copyWith(
        metaDepth: local.metaDepth.copyWith(sanctuaryXpLevel: 4),
      );
      final rich = _progress(life: 900, floor: 14, level: 8, stamp: 800000);
      expect(
        PlayGamesScores.compareSaveProgress(camp, rich),
        SaveProgressRelation.diverged,
      );
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 1000,
          cloudMs: 800000,
          local: camp,
          cloud: rich,
        ),
        CloudConflict.askUser,
      );
      final map = jsonDecode(GameLogic.exportSaveJson(rich)) as Map;
      (map['metaDepth'] as Map).remove('sanctuaryXpLevel');
      final partial = GameLogic.stateFromJson(Map<String, dynamic>.from(map));
      expect(partial.metaDepth.sanctuaryXpLevel, 0);
      expect(
        PlayGamesScores.compareSaveProgress(camp, partial),
        SaveProgressRelation.diverged,
      );
      expect(
        PlayGamesScores.resolveConflict(
          localMs: 1000,
          cloudMs: partial.metaDepth.cloudSaveUpdatedMs,
          local: camp,
          cloud: partial,
        ),
        CloudConflict.askUser,
      );
    });
  });

  group('native missing snapshot', () {
    test(
      'a successful list without this name is empty and does not open',
      () async {
        var opened = 0;
        final read = await PlayGamesBridge.readSnapshot(
          listNames: () async => const ['some-other-save'],
          loadPayload: () async {
            opened++;
            throw PlatformException(
              code: 'failed_to_load_game',
              message: 'NETWORK_ERROR',
            );
          },
        );
        expect(read.kind, CloudReadKind.empty);
        expect(opened, 0);
      },
    );

    test(
      'open throwing SNAPSHOT_NOT_FOUND on a listed name stays failed',
      () async {
        final read = await PlayGamesBridge.readSnapshot(
          listNames: () async => [PlayGamesBridge.snapshotName],
          loadPayload: () async {
            throw PlatformException(
              code: 'failed_to_load_game',
              message: 'SNAPSHOT_NOT_FOUND',
            );
          },
        );
        expect(read.kind, CloudReadKind.failed);
      },
    );

    test(
      'a list failure is failed even when open would return nothing',
      () async {
        var opened = 0;
        final read = await PlayGamesBridge.readSnapshot(
          listNames: () async => throw PlatformException(
            code: 'failed_to_get_saved_games',
            message: 'network',
          ),
          loadPayload: () async {
            opened++;
            return null;
          },
        );
        expect(read.kind, CloudReadKind.failed);
        expect(opened, 0);
        final blank = await PlayGamesBridge.readSnapshot(
          listNames: () async => [PlayGamesBridge.snapshotName],
          loadPayload: () async => '',
        );
        expect(blank.kind, CloudReadKind.failed);
        final missingList = await PlayGamesBridge.readSnapshot(
          listNames: () async => null,
          loadPayload: () async => null,
        );
        expect(missingList.kind, CloudReadKind.failed);
      },
    );
  });
}

GameState _progress({
  int life = 0,
  int floor = 0,
  int level = 1,
  int stamp = 0,
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

void _hook({required CloudRead Function() read}) {
  PlayGamesBridge.debugSignIn = () async => true;
  PlayGamesBridge.debugLoadCloud = () async => read();
  PlayGamesBridge.debugSaveCloud = (_) async => true;
}
