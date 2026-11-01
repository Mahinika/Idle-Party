import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/achievement_def.dart';
import '../models/apex_craft.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/dungeon_zoom.dart';
import '../models/class_ability.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/market_listing.dart';
import '../models/meta_depth.dart';
import '../models/pet.dart';
import '../models/vfx_quality.dart';
import '../spatial/floor_blueprint.dart';
import '../spatial/spatial_combat.dart';
import 'game_audio.dart';
import 'ad_boost.dart';
import 'scroll_well.dart';
import 'ad_free_nudge.dart';
import 'ad_rewarded.dart';
import 'analytics_events.dart';
import 'app_analytics.dart';
import 'build_stamp.dart';
import 'debug_play_log.dart';
import 'fight_frame_budget.dart';
import 'funnel_analytics.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'gauntlet_pact.dart';
import 'game_storage.dart';
import 'gear_service.dart';
import 'hero_identity.dart';
import 'gold_income.dart';
import 'logic_notices.dart';
import 'menu_alerts.dart';
import 'meta_systems.dart';
import 'mission_board.dart';
import 'party_name_filter.dart';
import 'pet_service.dart';
import 'farm_intensity.dart';
import 'pet_errand_stock.dart';
import 'run_stash_shop.dart';
import 'play_games_bridge.dart';
import 'rift.dart';
import 'greater_rift.dart';
import 'play_games_scores.dart';
import 'play_review_ask.dart';
import 'away_fight_tip.dart';
import 'play_store_update.dart';
import 'screen_awake.dart';
import 'shop_billing.dart';
import 'coupon_codes.dart';
import 'friend_referral.dart';
import 'friend_referral_live.dart' as friend_live;
import 'shop_catalog.dart';
import 'shop_store.dart';
import 'story_lore.dart';
import 'chase_contract.dart';
import 'ui_feedback.dart';
import 'session_telemetry.dart';
import 'local_notify.dart';
import 'local_reminders.dart';
import 'wipe_advice.dart';
import 'wisp_gift.dart';
import 'ashen_crown.dart';
import 'blessing_constellation.dart';
import 'god_hand_mastery.dart';
import 'nav_intent.dart';
import '../models/dungeon_def.dart';

export 'game_storage.dart';

part 'combat_loop.dart';
part 'director_forge.dart';
part 'director_meta_actions.dart';
part 'director_bag.dart';
part 'director_save.dart';
part 'director_fight.dart';
part 'director_platform.dart';

enum EquipFromStashResult { equipped, notInStash, cannotEquip }

class GameDirector extends ChangeNotifier {
  GameDirector(
    this._storage, {
    GameState? initialState,
    this.enableSpatialLoop = true,
  }) : _state = initialState ?? GameLogic.createInitialState() {
    _syncDevicePrefs();
  }

  factory GameDirector.persistent() {
    return GameDirector(SharedPreferencesGameStorage());
  }

  factory GameDirector.preview({GameState? initialState}) {
    final seed = initialState ?? GameLogic.createInitialState();
    return GameDirector(
      InMemoryGameStorage(seed),
      initialState: seed,
      enableSpatialLoop: false,
    );
  }

  final GameStorage _storage;
  final bool enableSpatialLoop;

  GameState _state;
  bool _isLoading = true;
  bool _hasExistingSave = false;
  int _activeSlot = 0;
  int? _pendingNewGameSlot;
  List<SaveSlotSummary> _saveSlots = List<SaveSlotSummary>.generate(
    GameStorage.slotCount,
    SaveSlotSummary.empty,
  );
  SpatialWorld? _spatial;
  Timer? _spatialTimer;

  /// One sim tick is already waiting for the next screen refresh.
  bool _combatFrameQueued = false;

  /// Timer fires that landed before that refresh. At most one is caught up.
  int _droppedCombatTicks = 0;

  /// Last fight tick, so a slow phone does not stack steps to catch up.
  int _lastCombatTickMs = 0;

  /// Next debug `[IP] fight` line. At most once a second.
  int _nextFightLogMs = 0;
  Timer? _uiTimer;
  Timer? _bootWarmup;
  Timer? _hubIdleTimer;
  int _battleToken = 0;

  /// Bumps only in [_rebuildSpatial]. The dungeon view snaps and fades on it.
  int _floorEpoch = 0;

  /// New floor (or a fresh enter). Not God Hand, not a flask heal.
  int get floorEpoch => _floorEpoch;
  int _uiThrottle = 0;
  int _visualFrame = 0;
  final List<(int ms, int gold)> _runGoldSamples = <(int, int)>[];
  int _runGoldPerMinute = 0;
  String? _lastTelemetryChaseKey;
  bool _runIncomeFrozen = false;
  int? _lastFloorClearSec;
  DateTime? _floorStartedAt;

  /// Party XP bank when this floor started, so the clear banner can say the gain.
  int _floorXpSnapshot = 0;

  /// Boss appear sting already played for the banner that is up.
  bool _bossIntroHeard = false;

  /// This process's clock for seconds-to-combat (set on New Game / continue).
  int _funnelSessionReadyMs = 0;
  bool _appColdStartLogged = false;

  /// Combat map + corner HUD; bumps every spatial tick (~60 Hz).
  final ValueNotifier<int> combatFrame = ValueNotifier(0);
  bool _awaitingWipeChoice = false;
  Timer? _wipeAutoTimer;

  /// Seconds until a wipe retries on its own. 0 means no countdown.
  final ValueNotifier<int> wipeAutoSeconds = ValueNotifier(0);

  /// Soft-pause spatial sim while inventory / meta menus are open.
  bool _uiPaused = false;

  int _wispVisibleRemainingMs = 0;
  bool _wispSpawnArmed = false;
  bool _wispTappedThisWindow = false;
  bool _wispMenuPaused = false;
  bool _wispChoiceOpen = false;

  /// Hard pause while the app is backgrounded (separate from menu [uiPaused]).
  bool _appPaused = false;

  /// Resume is replaying the gap. Combat and hub idle wait so they cannot
  /// spend the same seconds twice.
  bool _awayCreditInFlight = false;

  /// One Welcome Back card watches once. A new absence clears it.
  bool _welcomeBackAdBusy = false;
  bool _welcomeBackAdGranted = false;

  @visibleForTesting
  bool get debugWelcomeBackAdGranted => _welcomeBackAdGranted;

  /// Pretend this card already paid, so a later absence can prove the reset.
  @visibleForTesting
  void debugGrantWelcomeBackAd() {
    _welcomeBackAdGranted = true;
  }

  /// Cold starts already counted this process, per save slot.
  final Set<int> _sessionNotedSlots = <int>{};

  /// Boss kills at the start of this sitting. A later kill is a good moment.
  bool _sessionBossBaselineSet = false;
  int _bossesAtSessionStart = 0;

  /// Welcome Back kept for the rating card after the banner timer ends.
  OfflineProgressResult? _reviewWelcome;

  /// True after a boss kill this sitting. Preview directors stay false.
  bool get bossClearedThisSession =>
      _sessionBossBaselineSet && _state.bossVictories > _bossesAtSessionStart;

  OfflineProgressResult? get reviewWelcome => _reviewWelcome;

  void noteReviewWelcome(OfflineProgressResult summary) {
    _reviewWelcome = summary;
  }

  void clearReviewWelcome() {
    _reviewWelcome = null;
  }

  /// This foreground stint. Reset when the app resumes.
  DateTime _foregroundSince = DateTime.now();

  /// Shorter than this is an app switch, not a Welcome Back.
  static const int _awayCreditMinSec = 60;
  final UiFeedback uiFeedback = UiFeedback();
  int? _playUpdateVersionCode;
  bool _mandatoryPlayUpdateRequired = false;
  int _lastHighestDungeon = -1;
  double _autosaveAccum = 0;
  int _lastStashLen = 0;

  /// Throttle bag auto-clean toasts during dense loot (ms since epoch).
  int _lastBagToastMs = 0;

  /// Throttle crit haptics so a cleave does not buzz the phone every frame.
  double _feelCritCooldown = 0;

  /// Throttle kill pops so a pack wipe is one thump, not five.
  double _feelKillCooldown = 0;

  /// Screen punch 0..1 (presentation only; decays each combat tick).
  double combatShake = 0;

  /// Party-frame pin for the dungeon camera. Null follows the living pack.
  /// Not saved — cleared when leaving the dungeon.
  int? cameraHeroIndex;

  /// False until zone floor tiles decode — dungeon HUD stays hidden.
  bool _dungeonTilesReady = false;
  bool get dungeonTilesReady => _dungeonTilesReady;

  void setDungeonTilesReady(bool ready, {bool notify = true}) {
    if (_dungeonTilesReady == ready) return;
    _dungeonTilesReady = ready;
    if (notify) notifyListeners();
  }

  static const double _autosaveIntervalSec = 25;

  /// Serializes SharedPreferences writes so overlapping unawaited saves cannot
  /// last-write-wins with a stale snapshot. False when the latest write failed.
  Future<bool> _saveChain = Future<bool>.value(true);

  FriendReferralSync? _friendSync;
  Future<void> _friendChain = Future<void>.value();
  int _friendEpoch = 0;

  /// Player-picked enemy for the target corner HUD (runtime only).
  String? hudFocusEnemyId;

  /// Test hook: attempt a persist (no-op unless a real save exists).
  /// False when the write did not land.
  @visibleForTesting
  Future<bool> debugTryPersist() {
    _persist();
    return _saveChain;
  }

  GameState get state => _state;

  bool get isLoading => _isLoading;

  /// True after [boot] if the active slot was loaded (autosave may write).
  bool get hasExistingSave => _hasExistingSave;

  /// Title-screen files. Always [GameStorage.slotCount] long.
  List<SaveSlotSummary> get saveSlots => _saveSlots;

  /// Slot autosave writes to (0-based).
  int get activeSaveSlot => _activeSlot;

  /// Any of the five files has a party (title story skips when this is set).
  bool get hasAnySave => _saveSlots.any((slot) => slot.occupied);

  /// Empty slot the next clipboard import should fill, else the active file.
  int get preferredImportSlot {
    final empty = _saveSlots.indexWhere((slot) => !slot.occupied);
    if (empty >= 0) return empty;
    return _activeSlot;
  }

  SpatialWorld? get spatial => _spatial;

  /// Party-strip tests attach a fight so a status chip can overflow the row.
  @visibleForTesting
  void debugAttachSpatial(SpatialWorld? world) {
    _spatial = world;
  }

  /// Increments each spatial sim step — used by combat painter dirty-checks.
  int get visualFrame => _visualFrame;

  static const double _spatialDt = 1 / 60;
  static const Duration _spatialPeriod = Duration(milliseconds: 16);

  /// Full shell rebuild cadence while fighting (~10 Hz).
  static const int _shellNotifyEvery = 6;

  /// Debug / playtest combat multiplier (1 = realtime). Clamped 1–20.
  /// Runs N sim steps per wall-clock tick — does not inflate `dt`.
  double _debugTimeScale = 1;
  double get debugTimeScale => _debugTimeScale;

  int _slowFightTicks = 0;

  /// Cheap phones: a few slow fight ticks drop Full to Lite once.
  @visibleForTesting
  void debugNoteFightBudget(int elapsedMs) => _noteFightBudget(elapsedMs);

  void _noteFightBudget(int elapsedMs) {
    if (_state.vfxPinned || _state.vfxQuality != VfxQuality.full) return;
    if (!_state.inDungeon) return;
    if (elapsedMs > 48) {
      _slowFightTicks++;
      if (_slowFightTicks >= 12) {
        _slowFightTicks = 0;
        setVfxQuality(VfxQuality.lite, fromUser: false);
        showToast('Picture eased so the fight stays smooth', life: 2.4);
      }
    } else if (_slowFightTicks > 0) {
      _slowFightTicks--;
    }
  }

  void cycleCombatPace() {
    final next = _state.combatPace >= 2 ? 1 : 2;
    _applyUpgrade(_state.copyWith(combatPace: next));
    showToast(next >= 2 ? 'Fight speed 2×' : 'Fight speed 1×', life: 1.4);
  }

  void setDebugTimeScale(double scale) {
    final next = scale.clamp(1, 20).toDouble();
    if (next == _debugTimeScale) return;
    _debugTimeScale = next;
    showToast('Dev speed ${_debugTimeScale.round()}x', life: 1.6);
    notifyListeners();
  }

  void cycleDebugTimeScale() {
    setDebugTimeScale(_debugTimeScale >= 9.5 ? 1 : 10);
  }

  /// Debug builds: freeze the fight so a phone shot can catch the first frame.
  bool _debugHoldCombat = false;
  bool get debugHoldCombat => _debugHoldCombat;

  /// Debug builds: freeze the next floor rebuild, then clear.
  bool _debugHoldNextRebuild = false;

  void toggleDebugHoldCombat() {
    _debugHoldCombat = !_debugHoldCombat;
    showToast(_debugHoldCombat ? 'Dev hold on' : 'Dev hold off', life: 1.2);
    notifyListeners();
  }

  void debugHoldNextFloor() {
    _debugHoldNextRebuild = true;
    showToast('Dev hold next floor', life: 1.2);
    notifyListeners();
  }

  /// Debug builds: drop the party so the wipe path can be seen on a phone.
  void debugDownParty() {
    final world = _spatial;
    if (world == null || !_state.inDungeon) return;
    for (final hero in world.heroes) {
      if (hero.isPet) continue;
      hero.hp = 0;
    }
  }

  /// Test helper: put items in the bag without rebuilding combat.
  @visibleForTesting
  void debugInjectStash(List<EquipmentItem> items) {
    _state = _state.copyWith(gearStash: [...items, ..._state.gearStash]);
  }

  /// Test helper: move wallet gold without touching meta.
  @visibleForTesting
  void debugSetGold(int gold) {
    _state = _state.copyWith(gold: gold);
  }

  bool get awaitingWipeChoice => _awaitingWipeChoice;
  bool get uiPaused => _uiPaused;
  bool get appPaused => _appPaused;

  /// Combat gold/min from the last ~2 minutes of credited dungeon gold.
  int get runGoldPerMinute => _runGoldPerMinute;

  /// Seconds for the last finished floor (session + saved for forge tip).
  int? get lastFloorClearSec {
    final live = _lastFloorClearSec;
    if (live != null && live > 0) return live;
    final saved = _state.lastFloorClearSec;
    return saved > 0 ? saved : null;
  }

  /// Freeze dungeon combat while the player is in inventory / overlays.
  void setUiPaused(bool paused) {
    if (_uiPaused == paused) return;
    _uiPaused = paused;
  }

  /// Pause WISP despawn while dungeon menus are open.
  void setWispMenuPaused(bool paused) {
    _wispMenuPaused = paused;
  }

  bool get wispMenuPaused => _wispMenuPaused;

  /// Lantern only paints in a dungeon — never on the hub World Path.
  bool get isWispVisible => _state.inDungeon && _wispVisibleRemainingMs > 0;

  bool get wispPendingChoice => WispGift.hasPendingChoice(_state.metaDepth);

  void setWispChoiceOpen(bool open) {
    _wispChoiceOpen = open;
  }

  /// Freeze dungeon combat while the app is backgrounded; flush save on pause.
  ///
  /// Hub idle is the clock that moves [GameState.lastUpdated]. It stops here
  /// so a phone that keeps the process alive still has a real gap to credit.
  /// The toast timer does not touch that clock.

  String? get toast => uiFeedback.toast;

  NoticeKind get noticeKind => uiFeedback.noticeKind;

  bool get celebrating => uiFeedback.celebrating;

  /// Celebrate notice text (same slot as [toast] when kind is celebrate).
  String? get clearSummary => uiFeedback.clearSummary;

  OfflineProgressResult? get offlineSummary => uiFeedback.offlineSummary;

  void showToast(
    String message, {
    double life = 2.4,
    NoticeKind kind = NoticeKind.tip,
  }) {
    if (!uiFeedback.showToast(message, life: life, kind: kind)) return;
    DebugPlayLog.toast(message);
    _ensureUiTimer();
    notifyListeners();
  }

  /// Floor / KEY / zone payoff — same slot as [showToast], celebrate style.
  void presentClear(String text, {double life = 2.8}) {
    showToast(text, life: life, kind: NoticeKind.celebrate);
  }

  /// Last five floor payoffs, oldest first. Painted as the dungeon loot log.
  List<String> get lootLog => uiFeedback.lootLog;

  /// Quiet floor payoff. Does not take the toast slot.
  void noteLoot(String text) {
    if (!uiFeedback.pushLootLine(text)) return;
    notifyListeners();
  }

  void clearLootLog() => uiFeedback.clearLootLog();

  String? _questReadyLine() {
    final n = LogicNotices.takeQuestReady();
    if (n <= 0) return null;
    return n == 1 ? 'QUEST READY' : 'QUESTS READY';
  }

  void _flushQuestReadyToast({double life = 2.4}) {
    final line = _questReadyLine();
    if (line == null) return;
    showToast(line, life: life);
  }

  /// Bag auto-clean during combat — at most one toast every ~8s.
  void _toastBagCleanup(String message, {double life = 1.8}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBagToastMs < 8000) return;
    _lastBagToastMs = now;
    showToast(message, life: life);
  }

  /// Drop the active toast (e.g. when opening a modal that would cover it).
  void clearToast() {
    if (!uiFeedback.toastWasShowing) return;
    uiFeedback.clearToast();
    notifyListeners();
  }

  void dismissOfflineSummary() {
    uiFeedback.dismissOfflineSummary();
    notifyListeners();
  }

  void _ensureUiTimer() {
    if (_uiTimer != null) return;
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      tickWisp(deltaMs: 200);
      if (!uiFeedback.hasActiveTimers && !isWispVisible) return;
      _tickUiTimers(0.2);
      notifyListeners();
    });
  }

  void _tickUiTimers(double dt) {
    uiFeedback.tick(dt);
    if (_feelCritCooldown > 0) {
      _feelCritCooldown = (_feelCritCooldown - dt).clamp(0, 99);
    }
    if (_feelKillCooldown > 0) {
      _feelKillCooldown = (_feelKillCooldown - dt).clamp(0, 99);
    }
    if (combatShake > 0) {
      combatShake = (combatShake - dt * 5.5).clamp(0.0, 1.0);
    }
  }

  /// Light camera punch — skipped on Minimal VFX (reduce motion).
  void pulseCombatShake(double amount) {
    if (!_state.screenShake || _state.vfxQuality == VfxQuality.minimal) return;
    final next = amount.clamp(0.0, 1.0);
    if (next > combatShake) combatShake = next;
  }

  void _beginRunIncomeSession() {
    _runGoldSamples.clear();
    _runGoldPerMinute = 0;
    _runIncomeFrozen = false;
    _beginFloorClock();
  }

  void _beginFloorClock() {
    _floorStartedAt = DateTime.now();
    _floorXpSnapshot = partyXpBank(_state);
    _bossIntroHeard = false;
  }

  void _freezeRunIncome() {
    _refreshRunGpm(DateTime.now().millisecondsSinceEpoch);
    _runIncomeFrozen = true;
  }

  void _noteRunGold(int gained) {
    if (gained <= 0 || _runIncomeFrozen) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _runGoldSamples.add((now, gained));
    _refreshRunGpm(now);
  }

  void _noteLifetimeGold(GameState before, GameState after) {
    _noteRunGold(after.lifetimeGoldEarned - before.lifetimeGoldEarned);
  }

  void _refreshRunGpm(int nowMs) {
    if (_runIncomeFrozen) return;
    _runGoldSamples.removeWhere(
      (s) => s.$1 < nowMs - GoldIncome.sessionWindowMs,
    );
    _runGoldPerMinute = GoldIncome.runGoldPerMinuteFromSamples(
      _runGoldSamples,
      nowMs: nowMs,
    );
  }

  String _forgeSpeedToast(String name) {
    final sec = _lastFloorClearSec;
    if (sec == null) return '$name up · faster clears';
    return '$name up · last floor ${sec}s · faster clears';
  }

  static String _forgeTrackShort(PartyUpgradeType type) => switch (type) {
    PartyUpgradeType.attack => 'AP',
    PartyUpgradeType.defense => 'Armor',
    PartyUpgradeType.vitality => 'STA',
    PartyUpgradeType.moveSpeed => 'MOVE',
    PartyUpgradeType.attackSpeed => 'HASTE',
    PartyUpgradeType.crit => 'CRIT',
    PartyUpgradeType.mastery => 'MASTERY',
  };

  void setSoundMuted(bool muted) {
    _applyUpgrade(_state.copyWith(soundMuted: muted));
  }

  void setSfxVolume(double value) {
    _applyUpgrade(_state.copyWith(sfxVolume: value.clamp(0.0, 1.0)));
  }

  void setAmbienceVolume(double value) {
    _applyUpgrade(_state.copyWith(ambienceVolume: value.clamp(0.0, 1.0)));
  }

  void setMusicVolume(double value) {
    _applyUpgrade(_state.copyWith(musicVolume: value.clamp(0.0, 1.0)));
  }

  void setHapticsEnabled(bool enabled) {
    _applyUpgrade(_state.copyWith(hapticsEnabled: enabled));
  }

  void setScreenShake(bool enabled) {
    _applyUpgrade(_state.copyWith(screenShake: enabled));
  }

  void setKeepScreenAwake(bool enabled) {
    _applyUpgrade(_state.copyWith(keepScreenAwake: enabled));
  }

  void setAutoEquipUpgrades(bool enabled) {
    _applyUpgrade(_state.copyWith(autoEquipUpgrades: enabled));
  }

  void setAutoCaveOnLeave(bool enabled) {
    _applyUpgrade(_state.copyWith(autoCaveOnLeave: enabled));
  }

  /// Wear budget upgrades without rebuilding the floor.
  void _maybeAutoEquip() {
    if (!_state.autoEquipUpgrades ||
        _state.inGreaterRift ||
        _awaitingWipeChoice ||
        _state.gearStash.isEmpty) {
      return;
    }
    final result = GameLogic.autoEquipBetterGearResult(_state);
    if (result.equipped <= 0) return;
    final worn = GearService.wornLine(result.names);
    if (worn.isNotEmpty) showToast(worn, life: 2.2);
    _state = result.state;
    final spatial = _spatial;
    if (spatial != null) {
      _spatial = SpatialCombat.syncPartyFromState(spatial, _state);
    }
  }

  void setVfxQuality(VfxQuality value, {bool fromUser = true}) {
    _applyUpgrade(
      _state.copyWith(
        vfxQuality: value,
        vfxPinned: fromUser ? true : _state.vfxPinned,
      ),
    );
  }

  void cycleVfxQuality() {
    setVfxQuality(_state.vfxQuality.next);
  }

  void setDungeonZoom(DungeonZoom value) {
    _applyUpgrade(
      _state.copyWith(dungeonZoom: value, clearDungeonViewCols: true),
    );
  }

  void cycleDungeonZoom() {
    setDungeonZoom(_state.dungeonZoom.next);
  }

  /// Live pinch. One write when the fingers lift, not on every move.
  void setDungeonViewCols(double cols) {
    final clamped = DungeonZoom.clampCols(cols);
    _applyUpgrade(_state.copyWith(dungeonViewCols: clamped));
  }

  void setAutoSellMaxPower(int value) {
    final cap = GameLogic.maxAutoSellIlvlCap(_state);
    _applyUpgrade(_state.copyWith(autoSellMaxPower: value.clamp(0, cap)));
  }

  void setAutoSellMaxRarity(int value) {
    _applyUpgrade(_state.copyWith(autoSellMaxRarity: value.clamp(0, 4)));
  }

  void setAutoDisassembleMaxIlvl(int value) {
    final cap = GameLogic.maxAutoSellIlvlCap(_state);
    _applyUpgrade(_state.copyWith(autoDisassembleMaxIlvl: value.clamp(0, cap)));
  }

  void setAutoDisassembleMaxRarity(int value) {
    _applyUpgrade(_state.copyWith(autoDisassembleMaxRarity: value.clamp(0, 4)));
  }

  void setColorblindMode(bool value) {
    _applyUpgrade(_state.copyWith(colorblindMode: value));
  }

  void setHideHealFloaters(bool value) {
    _applyUpgrade(_state.copyWith(hideHealFloaters: value));
  }

  void setCompactCombatNumbers(bool value) {
    _applyUpgrade(_state.copyWith(compactCombatNumbers: value));
  }

  void setAlwaysShowEnemyHp(bool value) {
    _applyUpgrade(_state.copyWith(alwaysShowEnemyHp: value));
  }

  void setSessionTelemetryOptIn(bool value) {
    _applyUpgrade(SessionTelemetry.setOptIn(_state, value));
  }

  void clearSessionTelemetry() {
    _applyUpgrade(SessionTelemetry.clearLog(_state));
  }

  String sessionTelemetryExport() => SessionTelemetry.exportText(_state);

  void _maybeLogHubChase() {
    if (!_state.sessionTelemetryOptIn || _state.inDungeon) return;
    final contract = ChaseContract.fromState(_state);
    final chase = contract.chase;
    final key =
        '${chase.kind.name}|${chase.urgency.name}|${chase.title}|AL${_state.ascensionLevel}';
    if (_lastTelemetryChaseKey == key) return;
    _lastTelemetryChaseKey = key;
    _state = SessionTelemetry.append(_state, 'hub_chase', key);
  }

  void setUiTextScale(double value) {
    _applyUpgrade(
      _state.copyWith(
        uiTextScale: value.clamp(kUiTextScaleMin, kUiTextScaleMax),
      ),
    );
  }

  void resetDisplayDefaults() {
    _applyUpgrade(
      _state.copyWith(
        uiTextScale: 1.0,
        dungeonZoom: DungeonZoom.normal,
        clearDungeonViewCols: true,
        vfxQuality: VfxQuality.full,
        combatPace: 1,
        colorblindMode: false,
        hideHealFloaters: false,
        compactCombatNumbers: false,
        alwaysShowEnemyHp: false,
        screenShake: true,
        hapticsEnabled: true,
        keepScreenAwake: true,
        soundMuted: false,
        sfxVolume: 0.45,
        ambienceVolume: 0.20,
        musicVolume: 0.22,
      ),
    );
  }

  void setChallengeBossRush(bool value) {
    _applyUpgrade(_state.copyWith(challengeBossRush: value));
  }

  void setChallengeNoFlask(bool value) {
    _applyUpgrade(_state.copyWith(challengeNoFlask: value));
  }

  void setChallengeTiny(bool value) {
    _applyUpgrade(_state.copyWith(challengeTiny: value));
  }

  void claimMonthPass() {
    final before = _state.essence;
    _applyUpgrade(GameLogic.claimMonthPass(_state));
    if (_state.essence > before) {
      showToast('Month pass · +${_state.essence - before}e', life: 2.4);
    }
  }

  void enterAshenCrown({bool practice = false}) {
    if (!AshenCrown.canEnter(_state)) {
      showToast(
        GameLogic.endgameUnlocked(_state)
            ? 'Leave the dungeon first'
            : 'Ashen Crown unlocks when every active hero is Lv${GameLogic.maxHeroLevel}',
        life: 2.4,
      );
      return;
    }
    final week = AshenCrown.ensureWeek(_state);
    if (!practice) {
      if (week.metaDepth.worldBossClearedWeek) {
        showToast('Already cleared this week — PRACTICE is free', life: 2.8);
        return;
      }
      if (week.metaDepth.worldBossTickets <= 0) {
        showToast(
          'No Ashen Crown tickets this week — PRACTICE is free',
          life: 2.6,
        );
        return;
      }
    }
    _flushHubIdle();
    _state = GameLogic.enterAshenCrown(_state, practice: practice);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _beginRunIncomeSession();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _syncHubIdleTimer();
    showToast(
      practice
          ? 'Practice · ${AshenCrown.kitFor().title}'
          : '${AshenCrown.kitFor().title} · ticket held (returned if you leave early)',
      life: 2.6,
    );
    notifyListeners();
    unawaited(_persistFlush());
  }

  void startApexTrial() {
    if (!GameLogic.endgameUnlocked(_state) || _state.inDungeon) {
      showToast(
        _state.inDungeon
            ? 'Leave the dungeon first'
            : 'Craft Trial needs every active hero Lv${GameLogic.maxHeroLevel}',
        life: 2.6,
      );
      return;
    }
    final month = GameLogic.isoMonthKey(DateTime.now().toUtc());
    if (_state.metaDepth.apexTrialMonthKey == month &&
        _state.metaDepth.apexTrialCleared) {
      showToast('Craft Trial already cleared this month', life: 2.6);
      return;
    }
    _state = GameLogic.startApexTrial(_state);
    notifyListeners();
    showToast(
      'Craft Trial — every active hero Lv${GameLogic.maxHeroLevel} · '
      'non-Apex gear ignored',
      life: 2.6,
    );
  }

  void lightConstellationNode(String id) {
    final before = _state.metaDepth.constellationNodes.length;
    _applyUpgrade(BlessingConstellation.lightNode(_state, id));
    if (_state.metaDepth.constellationNodes.length > before) {
      showToast('Star Node lit', life: 2.0);
    }
  }

  void claimGodHandMastery(String id) {
    final before = _state.essence;
    _applyUpgrade(GodHandMastery.claim(_state, id));
    if (_state.essence > before) {
      showToast('God Hand mastery · +${_state.essence - before}e', life: 2.4);
    }
  }

  void setHardmodeLevel(int level) {
    _applyUpgrade(GameLogic.setHardmodeLevel(_state, level));
  }

  void markChangelogSeen() {
    if (_state.seenChangelogVersion == MetaSystems.currentVersion) return;
    _applyUpgrade(
      _state.copyWith(seenChangelogVersion: MetaSystems.currentVersion),
    );
  }

  // —— Team composition ————————————————————————————————————————

  void setActiveParty(List<String> heroIds) {
    if (_state.inDungeon) {
      showToast('Leave dungeon to change team', life: 2);
      return;
    }
    final before = _state.activeHeroIds.join(',');
    _applyUpgrade(GameLogic.setActiveParty(_state, heroIds));
    if (_state.activeHeroIds.join(',') != before) {
      showToast('Team updated', life: 1.6);
    }
  }

  void unlockPartySlot5() {
    final before = _state.metaDepth.partySlot5Unlocked;
    _applyUpgrade(GameLogic.unlockPartySlot5(_state));
    if (_state.metaDepth.partySlot5Unlocked && !before) {
      showToast('5th party slot unlocked', life: 2.2);
    }
  }

  void unlockSpec(HeroSpecId specId) {
    if (!GameLogic.canUnlockSpec(_state, specId)) {
      showToast(HeroSpecs.def(specId).unlockHint, life: 2.4);
      return;
    }
    final before = _state.isSpecUnlocked(specId);
    _applyUpgrade(GameLogic.unlockSpec(_state, specId));
    if (_state.isSpecUnlocked(specId) && !before) {
      final def = HeroSpecs.def(specId);
      showToast('${def.name} · ${HeroIdentity.meetDetail(specId)}', life: 2.8);
    }
  }

  /// Clears TODAY “Meet …” after the player opens PARTY.
  void ackPendingHeroReveals() {
    if (_state.metaDepth.pendingHeroReveals.isEmpty) return;
    _applyUpgrade(GameLogic.ackPendingHeroReveals(_state));
  }

  // —— Daily run ——————————————————————————————————————————————

  void enterDaily() {
    if (_isLoading) return;
    _flushHubIdle();
    _state = GameLogic.enterDaily(_state);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _beginRunIncomeSession();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _syncHubIdleTimer();
    showToast(
      StoryLore.dailyRun(
        _state.dungeonId,
        floor: _state.currentRoom.floorNumber,
      ),
      life: 3.2,
    );
    notifyListeners();
    unawaited(_persistFlush());
  }

  bool get isDailyClaimedToday => MetaSystems.isDailyClaimedToday(_state);

  String get dailyDungeonId =>
      MetaSystems.dailyDungeonId(DateTime.now().toUtc());

  /// Floor today's Daily Run will use (yesterday's PUSH peak + 1).
  int get dailyEchoFloor =>
      MetaSystems.dailyEchoFloor(_state, DateTime.now().toUtc());

  void enterGauntlet({GauntletPact? pact}) {
    if (_isLoading) return;
    if (!GameLogic.canEnterGauntlet(_state)) {
      showToast(
        !GameLogic.endgameUnlocked(_state)
            ? 'Gauntlet unlocks when every active hero is Lv${GameLogic.maxHeroLevel}'
            : 'Leave the dungeon first',
        life: 2.0,
      );
      return;
    }
    _flushHubIdle();
    _state = GameLogic.enterGauntlet(_state, pact: pact);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _beginRunIncomeSession();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _syncHubIdleTimer();
    final chosen = GauntletPacts.parse(_state.gauntletPact);
    showToast(
      chosen == null
          ? 'Gauntlet climb · Crystal Spire · best F${_state.metaDepth.gauntletBestFloor}'
          : 'Gauntlet ${GauntletPacts.title(chosen)} · ${GauntletPacts.blurb(chosen)}',
      life: 3.0,
    );
    notifyListeners();
    unawaited(_persistFlush());
  }

  void enterRift({int? tier}) {
    if (_isLoading) return;
    if (!GameLogic.canEnterRift(_state)) {
      showToast(
        !GameLogic.endgameUnlocked(_state)
            ? 'Rift unlocks when every active hero is Lv${GameLogic.maxHeroLevel}'
            : 'Leave the dungeon first',
        life: 2.0,
      );
      return;
    }
    _flushHubIdle();
    _state = GameLogic.enterRift(_state, tier: tier);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _beginRunIncomeSession();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _syncHubIdleTimer();
    showToast(
      'Farm Rift R${_state.riftTier} · Stormwake · '
      '${_state.riftKillTarget} kills · ${Rift.formatTimer(_state.riftParMs)}',
      life: 3.0,
    );
    notifyListeners();
    unawaited(_persistFlush());
  }

  void setRiftPreferredTier(int tier) {
    _state = GameLogic.setRiftPreferredTier(_state, tier);
    notifyListeners();
    _persist();
  }

  void enterGreaterRift({int? tier}) {
    if (_isLoading) return;
    if (!GameLogic.canEnterGreaterRift(_state)) {
      showToast(
        !GameLogic.endgameUnlocked(_state)
            ? 'Greater Rift unlocks when every active hero is Lv${GameLogic.maxHeroLevel}'
            : 'Leave the dungeon first',
        life: 2.0,
      );
      return;
    }
    _flushHubIdle();
    _state = GameLogic.enterGreaterRift(_state, tier: tier);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _beginRunIncomeSession();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    _syncHubIdleTimer();
    showToast(
      'Ranked GR${_state.grTier} · Mothveil · no mid-run gear · '
      '${_state.grKillTarget} kills · ${GreaterRift.formatTimer(_state.grParMs)}',
      life: 3.0,
    );
    notifyListeners();
    unawaited(_persistFlush());
  }

  void setGrPreferredTier(int tier) {
    _state = GameLogic.setGrPreferredTier(_state, tier);
    notifyListeners();
    _persist();
  }

  /// Playtest helper: max party levels (and AL if needed) then enter Gauntlet.
  /// Call only from debug UI (`kDebugMode`).
  void devEnterGauntlet() {
    if (_isLoading) return;
    if (_state.inDungeon) {
      showToast('Leave the dungeon first', life: 2.0);
      return;
    }
    if (_state.ascensionLevel < GameLogic.maxAscensionLevel) {
      _state = _state.copyWith(ascensionLevel: GameLogic.maxAscensionLevel);
    }
    if (!GameLogic.endgameUnlocked(_state)) {
      _state = _state.copyWith(
        heroRoster: [
          for (final h in _state.heroRoster)
            h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
        ],
      );
    }
    enterGauntlet();
  }

  void buyMarketFlask() {
    final cost = GameLogic.marketFlaskCost(_state);
    if (_state.gold < cost) {
      GameAudio.uiDeny();
      showToast('Need ${cost}g for flask', life: 2);
      return;
    }
    final beforeEss = _state.essence;
    _applyUpgrade(GameLogic.buyMarketFlask(_state));
    GameAudio.gold();
    final salvage = _state.essence - beforeEss;
    showToast(
      salvage > 0
          ? 'Flask acquired · bag full — salvaged oldest (+${salvage}e)'
          : 'Flask acquired',
      life: salvage > 0 ? 2.4 : 1.8,
    );
  }

  void buyMarketFlasks({int count = 3}) {
    final unit = GameLogic.marketFlaskCost(_state);
    final need = unit * count;
    if (_state.gold < unit) {
      GameAudio.uiDeny();
      showToast('Need ${unit}g for flask', life: 2);
      return;
    }
    final beforeGold = _state.gold;
    final beforeFlasks = _countFlasks(_state);
    final beforeEss = _state.essence;
    _applyUpgrade(GameLogic.buyMarketFlasks(_state, count: count));
    final bought = _countFlasks(_state) - beforeFlasks;
    final spent = beforeGold - _state.gold;
    if (bought <= 0) {
      GameAudio.uiDeny();
      showToast('Need ${need}g for $count flasks', life: 2);
      return;
    }
    GameAudio.gold();
    final salvage = _state.essence - beforeEss;
    showToast(
      salvage > 0
          ? '+$bought flask${bought == 1 ? '' : 's'} (−${spent}g) · '
                'bag full — salvaged (+${salvage}e)'
          : '+$bought flask${bought == 1 ? '' : 's'} (−${spent}g)',
      life: salvage > 0 ? 2.4 : 1.8,
    );
  }

  void buyMarketBandage() {
    final cost = GameLogic.marketBandageCost(_state);
    if (_state.gold < cost) {
      GameAudio.uiDeny();
      showToast('Need ${cost}g for bandage', life: 2);
      return;
    }
    final beforeEss = _state.essence;
    _applyUpgrade(GameLogic.buyMarketBandage(_state));
    GameAudio.gold();
    final salvage = _state.essence - beforeEss;
    showToast(
      salvage > 0
          ? 'Field Bandage acquired · bag full — salvaged oldest (+${salvage}e)'
          : 'Field Bandage acquired',
      life: salvage > 0 ? 2.4 : 1.8,
    );
  }

  void ensureMarketListings() {
    final before = _state.marketListingsRefreshMs;
    _applyUpgrade(GameLogic.ensureMarketListings(_state));
    if (_state.marketListingsRefreshMs != before &&
        _state.marketListings.isNotEmpty) {
      // Quiet refresh — no toast on timer roll.
    }
  }

  void buyMarketListing(String listingId) {
    MarketListing? found;
    for (final l in _state.marketListings) {
      if (l.id == listingId) {
        found = l;
        break;
      }
    }
    if (found == null) return;
    if (_state.gold < found.priceGold) {
      GameAudio.uiDeny();
      showToast('Need ${found.priceGold}g', life: 2);
      return;
    }
    final beforeGold = _state.gold;
    _applyUpgrade(GameLogic.buyMarketListing(_state, listingId));
    if (_state.gold < beforeGold) {
      GameAudio.gold();
      showToast('${found.item.name} · −${found.priceGold}g', life: 2.2);
    }
  }

  void refreshMarketListings() {
    final cost = GameLogic.marketListingsPaidRefreshCost(_state);
    if (_state.gold < cost) {
      showToast('Need ${cost}g to refresh listings', life: 2);
      return;
    }
    final beforeGold = _state.gold;
    _applyUpgrade(GameLogic.refreshMarketListingsPaid(_state));
    if (_state.gold < beforeGold) {
      showToast('Listings refreshed · −${beforeGold - _state.gold}g', life: 2);
    }
  }

  static int _countFlasks(GameState state) {
    var n = 0;
    for (final h in state.heroes) {
      if (h.itemIn(EquipmentSlot.consumable) != null) n++;
    }
    for (final g in state.gearStash) {
      if (g.slot == EquipmentSlot.consumable) n++;
    }
    return n;
  }

  void dismissTip(String tipId) {
    final updated = GameLogic.dismissTip(_state, tipId);
    if (identical(updated, _state)) return;
    _state = updated;
    if (AnalyticsEvents.coachTipIds.contains(tipId)) {
      unawaited(AppAnalytics.coachStep(tipId));
    }
    notifyListeners();
    unawaited(_persistFlush());
  }

  void hatchPet() {
    if (_state.ownedPets.length >= _state.metaDepth.basePetRosterCap) {
      showToast('Roster full', life: 1.8);
      return;
    }
    if (_state.essence < GameLogic.hatchPetCost(_state)) {
      showToast('Need essence', life: 1.8);
      return;
    }
    final beforeCount = _state.ownedPets.length;
    _applyUpgrade(GameLogic.hatchPet(_state));
    if (_state.ownedPets.length > beforeCount) {
      final pet = _state.ownedPets.last;
      GameAudio.unlock();
      showToast('Hatched ${pet.name}!', life: 2.6);
    }
  }

  void mergePets(String petIdA, String petIdB) {
    Pet? a;
    Pet? b;
    for (final pet in _state.ownedPets) {
      if (pet.id == petIdA) a = pet;
      if (pet.id == petIdB) b = pet;
    }
    if (a == null || b == null) return;
    if (a.resolvedSpecies != b.resolvedSpecies) {
      showToast('Need same species', life: 1.8);
      return;
    }
    if (a.rarity == PetRarity.legendary && b.rarity == PetRarity.legendary) {
      showToast('Already legendary', life: 1.8);
      return;
    }
    final before = _state.ownedPets.length;
    _applyUpgrade(GameLogic.mergePets(_state, petIdA, petIdB));
    if (_state.ownedPets.length < before) {
      final pet = _state.ownedPets.last;
      GameAudio.unlock();
      showToast('Merged ${pet.name} · ${pet.rarity.name}!', life: 2.6);
    }
  }

  void setFavoritePetSpecies(String speciesId) {
    _applyUpgrade(GameLogic.setFavoritePetSpecies(_state, speciesId));
    GameAudio.ui();
    showToast('Favorite species set', life: 1.6);
  }

  void setActiveTitle(String title) {
    _applyUpgrade(GameLogic.setActiveTitle(_state, title));
    if (_state.metaDepth.activeTitle == title) {
      GameAudio.ui();
      showToast('Title: $title', life: 1.8);
    }
  }

  void buyPetFrame(String petId, PetFrame frame) {
    final before = _state.essence;
    _applyUpgrade(GameLogic.buyPetFrame(_state, petId, frame));
    if (_state.essence < before) {
      GameAudio.ui();
      showToast('Frame · ${frame.name}', life: 1.8);
    }
  }

  void bondPet(String petId) {
    var beforeBond = -1;
    String? name;
    for (final pet in _state.ownedPets) {
      if (pet.id == petId) {
        beforeBond = pet.bondLevel;
        name = pet.name;
        break;
      }
    }
    if (beforeBond < 0) return;
    if (_state.essence < GameLogic.bondPetCost(beforeBond)) {
      GameAudio.uiDeny();
      showToast('Need essence', life: 1.8);
      return;
    }
    _applyUpgrade(GameLogic.bondPet(_state, petId));
    for (final pet in _state.ownedPets) {
      if (pet.id == petId && pet.bondLevel > beforeBond) {
        GameAudio.ui();
        showToast('${name ?? pet.name} bond Lv${pet.bondLevel}', life: 2.0);
        break;
      }
    }
  }

  void levelUpPet(String petId) {
    var beforeLevel = -1;
    String? name;
    for (final pet in _state.ownedPets) {
      if (pet.id == petId) {
        beforeLevel = pet.level;
        name = pet.name;
        break;
      }
    }
    _applyUpgrade(GameLogic.levelUpPet(_state, petId));
    for (final pet in _state.ownedPets) {
      if (pet.id == petId && pet.level > beforeLevel) {
        GameAudio.ui();
        showToast('${name ?? pet.name} · Lv${pet.level}!', life: 2.2);
        break;
      }
    }
  }

  void setActivePet(String petId) {
    _applyUpgrade(GameLogic.setActivePet(_state, petId));
  }

  void sendPetErrand(String petId, int hours) {
    if (PetService.errandActive(_state)) {
      showToast('A pet is already out', life: 1.8);
      return;
    }
    if (!PetErrandStock.canSend(_state)) {
      showToast('No errand shipments left today', life: 2.2);
      return;
    }
    final next = GameLogic.sendPetErrand(_state, petId, hours);
    if (identical(next, _state)) return;
    // Apply even while boot is still loading, same as the ping card.
    _applyNotify(next);
    final pet = PetService.errandPet(_state);
    showToast('${pet?.name ?? 'Pet'} is out for $hours hours', life: 2.2);
  }

  void claimPetErrand() {
    final next = GameLogic.claimPetErrand(_state);
    if (identical(next, _state)) return;
    _applyNotify(next);
    showToast('Pet prize claimed', life: 1.8);
  }

  void claimReturnRewards() {
    final next = GameLogic.claimReturnRewards(_state);
    if (identical(next, _state)) return;
    _applyNotify(next);
  }

  void renamePet(String petId, String rawName) {
    Pet? pet;
    for (final owned in _state.ownedPets) {
      if (owned.id == petId) {
        pet = owned;
        break;
      }
    }
    if (pet == null) return;
    final next = PartyNameFilter.sanitize(rawName, whenEmpty: pet.speciesName);
    if (next == null) {
      showToast('Choose another name', life: 1.8);
      return;
    }
    if (next == pet.name) return;
    final species = pet.speciesName;
    _applyUpgrade(GameLogic.renamePet(_state, petId, rawName));
    GameAudio.ui();
    showToast(next == species ? 'Name cleared' : 'Named $next', life: 1.8);
  }

  void useConsumable({int? heroIndex}) {
    final before = _state;
    final hpBefore = <String, int>{
      for (final h in _state.heroes) h.id: h.currentHp,
    };
    final next = GameLogic.useConsumable(_state, heroIndex: heroIndex);
    _applyUpgrade(next);
    if (!identical(next, before) && _spatial != null && _state.inDungeon) {
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

  void upgradeSanctuary(String track) {
    final before = switch (track) {
      'gold' => _state.sanctuaryGoldLevel,
      'power' => _state.sanctuaryPowerLevel,
      'vitality' => _state.sanctuaryVitalityLevel,
      'defense' => _state.sanctuaryDefenseLevel,
      'xp' => _state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    _applyUpgrade(GameLogic.upgradeSanctuary(_state, track));
    final after = switch (track) {
      'gold' => _state.sanctuaryGoldLevel,
      'power' => _state.sanctuaryPowerLevel,
      'vitality' => _state.sanctuaryVitalityLevel,
      'defense' => _state.sanctuaryDefenseLevel,
      'xp' => _state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (after > before) {
      final name = GameLogic.sanctuaryNames[track] ?? track;
      final prestige = switch (track) {
        'gold' => _state.metaDepth.sanctuaryGoldPrestige,
        'power' => _state.metaDepth.sanctuaryPowerPrestige,
        'vitality' => _state.metaDepth.sanctuaryVitalityPrestige,
        'defense' => _state.metaDepth.sanctuaryDefensePrestige,
        'xp' => _state.metaDepth.sanctuaryXpPrestige,
        _ => 0,
      };
      final bonus = GameLogic.sanctuaryBonusLabel(
        track,
        after,
        prestige: prestige,
      );
      GameAudio.ui();
      if (track == 'gold') {
        final rate = GoldIncome.hubGoldPerMinute(_state);
        final prev = GoldIncome.hubGoldPerMinuteAtGoldLevel(_state, after - 1);
        final gained = rate - prev;
        showToast(
          '$name Lv$after · Hub ${GoldIncome.perMinuteLabel(rate)}'
          '${gained > 0 ? ' (+$gained)' : ''}'
          '${_runGoldPerMinute > 0 ? ' · Run ${GoldIncome.perMinuteLabel(_runGoldPerMinute)}' : ''}',
          life: 2.6,
        );
      } else {
        showToast('$name Lv$after · $bonus', life: 2.4);
      }
    }
  }

  void upgradeSanctuaryBulk(
    String track, {
    int maxLevels = GoldIncome.sanctuaryGoldBulkMax,
  }) {
    final beforeLevel = switch (track) {
      'gold' => _state.sanctuaryGoldLevel,
      'power' => _state.sanctuaryPowerLevel,
      'vitality' => _state.sanctuaryVitalityLevel,
      'defense' => _state.sanctuaryDefenseLevel,
      'xp' => _state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (beforeLevel < 0) return;
    final hubBefore = track == 'gold' ? GoldIncome.hubGoldPerMinute(_state) : 0;
    _applyUpgrade(
      GameLogic.upgradeSanctuaryBulk(_state, track, maxLevels: maxLevels),
    );
    final after = switch (track) {
      'gold' => _state.sanctuaryGoldLevel,
      'power' => _state.sanctuaryPowerLevel,
      'vitality' => _state.sanctuaryVitalityLevel,
      'defense' => _state.sanctuaryDefenseLevel,
      'xp' => _state.metaDepth.sanctuaryXpLevel,
      _ => beforeLevel,
    };
    if (after > beforeLevel) {
      final name = GameLogic.sanctuaryNames[track] ?? track;
      GameAudio.ui();
      if (track == 'gold') {
        final rate = GoldIncome.hubGoldPerMinute(_state);
        showToast(
          'Gold Find Lv$after · Hub ${GoldIncome.perMinuteLabel(rate)} '
          '(+${rate - hubBefore})',
          life: 2.8,
        );
      } else {
        showToast('$name Lv$after · bought ${after - beforeLevel}', life: 2.6);
      }
    }
  }

  void upgradeGodHandCd() {
    final before = _state.metaDepth.godHandCdLevel;
    _applyUpgrade(GameLogic.upgradeGodHandCd(_state));
    if (_state.metaDepth.godHandCdLevel > before) {
      GameAudio.forgeUp();
      showToast('God Hand CD Lv${_state.metaDepth.godHandCdLevel}', life: 2.2);
    }
  }

  void setGodHandStyle(int style) {
    final before = _state.metaDepth.godHandStyle;
    _applyUpgrade(GameLogic.setGodHandStyle(_state, style));
    if (_state.metaDepth.godHandStyle != before) {
      final label = switch (_state.metaDepth.godHandStyle) {
        1 => 'Focus',
        2 => 'Wide',
        _ => 'Balanced',
      };
      showToast('God Hand · $label', life: 1.8);
    }
  }

  void buyGoldBagExpansion() {
    if (!RunStashShop.canBuyGold(_state)) {
      if (RunStashShop.goldBuysAtCap(_state.metaDepth)) {
        showToast('Gold bag upgrades at cap', life: 2);
      } else {
        showToast('Need ${RunStashShop.goldBuyCost(_state)} gold', life: 2.2);
      }
      return;
    }
    _applyUpgrade(GameLogic.buyGoldBagExpansion(_state));
    GameAudio.ui();
    showToast(
      'Bag +${RunStashShop.slotsPerGoldBuy} slots (${RunStashShop.goldBuyLabel(_state)})',
      life: 2.4,
    );
  }

  void buyCinderBagExpansion() {
    if (!RunStashShop.canBuyCinders(_state)) {
      if (RunStashShop.cinderBuysAtCap(_state.metaDepth)) {
        showToast('Cinder bag upgrade owned', life: 2);
      } else {
        showToast('Need ${RunStashShop.cinderBuyCost} Cinders', life: 2.2);
      }
      return;
    }
    _applyUpgrade(GameLogic.buyCinderBagExpansion(_state));
    GameAudio.ui();
    showToast('Bag +${RunStashShop.slotsPerCinderBuy} slots', life: 2.4);
  }

  void buyPetShipmentBonus() {
    if (!PetErrandStock.canBuyShipmentBonus(_state)) {
      if (_state.metaDepth.petShipmentBonus >= PetErrandStock.maxShipmentBonus) {
        showToast('Bigger Shipment at cap', life: 2);
      } else {
        showToast('Need ${PetErrandStock.cinderCostPerBonus} Cinders', life: 2.2);
      }
      return;
    }
    _applyUpgrade(GameLogic.buyPetShipmentBonus(_state));
    GameAudio.ui();
    showToast(
      '+1 errand shipment per day (${PetErrandStock.maxCredits(_state.metaDepth)}/day cap)',
      life: 2.6,
    );
  }

  void setFarmIntensity(int mult) {
    if (!FarmIntensity.canPick(_state, mult)) {
      showToast('Unlock ${mult}× on FARM later', life: 2);
      return;
    }
    _applyUpgrade(GameLogic.setFarmIntensity(_state, mult));
    showToast('FARM ${mult}× packs · ${mult}× loot', life: 2.2);
    if (_state.inDungeon) _rebuildSpatial();
  }

  void tryFarmIntensity(int mult) {
    if (!FarmIntensity.canTry(_state, mult)) {
      showToast('No TRY left or already unlocked', life: 2);
      return;
    }
    _applyUpgrade(GameLogic.startFarmTry(_state, mult));
    showToast('TRY FARM ${mult}× this room', life: 2.2);
    if (_state.inDungeon) _rebuildSpatial();
  }

  void hatchPetEgg() {
    if (_state.ownedPets.length >= _state.metaDepth.basePetRosterCap) {
      showToast('Roster full', life: 1.8);
      return;
    }
    final next = GameLogic.hatchPetWithCinders(_state);
    if (identical(next, _state)) {
      showToast('Need ${PetService.cinderEggCost} Cinders', life: 2);
      return;
    }
    _applyUpgrade(next);
    GameAudio.unlock();
    showToast('Pet hatched from egg', life: 2.2);
  }

  void buyPrestigeShopItem(String id) {
    final catalog = PrestigeShopCatalog.byId(id);
    if (catalog == null || !catalog.listedInShop) return;
    final before = _state.essence;
    if (PrestigeShopCatalog.atCap(_state.metaDepth, id)) {
      showToast('At cap', life: 1.8);
      return;
    }
    _applyUpgrade(GameLogic.buyPrestigeShopItem(_state, id));
    if (_state.essence < before) {
      String name = id;
      for (final item in PrestigeShopCatalog.all) {
        if (item.id == id) {
          name = item.name;
          break;
        }
      }
      GameAudio.ui();
      showToast('Bought $name', life: 2.2);
    }
  }

  void claimDailyVault() {
    final before = _state.essence;
    _applyUpgrade(GameLogic.claimDailyVault(_state));
    if (_state.essence > before) {
      GameAudio.unlock();
      final notices = LogicNotices.takeMetaPayoffs();
      final gained = _state.essence - before;
      final extra = notices.isEmpty ? '' : ' · ${notices.join(' · ')}';
      showToast('Daily Vault claimed · +${gained}e$extra', life: 2.8);
    }
  }

  /// Settle Will / Gauntlet / week / GR payoffs that auto-claim on hub sync.
  void syncMetaPayoffs() {
    final before = _state.essence;
    _applyUpgrade(GameLogic.syncMetaPayoffs(_state));
    final notices = LogicNotices.takeMetaPayoffs();
    final gained = _state.essence - before;
    if (gained > 0 || notices.isNotEmpty) {
      GameAudio.ui();
      final body = notices.isNotEmpty
          ? notices.join(' · ')
          : 'Meta rewards · +${gained}e';
      showToast(body, life: 2.6);
    } else {
      showToast('No week rewards waiting — keep pushing.', life: 2.0);
    }
  }

  /// Playtest / web: grant one Ad Ticket without an ad.
  void grantPowerupHour({int? nowMs}) {
    final before = _state.metaDepth.adTickets;
    _applyUpgrade(GameLogic.grantAdTicket(_state));
    final after = _state.metaDepth.adTickets;
    if (after > before) {
      GameAudio.ui();
      showToast('Ad Ticket +${AdBoost.ticketsPerAd} · $after total', life: 2.4);
    } else {
      showToast('Could not add Ad Ticket', life: 2.0);
    }
  }

  Future<void> _warmupShopStore() async {
    if (!ShopBilling.billingReady) return;
    await ShopStore.warmup(
      onGranted:
          ({
            required String productId,
            required String purchaseId,
            required bool restored,
            bool recovered = false,
          }) => _onShopPurchaseGranted(
            productId,
            purchaseId: purchaseId,
            restored: restored,
            recovered: recovered,
          ),
      onMessage: (msg) => showToast(msg, life: 2.4),
    );
    notifyListeners();
  }

  /// True when the grant is saved, or there was nothing new to save.
  /// False when the save did not land — the caller must leave the Play
  /// purchase unconsumed.
  ///
  /// [restored] is a Play restore or a startup past-purchase query. Those
  /// must not toast "Purchased" or log a store_purchase event.
  /// [recovered] is a startup past-purchase query. A pouch that actually
  /// grants Cinders toasts "Purchase restored" and still does not log a buy.
  Future<bool> _onShopPurchaseGranted(
    String productId, {
    required String purchaseId,
    bool restored = false,
    bool recovered = false,
  }) async {
    final item = ShopCatalog.byId[productId];
    if (item == null) return true;
    final known = ShopBilling.alreadyGranted(_state, purchaseId);
    if (!ShopBilling.shouldGrantPurchase(
      item: item,
      restored: restored,
      purchaseId: purchaseId,
      alreadyGranted: known,
    )) {
      return true;
    }
    final beforeOwned = ShopBilling.isOwned(_state, item);
    final beforeCinders = _state.metaDepth.cinders;
    final next = ShopBilling.applyTrackedPurchase(
      _state,
      item,
      purchaseId: purchaseId,
    );
    if (identical(next, _state) && beforeOwned) {
      if (!restored) {
        showToast('${item.name} restored', life: 2.2);
      }
      return true;
    }
    if (identical(next, _state)) return true;
    if (!_hasExistingSave) return false;
    final priorMeta = _state.metaDepth;
    _applyUpgrade(next);
    final saved = await _persistFlush();
    if (!saved) {
      // Keep gold, fight progress, and the rest of the live state.
      // Only the grant, which lives on meta, is undone.
      _applyUpgrade(_state.copyWith(metaDepth: priorMeta));
      return false;
    }
    final paidCinders = _state.metaDepth.cinders > beforeCinders;
    if (recovered && paidCinders) {
      GameAudio.ui();
      showToast('Purchase restored', life: 2.6);
      return true;
    }
    if (restored) return true;
    GameAudio.ui();
    showToast('Purchased ${item.name}', life: 2.6);
    unawaited(AppAnalytics.storePurchase(productId));
    return true;
  }

  /// Test hook for the Play grant path, including a failed save.
  @visibleForTesting
  Future<bool> debugGrantShopPurchase(
    String productId, {
    required String purchaseId,
    bool restored = false,
    bool recovered = false,
  }) => _onShopPurchaseGranted(
    productId,
    purchaseId: purchaseId,
    restored: restored,
    recovered: recovered,
  );

  Future<void> buyShopItem(String productId) async {
    if (!ShopBilling.billingReady) {
      showToast('Shop buys coming later.', life: 2.2);
      return;
    }
    final item = ShopCatalog.byId[productId];
    if (item == null) return;
    if (!ShopCatalog.mayBuy(
      productId,
      playLists: ShopStore.storeLists(productId),
    )) {
      showToast(
        item.kind == ShopOfferKind.boostHours
            ? 'That pack restores only.'
            : 'Play has not listed this pack yet.',
        life: 2.8,
      );
      return;
    }
    if (ShopBilling.isOwned(_state, item)) {
      showToast('Already owned', life: 2.0);
      return;
    }
    unawaited(AppAnalytics.storePurchaseStart(productId));
    final err = await ShopStore.buy(productId);
    notifyListeners();
    if (err != null) {
      unawaited(AppAnalytics.storePurchaseCancel(productId));
      showToast(err, life: 3.2);
      return;
    }
    // Success arrives via purchaseStream → _onShopPurchaseGranted.
  }

  Future<void> restoreShopPurchases() async {
    if (!ShopBilling.billingReady) {
      showToast('Shop buys coming later.', life: 2.2);
      return;
    }
    showToast('Restoring purchases…', life: 1.8);
    final err = await ShopStore.restore();
    if (err != null) {
      showToast(err, life: 2.6);
      return;
    }
    notifyListeners();
  }

  void redeemCoupon(String raw) {
    final result = CouponCodes.redeem(_state, raw);
    switch (result.status) {
      case CouponRedeemStatus.unknown:
        showToast('Unknown code', life: 2.0);
        return;
      case CouponRedeemStatus.alreadyUsed:
        showToast('Code already used on this save', life: 2.2);
        return;
      case CouponRedeemStatus.alreadyOwned:
        _applyUpgrade(result.state);
        showToast('Forever scrolls already owned', life: 2.2);
        return;
      case CouponRedeemStatus.granted:
        _applyUpgrade(result.state);
        GameAudio.ui();
        showToast('All forever scrolls unlocked', life: 2.6);
    }
  }

  void spendPowerupBuff(AdBuffId id, {int? nowMs}) {
    final offer = AdBuffCatalog.byId(id);
    final before = _state.metaDepth.adTickets;
    if (before < offer.ticketCost) {
      showToast('Need ${offer.ticketCost} Ad Ticket(s)', life: 2.0);
      return;
    }
    final next = GameLogic.spendAdBuff(_state, id, nowMs: nowMs);
    if (identical(next, _state) || next.metaDepth.adTickets == before) {
      showToast('Boost already stacked to 24 hours', life: 2.0);
      return;
    }
    _applyUpgrade(next);
    GameAudio.ui();
    showToast('${offer.label} · ready', life: 2.2);
  }

  /// Ad-free daily: +1 ticket without watching.
  void claimAdFreeDailyTicket({DateTime? now}) {
    final before = _state.metaDepth.adTickets;
    final next = GameLogic.claimAdFreeDailyTicket(_state, now: now);
    if (next.metaDepth.adTickets <= before) {
      showToast('Daily ticket already claimed today', life: 2.0);
      return;
    }
    _applyUpgrade(next);
    GameAudio.ui();
    showToast('Daily Ad Ticket claimed', life: 2.2);
  }

  /// SCROLLS Well step 1: free ticket (F2P, UTC day).
  void claimScrollWellFree({DateTime? now}) {
    if (_state.metaDepth.adFree) return;
    final before = _state.metaDepth.adTickets;
    final next = GameLogic.claimScrollWellFree(_state, now: now);
    if (next.metaDepth.adTickets <= before) {
      showToast('Daily free ticket already claimed', life: 2.0);
      return;
    }
    _applyUpgrade(next);
    GameAudio.ui();
    showToast('Free Ad Ticket · Well 1/3', life: 2.2);
    unawaited(
      AppAnalytics.logEvent(AnalyticsEvents.scrollWellFree, {
        'step': 1,
      }),
    );
  }

  /// A rewarded ad finished. Preview tickets do not count.
  void noteCompletedRewardedWatch() {
    final next = AdFreeNudge.noteWatch(_state);
    if (identical(next, _state)) return;
    _applyUpgrade(next);
  }

  /// SCROLLS showed the Ad-free line. Once per save. Logs the impression.
  void markAdFreeNudgeShown() {
    if (_state.metaDepth.adFreeNudgeShown) return;
    final next = AdFreeNudge.markShown(_state);
    if (identical(next, _state)) return;
    _applyUpgrade(next);
    unawaited(AppAnalytics.adFreeNudgeView());
  }

  /// Player tapped the SCROLLS line. The sheet opens SHOP after this.
  void openAdFreeFromScrollsNudge() {
    markAdFreeNudgeShown();
    unawaited(AppAnalytics.adFreeNudgeTap());
  }

  /// Android: show a rewarded ad, then +[AdBoost.ticketsPerAd] Ad Ticket.
  Future<void> watchPowerupAd() async {
    if (!AdRewarded.realAdsAvailable) {
      showToast('Ads play on the Android app', life: 2.2);
      return;
    }
    final wellAd = ScrollWell.canAdvanceWithAd(_state.metaDepth);
    showToast('Loading ad…', life: 1.4);
    final result = await AdRewarded.showRewarded(
      placement: wellAd
          ? AnalyticsEvents.placementScrollWell
          : AnalyticsEvents.placementPowerups,
    );
    switch (result) {
      case AdWatchResult.rewarded:
        noteCompletedRewardedWatch();
        if (wellAd) {
          final before = _state.metaDepth.adTickets;
          final step = ScrollWell.bonusClaims(_state.metaDepth) + 1;
          final next = GameLogic.advanceScrollWellBonusAd(_state);
          if (next.metaDepth.adTickets <= before) {
            showToast('Well step already claimed', life: 2.0);
            return;
          }
          _applyUpgrade(next);
          GameAudio.ui();
          showToast('Ad Ticket · Well $step/3', life: 2.2);
          unawaited(
            AppAnalytics.logEvent(AnalyticsEvents.scrollWellAd, {
              'step': step,
            }),
          );
        } else {
          grantPowerupHour();
        }
      case AdWatchResult.skipped:
        showToast(
          'Watch the whole ad to get ${AdBoost.ticketsPerAd} Ad Ticket',
          life: 2.2,
        );
      case AdWatchResult.failed:
        showToast('Ad not ready — try again in a bit', life: 2.2);
      case AdWatchResult.unavailable:
        showToast('Ads play on the Android app', life: 2.2);
    }
  }

  /// MORE → QUESTS: reroll Daily or Side (2/day UTC). F2P watches an ad.
  Future<void> rerollQuestSlot(int slotIndex) async {
    if (MissionBoard.questRerollsRemaining(_state) <= 0) {
      showToast('No quest rerolls left today', life: 2.2);
      return;
    }
    if (slotIndex < 0 || slotIndex >= _state.missions.length) return;
    final mission = _state.missions[slotIndex];
    if (!MissionBoard.canRerollMission(mission, slotIndex)) {
      showToast('Finish or claim this quest first', life: 2.2);
      return;
    }
    if (_state.metaDepth.adFree) {
      _finishQuestReroll(slotIndex);
      return;
    }
    if (!AdRewarded.realAdsAvailable) {
      showToast('Ads play on the Android app', life: 2.2);
      return;
    }
    showToast('Loading ad…', life: 1.4);
    final result = await AdRewarded.showRewarded(
      placement: AnalyticsEvents.placementQuestReroll,
    );
    switch (result) {
      case AdWatchResult.rewarded:
        noteCompletedRewardedWatch();
        _finishQuestReroll(slotIndex);
      case AdWatchResult.skipped:
        showToast('Watch the whole ad to reroll this quest', life: 2.2);
      case AdWatchResult.failed:
        showToast('Ad not ready — try again in a bit', life: 2.2);
      case AdWatchResult.unavailable:
        showToast('Ads play on the Android app', life: 2.2);
    }
  }

  void _finishQuestReroll(int slotIndex) {
    final before = _state.metaDepth.questRerollsToday;
    final next = MissionBoard.applyQuestReroll(_state, slotIndex);
    if (identical(next, _state) ||
        next.metaDepth.questRerollsToday <= before) {
      return;
    }
    _applyUpgrade(next);
    GameAudio.ui();
    final left = MissionBoard.questRerollsRemaining(_state);
    showToast('Quest rerolled · $left left today', life: 2.2);
    unawaited(
      AppAnalytics.logEvent(AnalyticsEvents.questReroll, {
        'slot': slotIndex == MissionBoard.dailySlot ? 'daily' : 'side',
        'left_today': left,
      }),
    );
  }

  void claimCodexReward(String tierId) {
    final before = _state.essence;
    _applyUpgrade(GameLogic.claimCodexReward(_state, tierId));
    if (_state.essence > before) {
      GameAudio.ui();
      showToast('Codex reward · +${_state.essence - before}e', life: 2.2);
    }
  }

  void ascend() {
    if (_isLoading) {
      return;
    }

    final hadRogue = _state.rogueUnlocked;
    final fromAl = _state.ascensionLevel;
    final updated = GameLogic.ascend(_state);
    if (identical(updated, _state)) {
      return;
    }

    final milestone = MetaSystems.ascendMilestoneReward(
      fromAl,
      updated.ascensionLevel,
    );
    _state = updated;
    unawaited(AppAnalytics.ascend(fromAl: fromAl, toAl: _state.ascensionLevel));
    GameAudio.ascend();
    final parts = <String>[
      StoryLore.ascendToast(
        al: _state.ascensionLevel,
        milestoneBonus: milestone,
        blessings: _state.metaDepth.ascendBlessings,
      ),
    ];
    if (!hadRogue && _state.rogueUnlocked) {
      parts.add('Shade joins');
    }
    final reveals = _state.metaDepth.pendingHeroReveals;
    if (reveals.isNotEmpty) {
      final names = <String>[];
      for (final name in reveals.take(2)) {
        final id = HeroIdentity.tryParseSpec(name);
        if (id == null) continue;
        names.add(HeroSpecs.def(id).name);
      }
      if (names.isNotEmpty) {
        final extra = reveals.length - names.length;
        parts.add(
          extra > 0
              ? 'New: ${names.join(' · ')} · +$extra'
              : 'New: ${names.join(' · ')}',
        );
      }
    }
    DebugPlayLog.event(
      'ascend',
      'AL$fromAl→${_state.ascensionLevel} · e ${_state.essence}',
    );
    showToast(parts.join(' · '), life: 3.6);
    final payoffs = LogicNotices.takeMetaPayoffs();
    if (payoffs.isNotEmpty) {
      showToast(payoffs.join(' · '), life: 3.0);
    }
    if (_state.inDungeon) {
      _rebuildSpatial();
    } else {
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    }
    notifyListeners();
    unawaited(_persistFlush());
  }

  void rebornAtCap() {
    if (_isLoading) {
      return;
    }
    if (!GameLogic.canRebornAtCap(_state)) {
      return;
    }
    final updated = GameLogic.rebornAtCap(_state);
    if (identical(updated, _state)) {
      return;
    }
    _state = updated;
    GameAudio.unlock();
    DebugPlayLog.event(
      'reborn',
      'AL${_state.ascensionLevel} · e ${_state.essence}',
    );
    showToast(
      StoryLore.rebornToast(essence: GameLogic.rebornEssenceReward()),
      life: 3.6,
    );
    final payoffs = LogicNotices.takeMetaPayoffs();
    if (payoffs.isNotEmpty) {
      showToast(payoffs.join(' · '), life: 3.0);
    }
    if (_state.inDungeon) {
      _rebuildSpatial();
    } else {
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    }
    notifyListeners();
    unawaited(_persistFlush());
  }

  void reviveParty() {
    if (_isLoading || !_state.isPartyDefeated) return;
    // Soft-lock recovery: dead party without modal still exits/retries.
    if (!_awaitingWipeChoice) {
      _awaitingWipeChoice = true;
    }
    if (_state.inGauntlet) {
      hubAfterWipe();
      return;
    }
    retryAfterWipe();
  }

  bool _pendingStartMenu = false;
  NavIntent? _pendingHubNav;

  bool get pendingStartMenu => _pendingStartMenu;

  /// Consume a one-shot menu open after wipe → hub (POWER / BAG / Shop).
  NavIntent? takePendingHubNav() {
    final nav = _pendingHubNav;
    _pendingHubNav = null;
    return nav;
  }

  void clearPendingStartMenu() {
    _pendingStartMenu = false;
  }

  Future<void> reset() async {
    if (_isLoading) {
      return;
    }
    _awaitingWipeChoice = false;
    await _storage.clear();
    _state = GameLogic.createInitialState();
    _hasExistingSave = false;
    _saveSlots = await _storage.listSlots();
    _pendingStartMenu = true;
    _syncDevicePrefs();
    _spatialTimer?.cancel();
    _spatial = null;
    notifyListeners();
  }

  /// Part extensions call this; [notifyListeners] is @protected on [ChangeNotifier].
  void _directorNotify() => notifyListeners();

  void _applyUpgrade(GameState updated) {
    if (_isLoading || identical(updated, _state)) {
      return;
    }

    final before = _state;
    _state = updated;
    final delta = DebugPlayLog.stateDelta(before, _state);
    if (delta != null) DebugPlayLog.event('state', delta);
    _syncDevicePrefs();
    _announceAbilityUnlocks(before, _state);
    _announceAchievementUnlocks(before, _state);
    _flushQuestReadyToast();
    if (!_state.inDungeon) {
      _spatial = null;
    } else if (_spatial != null &&
        before.inDungeon &&
        before.battleNumber == _state.battleNumber &&
        before.layoutSeed == _state.layoutSeed) {
      // Gear / forge / train mid-fight: keep enemies & positions.
      _spatial = SpatialCombat.syncPartyFromState(_spatial!, _state);
    } else {
      _rebuildSpatial();
    }
    notifyListeners();
    unawaited(_persistFlush());
  }

  void _syncDevicePrefs() {
    GameAudio.hapticsEnabled = _state.hapticsEnabled;
    GameAudio.applyVolumes(
      sfx: _state.sfxVolume,
      ambience: _state.ambienceVolume,
      music: _state.musicVolume,
    );
    GameAudio.setMuted(_state.soundMuted);
    SpatialCombat.colorblindMode = _state.colorblindMode;
    SpatialCombat.hideHealFloaters = _state.hideHealFloaters;
    SpatialCombat.compactNumbers = _state.compactCombatNumbers;
    GameAudio.coalesceLightHaptics = _state.vfxQuality != VfxQuality.full;
    SpatialCombat.alwaysShowEnemyHp = _state.alwaysShowEnemyHp;
    unawaited(
      ScreenAwake.setEnabled(_state.keepScreenAwake && _state.inDungeon),
    );
    // Only switch loops on hub ↔ dungeon, a boss, or unmute. Re-calling
    // every `_applyUpgrade` used to restart music on each button press.
    // While muted the score still tracks the fight so unmute is in the
    // right place; playback itself stays stopped.
    _syncSituationMusic();
  }

  void _syncSituationMusic() {
    unawaited(
      GameAudio.setAmbience(
        _state.inDungeon ? AmbienceKind.dungeon : AmbienceKind.hub,
        bossFight: _state.inDungeon && bossEncounterNow,
        floor: _state.currentRoom.floorNumber,
        dungeonId: _state.dungeonId,
      ),
    );
  }

  bool get bossEncounterNow =>
      _state.currentRoom.type == RoomType.boss ||
      _state.riftGuardianActive ||
      _state.grGuardianActive ||
      _state.inWorldBoss;

  void _announceAbilityUnlocks(GameState before, GameState after) {
    final bits = <String>[];
    var leveled = false;
    for (var i = 0; i < after.heroes.length; i++) {
      final hero = after.heroes[i];
      final oldLevel = i < before.heroes.length ? before.heroes[i].level : 0;
      if (hero.level <= oldLevel) continue;
      leveled = true;
      final unlocked = ClassKits.unlockedAtSpec(
        hero.specId,
        hero.level,
      ).where((d) => d.unlockLevel > oldLevel && d.unlockLevel <= hero.level);
      for (final ability in unlocked) {
        bits.add('${hero.name}: ${ability.shortLabel}');
      }
    }
    if (!leveled) return;
    GameAudio.levelUp();
    if (bits.isEmpty) {
      showToast('LEVEL UP!', life: 2.2);
      return;
    }
    // One toast — avoids spam when several heroes level in the same clear.
    showToast(
      bits.length == 1 ? '${bits.first}!' : '${bits.take(3).join(' · ')}!',
      life: 2.4,
    );
  }

  void _announceAchievementUnlocks(GameState before, GameState after) {
    if (after.achievements.length <= before.achievements.length) return;
    final known = before.achievements.toSet();
    var gain = 0;
    var fresh = 0;
    for (final id in after.achievements) {
      if (known.contains(id)) continue;
      fresh++;
      gain += AchievementCatalog.byId(id)?.essenceReward ?? 0;
    }
    if (fresh == 0) return;
    GameAudio.achievement();
    showToast(
      gain > 0 ? 'Achievement unlocked · +${gain}e' : 'Achievement unlocked!',
      life: 2.8,
    );
  }

  @override
  void dispose() {
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _combatFrameQueued = false;
    _wipeAutoTimer?.cancel();
    wipeAutoSeconds.dispose();
    _uiTimer?.cancel();
    _bootWarmup?.cancel();
    _hubIdleTimer?.cancel();
    combatFrame.dispose();
    PlayGamesBridge.cancelPendingUpload();
    unawaited(ShopStore.dispose());
    super.dispose();
  }
}
