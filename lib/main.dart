import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/equipment_factory.dart';
import 'core/gear/drop_tables.dart';
import 'core/game_director.dart';
import 'core/menu_router.dart';
import 'models/dungeon_def.dart';
import 'models/hero_spec.dart';
import 'ui/boot_intro_screen.dart';
import 'ui/custom_assets.dart';
import 'ui/first_session_tips.dart';
import 'ui/game_audio.dart';
import 'ui/game_theme.dart';
import 'ui/hub_screen.dart';
import 'ui/is2_shell.dart';
import 'ui/kenney_button.dart';
import 'ui/loading_splash.dart';
import 'ui/menu_chrome.dart';
import 'ui/new_game_party_picker.dart';
import 'ui/play_update_required_screen.dart';
import 'ui/save_import_flow.dart';
import 'ui/shell/menu_surface.dart';
import 'ui/start_menu_screen.dart';
import 'ui/web_click_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class _MyAppState extends State<MyApp> {
  late final GameDirector _director;

  @override
  void initState() {
    super.initState();
    // Stable for the app lifetime — never recreate on MaterialApp rebuilds.
    _director = widget.director ?? GameDirector.persistent();
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

class _GameHomePageState extends State<GameHomePage> with WidgetsBindingObserver {
  GameDirector get _director => widget.director;

  /// One owner of "which menu is open", shared by hub and dungeon.
  final MenuRouter _router = MenuRouter();
  _AppPhase _phase = _AppPhase.loading;
  bool _playUpdateTapBusy = false;

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
    if (state != AppLifecycleState.resumed) return;
    if (_phase != _AppPhase.playUpdateRequired) return;
    unawaited(_recheckMandatoryPlayUpdate());
  }

  Future<void> _bootstrap() async {
    unawaited(EquipmentFactory.loadAffixes());
    unawaited(DropTables.load());
    // Defer combat loop until after start menu so dungeon ticks cannot steal focus.
    await _director.boot(deferCombatLoop: widget.showIntro);
    GameAudio.muted = _director.state.soundMuted;
    if (kIsWeb) {
      WebClickBridge.bindSpeedControls(
        getSpeed: () => _director.debugTimeScale,
        setSpeed: _director.setDebugTimeScale,
      );
    }
    if (!mounted) return;

    final blocked = await _director.checkMandatoryPlayUpdate();
    if (!mounted) return;
    if (blocked) {
      setState(() => _phase = _AppPhase.playUpdateRequired);
      return;
    }

    _enterAfterBootChecks();
    unawaited(_precacheScenes());
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
    if (_phase != _AppPhase.startMenu) return;
    _director.continueGame();
    setState(() => _phase = _AppPhase.play);
    _director.ensureCombatLoop();
  }

  void _openNewGamePicker() {
    if (_phase != _AppPhase.startMenu) return;
    setState(() => _phase = _AppPhase.newGamePicker);
  }

  Future<void> _restoreSave() async {
    if (_phase != _AppPhase.startMenu) return;
    final ok = await SaveImportFlow.fromClipboard(
      context: context,
      director: _director,
    );
    if (!ok || !mounted) return;
    _continueGame();
  }

  Future<void> _confirmNewGame(List<HeroSpecId> specs, String partyName) async {
    if (_director.hasExistingSave) {
      WebClickBridge.pushLayer();
      bool? ok;
      try {
        ok = await showDialog<bool>(
          context: context,
          barrierColor: MenuChrome.scrim,
          builder: (ctx) => MenuChrome.dialog(
            title: 'Overwrite save?',
            content: Text(
              'Starting a new game erases your current progress.',
              style: GameTheme.body(size: 15, color: GameTheme.parchment),
            ),
            actions: [
              KenneyButton(
                label: 'CANCEL',
                style: KenneyButtonStyle.grey,
                expanded: false,
                onPressed: () => Navigator.pop(ctx, false),
              ),
              KenneyButton(
                label: 'OVERWRITE',
                expanded: false,
                style: KenneyButtonStyle.red,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
      } finally {
        WebClickBridge.popLayer();
      }
      if (ok != true || !mounted) {
        setState(() => _phase = _AppPhase.startMenu);
        return;
      }
    }
    await _director.startNewGame(specs, partyName: partyName);
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
          onFinished: () {
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
          canContinue: _director.hasExistingSave,
          saveSummary: _director.hasExistingSave
              ? '${_director.state.partyName} · ${DungeonCatalog.byId(_director.state.dungeonId).name}'
              : null,
          onContinue: _continueGame,
          onNewGame: _openNewGamePicker,
          onRestore: _restoreSave,
        ),
      );
    }

    if (_phase == _AppPhase.newGamePicker) {
      return NewGamePartyPicker(
        key: const ValueKey('new-game-picker'),
        onBack: () => setState(() => _phase = _AppPhase.startMenu),
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

        final Widget body;
        if (_director.state.inDungeon) {
          body = Is2Shell(
            director: _director,
            router: _router,
            pulse: 0.5,
            onLeaveDungeon: _director.leaveDungeon,
          );
        } else {
          body = ListenableBuilder(
            listenable: _router,
            builder: (context, _) => Stack(
              children: [
                IgnorePointer(
                  ignoring: _router.isOpen,
                  child: HubScreen(
                    director: _director,
                    router: _router,
                    onEnterDungeon: (id) {
                      _router.close();
                      _director.enterDungeon(dungeonId: id);
                    },
                  ),
                ),
                if (!_router.isOpen) FirstSessionTips(director: _director),
                MenuSurface(director: _director, router: _router),
              ],
            ),
          );
        }

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
