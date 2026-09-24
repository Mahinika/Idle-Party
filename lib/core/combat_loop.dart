part of 'game_director.dart';

/// Dungeon clock (~60 Hz). Tick order stays on this path.
extension GameDirectorCombatLoop on GameDirector {
  void tickDungeonClock() {
    if (_isLoading || !_state.inDungeon || _spatial == null) {
      return;
    }
    // Freeze sim while wipe modal is up (avoids toast/SFX spam).
    if (_awaitingWipeChoice) {
      return;
    }
    // Soft-pause while inventory / meta menus cover the fight.
    if (_uiPaused) {
      return;
    }
    // Hard pause while the app is backgrounded.
    if (_appPaused) {
      return;
    }

    // Room changed externally (travel / ascend / restart)
    if (_battleToken != _state.battleNumber) {
      _rebuildSpatial();
    }

    final steps = _debugTimeScale.round().clamp(1, 20);
    var playedLoot = false;
    for (var step = 0; step < steps; step++) {
      if (_awaitingWipeChoice ||
          _uiPaused ||
          _appPaused ||
          !_state.inDungeon ||
          _spatial == null) {
        break;
      }
      if (_battleToken != _state.battleNumber) {
        _rebuildSpatial();
      }

      final dt = GameDirector._spatialDt * AdBoost.combatDtMul(_state.metaDepth);
      final dtMs = (dt * 1000).round();

      final result = SpatialCombat.step(_spatial!, _state, dt: dt);
      final before = _state;
      _spatial = result.world;
      _state = result.state;
      // Keystone timer (idle-friendly; also advanced in offline catch-up).
      if (_state.keystoneRunActive) {
        _state = GameLogic.advanceKeystoneTimer(_state, dtMs);
      }
      if (_state.inRift) {
        _state = GameLogic.advanceRiftTimer(_state, dtMs);
        if (result.kills > 0) {
          _state = GameLogic.noteRiftKills(_state, result.kills);
        }
        final beforeGuardian = _state.riftGuardianActive;
        _state = GameLogic.maybeActivateRiftGuardian(_state);
        if (_state.riftGuardianActive && !beforeGuardian) {
          _rebuildSpatial();
        }
        final resolved = GameLogic.tryResolveRift(_state);
        if (resolved != null) {
          _state = resolved;
          _spatialTimer?.cancel();
          _spatialTimer = null;
          _spatial = null;
          _awaitingWipeChoice = false;
          showToast(
            _state.metaDepth.riftBestTier > 0
                ? 'Rift resolved · best R${_state.metaDepth.riftBestTier}'
                : 'Rift ended',
            life: 3.0,
          );
          _notifyShell();
          unawaited(_persistFlush());
          return;
        }
      }
      if (_state.inGreaterRift) {
        _state = GameLogic.advanceGreaterRiftTimer(_state, dtMs);
        if (result.kills > 0) {
          _state = GameLogic.noteGreaterRiftKills(_state, result.kills);
        }
        final beforeGuardian = _state.grGuardianActive;
        _state = GameLogic.maybeActivateGreaterRiftGuardian(_state);
        if (_state.grGuardianActive && !beforeGuardian) {
          _rebuildSpatial();
        }
        final resolved = GameLogic.tryResolveGreaterRift(_state);
        if (resolved != null) {
          _state = resolved;
          _spatialTimer?.cancel();
          _spatialTimer = null;
          _spatial = null;
          _awaitingWipeChoice = false;
          showToast(
            _state.metaDepth.grBestTier > 0
                ? 'Greater Rift · best GR${_state.metaDepth.grBestTier}'
                : 'Greater Rift ended',
            life: 3.0,
          );
          _notifyShell();
          unawaited(_persistFlush());
          return;
        }
      }
      // Only bank this-tick kill gold — clear-frame must not re-fold the room.
      // Kill gold is credited immediately below (survives wipe).
      // Credit kill gold immediately so wipe cannot erase floater "+Ng".
      if (result.goldFromKills > 0) {
        _state = GameLogic.creditCombatGold(_state, result.goldFromKills);
        _applyFunnelTick(FunnelAnalytics.onFirstReward(_state));
        _flushQuestReadyToast(life: 1.8);
      }
      _noteLifetimeGold(before, _state);
      // Count casts live; defer achievement scan to room clear / discrete events.
      if (result.abilityCasts > 0) {
        _state = _state.copyWith(
          metaDepth: _state.metaDepth.copyWith(
            lifetimeAbilityCasts:
                _state.metaDepth.lifetimeAbilityCasts + result.abilityCasts,
          ),
        );
      }
      _tickUiTimers(dt);
      _announceAbilityUnlocks(before, _state);
      _announceAchievementUnlocks(before, _state);
      if (result.critHits > 0 && _feelCritCooldown <= 0) {
        GameAudio.crit();
        _feelCritCooldown = 0.16;
        pulseCombatShake(0.45);
      }
      if (result.kills > 0 && _feelKillCooldown <= 0) {
        GameAudio.kill();
        _feelKillCooldown = 0.22;
        pulseCombatShake(0.28);
      }

      // Live auto-flask (same threshold as AFK): avg living HP < 35%.
      if (step == 0 &&
          GameLogic.canUseConsumable(_state) &&
          !_state.isPartyDefeated) {
        var livingCount = 0;
        var ratioSum = 0.0;
        for (final h in _state.heroes) {
          if (h.currentHp <= 0) continue;
          livingCount++;
          final maxHp = _state.effectiveHeroMaxHp(h);
          ratioSum += maxHp > 0 ? h.currentHp / maxHp : 0;
        }
        if (livingCount > 0 && ratioSum / livingCount < 0.35) {
          final hpBefore = <String, int>{
            for (final h in _state.heroes) h.id: h.currentHp,
          };
          final drank = GameLogic.useConsumable(_state);
          if (!identical(drank, _state)) {
            _state = drank;
            _spatial = SpatialCombat.syncPartyFromState(_spatial!, _state);
            final healed = <String>{
              for (final h in _state.heroes)
                if ((hpBefore[h.id] ?? h.currentHp) < h.currentHp) h.id,
            };
            SpatialCombat.spawnFlaskHealFx(
              _spatial!,
              reducedVfx: _state.reducedVfx,
              healedHeroIds: healed,
            );
            GameAudio.flask();
          }
        }
      }

      if (result.feelHits.isNotEmpty) {
        for (final hit in result.feelHits) {
          GameAudio.playCombatHit(hit);
        }
      }
      if (result.lootPickups > 0 && !playedLoot) {
        GameAudio.loot();
        playedLoot = true;
      }
      if (result.stairsOpened) {
        GameAudio.clear();
        // Corner CLEAR + HOLD own the walk — no second center “congrats” yet.
      }
      if (result.state.gearStash.length > _lastStashLen) {
        if (!playedLoot) {
          GameAudio.loot();
          playedLoot = true;
        }
        // Loot stays in BAG — equip via PARTY → AUTO EQUIP (not mid-fight).
      }
      final stashCap = GameLogic.maxGearStashFor(_state);
      var bagFullHandled = false;
      if (before.gearStash.length < stashCap &&
          _state.gearStash.length >= stashCap) {
        // Light auto-clean so salvage floaters don't spam every pickup.
        bagFullHandled = true;
        final beforeClean = _state.gearStash.length;
        _state = GameLogic.cleanBagJunk(
          _state,
          unstickBag: true,
          mergeFirst: true,
        );
        LogicNotices.takeBagCleanup();
        final cleared = beforeClean - _state.gearStash.length;
        _toastBagCleanup(
          cleared > 0
              ? 'Bag cleared $cleared junk — keep farming'
              : 'Bag full — oldest loot → essence',
          life: cleared > 0 ? 2.4 : 2.2,
        );
      }
      final cleanup = LogicNotices.takeBagCleanup();
      if (!cleanup.isEmpty && !bagFullHandled) {
        final bits = <String>[
          if (cleanup.sold > 0)
            'sold ${cleanup.sold} (+${cleanup.goldGained}g)',
          if (cleanup.scrapped > 0)
            'scrap ${cleanup.scrapped} (+${cleanup.essenceGained}e)',
        ];
        _toastBagCleanup('Bag unstuck · ${bits.join(' · ')}', life: 1.8);
      }
      _lastStashLen = _state.gearStash.length;

      _autosaveAccum += GameDirector._spatialDt;
      if (_autosaveAccum >= GameDirector._autosaveIntervalSec) {
        _autosaveAccum = 0;
        _persist();
      }

      if (result.partyWiped) {
        _awaitingWipeChoice = true;
        _spatialTimer?.cancel();
        _spatialTimer = null;
        GameAudio.wipe();
        // Panel owns the wipe copy — drop CLEAR/bag toast so it does not
        // draw on top of PARTY WIPED.
        clearToast();
        final spatial = _spatial;
        if (spatial != null) {
          _state = GameLogic.notePartyWipe(
            _state,
            WipeFightSnapshot.fromWorld(spatial),
          );
          DebugPlayLog.event(
            'wipe',
            'F${_state.currentRoom.floorNumber} · '
                'streak ${_state.wipeStreakCount} · '
                '${_state.wipeAdviceLine.isEmpty ? 'quiet' : _state.wipeAdviceLine}',
          );
          _state = SessionTelemetry.append(
            _state,
            'wipe',
            'F${_state.currentRoom.floorNumber}|'
                'streak${_state.wipeStreakCount}|'
                '${_state.wipeAdviceLine.isEmpty ? 'quiet' : _state.wipeAdviceLine}',
          );
          unawaited(
            AppAnalytics.partyWipe(
              dungeonId: _state.dungeonId,
              floor: _state.currentRoom.floorNumber,
              streak: _state.wipeStreakCount,
            ),
          );
        }
        // No WIPED toast — DungeonWipePanel + top HUD already say it.
        _notifyShell();
        return;
      }

      // Rift / GR Guardian phase replaces trash — do not floor-advance away.
      if (result.roomCleared &&
          !_state.riftGuardianActive &&
          !_state.grGuardianActive) {
        final floorNo = _state.currentRoom.floorNumber;
        final started = _floorStartedAt;
        if (started != null) {
          _lastFloorClearSec = DateTime.now()
              .difference(started)
              .inSeconds
              .clamp(1, 9999);
        }
        final wasTreasure = _spatial?.isTreasure ?? false;
        // Combat gold already credited per kill; treasure pays scaled chest budget.
        final gold = wasTreasure ? GameLogic.treasureGoldBudget(_state) : 0;
        final beforeDungeon = _state.highestDungeonCleared;
        final wasBoss = _state.currentRoom.type == RoomType.boss;
        final beforeClear = _state;
        // Combat: kill gear already on pickup; floor fillers roll here.
        // Treasure: also rolls chest gear (skipLootRoll: false).
        _state =
            GameLogic.completeCurrentRoom(
              _state,
              goldGain: gold,
              skipLootRoll: _state.inGreaterRift || !wasTreasure,
            ).copyWith(
              lastUpdated: DateTime.now(),
              lastFloorClearSec: _lastFloorClearSec ?? _state.lastFloorClearSec,
            );
        _noteLifetimeGold(beforeClear, _state);
        if (_state.lifetimeGoldEarned > beforeClear.lifetimeGoldEarned) {
          _applyFunnelTick(
            FunnelAnalytics.onFirstReward(_state),
            persist: false,
          );
        }
        if (wasBoss) {
          _applyFunnelTick(FunnelAnalytics.onFirstBoss(_state), persist: false);
        }
        // Level / achievement toasts wait — one clear banner owns the beat.
        final leveledHeroes = <int>[];
        for (var i = 0; i < _state.heroes.length; i++) {
          final oldLevel = i < beforeClear.heroes.length
              ? beforeClear.heroes[i].level
              : 0;
          if (_state.heroes[i].level > oldLevel) leveledHeroes.add(i);
        }
        final leveled = leveledHeroes.isNotEmpty;
        if (wasBoss) {
          GameAudio.boss();
        }
        // Clear sting already played when stairs opened.
        _state = MetaSystems.evaluateAchievements(_state);
        final goldDelta = _state.gold - beforeClear.gold;
        final essDelta = _state.essence - beforeClear.essence;
        var clearLine = goldDelta > 0
            ? 'F$floorNo CLEAR · +${goldDelta}g'
            : 'F$floorNo CLEAR';
        if (beforeClear.inGauntlet) {
          clearLine = essDelta > 0
              ? 'Spire F$floorNo · +${goldDelta}g · +${essDelta}e'
              : 'Spire F$floorNo · +${goldDelta}g';
        }
        if (leveled) {
          clearLine = '$clearLine · LEVEL UP';
          GameAudio.levelUp();
        }
        final matGrants = LogicNotices.takeCraftMats();
        final floorLoot = LogicNotices.takeFloorLootLine();
        final floorEquip = LogicNotices.takeFloorEquipLine();
        final clearExtra = floorLoot ?? floorEquip;
        if (clearExtra != null && (clearLine.length + clearExtra.length) < 70) {
          clearLine = '$clearLine · $clearExtra';
        }
        if (matGrants.isNotEmpty) {
          final labels = [
            for (final id in matGrants) ApexCraft.materialsById[id]?.name ?? id,
          ];
          final matBit = '+${labels.take(2).join(', ')}';
          if ((clearLine.length + matBit.length) < 70) {
            clearLine = '$clearLine · $matBit';
          }
        }
        final payoffNotices = LogicNotices.takeMetaPayoffs();
        final questReady = _questReadyLine();
        if (questReady != null && (clearLine.length + questReady.length) < 72) {
          clearLine = '$clearLine · $questReady';
        }
        // KEY TIMED / depleted owns the clear banner (bigger than F CLEAR).
        final keyBanner = payoffNotices.cast<String?>().firstWhere(
          (n) =>
              n != null &&
              (n.contains('TIMED') || n.toLowerCase().contains('depleted')),
          orElse: () => null,
        );
        if (keyBanner != null) {
          final timed = keyBanner.contains('TIMED');
          presentClear(keyBanner, life: timed ? 4.0 : 3.6);
          final rest = payoffNotices.where((n) => n != keyBanner).toList();
          if (rest.isNotEmpty) {
            // After banner — toast only if something KEY-adjacent remains.
            showToast(rest.join(' · '), life: 2.6);
          } else if (questReady != null) {
            showToast(questReady, life: 2.4);
          }
        } else {
          presentClear(clearLine, life: 2.8);
          // Rare extras only — never restate F CLEAR / gold / loot.
          if (payoffNotices.isNotEmpty) {
            showToast(payoffNotices.join(' · '), life: 2.6);
          }
        }
        // Ability unlocks (not bare LEVEL UP) — one line if any.
        if (leveled) {
          final bits = <String>[];
          for (final i in leveledHeroes) {
            final hero = _state.heroes[i];
            final oldLevel = beforeClear.heroes[i].level;
            final unlocked = ClassKits.unlockedAtSpec(hero.specId, hero.level)
                .where(
                  (d) =>
                      d.unlockLevel > oldLevel && d.unlockLevel <= hero.level,
                );
            for (final ability in unlocked) {
              bits.add('${hero.name}: ${ability.shortLabel}');
            }
          }
          if (bits.isNotEmpty) {
            showToast(
              bits.length == 1
                  ? '${bits.first}!'
                  : '${bits.take(2).join(' · ')}!',
              life: 2.2,
            );
          }
        }
        _announceAchievementUnlocks(beforeClear, _state);
        // GEAR badge already shows upgrade count — no CLEAR-time toast spam.
        if (_state.highestDungeonCleared > beforeDungeon) {
          GameAudio.unlock();
          String? nextId;
          for (final d in DungeonCatalog.all) {
            if (d.number == _state.highestDungeonCleared + 1) {
              nextId = d.id;
              break;
            }
          }
          showToast(
            nextId != null
                ? StoryLore.unlockedNextZone(nextId)
                : StoryLore.dungeonCleared(beforeClear.dungeonId),
            life: 3.0,
          );
          _lastHighestDungeon = _state.highestDungeonCleared;
        } else if (_state.highestDungeonCleared > _lastHighestDungeon) {
          _lastHighestDungeon = _state.highestDungeonCleared;
          showToast(StoryLore.dungeonCleared(beforeClear.dungeonId), life: 3.0);
        }
        if (_state.inDungeon) {
          _rebuildSpatial();
          _beginFloorClock();
        } else {
          _spatialTimer?.cancel();
          _spatial = null;
          _freezeRunIncome();
          if (beforeClear.dungeonMode == DungeonMode.push && wasBoss) {
            presentClear(
              'ZONE DONE · ${DungeonCatalog.byId(beforeClear.dungeonId).name}',
              life: 2.8,
            );
          } else {
            showToast(
              StoryLore.dungeonCleared(beforeClear.dungeonId),
              life: 3.2,
            );
          }
        }
        _bumpCombatFrame();
        _notifyShell();
        unawaited(_persistFlush());
        return;
      }

      _bumpCombatFrame();
    }

    _uiThrottle++;
    if (!_runIncomeFrozen && _state.inDungeon && _uiThrottle % 60 == 0) {
      _refreshRunGpm(DateTime.now().millisecondsSinceEpoch);
    }
    // Shell chrome (~10 Hz); map/HUD corners listen to [combatFrame] at 60 Hz.
    if (_uiThrottle % GameDirector._shellNotifyEvery == 0) {
      _notifyShell();
    }
  }
}
