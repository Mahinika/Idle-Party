import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_rewarded.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/mission_board.dart';
import 'package:idle_party/core/play_games_bridge.dart';
import 'package:idle_party/core/play_games_scores.dart';
import 'package:idle_party/core/save_needs_update.dart';
import 'package:idle_party/core/ump_consent_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('save version guard', () {
    String encode(GameState state, {required int version, int? gold}) {
      final json = state.toJson();
      json['version'] = version;
      if (gold != null) json['gold'] = gold;
      return jsonEncode(json);
    }

    GameState sample() => GameLogic.createInitialState(
      now: DateTime.utc(2026, 11, 24),
      partyName: 'Future Party',
    );

    test('v4 and older still load', () {
      final state = sample().copyWith(gold: 80, lifetimeGoldEarned: 80);
      for (final version in <int>[2, 3, 4]) {
        final loaded = GameLogic.stateFromJson(
          jsonDecode(encode(state, version: version)) as Map<String, dynamic>,
        );
        expect(loaded.gold, 80, reason: 'version $version');
        expect(loaded.partyName, 'Future Party', reason: 'version $version');
      }
      final v1 = GameLogic.stateFromJson(
        jsonDecode(File('test/fixtures/save_v1.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(v1.gold, 1450);
      expect(
        GameLogic.importSaveJson(encode(state, version: GameState.saveVersion)),
        isNotNull,
      );
    });

    test('a newer local save is refused and not rewritten', () async {
      final raw = encode(sample(), version: 5, gold: 4242);
      SharedPreferences.setMockInitialValues({
        'idle_party_slots_ready': true,
        'idle_party_active_slot': 0,
        'idle_party_save_slot_0': raw,
      });
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesGameStorage(preferences: prefs);

      expect(
        () => GameLogic.stateFromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        ),
        throwsA(isA<SaveNeedsAppUpdate>()),
      );
      expect(await storage.load(), isNull);
      expect(prefs.getString('idle_party_save_slot_0'), raw);
      expect(prefs.getString('idle_party_save_v2'), isNull);
      expect(prefs.getString('idle_party_save_v2_corrupt'), isNull);
      expect(prefs.getString('idle_party_save_slot_0_corrupt'), isNull);
      expect(GameLogic.takeSaveRefusal(), SaveNeedsAppUpdate.message);

      final memory = InMemoryGameStorage();
      memory.debugPlantActiveRaw(raw);
      final director = GameDirector(memory, enableSpatialLoop: false);
      addTearDown(director.dispose);
      await director.boot();
      expect(director.saveRecoveryMessage, SaveNeedsAppUpdate.message);
      expect(director.hasExistingSave, isFalse);
      expect(await director.debugTryPersist(), isTrue);
      expect(await memory.loadActiveRaw(), raw);
    });

    test('a newer cloud payload is refused and not rewritten', () async {
      addTearDown(PlayGamesBridge.debugResetCloudHooks);
      final payload = encode(sample(), version: 5, gold: 7777);
      var uploads = 0;
      String? uploaded;
      PlayGamesBridge.debugLoadCloud = () async =>
          PlayGamesBridge.decodeCloudPayload(payload);
      PlayGamesBridge.debugSaveCloud = (state) async {
        uploads++;
        uploaded = GameLogic.exportSaveJson(state);
        return true;
      };

      final read = await PlayGamesBridge.loadCloud();
      expect(read.kind, CloudReadKind.needsUpdate);
      expect(read.state, isNull);
      expect(read.blocksAutomaticUpload, isTrue);
      expect(PlayGamesBridge.cloudWriteBlocked, isTrue);
      final plan = PlayGamesScores.planSignIn(
        read: read,
        hasExistingSave: false,
        local: sample(),
        localIsReplaceable: true,
      );
      expect(plan.install, isFalse);
      expect(plan.upload, isFalse);
      expect(plan.toast, SaveNeedsAppUpdate.message);
      expect(
        await PlayGamesBridge.saveCloud(sample(), explicit: true),
        isFalse,
      );
      expect(uploads, 0);
      expect(uploaded, isNull);
      expect(payload, contains('"version":5'));
      expect(payload, contains('7777'));

      final current = PlayGamesBridge.decodeCloudPayload(
        encode(sample(), version: GameState.saveVersion, gold: 12),
      );
      expect(current.kind, CloudReadKind.ready);
      expect(current.state!.gold, 12);
    });

    test('a newer clipboard import is refused and not rewritten', () async {
      final seed = sample().copyWith(gold: 15, lifetimeGoldEarned: 15);
      final storage = InMemoryGameStorage(seed);
      final before = await storage.loadActiveRaw();
      final director = GameDirector(
        storage,
        initialState: seed,
        enableSpatialLoop: false,
      );
      addTearDown(director.dispose);

      final incoming = encode(sample(), version: 5, gold: 99999);
      expect(await director.importSaveJson(incoming), isFalse);
      expect(director.state.gold, 15);
      expect(director.state.partyName, 'Future Party');
      expect(director.toast, SaveNeedsAppUpdate.message);
      expect(await storage.loadActiveRaw(), before);
      expect(before, isNot(contains('"version":5')));
    });
  });

  group('UMP consent timeout', () {
    test('the timeout does not cover the form, then consent resyncs', () async {
      var phase = 'idle';
      final gate = runUmpConsentGate(
        updateTimeout: const Duration(milliseconds: 40),
        requestUpdate: (callbacks) => callbacks.onSuccess(),
        showForm: () async {
          phase = 'form';
          await Future<void>.delayed(const Duration(milliseconds: 120));
          phase = 'form-closed';
        },
        resync: () async {
          phase = 'resync';
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(phase, 'form');
      await gate;
      expect(phase, 'resync');
    });

    test(
      'a silent update stops at the timeout and does not open the form',
      () async {
        var showed = false;
        var resynced = false;
        var done = false;
        final gate = runUmpConsentGate(
          updateTimeout: const Duration(milliseconds: 40),
          requestUpdate: (callbacks) {},
          showForm: () async {
            showed = true;
          },
          resync: () async {
            resynced = true;
          },
        ).whenComplete(() => done = true);
        await Future<void>.delayed(const Duration(milliseconds: 15));
        expect(done, isFalse);
        expect(showed, isFalse);
        await gate;
        expect(done, isTrue);
        expect(showed, isFalse);
        expect(resynced, isFalse);
      },
    );

    test('an update that arrives after the timeout still resyncs', () async {
      late UmpUpdateCallbacks callbacks;
      var showed = false;
      var resynced = false;
      var done = false;
      final gate = runUmpConsentGate(
        updateTimeout: const Duration(milliseconds: 30),
        requestUpdate: (incoming) => callbacks = incoming,
        showForm: () async {
          showed = true;
          await Future<void>.delayed(const Duration(milliseconds: 40));
        },
        resync: () async {
          resynced = true;
        },
      ).whenComplete(() => done = true);
      await gate;
      expect(done, isTrue);
      expect(showed, isFalse);
      expect(resynced, isFalse);
      callbacks.onSuccess();
      expect(showed, isTrue);
      expect(resynced, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(resynced, isTrue);
    });

    test('a failed update and a no-form request do not resync', () async {
      var calls = 0;
      await runUmpConsentGate(
        updateTimeout: const Duration(milliseconds: 20),
        requestUpdate: (callbacks) => callbacks.onError(StateError('ump')),
        showForm: () async => calls++,
        resync: () async => calls++,
      );
      await runUmpConsentGate(
        updateTimeout: const Duration(milliseconds: 20),
        showFormOnSuccess: false,
        requestUpdate: (callbacks) => callbacks.onSuccess(),
        showForm: () async => calls++,
        resync: () async => calls++,
      );
      expect(calls, 0);
    });
  });

  group('rewarded preload and tap guard', () {
    test('a preload older than 55 minutes is disposed', () {
      final loaded = DateTime.utc(2026, 11, 24, 10);
      expect(
        rewardedPreloadIsStale(loaded, loaded.add(const Duration(minutes: 55))),
        isFalse,
      );
      expect(
        rewardedPreloadIsStale(
          loaded,
          loaded.add(const Duration(minutes: 55, milliseconds: 1)),
        ),
        isTrue,
      );
      var disposed = 0;
      expect(
        takeFreshRewardedPreload<String>(
          ad: 'stale',
          loadedAt: loaded,
          now: loaded.add(const Duration(minutes: 56)),
          dispose: (ad) {
            expect(ad, 'stale');
            disposed++;
          },
        ),
        isNull,
      );
      expect(disposed, 1);
      expect(
        takeFreshRewardedPreload<String>(
          ad: 'fresh',
          loadedAt: loaded,
          now: loaded.add(const Duration(minutes: 10)),
          dispose: (_) => disposed++,
        ),
        'fresh',
      );
      expect(
        takeFreshRewardedPreload<String>(
          ad: 'untimed',
          loadedAt: null,
          now: loaded,
          dispose: (_) => disposed++,
        ),
        isNull,
      );
      expect(disposed, 2);
    });

    test('a second tap while an ad is open grants once', () async {
      final director = GameDirector.preview(
        initialState: GameLogic.createInitialState(
          now: DateTime.now().toUtc(),
        ).copyWith(bossVictories: 1),
      );
      addTearDown(director.dispose);
      addTearDown(AdRewarded.debugReset);
      await director.boot();
      AdRewarded.debugAdsAvailable = true;

      Future<void> oneGrant({
        required Future<void> Function() tap,
        required int Function() read,
      }) async {
        final gate = Completer<AdWatchResult>();
        var shows = 0;
        AdRewarded.debugShowRewarded = ({required String placement}) {
          shows++;
          return gate.future;
        };
        final first = tap();
        final second = tap();
        await Future<void>.delayed(Duration.zero);
        expect(shows, 1);
        expect(read(), 0);
        gate.complete(AdWatchResult.rewarded);
        await first;
        await second;
        expect(shows, 1);
        expect(read(), 1);
        AdRewarded.debugReset();
        AdRewarded.debugAdsAvailable = true;
      }

      final campBefore = GameLogic.campAdClaimsToday(director.state);
      await oneGrant(
        tap: director.watchCampAd,
        read: () => GameLogic.campAdClaimsToday(director.state) - campBefore,
      );
      final ticketsBefore = director.state.metaDepth.adTickets;
      await oneGrant(
        tap: director.watchPowerupAd,
        read: () => director.state.metaDepth.adTickets - ticketsBefore,
      );
      final slot =
          MissionBoard.canRerollMission(
            director.state.missions[MissionBoard.dailySlot],
            MissionBoard.dailySlot,
          )
          ? MissionBoard.dailySlot
          : MissionBoard.sideSlot;
      expect(
        MissionBoard.canRerollMission(director.state.missions[slot], slot),
        isTrue,
      );
      final rerollsBefore = director.state.metaDepth.questRerollsToday;
      await oneGrant(
        tap: () => director.rerollQuestSlot(slot),
        read: () => director.state.metaDepth.questRerollsToday - rerollsBefore,
      );

      final gold = director.state.gold;
      final gate = Completer<AdWatchResult>();
      AdRewarded.debugShowRewarded = ({required String placement}) =>
          gate.future;
      final welcome = director.watchWelcomeBackGoldAd(40);
      final again = director.watchWelcomeBackGoldAd(40);
      expect(await again, isFalse);
      expect(director.state.gold, gold);
      gate.complete(AdWatchResult.rewarded);
      expect(await welcome, isTrue);
      expect(director.state.gold, gold + 40);
      expect(await director.watchWelcomeBackGoldAd(40), isFalse);
      expect(director.state.gold, gold + 40);
    });
  });
}
