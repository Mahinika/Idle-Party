import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/play_games_bridge.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/save_swap.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/shell/save_recovery_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PlayGamesBridge.debugResetCloudHooks);
  tearDown(PlayGamesBridge.debugResetCloudHooks);

  group('swap outcomes', () {
    test(
      'a failed publish marker still commits, and the next save keeps both parties',
      () async {
        final current = _party(life: 80, cinders: 4);
        final parked = _party(life: 500, cinders: 1);
        final director = _hold(current);
        addTearDown(director.dispose);
        expect(
          await director.restoreFromPlayGames(force: true, alreadyRead: parked),
          isTrue,
        );
        final storage = director.debugStorage as InMemoryGameStorage;
        storage.failExtraWhen = (key, value) {
          if (key == GameStorage.journalKey && value == 'swap-publish') {
            storage.failExtraWhen = null;
            return true;
          }
          return false;
        };
        expect(await director.restoreDisplacedDeviceSave(), isTrue);
        expect(director.state.lifetimeGoldEarned, 80);
        final displaced = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(displaced!.lifetimeGoldEarned, 500);
        expect(await director.debugTryPersist(), isTrue);
        final active = GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        );
        final stillParked = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(active!.lifetimeGoldEarned, 80);
        expect(stillParked!.lifetimeGoldEarned, 500);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(await storage.loadExtra(GameStorage.holdKey), isNull);
      },
    );

    test(
      'a legacy mirror failure after the slot write still commits both parties',
      () async {
        final current = _party(life: 80);
        final parked = _party(life: 500);
        final director = _hold(current);
        addTearDown(director.dispose);
        expect(
          await director.restoreFromPlayGames(force: true, alreadyRead: parked),
          isTrue,
        );
        final storage = director.debugStorage as InMemoryGameStorage;
        storage.failNextMirrorWrite = true;
        expect(await director.restoreDisplacedDeviceSave(), isTrue);
        expect(director.state.lifetimeGoldEarned, 80);
        final displaced = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(displaced!.lifetimeGoldEarned, 500);
        expect(await director.debugTryPersist(), isTrue);
        final active = GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        );
        expect(active!.lifetimeGoldEarned, 80);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadDisplacedSave())!,
          )!.lifetimeGoldEarned,
          500,
        );
      },
    );

    test(
      'a failed publish leaves the journal, and autosave does not delete it',
      () async {
        final current = _party(life: 80, adFree: true);
        final parked = _party(life: 500);
        final director = _hold(current);
        addTearDown(director.dispose);
        expect(
          await director.restoreFromPlayGames(force: true, alreadyRead: parked),
          isTrue,
        );
        final storage = director.debugStorage as InMemoryGameStorage;
        storage.failExtraWhen = (key, value) =>
            key == GameStorage.displacedKey && value != null;
        expect(await director.restoreDisplacedDeviceSave(), isFalse);
        expect(director.debugSaveRecoveryBlocked, isTrue);
        expect(await storage.loadExtra(GameStorage.holdKey), isNotNull);
        expect(await storage.loadExtra(GameStorage.journalKey), isNotNull);
        final hold = GameLogic.importSaveJson(
          (await storage.loadExtra(GameStorage.holdKey))!,
        );
        expect(hold!.metaDepth.adFree, isTrue);
        expect(await director.debugTryPersist(), isFalse);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadExtra(GameStorage.holdKey))!,
          )!.metaDepth.adFree,
          isTrue,
        );
        storage.failExtraWhen = null;
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
        final active = GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        );
        final displaced = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(active!.lifetimeGoldEarned, 80);
        expect(displaced!.lifetimeGoldEarned, 500);
        expect(displaced.metaDepth.adFree, isTrue);
        expect(await storage.loadExtra(GameStorage.holdKey), isNull);
      },
    );

    test(
      'simulated second crash after the hold is published still keeps both parties',
      () async {
        final storage = InMemoryGameStorage();
        final active = _party(life: 500);
        final hold = _party(life: 80, adFree: true);
        final activeJson = GameLogic.exportSaveJson(active);
        final holdJson = GameLogic.exportSaveJson(hold);
        await storage.writeActiveRaw(activeJson);
        await storage.writeExtra(GameStorage.stagingKey, activeJson);
        await storage.writeExtra(GameStorage.holdKey, holdJson);
        await storage.writeExtra(GameStorage.displacedKey, holdJson);
        await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadActiveRaw())!,
          )!.lifetimeGoldEarned,
          500,
        );
        expect(
          GameLogic.importSaveJson(
            (await storage.loadDisplacedSave())!,
          )!.metaDepth.adFree,
          isTrue,
        );
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(await storage.loadExtra(GameStorage.holdKey), isNull);
      },
    );

    test('boot does not overwrite an unresolved journal', () async {
      final storage = InMemoryGameStorage();
      final active = _party(life: 500);
      final hold = _party(life: 80, adFree: true);
      await storage.writeActiveRaw(GameLogic.exportSaveJson(active));
      await storage.writeExtra(
        GameStorage.stagingKey,
        GameLogic.exportSaveJson(active),
      );
      await storage.writeExtra(
        GameStorage.holdKey,
        GameLogic.exportSaveJson(hold),
      );
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      storage.failExtraWhen = (key, value) => key == GameStorage.displacedKey;
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.debugSaveRecoveryBlocked, isTrue);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        )!.lifetimeGoldEarned,
        500,
      );
      expect(
        GameLogic.importSaveJson(
          (await storage.loadExtra(GameStorage.holdKey))!,
        )!.metaDepth.adFree,
        isTrue,
      );
      expect(await director.debugTryPersist(), isFalse);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
    });

    test(
      'simulated process kill after the active write still recovers both parties',
      () async {
        final storage = InMemoryGameStorage();
        final current = _party(life: 80, adFree: true);
        final parked = _party(life: 500);
        await storage.writeActiveRaw(GameLogic.exportSaveJson(current));
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(parked),
        );
        storage.killAfterNextActiveDurableWrite = true;
        expect(
          await SaveSwap.commitSwap(
            storage: storage,
            newActiveJson: GameLogic.exportSaveJson(parked),
            newDisplacedJson: GameLogic.exportSaveJson(current),
          ),
          SaveSwapOutcome.committed,
        );
        final restarted = InMemoryGameStorage();
        restarted.restoreDurableBytes(storage.bytesAtKill!);
        expect(await SaveSwap.recover(restarted), SaveSwapOutcome.committed);
        expect(
          GameLogic.importSaveJson(
            (await restarted.loadActiveRaw())!,
          )!.lifetimeGoldEarned,
          500,
        );
        expect(
          GameLogic.importSaveJson(
            (await restarted.loadDisplacedSave())!,
          )!.metaDepth.adFree,
          isTrue,
        );
      },
    );

    test(
      'a cache that shows the new slot before the platform rejects it does not commit',
      () async {
        final storage = InMemoryGameStorage();
        final current = _party(life: 80);
        final parked = _party(life: 500);
        await storage.writeActiveRaw(GameLogic.exportSaveJson(current));
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(parked),
        );
        storage.cacheAheadOnFailedWrite = true;
        storage.failNextActiveWrite = true;
        expect(
          await SaveSwap.commitSwap(
            storage: storage,
            newActiveJson: GameLogic.exportSaveJson(parked),
            newDisplacedJson: GameLogic.exportSaveJson(current),
          ),
          SaveSwapOutcome.aborted,
        );
        expect(
          GameLogic.importSaveJson(
            (await storage.loadActiveRaw())!,
          )!.lifetimeGoldEarned,
          80,
        );
        expect(
          GameLogic.importSaveJson(
            (await storage.loadDisplacedSave())!,
          )!.lifetimeGoldEarned,
          500,
        );
      },
    );
  });

  group('slot journal', () {
    test('slot 1 recovery does not delete slot 0 evidence', () async {
      final storage = InMemoryGameStorage();
      final slot0 = _party(life: 500, adFree: true);
      final slot1 = _party(life: 12);
      await storage.writeExtra(GameStorage.journalKeyFor(0), 'swap-publish');
      await storage.writeExtra(
        GameStorage.holdKeyFor(0),
        GameLogic.exportSaveJson(slot0),
      );
      await storage.writeExtra(
        GameStorage.stagingKeyFor(0),
        GameLogic.exportSaveJson(slot1),
      );
      await storage.setActiveSlot(1);
      await storage.writeActiveRaw(GameLogic.exportSaveJson(slot1));
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.idle);
      expect(await storage.loadExtra(GameStorage.holdKeyFor(0)), isNotNull);
      expect(
        await storage.loadExtra(GameStorage.journalKeyFor(0)),
        'swap-publish',
      );
    });
  });

  group('ownership and backup', () {
    test('the 64-id cap keeps the chosen receipts', () {
      final chosen = _party(
        purchaseIds: [for (var i = 0; i < 64; i++) 'chosen-$i'],
      );
      final other = _party(
        purchaseIds: [for (var i = 0; i < 64; i++) 'other-$i'],
      );
      final merged = PlayGamesScores.withKeptOwnership(
        chosen: chosen,
        other: other,
      );
      expect(merged.metaDepth.grantedShopPurchaseIds, contains('chosen-0'));
      expect(merged.metaDepth.grantedShopPurchaseIds, contains('chosen-63'));
      expect(
        merged.metaDepth.grantedShopPurchaseIds.any(
          (id) => id.startsWith('other-'),
        ),
        isFalse,
      );
      final replay = GameLogic.importSaveJson(GameLogic.exportSaveJson(merged));
      expect(ShopBilling.alreadyGranted(replay!, 'chosen-63'), isTrue);
    });

    test('KEEP DEVICE and BACKUP NOW union paid ownership only', () async {
      final local = _party(life: 40, cinders: 3, adFree: true, tickets: 2);
      final cloud = _party(
        life: 90,
        cinders: 9,
        tickets: 8,
        pass: true,
        purchaseIds: const ['cloud-receipt'],
      );
      final director = _hold(local);
      addTearDown(director.dispose);
      expect(await director.keepDeviceAndCloudOwnership(cloud), isTrue);
      expect(director.state.metaDepth.adFree, isTrue);
      expect(director.state.metaDepth.paidSeasonPass, isTrue);
      expect(director.state.metaDepth.cinders, 3);
      expect(director.state.metaDepth.adTickets, 2);
      expect(director.state.lifetimeGoldEarned, 40);
      expect(
        director.state.metaDepth.grantedShopPurchaseIds,
        contains('cloud-receipt'),
      );

      GameState? uploaded;
      PlayGamesBridge.debugAccountId = () async => 'player-1';
      PlayGamesBridge.debugLoadCloud = () async => CloudRead.ready(cloud);
      PlayGamesBridge.debugSaveCloud = (state) async {
        uploaded = state;
        return true;
      };
      expect(await director.backupToPlayGames(), isTrue);
      expect(uploaded!.metaDepth.adFree, isTrue);
      expect(uploaded!.metaDepth.paidSeasonPass, isTrue);
      expect(uploaded!.metaDepth.cinders, 3);
      expect(uploaded!.lifetimeGoldEarned, 40);
      expect(
        director.state.metaDepth.cloudBackupPreviousSeal,
        PlayGamesScores.progressSeal(cloud),
      );
    });

    test(
      'an opted-in restart resumes automatic backup for this device lineage',
      () async {
        final cloud = _party(life: 10, floor: 2);
        final seal = PlayGamesScores.progressSeal(cloud);
        final local = _party(life: 80, floor: 4, optIn: true).copyWith(
          metaDepth: _party(
            life: 80,
            floor: 4,
            optIn: true,
          ).metaDepth.copyWith(cloudBackupSeal: seal),
        );
        final director = _hold(local);
        addTearDown(director.dispose);
        var uploads = 0;
        PlayGamesBridge.debugAccountId = () async => 'player-1';
        PlayGamesBridge.debugLoadCloud = () async => CloudRead.ready(cloud);
        PlayGamesBridge.debugSaveCloud = (_) async {
          uploads++;
          return true;
        };
        await director.rebindOptedInCloudBackup();
        expect(await PlayGamesBridge.saveCloud(director.state), isTrue);
        expect(uploads, 1);
      },
    );

    test(
      'BACKUP NOW works on a cold start and then automatic backup continues',
      () async {
        final cloud = _party(life: 10, floor: 2, pass: true, cinders: 9);
        final local = _party(life: 80, floor: 4, optIn: true, adFree: true);
        final director = _hold(local);
        addTearDown(director.dispose);
        GameState? uploaded;
        PlayGamesBridge.debugAccountId = () async => 'player-1';
        PlayGamesBridge.debugLoadCloud = () async => CloudRead.ready(cloud);
        PlayGamesBridge.debugSaveCloud = (state) async {
          uploaded = state;
          return true;
        };
        expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
        expect(await PlayGamesBridge.saveCloud(director.state), isFalse);
        expect(uploaded, isNull);
        expect(await director.backupToPlayGames(), isTrue);
        expect(uploaded!.metaDepth.adFree, isTrue);
        expect(uploaded!.metaDepth.paidSeasonPass, isTrue);
        expect(uploaded!.metaDepth.cinders, local.metaDepth.cinders);
        expect(await PlayGamesBridge.saveCloud(director.state), isTrue);
      },
    );

    test('a stale snapshot list is not a missing snapshot', () async {
      var opened = 0;
      final read = await PlayGamesBridge.readSnapshot(
        listNames: () async => const SnapshotNameList(names: [], fresh: false),
        loadPayload: () async {
          opened++;
          return null;
        },
      );
      expect(read.kind, CloudReadKind.failed);
      expect(opened, 0);
    });

    test('a restore drops an upload armed for the previous party', () async {
      final local = _party(life: 20, optIn: true);
      final cloud = _party(life: 90, optIn: true);
      final director = _hold(local);
      addTearDown(director.dispose);
      var uploads = 0;
      PlayGamesBridge.debugAccountId = () async => 'player-1';
      PlayGamesBridge.debugLoadCloud = () async => const CloudRead.empty();
      PlayGamesBridge.debugSaveCloud = (_) async {
        uploads++;
        return true;
      };
      await PlayGamesBridge.loadCloud();
      PlayGamesBridge.scheduleCloudUpload(local);
      expect(PlayGamesBridge.debugHasPendingUpload, isTrue);
      PlayGamesBridge.debugLoadCloud = () async => CloudRead.ready(cloud);
      expect(
        await director.restoreFromPlayGames(force: true, alreadyRead: cloud),
        isTrue,
      );
      expect(PlayGamesBridge.debugHasPendingUpload, isFalse);
      expect(await PlayGamesBridge.debugFlushPendingUpload(), isFalse);
      expect(uploads, 0);
    });
  });

  group('grant versus resume and slot change', () {
    test(
      'a grant during warm resume is still in the save afterwards',
      () async {
        final director = _hold(_party(life: 15));
        addTearDown(director.dispose);
        director.debugStampAway(lastUpdatedAgo: const Duration(minutes: 5));
        final release = Completer<void>();
        director.debugAwayCreditPause = release.future;
        final pending = director.debugResumeFromBackground();
        await pumpEventQueue();
        expect(
          await director.debugGrantShopPurchase(
            'ad_free',
            purchaseId: 'resume-grant',
          ),
          isTrue,
        );
        expect(director.state.metaDepth.adFree, isTrue);
        release.complete();
        await pending;
        expect(director.state.metaDepth.adFree, isTrue);
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          contains('resume-grant'),
        );
        final saved = await (director.debugStorage as InMemoryGameStorage)
            .load();
        expect(saved!.metaDepth.adFree, isTrue);
        expect(
          saved.metaDepth.grantedShopPurchaseIds,
          contains('resume-grant'),
        );
      },
    );

    test('a grant during a slot change lands on the opened slot', () async {
      final local = _party(life: 15);
      final other = _party(life: 70);
      final director = _hold(local);
      addTearDown(director.dispose);
      final storage = director.debugStorage as InMemoryGameStorage;
      await storage.setActiveSlot(1);
      await storage.save(other);
      await storage.setActiveSlot(0);
      final release = Completer<void>();
      director.debugAwayCreditPause = release.future;
      final opening = director.openSaveSlot(1);
      await pumpEventQueue();
      final granting = director.debugGrantShopPurchase(
        'ad_free',
        purchaseId: 'slot-grant',
      );
      release.complete();
      expect(await opening, isTrue);
      expect(await granting, isTrue);
      expect(director.state.lifetimeGoldEarned, 70);
      expect(director.state.metaDepth.adFree, isTrue);
      expect(
        director.state.metaDepth.grantedShopPurchaseIds,
        contains('slot-grant'),
      );
      final slot1 = await storage.loadSlot(1);
      final slot0 = await storage.loadSlot(0);
      expect(slot1!.metaDepth.adFree, isTrue);
      expect(slot0!.metaDepth.adFree, isFalse);
    });
  });

  group('recovery matrix', () {
    test(
      'an in-process reload throw after cleanup still commits both parties',
      () async {
        final current = _party(life: 80, adFree: true);
        final parked = _party(life: 500, cinders: 2);
        final director = _hold(current);
        addTearDown(director.dispose);
        expect(
          await director.restoreFromPlayGames(force: true, alreadyRead: parked),
          isTrue,
        );
        final storage = director.debugStorage as InMemoryGameStorage;
        storage.skipReloadsBeforeThrow = 2;
        storage.reloadThrowsRemaining = 1;
        expect(await director.restoreDisplacedDeviceSave(), isTrue);
        expect(director.saveRecoveryBlocked, isFalse);
        expect(director.state.lifetimeGoldEarned, 80);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(await director.debugTryPersist(), isTrue);
        final active = GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        );
        final displaced = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(active!.lifetimeGoldEarned, 80);
        expect(active.metaDepth.adFree, isTrue);
        expect(displaced!.lifetimeGoldEarned, 500);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      },
    );

    test('a reload that cannot be repeated blocks the next autosave', () async {
      final current = _party(life: 80, adFree: true);
      final parked = _party(life: 500);
      final director = _hold(current);
      addTearDown(director.dispose);
      expect(
        await director.restoreFromPlayGames(force: true, alreadyRead: parked),
        isTrue,
      );
      final storage = director.debugStorage as InMemoryGameStorage;
      storage.skipReloadsBeforeThrow = 2;
      storage.reloadThrowsRemaining = 2;
      expect(await director.restoreDisplacedDeviceSave(), isFalse);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.saveRecoveryMessage, isNotEmpty);
      final durable = storage.durableBytes();
      expect(await director.debugTryPersist(), isFalse);
      expect(storage.durableBytes(), durable);
      final idleBefore = director.state.metaDepth.hubAfkSec;
      director.debugStampAway(lastUpdatedAgo: const Duration(minutes: 5));
      director.debugTickHubIdle();
      expect(director.state.metaDepth.hubAfkSec, idleBefore);
      await director.buyShopItem('ad_free');
      expect(director.toast, contains('Purchases stay off'));
      await director.eraseSaveSlot(0);
      expect(await storage.loadActiveRaw(), isNotNull);
      await director.startNewGame(HeroSpecs.starterUnlocked);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        )!.lifetimeGoldEarned,
        isNot(0),
      );
      storage.reloadThrowsRemaining = 0;
      expect(await director.retrySaveRecovery(), isTrue);
      expect(director.saveRecoveryBlocked, isFalse);
      expect(director.state.lifetimeGoldEarned, 80);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        )!.lifetimeGoldEarned,
        500,
      );
    });

    test('a second device copy does not replace the only hold', () async {
      final storage = InMemoryGameStorage();
      final active = _party(life: 500);
      final hold = _party(life: 80, adFree: true, cinders: 7);
      final holdJson = GameLogic.exportSaveJson(hold);
      await storage.writeActiveRaw(GameLogic.exportSaveJson(active));
      await storage.writeExtra(
        GameStorage.stagingKey,
        GameLogic.exportSaveJson(active),
      );
      await storage.writeExtra(GameStorage.holdKey, holdJson);
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      storage.failExtraWhen = (key, value) => key == GameStorage.displacedKey;
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await director.restoreDisplacedDeviceSave(), isFalse);
      expect(await storage.loadExtra(GameStorage.holdKey), holdJson);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
      expect(
        await SaveSwap.commitSwap(
          storage: storage,
          newActiveJson: GameLogic.exportSaveJson(active),
          newDisplacedJson: holdJson,
        ),
        SaveSwapOutcome.unresolved,
      );
      expect(await storage.loadExtra(GameStorage.holdKey), holdJson);
    });

    test(
      'cleanup that already deleted staging and hold can still finish',
      () async {
        final storage = InMemoryGameStorage();
        final active = _party(life: 500);
        final parked = _party(life: 80, adFree: true);
        await storage.writeActiveRaw(GameLogic.exportSaveJson(active));
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(parked),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.idle);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadDisplacedSave())!,
          )!.metaDepth.adFree,
          isTrue,
        );
      },
    );

    test('a throw during cleanup is finished by the next recovery', () async {
      final storage = InMemoryGameStorage();
      final active = _party(life: 500);
      final hold = _party(life: 80, adFree: true);
      final activeJson = GameLogic.exportSaveJson(active);
      await storage.writeActiveRaw(activeJson);
      await storage.writeExtra(GameStorage.stagingKey, activeJson);
      await storage.writeExtra(
        GameStorage.holdKey,
        GameLogic.exportSaveJson(hold),
      );
      await storage.writeExtra(
        GameStorage.displacedKey,
        GameLogic.exportSaveJson(hold),
      );
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      storage.throwAfterDeletingKey = GameStorage.holdKey;
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
      expect(await storage.loadExtra(GameStorage.stagingKey), isNull);
      expect(await storage.loadExtra(GameStorage.holdKey), isNull);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadActiveRaw())!,
        )!.lifetimeGoldEarned,
        500,
      );
      expect(
        GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        )!.metaDepth.adFree,
        isTrue,
      );
    });

    test(
      'a swap killed before the active write keeps the newer live party',
      () async {
        final storage = InMemoryGameStorage();
        final autosave = _party(life: 10);
        final live = _party(life: 80, adFree: true, cinders: 4);
        final incoming = _party(life: 500);
        await storage.writeActiveRaw(GameLogic.exportSaveJson(autosave));
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(_party(life: 1)),
        );
        await storage.writeExtra(
          GameStorage.stagingKey,
          GameLogic.exportSaveJson(incoming),
        );
        await storage.writeExtra(
          GameStorage.holdKey,
          GameLogic.exportSaveJson(live),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-commit');
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadActiveRaw())!,
          )!.lifetimeGoldEarned,
          500,
        );
        final parked = GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        );
        expect(parked!.lifetimeGoldEarned, 80);
        expect(parked.metaDepth.adFree, isTrue);
        expect(parked.metaDepth.cinders, 4);
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.idle);
      },
    );

    test(
      'a legacy global journal is adopted by the slot whose bytes match',
      () async {
        final storage = InMemoryGameStorage();
        final incoming = _party(life: 500);
        final live = _party(life: 80, adFree: true);
        final incomingJson = GameLogic.exportSaveJson(incoming);
        await storage.setActiveSlot(2);
        await storage.writeActiveRaw(incomingJson);
        await storage.writeExtra(GameStorage.stagingKey, incomingJson);
        await storage.writeExtra(
          GameStorage.holdKey,
          GameLogic.exportSaveJson(live),
        );
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(_party(life: 1)),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isFalse);
        expect(director.activeSaveSlot, 2);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
        final parked = GameLogic.importSaveJson(
          (await storage.loadExtra(GameStorage.displacedKeyFor(2)))!,
        );
        expect(parked!.metaDepth.adFree, isTrue);
        expect(parked.lifetimeGoldEarned, 80);
      },
    );

    test('an unmatched legacy journal is kept and blocks saving', () async {
      final storage = InMemoryGameStorage();
      final live = _party(life: 80, adFree: true);
      final holdJson = GameLogic.exportSaveJson(live);
      await storage.setActiveSlot(2);
      await storage.writeActiveRaw(GameLogic.exportSaveJson(_party(life: 3)));
      await storage.writeExtra(GameStorage.holdKey, holdJson);
      await storage.writeExtra(
        GameStorage.stagingKey,
        GameLogic.exportSaveJson(_party(life: 9)),
      );
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await storage.loadExtra(GameStorage.holdKey), holdJson);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
      expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
      expect(await director.debugTryPersist(), isFalse);
      expect(await director.retrySaveRecovery(), isFalse);
      expect(await storage.loadExtra(GameStorage.holdKey), holdJson);
    });

    test(
      'BACKUP unions ownership from the final read, not only the first',
      () async {
        final local = _party(life: 80, cinders: 3, adFree: true);
        final first = _party(life: 10, cinders: 9);
        final observed = _party(
          life: 12,
          cinders: 40,
          pass: true,
          purchaseIds: const ['paid-observed'],
        );
        final director = _hold(local);
        addTearDown(director.dispose);
        var reads = 0;
        GameState? uploaded;
        PlayGamesBridge.debugAccountId = () async => 'player-1';
        PlayGamesBridge.debugLoadCloud = () async {
          reads++;
          return CloudRead.ready(reads == 1 ? first : observed);
        };
        PlayGamesBridge.debugSaveCloud = (state) async {
          uploaded = state;
          return true;
        };
        expect(await director.backupToPlayGames(), isTrue);
        expect(reads, greaterThanOrEqualTo(2));
        expect(uploaded!.metaDepth.paidSeasonPass, isTrue);
        expect(uploaded!.metaDepth.adFree, isTrue);
        expect(uploaded!.metaDepth.cinders, 3);
        expect(uploaded!.lifetimeGoldEarned, 80);
        expect(
          uploaded!.metaDepth.grantedShopPurchaseIds,
          contains('paid-observed'),
        );
        expect(director.state.metaDepth.paidSeasonPass, isTrue);
        expect(director.state.metaDepth.cinders, 3);
        expect(director.state.lifetimeGoldEarned, 80);
      },
    );

    test('a snapshot list without a stale bool is not fresh', () async {
      final missing = PlayGamesBridge.snapshotListFromChannel({
        'names': ['idle_party'],
      });
      expect(missing.fresh, isFalse);
      expect(missing.names, ['idle_party']);
      final word = PlayGamesBridge.snapshotListFromChannel({
        'names': ['idle_party'],
        'stale': 'false',
      });
      expect(word.fresh, isFalse);
      final fresh = PlayGamesBridge.snapshotListFromChannel({
        'names': ['idle_party'],
        'stale': false,
      });
      expect(fresh.fresh, isTrue);
      var opened = 0;
      final read = await PlayGamesBridge.readSnapshot(
        listNames: () async => missing,
        loadPayload: () async {
          opened++;
          return '{}';
        },
      );
      expect(read.kind, CloudReadKind.failed);
      expect(opened, 0);
    });

    test('a pending other-file receipt is kept when the cap has room', () {
      final chosen = _party(purchaseIds: const ['chosen-open']);
      final other = _party(purchaseIds: const ['pending-other']);
      final merged = PlayGamesScores.withKeptOwnership(
        chosen: chosen,
        other: other,
      );
      expect(
        merged.metaDepth.grantedShopPurchaseIds,
        contains('pending-other'),
      );
      expect(ShopBilling.alreadyGranted(merged, 'pending-other'), isTrue);
      final pouch = ShopCatalog.byId['cinder_pouch']!;
      expect(
        ShopBilling.shouldGrantPurchase(
          item: pouch,
          restored: true,
          purchaseId: 'pending-other',
          alreadyGranted: ShopBilling.alreadyGranted(merged, 'pending-other'),
        ),
        isFalse,
      );
    });

    test('a full chosen list leaves an unconsumed other receipt out', () {
      final chosen = _party(
        purchaseIds: [for (var i = 0; i < 64; i++) 'chosen-$i'],
      );
      final other = _party(adFree: true, purchaseIds: const ['pending-other']);
      final merged = PlayGamesScores.withKeptOwnership(
        chosen: chosen,
        other: other,
      );
      expect(merged.metaDepth.adFree, isTrue);
      expect(
        merged.metaDepth.grantedShopPurchaseIds,
        isNot(contains('pending-other')),
      );
      expect(ShopBilling.alreadyGranted(merged, 'pending-other'), isFalse);
      final pouch = ShopCatalog.byId['cinder_pouch']!;
      expect(
        ShopBilling.shouldGrantPurchase(
          item: pouch,
          restored: true,
          purchaseId: 'pending-other',
          alreadyGranted: false,
        ),
        isTrue,
      );
      expect(
        ShopBilling.applyPurchase(merged, ShopCatalog.byId['ad_free']!),
        same(merged),
      );
    });

    test('a grant in flight stays on its slot when import is queued', () async {
      final director = _hold(_party(life: 15));
      addTearDown(director.dispose);
      final storage = director.debugStorage as InMemoryGameStorage;
      final release = Completer<void>();
      storage.pauseBeforeNextWrite = release.future;
      final granting = director.debugGrantShopPurchase(
        'ad_free',
        purchaseId: 'import-grant',
      );
      await pumpEventQueue();
      expect(storage.writeEntered, isTrue);
      final arming = director.armImportSlot(1);
      release.complete();
      expect(await granting, isTrue);
      await arming;
      expect(director.activeSaveSlot, 1);
      await storage.setActiveSlot(0);
      final slot0 = await storage.load();
      expect(slot0!.metaDepth.grantedShopPurchaseIds, contains('import-grant'));
      expect(slot0.metaDepth.adFree, isTrue);
    });

    testWidgets('the recovery gate stays up and retries', (tester) async {
      var tries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SaveRecoveryGate(
            message: 'Saving is paused. Retry keeps both copies.',
            onRetry: () async {
              tries++;
              return false;
            },
          ),
        ),
      );
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      expect(tries, 1);
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
    });
  });

  group('shared_preferences cache', () {
    test('plugin cache readback is not treated as a durable write', () async {
      final store = _RejectingPrefsStore();
      final previous = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = store;
      SharedPreferences.resetStatic();
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await prefs.setString('idle_party_save_slot_0', 'OLD'), isTrue);
      expect(await prefs.setString('idle_party_save_v2', 'OLD'), isTrue);
      store.rejectWrites = true;
      final lied = await prefs.setString('probe', 'NEW');
      expect(lied, isFalse);
      expect(prefs.getString('probe'), 'NEW');
      await prefs.reload();
      expect(prefs.getString('probe'), isNull);

      final storage = SharedPreferencesGameStorage(preferences: prefs);
      expect(await storage.writeActiveRaw('NEW-SLOT'), isFalse);
      expect(prefs.getString('idle_party_save_slot_0'), 'NEW-SLOT');
      await storage.reloadDurable();
      expect(await storage.loadActiveRaw(), 'OLD');
    });
  });

  group('swap-stage live party and migration', () {
    test(
      'swap-stage retry publishes the live party after the active write',
      () async {
        final storage = InMemoryGameStorage();
        final autosave = _party(life: 10);
        final live = _party(life: 80, adFree: true, cinders: 4);
        final incoming = _party(life: 500);
        final liveJson = GameLogic.exportSaveJson(live);
        final incomingJson = GameLogic.exportSaveJson(incoming);
        await storage.writeActiveRaw(incomingJson);
        await storage.writeExtra(GameStorage.stagingKey, incomingJson);
        await storage.writeExtra(GameStorage.holdKey, liveJson);
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(autosave),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-stage');
        var publishFails = 0;
        storage.failExtraWhen = (key, value) {
          if (key != GameStorage.displacedKey || value == null) return false;
          publishFails++;
          return publishFails <= 2;
        };
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
        expect(await storage.loadExtra(GameStorage.holdKey), liveJson);
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
        expect(await storage.loadExtra(GameStorage.holdKey), liveJson);
        storage.failExtraWhen = null;
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadDisplacedSave())!,
          )!.metaDepth.cinders,
          4,
        );
        expect(
          GameLogic.importSaveJson(
            (await storage.loadActiveRaw())!,
          )!.lifetimeGoldEarned,
          500,
        );
        expect(await storage.loadExtra(GameStorage.holdKey), isNull);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      },
    );

    test(
      'a simulated kill between the active write and the copy publish keeps the live party',
      () async {
        final storage = InMemoryGameStorage();
        final live = _party(life: 80, adFree: true, cinders: 4);
        final incoming = _party(life: 500);
        final liveJson = GameLogic.exportSaveJson(live);
        await storage.writeActiveRaw(
          GameLogic.exportSaveJson(_party(life: 10)),
        );
        await storage.writeExtra(
          GameStorage.stagingKey,
          GameLogic.exportSaveJson(incoming),
        );
        await storage.writeExtra(GameStorage.holdKey, liveJson);
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(_party(life: 1)),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-stage');
        storage.killAfterNextActiveDurableWrite = true;
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
        final killed = storage.bytesAtKill;
        expect(killed, isNotNull);
        final fresh = InMemoryGameStorage();
        fresh.restoreDurableBytes(killed!);
        expect(await SaveSwap.recover(fresh), SaveSwapOutcome.committed);
        expect(
          GameLogic.importSaveJson(
            (await fresh.loadDisplacedSave())!,
          )!.metaDepth.cinders,
          4,
        );
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadDisplacedSave())!,
          )!.metaDepth.adFree,
          isTrue,
        );
      },
    );

    test(
      'a cloud restore refuses to replace a different parked party',
      () async {
        final current = _party(life: 80);
        final parked = _party(life: 500, adFree: true, cinders: 7);
        final incoming = _party(life: 900, pass: true);
        final director = _hold(current);
        addTearDown(director.dispose);
        final storage = director.debugStorage as InMemoryGameStorage;
        final parkedJson = GameLogic.exportSaveJson(parked);
        await storage.writeExtra(GameStorage.displacedKey, parkedJson);
        expect(
          await director.restoreFromPlayGames(
            force: true,
            alreadyRead: incoming,
          ),
          isFalse,
        );
        expect(director.saveRecoveryBlocked, isFalse);
        expect(director.state.lifetimeGoldEarned, 80);
        expect(director.toast, contains('device copy is already saved'));
        expect(await storage.loadDisplacedSave(), parkedJson);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(
          await SaveSwap.commitReplacement(
            storage: storage,
            nextJson: GameLogic.exportSaveJson(incoming),
            previousJson: GameLogic.exportSaveJson(current),
          ),
          SaveSwapOutcome.aborted,
        );
        expect(await storage.loadDisplacedSave(), parkedJson);
      },
    );

    test('an empty legacy marker is cleared', () async {
      final storage = InMemoryGameStorage();
      final party = _party(life: 80);
      await storage.setActiveSlot(2);
      await storage.writeActiveRaw(GameLogic.exportSaveJson(party));
      await storage.writeExtra(GameStorage.journalKey, 'park');
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isFalse);
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      expect(director.state.lifetimeGoldEarned, 80);
    });

    test('a parked legacy party is migrated by its bytes', () async {
      final storage = InMemoryGameStorage();
      final parked = _party(life: 80, adFree: true);
      final parkedJson = GameLogic.exportSaveJson(parked);
      await storage.setActiveSlot(2);
      await storage.writeActiveRaw(parkedJson);
      await storage.writeExtra(GameStorage.displacedKey, parkedJson);
      await storage.writeExtra(GameStorage.journalKey, 'park');
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isFalse);
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      expect(director.state.metaDepth.adFree, isTrue);
    });

    test(
      'a destination journal without its payload resumes and does not stick',
      () async {
        final storage = InMemoryGameStorage();
        final incoming = _party(life: 500);
        final live = _party(life: 80, adFree: true, cinders: 4);
        final incomingJson = GameLogic.exportSaveJson(incoming);
        final liveJson = GameLogic.exportSaveJson(live);
        await storage.setActiveSlot(2);
        await storage.writeActiveRaw(incomingJson);
        await storage.writeExtra(GameStorage.journalKeyFor(2), 'swap-publish');
        await storage.writeExtra(GameStorage.stagingKey, incomingJson);
        await storage.writeExtra(GameStorage.holdKey, liveJson);
        await storage.writeExtra(
          GameStorage.displacedKey,
          GameLogic.exportSaveJson(_party(life: 1)),
        );
        await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isFalse);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadExtra(GameStorage.displacedKeyFor(2)))!,
          )!.metaDepth.cinders,
          4,
        );
      },
    );

    test(
      'a leftover global marker is cleared once the slot has the party',
      () async {
        final storage = InMemoryGameStorage();
        final live = _party(life: 80, adFree: true);
        final liveJson = GameLogic.exportSaveJson(live);
        await storage.setActiveSlot(2);
        await storage.writeActiveRaw(
          GameLogic.exportSaveJson(_party(life: 500)),
        );
        await storage.writeExtra(GameStorage.displacedKeyFor(2), liveJson);
        await storage.writeExtra(GameStorage.displacedKey, liveJson);
        await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isFalse);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(
          await storage.loadExtra(GameStorage.displacedKeyFor(2)),
          liveJson,
        );
      },
    );

    test(
      'two matching slots are not guessed and other slots still open',
      () async {
        final storage = InMemoryGameStorage();
        final shared = GameLogic.exportSaveJson(_party(life: 80, adFree: true));
        final other = GameLogic.exportSaveJson(_party(life: 3));
        await storage.setActiveSlot(1);
        await storage.writeActiveRaw(shared);
        await storage.setActiveSlot(2);
        await storage.writeActiveRaw(shared);
        await storage.writeExtra(GameStorage.stagingKey, shared);
        await storage.writeExtra(GameStorage.holdKey, other);
        await storage.writeExtra(GameStorage.journalKey, 'swap-stage');
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        expect(director.saveRecoveryAmbiguous, isTrue);
        expect(await storage.loadExtra(GameStorage.journalKey), 'swap-stage');
        expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
        expect(await storage.loadExtra(GameStorage.holdKey), other);
        expect(director.safeRecoverySlots, contains(3));
        expect(director.safeRecoverySlots, isNot(contains(0)));
        expect(director.safeRecoverySlots, isNot(contains(1)));
        expect(director.safeRecoverySlots, isNot(contains(2)));
        final exported = await director.exportRecoveryRecords();
        expect(exported, contains('swap-stage'));
        expect(exported, contains(other));
        expect(await storage.loadExtra(GameStorage.journalKey), 'swap-stage');
        expect(await director.retrySaveRecovery(), isFalse);
        expect(await director.openSafeRecoverySlot(0), isFalse);
        expect(await director.openSafeRecoverySlot(2), isFalse);
        expect(await director.openSafeRecoverySlot(3), isTrue);
        expect(director.saveRecoveryBlocked, isFalse);
        expect(await storage.loadExtra(GameStorage.journalKey), 'swap-stage');
        expect(await storage.loadExtra(GameStorage.holdKey), other);
      },
    );

    test('a unique slot 0 journal does not block another slot', () async {
      final storage = InMemoryGameStorage();
      final owned = GameLogic.exportSaveJson(_party(life: 80, adFree: true));
      await storage.setActiveSlot(0);
      await storage.writeActiveRaw(owned);
      await storage.setActiveSlot(2);
      await storage.writeActiveRaw(GameLogic.exportSaveJson(_party(life: 3)));
      await storage.writeExtra(GameStorage.holdKey, owned);
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isFalse);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
      expect(await director.debugTryPersist(), isTrue);
      expect(await storage.loadExtra(GameStorage.holdKey), owned);
    });

    test('a proven slot 0 journal still publishes its own hold', () async {
      final storage = InMemoryGameStorage();
      final live = _party(life: 80, adFree: true, cinders: 4);
      final incoming = _party(life: 500);
      final liveJson = GameLogic.exportSaveJson(live);
      final incomingJson = GameLogic.exportSaveJson(incoming);
      await storage.setActiveSlot(0);
      await storage.writeActiveRaw(incomingJson);
      await storage.writeExtra(GameStorage.stagingKey, incomingJson);
      await storage.writeExtra(GameStorage.holdKey, liveJson);
      await storage.writeExtra(
        GameStorage.displacedKey,
        GameLogic.exportSaveJson(_party(life: 1)),
      );
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isFalse);
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      expect(await _finalHasCinders(storage, 4), isFalse);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadExtra(GameStorage.displacedKey))!,
        )!.metaDepth.cinders,
        4,
      );
      expect(await director.debugTryPersist(), isTrue);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadSlotRaw(0))!,
        )!.metaDepth.adFree,
        isFalse,
      );
    });

    test('selecting slot 0 does not apply a slot 2 journal', () async {
      for (final phase in ['swap-commit', 'swap-publish']) {
        final planted = await _plantSlot0Selection(phase: phase);
        final storage = planted.storage;
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
        expect(await storage.loadSlotRaw(0), planted.slot0);
        expect(await storage.loadSlotRaw(2), planted.owner);
        expect(await storage.loadExtra(GameStorage.journalKey), phase);
        expect(await storage.loadExtra(GameStorage.holdKey), planted.held);
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isFalse, reason: phase);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(_rawHas(await storage.loadSlotRaw(0), 'd0-only'), isTrue);
        expect(await storage.loadSlotRaw(2), planted.owner);
        expect(
          await storage.loadExtra(GameStorage.holdKeyFor(2)),
          planted.held,
        );
        expect(await director.debugTryPersist(), isTrue, reason: phase);
        expect(_rawHas(await storage.loadSlotRaw(0), 'd0-only'), isTrue);
        expect(await storage.loadSlotRaw(2), planted.owner);
        expect(await director.openSaveSlot(2), isTrue, reason: phase);
        expect(_rawHas(await storage.loadSlotRaw(0), 'd0-only'), isTrue);
        expect(await _slotFinalHasCinders(storage, 2, 4), isTrue);
        expect(await director.restoreDisplacedDeviceSave(), isTrue);
        expect(await _slotFinalHasCinders(storage, 2, 4), isTrue);
        expect(_rawHas(await storage.loadSlotRaw(0), 'd0-only'), isTrue);
      }
    });

    test('slot 0 selection cuts keep both parties for a later boot', () async {
      const writes = 8;
      for (var n = 1; n <= writes; n++) {
        for (final kind in ['fail', 'throw-before', 'throw-after']) {
          final planted = await _plantSlot0Selection(phase: 'swap-commit');
          final storage = planted.storage;
          storage.armExtraWriteCut(
            failAt: kind == 'fail' ? n : null,
            throwBefore: kind == 'throw-before' ? n : null,
            throwAfter: kind == 'throw-after' ? n : null,
          );
          await SaveSwap.migrateLegacyGlobalJournal(storage);
          expect(storage.failNthExtraWrite, isNull, reason: '$kind $n');
          expect(storage.throwBeforeNthExtraWrite, isNull, reason: kind);
          expect(storage.throwAfterNthExtraWrite, isNull, reason: kind);
          storage.clearExtraWriteCut();
          expect(await storage.loadSlotRaw(0), planted.slot0, reason: kind);
          expect(await storage.loadSlotRaw(2), planted.owner, reason: kind);
          await SaveSwap.recover(storage);
          expect(await storage.loadSlotRaw(0), planted.slot0, reason: kind);
          expect(
            await _durableHas(storage, planted.held),
            isTrue,
            reason: '$kind $n',
          );
          final director = GameDirector(storage, enableSpatialLoop: false);
          addTearDown(director.dispose);
          await director.boot();
          if (director.saveRecoveryBlocked) {
            expect(await director.retrySaveRecovery(), isTrue, reason: kind);
          }
          expect(director.saveRecoveryBlocked, isFalse, reason: '$kind $n');
          expect(
            _rawHas(await storage.loadSlotRaw(0), 'd0-only'),
            isTrue,
            reason: '$kind $n',
          );
          expect(await director.debugTryPersist(), isTrue, reason: kind);
          expect(
            _rawHas(await storage.loadSlotRaw(0), 'd0-only'),
            isTrue,
            reason: '$kind $n save',
          );
          expect(
            await _durableHas(storage, planted.held) ||
                await _slotFinalHasCinders(storage, 2, 4),
            isTrue,
            reason: '$kind $n held party',
          );
          expect(await storage.loadSlotRaw(2), planted.owner, reason: kind);
        }
      }
    });

    test(
      'a journal nobody matches is not given to the selected slot',
      () async {
        final planted = await _plantSlot0Selection(phase: 'swap-commit');
        final storage = planted.storage;
        final selected = GameLogic.exportSaveJson(
          _party(life: 15, purchaseIds: const ['slot1-only']),
        );
        await _writeSlot(
          storage,
          2,
          GameLogic.exportSaveJson(
            _party(life: 9, purchaseIds: const ['other']),
          ),
        );
        await _writeSlot(storage, 1, selected);
        await storage.setActiveSlot(1);
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        expect(director.saveRecoveryAmbiguous, isTrue);
        expect(await storage.loadSlotRaw(0), planted.slot0);
        expect(await storage.loadSlotRaw(1), selected);
        expect(await storage.loadExtra(GameStorage.journalKey), 'swap-commit');
        expect(await storage.loadExtra(GameStorage.holdKey), planted.held);
        final exported = await director.exportRecoveryRecords();
        expect(exported, contains('d0-only'));
        expect(exported, contains('swap-commit'));
        expect(exported, contains(planted.held));
        expect(
          await SaveSwap.recover(storage, slot: 0),
          SaveSwapOutcome.unresolved,
        );
        expect(await storage.loadSlotRaw(0), planted.slot0);
        expect(await storage.loadSlotRaw(1), selected);
        expect(await director.retrySaveRecovery(), isFalse);
        expect(await director.openSafeRecoverySlot(0), isFalse);
        expect(director.safeRecoverySlots, contains(4));
        expect(director.safeRecoverySlots, isNot(contains(0)));
        expect(await director.openSafeRecoverySlot(4), isTrue);
        expect(await storage.loadSlotRaw(0), planted.slot0);
        expect(await storage.loadExtra(GameStorage.journalKey), 'swap-commit');
      },
    );

    test('a journal nobody matches is not applied to slot 0', () async {
      final planted = await _plantSlot0Selection(phase: 'swap-commit');
      final storage = planted.storage;
      await _writeSlot(
        storage,
        2,
        GameLogic.exportSaveJson(_party(life: 9, purchaseIds: const ['other'])),
      );
      await storage.setActiveSlot(0);
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.saveRecoveryAmbiguous, isTrue);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-commit');
      expect(await storage.loadExtra(GameStorage.holdKey), planted.held);
      final exported = await director.exportRecoveryRecords();
      expect(exported, contains('d0-only'));
      expect(exported, contains(planted.held));
      expect(await director.retrySaveRecovery(), isFalse);
      expect(await director.debugTryPersist(), isFalse);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      expect(await director.openSafeRecoverySlot(0), isFalse);
      expect(director.safeRecoverySlots, contains(4));
      expect(await director.openSafeRecoverySlot(4), isTrue);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-commit');
      expect(await storage.loadExtra(GameStorage.holdKey), planted.held);
    });

    test('two owners are not resolved onto the selected slot', () async {
      final planted = await _plantSlot0Selection(phase: 'swap-publish');
      final storage = planted.storage;
      await _writeSlot(storage, 3, planted.owner);
      await storage.setActiveSlot(0);
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.saveRecoveryAmbiguous, isTrue);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      expect(await storage.loadSlotRaw(2), planted.owner);
      expect(await storage.loadSlotRaw(3), planted.owner);
      expect(await storage.loadExtra(GameStorage.holdKey), planted.held);
      expect(director.safeRecoverySlots, contains(4));
      expect(director.safeRecoverySlots, isNot(contains(0)));
      expect(director.safeRecoverySlots, isNot(contains(2)));
      expect(director.safeRecoverySlots, isNot(contains(3)));
      expect(await director.retrySaveRecovery(), isFalse);
      expect(await storage.loadSlotRaw(0), planted.slot0);
    });

    test(
      'a nonzero selection does not receive another slot\'s journal',
      () async {
        final planted = await _plantSlot0Selection(phase: 'swap-commit');
        final storage = planted.storage;
        final selected = GameLogic.exportSaveJson(
          _party(life: 15, purchaseIds: const ['slot1-only']),
        );
        await _writeSlot(storage, 1, selected);
        await storage.setActiveSlot(1);
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isFalse);
        expect(_rawHas(await storage.loadSlotRaw(1), 'slot1-only'), isTrue);
        expect(await storage.loadSlotRaw(0), planted.slot0);
        expect(await storage.loadSlotRaw(2), planted.owner);
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
        expect(
          await storage.loadExtra(GameStorage.holdKeyFor(2)),
          planted.held,
        );
        expect(await director.debugTryPersist(), isTrue);
        expect(_rawHas(await storage.loadSlotRaw(1), 'slot1-only'), isTrue);
        expect(await storage.loadSlotRaw(0), planted.slot0);
      },
    );

    test('an unrelated scoped journal does not consume slot 0', () async {
      final planted = await _plantSlot0Selection(phase: 'swap-commit');
      final storage = planted.storage;
      final other = GameLogic.exportSaveJson(
        _party(life: 7, purchaseIds: const ['scoped-other']),
      );
      await _writeSlot(storage, 2, other);
      await storage.writeExtra(GameStorage.journalKeyFor(2), 'swap-stage');
      await storage.writeExtra(GameStorage.stagingKeyFor(2), other);
      await _writeSlot(storage, 3, planted.owner);
      await storage.setActiveSlot(0);
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      expect(await storage.loadSlotRaw(2), other);
      expect(await storage.loadSlotRaw(3), planted.owner);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-commit');
      expect(await storage.loadExtra(GameStorage.holdKey), planted.held);
      expect(
        await storage.loadExtra(GameStorage.journalKeyFor(2)),
        'swap-stage',
      );
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      final exported = await director.exportRecoveryRecords();
      expect(exported, contains('d0-only'));
      expect(exported, contains(planted.held));
    });

    test(
      'migration cuts keep the source until a later retry can finish',
      () async {
        final incoming = _party(life: 500);
        final live = _party(life: 80, adFree: true, cinders: 4);
        final previous = _party(life: 1);
        final incomingJson = GameLogic.exportSaveJson(incoming);
        final liveJson = GameLogic.exportSaveJson(live);
        final previousJson = GameLogic.exportSaveJson(previous);
        // Eight side-file writes: staging, hold, displaced, journal, then the
        // four source deletes. Each cut is that one write, not the first N.
        // The throw is in-process. It is not an operating-system kill.
        const writes = 8;
        for (var n = 1; n <= writes; n++) {
          for (final kind in ['fail', 'throw-before', 'throw-after']) {
            final storage = InMemoryGameStorage();
            await _plantGlobalSwap(
              storage,
              active: incomingJson,
              staging: incomingJson,
              hold: liveJson,
              displaced: previousJson,
            );
            storage.armExtraWriteCut(
              failAt: kind == 'fail' ? n : null,
              throwBefore: kind == 'throw-before' ? n : null,
              throwAfter: kind == 'throw-after' ? n : null,
            );
            final stuck = await SaveSwap.migrateLegacyGlobalJournal(storage);
            expect(
              storage.failNthExtraWrite,
              isNull,
              reason: '$kind $n did not reach that write',
            );
            expect(storage.throwBeforeNthExtraWrite, isNull, reason: kind);
            expect(storage.throwAfterNthExtraWrite, isNull, reason: kind);
            storage.clearExtraWriteCut();
            await _expectOwnerMarkerIfHoldIsOnlyCopy(
              storage,
              liveJson,
              reason: '$kind $n',
            );
            expect(
              await _durableHas(storage, liveJson),
              isTrue,
              reason: '$kind $n dropped the held party before retry',
            );
            expect(
              await _durableHas(storage, incomingJson),
              isTrue,
              reason: '$kind $n',
            );
            expect(
              await _durableHas(storage, previousJson),
              isTrue,
              reason: '$kind $n',
            );
            if (stuck) {
              expect(
                await storage.loadExtra(GameStorage.journalKey) != null ||
                    await storage.loadExtra(GameStorage.journalKeyFor(2)) !=
                        null,
                isTrue,
                reason: '$kind $n',
              );
            }
            final director = GameDirector(storage, enableSpatialLoop: false);
            addTearDown(director.dispose);
            await director.boot();
            expect(director.saveRecoveryBlocked, isFalse, reason: '$kind $n');
            expect(
              await director.debugTryPersist(),
              isTrue,
              reason: '$kind $n',
            );
            expect(
              await _finalHasCinders(storage, 4),
              isTrue,
              reason: '$kind $n',
            );
            expect(await director.restoreDisplacedDeviceSave(), isTrue);
            expect(
              await _finalHasCinders(storage, 4),
              isTrue,
              reason: '$kind $n device copy',
            );
            expect(await director.restoreDisplacedDeviceSave(), isTrue);
            expect(
              await _finalHasCinders(storage, 4),
              isTrue,
              reason: '$kind $n second device copy',
            );
          }
        }
      },
    );

    test('a cut before the scoped journal does not orphan the hold', () async {
      final incoming = _party(life: 500);
      final live = _party(life: 80, adFree: true, cinders: 4);
      final previous = _party(life: 1);
      final incomingJson = GameLogic.exportSaveJson(incoming);
      final liveJson = GameLogic.exportSaveJson(live);
      final previousJson = GameLogic.exportSaveJson(previous);
      final storage = InMemoryGameStorage();
      await _plantGlobalSwap(
        storage,
        active: incomingJson,
        staging: incomingJson,
        hold: liveJson,
        displaced: previousJson,
      );
      storage.failExtraWhen = (key, value) =>
          key == GameStorage.journalKeyFor(2) && value == 'swap-publish';
      expect(await SaveSwap.migrateLegacyGlobalJournal(storage), isTrue);
      storage.failExtraWhen = null;
      expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
      expect(await storage.loadExtra(GameStorage.holdKeyFor(2)), liveJson);
      expect(await storage.loadExtra(GameStorage.holdKey), liveJson);
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isFalse);
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
      expect(await _finalHasCinders(storage, 4), isTrue);
      expect(await director.debugTryPersist(), isTrue);
      expect(await director.restoreDisplacedDeviceSave(), isTrue);
      expect(await _finalHasCinders(storage, 4), isTrue);
      expect(
        await storage.loadExtra(GameStorage.holdKeyFor(2)),
        isNot(liveJson),
      );
    });

    test(
      'boot does not recover a colliding migration over a parked party',
      () async {
        final incoming = _party(life: 500);
        final live = _party(life: 80, adFree: true, cinders: 4);
        final previous = _party(life: 1);
        final parked = _party(life: 77, cinders: 9);
        final incomingJson = GameLogic.exportSaveJson(incoming);
        final liveJson = GameLogic.exportSaveJson(live);
        final previousJson = GameLogic.exportSaveJson(previous);
        final parkedJson = GameLogic.exportSaveJson(parked);
        Future<InMemoryGameStorage> plant() async {
          final storage = InMemoryGameStorage();
          await _plantGlobalSwap(
            storage,
            active: incomingJson,
            staging: incomingJson,
            hold: liveJson,
            displaced: previousJson,
          );
          await storage.writeExtra(
            GameStorage.journalKeyFor(2),
            'swap-publish',
          );
          await storage.writeExtra(GameStorage.displacedKeyFor(2), parkedJson);
          return storage;
        }

        final storage = await plant();
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        expect(director.saveRecoveryAmbiguous, isTrue);
        expect(
          await storage.loadExtra(GameStorage.displacedKeyFor(2)),
          parkedJson,
        );
        expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
        expect(await storage.loadExtra(GameStorage.holdKey), liveJson);
        expect(await storage.loadExtra(GameStorage.displacedKey), previousJson);
        expect(await director.retrySaveRecovery(), isFalse);
        expect(
          await storage.loadExtra(GameStorage.displacedKeyFor(2)),
          parkedJson,
        );
        expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
        expect(
          await storage.loadExtra(GameStorage.displacedKeyFor(2)),
          parkedJson,
        );
        expect(await director.debugTryPersist(), isFalse);

        // The collision itself is the third field. Cuts land on the two
        // copies that precede it. Each fault is in-process, not an OS kill.
        for (var n = 1; n <= 2; n++) {
          for (final kind in ['fail', 'throw-before', 'throw-after']) {
            final cut = await plant();
            cut.armExtraWriteCut(
              failAt: kind == 'fail' ? n : null,
              throwBefore: kind == 'throw-before' ? n : null,
              throwAfter: kind == 'throw-after' ? n : null,
            );
            expect(await SaveSwap.migrateLegacyGlobalJournal(cut), isTrue);
            expect(cut.failNthExtraWrite, isNull, reason: '$kind $n');
            cut.clearExtraWriteCut();
            expect(
              await cut.loadExtra(GameStorage.displacedKeyFor(2)),
              parkedJson,
            );
            final again = GameDirector(cut, enableSpatialLoop: false);
            addTearDown(again.dispose);
            await again.boot();
            expect(again.saveRecoveryBlocked, isTrue, reason: '$kind $n');
            expect(
              await cut.loadExtra(GameStorage.displacedKeyFor(2)),
              parkedJson,
            );
            expect(
              await again.retrySaveRecovery(),
              isFalse,
              reason: '$kind $n',
            );
            expect(
              await cut.loadExtra(GameStorage.displacedKeyFor(2)),
              parkedJson,
            );
            expect(await cut.loadExtra(GameStorage.journalKey), 'swap-publish');
            expect(await cut.loadExtra(GameStorage.holdKey), liveJson);
          }
        }
      },
    );

    test('device-copy cuts keep both parties', () async {
      final current = _party(life: 80, adFree: true, cinders: 4);
      final parked = _party(life: 500);
      final currentJson = GameLogic.exportSaveJson(current);
      final parkedJson = GameLogic.exportSaveJson(parked);
      Future<void> plant(InMemoryGameStorage storage) async {
        await storage.writeActiveRaw(currentJson);
        await storage.writeExtra(GameStorage.displacedKey, parkedJson);
      }

      bool hasParty(Map<String, String> bytes, String json) {
        return bytes.values.contains(json);
      }

      for (var cuts = 1; cuts <= 8; cuts++) {
        final storage = InMemoryGameStorage();
        await plant(storage);
        storage.failNextExtraWrites = cuts;
        await SaveSwap.commitSwap(
          storage: storage,
          newActiveJson: parkedJson,
          newDisplacedJson: currentJson,
        );
        final durable = storage.durableBytes();
        expect(
          hasParty(durable, currentJson),
          isTrue,
          reason: 'bool cut $cuts current',
        );
        expect(
          hasParty(durable, parkedJson),
          isTrue,
          reason: 'bool cut $cuts parked',
        );
        final fresh = InMemoryGameStorage();
        fresh.restoreDurableBytes(durable);
        await SaveSwap.recover(fresh);
        final after = fresh.durableBytes();
        expect(
          hasParty(after, currentJson),
          isTrue,
          reason: 'replay $cuts current',
        );
        expect(
          hasParty(after, parkedJson),
          isTrue,
          reason: 'replay $cuts parked',
        );
      }

      final killed = InMemoryGameStorage();
      await plant(killed);
      killed.killAfterNextActiveDurableWrite = true;
      await SaveSwap.commitSwap(
        storage: killed,
        newActiveJson: parkedJson,
        newDisplacedJson: currentJson,
      );
      final snapshot = killed.bytesAtKill;
      expect(snapshot, isNotNull);
      expect(hasParty(snapshot!, currentJson), isTrue);
      expect(hasParty(snapshot, parkedJson), isTrue);
      final replay = InMemoryGameStorage();
      replay.restoreDurableBytes(snapshot);
      expect(await SaveSwap.recover(replay), isNot(SaveSwapOutcome.unresolved));
      expect(hasParty(replay.durableBytes(), currentJson), isTrue);
      expect(hasParty(replay.durableBytes(), parkedJson), isTrue);
    });

    test('retry stays blocked when the active file cannot be read', () async {
      final storage = InMemoryGameStorage();
      await storage.writeActiveRaw(GameLogic.exportSaveJson(_party(life: 80)));
      storage.reloadThrowsRemaining = 1;
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      storage.debugPlantActiveRaw('not-json');
      expect(await director.retrySaveRecovery(), isFalse);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.state.lifetimeGoldEarned, 80);
      expect(await director.debugTryPersist(), isFalse);
      expect(await storage.loadActiveRaw(), 'not-json');
      await storage.clear();
      expect(await director.retrySaveRecovery(), isFalse);
      expect(director.saveRecoveryBlocked, isTrue);
    });

    test('retry rebuilds a dungeon and hub idle can tick again', () async {
      final storage = InMemoryGameStorage();
      final hub = _party(life: 10);
      final live = _party(life: 80, adFree: true);
      final incoming = GameLogic.enterDungeon(_party(life: 500));
      await storage.writeActiveRaw(GameLogic.exportSaveJson(hub));
      await storage.writeExtra(
        GameStorage.stagingKey,
        GameLogic.exportSaveJson(incoming),
      );
      await storage.writeExtra(
        GameStorage.holdKey,
        GameLogic.exportSaveJson(live),
      );
      await storage.writeExtra(GameStorage.journalKey, 'swap-stage');
      storage.failExtraWhen = (key, value) =>
          key == GameStorage.journalKey && value == 'swap-commit';
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.state.inDungeon, isFalse);
      expect(director.spatial, isNull);
      director.debugStampAway(lastUpdatedAgo: const Duration(seconds: 30));
      final goldWhileBlocked = director.state.gold;
      director.debugTickHubIdle();
      expect(director.state.gold, goldWhileBlocked);
      storage.failExtraWhen = null;
      expect(await director.retrySaveRecovery(), isTrue);
      expect(director.saveRecoveryBlocked, isFalse);
      expect(director.state.inDungeon, isTrue);
      expect(director.spatial, isNotNull);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        )!.metaDepth.adFree,
        isTrue,
      );
    });

    test(
      'a failed local ownership save does not report backup success',
      () async {
        final local = _party(life: 80, cinders: 3, adFree: true);
        final first = _party(life: 10);
        final observed = _party(
          life: 12,
          pass: true,
          purchaseIds: const ['paid-observed'],
        );
        final director = _hold(local);
        addTearDown(director.dispose);
        final storage = director.debugStorage as InMemoryGameStorage;
        var reads = 0;
        GameState? uploaded;
        PlayGamesBridge.debugAccountId = () async => 'player-1';
        PlayGamesBridge.debugLoadCloud = () async {
          reads++;
          return CloudRead.ready(reads == 1 ? first : observed);
        };
        PlayGamesBridge.debugSaveCloud = (state) async {
          uploaded = state;
          return true;
        };
        storage.armFailAfterSuccessfulSaves(1);
        expect(await director.backupToPlayGames(), isFalse);
        expect(uploaded!.metaDepth.paidSeasonPass, isTrue);
        expect(uploaded!.metaDepth.adFree, isTrue);
        expect(director.state.metaDepth.paidSeasonPass, isFalse);
        expect(director.toast, contains('could not store'));
      },
    );

    test('a settings import waits for an in-flight grant', () async {
      final director = _hold(_party(life: 15));
      addTearDown(director.dispose);
      final storage = director.debugStorage as InMemoryGameStorage;
      final release = Completer<void>();
      storage.pauseBeforeNextWrite = release.future;
      final granting = director.debugGrantShopPurchase(
        'ad_free',
        purchaseId: 'import-grant',
      );
      await pumpEventQueue();
      expect(storage.writeEntered, isTrue);
      final importing = director.importSaveJson(
        GameLogic.exportSaveJson(_party(life: 999)),
      );
      release.complete();
      expect(await granting, isTrue);
      expect(await importing, isTrue);
      expect(director.state.lifetimeGoldEarned, 999);
      expect(director.state.metaDepth.adFree, isTrue);
      expect(
        director.state.metaDepth.grantedShopPurchaseIds,
        contains('import-grant'),
      );
      final disk = await storage.load();
      expect(disk!.lifetimeGoldEarned, 999);
      expect(disk.metaDepth.adFree, isTrue);
      expect(disk.metaDepth.grantedShopPurchaseIds, contains('import-grant'));
    });

    testWidgets('cold boot with the intro shows recovery before play', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = InMemoryGameStorage();
      await storage.writeActiveRaw(GameLogic.exportSaveJson(_party(life: 80)));
      storage.reloadThrowsRemaining = 1;
      final director = GameDirector(storage, enableSpatialLoop: false);
      await tester.pumpWidget(
        MyApp(director: director, autoStartLoop: false, showIntro: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      expect(find.text('RETRY'), findsOneWidget);
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('SAVE RECOVERY'), findsNothing);
      expect(find.text('ENTER DUNGEON'), findsOneWidget);
      expect(director.saveRecoveryBlocked, isFalse);
    });
  });
}

class _Slot0Selection {
  _Slot0Selection({
    required this.storage,
    required this.slot0,
    required this.owner,
    required this.held,
  });

  final InMemoryGameStorage storage;
  final String slot0;
  final String owner;
  final String held;
}

/// Active selection is slot 0. The global journal's bytes belong to slot 2.
Future<_Slot0Selection> _plantSlot0Selection({required String phase}) async {
  final storage = InMemoryGameStorage();
  final slot0 = GameLogic.exportSaveJson(
    _party(life: 42, adFree: true, cinders: 11, purchaseIds: const ['d0-only']),
  );
  final owner = GameLogic.exportSaveJson(_party(life: 500));
  final held = GameLogic.exportSaveJson(
    _party(life: 80, adFree: true, cinders: 4),
  );
  await _writeSlot(storage, 2, owner);
  await _writeSlot(storage, 0, slot0);
  await storage.setActiveSlot(0);
  await storage.writeExtra(GameStorage.stagingKey, owner);
  await storage.writeExtra(GameStorage.holdKey, held);
  await storage.writeExtra(
    GameStorage.displacedKey,
    GameLogic.exportSaveJson(_party(life: 1)),
  );
  await storage.writeExtra(GameStorage.journalKey, phase);
  return _Slot0Selection(
    storage: storage,
    slot0: slot0,
    owner: owner,
    held: held,
  );
}

Future<void> _writeSlot(
  InMemoryGameStorage storage,
  int slot,
  String json,
) async {
  await storage.setActiveSlot(slot);
  await storage.writeActiveRaw(json);
}

bool _rawHas(String? raw, String marker) => raw != null && raw.contains(marker);

Future<bool> _slotFinalHasCinders(
  InMemoryGameStorage storage,
  int slot,
  int cinders,
) async {
  for (final raw in [
    await storage.loadSlotRaw(slot),
    await storage.loadExtra(GameStorage.displacedKeyFor(slot)),
  ]) {
    final imported = raw == null ? null : GameLogic.importSaveJson(raw);
    if (imported?.metaDepth.cinders == cinders) return true;
  }
  return false;
}

Future<void> _plantGlobalSwap(
  InMemoryGameStorage storage, {
  required String active,
  required String staging,
  required String hold,
  required String displaced,
}) async {
  await storage.setActiveSlot(2);
  await storage.writeActiveRaw(active);
  await storage.writeExtra(GameStorage.stagingKey, staging);
  await storage.writeExtra(GameStorage.holdKey, hold);
  await storage.writeExtra(GameStorage.displacedKey, displaced);
  await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
}

Future<bool> _durableHas(InMemoryGameStorage storage, String json) async {
  const keys = <String>[
    GameStorage.stagingKey,
    GameStorage.holdKey,
    GameStorage.displacedKey,
  ];
  if (await storage.loadActiveRaw() == json) return true;
  if (await storage.loadSlotRaw(2) == json) return true;
  for (final key in keys) {
    if (await storage.loadExtra(key) == json) return true;
    if (await storage.loadExtra('${key}_2') == json) return true;
  }
  return false;
}

/// A party that is not yet in the active file or the parked file still needs
/// a journal. Deleting the last marker is the loss the next device copy hits.
Future<void> _expectOwnerMarkerIfHoldIsOnlyCopy(
  InMemoryGameStorage storage,
  String json, {
  required String reason,
}) async {
  final active = await storage.loadSlotRaw(2);
  final parked = await storage.loadExtra(GameStorage.displacedKeyFor(2));
  if (active == json || parked == json) return;
  final global = await storage.loadExtra(GameStorage.journalKey);
  final scoped = await storage.loadExtra(GameStorage.journalKeyFor(2));
  expect(global != null || scoped != null, isTrue, reason: reason);
}

Future<bool> _finalHasCinders(InMemoryGameStorage storage, int cinders) async {
  for (final raw in [
    await storage.loadSlotRaw(2),
    await storage.loadExtra(GameStorage.displacedKeyFor(2)),
  ]) {
    final imported = raw == null ? null : GameLogic.importSaveJson(raw);
    if (imported?.metaDepth.cinders == cinders) return true;
  }
  return false;
}

GameState _party({
  int life = 0,
  int floor = 0,
  int cinders = 0,
  int tickets = 0,
  bool adFree = false,
  bool pass = false,
  bool optIn = false,
  List<String> purchaseIds = const [],
}) {
  final base = GameLogic.createInitialState();
  return base.copyWith(
    lifetimeGoldEarned: life,
    highestFloorCleared: floor,
    metaDepth: base.metaDepth.copyWith(
      cinders: cinders,
      adTickets: tickets,
      adFree: adFree,
      paidSeasonPass: pass,
      playGamesOptIn: optIn,
      grantedShopPurchaseIds: purchaseIds,
    ),
  );
}

GameDirector _hold(GameState state) {
  final director = GameDirector.preview(initialState: state);
  director.debugHoldSave(state);
  return director;
}

class _RejectingPrefsStore extends InMemorySharedPreferencesStore {
  _RejectingPrefsStore() : super.empty();

  bool rejectWrites = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (rejectWrites) return false;
    return super.setValue(valueType, key, value);
  }
}
