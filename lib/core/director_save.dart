part of 'game_director.dart';

/// Save — extracted from GameDirector.
extension GameDirectorSave on GameDirector {
  void _persist() {
    // Title-screen placeholder and boot-failure empty state must not overwrite
    // a real save (hub idle used to write after 25s).
    if (!_hasExistingSave) return;
    final stamped = _state.copyWith(
      metaDepth: _state.metaDepth.copyWith(
        cloudSaveUpdatedMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
    _state = stamped;
    // A false or thrown write completes as false. The chain stays alive so
    // the next save still runs. Callers that grant a purchase must see false.
    _saveChain = _saveChain.then((_) async {
      try {
        final ok = await _storage.save(_state);
        if (!ok) {
          DebugPlayLog.event('save', 'write failed: setString returned false');
          debugPrint('save failed: setString returned false');
          return false;
        }
        PlayGamesBridge.notePartyPower(
          score: GameLogic.partyPowerScore(_state),
          partyName: _state.partyName,
        );
        PlayGamesBridge.scheduleCloudUpload(_state);
        unawaited(PlayGamesBridge.flushPendingScores());
        return true;
      } catch (e, st) {
        DebugPlayLog.event('save', 'write failed: $e');
        debugPrint('save failed: $e\n$st');
        return false;
      }
    });
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

  /// Title NEW GAME on an empty file. Ignored once [startNewGame] runs.
  void armNewGameSlot(int index) {
    _pendingNewGameSlot = index.clamp(0, GameStorage.slotCount - 1);
  }

  /// Point the next import / cloud write at [index] without loading it yet.
  Future<void> armImportSlot(int index) async {
    final slot = index.clamp(0, GameStorage.slotCount - 1);
    await _storage.setActiveSlot(slot);
    _activeSlot = slot;
    if (!_saveSlots[slot].occupied) {
      _hasExistingSave = false;
    }
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
  Future<void> _resumeFromBackground() async {
    if (!_isLoading) {
      final elapsed = DateTime.now().difference(_state.lastUpdated);
      if (elapsed.inSeconds >= GameDirector._awayCreditMinSec) {
        _awayCreditInFlight = true;
        try {
          final credited = await _creditAway(_state, showCard: true);
          _state = credited;
          if (_state.inDungeon) {
            _rebuildSpatial();
          } else {
            _spatialTimer?.cancel();
            _spatialTimer = null;
            _spatial = null;
          }
          _directorNotify();
        } finally {
          _awayCreditInFlight = false;
        }
      }
      if (!_appPaused) {
        _noteFunnelSession(newInstall: false);
        _syncHubIdleTimer();
        unawaited(_persistFlush());
      }
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
    if (_isLoading || _state.inDungeon || _appPaused || _awayCreditInFlight) {
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
    if (_isLoading || _state.inDungeon) return;
    final now = DateTime.now();
    final seconds = now.difference(_state.lastUpdated).inSeconds;
    if (seconds < 1) {
      _state = _state.copyWith(lastUpdated: now);
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
      _saveSlots = await _storage.listSlots();
      _activeSlot = _storage.activeSlotIndex;
      final saved = await _storage.load();
      _hasExistingSave = saved != null;
      final loaded = saved == null
          ? GameLogic.createInitialState()
          : await _catchUpSaved(saved, deferCombatLoop: deferCombatLoop);
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
        if (enableSpatialLoop && !deferCombatLoop) {
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
      if (_hasExistingSave) {
        _notePlaySession();
        _noteFunnelSession(newInstall: false);
        await _persistFlush();
      } else {
        _notePlaySession();
      }
      _saveSlots = await _storage.listSlots();
      _activeSlot = _storage.activeSlotIndex;
    } catch (e, st) {
      DebugPlayLog.event('boot', 'failed: $e');
      debugPrint('boot failed: $e\n$st');
      _hasExistingSave = false;
      _state = GameLogic.createInitialState();
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    } finally {
      _isLoading = false;
      _syncHubIdleTimer();
      _directorNotify();
      DebugPlayLog.event('boot', DebugPlayLog.bootDetail(_state));
      unawaited(syncFriendReferral());
      unawaited(refreshPlayUpdateNotice());
      unawaited(LocalNotify.init());
      // Ads / billing after first hub frames — Binder + Play Services hitch cold start.
      _bootWarmup?.cancel();
      _bootWarmup = Timer(const Duration(seconds: 2), () {
        unawaited(AdRewarded.warmup());
        unawaited(_warmupShopStore());
      });
    }
  }

  /// Offline catch-up for one slot. Does not write prefs.
  Future<GameState> _catchUpSaved(
    GameState saved, {
    required bool deferCombatLoop,
  }) async {
    // Paint immediately — AFK spatial sim must not hold the spinner.
    // Do NOT start the live spatial loop until after offline catch-up.
    _state = GameLogic.ensureRogueHero(saved);
    _lastHighestDungeon = _state.highestDungeonCleared;
    _syncDevicePrefs();
    _ensureUiTimer();
    // Keep loading flag true until boot's finally{} when intro is deferred —
    // early notify would flash hub/dungeon under the title card.
    if (!deferCombatLoop) {
      _isLoading = false;
      _directorNotify();
    }

    return _creditAway(saved, showCard: true);
  }

  /// Apply the gap since [saved.lastUpdated]. Same path for cold start and resume.
  Future<GameState> _creditAway(
    GameState saved, {
    required bool showCard,
  }) async {
    final elapsed = DateTime.now().difference(saved.lastUpdated);
    _welcomeBackAdGranted = false;
    final offline = await GameLogic.applyOfflineProgressAsync(saved, elapsed);
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
  Future<bool> openSaveSlot(int index) async {
    final slot = index.clamp(0, GameStorage.slotCount - 1);
    if (slot == _activeSlot && _hasExistingSave) return true;
    final saved = await _storage.loadSlot(slot);
    if (saved == null) {
      _saveSlots = await _storage.listSlots();
      _directorNotify();
      return false;
    }
    _friendEpoch++;
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _spatial = null;
    _awaitingWipeChoice = false;
    uiFeedback.dismissOfflineSummary();
    await _storage.setActiveSlot(slot);
    _activeSlot = slot;
    _hasExistingSave = true;
    final caught = await _catchUpSaved(saved, deferCombatLoop: true);
    await _installCaughtUp(caught);
    _notePlaySession();
    _noteFunnelSession(newInstall: false);
    await _persistFlush();
    _saveSlots = await _storage.listSlots();
    _syncHubIdleTimer();
    _directorNotify();
    unawaited(syncFriendReferral());
    return true;
  }

  /// Delete one file. Other slots stay. Active slot becomes a blank title state.
  Future<void> eraseSaveSlot(int index) async {
    final slot = index.clamp(0, GameStorage.slotCount - 1);
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
  Future<void> startNewGame(
    List<HeroSpecId> partySpecs, {
    String? partyName,
    HeroRace partyRace = HeroRace.human,
    List<HeroRace>? partyRaces,
    List<HeroSex>? partySexes,
  }) async {
    _friendEpoch++;
    final slot = (_pendingNewGameSlot ?? _activeSlot).clamp(
      0,
      GameStorage.slotCount - 1,
    );
    _pendingNewGameSlot = null;
    await _storage.setActiveSlot(slot);
    _activeSlot = slot;
    _awaitingWipeChoice = false;
    uiFeedback.dismissOfflineSummary();
    _spatialTimer?.cancel();
    _spatial = null;
    _state = GameLogic.createInitialState(
      partySpecs: GameLogic.normalizeNewGameParty(partySpecs),
      partyName: partyName,
      partyRace: partyRace,
      partyRaces: partyRaces,
      partySexes: partySexes,
    );
    _hasExistingSave = true;
    _notePlaySession(newGame: true);
    _noteFunnelSession(newInstall: true);
    _syncDevicePrefs();
    _lastHighestDungeon = _state.highestDungeonCleared;
    _ensureUiTimer();
    _syncHubIdleTimer();
    _directorNotify();
    DebugPlayLog.event('new_game', DebugPlayLog.bootDetail(_state));
    await _persistFlush();
    _saveSlots = await _storage.listSlots();
    _directorNotify();
    unawaited(syncFriendReferral());
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
    if (!_hasExistingSave) return;
    DebugPlayLog.event('continue', DebugPlayLog.bootDetail(_state));
    ensureCombatLoop();
    _syncHubIdleTimer();
    _directorNotify();
  }
}
