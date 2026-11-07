import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/main.dart';
import 'package:idle_party/core/equipment_factory.dart';
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
          if (key == GameStorage.journalKey && value == 'swap-publish@0') {
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
        await storage.writeExtra(GameStorage.journalKey, 'swap-publish@0');
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
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish@0');
      storage.throwAfterDeletingKey = GameStorage.holdKey;
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.unresolved);
      expect(await storage.loadExtra(GameStorage.stagingKey), isNull);
      expect(await storage.loadExtra(GameStorage.holdKey), isNull);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish@0');
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
        await storage.writeExtra(GameStorage.journalKey, 'swap-commit@0');
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
      expect(find.text('EXPORT RECORDS'), findsNothing);
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      expect(tries, 1);
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
    });

    testWidgets('an unmatched copy offers export instead of retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SaveRecoveryGate(
            message:
                'Saving is paused. An unfinished copy could not be matched to one file. It was left untouched.',
            onRetry: () async => false,
            onExport: () async {},
            safeSlots: const [4],
            onOpenSlot: (_) async {},
          ),
        ),
      );
      expect(find.text('RETRY'), findsNothing);
      expect(find.text('EXPORT RECORDS'), findsOneWidget);
      expect(find.text('OPEN SLOT 5'), findsOneWidget);
      expect(find.textContaining('cannot choose an owner'), findsOneWidget);
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

    test(
      'title, picker, and recovery START ignore a cache-only write',
      () async {
        final harness = await _installRejectingPrefs();
        final store = harness.store;
        final prefs = harness.prefs;
        final storage = SharedPreferencesGameStorage(preferences: prefs);
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();

        for (final mode in ['false', 'throw']) {
          director.armNewGameSlot(0);
          store.rejectWrites = mode == 'false';
          store.throwWrites = mode == 'throw';
          expect(
            await director.startNewGame(
              HeroSpecs.starterUnlocked,
              partyName: 'Cave Company',
            ),
            isFalse,
            reason: mode,
          );
          expect(director.hasExistingSave, isFalse, reason: mode);
          expect(director.state.inDungeon, isFalse, reason: mode);
          await prefs.reload();
          expect(
            prefs.getString('idle_party_save_slot_0'),
            isNull,
            reason: mode,
          );
        }
        store.rejectWrites = false;
        store.throwWrites = false;
        director.armNewGameSlot(0);
        expect(
          await director.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Cave Company',
          ),
          isTrue,
        );
        await prefs.reload();
        expect(
          GameLogic.importSaveJson(
            prefs.getString('idle_party_save_slot_0')!,
          )!.partyName,
          'Cave Company',
        );

        store.rejectMirror = true;
        final mirrorDirector = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(mirrorDirector.dispose);
        await mirrorDirector.boot();
        mirrorDirector.armNewGameSlot(1);
        expect(
          await mirrorDirector.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Mirror Split',
          ),
          isTrue,
        );
        await prefs.reload();
        expect(
          GameLogic.importSaveJson(
            prefs.getString('idle_party_save_slot_1')!,
          )!.partyName,
          'Mirror Split',
        );
        expect(
          prefs.getString('idle_party_save_v2'),
          isNot(contains('Mirror Split')),
        );
      },
    );

    test(
      'recovery START ignores a cache-only write and a later retry lands',
      () async {
        final harness = await _installRejectingPrefs();
        final store = harness.store;
        final prefs = harness.prefs;
        final kept = GameLogic.exportSaveJson(
          _party(life: 40, adFree: true, purchaseIds: const ['slot2-keep']),
        );
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 2);
        await prefs.setString('idle_party_save_slot_2', kept);
        await prefs.setString('idle_party_save_journal', 'swap-stage');
        await prefs.setString(
          'idle_party_save_staging',
          GameLogic.exportSaveJson(_party(life: 1)),
        );
        await prefs.setString(
          'idle_party_save_hold',
          GameLogic.exportSaveJson(_party(life: 2)),
        );
        final director = GameDirector(
          SharedPreferencesGameStorage(preferences: prefs),
          enableSpatialLoop: false,
        );
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        expect(
          await director.openSafeRecoverySlot(4),
          RecoverySlotOpen.needsNewGame,
        );
        for (final mode in ['false', 'throw']) {
          store.rejectWrites = mode == 'false';
          store.throwWrites = mode == 'throw';
          expect(
            await director.startNewGame(
              HeroSpecs.starterUnlocked,
              partyName: 'Ember',
            ),
            isFalse,
            reason: mode,
          );
          expect(director.saveRecoveryBlocked, isTrue, reason: mode);
          await prefs.reload();
          expect(
            prefs.getString('idle_party_save_slot_4'),
            isNull,
            reason: mode,
          );
          expect(prefs.getString('idle_party_save_slot_2'), kept, reason: mode);
          expect(prefs.getString('idle_party_save_journal'), 'swap-stage');
        }
        store.rejectWrites = false;
        store.throwWrites = false;
        expect(
          await director.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Ember',
          ),
          isTrue,
        );
        await prefs.reload();
        expect(
          GameLogic.importSaveJson(
            prefs.getString('idle_party_save_slot_4')!,
          )!.partyName,
          'Ember',
        );
        expect(prefs.getString('idle_party_save_slot_2'), kept);
        SharedPreferences.resetStatic();
        final reboot = GameDirector(
          SharedPreferencesGameStorage(),
          enableSpatialLoop: false,
        );
        addTearDown(reboot.dispose);
        await reboot.boot();
        final again = await SharedPreferences.getInstance();
        expect(
          GameLogic.importSaveJson(
            again.getString('idle_party_save_slot_4')!,
          )!.partyName,
          'Ember',
        );
        expect(again.getString('idle_party_save_slot_2'), kept);
        expect(again.getString('idle_party_save_journal'), 'swap-stage');
      },
    );

    test(
      'a failed boot read keeps the local party out of cloud restore',
      () async {
        final harness = await _installRejectingPrefs();
        final store = harness.store;
        final prefs = harness.prefs;
        final local = _party(
          life: 4242,
          adFree: true,
          purchaseIds: const ['GPA.local'],
        );
        final json = GameLogic.exportSaveJson(local);
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 0);
        await prefs.setString('idle_party_save_slot_0', json);
        store.failGets = 1;
        SharedPreferences.resetStatic();
        final director = GameDirector(
          SharedPreferencesGameStorage(),
          enableSpatialLoop: false,
        );
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        expect(director.hasExistingSave, isFalse);
        PlayGamesBridge.debugSignIn = () async => true;
        PlayGamesBridge.debugLoadCloud = () async =>
            CloudRead.ready(_party(life: 9, purchaseIds: const ['GPA.cloud']));
        expect(await director.restoreCloudOnTitle(), isFalse);
        expect(await director.backupToPlayGames(), isFalse);
        expect(await director.keepDeviceAndCloudOwnership(local), isFalse);
        SharedPreferences.resetStatic();
        final mid = await SharedPreferences.getInstance();
        expect(mid.getString('idle_party_save_slot_0'), json);
        expect(mid.getString('idle_party_displaced_save'), isNull);
        expect(await director.retrySaveRecovery(), isTrue);
        expect(director.saveRecoveryBlocked, isFalse);
        expect(director.state.lifetimeGoldEarned, 4242);
        expect(director.state.metaDepth.adFree, isTrue);
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          contains('GPA.local'),
        );
        SharedPreferences.resetStatic();
        final reboot = GameDirector(
          SharedPreferencesGameStorage(),
          enableSpatialLoop: false,
        );
        addTearDown(reboot.dispose);
        await reboot.boot();
        expect(reboot.saveRecoveryBlocked, isFalse);
        expect(reboot.state.lifetimeGoldEarned, 4242);
        expect(reboot.state.metaDepth.adFree, isTrue);
        expect(
          reboot.state.metaDepth.grantedShopPurchaseIds,
          contains('GPA.local'),
        );
      },
    );

    test(
      'an unreadable file stays put and an empty phone can restore',
      () async {
        final harness = await _installRejectingPrefs();
        final prefs = harness.prefs;
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 0);
        await prefs.setString('idle_party_save_slot_0', '{not-json');
        final director = GameDirector(
          SharedPreferencesGameStorage(preferences: prefs),
          enableSpatialLoop: false,
        );
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        PlayGamesBridge.debugSignIn = () async => true;
        PlayGamesBridge.debugLoadCloud = () async =>
            CloudRead.ready(_party(life: 9, purchaseIds: const ['GPA.cloud']));
        expect(await director.restoreCloudOnTitle(), isFalse);
        expect(prefs.getString('idle_party_save_slot_0'), '{not-json');
        expect(prefs.getString('idle_party_save_v2_corrupt'), isNull);
        expect(await director.retrySaveRecovery(), isFalse);
        expect(prefs.getString('idle_party_save_slot_0'), '{not-json');

        final empty = _RejectingPrefsStore();
        final previous = SharedPreferencesStorePlatform.instance;
        SharedPreferencesStorePlatform.instance = empty;
        SharedPreferences.resetStatic();
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = previous;
        });
        empty.failGets = 1;
        final fresh = GameDirector(
          SharedPreferencesGameStorage(),
          enableSpatialLoop: false,
        );
        addTearDown(fresh.dispose);
        await fresh.boot();
        expect(fresh.saveRecoveryBlocked, isTrue);
        expect(await fresh.restoreCloudOnTitle(), isFalse);
        expect(await fresh.retrySaveRecovery(), isTrue);
        expect(fresh.hasExistingSave, isFalse);
        expect(fresh.saveRecoveryBlocked, isFalse);
        PlayGamesBridge.debugSignIn = () async => true;
        PlayGamesBridge.debugLoadCloud = () async =>
            CloudRead.ready(_party(life: 9, purchaseIds: const ['GPA.cloud']));
        expect(await fresh.restoreCloudOnTitle(), isTrue);
        expect(
          fresh.state.metaDepth.grantedShopPurchaseIds,
          contains('GPA.cloud'),
        );
      },
    );

    testWidgets('title PLAY and CUSTOMIZE stay on setup when the cache lies', (
      tester,
    ) async {
      final harness = await _installRejectingPrefs();
      final store = harness.store;
      final director = GameDirector(
        SharedPreferencesGameStorage(preferences: harness.prefs),
        enableSpatialLoop: false,
      );
      await _pumpRecoveryApp(tester, director, showIntro: true);
      expect(find.text('PLAY'), findsOneWidget);
      store.rejectWrites = true;
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      await harness.prefs.reload();
      expect(harness.prefs.getString('idle_party_save_slot_0'), isNull);
      store.rejectWrites = false;
      store.throwWrites = true;
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('PLAY'), findsOneWidget);
      await harness.prefs.reload();
      expect(harness.prefs.getString('idle_party_save_slot_0'), isNull);
      store.throwWrites = false;
      await tester.tap(find.text('CUSTOMIZE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(find.byType(TextField), 'Ember Test');
      await tester.pump();
      store.rejectWrites = true;
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('START'), findsOneWidget);
      await harness.prefs.reload();
      expect(harness.prefs.getString('idle_party_save_slot_0'), isNull);
      store.rejectWrites = false;
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(director.hasExistingSave, isTrue);
      await _disposeRecoveryApp(tester);
    });

    testWidgets('recovery START stays on setup when the cache lies', (
      tester,
    ) async {
      final harness = await _installRejectingPrefs();
      final store = harness.store;
      final prefs = harness.prefs;
      final kept = GameLogic.exportSaveJson(
        _party(life: 40, adFree: true, purchaseIds: const ['slot2-keep']),
      );
      await prefs.setBool('idle_party_slots_ready', true);
      await prefs.setInt('idle_party_active_slot', 2);
      await prefs.setString('idle_party_save_slot_2', kept);
      await prefs.setString('idle_party_save_journal', 'swap-stage');
      await prefs.setString(
        'idle_party_save_staging',
        GameLogic.exportSaveJson(_party(life: 1)),
      );
      await prefs.setString(
        'idle_party_save_hold',
        GameLogic.exportSaveJson(_party(life: 2)),
      );
      final director = GameDirector(
        SharedPreferencesGameStorage(preferences: prefs),
        enableSpatialLoop: false,
      );
      await _pumpRecoveryApp(tester, director);
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(find.text('RESTORE'), findsNothing);
      await tester.ensureVisible(find.text('OPEN SLOT 5'));
      await tester.tap(find.text('OPEN SLOT 5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Ember Test');
      await tester.pump();
      store.rejectWrites = true;
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('START'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      await prefs.reload();
      expect(prefs.getString('idle_party_save_slot_4'), isNull);
      expect(prefs.getString('idle_party_save_slot_2'), kept);
      store.rejectWrites = false;
      store.throwWrites = true;
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('START'), findsOneWidget);
      await prefs.reload();
      expect(prefs.getString('idle_party_save_slot_4'), isNull);
      store.throwWrites = false;
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(director.hasExistingSave, isTrue);
      expect(director.state.partyName, 'Ember Test');
      await _disposeRecoveryApp(tester);
      SharedPreferences.resetStatic();
      final reboot = GameDirector(
        SharedPreferencesGameStorage(),
        enableSpatialLoop: false,
      );
      try {
        await reboot.boot();
        final again = await SharedPreferences.getInstance();
        expect(
          GameLogic.importSaveJson(
            again.getString('idle_party_save_slot_4')!,
          )!.partyName,
          'Ember Test',
        );
        expect(again.getString('idle_party_save_slot_2'), kept);
      } finally {
        reboot.dispose();
      }
    });

    test('a parse probe does not move the combat random', () {
      final raw = GameLogic.exportSaveJson(GameLogic.createInitialState());
      final saved = GameLogic.random;
      final gear = EquipmentFactory.random;
      GameLogic.random = Random(123);
      EquipmentFactory.random = GameLogic.random;
      final expected = Random(123).nextInt(1000000);
      try {
        expect(
          GameLogic.importSaveJson(raw, keepCombatRandom: true),
          isNotNull,
        );
        expect(GameLogic.random.nextInt(1000000), expected);
      } finally {
        GameLogic.random = saved;
        EquipmentFactory.random = gear;
      }
    });

    test(
      'a failed native commit does not start a game or acknowledge a purchase',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final store = _NativeCommitStore();
        SharedPreferencesStorePlatform.instance = store;
        SharedPreferences.resetStatic();
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = previous;
          SharedPreferences.resetStatic();
        });
        final prefs = await SharedPreferences.getInstance();
        final original = _party(
          life: 80,
          adFree: true,
          purchaseIds: const ['GPA.old'],
        ).copyWith(partyName: 'Disk Party');
        final originalJson = GameLogic.exportSaveJson(original);
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 0);
        await prefs.setString('idle_party_save_slot_0', originalJson);
        await prefs.setString('idle_party_save_v2', originalJson);
        final director = GameDirector(
          SharedPreferencesGameStorage(preferences: prefs),
          enableSpatialLoop: false,
        );
        addTearDown(director.dispose);
        await director.boot();
        expect(director.state.partyName, 'Disk Party');
        final baselineSlot = prefs.getString('idle_party_save_slot_0');
        final baselineMirror = prefs.getString('idle_party_save_v2');
        store.failStringCommit = true;
        expect(
          await director.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Memory Only',
          ),
          isFalse,
        );
        expect(director.hasExistingSave, isTrue);
        expect(director.state.partyName, 'Disk Party');
        expect(director.state.inDungeon, isFalse);
        await prefs.reload();
        // The false commit is followed by a restore of the previous bytes
        // into the map, so a later successful key cannot flush the rejected
        // party. Disk is checked after restartFromDisk.
        expect(
          prefs.getString('idle_party_save_slot_0'),
          isNot(contains('Memory Only')),
        );
        await store.restartFromDisk();
        SharedPreferences.resetStatic();
        final diskPrefs = await SharedPreferences.getInstance();
        expect(diskPrefs.getString('idle_party_save_slot_0'), baselineSlot);
        expect(diskPrefs.getString('idle_party_save_v2'), baselineMirror);

        store.failStringCommit = false;
        final playing = GameDirector(
          SharedPreferencesGameStorage(preferences: diskPrefs),
          enableSpatialLoop: false,
        );
        addTearDown(playing.dispose);
        await playing.boot();
        expect(playing.state.partyName, 'Disk Party');
        store.failStringCommit = true;
        final granted = await playing.debugGrantShopPurchase(
          'cinder_pouch',
          purchaseId: 'GPA.new',
        );
        expect(granted, isFalse);
        expect(playing.state.metaDepth.grantedShopPurchaseIds, ['GPA.old']);
        expect(playing.state.metaDepth.cinders, 0);
        await diskPrefs.reload();
        expect(
          diskPrefs.getString('idle_party_save_slot_0'),
          isNot(contains('GPA.new')),
        );
        await store.restartFromDisk();
        SharedPreferences.resetStatic();
        final after = await SharedPreferences.getInstance();
        final durable = GameLogic.importSaveJson(
          after.getString('idle_party_save_slot_0')!,
        )!;
        expect(durable.partyName, 'Disk Party');
        expect(durable.metaDepth.grantedShopPurchaseIds, ['GPA.old']);
        expect(durable.metaDepth.adFree, isTrue);
        expect(
          after.getString('idle_party_save_v2'),
          isNot(contains('GPA.new')),
        );
      },
    );

    test(
      'a stuck native receipt is not adopted by retry or acknowledged',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final store = _NativeCommitStore();
        SharedPreferencesStorePlatform.instance = store;
        SharedPreferences.resetStatic();
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = previous;
          SharedPreferences.resetStatic();
        });
        final prefs = await SharedPreferences.getInstance();
        final original = _party(
          life: 80,
          adFree: true,
          purchaseIds: const ['GPA.old'],
        ).copyWith(partyName: 'Disk Party');
        final originalJson = GameLogic.exportSaveJson(original);
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 0);
        await prefs.setString('idle_party_save_slot_0', originalJson);
        await prefs.setString('idle_party_save_v2', originalJson);
        final storage = SharedPreferencesGameStorage(preferences: prefs);
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        store.stickFailedString = true;
        expect(
          await director.debugGrantShopPurchase(
            'cinder_pouch',
            purchaseId: 'GPA.stuck',
          ),
          isFalse,
        );
        expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.old']);
        expect(director.state.metaDepth.cinders, 0);
        expect(storage.hasUnprovenWrite, isTrue);
        await prefs.reload();
        expect(
          prefs.getString('idle_party_save_slot_0'),
          contains('GPA.stuck'),
        );
        expect(await director.localReadBlocksMutation(), isTrue);
        expect(await director.retrySaveRecovery(), isFalse);
        expect(director.saveRecoveryBlocked, isTrue);
        expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.old']);
        expect(
          await director.debugGrantShopPurchase(
            'cinder_pouch',
            purchaseId: 'GPA.stuck',
          ),
          isFalse,
        );
        await storage.setActiveSlot(3);
        await store.restartFromDisk();
        SharedPreferences.resetStatic();
        final disk = await SharedPreferences.getInstance();
        expect(disk.getInt('idle_party_active_slot'), 0);
        expect(
          disk.getString('idle_party_save_slot_0'),
          isNot(contains('GPA.stuck')),
        );
        expect(
          disk.getString('idle_party_save_v2'),
          isNot(contains('GPA.stuck')),
        );

        store.stickFailedString = false;
        store.releaseStuckString();
        final playing = GameDirector(
          SharedPreferencesGameStorage(preferences: disk),
          enableSpatialLoop: false,
        );
        addTearDown(playing.dispose);
        await playing.boot();
        expect(playing.state.metaDepth.grantedShopPurchaseIds, ['GPA.old']);
        expect(
          await playing.debugGrantShopPurchase(
            'cinder_pouch',
            purchaseId: 'GPA.stuck',
          ),
          isTrue,
        );
        await store.restartFromDisk();
        SharedPreferences.resetStatic();
        final confirmed = await SharedPreferences.getInstance();
        final durable = GameLogic.importSaveJson(
          confirmed.getString('idle_party_save_slot_0')!,
        )!;
        expect(durable.metaDepth.grantedShopPurchaseIds, contains('GPA.stuck'));
        expect(durable.metaDepth.adFree, isTrue);
      },
    );

    test(
      'an unproven slot change does not overwrite the other party',
      () async {
        final previous = SharedPreferencesStorePlatform.instance;
        final store = _NativeCommitStore();
        SharedPreferencesStorePlatform.instance = store;
        SharedPreferences.resetStatic();
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = previous;
          SharedPreferences.resetStatic();
        });
        final prefs = await SharedPreferences.getInstance();
        final slot0 = _party(
          life: 80,
          adFree: true,
          purchaseIds: const ['GPA.slot0'],
        ).copyWith(partyName: 'Slot Zero');
        final slot1 = _party(
          life: 11,
          purchaseIds: const ['GPA.slot1'],
        ).copyWith(partyName: 'Slot One');
        final slot0Json = GameLogic.exportSaveJson(slot0);
        final slot1Json = GameLogic.exportSaveJson(slot1);
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 0);
        await prefs.setString('idle_party_save_slot_0', slot0Json);
        await prefs.setString('idle_party_save_slot_1', slot1Json);
        await prefs.setString('idle_party_save_v2', slot0Json);
        final storage = SharedPreferencesGameStorage(preferences: prefs);
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        final kept0 = prefs.getString('idle_party_save_slot_0');
        final kept1 = prefs.getString('idle_party_save_slot_1');
        store.stickFailedString = true;
        expect(
          await director.debugGrantShopPurchase(
            'cinder_pouch',
            purchaseId: 'GPA.stuck',
          ),
          isFalse,
        );
        expect(storage.hasUnprovenWrite, isTrue);
        expect(storage.activeSlotIndex, 0);
        expect(director.activeSaveSlot, 0);
        await storage.setActiveSlot(1);
        expect(storage.activeSlotIndex, 0);
        expect(prefs.getInt('idle_party_active_slot'), 0);
        expect(director.activeSaveSlot, 0);
        final imported = GameLogic.exportSaveJson(
          _party(
            life: 3,
            purchaseIds: const ['GPA.import'],
          ).copyWith(partyName: 'Imported'),
        );
        await director.armImportSlot(1);
        expect(director.activeSaveSlot, 0);
        expect(storage.activeSlotIndex, 0);
        expect(await director.importSaveJson(imported), isFalse);
        expect(director.activeSaveSlot, 0);
        expect(
          prefs.getString('idle_party_save_slot_0'),
          isNot(contains('Imported')),
        );
        expect(prefs.getString('idle_party_save_slot_1'), kept1);
        expect(await director.openSaveSlot(1), isFalse);
        expect(director.activeSaveSlot, 0);
        expect(storage.activeSlotIndex, 0);
        expect(prefs.getString('idle_party_save_slot_1'), kept1);
        expect(await director.localReadBlocksMutation(), isTrue);
        expect(director.activeSaveSlot, 0);
        expect(storage.activeSlotIndex, 0);
        expect(await director.retrySaveRecovery(), isFalse);
        expect(director.saveRecoveryBlocked, isTrue);
        store.stickFailedString = false;
        store.releaseStuckString();
        expect(await director.retrySaveRecovery(), isTrue);
        expect(director.activeSaveSlot, 0);
        expect(storage.activeSlotIndex, 0);
        expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.slot0']);
        await store.restartFromDisk();
        SharedPreferences.resetStatic();
        final disk = await SharedPreferences.getInstance();
        expect(disk.getInt('idle_party_active_slot'), 0);
        expect(disk.getString('idle_party_save_slot_1'), kept1);
        expect(
          disk.getString('idle_party_save_slot_0'),
          isNot(contains('GPA.stuck')),
        );
        expect(
          disk.getString('idle_party_save_slot_0'),
          isNot(contains('Imported')),
        );
        expect(disk.getString('idle_party_save_slot_0'), contains('GPA.slot0'));
        expect(kept0, isNotNull);
      },
    );

    test('a failed title import restores the selected slot', () async {
      final harness = await _installRejectingPrefs();
      final prefs = harness.prefs;
      final party = _party(
        life: 40,
        adFree: true,
        purchaseIds: const ['GPA.slot0'],
      ).copyWith(partyName: 'Slot Zero');
      final json = GameLogic.exportSaveJson(party);
      await prefs.setBool('idle_party_slots_ready', true);
      await prefs.setInt('idle_party_active_slot', 0);
      await prefs.setString('idle_party_save_slot_0', json);
      await prefs.setString('idle_party_save_v2', json);
      final director = GameDirector(
        SharedPreferencesGameStorage(preferences: prefs),
        enableSpatialLoop: false,
      );
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isFalse);
      final kept = prefs.getString('idle_party_save_slot_0');
      await director.armImportSlot(1);
      expect(director.activeSaveSlot, 1);
      expect(await director.importSaveJson('{not-json'), isFalse);
      expect(director.activeSaveSlot, 0);
      expect(director.hasExistingSave, isTrue);
      expect(director.state.partyName, 'Slot Zero');
      expect(prefs.getInt('idle_party_active_slot'), 0);
      expect(prefs.getString('idle_party_save_slot_1'), anyOf(isNull, isEmpty));
      expect(prefs.getString('idle_party_save_slot_0'), kept);

      final again = GameDirector(
        SharedPreferencesGameStorage(preferences: prefs),
        enableSpatialLoop: false,
      );
      addTearDown(again.dispose);
      await again.boot();
      expect(again.saveRecoveryBlocked, isFalse);
      expect(again.activeSaveSlot, 0);
      expect(again.state.partyName, 'Slot Zero');
      expect(again.state.metaDepth.adFree, isTrue);
      expect(again.state.metaDepth.grantedShopPurchaseIds, ['GPA.slot0']);
    });

    test('an empty selection can still open a healthy slot', () async {
      final harness = await _installRejectingPrefs();
      final prefs = harness.prefs;
      final party = _party(
        life: 22,
        purchaseIds: const ['GPA.keep'],
      ).copyWith(partyName: 'Kept Party');
      final json = GameLogic.exportSaveJson(party);
      await prefs.setBool('idle_party_slots_ready', true);
      await prefs.setInt('idle_party_active_slot', 1);
      await prefs.setString('idle_party_save_slot_0', json);
      await prefs.setString('idle_party_save_v2', json);
      final director = GameDirector(
        SharedPreferencesGameStorage(preferences: prefs),
        enableSpatialLoop: false,
      );
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.safeRecoverySlots, contains(0));
      expect(await director.openSafeRecoverySlot(0), RecoverySlotOpen.ready);
      expect(director.saveRecoveryBlocked, isFalse);
      expect(director.activeSaveSlot, 0);
      expect(director.state.partyName, 'Kept Party');
      expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.keep']);
      final again = GameDirector(
        SharedPreferencesGameStorage(preferences: prefs),
        enableSpatialLoop: false,
      );
      addTearDown(again.dispose);
      await again.boot();
      expect(again.saveRecoveryBlocked, isFalse);
      expect(again.state.partyName, 'Kept Party');
    });

    test('a journaled slot is not a healthy recovery target', () async {
      final harness = await _installRejectingPrefs();
      final prefs = harness.prefs;
      final kept = _party(
        life: 22,
        purchaseIds: const ['GPA.keep'],
      ).copyWith(partyName: 'Kept Party');
      final owned = _party(
        life: 30,
        purchaseIds: const ['GPA.owned'],
      ).copyWith(partyName: 'Owned Party');
      final incoming = _party(
        life: 4,
        purchaseIds: const ['GPA.incoming'],
      ).copyWith(partyName: 'Incoming');
      final held = _party(
        life: 8,
        purchaseIds: const ['GPA.held'],
      ).copyWith(partyName: 'Held');
      final keptJson = GameLogic.exportSaveJson(kept);
      final ownedJson = GameLogic.exportSaveJson(owned);
      await prefs.setBool('idle_party_slots_ready', true);
      await prefs.setInt('idle_party_active_slot', 1);
      await prefs.setString('idle_party_save_slot_0', keptJson);
      await prefs.setString('idle_party_save_v2', keptJson);
      await prefs.setString('idle_party_save_slot_2', ownedJson);
      await prefs.setString(GameStorage.journalKeyFor(2), 'swap-stage@2');
      await prefs.setString(
        GameStorage.stagingKeyFor(2),
        GameLogic.exportSaveJson(incoming),
      );
      await prefs.setString(
        GameStorage.holdKeyFor(2),
        GameLogic.exportSaveJson(held),
      );
      final director = GameDirector(
        SharedPreferencesGameStorage(preferences: prefs),
        enableSpatialLoop: false,
      );
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.safeRecoverySlots, contains(0));
      expect(director.safeRecoverySlots, isNot(contains(2)));
      expect(await director.openSafeRecoverySlot(2), RecoverySlotOpen.refused);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(
        await director.debugGrantShopPurchase(
          'cinder_pouch',
          purchaseId: 'GPA.fresh',
        ),
        isFalse,
      );
      expect(prefs.getString('idle_party_save_slot_2'), ownedJson);
      expect(prefs.getString(GameStorage.journalKeyFor(2)), 'swap-stage@2');
      expect(await director.openSafeRecoverySlot(0), RecoverySlotOpen.ready);
      expect(
        await director.debugGrantShopPurchase(
          'cinder_pouch',
          purchaseId: 'GPA.fresh',
        ),
        isTrue,
      );
      final again = GameDirector(
        SharedPreferencesGameStorage(preferences: prefs),
        enableSpatialLoop: false,
      );
      addTearDown(again.dispose);
      await again.boot();
      expect(again.saveRecoveryBlocked, isFalse);
      expect(again.activeSaveSlot, 0);
      expect(
        again.state.metaDepth.grantedShopPurchaseIds,
        contains('GPA.keep'),
      );
      expect(
        again.state.metaDepth.grantedShopPurchaseIds,
        contains('GPA.fresh'),
      );
      expect(prefs.getString('idle_party_save_slot_2'), ownedJson);
      expect(prefs.getString(GameStorage.journalKeyFor(2)), 'swap-stage@2');
      expect(
        prefs.getString('idle_party_save_slot_2'),
        isNot(contains('GPA.fresh')),
      );
      expect(
        prefs.getString('idle_party_save_slot_2'),
        isNot(contains('GPA.incoming')),
      );
    });

    test(
      'a valid JSON save that does not parse stays in place with its mirror',
      () async {
        final harness = await _installRejectingPrefs();
        final prefs = harness.prefs;
        final healthy = _party(
          life: 77,
          adFree: true,
          purchaseIds: const ['GPA.mirror'],
        ).copyWith(partyName: 'Healthy Mirror');
        final healthyJson = GameLogic.exportSaveJson(healthy);
        final broken = jsonDecode(healthyJson) as Map<String, dynamic>;
        broken['lastUpdated'] = 'not-a-date';
        final brokenJson = jsonEncode(broken);
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 0);
        await prefs.setString('idle_party_save_slot_0', brokenJson);
        await prefs.setString('idle_party_save_v2', healthyJson);
        final director = GameDirector(
          SharedPreferencesGameStorage(preferences: prefs),
          enableSpatialLoop: false,
        );
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        expect(director.hasExistingSave, isFalse);
        expect(prefs.getString('idle_party_save_slot_0'), brokenJson);
        expect(prefs.getString('idle_party_save_v2'), healthyJson);
        expect(prefs.getString('idle_party_save_v2_corrupt'), isNull);
        expect(prefs.getString('idle_party_save_slot_0_corrupt'), isNull);
        PlayGamesBridge.debugSignIn = () async => true;
        PlayGamesBridge.debugLoadCloud = () async =>
            CloudRead.ready(_party(life: 1, purchaseIds: const ['GPA.cloud']));
        expect(await director.restoreCloudOnTitle(), isFalse);
        expect(prefs.getString('idle_party_save_slot_0'), brokenJson);
        expect(prefs.getString('idle_party_save_v2'), healthyJson);
        expect(await director.retrySaveRecovery(), isFalse);
        expect(prefs.getString('idle_party_save_v2'), contains('GPA.mirror'));
        final records = await director.exportRecoveryRecords();
        expect(records, contains('not-a-date'));
        expect(records, contains('GPA.mirror'));

        harness.store.failRemoves = true;
        final direct = SharedPreferencesGameStorage(preferences: prefs);
        await expectLater(direct.load(), throwsStateError);
        await prefs.reload();
        expect(prefs.getString('idle_party_save_slot_0'), brokenJson);
        expect(prefs.getString('idle_party_save_v2'), healthyJson);

        final copy = await _installRejectingPrefs();
        await copy.prefs.setBool('idle_party_slots_ready', true);
        await copy.prefs.setString('idle_party_save_slot_0', brokenJson);
        copy.store.failCorruptCopy = true;
        final copyStorage = SharedPreferencesGameStorage(
          preferences: copy.prefs,
        );
        await expectLater(copyStorage.load(), throwsStateError);
        await copy.prefs.reload();
        expect(copy.prefs.getString('idle_party_save_slot_0'), brokenJson);
        expect(copy.prefs.getString('idle_party_save_slot_0_corrupt'), isNull);

        copy.store.failCorruptCopy = false;
        copy.store.throwCorruptCopy = true;
        await expectLater(copyStorage.load(), throwsStateError);
        await copy.prefs.reload();
        expect(copy.prefs.getString('idle_party_save_slot_0'), brokenJson);
        expect(copy.prefs.getString('idle_party_save_slot_0_corrupt'), isNull);
        expect(prefs.getString('idle_party_save_v2'), healthyJson);
      },
    );

    test(
      'retry adopts the stored slot and open follows that identity',
      () async {
        final harness = await _installRejectingPrefs();
        final store = harness.store;
        final slot0 = _party(
          life: 10,
          purchaseIds: const ['GPA.slot0'],
        ).copyWith(partyName: 'Slot Zero');
        final slot2 = _party(
          life: 20,
          adFree: true,
          purchaseIds: const ['GPA.slot2'],
        ).copyWith(partyName: 'Slot Two');
        final slot0Json = GameLogic.exportSaveJson(slot0);
        final slot2Json = GameLogic.exportSaveJson(slot2);
        final prefs = harness.prefs;
        await prefs.setBool('idle_party_slots_ready', true);
        await prefs.setInt('idle_party_active_slot', 2);
        await prefs.setString('idle_party_save_slot_0', slot0Json);
        await prefs.setString('idle_party_save_slot_2', slot2Json);
        store.failGets = 1;
        SharedPreferences.resetStatic();
        final director = GameDirector(
          SharedPreferencesGameStorage(),
          enableSpatialLoop: false,
        );
        addTearDown(director.dispose);
        await director.boot();
        expect(director.saveRecoveryBlocked, isTrue);
        expect(director.activeSaveSlot, 0);
        expect(await director.retrySaveRecovery(), isTrue);
        expect(director.saveRecoveryBlocked, isFalse);
        expect(director.activeSaveSlot, 2);
        expect(director.debugStorage.activeSlotIndex, 2);
        expect(director.state.partyName, 'Slot Two');
        expect(director.state.metaDepth.adFree, isTrue);
        final granted = await director.debugGrantShopPurchase(
          'cinder_pouch',
          purchaseId: 'GPA.during',
        );
        expect(granted, isTrue);
        SharedPreferences.resetStatic();
        final mid = await SharedPreferences.getInstance();
        expect(mid.getString('idle_party_save_slot_0'), slot0Json);
        expect(mid.getString('idle_party_save_slot_2'), contains('GPA.during'));
        expect(mid.getString('idle_party_save_slot_2'), contains('Slot Two'));
        expect(await director.openSaveSlot(2), isTrue);
        expect(director.state.partyName, 'Slot Two');
        expect(await director.openSaveSlot(0), isTrue);
        expect(director.activeSaveSlot, 0);
        expect(director.debugStorage.activeSlotIndex, 0);
        expect(director.state.partyName, 'Slot Zero');
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          isNot(contains('GPA.during')),
        );
        final afterOpen = await SharedPreferences.getInstance();
        expect(
          afterOpen.getString('idle_party_save_slot_2'),
          contains('GPA.during'),
        );
        expect(await director.openSaveSlot(2), isTrue);
        expect(director.activeSaveSlot, 2);
        expect(director.state.partyName, 'Slot Two');
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          contains('GPA.during'),
        );
        SharedPreferences.resetStatic();
        final reboot = GameDirector(
          SharedPreferencesGameStorage(),
          enableSpatialLoop: false,
        );
        addTearDown(reboot.dispose);
        await reboot.boot();
        expect(reboot.activeSaveSlot, 2);
        expect(reboot.state.partyName, 'Slot Two');
        expect(
          reboot.state.metaDepth.grantedShopPurchaseIds,
          contains('GPA.slot2'),
        );
        expect(
          reboot.state.metaDepth.grantedShopPurchaseIds,
          contains('GPA.during'),
        );
        final files = await SharedPreferences.getInstance();
        expect(
          files.getString('idle_party_save_slot_0'),
          contains('Slot Zero'),
        );
        expect(
          files.getString('idle_party_save_slot_0'),
          isNot(contains('GPA.during')),
        );
      },
    );
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
        await storage.writeExtra(GameStorage.journalKey, 'swap-stage@0');
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
        expect(
          await director.openSafeRecoverySlot(0),
          RecoverySlotOpen.refused,
        );
        expect(
          await director.openSafeRecoverySlot(2),
          RecoverySlotOpen.refused,
        );
        expect(
          await director.openSafeRecoverySlot(3),
          RecoverySlotOpen.needsNewGame,
        );
        expect(director.saveRecoveryBlocked, isTrue);
        expect(await storage.loadSlotRaw(3), isNull);
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
        expect(
          await director.openSafeRecoverySlot(0),
          RecoverySlotOpen.refused,
        );
        expect(director.safeRecoverySlots, contains(4));
        expect(director.safeRecoverySlots, isNot(contains(0)));
        expect(
          await director.openSafeRecoverySlot(4),
          RecoverySlotOpen.needsNewGame,
        );
        expect(director.saveRecoveryBlocked, isTrue);
        expect(await storage.loadSlotRaw(4), isNull);
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
      expect(await director.openSafeRecoverySlot(0), RecoverySlotOpen.refused);
      expect(director.safeRecoverySlots, contains(4));
      expect(
        await director.openSafeRecoverySlot(4),
        RecoverySlotOpen.needsNewGame,
      );
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await storage.loadSlotRaw(4), isNull);
      expect(await storage.loadSlotRaw(0), planted.slot0);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-commit');
      expect(await storage.loadExtra(GameStorage.holdKey), planted.held);
    });

    test('a missing or quarantined owner is not finished on slot 0', () async {
      for (final phase in ['swap-commit', 'swap-publish']) {
        for (final kind in ['missing', 'quarantined']) {
          final planted = await _plantSlot0Selection(phase: phase);
          final storage = planted.storage;
          await storage.clearSlot(2);
          if (kind == 'quarantined') {
            await storage.writeExtra(
              'idle_party_save_slot_2_corrupt',
              planted.owner,
            );
          }
          expect(await storage.loadSlotRaw(2), isNull, reason: '$phase $kind');
          expect(
            await SaveSwap.recover(storage),
            SaveSwapOutcome.unresolved,
            reason: '$phase $kind',
          );
          expect(await storage.loadSlotRaw(0), planted.slot0, reason: kind);
          expect(
            await storage.loadExtra(GameStorage.journalKey),
            phase,
            reason: kind,
          );
          expect(
            await storage.loadExtra(GameStorage.holdKey),
            planted.held,
            reason: kind,
          );
          final director = GameDirector(storage, enableSpatialLoop: false);
          addTearDown(director.dispose);
          await director.boot();
          expect(director.saveRecoveryBlocked, isTrue, reason: kind);
          expect(director.saveRecoveryAmbiguous, isTrue, reason: kind);
          expect(await director.retrySaveRecovery(), isFalse, reason: kind);
          expect(await director.retrySaveRecovery(), isFalse, reason: kind);
          expect(await director.debugTryPersist(), isFalse, reason: kind);
          expect(await storage.loadSlotRaw(0), planted.slot0, reason: kind);
          expect(
            await storage.loadExtra(GameStorage.holdKey),
            planted.held,
            reason: kind,
          );
          expect(
            await storage.loadExtra(GameStorage.journalKey),
            phase,
            reason: kind,
          );
          final exported = await director.exportRecoveryRecords();
          expect(exported, contains('d0-only'), reason: kind);
          expect(exported, contains(planted.held), reason: kind);
          if (kind == 'quarantined') {
            expect(
              await storage.loadExtra('idle_party_save_slot_2_corrupt'),
              planted.owner,
              reason: phase,
            );
          }
        }
      }
    });

    test('a named slot 0 swap recovers while another save exists', () async {
      final c0 = GameLogic.exportSaveJson(_party(life: 10));
      final c1 = GameLogic.exportSaveJson(
        _party(life: 80, adFree: true, cinders: 4),
      );
      final incoming = GameLogic.exportSaveJson(_party(life: 500));
      final d2 = GameLogic.exportSaveJson(
        _party(life: 9, purchaseIds: const ['d2-only']),
      );
      final storage = InMemoryGameStorage();
      await _writeSlot(storage, 2, d2);
      await _writeSlot(storage, 0, c0);
      await storage.setActiveSlot(0);
      storage.failExtraWhen = (key, value) =>
          key == GameStorage.journalKey && value == 'swap-commit@0';
      expect(
        await SaveSwap.commitSwap(
          storage: storage,
          newActiveJson: incoming,
          newDisplacedJson: c1,
        ),
        SaveSwapOutcome.unresolved,
      );
      expect(await storage.loadSlotRaw(0), c0);
      expect(await storage.loadSlotRaw(2), d2);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-stage@0');
      expect(await storage.loadExtra(GameStorage.holdKey), c1);
      storage.failExtraWhen = null;
      expect(await SaveSwap.recover(storage), SaveSwapOutcome.committed);
      expect(await storage.loadSlotRaw(0), incoming);
      expect(await storage.loadSlotRaw(2), d2);
      expect(
        GameLogic.importSaveJson(
          (await storage.loadDisplacedSave())!,
        )!.metaDepth.cinders,
        4,
      );
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);

      final again = InMemoryGameStorage();
      await _writeSlot(again, 2, d2);
      await _writeSlot(again, 0, c0);
      await again.setActiveSlot(0);
      await again.writeExtra(GameStorage.stagingKey, incoming);
      await again.writeExtra(GameStorage.holdKey, c1);
      await again.writeExtra(
        GameStorage.displacedKey,
        GameLogic.exportSaveJson(_party(life: 1)),
      );
      await again.writeExtra(GameStorage.journalKey, 'swap-stage@0');
      final director = GameDirector(again, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isFalse);
      expect(director.saveRecoveryAmbiguous, isFalse);
      expect(await again.loadSlotRaw(2), d2);
      final resumed = GameLogic.importSaveJson((await again.loadSlotRaw(0))!);
      expect(resumed!.lifetimeGoldEarned, 500);
      expect(
        resumed.metaDepth.grantedShopPurchaseIds,
        isNot(contains('d2-only')),
      );
      expect(
        GameLogic.importSaveJson(
          (await again.loadDisplacedSave())!,
        )!.metaDepth.cinders,
        4,
      );
    });

    test('named slot 0 marker cuts keep the other save', () async {
      final c0 = GameLogic.exportSaveJson(_party(life: 10));
      final c1 = GameLogic.exportSaveJson(
        _party(life: 80, adFree: true, cinders: 4),
      );
      final incoming = GameLogic.exportSaveJson(_party(life: 500));
      final d2 = GameLogic.exportSaveJson(
        _party(life: 9, purchaseIds: const ['d2-only']),
      );
      for (final kind in ['fail', 'throw-before', 'throw-after']) {
        final storage = InMemoryGameStorage();
        await _writeSlot(storage, 2, d2);
        await _writeSlot(storage, 0, c0);
        await storage.setActiveSlot(0);
        storage.armExtraWriteCut(
          failAt: kind == 'fail' ? 4 : null,
          throwBefore: kind == 'throw-before' ? 4 : null,
          throwAfter: kind == 'throw-after' ? 4 : null,
        );
        final outcome = await SaveSwap.commitSwap(
          storage: storage,
          newActiveJson: incoming,
          newDisplacedJson: c1,
        );
        expect(outcome, SaveSwapOutcome.committed, reason: kind);
        expect(await storage.loadSlotRaw(2), d2, reason: kind);
        expect(await storage.loadSlotRaw(0), incoming, reason: kind);
        expect(
          GameLogic.importSaveJson(
            (await storage.loadDisplacedSave())!,
          )!.metaDepth.cinders,
          4,
          reason: kind,
        );
        expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      }
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
      await storage.writeExtra(GameStorage.journalKey, 'swap-stage@0');
      storage.failExtraWhen = (key, value) =>
          key == GameStorage.journalKey && value == 'swap-commit@0';
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

    testWidgets(
      'recovery overlay saves an empty slot before play and reads it back',
      (tester) async {
        final planted = await _ambiguousEscape();
        final director = GameDirector(
          planted.storage,
          enableSpatialLoop: false,
        );
        await _pumpRecoveryApp(tester, director);
        expect(find.text('SAVE RECOVERY'), findsOneWidget);
        expect(find.text('ENTER DUNGEON'), findsNothing);
        expect(find.text('OPEN SLOT 3'), findsOneWidget);
        expect(find.text('OPEN SLOT 5'), findsOneWidget);

        await tester.ensureVisible(find.text('OPEN SLOT 3'));
        await tester.tap(find.text('OPEN SLOT 3'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('SAVE RECOVERY'), findsNothing);
        expect(director.saveRecoveryBlocked, isFalse);
        expect(director.hasExistingSave, isTrue);
        expect(director.state.lifetimeGoldEarned, 40);
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          contains('slot2-keep'),
        );
        expect(
          await planted.storage.loadExtra(GameStorage.journalKey),
          'swap-stage',
        );
        _expectParty(
          await planted.storage.loadSlotRaw(2),
          life: 40,
          purchase: 'slot2-keep',
        );
        expect(
          await planted.storage.loadExtra(GameStorage.holdKey),
          planted.held,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final cold = GameDirector(planted.storage, enableSpatialLoop: false);
        await _pumpRecoveryApp(tester, cold);
        expect(find.text('SAVE RECOVERY'), findsOneWidget);
        expect(find.text('ENTER DUNGEON'), findsNothing);
        await tester.ensureVisible(find.text('OPEN SLOT 5'));
        await tester.tap(find.text('OPEN SLOT 5'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('START'), findsOneWidget);
        expect(find.text('ENTER DUNGEON'), findsNothing);
        expect(cold.saveRecoveryBlocked, isTrue);
        expect(await planted.storage.loadSlotRaw(4), isNull);

        await tester.enterText(find.byType(TextField), 'Ember Test');
        await tester.pump();
        await tester.tap(find.text('START'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(cold.saveRecoveryBlocked, isFalse);
        expect(cold.hasExistingSave, isTrue);
        expect(cold.state.partyName, 'Ember Test');
        cold.debugSetGold(4242);
        expect(await cold.debugTryPersist(), isTrue);
        expect(
          GameLogic.importSaveJson(
            (await planted.storage.loadSlotRaw(4))!,
          )!.gold,
          4242,
        );
        _expectParty(
          await planted.storage.loadSlotRaw(2),
          life: 40,
          purchase: 'slot2-keep',
        );
        expect(
          await planted.storage.loadExtra(GameStorage.journalKey),
          'swap-stage',
        );
        expect(
          await planted.storage.loadExtra(GameStorage.holdKey),
          planted.held,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final reboot = GameDirector(planted.storage, enableSpatialLoop: false);
        await _pumpRecoveryApp(tester, reboot);
        expect(find.text('SAVE RECOVERY'), findsOneWidget);
        expect(find.text('ENTER DUNGEON'), findsNothing);
        expect(
          GameLogic.importSaveJson(
            (await planted.storage.loadSlotRaw(4))!,
          )!.gold,
          4242,
        );
        await tester.ensureVisible(find.text('OPEN SLOT 5'));
        await tester.tap(find.text('OPEN SLOT 5'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(reboot.saveRecoveryBlocked, isFalse);
        expect(reboot.hasExistingSave, isTrue);
        expect(reboot.state.gold, 4242);
        expect(reboot.state.partyName, 'Ember Test');
        _expectParty(
          await planted.storage.loadSlotRaw(2),
          life: 40,
          purchase: 'slot2-keep',
        );
        expect(
          await planted.storage.loadExtra(GameStorage.journalKey),
          'swap-stage',
        );
        expect(
          await planted.storage.loadExtra(GameStorage.holdKey),
          planted.held,
        );
        await _disposeRecoveryApp(tester);
      },
    );

    testWidgets('recovery back and a failed new game stay off the empty slot', (
      tester,
    ) async {
      final planted = await _ambiguousEscape();
      final director = GameDirector(planted.storage, enableSpatialLoop: false);
      await _pumpRecoveryApp(tester, director);
      await tester.ensureVisible(find.text('OPEN SLOT 5'));
      await tester.tap(find.text('OPEN SLOT 5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('START'), findsOneWidget);
      await tester.tap(find.text('BACK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await planted.storage.loadSlotRaw(4), isNull);
      expect(await planted.storage.loadSlotRaw(2), planted.slot2);
      expect(
        await planted.storage.loadExtra(GameStorage.journalKey),
        'swap-stage',
      );

      await tester.ensureVisible(find.text('OPEN SLOT 5'));
      await tester.tap(find.text('OPEN SLOT 5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      planted.storage.failNextActiveWrite = true;
      await tester.enterText(find.byType(TextField), 'Ember Test');
      await tester.pump();
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('START'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.hasExistingSave, isTrue);
      expect(await planted.storage.loadSlotRaw(4), isNull);
      expect(await planted.storage.loadSlotRaw(2), planted.slot2);
      expect(
        await planted.storage.loadExtra(GameStorage.journalKey),
        'swap-stage',
      );
      expect(
        await planted.storage.loadExtra(GameStorage.holdKey),
        planted.held,
      );

      planted.storage.throwNextActiveWrite = true;
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('START'), findsOneWidget);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await planted.storage.loadSlotRaw(4), isNull);
      expect(await planted.storage.loadSlotRaw(2), planted.slot2);
      expect(
        await planted.storage.loadExtra(GameStorage.journalKey),
        'swap-stage',
      );
      await tester.tap(find.text('BACK'));
      await tester.pump();
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(find.text('OPEN SLOT 5'), findsOneWidget);
    });

    testWidgets('in-play recovery opens an empty slot through party setup', (
      tester,
    ) async {
      final storage = InMemoryGameStorage();
      final slot0 = GameLogic.exportSaveJson(
        _party(life: 11, purchaseIds: const ['slot0-keep']),
      );
      await storage.writeActiveRaw(slot0);
      expect(await storage.loadSlotRaw(0), slot0);
      final director = GameDirector(storage, enableSpatialLoop: false);
      await _pumpRecoveryApp(tester, director);
      expect(find.text('SAVE RECOVERY'), findsNothing);
      expect(director.hasExistingSave, isTrue);
      final kept = await storage.loadSlotRaw(0);

      final held = GameLogic.exportSaveJson(
        _party(life: 500, purchaseIds: const ['held-only']),
      );
      await storage.writeExtra(GameStorage.journalKey, 'swap-stage');
      await storage.writeExtra(GameStorage.stagingKey, held);
      await storage.writeExtra(GameStorage.holdKey, held);
      expect(await director.restoreDisplacedDeviceSave(), isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
      expect(director.saveRecoveryAmbiguous, isFalse);
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('RETRY'), findsNothing);
      expect(find.text('OPEN SLOT 2'), findsOneWidget);
      expect(await storage.loadSlotRaw(0), kept);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-stage');

      await tester.ensureVisible(find.text('OPEN SLOT 2'));
      await tester.tap(find.text('OPEN SLOT 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('START'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await storage.loadSlotRaw(1), isNull);
      expect(await storage.loadSlotRaw(0), kept);

      await tester.tap(find.text('BACK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await storage.loadSlotRaw(0), kept);
      expect(await storage.loadExtra(GameStorage.holdKey), held);

      await tester.ensureVisible(find.text('OPEN SLOT 2'));
      await tester.tap(find.text('OPEN SLOT 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Ember Test');
      await tester.pump();
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(director.saveRecoveryBlocked, isFalse);
      expect(director.hasExistingSave, isTrue);
      expect(director.state.partyName, 'Ember Test');
      director.debugSetGold(4242);
      expect(await director.debugTryPersist(), isTrue);
      expect(await storage.loadSlotRaw(0), kept);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-stage');
      expect(await storage.loadExtra(GameStorage.holdKey), held);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final reboot = GameDirector(storage, enableSpatialLoop: false);
      await _pumpRecoveryApp(tester, reboot);
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(
        GameLogic.importSaveJson((await storage.loadSlotRaw(1))!)!.gold,
        4242,
      );
      expect(await storage.loadSlotRaw(0), kept);
      await tester.ensureVisible(find.text('OPEN SLOT 2'));
      await tester.tap(find.text('OPEN SLOT 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(reboot.hasExistingSave, isTrue);
      expect(reboot.state.gold, 4242);
      expect(reboot.state.partyName, 'Ember Test');
      expect(await storage.loadSlotRaw(0), kept);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-stage');
      expect(await storage.loadExtra(GameStorage.holdKey), held);
      await _disposeRecoveryApp(tester);
    });

    test(
      'a failed or thrown title new game stays unstarted until a retry',
      () async {
        final storage = InMemoryGameStorage();
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        storage.failNextActiveWrite = true;
        expect(
          await director.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Cave Company',
          ),
          isFalse,
        );
        expect(director.hasExistingSave, isFalse);
        expect(director.state.inDungeon, isFalse);
        expect(await storage.loadSlotRaw(0), isNull);
        storage.throwNextActiveWrite = true;
        expect(
          await director.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Cave Company',
          ),
          isFalse,
        );
        expect(await storage.loadSlotRaw(0), isNull);
        expect(
          await director.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Cave Company',
          ),
          isTrue,
        );
        expect(director.hasExistingSave, isTrue);
        expect((await storage.load())!.partyName, 'Cave Company');
      },
    );

    test('recovery START retries after a failed or thrown save', () async {
      final planted = await _ambiguousEscape();
      final director = GameDirector(planted.storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(
        await director.openSafeRecoverySlot(4),
        RecoverySlotOpen.needsNewGame,
      );
      planted.storage.failNextActiveWrite = true;
      expect(
        await director.startNewGame(
          HeroSpecs.starterUnlocked,
          partyName: 'Retry',
        ),
        isFalse,
      );
      expect(await planted.storage.loadSlotRaw(4), isNull);
      planted.storage.throwNextActiveWrite = true;
      expect(
        await director.startNewGame(
          HeroSpecs.starterUnlocked,
          partyName: 'Retry',
        ),
        isFalse,
      );
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await planted.storage.loadSlotRaw(4), isNull);
      expect(await planted.storage.loadSlotRaw(2), planted.slot2);
      expect(
        await director.startNewGame(
          HeroSpecs.starterUnlocked,
          partyName: 'Retry',
        ),
        isTrue,
      );
      expect(director.saveRecoveryBlocked, isFalse);
      expect(director.hasExistingSave, isTrue);
      expect((await planted.storage.loadSlot(4))!.partyName, 'Retry');
      expect(await planted.storage.loadSlotRaw(2), planted.slot2);
      expect(
        await planted.storage.loadExtra(GameStorage.journalKey),
        'swap-stage',
      );
      expect(
        await planted.storage.loadExtra(GameStorage.holdKey),
        planted.held,
      );
    });

    test(
      'a save that lands and then returns false is still the new game',
      () async {
        // The in-memory map can change and the setter can still return
        // false. That is not a disk commit, so play stays closed.
        final storage = InMemoryGameStorage();
        final director = GameDirector(storage, enableSpatialLoop: false);
        addTearDown(director.dispose);
        await director.boot();
        storage.landThenFailSave = true;
        expect(
          await director.startNewGame(
            HeroSpecs.starterUnlocked,
            partyName: 'Landed',
          ),
          isFalse,
        );
        expect(director.hasExistingSave, isFalse);
        expect(director.state.inDungeon, isFalse);
        expect((await storage.load())!.partyName, 'Landed');
      },
    );

    test(
      'a second START does not run after a grant on the new party',
      () async {
        final planted = await _ambiguousEscape();
        final director = GameDirector(
          planted.storage,
          enableSpatialLoop: false,
        );
        addTearDown(director.dispose);
        await director.boot();
        expect(
          await director.openSafeRecoverySlot(4),
          RecoverySlotOpen.needsNewGame,
        );
        final release = Completer<void>();
        planted.storage.pauseBeforeNextWrite = release.future;
        final first = director.startNewGame(
          HeroSpecs.starterUnlocked,
          partyName: 'Ember',
        );
        await pumpEventQueue();
        expect(planted.storage.writeEntered, isTrue);
        final second = director.startNewGame(
          HeroSpecs.starterUnlocked,
          partyName: 'Stale',
        );
        final third = director.startNewGame(
          HeroSpecs.starterUnlocked,
          partyName: 'Stale Two',
        );
        final grant = director.debugGrantShopPurchase(
          'cinder_pouch',
          purchaseId: 'GPA.once',
        );
        expect(await second, isFalse);
        expect(await third, isFalse);
        release.complete();
        expect(await first, isTrue);
        expect(await grant, isTrue);
        expect(director.state.partyName, 'Ember');
        expect(
          director.state.metaDepth.grantedShopPurchaseIds,
          contains('GPA.once'),
        );
        expect(director.state.metaDepth.cinders, greaterThan(0));
        final cinders = director.state.metaDepth.cinders;
        expect(await planted.storage.loadSlotRaw(2), planted.slot2);
        expect(
          await planted.storage.loadExtra(GameStorage.journalKey),
          'swap-stage',
        );
        expect(
          await planted.storage.loadExtra(GameStorage.holdKey),
          planted.held,
        );
        final reboot = GameDirector(planted.storage, enableSpatialLoop: false);
        addTearDown(reboot.dispose);
        await reboot.boot();
        final parsed = GameLogic.importSaveJson(
          (await planted.storage.loadSlotRaw(4))!,
        )!;
        expect(parsed.partyName, 'Ember');
        expect(parsed.metaDepth.grantedShopPurchaseIds, contains('GPA.once'));
        expect(parsed.metaDepth.cinders, cinders);
        expect(await planted.storage.loadSlotRaw(2), planted.slot2);
        expect(
          await planted.storage.loadExtra(GameStorage.journalKey),
          'swap-stage',
        );
      },
    );

    testWidgets('title PLAY stays on the menu when the first save fails', (
      tester,
    ) async {
      final storage = InMemoryGameStorage();
      final director = GameDirector(storage, enableSpatialLoop: false);
      await _pumpRecoveryApp(tester, director, showIntro: true);
      expect(find.text('PLAY'), findsOneWidget);
      storage.failNextActiveWrite = true;
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      expect(director.hasExistingSave, isFalse);
      expect(director.state.inDungeon, isFalse);
      expect(await storage.loadSlotRaw(0), isNull);
      storage.throwNextActiveWrite = true;
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('PLAY'), findsOneWidget);
      expect(await storage.loadSlotRaw(0), isNull);
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(director.hasExistingSave, isTrue);
      expect((await storage.load())!.partyName, 'The Party');
      await _disposeRecoveryApp(tester);
      final reboot = GameDirector(storage, enableSpatialLoop: false);
      try {
        await reboot.boot();
        expect((await storage.load())!.partyName, 'The Party');
      } finally {
        reboot.dispose();
      }
    });

    testWidgets('recovery START taps do not queue a second game over a grant', (
      tester,
    ) async {
      final planted = await _ambiguousEscape();
      final director = GameDirector(planted.storage, enableSpatialLoop: false);
      await _pumpRecoveryApp(tester, director);
      await tester.ensureVisible(find.text('OPEN SLOT 5'));
      await tester.tap(find.text('OPEN SLOT 5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Ember Test');
      await tester.pump();
      final release = Completer<void>();
      planted.storage.pauseBeforeNextWrite = release.future;
      await tester.ensureVisible(find.text('START'));
      await tester.tap(find.text('START'));
      await tester.pump();
      for (var i = 0; i < 20 && !planted.storage.writeEntered; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(planted.storage.writeEntered, isTrue);
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.tap(find.text('START'));
      await tester.pump();
      final second = director.startNewGame(
        HeroSpecs.starterUnlocked,
        partyName: 'Stale',
      );
      final third = director.startNewGame(
        HeroSpecs.starterUnlocked,
        partyName: 'Stale Two',
      );
      final grant = director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.ui',
      );
      expect(await second, isFalse);
      expect(await third, isFalse);
      release.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(await grant, isTrue);
      expect(director.state.partyName, 'Ember Test');
      expect(
        director.state.metaDepth.grantedShopPurchaseIds,
        contains('GPA.ui'),
      );
      expect(director.state.metaDepth.cinders, greaterThan(0));
      final cinders = director.state.metaDepth.cinders;
      expect(await planted.storage.loadSlotRaw(2), planted.slot2);
      expect(
        await planted.storage.loadExtra(GameStorage.journalKey),
        'swap-stage',
      );
      expect(
        await planted.storage.loadExtra(GameStorage.holdKey),
        planted.held,
      );
      await _disposeRecoveryApp(tester);
      final reboot = GameDirector(planted.storage, enableSpatialLoop: false);
      try {
        await reboot.boot();
        final parsed = GameLogic.importSaveJson(
          (await planted.storage.loadSlotRaw(4))!,
        )!;
        expect(parsed.partyName, 'Ember Test');
        expect(parsed.metaDepth.grantedShopPurchaseIds, contains('GPA.ui'));
        expect(parsed.metaDepth.cinders, cinders);
        expect(await planted.storage.loadSlotRaw(2), planted.slot2);
        expect(
          await planted.storage.loadExtra(GameStorage.journalKey),
          'swap-stage',
        );
      } finally {
        reboot.dispose();
      }
    });

    testWidgets('BACK during a held new-game save does not enter play', (
      tester,
    ) async {
      final planted = await _ambiguousEscape();
      final director = GameDirector(planted.storage, enableSpatialLoop: false);
      await _pumpRecoveryApp(tester, director);
      await tester.ensureVisible(find.text('OPEN SLOT 5'));
      await tester.tap(find.text('OPEN SLOT 5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Ember Test');
      await tester.pump();
      final release = Completer<void>();
      planted.storage.pauseBeforeNextWrite = release.future;
      await tester.tap(find.text('START'));
      await tester.pump();
      for (var i = 0; i < 20 && !planted.storage.writeEntered; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(planted.storage.writeEntered, isTrue);
      await tester.tap(find.text('BACK'));
      await tester.pump();
      release.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('SAVE RECOVERY'), findsOneWidget);
      expect(find.text('ENTER DUNGEON'), findsNothing);
      expect(director.saveRecoveryBlocked, isTrue);
      expect(await planted.storage.loadSlotRaw(2), planted.slot2);
      expect(
        await planted.storage.loadExtra(GameStorage.journalKey),
        'swap-stage',
      );
      expect(
        await planted.storage.loadExtra(GameStorage.holdKey),
        planted.held,
      );
      final started = await planted.storage.loadSlotRaw(4);
      if (started != null) {
        expect(GameLogic.importSaveJson(started)!.partyName, 'Ember Test');
      }
      await _disposeRecoveryApp(tester);
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

  group('recovery slot machine', () {
    test('a swap finishes on the slot that owns it', () async {
      _keepSuiteRandom();
      final storage = InMemoryGameStorage();
      final slot0 = GameLogic.exportSaveJson(
        _party(
          life: 80,
          purchaseIds: const ['GPA.slot0'],
        ).copyWith(partyName: 'Slot Zero'),
      );
      final owned = GameLogic.exportSaveJson(
        _party(
          life: 30,
          purchaseIds: const ['GPA.owned'],
        ).copyWith(partyName: 'Owned'),
      );
      final incoming = GameLogic.exportSaveJson(
        _party(
          life: 4,
          purchaseIds: const ['GPA.incoming'],
        ).copyWith(partyName: 'Incoming'),
      );
      final held = GameLogic.exportSaveJson(
        _party(
          life: 8,
          purchaseIds: const ['GPA.held'],
        ).copyWith(partyName: 'Held'),
      );
      await _writeSlot(storage, 0, slot0);
      await _writeSlot(storage, 2, owned);
      await storage.setActiveSlot(0);
      await storage.writeExtra(GameStorage.journalKeyFor(2), 'swap-stage@2');
      await storage.writeExtra(GameStorage.stagingKeyFor(2), incoming);
      await storage.writeExtra(GameStorage.holdKeyFor(2), held);
      expect(
        await SaveSwap.recover(storage, slot: 2),
        SaveSwapOutcome.committed,
      );
      expect(storage.activeSlotIndex, 0);
      expect(await storage.loadSlotRaw(0), slot0);
      expect(await storage.loadSlotRaw(2), incoming);
      expect(await storage.loadExtra(GameStorage.displacedKeyFor(2)), held);
      expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
    });

    test('sequences keep a refusal from replacing another party', () async {
      _keepSuiteRandom();
      final rows = <String, Future<void> Function()>{
        'refused start': _sequenceRefusedStart,
        'rolled-back start': _sequenceRolledBackStart,
        'journal reopen': _sequenceJournalReopen,
        'unresolved journal': _sequenceUnresolvedJournal,
        'only journaled file': _sequenceOnlyJournal,
        'unknown phase keeps a healthy file': _sequenceUnknownPhaseEscape,
        'unknown phase alone stays closed': _sequenceUnknownPhaseAlone,
        'ambiguous owner stays unrecoverable': _sequenceAmbiguousStays,
      };
      for (final row in rows.entries) {
        try {
          await row.value();
        } catch (error) {
          fail('${row.key}: $error');
        }
      }
    });
  });

  testWidgets('a known swap-commit with no hold still opens the other file', (
    tester,
  ) async {
    _keepSuiteRandom();
    final storage = InMemoryGameStorage();
    final owned = GameLogic.exportSaveJson(
      _party(life: 30, purchaseIds: const ['GPA.c0']).copyWith(partyName: 'C0'),
    );
    final healthy = GameLogic.exportSaveJson(
      _party(life: 70, purchaseIds: const ['GPA.d0']).copyWith(partyName: 'D0'),
    );
    final staged = GameLogic.exportSaveJson(
      _party(
        life: 4,
        purchaseIds: const ['GPA.staged'],
      ).copyWith(partyName: 'Staged'),
    );
    await _writeSlot(storage, 2, owned);
    await _writeSlot(storage, 0, healthy);
    await storage.setActiveSlot(2);
    await storage.writeExtra(GameStorage.journalKeyFor(2), 'swap-commit@2');
    await storage.writeExtra(GameStorage.stagingKeyFor(2), staged);
    final director = GameDirector(storage, enableSpatialLoop: false);
    await _pumpRecoveryApp(tester, director);
    expect(find.text('SAVE RECOVERY'), findsOneWidget);
    expect(find.text('EXPORT RECORDS'), findsNothing);
    expect(find.text('OPEN SLOT 1'), findsOneWidget);
    expect(find.text('OPEN SLOT 3'), findsNothing);
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SAVE RECOVERY'), findsOneWidget);
    expect(find.text('OPEN SLOT 1'), findsOneWidget);
    expect(
      await storage.loadExtra(GameStorage.journalKeyFor(2)),
      'swap-commit@2',
    );
    expect(await storage.loadExtra(GameStorage.stagingKeyFor(2)), staged);
    expect(await storage.loadExtra(GameStorage.holdKeyFor(2)), isNull);
    expect(await storage.loadExtra(GameStorage.displacedKeyFor(2)), isNull);
    expect(await storage.loadSlotRaw(2), owned);
    expect(await storage.loadSlotRaw(0), healthy);
    await tester.ensureVisible(find.text('OPEN SLOT 1'));
    await tester.tap(find.text('OPEN SLOT 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SAVE RECOVERY'), findsNothing);
    expect(director.saveRecoveryBlocked, isFalse);
    expect(director.activeSaveSlot, 0);
    expect(director.state.partyName, 'D0');
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isTrue,
    );
    expect(await storage.loadSlotRaw(2), owned);
    expect(
      await storage.loadExtra(GameStorage.journalKeyFor(2)),
      'swap-commit@2',
    );
    expect(await storage.loadExtra(GameStorage.stagingKeyFor(2)), staged);
    expect(await storage.loadExtra(GameStorage.holdKeyFor(2)), isNull);
    expect(_rawHas(await storage.loadSlotRaw(2), 'GPA.fresh'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final playing = GameDirector(storage, enableSpatialLoop: false);
    await _pumpRecoveryApp(tester, playing);
    expect(find.text('SAVE RECOVERY'), findsNothing);
    expect(playing.saveRecoveryBlocked, isFalse);
    expect(playing.activeSaveSlot, 0);
    expect(playing.state.partyName, 'D0');
    expect(
      playing.state.metaDepth.grantedShopPurchaseIds,
      containsAll(['GPA.d0', 'GPA.fresh']),
    );
    expect(
      await storage.loadExtra(GameStorage.journalKeyFor(2)),
      'swap-commit@2',
    );
    expect(await storage.loadExtra(GameStorage.stagingKeyFor(2)), staged);
    expect(await storage.loadSlotRaw(2), owned);
    await _disposeRecoveryApp(tester);
  });

  testWidgets('an unknown journal on slot 2 opens slot 1 from the gate', (
    tester,
  ) async {
    _keepSuiteRandom();
    final storage = InMemoryGameStorage();
    final owned = GameLogic.exportSaveJson(
      _party(
        life: 30,
        purchaseIds: const ['GPA.owned'],
      ).copyWith(partyName: 'Owned'),
    );
    final healthy = GameLogic.exportSaveJson(
      _party(
        life: 70,
        purchaseIds: const ['GPA.keep'],
      ).copyWith(partyName: 'Healthy'),
    );
    final staged = GameLogic.exportSaveJson(
      _party(
        life: 4,
        purchaseIds: const ['GPA.staged'],
      ).copyWith(partyName: 'Staged'),
    );
    final held = GameLogic.exportSaveJson(
      _party(
        life: 8,
        purchaseIds: const ['GPA.held'],
      ).copyWith(partyName: 'Held'),
    );
    await _writeSlot(storage, 2, owned);
    await _writeSlot(storage, 0, healthy);
    await storage.setActiveSlot(2);
    await storage.writeExtra(GameStorage.journalKeyFor(2), 'nope@2');
    await storage.writeExtra(GameStorage.stagingKeyFor(2), staged);
    await storage.writeExtra(GameStorage.holdKeyFor(2), held);
    final director = GameDirector(storage, enableSpatialLoop: false);
    await _pumpRecoveryApp(tester, director);
    expect(find.text('SAVE RECOVERY'), findsOneWidget);
    expect(find.text('OPEN SLOT 1'), findsOneWidget);
    expect(find.text('OPEN SLOT 3'), findsNothing);
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('OPEN SLOT 1'), findsOneWidget);
    await tester.ensureVisible(find.text('OPEN SLOT 1'));
    await tester.tap(find.text('OPEN SLOT 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SAVE RECOVERY'), findsNothing);
    expect(director.activeSaveSlot, 0);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isTrue,
    );
    expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), 'nope@2');
    expect(await storage.loadExtra(GameStorage.stagingKeyFor(2)), staged);
    expect(await storage.loadExtra(GameStorage.holdKeyFor(2)), held);
    expect(await storage.loadSlotRaw(2), owned);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final playing = GameDirector(storage, enableSpatialLoop: false);
    await _pumpRecoveryApp(tester, playing);
    expect(find.text('SAVE RECOVERY'), findsNothing);
    expect(playing.saveRecoveryBlocked, isFalse);
    expect(playing.activeSaveSlot, 0);
    expect(
      playing.state.metaDepth.grantedShopPurchaseIds,
      containsAll(['GPA.keep', 'GPA.fresh']),
    );
    expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), 'nope@2');
    expect(await storage.loadSlotRaw(2), owned);
    await _disposeRecoveryApp(tester);
  });

  testWidgets('an unmatched journal still continues on the third file', (
    tester,
  ) async {
    _keepSuiteRandom();
    final storage = InMemoryGameStorage();
    final shared = GameLogic.exportSaveJson(
      _party(
        life: 11,
        purchaseIds: const ['GPA.shared'],
      ).copyWith(partyName: 'Shared'),
    );
    final held = GameLogic.exportSaveJson(
      _party(
        life: 13,
        purchaseIds: const ['GPA.held'],
      ).copyWith(partyName: 'Held'),
    );
    final free = GameLogic.exportSaveJson(
      _party(
        life: 14,
        purchaseIds: const ['GPA.free'],
      ).copyWith(partyName: 'Free'),
    );
    await _writeSlot(storage, 0, shared);
    await _writeSlot(storage, 2, shared);
    await _writeSlot(storage, 4, free);
    await storage.setActiveSlot(0);
    await storage.writeExtra(GameStorage.stagingKey, shared);
    await storage.writeExtra(GameStorage.holdKey, held);
    await storage.writeExtra(GameStorage.journalKey, 'nope');
    final director = GameDirector(storage, enableSpatialLoop: false);
    await _pumpRecoveryApp(tester, director);
    expect(find.text('SAVE RECOVERY'), findsOneWidget);
    expect(find.text('RETRY'), findsNothing);
    expect(find.text('EXPORT RECORDS'), findsOneWidget);
    expect(find.text('OPEN SLOT 1'), findsNothing);
    expect(find.text('OPEN SLOT 3'), findsNothing);
    expect(find.text('OPEN SLOT 5'), findsOneWidget);
    expect(await director.retrySaveRecovery(), isFalse);
    await tester.pump();
    expect(find.text('OPEN SLOT 5'), findsOneWidget);
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope');
    await tester.ensureVisible(find.text('OPEN SLOT 5'));
    await tester.tap(find.text('OPEN SLOT 5'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SAVE RECOVERY'), findsNothing);
    expect(director.activeSaveSlot, 4);
    expect(director.state.partyName, 'Free');
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isTrue,
    );
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope');
    expect(await storage.loadExtra(GameStorage.stagingKey), shared);
    expect(await storage.loadExtra(GameStorage.holdKey), held);
    expect(await storage.loadSlotRaw(0), shared);
    expect(await storage.loadSlotRaw(2), shared);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final playing = GameDirector(storage, enableSpatialLoop: false);
    await _pumpRecoveryApp(tester, playing);
    expect(playing.saveRecoveryBlocked, isTrue);
    expect(find.text('SAVE RECOVERY'), findsOneWidget);
    expect(find.text('OPEN SLOT 1'), findsNothing);
    expect(find.text('OPEN SLOT 3'), findsNothing);
    expect(find.text('OPEN SLOT 5'), findsOneWidget);
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope');
    expect(_rawHas(await storage.loadSlotRaw(4), 'GPA.fresh'), isTrue);
    expect(_rawHas(await storage.loadSlotRaw(4), 'GPA.free'), isTrue);
    await tester.ensureVisible(find.text('OPEN SLOT 5'));
    await tester.tap(find.text('OPEN SLOT 5'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SAVE RECOVERY'), findsNothing);
    expect(playing.saveRecoveryBlocked, isFalse);
    expect(playing.activeSaveSlot, 4);
    expect(
      playing.state.metaDepth.grantedShopPurchaseIds,
      containsAll(['GPA.free', 'GPA.fresh']),
    );
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope');
    expect(await storage.loadSlotRaw(0), shared);
    expect(await storage.loadSlotRaw(2), shared);
    await _disposeRecoveryApp(tester);
  });

  test(
    'a publish that cannot write yet does not offer the other file',
    () async {
      _keepSuiteRandom();
      final storage = InMemoryGameStorage();
      final active = GameLogic.exportSaveJson(
        _party(
          life: 500,
          purchaseIds: const ['GPA.active'],
        ).copyWith(partyName: 'Active'),
      );
      final hold = GameLogic.exportSaveJson(
        _party(
          life: 80,
          adFree: true,
          purchaseIds: const ['GPA.hold'],
        ).copyWith(partyName: 'Hold'),
      );
      final other = GameLogic.exportSaveJson(
        _party(
          life: 9,
          purchaseIds: const ['GPA.other'],
        ).copyWith(partyName: 'Other'),
      );
      await _writeSlot(storage, 0, active);
      await _writeSlot(storage, 2, other);
      await storage.setActiveSlot(0);
      await storage.writeExtra(GameStorage.stagingKey, active);
      await storage.writeExtra(GameStorage.holdKey, hold);
      await storage.writeExtra(GameStorage.journalKey, 'swap-publish');
      storage.failExtraWhen = (key, value) => key == GameStorage.displacedKey;
      final director = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryBlocked, isTrue);
      expect(director.safeRecoverySlots, isEmpty);
      expect(await director.retrySaveRecovery(), isFalse);
      expect(director.safeRecoverySlots, isEmpty);
      expect(await storage.loadSlotRaw(0), active);
      expect(await storage.loadSlotRaw(2), other);
      expect(await storage.loadExtra(GameStorage.journalKey), 'swap-publish');
      expect(await storage.loadExtra(GameStorage.holdKey), hold);
      storage.failExtraWhen = null;
      expect(await director.retrySaveRecovery(), isTrue);
      expect(director.saveRecoveryBlocked, isFalse);
      expect(director.activeSaveSlot, 0);
      expect(await storage.loadExtra(GameStorage.journalKey), isNull);
      expect(await storage.loadSlotRaw(2), other);
      expect(_rawHas(await storage.loadSlotRaw(0), 'GPA.other'), isFalse);
    },
  );
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

Future<({InMemoryGameStorage storage, String slot2, String held})>
_ambiguousEscape() async {
  final storage = InMemoryGameStorage();
  final slot2 = GameLogic.exportSaveJson(
    _party(life: 40, purchaseIds: const ['slot2-keep']),
  );
  final held = GameLogic.exportSaveJson(
    _party(life: 500, purchaseIds: const ['held-only']),
  );
  await storage.setActiveSlot(2);
  await storage.writeActiveRaw(slot2);
  await storage.writeExtra(GameStorage.journalKey, 'swap-stage');
  await storage.writeExtra(GameStorage.stagingKey, held);
  await storage.writeExtra(GameStorage.holdKey, held);
  return (storage: storage, slot2: slot2, held: held);
}

void _expectParty(String? raw, {required int life, required String purchase}) {
  final parsed = GameLogic.importSaveJson(raw!);
  expect(parsed, isNotNull);
  expect(parsed!.lifetimeGoldEarned, life);
  expect(parsed.metaDepth.grantedShopPurchaseIds, contains(purchase));
  expect(parsed.metaDepth.grantedShopPurchaseIds, isNot(contains('held-only')));
}

Future<void> _disposeRecoveryApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpRecoveryApp(
  WidgetTester tester,
  GameDirector director, {
  bool showIntro = false,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MyApp(director: director, autoStartLoop: false, showIntro: showIntro),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _keepSuiteRandom() {
  final logic = GameLogic.random;
  final gear = EquipmentFactory.random;
  GameLogic.random = Random(0x51A7E);
  EquipmentFactory.random = Random(0x51A7E);
  addTearDown(() {
    GameLogic.random = logic;
    EquipmentFactory.random = gear;
  });
}

Future<GameDirector> _bootNamedSlot0(SharedPreferences prefs) async {
  final party = _party(
    life: 80,
    adFree: true,
    purchaseIds: const ['GPA.slot0'],
  ).copyWith(partyName: 'Slot Zero');
  final json = GameLogic.exportSaveJson(party);
  await prefs.setBool('idle_party_slots_ready', true);
  await prefs.setInt('idle_party_active_slot', 0);
  await prefs.setString('idle_party_save_slot_0', json);
  await prefs.setString('idle_party_save_v2', json);
  final director = GameDirector(
    SharedPreferencesGameStorage(preferences: prefs),
    enableSpatialLoop: false,
  );
  await director.boot();
  return director;
}

Future<void> _sequenceRefusedStart() async {
  final previous = SharedPreferencesStorePlatform.instance;
  final store = _NativeCommitStore();
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  final prefs = await SharedPreferences.getInstance();
  GameDirector? director;
  try {
    director = await _bootNamedSlot0(prefs);
    store.stickFailedString = true;
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.stuck',
      ),
      isFalse,
    );
    expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.slot0']);
    director.armNewGameSlot(1);
    expect(
      await director.startNewGame(
        HeroSpecs.starterUnlocked,
        partyName: 'Fresh',
      ),
      isFalse,
    );
    expect(director.activeSaveSlot, 0);
    expect(director.state.partyName, 'Slot Zero');
    expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.slot0']);
    expect(store.durable['flutter.idle_party_save_slot_1'], isNull);
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      isNot(contains('Fresh')),
    );
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      isNot(contains('GPA.stuck')),
    );
    expect(
      await director.startNewGame(
        HeroSpecs.starterUnlocked,
        partyName: 'Fresh',
      ),
      isFalse,
    );
    expect(director.state.partyName, 'Slot Zero');
    expect(store.durable['flutter.idle_party_active_slot'], 0);
    store.releaseStuckString();
    expect(
      await director.startNewGame(
        HeroSpecs.starterUnlocked,
        partyName: 'Fresh',
      ),
      isTrue,
    );
    expect(director.activeSaveSlot, 1);
    expect(director.state.partyName, 'Fresh');
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      contains('GPA.slot0'),
    );
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      isNot(contains('Fresh')),
    );
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      isNot(contains('GPA.stuck')),
    );
    expect(store.durable['flutter.idle_party_save_slot_1'], contains('Fresh'));
    expect(store.durable['flutter.idle_party_active_slot'], 1);
  } finally {
    director?.dispose();
    SharedPreferencesStorePlatform.instance = previous;
    SharedPreferences.resetStatic();
  }
}

Future<void> _sequenceRolledBackStart() async {
  final previous = SharedPreferencesStorePlatform.instance;
  final store = _NativeCommitStore();
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  final prefs = await SharedPreferences.getInstance();
  GameDirector? director;
  try {
    director = await _bootNamedSlot0(prefs);
    store.holdRejectedString = true;
    director.armNewGameSlot(1);
    expect(
      await director.startNewGame(
        HeroSpecs.starterUnlocked,
        partyName: 'Fresh',
      ),
      isFalse,
    );
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.activeSaveSlot, 0);
    expect(director.state.partyName, 'Slot Zero');
    expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.slot0']);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.during',
      ),
      isFalse,
    );
    expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.slot0']);
    expect(await director.retrySaveRecovery(), isFalse);
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.activeSaveSlot, 0);
    final parked = store.durable['flutter.idle_party_save_slot_1'];
    expect(parked == null || !parked.toString().contains('Fresh'), isTrue);
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      contains('GPA.slot0'),
    );
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      isNot(contains('Fresh')),
    );
    store.holdRejectedString = false;
    expect(await director.retrySaveRecovery(), isTrue);
    expect(director.saveRecoveryBlocked, isFalse);
    expect(director.activeSaveSlot, 0);
    expect(director.state.partyName, 'Slot Zero');
    expect(director.state.metaDepth.grantedShopPurchaseIds, ['GPA.slot0']);
    expect(store.durable['flutter.idle_party_active_slot'], 0);
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      contains('GPA.slot0'),
    );
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      isNot(contains('Fresh')),
    );
    expect(
      store.durable['flutter.idle_party_save_slot_0'],
      isNot(contains('GPA.during')),
    );
    final slot1 = store.durable['flutter.idle_party_save_slot_1'];
    expect(slot1 == null || !slot1.toString().contains('Fresh'), isTrue);
  } finally {
    director?.dispose();
    SharedPreferencesStorePlatform.instance = previous;
    SharedPreferences.resetStatic();
  }
}

Future<void> _sequenceJournalReopen() async {
  final storage = InMemoryGameStorage();
  final slot0 = GameLogic.exportSaveJson(
    _party(
      life: 80,
      purchaseIds: const ['GPA.slot0'],
    ).copyWith(partyName: 'Slot Zero'),
  );
  final owned = GameLogic.exportSaveJson(
    _party(
      life: 30,
      purchaseIds: const ['GPA.owned'],
    ).copyWith(partyName: 'Owned'),
  );
  final incoming = GameLogic.exportSaveJson(
    _party(
      life: 4,
      purchaseIds: const ['GPA.incoming'],
    ).copyWith(partyName: 'Incoming'),
  );
  final held = GameLogic.exportSaveJson(
    _party(
      life: 8,
      purchaseIds: const ['GPA.held'],
    ).copyWith(partyName: 'Held'),
  );
  await _writeSlot(storage, 0, slot0);
  await _writeSlot(storage, 2, owned);
  await storage.setActiveSlot(0);
  await storage.writeExtra(GameStorage.journalKeyFor(2), 'swap-stage@2');
  await storage.writeExtra(GameStorage.stagingKeyFor(2), incoming);
  await storage.writeExtra(GameStorage.holdKeyFor(2), held);
  final director = GameDirector(storage, enableSpatialLoop: false);
  try {
    await director.boot();
    expect(director.saveRecoveryBlocked, isFalse);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isTrue,
    );
    final kept = await storage.loadSlotRaw(0);
    expect(kept, contains('GPA.slot0'));
    expect(kept, contains('GPA.fresh'));
    expect(await director.openSaveSlot(2), isTrue);
    expect(director.activeSaveSlot, 2);
    expect(director.state.partyName, 'Incoming');
    expect(
      director.state.metaDepth.grantedShopPurchaseIds,
      contains('GPA.incoming'),
    );
    expect(
      director.state.metaDepth.grantedShopPurchaseIds,
      isNot(contains('GPA.fresh')),
    );
    expect(await storage.loadSlotRaw(0), kept);
    expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
    expect(await storage.loadExtra(GameStorage.displacedKeyFor(2)), held);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.after',
      ),
      isTrue,
    );
  } finally {
    director.dispose();
  }
  final again = GameDirector(storage, enableSpatialLoop: false);
  try {
    await again.boot();
    expect(again.saveRecoveryBlocked, isFalse);
    expect(again.activeSaveSlot, 2);
    expect(again.state.partyName, 'Incoming');
    expect(
      again.state.metaDepth.grantedShopPurchaseIds,
      contains('GPA.incoming'),
    );
    expect(again.state.metaDepth.grantedShopPurchaseIds, contains('GPA.after'));
    expect(await storage.loadSlotRaw(0), contains('GPA.fresh'));
    expect(await storage.loadSlotRaw(0), isNot(contains('GPA.after')));
    expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), isNull);
  } finally {
    again.dispose();
  }
}

Future<void> _sequenceUnresolvedJournal() async {
  final storage = InMemoryGameStorage();
  final slot0 = GameLogic.exportSaveJson(
    _party(
      life: 80,
      purchaseIds: const ['GPA.slot0'],
    ).copyWith(partyName: 'Slot Zero'),
  );
  final owned = GameLogic.exportSaveJson(
    _party(
      life: 30,
      purchaseIds: const ['GPA.owned'],
    ).copyWith(partyName: 'Owned'),
  );
  await _writeSlot(storage, 0, slot0);
  await _writeSlot(storage, 2, owned);
  await storage.setActiveSlot(0);
  await storage.writeExtra(GameStorage.journalKeyFor(2), 'nope@2');
  final director = GameDirector(storage, enableSpatialLoop: false);
  try {
    await director.boot();
    expect(director.saveRecoveryBlocked, isFalse);
    final kept = await storage.loadSlotRaw(0);
    expect(await director.openSaveSlot(2), isFalse);
    expect(director.activeSaveSlot, 0);
    expect(director.state.partyName, 'Slot Zero');
    expect(await storage.loadSlotRaw(2), owned);
    expect(await storage.loadSlotRaw(0), kept);
    expect(await storage.loadExtra(GameStorage.journalKeyFor(2)), 'nope@2');
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isTrue,
    );
    expect(await storage.loadSlotRaw(2), owned);
    expect(await storage.loadSlotRaw(0), contains('GPA.fresh'));
    expect(await storage.loadSlotRaw(2), isNot(contains('GPA.fresh')));
  } finally {
    director.dispose();
  }
}

Future<void> _sequenceOnlyJournal() async {
  final previous = SharedPreferencesStorePlatform.instance;
  final store = _NativeCommitStore();
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  final prefs = await SharedPreferences.getInstance();
  GameDirector? director;
  try {
    final owned = GameLogic.exportSaveJson(
      _party(
        life: 30,
        purchaseIds: const ['GPA.owned'],
      ).copyWith(partyName: 'Owned'),
    );
    final incoming = GameLogic.exportSaveJson(
      _party(
        life: 4,
        purchaseIds: const ['GPA.incoming'],
      ).copyWith(partyName: 'Incoming'),
    );
    final held = GameLogic.exportSaveJson(
      _party(
        life: 8,
        purchaseIds: const ['GPA.held'],
      ).copyWith(partyName: 'Held'),
    );
    await prefs.setBool('idle_party_slots_ready', true);
    await prefs.setInt('idle_party_active_slot', 1);
    await prefs.setString('idle_party_save_v2', 'mirror');
    await prefs.setString('idle_party_save_slot_2', owned);
    await prefs.setString(GameStorage.journalKeyFor(2), 'swap-stage@2');
    await prefs.setString(GameStorage.stagingKeyFor(2), incoming);
    await prefs.setString(GameStorage.holdKeyFor(2), held);
    director = GameDirector(
      SharedPreferencesGameStorage(preferences: prefs),
      enableSpatialLoop: false,
    );
    await director.boot();
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.safeRecoverySlots, [2]);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.during',
      ),
      isFalse,
    );
    expect(prefs.getString('idle_party_save_slot_2'), owned);
    expect(prefs.getString(GameStorage.journalKeyFor(2)), 'swap-stage@2');
    expect(await director.openSafeRecoverySlot(2), RecoverySlotOpen.ready);
    expect(director.saveRecoveryBlocked, isFalse);
    expect(director.activeSaveSlot, 2);
    expect(director.state.partyName, 'Incoming');
    expect(
      director.state.metaDepth.grantedShopPurchaseIds,
      contains('GPA.incoming'),
    );
    expect(
      director.state.metaDepth.grantedShopPurchaseIds,
      isNot(contains('GPA.during')),
    );
    expect(prefs.getString(GameStorage.journalKeyFor(2)), isNull);
    expect(prefs.getString(GameStorage.displacedKeyFor(2)), held);
    expect(prefs.getString('idle_party_save_slot_0'), anyOf(isNull, isEmpty));
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.after',
      ),
      isTrue,
    );
    final playing = GameDirector(
      SharedPreferencesGameStorage(preferences: prefs),
      enableSpatialLoop: false,
    );
    try {
      await playing.boot();
      expect(playing.activeSaveSlot, 2);
      expect(playing.state.partyName, 'Incoming');
      expect(
        playing.state.metaDepth.grantedShopPurchaseIds,
        contains('GPA.incoming'),
      );
      expect(
        playing.state.metaDepth.grantedShopPurchaseIds,
        contains('GPA.after'),
      );
      expect(prefs.getString(GameStorage.journalKeyFor(2)), isNull);
    } finally {
      playing.dispose();
    }
  } finally {
    director?.dispose();
    SharedPreferencesStorePlatform.instance = previous;
    SharedPreferences.resetStatic();
  }
}

/// Selected slot 0 owns an unknown phase. Slot 2 parses and has no journal.
/// Before the fix, boot and every RETRY clear the escape list.
Future<void> _sequenceUnknownPhaseEscape() async {
  final storage = InMemoryGameStorage();
  final owned = GameLogic.exportSaveJson(
    _party(
      life: 30,
      purchaseIds: const ['GPA.owned'],
    ).copyWith(partyName: 'Owned'),
  );
  final healthy = GameLogic.exportSaveJson(
    _party(
      life: 70,
      purchaseIds: const ['GPA.keep'],
    ).copyWith(partyName: 'Healthy'),
  );
  final held = GameLogic.exportSaveJson(
    _party(
      life: 8,
      purchaseIds: const ['GPA.held'],
    ).copyWith(partyName: 'Held'),
  );
  await _writeSlot(storage, 0, owned);
  await _writeSlot(storage, 2, healthy);
  await storage.setActiveSlot(0);
  await storage.writeExtra(GameStorage.journalKey, 'nope@0');
  await storage.writeExtra(GameStorage.stagingKey, owned);
  await storage.writeExtra(GameStorage.holdKey, held);
  final director = GameDirector(storage, enableSpatialLoop: false);
  try {
    await director.boot();
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.activeSaveSlot, 0);
    expect(director.safeRecoverySlots, [2]);
    expect(director.safeRecoverySlots, isNot(contains(0)));
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope@0');
    expect(await storage.loadExtra(GameStorage.stagingKey), owned);
    expect(await storage.loadExtra(GameStorage.holdKey), held);
    expect(await storage.loadSlotRaw(0), owned);
    expect(await storage.loadSlotRaw(2), healthy);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.during',
      ),
      isFalse,
    );
    expect(await director.openSafeRecoverySlot(0), RecoverySlotOpen.refused);
    expect(await director.retrySaveRecovery(), isFalse);
    expect(await director.retrySaveRecovery(), isFalse);
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.safeRecoverySlots, [2]);
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope@0');
    expect(await storage.loadExtra(GameStorage.stagingKey), owned);
    expect(await storage.loadExtra(GameStorage.holdKey), held);
    expect(await storage.loadSlotRaw(0), owned);
    expect(await director.openSafeRecoverySlot(2), RecoverySlotOpen.ready);
    expect(director.saveRecoveryBlocked, isFalse);
    expect(director.activeSaveSlot, 2);
    expect(director.state.partyName, 'Healthy');
    expect(
      director.state.metaDepth.grantedShopPurchaseIds,
      contains('GPA.keep'),
    );
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isTrue,
    );
    expect(await storage.loadSlotRaw(0), owned);
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope@0');
    expect(await storage.loadExtra(GameStorage.stagingKey), owned);
    expect(await storage.loadExtra(GameStorage.holdKey), held);
    expect(await director.openSaveSlot(0), isFalse);
    expect(director.activeSaveSlot, 2);
    expect(await storage.loadSlotRaw(0), owned);
    expect(_rawHas(await storage.loadSlotRaw(2), 'GPA.fresh'), isTrue);
    expect(_rawHas(await storage.loadSlotRaw(2), 'GPA.keep'), isTrue);
    expect(_rawHas(await storage.loadSlotRaw(0), 'GPA.fresh'), isFalse);
    final playing = GameDirector(storage, enableSpatialLoop: false);
    try {
      await playing.boot();
      expect(playing.saveRecoveryBlocked, isFalse);
      expect(playing.activeSaveSlot, 2);
      expect(playing.state.partyName, 'Healthy');
      expect(
        playing.state.metaDepth.grantedShopPurchaseIds,
        containsAll(['GPA.keep', 'GPA.fresh']),
      );
      expect(await storage.loadExtra(GameStorage.journalKey), 'nope@0');
      expect(await storage.loadExtra(GameStorage.stagingKey), owned);
      expect(await storage.loadExtra(GameStorage.holdKey), held);
      expect(await storage.loadSlotRaw(0), owned);
      expect(_rawHas(await storage.loadSlotRaw(0), 'GPA.fresh'), isFalse);
    } finally {
      playing.dispose();
    }
  } finally {
    director.dispose();
  }
}

/// An unknown phase with no other readable file stays closed. The owner
/// is not offered as if this build could finish the phase.
Future<void> _sequenceUnknownPhaseAlone() async {
  final storage = InMemoryGameStorage();
  final owned = GameLogic.exportSaveJson(
    _party(
      life: 30,
      purchaseIds: const ['GPA.owned'],
    ).copyWith(partyName: 'Owned'),
  );
  final held = GameLogic.exportSaveJson(
    _party(
      life: 8,
      purchaseIds: const ['GPA.held'],
    ).copyWith(partyName: 'Held'),
  );
  await _writeSlot(storage, 0, owned);
  await storage.setActiveSlot(0);
  await storage.writeExtra(GameStorage.journalKey, 'nope@0');
  await storage.writeExtra(GameStorage.stagingKey, owned);
  await storage.writeExtra(GameStorage.holdKey, held);
  final director = GameDirector(storage, enableSpatialLoop: false);
  try {
    await director.boot();
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.safeRecoverySlots, isEmpty);
    expect(await director.retrySaveRecovery(), isFalse);
    expect(await director.retrySaveRecovery(), isFalse);
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.safeRecoverySlots, isEmpty);
    expect(await director.openSafeRecoverySlot(0), RecoverySlotOpen.refused);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isFalse,
    );
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope@0');
    expect(await storage.loadExtra(GameStorage.stagingKey), owned);
    expect(await storage.loadExtra(GameStorage.holdKey), held);
    expect(await storage.loadSlotRaw(0), owned);
    expect(_rawHas(await storage.loadSlotRaw(0), 'GPA.fresh'), isFalse);
  } finally {
    director.dispose();
  }
}

/// Two files match one unnamed journal. RETRY does not finish it, and the
/// matching files are not offered as a recovered party.
Future<void> _sequenceAmbiguousStays() async {
  final storage = InMemoryGameStorage();
  final shared = GameLogic.exportSaveJson(
    _party(
      life: 11,
      purchaseIds: const ['GPA.shared'],
    ).copyWith(partyName: 'Shared'),
  );
  final held = GameLogic.exportSaveJson(
    _party(
      life: 13,
      purchaseIds: const ['GPA.held'],
    ).copyWith(partyName: 'Held'),
  );
  final free = GameLogic.exportSaveJson(
    _party(
      life: 14,
      purchaseIds: const ['GPA.free'],
    ).copyWith(partyName: 'Free'),
  );
  await _writeSlot(storage, 0, shared);
  await _writeSlot(storage, 2, shared);
  await _writeSlot(storage, 4, free);
  await storage.setActiveSlot(0);
  await storage.writeExtra(GameStorage.stagingKey, shared);
  await storage.writeExtra(GameStorage.holdKey, held);
  await storage.writeExtra(GameStorage.journalKey, 'nope');
  final director = GameDirector(storage, enableSpatialLoop: false);
  try {
    await director.boot();
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.safeRecoverySlots, isNot(contains(0)));
    expect(director.safeRecoverySlots, isNot(contains(2)));
    expect(director.safeRecoverySlots, contains(4));
    expect(await director.retrySaveRecovery(), isFalse);
    expect(director.saveRecoveryBlocked, isTrue);
    expect(director.safeRecoverySlots, isNot(contains(0)));
    expect(director.safeRecoverySlots, isNot(contains(2)));
    expect(await storage.loadExtra(GameStorage.journalKey), 'nope');
    expect(await storage.loadExtra(GameStorage.stagingKey), shared);
    expect(await storage.loadExtra(GameStorage.holdKey), held);
    expect(await storage.loadSlotRaw(0), shared);
    expect(await storage.loadSlotRaw(2), shared);
    expect(
      await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.fresh',
      ),
      isFalse,
    );
    expect(await director.openSafeRecoverySlot(0), RecoverySlotOpen.refused);
    expect(await director.openSafeRecoverySlot(2), RecoverySlotOpen.refused);
    expect(_rawHas(await storage.loadSlotRaw(0), 'GPA.fresh'), isFalse);
    expect(_rawHas(await storage.loadSlotRaw(2), 'GPA.fresh'), isFalse);
  } finally {
    director.dispose();
  }
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

Future<({_RejectingPrefsStore store, SharedPreferences prefs})>
_installRejectingPrefs() async {
  final store = _RejectingPrefsStore();
  final previous = SharedPreferencesStorePlatform.instance;
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  addTearDown(() {
    SharedPreferencesStorePlatform.instance = previous;
    SharedPreferences.resetStatic();
  });
  final prefs = await SharedPreferences.getInstance();
  return (store: store, prefs: prefs);
}

class _RejectingPrefsStore extends InMemorySharedPreferencesStore {
  _RejectingPrefsStore() : super.empty();

  bool rejectWrites = false;
  bool throwWrites = false;
  bool rejectMirror = false;
  bool failRemoves = false;
  bool failCorruptCopy = false;
  bool throwCorruptCopy = false;

  /// The next N [getAll] calls throw. Later reads see the backing map.
  int failGets = 0;

  @override
  Future<Map<String, Object>> getAll() async {
    if (failGets > 0) {
      failGets--;
      throw StateError('prefs unavailable');
    }
    return super.getAll();
  }

  @override
  Future<bool> remove(String key) async {
    if (failRemoves) return false;
    return super.remove(key);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('corrupt') && (failCorruptCopy || throwCorruptCopy)) {
      if (throwCorruptCopy) throw StateError('corrupt copy failed');
      return false;
    }
    if (throwWrites && valueType == 'String') {
      throw StateError('disk full');
    }
    if (rejectMirror && key.endsWith('idle_party_save_v2')) return false;
    if (rejectWrites) return false;
    return super.setValue(valueType, key, value);
  }
}

/// Native memory and disk are separate. A string commit updates memory and
/// returns false without copying to disk, which is what Android's
/// SharedPreferencesImpl.commit can do. This is not a device or an OS kill.
class _NativeCommitStore extends InMemorySharedPreferencesStore {
  _NativeCommitStore() : super.empty();

  final Map<String, Object> _disk = <String, Object>{};
  bool failStringCommit = false;

  Map<String, Object> get durable => Map<String, Object>.from(_disk);

  /// The first string commit updates memory and returns false. Later string
  /// commits return false without changing memory, so a restore cannot hide
  /// the rejected value. A successful commit of any other key copies the
  /// whole memory map to disk, which is what Android's commit() writes.
  bool stickFailedString = false;

  /// Every string commit updates memory and returns false, and remove
  /// returns false without changing memory. Models a commit that landed
  /// in the native map and did not reach disk, including the restore.
  /// This is not a device or an OS kill.
  bool holdRejectedString = false;
  bool _stuck = false;

  void releaseStuckString() {
    stickFailedString = false;
    _stuck = false;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (holdRejectedString && valueType == 'String') {
      await super.setValue(valueType, key, value);
      return false;
    }
    if (stickFailedString && valueType == 'String') {
      if (!_stuck) {
        await super.setValue(valueType, key, value);
        _stuck = true;
      }
      return false;
    }
    await super.setValue(valueType, key, value);
    if (failStringCommit && valueType == 'String') return false;
    await _flushMemoryToDisk();
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (holdRejectedString) return false;
    final removed = await super.remove(key);
    if (removed && !stickFailedString && !failStringCommit) {
      await _flushMemoryToDisk();
    } else if (removed) {
      _disk.remove(key);
    }
    return removed;
  }

  @override
  Future<bool> clear() async {
    final cleared = await super.clear();
    _disk.clear();
    return cleared;
  }

  Future<void> _flushMemoryToDisk() async {
    final memory = await super.getAll();
    _disk
      ..clear()
      ..addAll(memory);
  }

  /// Load the next process from disk. The native map is replaced first.
  Future<void> restartFromDisk() async {
    final saved = Map<String, Object>.from(_disk);
    await super.clear();
    for (final entry in saved.entries) {
      await super.setValue(_typeOf(entry.value), entry.key, entry.value);
    }
    _disk
      ..clear()
      ..addAll(saved);
  }

  String _typeOf(Object value) {
    if (value is bool) return 'Bool';
    if (value is int) return 'Int';
    if (value is double) return 'Double';
    if (value is List) return 'StringList';
    return 'String';
  }
}
