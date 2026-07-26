import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/game_director.dart';
import 'ui/game_audio.dart';
import 'ui/game_theme.dart';
import 'ui/hub_screen.dart';
import 'ui/is2_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.director, this.autoStartLoop = true});

  final GameDirector? director;
  final bool autoStartLoop;

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
        director: director ?? GameDirector.persistent(),
        autoStartLoop: autoStartLoop,
      ),
    );
  }
}

class GameHomePage extends StatefulWidget {
  const GameHomePage({
    super.key,
    required this.director,
    required this.autoStartLoop,
  });

  final GameDirector director;
  final bool autoStartLoop;

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage> {
  GameDirector get _director => widget.director;
  Is2Overlay? _hubOverlay;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _director.boot();
    GameAudio.muted = _director.state.soundMuted;
  }

  @override
  void dispose() {
    _director.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _director,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: _director.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _director.state.inDungeon
                    ? Is2Shell(
                        director: _director,
                        pulse: 0.5,
                        onLeaveDungeon: _director.leaveDungeon,
                      )
                    : Stack(
                        children: [
                          HubScreen(
                            director: _director,
                            onEnterDungeon: (id) =>
                                _director.enterDungeon(dungeonId: id),
                            onOpenInventory: () => setState(
                              () => _hubOverlay = Is2Overlay.inventory,
                            ),
                            onOpenForge: () => setState(
                              () => _hubOverlay = Is2Overlay.forge,
                            ),
                            onOpenJobs: () => setState(
                              () => _hubOverlay = Is2Overlay.jobs,
                            ),
                            onOpenSanctuary: () => setState(
                              () => _hubOverlay = Is2Overlay.sanctuary,
                            ),
                            onOpenMarket: () => setState(
                              () => _hubOverlay = Is2Overlay.market,
                            ),
                            onOpenBeast: () => setState(
                              () => _hubOverlay = Is2Overlay.beast,
                            ),
                            onOpenSettings: () => setState(
                              () => _hubOverlay = Is2Overlay.settings,
                            ),
                          ),
                          if (_hubOverlay != null)
                            Positioned.fill(
                              child: Material(
                                color: const Color(0xF20A0806),
                                child: Is2Shell(
                                  key: ValueKey(_hubOverlay),
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
                      ),
          ),
        );
      },
    );
  }
}
