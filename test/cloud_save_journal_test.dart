import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/play_games_bridge.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/save_swap.dart';
import 'package:idle_party/core/shop_billing.dart';
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
        await expectLater(
          SaveSwap.commitSwap(
            storage: storage,
            newActiveJson: GameLogic.exportSaveJson(parked),
            newDisplacedJson: GameLogic.exportSaveJson(current),
          ),
          throwsA(isA<SimulatedSaveKill>()),
        );
        final restarted = InMemoryGameStorage();
        restarted.restoreDurableBytes(storage.durableBytes());
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
