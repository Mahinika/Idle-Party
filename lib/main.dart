import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_analytics.dart';
import 'core/equipment_factory.dart';
import 'core/gear/drop_tables.dart';
import 'core/game_director.dart';
import 'core/immersive_ui.dart';
import 'core/menu_router.dart';
import 'models/hero.dart';
import 'models/hero_spec.dart';
import 'ui/boot_intro_screen.dart';
import 'assets/custom_assets.dart';
import 'ui/game_audio.dart';
import 'ui/loading_splash.dart';
import 'ui/theme.dart';
import 'ui/new_game_party_picker.dart';
import 'ui/play_update_required_screen.dart';
import 'ui/save_import_flow.dart';
import 'ui/shell/play_shell.dart';
import 'ui/start_menu_screen.dart';
import 'ui/web_click_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget before first frame — phone product is edge-to-edge game UI.
  unawaited(lockImmersiveUi());
  // Android + google-services.json only; no-op elsewhere / missing config.
  unawaited(AppAnalytics.init());
  runApp(const MyApp());
  // Expose the semantics DOM overlay on web so browser automation / a11y
  // tools can click buttons (CanvasKit has no real DOM widgets otherwise).
  // Must run after runApp — see flutter.dev accessibility-on-the-web.
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
    WebClickBridge.install();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.director,
    this.autoStartLoop = true,
    this.showIntro = true,
  });

  final GameDirector? director;
  final bool autoStartLoop;

  /// Cold-start title card. Tests set this false to land on the hub immediately.
  final bool showIntro;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final GameDirector _director;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Stable for the app lifetime — never recreate on MaterialApp rebuilds.
    _director = widget.director ?? GameDirector.persistent();
    unawaited(lockImmersiveUi());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(lockImmersiveUi());
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'Idle Party',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.vt323TextTheme(base.textTheme).apply(
          bodyColor: GameTheme.parchment,
          displayColor: GameTheme.torchHot,
        ),
        colorScheme: const ColorScheme.dark(
          primary: GameTheme.torch,
          secondary: GameTheme.mossLit,
          surface: GameTheme.stone,
          onSurface: GameTheme.parchment,
          error: GameTheme.bloodLit,
        ),
        scaffoldBackgroundColor: GameTheme.ink,
      ),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!kIsWeb) return content;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Samsung Galaxy A56: 1080×2340 @ DPR 3 → 360×780 CSS.
            // Always letterbox to that phone frame so web playtest matches the
            // APK — never stretch to a tall/wide Cursor browser panel.
            const phoneW = 360.0;
            const phoneH = 780.0;
            // Approx status bar + gesture home indicator (logical / CSS px).
            const padTop = 28.0;
            const padBottom = 20.0;
            final mq = MediaQuery.of(context);
            return ColoredBox(
              color: const Color(0xFF05070A),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: phoneW,
                    height: phoneH,
                    child: MediaQuery(
                      data: mq.copyWith(
                        size: const Size(phoneW, phoneH),
                        padding: const EdgeInsets.only(
                          top: padTop,
                          bottom: padBottom,
                        ),
                        viewPadding: const EdgeInsets.only(
                          top: padTop,
                          bottom: padBottom,
                        ),
                        viewInsets: EdgeInsets.zero,
                        devicePixelRatio: 3,
                      ),
                      child: content,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      home: GameHomePage(
        key: const ValueKey('game-home'),
        director: _director,
        autoStartLoop: widget.autoStartLoop,
        showIntro: widget.showIntro,
      ),
    );
  }
}

enum _AppPhase {
  loading,
  playUpdateRequired,
  bootIntro,
  startMenu,
  pickSave,
  newGamePicker,
  play,
}

class GameHomePage extends StatefulWidget {
  const GameHomePage({
    super.key,
    required this.director,
    required this.autoStartLoop,
    this.showIntro = true,
  });

  final GameDirector director;
  final bool autoStartLoop;
  final bool showIntro;

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage>
    with WidgetsBindingObserver {
  GameDirector get _director => widget.director;

  /// One owner of "which menu is open", shared by hub and dungeon.
  final MenuRouter _router = MenuRouter();
  _AppPhase _phase = _AppPhase.loading;
  bool _playUpdateTapBusy = false;
  _AppPhase _menuBeforeNewGame = _AppPhase.startMenu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _director.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        GameAudio.onAppPaused();
        _director.setAppPaused(true);
      case AppLifecycleState.inactive:
        // Control-center / notification shade — mute audio only; keep sim
        // so a brief swipe does not stutter combat.
        GameAudio.onAppPaused();
      case AppLifecycleState.resumed:
        GameAudio.onAppResumed();
        _director.setAppPaused(false);
        unawaited(_director.syncFriendReferral());
        if (_phase != _AppPhase.playUpdateRequired) return;
        unawaited(_recheckMandatoryPlayUpdate());
    }
  }

  Future<void> _bootstrap() async {
    unawaited(EquipmentFactory.loadAffixes());
    unawaited(DropTables.load());
    // Defer combat loop until after start menu so dungeon ticks cannot steal focus.
    await _director.boot(deferCombatLoop: widget.showIntro);
    if (!mounted) return;

    final blocked = await _director.checkMandatoryPlayUpdate();
    if (!mounted) return;
    if (blocked) {
      setState(() => _phase = _AppPhase.playUpdateRequired);
      // Still warm audio in the background behind the update gate.
      unawaited(_initAudioAfterFirstPaint());
      return;
    }

    // Paint hub/dungeon before SoLoud — AAudio open was ~250+ skipped frames.
    _enterAfterBootChecks();
    unawaited(_precacheScenes());
    unawaited(_initAudioAfterFirstPaint());
  }

  Future<void> _initAudioAfterFirstPaint() async {
    // Let the first Flutter frame complete before touching the audio engine.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await GameAudio.init();
    unawaited(GameAudio.warmRemainingAssets());
    GameAudio.hapticsEnabled = _director.state.hapticsEnabled;
    GameAudio.applyVolumes(
      sfx: _director.state.sfxVolume,
      ambience: _director.state.ambienceVolume,
      music: _director.state.musicVolume,
    );
    GameAudio.setMuted(_director.state.soundMuted);
    unawaited(
      GameAudio.setAmbience(
        _director.state.inDungeon ? AmbienceKind.dungeon : AmbienceKind.hub,
        bossFight: _director.bossEncounterNow,
        floor: _director.state.currentRoom.floorNumber,
      ),
    );
    if (kIsWeb) {
      WebClickBridge.bindSpeedControls(
        getSpeed: () => _director.debugTimeScale,
        setSpeed: _director.setDebugTimeScale,
      );
    }
  }

  void _enterAfterBootChecks() {
    setState(() {
      _phase = widget.showIntro ? _AppPhase.bootIntro : _AppPhase.play;
    });
    if (_phase == _AppPhase.play) {
      _director.ensureCombatLoop();
    }
  }

  Future<void> _recheckMandatoryPlayUpdate() async {
    final blocked = await _director.checkMandatoryPlayUpdate();
    if (!mounted) return;
    if (blocked) {
      setState(() {
        _phase = _AppPhase.playUpdateRequired;
        _playUpdateTapBusy = false;
      });
      return;
    }
    _enterAfterBootChecks();
  }

  Future<void> _startMandatoryPlayUpdate() async {
    if (_playUpdateTapBusy) return;
    setState(() => _playUpdateTapBusy = true);
    await _director.startMandatoryPlayUpdate();
    if (!mounted) return;
    setState(() => _playUpdateTapBusy = false);
    await _recheckMandatoryPlayUpdate();
  }

  /// Warms the two painted scenes the player hits first, while the intro or
  /// start menu is still on screen. Decode sizes must match
  /// [CaveAtmosphere.fullBleedScene] or the warm-up lands in a different
  /// cache entry and buys nothing.
  Future<void> _precacheScenes() async {
    for (final asset in <String>[
      CustomAssets.hubScene,
      CustomAssets.dungeonBackdropFor(_director.state.dungeonId),
    ]) {
      if (!mounted) return;
      await precacheImage(
        ResizeImage(
          AssetImage(asset),
          width: 960,
          height: 960,
          allowUpscaling: false,
        ),
        context,
      );
    }
  }

  void _continueGame() {
    if (_phase != _AppPhase.startMenu && _phase != _AppPhase.pickSave) return;
    _director.continueGame();
    setState(() => _phase = _AppPhase.play);
    _director.ensureCombatLoop();
  }

  void _openSavePicker() {
    if (_phase != _AppPhase.startMenu) return;
    setState(() => _phase = _AppPhase.pickSave);
  }

  void _openNewGamePicker() {
    if (_phase != _AppPhase.startMenu && _phase != _AppPhase.pickSave) return;
    final empty = _director.saveSlots.indexWhere((slot) => !slot.occupied);
    if (empty < 0) return;
    _director.armNewGameSlot(empty);
    _menuBeforeNewGame = _phase;
    setState(() => _phase = _AppPhase.newGamePicker);
  }

  String? _continueSummary() {
    final slots = _director.saveSlots;
    SaveSlotSummary? slot;
    final active = _director.activeSaveSlot;
    if (active >= 0 && active < slots.length) {
      final current = slots[active];
      if (current.occupied && !current.corrupt) slot = current;
    }
    if (slot == null) {
      for (final candidate in slots) {
        if (candidate.occupied && !candidate.corrupt) {
          slot = candidate;
          break;
        }
      }
    }
    final name = slot?.partyName;
    if (name == null || name.isEmpty) return null;
    final zone = slot?.zoneName;
    if (zone == null || zone.isEmpty) return name;
    return '$name · $zone';
  }

  void _savesFull() {
    showDialog<void>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Saves full',
        content: Text(
          'All five saves are in use. Continue, then erase one.',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          GameButton(
            label: 'OK',
            expanded: false,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _openSlot(int index) async {
    if (_phase != _AppPhase.pickSave) return;
    if (index < 0 || index >= _director.saveSlots.length) return;
    final slot = _director.saveSlots[index];
    if (!slot.occupied || slot.corrupt) {
      if (slot.corrupt) return;
      _director.armNewGameSlot(index);
      _openNewGamePicker();
      return;
    }
    final ok = await _director.openSaveSlot(index);
    if (!ok || !mounted) return;
    _continueGame();
  }

  Future<void> _eraseSlot(int index) async {
    if (_phase != _AppPhase.pickSave) return;
    if (index < 0 || index >= _director.saveSlots.length) return;
    final slot = _director.saveSlots[index];
    if (!slot.occupied) return;
    WebClickBridge.pushLayer();
    bool? ok;
    try {
      final who = slot.partyName ?? slot.label;
      ok = await showDialog<bool>(
        context: context,
        barrierColor: MenuChrome.scrim,
        builder: (ctx) => MenuChrome.dialog(
          title: 'Erase ${slot.label}?',
          content: Text(
            '$who will be deleted. Your other saves stay.',
            style: GameTheme.body(size: 15, color: GameTheme.parchment),
          ),
          actions: [
            GameButton(
              label: 'CANCEL',
              style: GameButtonStyle.grey,
              expanded: false,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            GameButton(
              label: 'ERASE',
              expanded: false,
              style: GameButtonStyle.red,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
    } finally {
      WebClickBridge.popLayer();
    }
    if (ok != true || !mounted) return;
    await _director.eraseSaveSlot(index);
    if (mounted) setState(() {});
  }

  Future<void> _restoreSave() async {
    if (_phase != _AppPhase.startMenu) return;
    final slot = _director.preferredImportSlot;
    final replaces = _director.saveSlots[slot].occupied;
    if (!mounted) return;
    final label = 'SAVE ${slot + 1}';
    final ok = await SaveImportFlow.fromClipboard(
      context: context,
      director: _director,
      message: replaces
          ? 'This replaces $label. This cannot be undone.'
          : 'This fills $label from the clipboard.',
      onConfirmed: () => _director.armImportSlot(slot),
    );
    if (!ok || !mounted) return;
    _continueGame();
  }

  Future<void> _confirmNewGame(
    List<HeroSpecId> specs,
    String partyName,
    List<HeroRace> races,
  ) async {
    await _director.startNewGame(
      specs,
      partyName: partyName,
      partyRaces: races,
    );
    if (!mounted) return;
    _director.clearPendingStartMenu();
    setState(() => _phase = _AppPhase.play);
    _director.ensureCombatLoop();
  }

  @override
  Widget build(BuildContext context) {
    // Intro is outside the director AnimatedBuilder so toast/combat notifies
    // cannot rebuild or accidentally dismiss the title card.
    if (_phase == _AppPhase.loading) {
      return const LoadingSplash();
    }

    if (_phase == _AppPhase.playUpdateRequired) {
      return PlayUpdateRequiredScreen(
        key: const ValueKey('play-update-required'),
        updating: _playUpdateTapBusy,
        onUpdate: () => unawaited(_startMandatoryPlayUpdate()),
      );
    }

    if (_phase == _AppPhase.bootIntro) {
      return Scaffold(
        body: BootIntroScreen(
          key: const ValueKey('boot-intro'),
          showStory:
              !_director.hasAnySave &&
              !_director.state.seenTips.contains(BootIntroScreen.storyTipId),
          playCinematic:
              CustomAssets.introVideoBundled &&
              !_director.state.seenTips.contains(
                BootIntroScreen.cinematicTipId,
              ),
          muted: GameAudio.muted,
          onCinematicConsumed: () =>
              _director.dismissTip(BootIntroScreen.cinematicTipId),
          onFinished: () {
            _director.dismissTip(BootIntroScreen.storyTipId);
            if (!mounted) return;
            setState(() => _phase = _AppPhase.startMenu);
          },
        ),
      );
    }

    if (_phase == _AppPhase.startMenu) {
      return Scaffold(
        body: StartMenuScreen(
          key: const ValueKey('start-menu'),
          canContinue: _director.hasAnySave,
          saveSummary: _continueSummary(),
          canStartNewGame: _director.saveSlots.any((slot) => !slot.occupied),
          onContinue: _openSavePicker,
          onNewGame: _openNewGamePicker,
          onSavesFull: _savesFull,
          onRestore: () => unawaited(_restoreSave()),
          onSettings: () {
            if (_director.hasExistingSave) {
              _continueGame();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _router.open(MenuRoute.more, more: MoreSection.settings);
              });
              return;
            }
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: GameTheme.ink,
                title: Text('Settings', style: GameTheme.menuTitle(size: 18)),
                content: Text(
                  'Start or continue a save, then open MORE → SETTINGS for sound, zoom, and save tools.\n\n'
                  'Privacy options are on PRIVACY below.',
                  style: GameTheme.body(size: 14, color: GameTheme.parchment),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'OK',
                      style: GameTheme.body(
                        size: 14,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    if (_phase == _AppPhase.pickSave) {
      return Scaffold(
        body: SaveSlotPicker(
          key: const ValueKey('save-picker'),
          slots: _director.saveSlots,
          activeSlot: _director.activeSaveSlot,
          onOpenSlot: (index) => unawaited(_openSlot(index)),
          onEraseSlot: (index) => unawaited(_eraseSlot(index)),
          onBack: () => setState(() => _phase = _AppPhase.startMenu),
        ),
      );
    }

    if (_phase == _AppPhase.newGamePicker) {
      return NewGamePartyPicker(
        key: const ValueKey('new-game-picker'),
        onBack: () => setState(() => _phase = _menuBeforeNewGame),
        onConfirm: _confirmNewGame,
      );
    }

    return AnimatedBuilder(
      animation: _director,
      builder: (context, _) {
        if (_director.pendingStartMenu && _phase == _AppPhase.play) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!_director.pendingStartMenu) return;
            _director.clearPendingStartMenu();
            setState(() => _phase = _AppPhase.startMenu);
          });
        }

        final body = PlayShell(director: _director, router: _router);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: GameTheme.composeTextScaler(
              platform: MediaQuery.textScalerOf(context),
              gameScale: _director.state.uiTextScale,
            ),
          ),
          child: Scaffold(
            // Shells apply SafeArea around chrome so dungeon art can full-bleed.
            body: body,
          ),
        );
      },
    );
  }
}
