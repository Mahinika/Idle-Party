part of 'game_director.dart';

/// Opening another file while an unmatched copy is still on this device.
enum RecoverySlotOpen {
  /// Not a safe choice. Recovery stays up.
  refused,

  /// An existing file was loaded and saving is on.
  ready,

  /// Empty file. Party setup must save before any fight.
  needsNewGame,
}

/// Save — extracted from GameDirector.
extension GameDirectorSave on GameDirector {
  void _persist() {
    // Title-screen placeholder and boot-failure empty state must not overwrite
    // a real save (hub idle used to write after 25s).
    if (!_hasExistingSave) return;
    if (_durableSaveBlocked) {
      _saveChain = _saveChain.then((_) async => false);
      return;
    }
    // Snapshot when this turn runs, not when it was queued, and write those
    // bytes. A later cloud install cannot be overwritten by a stale capture,
    // and a grant cannot change the bytes after this turn has read them.
    _saveChain = _saveChain.then((_) async {
      if (_durableSaveBlocked) return false;
      final snapshot = _stampCloudClock(_state);
      _state = snapshot;
      try {
        final ok = await _storage.save(snapshot);
        if (!ok) {
          DebugPlayLog.event('save', 'write failed: setString returned false');
          debugPrint('save failed: setString returned false');
          return false;
        }
        PlayGamesBridge.notePartyPower(
          score: GameLogic.partyPowerScore(snapshot),
          partyName: snapshot.partyName,
        );
        PlayGamesBridge.scheduleCloudUpload(snapshot);
        unawaited(PlayGamesBridge.flushPendingScores());
        return true;
      } catch (e, st) {
        DebugPlayLog.event('save', 'write failed: $e');
        debugPrint('save failed: $e\n$st');
        return false;
      }
    });
  }

  GameState _stampCloudClock(GameState state) {
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        cloudSaveUpdatedMs: PlayGamesScores.monotonicCloudStamp(
          previousMs: state.metaDepth.cloudSaveUpdatedMs,
          nowMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// One save mutation at a time. The action reads [_state] when it starts,
  /// after every earlier persist, grant, and cloud install has finished.
  Future<T> _enqueueSave<T>(Future<T> Function() action) {
    final done = Completer<T>();
    _saveChain = _saveChain.then((_) async {
      try {
        final value = await action();
        if (!done.isCompleted) done.complete(value);
        if (value is bool) return value;
        return true;
      } catch (e, st) {
        debugPrint('save turn failed: $e\n$st');
        _blockSaveRecovery(
          'Saving is paused. The last save was interrupted before it could be confirmed.',
        );
        if (!done.isCompleted) {
          if (false is T) {
            done.complete(false as T);
          } else {
            done.completeError(e, st);
          }
        }
        return false;
      }
    });
    return done.future;
  }

  /// False when this write did not land.
  Future<bool> _persistFlush() {
    _persist();
    return _saveChain;
  }

  void _applyFunnelTick(FunnelTick tick, {bool persist = true}) {
    if (identical(tick.state, _state) && tick.events.isEmpty) return;
    _state = tick.state;
    for (final hit in tick.events) {
      unawaited(
        AppAnalytics.logEvent(hit.name, hit.params.isEmpty ? null : hit.params),
      );
    }
    if (persist && _hasExistingSave) {
      unawaited(_persistFlush());
    }
  }

  void _noteFunnelSession({required bool newInstall, DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (_funnelSessionReadyMs == 0) {
      _funnelSessionReadyMs = clock.millisecondsSinceEpoch;
    }
    final tick = newInstall
        ? FunnelAnalytics.onNewInstall(_state, clock)
        : FunnelAnalytics.onExistingSession(_state, clock);
    _applyFunnelTick(tick, persist: false);
  }

  void _noteAppColdStart() {
    if (_appColdStartLogged) return;
    _appColdStartLogged = true;
    final days = AnalyticsEvents.daysSinceInstallMs(
      _state.metaDepth.funnelInstallMs,
      DateTime.now(),
    );
    unawaited(AppAnalytics.appColdStart(daysSinceInstall: days));
    _syncMeasurementContext();
  }

  void _syncMeasurementContext() {
    final zone = _state.inDungeon ? _state.dungeonId : 'hub';
    AppAnalytics.syncCrashContext(
      zoneId: zone,
      appVersion: BuildStamp.versionLabel(ChangelogCatalog.currentVersion),
    );
  }

  /// Title NEW GAME on an empty file. Ignored once [startNewGame] runs.
  void armNewGameSlot(int index) {
    _pendingNewGameSlot = index.clamp(0, GameStorage.slotCount - 1);
  }

  /// Point the next import / cloud write at [index] without loading it yet.
  ///
  /// Queued with grants and restores. Refused while recovery is unfinished
  /// so the import cannot land on a different file than the grant.
  Future<void> armImportSlot(int index) {
    return _enqueueSave<void>(() async {
      if (_durableSaveBlocked) return;
      final slot = index.clamp(0, GameStorage.slotCount - 1);
      if (await _slotBytesUnreadable(slot)) {
        _blockSaveRecovery(
          'Saving is paused. A save file could not be read. It was left untouched.',
        );
        return;
      }
      if (await _slotJournalOpen(slot) || await _slotJournalOpen(_activeSlot)) {
        _blockSaveRecovery(
          'Saving is paused. An unfinished copy is still on this device.',
        );
        return;
      }
      await _storage.setActiveSlot(slot);
      _activeSlot = slot;
      if (!_saveSlots[slot].occupied) {
        _hasExistingSave = false;
      }
    });
  }

  Future<bool> _slotJournalOpen(int slot) async {
    final phase = await _storage.loadExtra(GameStorage.journalKeyFor(slot));
    return phase != null;
  }

  /// True when [slot] has bytes that do not parse. Does not delete them.
  Future<bool> _slotBytesUnreadable(int slot) async {
    final raw = await _storage.loadSlotRaw(slot);
    return raw != null &&
        raw.isNotEmpty &&
        GameLogic.importSaveJson(raw) == null;
  }

  void _blockSaveRecovery(String message) {
    _durableSaveBlocked = true;
    _saveRecoveryMessage = message;
    PlayGamesBridge.invalidateUploads();
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _hubIdleTimer?.cancel();
    _hubIdleTimer = null;
    if (!_directorClosed) _directorNotify();
  }

  /// Read the durable file again and resume only when the journal is gone.
  Future<bool> retrySaveRecovery() {
    return _enqueueSave(() async {
      if (!_durableSaveBlocked) return true;
      final legacyUnassigned = await SaveSwap.migrateLegacyGlobalJournal(
        _storage,
      );
      if (legacyUnassigned) {
        // Same rule as boot. Recovery would finish the destination journal
        // and can replace a parked party the copy just refused.
        _saveRecoveryAmbiguous = true;
        await _refreshSafeRecoverySlots();
        _blockSaveRecovery(
          'Saving is paused. An unfinished copy could not be matched to one file. It was left untouched.',
        );
        return false;
      }
      final outcome = await SaveSwap.recover(_storage);
      if (outcome == SaveSwapOutcome.unresolved) {
        _saveRecoveryAmbiguous = false;
        _safeRecoverySlots = const [];
        _blockSaveRecovery(
          'Saving is paused. An unfinished copy is still on this device. Retry keeps both copies.',
        );
        return false;
      }
      try {
        await _storage.reloadDurable();
      } catch (error, stack) {
        debugPrint('save recovery retry could not reload: $error\n$stack');
        _blockSaveRecovery(
          'Saving is paused. The device copy could not be read back.',
        );
        return false;
      }
      // The preference names the slot. Adopting its party without this
      // leaves the director on the constructor default.
      _activeSlot = _storage.activeSlotIndex;
      final raw = await _storage.loadActiveRaw();
      final parsed = raw == null ? null : GameLogic.importSaveJson(raw);
      if (parsed == null) {
        if (raw != null) {
          _blockSaveRecovery(
            'Saving is paused. A save file could not be read. It was left untouched.',
          );
          return false;
        }
        final slots = await _storage.listSlots();
        // A party already loaded, a file that does not parse, or a mirror
        // left beside an empty slot is not an empty phone.
        if (_hasExistingSave ||
            slots.any((slot) => slot.occupied) ||
            await _storage.hasUnadoptedCopy()) {
          _blockSaveRecovery(
            'Saving is paused. This device has a save that was not loaded. Retry leaves it untouched.',
          );
          return false;
        }
        _durableSaveBlocked = false;
        _saveRecoveryMessage = '';
        _saveRecoveryAmbiguous = false;
        _safeRecoverySlots = const [];
        _hasExistingSave = false;
        _phoneHadNoSaveAtBoot = true;
        _state = GameLogic.createInitialState();
        _saveSlots = slots;
        _syncHubIdleTimer();
        _directorNotify();
        return true;
      }
      _durableSaveBlocked = false;
      _saveRecoveryMessage = '';
      _saveRecoveryAmbiguous = false;
      _safeRecoverySlots = const [];
      _hasExistingSave = true;
      await _installCaughtUp(parsed);
      _saveSlots = await _storage.listSlots();
      final displaced = await _storage.loadDisplacedSave();
      _hasDisplacedDeviceSave = displaced != null && displaced.isNotEmpty;
      _syncHubIdleTimer();
      ensureCombatLoop();
      _directorNotify();
      return true;
    });
  }

  /// Copy of the journal and every slot. Does not delete anything.
  Future<String> exportRecoveryRecords() async {
    final lines = StringBuffer();
    Future<void> put(String key, String? value) async {
      lines.writeln('--- $key ---');
      lines.writeln(value ?? '');
    }

    for (final key in [
      GameStorage.journalKey,
      GameStorage.stagingKey,
      GameStorage.holdKey,
      GameStorage.displacedKey,
      GameStorage.mirrorKey,
      GameStorage.legacyMirrorKey,
      GameStorage.mirrorCorruptKey,
    ]) {
      await put(key, await _storage.loadExtra(key));
    }
    for (var slot = 0; slot < GameStorage.slotCount; slot++) {
      await put('slot_$slot', await _storage.loadSlotRaw(slot));
      await put(
        'slot_${slot}_corrupt',
        await _storage.loadExtra(GameStorage.slotCorruptKey(slot)),
      );
      if (slot == 0) continue;
      await put(
        'journal_$slot',
        await _storage.loadExtra(GameStorage.journalKeyFor(slot)),
      );
      await put(
        'staging_$slot',
        await _storage.loadExtra(GameStorage.stagingKeyFor(slot)),
      );
      await put(
        'hold_$slot',
        await _storage.loadExtra(GameStorage.holdKeyFor(slot)),
      );
      await put(
        'displaced_$slot',
        await _storage.loadExtra(GameStorage.displacedKeyFor(slot)),
      );
    }
    return lines.toString();
  }

  /// Open a slot that is not part of an unmatched journal.
  ///
  /// An existing file loads and saving turns on. An empty file only arms
  /// party setup. The global bytes stay, and play stays behind recovery
  /// until that new game has been saved. Slot 0 is refused while the
  /// journal exists.
  Future<RecoverySlotOpen> openSafeRecoverySlot(int index) {
    return _enqueueSave(() async {
      if (!_saveRecoveryAmbiguous || index <= 0) {
        return RecoverySlotOpen.refused;
      }
      await _refreshSafeRecoverySlots();
      if (!_safeRecoverySlots.contains(index)) {
        return RecoverySlotOpen.refused;
      }
      final raw = await _storage.loadSlotRaw(index);
      if (raw == null) {
        _pendingNewGameSlot = index;
        _pendingRecoveryNewGame = true;
        if (!_directorClosed) _directorNotify();
        return RecoverySlotOpen.needsNewGame;
      }
      final loaded = GameLogic.importSaveJson(raw);
      if (loaded == null) {
        _blockSaveRecovery(
          'Saving is paused. A save file could not be read. It was left untouched.',
        );
        return RecoverySlotOpen.refused;
      }
      await _storage.setActiveSlot(index);
      _activeSlot = index;
      _hasExistingSave = true;
      await _installCaughtUp(loaded);
      _durableSaveBlocked = false;
      _saveRecoveryMessage = '';
      _saveRecoveryAmbiguous = false;
      _safeRecoverySlots = const [];
      _pendingRecoveryNewGame = false;
      _pendingNewGameSlot = null;
      _saveSlots = await _storage.listSlots();
      _syncHubIdleTimer();
      ensureCombatLoop();
      _directorNotify();
      return RecoverySlotOpen.ready;
    });
  }

  /// Leave party setup. An in-flight START cannot continue into play.
  void cancelRecoveryNewGame() {
    _newGameEpoch++;
    _pendingRecoveryNewGame = false;
    if (_durableSaveBlocked) _pendingNewGameSlot = null;
  }

  Future<void> _refreshSafeRecoverySlots() async {
    final evidence = <String>{};
    for (final key in [
      GameStorage.stagingKey,
      GameStorage.holdKey,
      GameStorage.displacedKey,
    ]) {
      final value = await _storage.loadExtra(key);
      if (value != null && value.isNotEmpty) evidence.add(value);
    }
    final safe = <int>[];
    for (var slot = 1; slot < GameStorage.slotCount; slot++) {
      if (await _storage.loadExtra(GameStorage.journalKeyFor(slot)) != null) {
        continue;
      }
      final raw = await _storage.loadSlotRaw(slot);
      if (raw != null && evidence.contains(raw)) continue;
      safe.add(slot);
    }
    _safeRecoverySlots = safe;
  }

  void setAppPaused(bool paused) {
    if (_appPaused == paused) return;
    _appPaused = paused;
    if (paused) {
      final seconds = DateTime.now().difference(_foregroundSince).inSeconds;
      _foregroundSince = DateTime.now();
      if (seconds >= 15) {
        unawaited(AppAnalytics.sessionLength(seconds));
      }
      _syncHubIdleTimer();
      unawaited(_persistFlush());
      unawaited(_syncAwayReminders(backgrounded: true));
    } else {
      _foregroundSince = DateTime.now();
      unawaited(_resumeFromBackground());
    }
  }

  /// Credit time spent backgrounded, then note the day-2 funnel.
  ///
  /// Cold start already does this in [boot]. A process Android kept alive
  /// used to skip it, so Welcome Back, the ping ask, and `d1_return` never ran.
  /// Live play slices long cave catch-up ([GameLogic.applyOfflineProgressAsync])
  /// so the frame stays paintable. The saved level stays up until that credit
  /// finishes, then one notify shows the caught-up party.
  ///
  /// Preview / tests use the synchronous path via [_simulateAwayProgress].
  Future<OfflineProgressResult> _simulateAwayProgress(
    GameState saved,
    Duration elapsed,
  ) {
    if (!enableSpatialLoop) {
      return Future.value(GameLogic.applyOfflineProgress(saved, elapsed));
    }
    return GameLogic.applyOfflineProgressAsync(saved, elapsed);
  }

  Future<void> _resumeFromBackground() async {
    if (_durableSaveBlocked) {
      _syncHubIdleTimer();
      return;
    }
    if (!_isLoading) {
      final elapsed = DateTime.now().difference(_state.lastUpdated);
      if (elapsed.inSeconds >= GameDirector._awayCreditMinSec) {
        _welcomeBackAdGranted = false;
        _awayCreditInFlight = true;
        final epoch = _saveEpoch;
        final base = _state;
        try {
          final credited = await _creditAway(
            base,
            showCard: true,
            stillCurrent: () => epoch == _saveEpoch && !_directorClosed,
          );
          if (_directorClosed) return;
          if (epoch != _saveEpoch) {
            final again = await _creditAway(
              _state,
              showCard: false,
              stillCurrent: () => !_directorClosed,
            );
            if (_directorClosed) return;
            _state = again;
          } else {
            _state = credited;
          }
          if (_state.inDungeon && _spatial == null) {
            _rebuildSpatial();
          }
          _directorNotify();
        } finally {
          _awayCreditInFlight = false;
        }
      }
    }
    if (!_isLoading && !_appPaused) {
      _noteFunnelSession(newInstall: false);
      _syncHubIdleTimer();
      unawaited(_persistFlush());
    }
    if (!_appPaused) {
      unawaited(_syncAwayReminders(backgrounded: false));
    }
  }

  /// Rewind the foreground clock in tests. Does not log by itself.
  @visibleForTesting
  void debugStampForeground({required Duration ago}) {
    _foregroundSince = DateTime.now().subtract(ago);
  }

  /// One hub-idle tick. Tests use this while the recovery gate is up.
  @visibleForTesting
  void debugTickHubIdle() => _tickHubIdle();

  /// Rewind clocks in tests. Does not credit gold.
  @visibleForTesting
  void debugStampAway({Duration? lastUpdatedAgo, int? funnelInstallMs}) {
    var next = _state;
    if (lastUpdatedAgo != null) {
      next = next.copyWith(
        lastUpdated: DateTime.now().subtract(lastUpdatedAgo),
      );
    }
    if (funnelInstallMs != null) {
      next = next.copyWith(
        metaDepth: next.metaDepth.copyWith(funnelInstallMs: funnelInstallMs),
      );
    }
    _state = next;
  }

  void _syncHubIdleTimer() {
    final want =
        enableSpatialLoop &&
        !_isLoading &&
        !_appPaused &&
        !_awayCreditInFlight &&
        !_durableSaveBlocked &&
        !_state.inDungeon;
    if (!want) {
      _hubIdleTimer?.cancel();
      _hubIdleTimer = null;
      return;
    }
    if (_hubIdleTimer != null) return;
    _hubIdleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickHubIdle();
    });
  }

  void _tickHubIdle() {
    if (_isLoading ||
        _state.inDungeon ||
        _appPaused ||
        _awayCreditInFlight ||
        _durableSaveBlocked) {
      _syncHubIdleTimer();
      return;
    }
    final now = DateTime.now();
    final seconds = now.difference(_state.lastUpdated).inSeconds;
    if (seconds < 1) return;
    final beforeGold = _state.gold;
    final beforeEssence = _state.essence;
    _state = GoldIncome.applyHubIdle(
      _state,
      seconds,
    ).copyWith(lastUpdated: now);
    _autosaveAccum += seconds.toDouble();
    if (_autosaveAccum >= GameDirector._autosaveIntervalSec) {
      _autosaveAccum = 0;
      _persist();
    }
    if (_state.gold != beforeGold || _state.essence != beforeEssence) {
      _directorNotify();
    }
  }

  void _flushHubIdle() {
    if (_isLoading || _state.inDungeon || _durableSaveBlocked) return;
    final now = DateTime.now();
    final seconds = now.difference(_state.lastUpdated).inSeconds;
    if (seconds < 1) {
      // A clock behind the save must not rewind [lastUpdated]. The next
      // honest tick would otherwise treat the whole gap as time away.
      if (seconds >= 0) {
        _state = _state.copyWith(lastUpdated: now);
      }
      return;
    }
    _state = GoldIncome.applyHubIdle(
      _state,
      seconds,
    ).copyWith(lastUpdated: now);
  }

  Future<void> boot({bool deferCombatLoop = false}) async {
    _funnelSessionReadyMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await _storage.listSlots();
      final legacyUnassigned = await SaveSwap.migrateLegacyGlobalJournal(
        _storage,
      );
      // An unmatched or colliding migration still owns its global journal.
      // Recovering the destination now would publish that partial copy and
      // replace a parked party the copy refused to overwrite.
      final recovered = legacyUnassigned
          ? SaveSwapOutcome.unresolved
          : await SaveSwap.recover(_storage);
      if (legacyUnassigned) {
        _saveRecoveryAmbiguous = true;
        await _refreshSafeRecoverySlots();
        _blockSaveRecovery(
          'Saving is paused. An unfinished copy could not be matched to one file. It was left untouched.',
        );
      } else if (recovered == SaveSwapOutcome.unresolved) {
        _saveRecoveryAmbiguous = false;
        _safeRecoverySlots = const [];
        _blockSaveRecovery(
          'Saving is paused. An unfinished copy is still on this device. Retry keeps both copies.',
        );
      } else {
        _durableSaveBlocked = false;
        _saveRecoveryMessage = '';
        _saveRecoveryAmbiguous = false;
        _safeRecoverySlots = const [];
      }
      _saveSlots = await _storage.listSlots();
      _activeSlot = _storage.activeSlotIndex;
      // The slot summary only checks that the blob is a map. A later field
      // can still fail the full parse. load() would move that blob aside.
      final unreadable =
          _saveSlots.any((slot) => slot.corrupt) ||
          await _storage.hasUnadoptedCopy();
      if (unreadable) {
        _phoneHadNoSaveAtBoot = false;
        _hasExistingSave = false;
        _state = GameLogic.createInitialState();
        _blockSaveRecovery(
          'Saving is paused. A save file could not be read. It was left untouched.',
        );
      } else {
        _phoneHadNoSaveAtBoot = !_saveSlots.any((slot) => slot.occupied);
        final raw = await _storage.loadActiveRaw();
        // Probe the full parse first. load() moves a blob it cannot parse,
        // so a field that fails after the summary check must not reach it.
        // A probe that succeeds still loads through storage: that read is
        // the same object an in-memory slot already holds, and it does not
        // quarantine a file it can parse.
        final unreadableRaw =
            raw != null &&
            raw.isNotEmpty &&
            GameLogic.importSaveJson(raw, keepCombatRandom: true) == null;
        if (unreadableRaw) {
          _phoneHadNoSaveAtBoot = false;
          _hasExistingSave = false;
          _state = GameLogic.createInitialState();
          _blockSaveRecovery(
            'Saving is paused. A save file could not be read. It was left untouched.',
          );
        } else {
          final saved = await _storage.load();
          _hasExistingSave = saved != null;
          final loaded = saved == null
              ? GameLogic.createInitialState()
              : _durableSaveBlocked
              ? saved
              : await _catchUpSaved(saved);
          _state = GameLogic.backfillCodexFromInventory(
            GameLogic.ensureWeeklyContract(GameLogic.ensureRogueHero(loaded)),
          );
          _lastHighestDungeon = _state.highestDungeonCleared;
          if (_state.lastFloorClearSec > 0) {
            _lastFloorClearSec = _state.lastFloorClearSec;
          }
          _syncDevicePrefs();
          _ensureUiTimer();
          if (_state.inDungeon) {
            _rebuildSpatial();
            if (enableSpatialLoop && !deferCombatLoop && !_durableSaveBlocked) {
              // First dungeon paint before 60 Hz sim — cold mid-dungeon resume.
              scheduleMicrotask(() {
                if (_state.inDungeon && enableSpatialLoop) {
                  _startSpatialLoop();
                }
              });
            }
            if (!deferCombatLoop) {
              showToast('Floor combat restarted (positions reset)', life: 3.2);
            }
          } else {
            _spatialTimer?.cancel();
            _spatialTimer = null;
            _spatial = null;
          }
          // Only persist when continuing an existing save (offline catch-up).
          // An unresolved journal must stay byte-for-byte until the next launch.
          if (_durableSaveBlocked) {
            // Leave the loaded bytes alone. Play stays behind the recovery gate.
          } else if (_hasExistingSave) {
            _notePlaySession();
            _noteAppColdStart();
            _noteFunnelSession(newInstall: false);
            await _persistFlush();
          } else {
            _notePlaySession();
          }
          _saveSlots = await _storage.listSlots();
          _activeSlot = _storage.activeSlotIndex;
        }
      }
    } catch (e, st) {
      DebugPlayLog.event('boot', 'failed: $e');
      debugPrint('boot failed: $e\n$st');
      // A thrown inventory read is not proof the phone is empty.
      _phoneHadNoSaveAtBoot = false;
      _hasExistingSave = false;
      _state = GameLogic.createInitialState();
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
      _blockSaveRecovery(
        'Saving is paused. This device could not be read. Retry leaves it untouched.',
      );
    } finally {
      _isLoading = false;
      _syncHubIdleTimer();
      _directorNotify();
      DebugPlayLog.event('boot', DebugPlayLog.bootDetail(_state));
    }
  }

  /// Friend list, reminders, the Play-update notice, and shop billing.
  ///
  /// Called once the loading splash has been replaced. Doing this inside
  /// [boot] bound Play services while the spinner was still on screen.
  void wakePlatformAfterSplash() {
    unawaited(syncFriendReferral());
    unawaited(refreshPlayUpdateNotice());
    unawaited(LocalNotify.init());
    unawaited(rebindOptedInCloudBackup());
    // Billing after the splash — Binder + Play Services hitch cold start.
    // Shop only. A rewarded ad loads when its button is about to show.
    _bootWarmup?.cancel();
    _bootWarmup = Timer(const Duration(seconds: 2), () {
      unawaited(_warmupShopStore());
    });
  }

  /// Offline catch-up for one slot. Does not write prefs.
  ///
  /// Does not publish [saved] first. That frame was the old party level.
  Future<GameState> _catchUpSaved(GameState saved) {
    return _creditAway(saved, showCard: true);
  }

  /// Apply the gap since [saved.lastUpdated]. Same path for cold start and resume.
  Future<GameState> _creditAway(
    GameState saved, {
    required bool showCard,
    bool Function()? stillCurrent,
  }) async {
    final elapsed = DateTime.now().difference(saved.lastUpdated);
    final pause = debugAwayCreditPause;
    if (pause != null) await pause;
    if (stillCurrent != null && !stillCurrent()) return saved;
    _welcomeBackAdGranted = false;
    final offline = await _simulateAwayProgress(saved, elapsed);
    if (stillCurrent != null && !stillCurrent()) return saved;
    return _finishAwayCredit(offline, showCard: showCard);
  }

  /// Welcome Back card and funnel for a result that is already simulated.
  Future<GameState> _finishAwayCredit(
    OfflineProgressResult offline, {
    required bool showCard,
  }) async {
    var caught = offline.state;
    if (offline.hasSummary) {
      if (showCard) {
        uiFeedback.presentOffline(offline);
        noteReviewWelcome(offline);
        unawaited(
          AppAnalytics.welcomeBack(
            where: offline.wasInDungeon ? 'dungeon' : 'hub',
            seconds: offline.secondsApplied,
            gold: offline.goldGained,
          ),
        );
        if (offline.welcomeBackAdOffer) {
          unawaited(AppAnalytics.welcomeBackAdOffer());
          unawaited(
            AdRewarded.prepareOffer(
              placement: AnalyticsEvents.placementWelcomeBack,
            ),
          );
        }
        // The cave opens the same Welcome Back card. A toast would cover it.
      }
      final tick = offline.goldGained > 0
          ? FunnelAnalytics.onOfflineGold(caught, gold: offline.goldGained)
          : offline.wasInDungeon
          ? FunnelAnalytics.onOfflineHold(caught)
          : FunnelTick.none(caught);
      caught = tick.state;
      for (final hit in tick.events) {
        unawaited(
          AppAnalytics.logEvent(
            hit.name,
            hit.params.isEmpty ? null : hit.params,
          ),
        );
      }
    }
    return caught;
  }

  Future<void> _installCaughtUp(GameState loaded) async {
    _state = GameLogic.backfillCodexFromInventory(
      GameLogic.ensureWeeklyContract(GameLogic.ensureRogueHero(loaded)),
    );
    _lastHighestDungeon = _state.highestDungeonCleared;
    if (_state.lastFloorClearSec > 0) {
      _lastFloorClearSec = _state.lastFloorClearSec;
    }
    _syncDevicePrefs();
    _ensureUiTimer();
    if (_state.inDungeon) {
      _rebuildSpatial();
    } else {
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    }
  }

  /// Load [index] and make it the autosave target. No-op success if already active.
  Future<bool> openSaveSlot(int index) {
    if (_durableSaveBlocked) return Future<bool>.value(false);
    return _enqueueSave(() => _openSaveSlotTurn(index));
  }

  Future<bool> _openSaveSlotTurn(int index) async {
    final slot = index.clamp(0, GameStorage.slotCount - 1);
    if (slot == _activeSlot &&
        _storage.activeSlotIndex == slot &&
        _hasExistingSave) {
      return true;
    }
    if (await _slotBytesUnreadable(slot)) {
      _blockSaveRecovery(
        'Saving is paused. A save file could not be read. It was left untouched.',
      );
      return false;
    }
    final saved = await _storage.loadSlot(slot);
    if (saved == null) {
      _saveSlots = await _storage.listSlots();
      _directorNotify();
      return false;
    }
    final pending = await SaveSwap.recover(_storage, slot: slot);
    if (pending == SaveSwapOutcome.unresolved) {
      _directorNotify();
      return false;
    }
    _saveEpoch++;
    PlayGamesBridge.invalidateUploads();
    _friendEpoch++;
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _spatial = null;
    _awaitingWipeChoice = false;
    uiFeedback.dismissOfflineSummary();
    await _storage.setActiveSlot(slot);
    _activeSlot = slot;
    _hasExistingSave = true;
    final caught = await _catchUpSaved(saved);
    await _installCaughtUp(caught);
    _notePlaySession();
    _noteAppColdStart();
    _noteFunnelSession(newInstall: false);
    final snapshot = _stampCloudClock(_state);
    _state = snapshot;
    if (!await _storage.save(snapshot)) return false;
    PlayGamesBridge.scheduleCloudUpload(snapshot);
    _saveSlots = await _storage.listSlots();
    _syncHubIdleTimer();
    _directorNotify();
    unawaited(syncFriendReferral());
    return true;
  }

  /// Delete one file. Other slots stay. Active slot becomes a blank title state.
  /// Refused while a journal still holds a party.
  Future<void> eraseSaveSlot(int index) {
    return _enqueueSave<void>(() async {
      if (_durableSaveBlocked) return;
      final slot = index.clamp(0, GameStorage.slotCount - 1);
      if (await _slotBytesUnreadable(slot)) {
        _blockSaveRecovery(
          'Saving is paused. A save file could not be read. It was left untouched.',
        );
        return;
      }
      if (await _slotJournalOpen(slot)) {
        _blockSaveRecovery(
          'Saving is paused. This file still has an unfinished copy, so it was not erased.',
        );
        return;
      }
      await _eraseSaveSlotTurn(slot);
    });
  }

  Future<void> _eraseSaveSlotTurn(int slot) async {
    await _storage.clearSlot(slot);
    if (slot == _activeSlot) {
      _friendEpoch++;
      _awaitingWipeChoice = false;
      uiFeedback.dismissOfflineSummary();
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
      _state = GameLogic.createInitialState();
      _hasExistingSave = false;
      _syncDevicePrefs();
    }
    _saveSlots = await _storage.listSlots();
    _syncHubIdleTimer();
    _directorNotify();
  }

  /// Hard start: create a fresh party in the armed slot (or the active one).
  ///
  /// Returns false when the initial save did not land, when this call is a
  /// duplicate of a setup already in flight, or when the player left setup.
  /// Play stays closed until that save is on disk. A second START does not
  /// enter the queue, so it cannot reset a party a grant just saved.
  Future<bool> startNewGame(
    List<HeroSpecId> partySpecs, {
    String? partyName,
    HeroRace partyRace = HeroRace.human,
    List<HeroRace>? partyRaces,
    List<HeroSex>? partySexes,
  }) {
    if (_newGameBusy) return Future<bool>.value(false);
    _newGameBusy = true;
    final epoch = _newGameEpoch;
    final pending = _pendingNewGameSlot;
    final slot = (pending ?? _activeSlot).clamp(0, GameStorage.slotCount - 1);
    final fromRecovery = _durableSaveBlocked && pending == slot;
    // An armed slot must still be empty when the turn runs. A call with no
    // armed slot may replace the active file (preview tests do this).
    final expectEmpty = pending != null;
    return _enqueueSave<bool>(() async {
      try {
        if (epoch != _newGameEpoch) return false;
        if (_durableSaveBlocked && !fromRecovery) return false;
        if (fromRecovery) {
          await _refreshSafeRecoverySlots();
          if (!_safeRecoverySlots.contains(slot)) return false;
        }
        final existing = await _storage.loadSlotRaw(slot);
        if (await _slotBytesUnreadable(slot)) {
          _blockSaveRecovery(
            'Saving is paused. A save file could not be read. It was left untouched.',
          );
          return false;
        }
        if (expectEmpty && existing != null) {
          return false;
        }
        if (await _slotJournalOpen(slot)) {
          _blockSaveRecovery(
            'Saving is paused. This file still has an unfinished copy, so a new game was not started.',
          );
          return false;
        }
        return await _startNewGameTurn(
          partySpecs,
          partyName: partyName,
          partyRace: partyRace,
          partyRaces: partyRaces,
          partySexes: partySexes,
          slot: slot,
          fromRecovery: fromRecovery,
          epoch: epoch,
        );
      } finally {
        _newGameBusy = false;
      }
    });
  }

  Future<bool> _startNewGameTurn(
    List<HeroSpecId> partySpecs, {
    String? partyName,
    HeroRace partyRace = HeroRace.human,
    List<HeroRace>? partyRaces,
    List<HeroSex>? partySexes,
    required int slot,
    required bool fromRecovery,
    required int epoch,
  }) async {
    final previous = _state;
    final previousHas = _hasExistingSave;
    final previousSlot = _activeSlot;
    final previousEpoch = _friendEpoch;
    if (epoch != _newGameEpoch) return false;
    _friendEpoch++;
    _pendingNewGameSlot = null;
    var switched = false;
    var saved = false;
    try {
      await _storage.setActiveSlot(slot);
      switched = true;
      _activeSlot = slot;
      _awaitingWipeChoice = false;
      uiFeedback.dismissOfflineSummary();
      _spatialTimer?.cancel();
      _spatial = null;
      final layout = _phoneHadNoSaveAtBoot
          ? HomeLayout.home
          : previous.homeLayout;
      final panelFull = previous.homePanelFull;
      _state =
          GameLogic.createInitialState(
            partySpecs: GameLogic.normalizeNewGameParty(partySpecs),
            partyName: partyName,
            partyRace: partyRace,
            partyRaces: partyRaces,
            partySexes: partySexes,
          ).copyWith(
            homeLayout: layout,
            homePanelFull: layout == HomeLayout.home ? true : panelFull,
          );
      if (_phoneHadNoSaveAtBoot) {
        _state = ReinstallPouch.markDue(_state);
      }
      _notePlaySession(newGame: true);
      _noteAppColdStart();
      _noteFunnelSession(newInstall: true);
      _syncDevicePrefs();
      _lastHighestDungeon = _state.highestDungeonCleared;
      _ensureUiTimer();
      _syncHubIdleTimer();
      _directorNotify();
      DebugPlayLog.event('new_game', DebugPlayLog.bootDetail(_state));
      final snapshot = _stampCloudClock(_state);
      _state = snapshot;
      try {
        saved = await _storage.save(snapshot);
      } catch (error, stack) {
        debugPrint('new game save failed: $error\n$stack');
        saved = false;
      }
      // A false or thrown commit is not accepted from a later read.
      // Android can show the new value in memory after commit() returns false.
      final cancelled = epoch != _newGameEpoch;
      if (!saved || cancelled) {
        await _rollbackRecoveryNewGame(
          previous: previous,
          previousHas: previousHas,
          previousSlot: previousSlot,
          previousEpoch: previousEpoch,
          armedSlot: slot,
          switched: switched,
          restorePending: !cancelled,
        );
        return false;
      }
      _hasExistingSave = true;
      if (fromRecovery) {
        _durableSaveBlocked = false;
        _saveRecoveryMessage = '';
        _saveRecoveryAmbiguous = false;
        _safeRecoverySlots = const [];
        _pendingRecoveryNewGame = false;
      }
      PlayGamesBridge.scheduleCloudUpload(snapshot);
      _saveSlots = await _storage.listSlots();
      _directorNotify();
      if (_state.homeLayout == HomeLayout.home) {
        enterDungeon(dungeonId: 'sandy');
      }
      unawaited(syncFriendReferral());
      return true;
    } catch (error, stack) {
      debugPrint('new game setup failed: $error\n$stack');
      await _rollbackRecoveryNewGame(
        previous: previous,
        previousHas: previousHas,
        previousSlot: previousSlot,
        previousEpoch: previousEpoch,
        armedSlot: slot,
        switched: switched,
        restorePending: epoch == _newGameEpoch,
      );
      return false;
    }
  }

  Future<void> _rollbackRecoveryNewGame({
    required GameState previous,
    required bool previousHas,
    required int previousSlot,
    required int previousEpoch,
    required int armedSlot,
    bool switched = true,
    bool restorePending = true,
  }) async {
    if (switched) {
      try {
        await _storage.setActiveSlot(previousSlot);
      } catch (error, stack) {
        debugPrint(
          'new game rollback could not restore the slot: $error\n$stack',
        );
      }
    }
    _activeSlot = previousSlot;
    _state = previous;
    _hasExistingSave = previousHas;
    _friendEpoch = previousEpoch;
    if (restorePending) _pendingNewGameSlot = armedSlot;
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _spatial = null;
    _saveSlots = await _storage.listSlots();
    if (!_directorClosed) _directorNotify();
  }

  /// One count per cold start. A new game is sitting 1.
  /// An older save that already cleared the first boss is not treated as
  /// that player's first sitting.
  void _notePlaySession({bool newGame = false}) {
    if (newGame) {
      _sessionNotedSlots.add(_activeSlot);
      _bossesAtSessionStart = 0;
      _sessionBossBaselineSet = true;
      _reviewWelcome = null;
      _state = _state.copyWith(
        metaDepth: _state.metaDepth.copyWith(sessionCount: 1),
      );
      return;
    }
    if (_sessionNotedSlots.contains(_activeSlot)) return;
    _sessionNotedSlots.add(_activeSlot);
    final prior = _state.metaDepth.sessionCount;
    var next = prior + 1;
    if (prior == 0 && _hasExistingSave && GameLogic.showDailyChase(_state)) {
      next = 2;
    }
    if (next < 1) next = 1;
    _state = _state.copyWith(
      metaDepth: _state.metaDepth.copyWith(sessionCount: next),
    );
    _bossesAtSessionStart = _state.bossVictories;
    _sessionBossBaselineSet = true;
  }

  /// Continue from the loaded save into play (no-op if already ready).
  void continueGame() {
    if (!_hasExistingSave || _durableSaveBlocked) return;
    DebugPlayLog.event('continue', DebugPlayLog.bootDetail(_state));
    ensureCombatLoop();
    _syncHubIdleTimer();
    _directorNotify();
  }
}
