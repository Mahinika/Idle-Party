import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/offline_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'dungeon autosave stamps lastUpdated so a kill replays only the gap',
    () async {
      final seed = GameLogic.createInitialState();
      final storage = InMemoryGameStorage(seed);
      final director = GameDirector(
        storage,
        initialState: seed,
        enableSpatialLoop: false,
      );
      addTearDown(director.dispose);
      await director.boot(deferCombatLoop: true);
      director.enterDungeon();
      expect(await director.debugTryPersist(), isTrue);

      final stale = DateTime.now().subtract(const Duration(minutes: 12));
      director.debugHoldSave(
        director.state.copyWith(gold: 4794, essence: 420, lastUpdated: stale),
      );
      expect(director.state.inDungeon, isTrue);
      expect(await director.debugCommitDungeonAutosave(), isTrue);

      final saved = await storage.load();
      expect(saved, isNotNull);
      expect(saved!.gold, 4794);
      expect(saved.essence, 420);
      expect(saved.inDungeon, isTrue);
      expect(saved.lastUpdated.isAfter(stale), isTrue);
      final gap = DateTime.now().difference(saved.lastUpdated);
      expect(gap.inSeconds, lessThan(5));
      expect(gap.inSeconds, lessThan(const Duration(minutes: 12).inSeconds));

      final replay = OfflineProgress.applyOfflineProgress(saved, gap);
      expect(replay.essenceGained, 0);
      expect(replay.state.essence, 420);

    final revived = GameDirector(storage, enableSpatialLoop: false);
      addTearDown(revived.dispose);
      await revived.boot(deferCombatLoop: true);
      expect(revived.state.essence, 420);
      expect(revived.state.gold, 4794);
    },
  );

  test(
    'lifecycle flush persists the current wallet without pausing on a shade',
    () async {
      final seed = GameLogic.createInitialState();
      final storage = InMemoryGameStorage(seed);
      final director = GameDirector(
        storage,
        initialState: seed,
        enableSpatialLoop: false,
      );
      addTearDown(director.dispose);
      await director.boot(deferCombatLoop: true);
      director.enterDungeon();
      expect(await director.debugTryPersist(), isTrue);

      director.debugHoldSave(director.state.copyWith(gold: 2222, essence: 77));
      final frame = director.visualFrame;
      expect(await director.flushLifecycleWallet(), isTrue);
      expect(director.appPaused, isFalse);
      director.spatialTick();
      expect(director.visualFrame, greaterThan(frame));

      final shaded = await storage.load();
      expect(shaded, isNotNull);
      expect(shaded!.gold, 2222);
      expect(shaded.essence, 77);
      expect(
        DateTime.now().difference(shaded.lastUpdated).inSeconds,
        lessThan(5),
      );

      director.debugHoldSave(director.state.copyWith(gold: 3333, essence: 88));
      await director.setAppPaused(true);
      expect(director.appPaused, isTrue);
      final pausedFrame = director.visualFrame;
      director.spatialTick();
      expect(director.visualFrame, pausedFrame);

      final paused = await storage.load();
      expect(paused, isNotNull);
      expect(paused!.gold, 3333);
      expect(paused.essence, 88);
    },
  );
}
