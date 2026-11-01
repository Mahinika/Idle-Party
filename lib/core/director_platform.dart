part of 'game_director.dart';

/// Platform — extracted from GameDirector.
extension GameDirectorPlatform on GameDirector {
  FriendReferralSync get _friends =>
      _friendSync ??= friend_live.liveFriendReferralSync();

  /// Test hook: friend list without Firebase.
  @visibleForTesting
  void debugSetFriendSync(FriendReferralSync sync) {
    _friendSync = sync;
  }

  Future<void> _runFriend(
    Future<FriendReferralOutcome> Function(FriendReferralSync sync) body,
  ) {
    final run = _friendChain.then((_) async {
      try {
        if (_isLoading) return;
        final epoch = _friendEpoch;
        final start = _state;
        final outcome = await body(_friends);
        if (epoch != _friendEpoch || _isLoading) return;
        final merged = FriendReferral.mergeOnto(_state, start, outcome.state);
        if (!identical(merged, _state)) {
          _applyUpgrade(merged);
        }
        final toast = outcome.toast;
        if (toast != null && toast.isNotEmpty) {
          showToast(toast, life: 2.6);
        }
      } catch (e, st) {
        debugPrint('Friend referral failed: $e\n$st');
      }
    });
    _friendChain = run;
    return run;
  }

  /// Register this save's code, pay new friends, and read a Play install link.
  Future<void> syncFriendReferral() => _runFriend((sync) => sync.sync(_state));

  /// Create a code if needed and open the Android share sheet.
  /// The code is saved before the sheet so a friend can count if the app
  /// closes while sharing.
  Future<void> shareFriendInvite() async {
    if (!FriendReferral.isValidCode(_state.metaDepth.friendCode)) {
      _applyUpgrade(
        _state.copyWith(
          metaDepth: _state.metaDepth.copyWith(
            friendCode: FriendReferral.newCode(math.Random.secure()),
          ),
        ),
      );
      await _persistFlush();
    }
    await _runFriend((sync) => sync.shareInvite(_state));
  }

  /// Friend types a code in SCROLLS. One phone, one invite.
  Future<void> applyFriendCode(String raw) =>
      _runFriend((sync) => sync.applyCode(_state, raw));
  void tickWisp({int deltaMs = 200}) {
    if (_isLoading) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final md = _state.metaDepth;
    if (!WispGift.unlocked(md) || !WispGift.canTapToday(md)) {
      if (_wispVisibleRemainingMs > 0) {
        _wispVisibleRemainingMs = 0;
        _wispSpawnArmed = false;
        _directorNotify();
      }
      return;
    }
    // Debug cadence is 20s. A save still waiting on the live 10-minute
    // timer would hide the gift — pull that clock forward once.
    if (WispGift.unlimitedToday &&
        md.wispNextSpawnMs > now + WispGift.intervalMs) {
      _applyUpgrade(
        _state.copyWith(metaDepth: md.copyWith(wispNextSpawnMs: now)),
      );
    }
    // Hub: do not spawn or burn the lantern window. Schedule stays ready
    // until the player is in a cave.
    if (!_state.inDungeon) return;
    final schedule = _state.metaDepth;
    if (_wispChoiceOpen) return;
    if (_wispVisibleRemainingMs > 0) {
      if (!_wispMenuPaused) {
        final next = _wispVisibleRemainingMs - deltaMs;
        if (next <= 0) {
          _wispVisibleRemainingMs = 0;
          _wispSpawnArmed = false;
          if (!_wispTappedThisWindow) {
            _applyUpgrade(WispGift.onWispMissed(_state, nowMs: now));
          }
          _directorNotify();
        } else {
          _wispVisibleRemainingMs = next;
        }
      }
      return;
    }
    if (WispGift.shouldSpawn(schedule, now)) {
      if (!_wispSpawnArmed) {
        _wispSpawnArmed = true;
        _wispTappedThisWindow = false;
        _wispVisibleRemainingMs = WispGift.visibleMs;
        _directorNotify();
      }
    } else {
      _wispSpawnArmed = false;
    }
  }

  void tapWispGift() {
    if (!isWispVisible) return;
    _wispVisibleRemainingMs = 0;
    _wispSpawnArmed = false;
    _wispTappedThisWindow = true;
    final adFree = _state.metaDepth.adFree;
    final keepBefore = _state.gold;
    _applyUpgrade(WispGift.onWispTapped(_state));
    final keep = _state.gold - keepBefore;
    GameAudio.gold();
    showToast('WISP · +$keep gold', life: 2.2);
    if (adFree) {
      _grantWispWatchReward(toast: true);
    }
    _directorNotify();
    unawaited(_persistFlush());
  }

  void dismissWispPending() {
    if (!wispPendingChoice) return;
    _applyUpgrade(WispGift.dismissPending(_state));
    _directorNotify();
    unawaited(_persistFlush());
  }

  void _grantWispWatchReward({bool toast = true}) {
    if (!wispPendingChoice) return;
    final before = _state.gold;
    _applyUpgrade(WispGift.grantWatchReward(_state));
    final gained = _state.gold - before;
    if (toast) {
      GameAudio.gold();
      showToast('WISP · +$gained gold', life: 2.8);
    }
    _directorNotify();
    unawaited(_persistFlush());
  }

  /// Optional Welcome Back watch. Doubles [baseGold] and [baseEssence]
  /// already credited. Skip, fail, or ad-free grants nothing.
  Future<bool> watchWelcomeBackGoldAd(
    int baseGold, {
    int baseEssence = 0,
  }) async {
    if ((baseGold <= 0 && baseEssence <= 0) ||
        _welcomeBackAdGranted ||
        _welcomeBackAdBusy) {
      return false;
    }
    if (_isLoading) return false;
    final md = _state.metaDepth;
    if (md.adFree || AdBoost.hasPerm(md, AdBoost.permRest)) return false;
    if (!GameLogic.showDailyChase(_state)) return false;
    if (!AdRewarded.realAdsAvailable) {
      showToast('Ads play on the Android app', life: 2.2);
      return false;
    }
    _welcomeBackAdBusy = true;
    showToast('Loading ad…', life: 1.4);
    unawaited(AppAnalytics.welcomeBackAdTap());
    try {
      final result = await AdRewarded.showRewarded(
        placement: AnalyticsEvents.placementWelcomeBack,
      );
      switch (result) {
        case AdWatchResult.rewarded:
          noteCompletedRewardedWatch();
          _welcomeBackAdGranted = true;
          final beforeGold = _state.gold;
          final beforeEssence = _state.essence;
          _applyUpgrade(
            GameLogic.grantWelcomeBackWatchGold(
              _state,
              baseGold,
              baseEssence: baseEssence,
            ),
          );
          final gained = _state.gold - beforeGold;
          final essence = _state.essence - beforeEssence;
          if (gained <= 0 && essence <= 0) {
            _welcomeBackAdGranted = false;
            return false;
          }
          GameAudio.gold();
          showToast('Welcome Back · loot doubled', life: 2.4);
          unawaited(
            AppAnalytics.logEvent('welcome_back_ad', {
              'gold': gained,
              'essence': essence,
            }),
          );
          return true;
        case AdWatchResult.skipped:
          unawaited(AppAnalytics.welcomeBackAdSkip());
          showToast(
            'Watch the whole ad to double this trip\'s loot',
            life: 2.2,
          );
          return false;
        case AdWatchResult.failed:
          showToast('Ad not ready — try again in a bit', life: 2.2);
          return false;
        case AdWatchResult.unavailable:
          showToast('Ads play on the Android app', life: 2.2);
          return false;
      }
    } finally {
      _welcomeBackAdBusy = false;
    }
  }

  /// Rewarded ad for the locked WATCH pile. Plays where the lantern was tapped.
  Future<void> watchWispGiftAd() async {
    if (!wispPendingChoice) return;
    _wispChoiceOpen = true;
    if (!AdRewarded.realAdsAvailable) {
      showToast('Ads play on the Android app', life: 2.2);
      _wispChoiceOpen = false;
      return;
    }
    showToast('Loading ad…', life: 1.4);
    final result = await AdRewarded.showRewarded(
      placement: AnalyticsEvents.placementWispGift,
    );
    _wispChoiceOpen = false;
    switch (result) {
      case AdWatchResult.rewarded:
        noteCompletedRewardedWatch();
        _grantWispWatchReward();
      case AdWatchResult.skipped:
        showToast('Watch the whole ad for the WISP bonus', life: 2.2);
        dismissWispPending();
      case AdWatchResult.failed:
        showToast('Ad not ready — try again in a bit', life: 2.2);
        dismissWispPending();
      case AdWatchResult.unavailable:
        showToast('Ads play on the Android app', life: 2.2);
        dismissWispPending();
    }
  }

  Future<void> acceptNotifyOptIn() async {
    _applyNotify(LocalReminders.setOptIn(_state, enabled: true));
    unawaited(AppAnalytics.logEvent('notify_opt_in', {'source': 'card'}));
    final granted = await LocalNotify.requestPermission();
    if (!granted) {
      _applyNotify(LocalReminders.setOptIn(_state, enabled: false));
      unawaited(
        AppAnalytics.logEvent('notify_opt_out', {
          'source': 'card',
          'reason': 'os',
        }),
      );
    }
  }

  void declineNotifyOptIn() {
    _applyNotify(LocalReminders.setOptIn(_state, enabled: false));
    unawaited(
      AppAnalytics.logEvent('notify_opt_out', {
        'source': 'card',
        'reason': 'dismiss',
      }),
    );
  }

  Future<void> setNotifyOptIn(bool value) async {
    if (value) {
      final granted = await LocalNotify.requestPermission();
      if (!granted) {
        _applyNotify(LocalReminders.setOptIn(_state, enabled: false));
        unawaited(
          AppAnalytics.logEvent('notify_opt_out', {
            'source': 'settings',
            'reason': 'os',
          }),
        );
        return;
      }
    } else {
      unawaited(LocalNotify.cancelAll());
    }
    _applyNotify(LocalReminders.setOptIn(_state, enabled: value));
    unawaited(
      AppAnalytics.logEvent(value ? 'notify_opt_in' : 'notify_opt_out', {
        'source': 'settings',
      }),
    );
  }

  /// Reminder flags must apply even on [GameDirector.preview] (still loading).
  void _applyNotify(GameState updated) {
    if (identical(updated, _state)) return;
    _state = updated;
    _directorNotify();
    unawaited(_persistFlush());
  }

  Future<void> _syncAwayReminders({required bool backgrounded}) async {
    if (backgrounded) {
      final now = DateTime.now();
      final pings = LocalReminders.plan(_state, now);
      final tray = LocalReminders.chestTray(_state, now);
      final next = LocalReminders.recordPlan(_state, pings, now: now);
      if (!identical(next, _state)) _applyNotify(next);
      await LocalNotify.present(pings: pings, tray: tray);
    } else {
      await LocalNotify.cancelAll();
      final next = LocalReminders.clearFuture(_state, DateTime.now());
      if (!identical(next, _state)) _applyNotify(next);
    }
  }
  // —— Save export / import ——————————————————————————————————————

  String exportSaveJson() => GameLogic.exportSaveJson(_state);

  /// Returns true on success. On failure the current state is untouched.
  bool importSaveJson(String raw) {
    final imported = GameLogic.importSaveJson(raw);
    if (imported == null) return false;
    _awaitingWipeChoice = false;
    _state = GameLogic.ensureRogueHero(imported);
    _hasExistingSave = true;
    _syncDevicePrefs();
    if (_state.inDungeon) {
      _rebuildSpatial();
      if (enableSpatialLoop) {
        _startSpatialLoop();
      }
    } else {
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    }
    _rememberActiveSummary();
    _directorNotify();
    unawaited(_persistFlush());
    return true;
  }

  void _rememberActiveSummary() {
    if (_activeSlot < 0 || _activeSlot >= _saveSlots.length) return;
    final next = List<SaveSlotSummary>.from(_saveSlots);
    next[_activeSlot] = SaveSlotSummary.fromState(_activeSlot, _state);
    _saveSlots = next;
  }

  /// Play-installed Android with a newer build on the store — blocks cold start.
  bool get mandatoryPlayUpdateRequired => _mandatoryPlayUpdateRequired;

  /// Probe Play for a mandatory update gate. Sideload / web / tests → false.
  Future<bool> checkMandatoryPlayUpdate() async {
    if (!PlayStoreUpdate.isSupported) {
      _mandatoryPlayUpdateRequired = false;
      return false;
    }
    final code = await PlayStoreUpdate.availableVersionCode();
    _playUpdateVersionCode = code;
    _mandatoryPlayUpdateRequired = code != null && code > 0;
    _directorNotify();
    return _mandatoryPlayUpdateRequired;
  }

  /// Immediate Play update, then flexible, then listing. Stays blocking on deny.
  Future<void> startMandatoryPlayUpdate() async {
    final started = await PlayStoreUpdate.startMandatoryUpdate();
    if (started) {
      showToast('Updating from Google Play…', life: 3.2);
      return;
    }
    showToast('Could not open Google Play', life: 2.4);
  }

  /// True when Play reports a newer version than this install, and LATER was
  /// not tapped for that versionCode.
  bool get showPlayUpdateNotice {
    final code = _playUpdateVersionCode;
    if (code == null || code <= 0) return false;
    return code > _state.metaDepth.dismissedPlayUpdateVersionCode;
  }

  Future<void> refreshPlayUpdateNotice() async {
    final code = await PlayStoreUpdate.availableVersionCode();
    if (code == _playUpdateVersionCode) return;
    _playUpdateVersionCode = code;
    _directorNotify();
  }

  void dismissPlayUpdateNotice() {
    final code = _playUpdateVersionCode;
    if (code == null || code <= 0) return;
    _state = _state.copyWith(
      metaDepth: _state.metaDepth.copyWith(
        dismissedPlayUpdateVersionCode: code,
      ),
    );
    _directorNotify();
    unawaited(_persistFlush());
  }

  Future<void> openPlayUpdate() async {
    final started = await PlayStoreUpdate.startFlexibleUpdate();
    if (started) {
      showToast('Downloading on Google Play…', life: 3.2);
      return;
    }
    final opened = await PlayStoreUpdate.openListing();
    if (!opened) {
      showToast('Could not open Google Play', life: 2.2);
    }
  }

  /// One-time Play in-app review (or listing fallback). Never pays loot.
  Future<void> requestPlayReview({String source = 'card'}) async {
    final already = _state.metaDepth.reviewPrompted;
    _applyNotify(PlayReviewAsk.markPrompted(_state));
    clearReviewWelcome();
    unawaited(AppAnalytics.logEvent('review_prompt', {'source': source}));
    final sheet = await PlayStoreUpdate.requestInAppReview();
    if (sheet) return;
    final opened = await PlayStoreUpdate.openListing();
    if (!opened && source == 'settings' && !already) {
      showToast('Could not open Google Play', life: 2.2);
    }
  }

  void dismissPlayReviewAsk() {
    _applyNotify(PlayReviewAsk.snooze(_state));
    clearReviewWelcome();
    unawaited(
      AppAnalytics.logEvent('review_prompt', {
        'source': 'card',
        'result': 'later',
      }),
    );
  }

  /// Stamp the tomorrow line on the UTC day the first boss is already down.
  void armAwayPromise() {
    final next = AwayFightTip.arm(_state, DateTime.now());
    if (identical(next, _state)) return;
    _applyNotify(next);
  }

  /// Legacy dismiss. The appointment now hides on the next UTC day.
  void dismissAwayFightTip() {
    _applyNotify(AwayFightTip.markSeen(_state));
  }

  /// Debug cold-start gate — pretends Play has a newer build.
  void debugForceMandatoryPlayUpdate() {
    _playUpdateVersionCode = 999999;
    _mandatoryPlayUpdateRequired = true;
    _directorNotify();
  }

  /// Debug hub layout — pretends Play has a newer build.
  void debugForcePlayUpdateNotice() {
    _playUpdateVersionCode = 999999;
    _directorNotify();
  }

  /// Opt-in Play Games sign-in (leaderboards + cloud). Returns true when signed in.
  Future<bool> signInPlayGames() async {
    final ok = await PlayGamesBridge.signIn();
    if (!ok) {
      showToast(
        PlayGamesBridge.isSupported
            ? 'Play Games sign-in failed'
            : 'Play Games unavailable on this build',
        life: 2.4,
      );
      return false;
    }
    _state = _state.copyWith(
      metaDepth: _state.metaDepth.copyWith(playGamesOptIn: true),
    );
    _directorNotify();
    final cloud = await PlayGamesBridge.loadCloud();
    if (cloud != null && !_hasExistingSave) {
      _applyCloudRestore(cloud, toast: 'Restored from Play Games');
    } else if (cloud == null && !_hasExistingSave) {
      showToast('Signed in · no cloud save yet', life: 2.2);
    } else {
      showToast('Signed in to Play Games', life: 2.0);
    }
    unawaited(PlayGamesBridge.saveCloud(_state));
    unawaited(PlayGamesBridge.flushPendingScores());
    unawaited(_persistFlush());
    return true;
  }

  void _applyCloudRestore(GameState cloud, {required String toast}) {
    _awaitingWipeChoice = false;
    _hasExistingSave = true;
    _state = GameLogic.ensureRogueHero(GameLogic.ensureWeeklyContract(cloud));
    _syncDevicePrefs();
    if (_state.inDungeon) {
      _rebuildSpatial();
      if (enableSpatialLoop) _startSpatialLoop();
    } else {
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    }
    _rememberActiveSummary();
    _directorNotify();
    showToast(toast, life: 2.6);
  }

  Future<bool> backupToPlayGames() async {
    final ok = await PlayGamesBridge.saveCloud(_state);
    showToast(
      ok ? 'Backed up to Play Games' : 'Cloud backup failed',
      life: 2.2,
    );
    return ok;
  }

  Future<bool> restoreFromPlayGames({bool force = false}) async {
    final cloud = await PlayGamesBridge.loadCloud();
    if (cloud == null) {
      showToast('No Play Games save found', life: 2.2);
      return false;
    }
    if (!force) {
      final decision = PlayGamesScores.resolveConflict(
        localMs: _state.metaDepth.cloudSaveUpdatedMs,
        cloudMs: cloud.metaDepth.cloudSaveUpdatedMs,
      );
      if (decision == CloudConflict.preferLocal) {
        showToast('This device is newer — kept local save', life: 2.4);
        return false;
      }
      if (decision == CloudConflict.askUser) {
        // Caller should show confirm; force=true after confirm.
        return false;
      }
    }
    _applyCloudRestore(cloud, toast: 'Restored from Play Games');
    unawaited(_persistFlush());
    return true;
  }

  /// Hint lines for cloud conflict dialogs.
  String playGamesConflictHint(GameState s) => PlayGamesBridge.conflictHint(s);

  CloudConflict peekCloudConflict(GameState cloud) =>
      PlayGamesScores.resolveConflict(
        localMs: _state.metaDepth.cloudSaveUpdatedMs,
        cloudMs: cloud.metaDepth.cloudSaveUpdatedMs,
      );

  Future<GameState?> loadPlayGamesCloud() => PlayGamesBridge.loadCloud();
}
