import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/equipment_factory.dart';
import 'core/game_director.dart';
import 'models/hero_spec.dart';
import 'ui/custom_assets.dart';
import 'ui/first_session_tips.dart';
import 'ui/game_audio.dart';
import 'ui/game_theme.dart';
import 'ui/hub_screen.dart';
import 'ui/is2_shell.dart';
import 'ui/kenney_button.dart';
import 'ui/kenney_sprite.dart';
import 'ui/menu_chrome.dart';
import 'ui/new_game_party_picker.dart';
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
      home: GameHomePage(
        key: const ValueKey('game-home'),
        director: _director,
        autoStartLoop: widget.autoStartLoop,
        showIntro: widget.showIntro,
      ),
    );
  }
}

enum _AppPhase { loading, startMenu, newGamePicker, play }

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

class _GameHomePageState extends State<GameHomePage> {
  GameDirector get _director => widget.director;
  Is2Overlay? _hubOverlay;
  _AppPhase _phase = _AppPhase.loading;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    unawaited(EquipmentFactory.loadAffixes());
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
    setState(() {
      _phase = widget.showIntro ? _AppPhase.startMenu : _AppPhase.play;
    });
    if (_phase == _AppPhase.play) {
      _director.ensureCombatLoop();
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

  Future<void> _confirmNewGame(List<HeroSpecId> specs) async {
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
    await _director.startNewGame(specs);
    if (!mounted) return;
    _director.clearPendingStartMenu();
    setState(() => _phase = _AppPhase.play);
    _director.ensureCombatLoop();
  }

  @override
  void dispose() {
    _director.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Intro is outside the director AnimatedBuilder so toast/combat notifies
    // cannot rebuild or accidentally dismiss the title card.
    if (_phase == _AppPhase.loading) {
      return Scaffold(
        backgroundColor: GameTheme.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: GameTheme.ink),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneySprite(asset: CustomAssets.introLogo, size: 96),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: GameTheme.torch.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_phase == _AppPhase.startMenu) {
      return Scaffold(
        body: StartMenuScreen(
          key: const ValueKey('start-menu'),
          canContinue: _director.hasExistingSave,
          onContinue: _continueGame,
          onNewGame: _openNewGamePicker,
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

        // Drop stale hub MORE overlays when combat starts (ENTER / Daily /
        // Gauntlet). Otherwise Codex/Guides can reopen on return to hub.
        if (_director.state.inDungeon && _hubOverlay != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_director.state.inDungeon && _hubOverlay != null) {
              setState(() => _hubOverlay = null);
            }
          });
        }

        final Widget body;
        if (_director.state.inDungeon) {
          body = Is2Shell(
            director: _director,
            pulse: 0.5,
            onLeaveDungeon: _director.leaveDungeon,
          );
        } else {
          body = Stack(
            children: [
              IgnorePointer(
                ignoring: _hubOverlay != null,
                child: HubScreen(
                  director: _director,
                  onEnterDungeon: (id) {
                    setState(() => _hubOverlay = null);
                    _director.enterDungeon(dungeonId: id);
                  },
                  onOpenParty: () {
                    _director.ackPendingHeroReveals();
                    setState(() => _hubOverlay = Is2Overlay.inventory);
                  },
                  onOpenPower: () => setState(
                    () => _hubOverlay = Is2Overlay.power,
                  ),
                  onOpenMeta: () => setState(
                    () => _hubOverlay = Is2Overlay.meta,
                  ),
                  onOpenSettings: () => setState(
                    () => _hubOverlay = Is2Overlay.settings,
                  ),
                ),
              ),
              if (_hubOverlay == null)
                FirstSessionTips(director: _director),
              if (_hubOverlay != null)
                Positioned.fill(
                  child: Material(
                    color: const Color(0xF20A0806),
                    child: Is2Shell(
                      key: const ValueKey('hub-meta-shell'),
                      director: _director,
                      pulse: 0.5,
                      hubMode: true,
                      initialOverlay: _hubOverlay!,
                      onLeaveDungeon: () => setState(
                        () => _hubOverlay = null,
                      ),
                    ),
                  ),
                ),
            ],
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
