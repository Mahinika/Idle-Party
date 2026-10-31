part of 'game_director.dart';

/// Fight — extracted from GameDirector.
extension GameDirectorFight on GameDirector {
  /// Start spatial combat after the cold-start intro (if already in a dungeon).
  void ensureCombatLoop() {
    if (!enableSpatialLoop || !_state.inDungeon) return;
    if (_spatial == null) {
      _rebuildSpatial();
    }
    if (_spatialTimer == null) {
      _startSpatialLoop();
      showToast('Floor combat restarted (positions reset)', life: 3.2);
    }
  }

  /// Fight should advance. A pause does not ask the screen for another frame.
  bool get _combatClockShouldPump {
    if (_isLoading || !_state.inDungeon || _spatial == null) return false;
    if (_awaitingWipeChoice || _uiPaused || _appPaused || _awayCreditInFlight) {
      return false;
    }
    return true;
  }

  void _startSpatialLoop() {
    _spatialTimer?.cancel();
    _combatFrameQueued = false;
    _droppedCombatTicks = 0;
    // Wall clock asks for a step. The step itself runs on the next refresh,
    // so two asks in one frame do not stack a hitch. Map paint follows
    // [combatFrame]; shell HUD stays on [_shellNotifyEvery].
    _spatialTimer = Timer.periodic(GameDirector._spatialPeriod, (timer) {
      if (!identical(_spatialTimer, timer)) return;
      if (!_combatClockShouldPump) return;
      if (_combatFrameQueued) {
        if (_droppedCombatTicks < 1) _droppedCombatTicks++;
        return;
      }
      _combatFrameQueued = true;
      final binding = SchedulerBinding.instance;
      binding.scheduleFrameCallback((_) {
        if (!identical(_spatialTimer, timer)) return;
        _combatFrameQueued = false;
        final extra = _lastCombatTickMs > 22 ? 0 : _droppedCombatTicks;
        _droppedCombatTicks = 0;
        spatialTick(extraSteps: extra);
      });
      binding.scheduleFrame();
    });
  }

  void _rebuildSpatial() {
    _floorEpoch++;
    hudFocusEnemyId = null;
    final ticketAshenCrown = _state.inWorldBoss && !_state.worldBossPractice;
    _spatial = SpatialCombat.build(
      _state,
      // Soft HP when party >> zone unlock so pack tells stay readable (#64).
      threatScale: GameLogic.overgearThreatScale(_state),
      afkAssist: ticketAshenCrown ? false : null,
    );
    _battleToken = _state.battleNumber;
    if (kDebugMode && _debugHoldNextRebuild) {
      _debugHoldNextRebuild = false;
      _debugHoldCombat = true;
    }
    if (kDebugMode && _spatial != null) {
      final world = _spatial!;
      final shrine = world.map.chambers.any(
        (c) => c.beatKind == FloorBeatKind.shrine,
      );
      var far = 0.0;
      if (world.heroes.isNotEmpty) {
        final party = world.heroes.firstWhere(
          (h) => !h.isPet,
          orElse: () => world.heroes.first,
        );
        for (final enemy in world.enemies) {
          if (enemy.hp <= 0) continue;
          final dx = enemy.x - party.x;
          final dy = enemy.y - party.y;
          final d = math.sqrt(dx * dx + dy * dy);
          if (far == 0 || d < far) far = d;
        }
      }
      DebugPlayLog.event(
        'layout',
        'F${_state.currentRoom.floorNumber} '
            '${_state.dungeonId} shrine=$shrine '
            'far=${far.toStringAsFixed(1)} hold=$_debugHoldCombat',
      );
    }
  }

  void _bumpCombatFrame() {
    _visualFrame++;
    combatFrame.value = _visualFrame;
  }

  /// Real-time spatial combat step, once per screen refresh while in a dungeon.
  ///
  /// [extraSteps] catches up a single dropped ask without a second paint.
  void spatialTick({int extraSteps = 0}) =>
      tickDungeonClock(extraSteps: extraSteps);

  void _notifyShell() => notifyListeners();

  void _cancelWipeAuto() {
    _wipeAutoTimer?.cancel();
    _wipeAutoTimer = null;
    if (wipeAutoSeconds.value != 0) wipeAutoSeconds.value = 0;
  }

  /// Normal caves retry themselves. Gauntlet, rifts, and Daily Run wait.
  void _armWipeAutoContinue() {
    _cancelWipeAuto();
    if (_state.inGauntlet ||
        _state.inAnyRiftMode ||
        MetaSystems.isActiveDailyRun(_state)) {
      return;
    }
    wipeAutoSeconds.value = 3;
    _wipeAutoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = wipeAutoSeconds.value - 1;
      if (next > 0) {
        wipeAutoSeconds.value = next;
        return;
      }
      timer.cancel();
      _wipeAutoTimer = null;
      wipeAutoSeconds.value = 0;
      if (_awaitingWipeChoice) retryAfterWipe();
    });
  }

  void _handleWipe() {
    _awaitingWipeChoice = false;
    _cancelWipeAuto();
    if (_state.inGauntlet) {
      final floor = _state.currentRoom.floorNumber;
      _state = GameLogic.exitToHubHealed(_state);
      _spatialTimer?.cancel();
      _spatial = null;
      _freezeRunIncome();
      _state = _state.copyWith(lastUpdated: DateTime.now());
      _syncHubIdleTimer();
      showToast(
        'Gauntlet ended on F$floor · best F${_state.metaDepth.gauntletBestFloor}',
        life: 3.2,
      );
      final payoffs = LogicNotices.takeMetaPayoffs();
      if (payoffs.isNotEmpty) {
        showToast(payoffs.join(' · '), life: 3.0);
      }
      GameAudio.uiBack();
      notifyListeners();
      unawaited(_persistFlush());
      return;
    }
    if (_state.inRift) {
      final tier = _state.riftTier;
      _state = GameLogic.exitToHubHealed(_state);
      _spatialTimer?.cancel();
      _spatial = null;
      _freezeRunIncome();
      _state = _state.copyWith(lastUpdated: DateTime.now());
      _syncHubIdleTimer();
      showToast('Rift R$tier ended', life: 3.2);
      final payoffs = LogicNotices.takeMetaPayoffs();
      if (payoffs.isNotEmpty) {
        showToast(payoffs.join(' · '), life: 3.0);
      }
      GameAudio.uiBack();
      notifyListeners();
      unawaited(_persistFlush());
      return;
    }
    if (_state.inGreaterRift) {
      final tier = _state.grTier;
      _state = GameLogic.exitToHubHealed(_state);
      _spatialTimer?.cancel();
      _spatial = null;
      _freezeRunIncome();
      _state = _state.copyWith(lastUpdated: DateTime.now());
      _syncHubIdleTimer();
      showToast('Greater Rift GR$tier ended', life: 3.2);
      final payoffs = LogicNotices.takeMetaPayoffs();
      if (payoffs.isNotEmpty) {
        showToast(payoffs.join(' · '), life: 3.0);
      }
      GameAudio.uiBack();
      notifyListeners();
      unawaited(_persistFlush());
      return;
    }
    final farmingBack =
        _state.wipeStreakCount >= GameLogic.pushWipesBeforeFarm &&
        _state.dungeonMode == DungeonMode.push &&
        _state.currentRoom.floorNumber > _state.highestFloorCleared;
    _state = GameLogic.continueAfterWipe(
      _state,
    ).copyWith(lastUpdated: DateTime.now());
    if (MetaSystems.isActiveDailyRun(_state)) {
      showToast('Daily echo restarted — fight on', life: 2.5);
    } else if (farmingBack && _state.pushResumeFloor > 0) {
      showToast(
        'Farming floor ${_state.currentRoom.floorNumber} — then F${_state.pushResumeFloor}',
        life: 3,
      );
    } else {
      showToast('Floor restarted — fight on', life: 2.5);
    }
    GameAudio.uiConfirm();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _beginFloorClock();
    notifyListeners();
    unawaited(_persistFlush());
  }

  /// First wipe before the boss: wear bag upgrades and fight this floor again.
  bool _wearUpgradesAndFightOn() {
    if (!WipeAdvice.wearUpgradesAndContinue(_state)) return false;
    final result = GameLogic.autoEquipBetterGearResult(_state);
    if (result.equipped <= 0) return false;
    final floor = _state.currentRoom.floorNumber;
    _state = GameLogic.restartFloor(result.state).copyWith(
      lastUpdated: DateTime.now(),
      wipeAdviceLine: '',
      wipeScanLine: '',
    );
    final n = result.equipped;
    final worn = GearService.wornLine(result.names);
    showToast(
      worn.isEmpty ? 'Better gear on — fight on' : '$worn — fight on',
      life: 2.6,
    );
    DebugPlayLog.event('wipe', 'wore $n · fight on F$floor');
    GameAudio.equip();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _beginFloorClock();
    notifyListeners();
    unawaited(_persistFlush());
    return true;
  }

  void retryAfterWipe() {
    if (!_awaitingWipeChoice) return;
    // Gauntlet has no floor retry — same as hub exit.
    if (_state.inGauntlet) {
      hubAfterWipe();
      return;
    }
    _handleWipe();
  }

  void hubAfterWipe({NavIntent? openMenu}) {
    if (!_awaitingWipeChoice) return;
    _awaitingWipeChoice = false;
    _cancelWipeAuto();
    _state = GameLogic.exitToHubHealed(_state);
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _spatial = null;
    _freezeRunIncome();
    _state = _state.copyWith(lastUpdated: DateTime.now());
    _syncHubIdleTimer();
    _pendingHubNav = openMenu;
    final payoffs = LogicNotices.takeMetaPayoffs();
    showToast(
      payoffs.isNotEmpty ? payoffs.join(' · ') : 'Returned to hub',
      life: payoffs.isNotEmpty ? 3.0 : 2,
    );
    GameAudio.uiBack();
    notifyListeners();
    unawaited(_persistFlush());
  }

  /// True while the player paused auto-walk to stairs after a clear.
  bool get exitHoldActive => (_spatial?.exitHoldSec ?? 0) > 0;

  /// Skip the stairs walk — bump the soft-lock timer so the floor finishes
  /// on the next combat tick (matches HOLD tip / What’s New).
  void startExitHold() {
    final spatial = _spatial;
    if (spatial == null || !spatial.awaitingExit) return;
    spatial.exitHoldSec = 0;
    spatial.exitWaitTimer = 99;
    notifyListeners();
  }

  /// Keep the cleared floor still while the away-ping card is up.
  bool pauseExitForPrompt() {
    final spatial = _spatial;
    if (spatial == null || !spatial.awaitingExit) return false;
    spatial.exitHoldSec = 45;
    return true;
  }

  /// Let the party walk the stairs after the card closes.
  void releaseExitPrompt() {
    final spatial = _spatial;
    if (spatial == null || !spatial.awaitingExit) return;
    if (spatial.exitHoldSec > 0) spatial.exitHoldSec = 0;
  }

  /// Prefer an enemy under a map tap for the target HUD (within ~1.6 tiles).
  void setHudFocusAtWorld(double tileX, double tileY) {
    final spatial = _spatial;
    if (spatial == null) return;
    SpatialActor? best;
    var bestD2 = 2.6; // ~1.6 tiles
    for (final e in spatial.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final dx = e.x - tileX;
      final dy = e.y - tileY;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = e;
      }
    }
    if (best == null) return;
    if (hudFocusEnemyId == best.id) return;
    hudFocusEnemyId = best.id;
    notifyListeners();
  }

  /// God Hand aimed at the nearest live enemy to the party, else party center.
  void godHandAtFocus() {
    final spatial = _spatial;
    if (spatial == null) return;
    final aliveHeroes = spatial.heroes.where((h) => h.hp > 0).toList();
    var cx = spatial.cols / 2.0;
    var cy = spatial.rows / 2.0;
    if (aliveHeroes.isNotEmpty) {
      cx = 0;
      cy = 0;
      for (final h in aliveHeroes) {
        cx += h.x;
        cy += h.y;
      }
      cx /= aliveHeroes.length;
      cy /= aliveHeroes.length;
    }
    SpatialActor? best;
    var bestD2 = double.infinity;
    for (final e in spatial.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final dx = e.x - cx;
      final dy = e.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = e;
      }
    }
    if (best != null) {
      godHandAtWorld(best.x, best.y);
    } else {
      godHandAtWorld(cx, cy);
    }
  }

  /// God Hand tap at world-tile coordinates.
  void godHandAtWorld(double tileX, double tileY) {
    if (_isLoading ||
        !_state.inDungeon ||
        _spatial == null ||
        _state.isPartyDefeated) {
      return;
    }
    if (_spatial!.godHandCooldown > 0) {
      GameAudio.uiDeny();
      SpatialCombat.spawnRing(
        _spatial!,
        x: tileX,
        y: tileY,
        argb: 0x88FF8060,
        radius: 0.7,
        life: 0.28,
      );
      return;
    }
    final before = _state;
    final result = SpatialCombat.godHand(
      _spatial!,
      _state,
      tileX: tileX.clamp(0.0, _spatial!.cols.toDouble()).toDouble(),
      tileY: tileY.clamp(0.0, _spatial!.rows.toDouble()).toDouble(),
    );
    _spatial = result.world;
    _state = result.state;
    _state = GodHandMastery.noteSmash(_state);
    _state = GameLogic.dismissTip(_state, 'godhand');
    if (result.goldFromKills > 0) {
      _state = GameLogic.creditCombatGold(_state, result.goldFromKills);
      _applyFunnelTick(FunnelAnalytics.onFirstReward(_state));
      _flushQuestReadyToast(life: 1.8);
    }
    _noteLifetimeGold(before, _state);
    if (result.kills > 0) {
      GameAudio.crit();
      pulseCombatShake(0.72);
    } else {
      GameAudio.uiDeny();
    }
    _announceAbilityUnlocks(before, _state);
    _announceAchievementUnlocks(before, _state);
    if (result.kills > 0) {
      final g = result.goldFromKills;
      showToast(
        result.kills == 1
            ? (g > 0 ? 'God Hand · 1 kill · +${g}g' : 'God Hand · 1 kill')
            : (g > 0
                  ? 'God Hand · ${result.kills} kills · +${g}g'
                  : 'God Hand · ${result.kills} kills'),
        life: 1.5,
      );
    } else {
      showToast('God Hand · steered party (no kill)', life: 1.3);
    }
    _state = SessionTelemetry.append(
      _state,
      'god_hand',
      'kills${result.kills}',
    );
    notifyListeners();
  }

  /// Welcome Back in a failed push: farm the floor they can clear.
  void continueClearableFloor() {
    if (!_state.inDungeon) return;
    final next = GameLogic.returnToClearableFloor(_state);
    if (next.currentRoom.floorNumber == _state.currentRoom.floorNumber &&
        next.dungeonMode == _state.dungeonMode) {
      return;
    }
    _state = next;
    _rebuildSpatial();
    notifyListeners();
  }

  void enterDungeon({String dungeonId = 'sandy'}) {
    if (_isLoading) return;
    clearLootLog();
    _awaitingWipeChoice = false;
    _flushHubIdle();
    var entered = GameLogic.dismissTip(
      GameLogic.enterDungeon(_state, dungeonId: dungeonId),
      'first_run',
    );
    final md = entered.metaDepth;
    if (!md.wispUnlocked) {
      entered = entered.copyWith(metaDepth: WispGift.unlockOnFirstEnter(md));
    }
    _state = entered;
    if (_state.metaDepth.wispUnlocked) {
      _ensureUiTimer();
    }
    _applyFunnelTick(
      FunnelAnalytics.onFirstEnter(
        _state,
        DateTime.now(),
        dungeonId: dungeonId,
        sessionReadyMs: _funnelSessionReadyMs,
      ),
      persist: false,
    );
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _beginRunIncomeSession();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _syncHubIdleTimer();
    DebugPlayLog.event(
      'enter',
      '${_state.dungeonId} F${_state.currentRoom.floorNumber} · '
          'KEY +${_state.hardmodeLevel}',
    );
    showToast(StoryLore.enterDungeon(dungeonId), life: 1.35);
    unawaited(
      AppAnalytics.enterDungeon(
        dungeonId: dungeonId,
        keyLevel: _state.hardmodeLevel,
        floor: _state.currentRoom.floorNumber,
      ),
    );
    notifyListeners();
    unawaited(_persistFlush());
    _syncSituationMusic();
  }

  void leaveDungeon() {
    clearLootLog();
    hudFocusEnemyId = null;
    cameraHeroIndex = null;
    _dungeonTilesReady = false;
    if (_isLoading) return;
    _awaitingWipeChoice = false;
    final hadSpeedBoost = AdBoost.speedActive(_state.metaDepth);
    final leaveDungeonId = _state.dungeonId;
    final leaveFloor = _state.currentRoom.floorNumber;
    _state = GameLogic.ensureWeeklyContract(GameLogic.leaveDungeon(_state));
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _spatial = null;
    _freezeRunIncome();
    _state = _state.copyWith(lastUpdated: DateTime.now());
    _maybeLogHubChase();
    DebugPlayLog.event('leave', DebugPlayLog.bootDetail(_state));
    unawaited(
      AppAnalytics.leaveDungeon(dungeonId: leaveDungeonId, floor: leaveFloor),
    );
    _syncHubIdleTimer();
    final payoffs = LogicNotices.takeMetaPayoffs();
    if (payoffs.isNotEmpty) {
      showToast(payoffs.join(' · '), life: 3.0);
    } else if (hadSpeedBoost) {
      showToast('Dungeon speed back to 1× in hub', life: 2.2);
    } else {
      showToast('Returned to hub', life: 2);
    }
    notifyListeners();
    unawaited(_persistFlush());
    _syncSituationMusic();
  }

  void upgradeGodHand() {
    final before = _state.godHandLevel;
    _applyUpgrade(GameLogic.upgradeGodHand(_state));
    if (_state.godHandLevel > before) {
      GameAudio.forgeUp();
      showToast(
        'God Hand Lv${_state.godHandLevel} · smash ${_state.godHandSmashDamage()}',
        life: 2.4,
      );
    }
  }

  void setDungeonMode(DungeonMode mode) {
    final before = _state.dungeonMode;
    _applyUpgrade(GameLogic.setDungeonMode(_state, mode));
    if (_state.dungeonMode != before) {
      GameAudio.uiTab();
      showToast(
        _state.dungeonMode == DungeonMode.farm
            ? 'FARM — loop this floor for loot · 0 essence'
            : 'PUSH — clear to advance · +1e clear · +2e boss',
        life: 2.2,
      );
    }
  }

  void travelToFloor(int floorNumber) {
    if (_state.inGauntlet || _state.inAnyRiftMode) {
      showToast(
        _state.inGauntlet
            ? 'Gauntlet — no floor jump (endless climb; wipe/leave → hub)'
            : _state.inGreaterRift
            ? 'Ranked GR — no floor jump (timer run; leave → hub)'
            : 'Farm Rift — no floor jump (kill-quota run; leave → hub)',
        life: 2.0,
      );
      return;
    }
    final before = _state.currentRoom.floorNumber;
    _applyUpgrade(GameLogic.travelToFloor(_state, floorNumber));
    final after = _state.currentRoom.floorNumber;
    if (after != before) {
      _beginFloorClock();
      showToast('Floor $after · party healed', life: 2.0);
    }
  }
}
