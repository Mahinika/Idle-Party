import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/game_director.dart';
import 'core/game_logic.dart';
import 'core/game_state.dart';
import 'models/enemy.dart';
import 'models/hero.dart';
import 'models/loot.dart';
import 'ui/kenney_assets.dart';
import 'ui/kenney_bar.dart';
import 'ui/kenney_button.dart';
import 'ui/kenney_panel.dart';
import 'ui/kenney_sprite.dart';

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
          bodyColor: const Color(0xFFE6DFC8),
          displayColor: const Color(0xFFF4E6AE),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB7A15E),
          secondary: Color(0xFF6B7450),
          surface: Color(0xFF18160F),
        ),
        scaffoldBackgroundColor: const Color(0xFF090805),
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

class _GameHomePageState extends State<GameHomePage>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _pulseController;
  bool _showLootLedger = true;
  bool _showForgeDrawer = false;

  GameDirector get _director => widget.director;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _director.boot();
    if (!mounted) {
      return;
    }

    if (widget.autoStartLoop) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _director.tick();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _director.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_director, _pulseController]),
      builder: (context, _) {
        final state = _director.state;
        final pulse = Curves.easeInOut.transform(_pulseController.value);

        return Scaffold(
          body: Stack(
            children: [
              const _DungeonBackdrop(),
              SafeArea(
                child: _director.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          10,
                          10,
                          10,
                          MediaQuery.of(context).padding.bottom + 18,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1080),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _CabinetHeader(state: state),
                                const SizedBox(height: 10),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final wide = constraints.maxWidth >= 900;
                                    if (wide) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _GameCabinet(
                                              state: state,
                                              pulse: pulse,
                                              onTrainParty:
                                                  _director.applyTraining,
                                              onUpgradeAttack:
                                                  _director.upgradeAttack,
                                              onUpgradeDefense:
                                                  _director.upgradeDefense,
                                              onUpgradeVitality:
                                                  _director.upgradeVitality,
                                              onUnlockRelic:
                                                  _director.unlockRelic,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 224,
                                            child: _ControlRail(
                                              state: state,
                                              showLootLedger: _showLootLedger,
                                              showForgeDrawer: _showForgeDrawer,
                                              onToggleLoot: () {
                                                setState(() {
                                                  _showLootLedger =
                                                      !_showLootLedger;
                                                });
                                              },
                                              onToggleForge: () {
                                                setState(() {
                                                  _showForgeDrawer =
                                                      !_showForgeDrawer;
                                                });
                                              },
                                              onAdvanceTick: _director.tick,
                                              onRevive: _director.reviveParty,
                                              onReset: () async {
                                                await _director.reset();
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _GameCabinet(
                                          state: state,
                                          pulse: pulse,
                                          onTrainParty: _director.applyTraining,
                                          onUpgradeAttack:
                                              _director.upgradeAttack,
                                          onUpgradeDefense:
                                              _director.upgradeDefense,
                                          onUpgradeVitality:
                                              _director.upgradeVitality,
                                          onUnlockRelic: _director.unlockRelic,
                                        ),
                                        const SizedBox(height: 10),
                                        _ControlRail(
                                          state: state,
                                          showLootLedger: _showLootLedger,
                                          showForgeDrawer: _showForgeDrawer,
                                          onToggleLoot: () {
                                            setState(() {
                                              _showLootLedger =
                                                  !_showLootLedger;
                                            });
                                          },
                                          onToggleForge: () {
                                            setState(() {
                                              _showForgeDrawer =
                                                  !_showForgeDrawer;
                                            });
                                          },
                                          onAdvanceTick: _director.tick,
                                          onRevive: _director.reviveParty,
                                          onReset: () async {
                                            await _director.reset();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if (_showLootLedger) ...[
                                  const SizedBox(height: 10),
                                  _LootLedgerPanel(state: state),
                                ],
                                if (_showForgeDrawer) ...[
                                  const SizedBox(height: 10),
                                  _ForgeDrawerPanel(
                                    state: state,
                                    onTrainParty: _director.applyTraining,
                                    onUpgradeAttack: _director.upgradeAttack,
                                    onUpgradeDefense: _director.upgradeDefense,
                                    onUpgradeVitality:
                                        _director.upgradeVitality,
                                    onUnlockRelic: _director.unlockRelic,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CabinetHeader extends StatelessWidget {
  const _CabinetHeader({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return KenneyPanel(
      padding: const EdgeInsets.all(12),
      style: KenneyPanelStyle.beige,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
            child: Row(
              children: [
                KenneySprite(
                  asset: KenneyAssets.heroKnight,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IDLE PARTY',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 18,
                          color: const Color(0xFFFFEDB5),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Dungeon lane - hero deck - inventory grind',
                        style: TextStyle(
                          fontSize: 20,
                          color: Color(0xFFD8D1B2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _HeaderChip(
            label: 'Gold',
            value: state.gold.toString(),
            icon: KenneyAssets.iconCoin,
          ),
          _HeaderChip(
            label: 'Battle',
            value: state.battleNumber.toString(),
            icon: KenneyAssets.iconSword,
          ),
          _HeaderChip(
            label: 'Essence',
            value: state.essence.toString(),
            icon: KenneyAssets.potionBlue,
          ),
          _HeaderChip(
            label: 'Bosses',
            value: state.bossVictories.toString(),
            icon: KenneyAssets.iconCrown,
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(KenneyAssets.hexagonBrown),
          fit: BoxFit.fill,
          centerSlice: const Rect.fromLTWH(8, 8, 16, 16),
          filterQuality: FilterQuality.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(asset: icon, size: 18),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: const Color(0xFFD9CA96),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFF1C8),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCabinet extends StatelessWidget {
  const _GameCabinet({
    required this.state,
    required this.pulse,
    required this.onTrainParty,
    required this.onUpgradeAttack,
    required this.onUpgradeDefense,
    required this.onUpgradeVitality,
    required this.onUnlockRelic,
  });

  final GameState state;
  final double pulse;
  final VoidCallback onTrainParty;
  final VoidCallback onUpgradeAttack;
  final VoidCallback onUpgradeDefense;
  final VoidCallback onUpgradeVitality;
  final void Function(String relicId) onUnlockRelic;

  @override
  Widget build(BuildContext context) {
    return KenneyPanel(
      padding: const EdgeInsets.all(10),
      style: KenneyPanelStyle.brown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SurfaceStatusRow(state: state),
          const SizedBox(height: 8),
          _BattleStage(state: state, pulse: pulse),
          const SizedBox(height: 8),
          _HeroDeck(state: state),
          const SizedBox(height: 8),
          _InventoryBoard(
            state: state,
            onTrainParty: onTrainParty,
            onUpgradeAttack: onUpgradeAttack,
            onUpgradeDefense: onUpgradeDefense,
            onUpgradeVitality: onUpgradeVitality,
            onUnlockRelic: onUnlockRelic,
          ),
        ],
      ),
    );
  }
}

class _SurfaceStatusRow extends StatelessWidget {
  const _SurfaceStatusRow({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final enemy = state.enemy;
    final bossLive = GameLogic.isBossBattle(state.battleNumber);
    final nextBossBattle = ((state.battleNumber - 1) ~/ 10 + 1) * 10;
    final wavesLeft = nextBossBattle - state.battleNumber;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        _SurfaceTag(
          label: 'Zone',
          value: bossLive ? 'Boss Room' : 'Stone Passage',
          accent: const Color(0xFF8E9A66),
        ),
        _SurfaceTag(
          label: 'Target',
          value: enemy.name,
          accent: const Color(0xFFB97B62),
        ),
        _SurfaceTag(
          label: 'Objective',
          value: bossLive ? 'Clear the Warden' : '$wavesLeft to boss',
          accent: const Color(0xFFB6A15F),
        ),
      ],
    );
  }
}

class _SurfaceTag extends StatelessWidget {
  const _SurfaceTag({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF17150F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: GoogleFonts.pressStart2p(fontSize: 8, color: accent),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 20, color: Color(0xFFF4ECC7)),
          ),
        ],
      ),
    );
  }
}

class _PixelPanel extends StatelessWidget {
  const _PixelPanel({
    required this.child,
    required this.padding,
    this.style = KenneyPanelStyle.brown,
  });

  final Widget child;
  final EdgeInsets padding;
  final KenneyPanelStyle style;

  @override
  Widget build(BuildContext context) {
    return KenneyPanel(padding: padding, style: style, child: child);
  }
}

class _BattleStage extends StatefulWidget {
  const _BattleStage({required this.state, required this.pulse});

  final GameState state;
  final double pulse;

  @override
  State<_BattleStage> createState() => _BattleStageState();
}

class _BattleStageState extends State<_BattleStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hitController;

  @override
  void initState() {
    super.initState();
    _hitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didUpdateWidget(covariant _BattleStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final enemyDamaged =
        oldWidget.state.enemy.currentHp > widget.state.enemy.currentHp;
    final battleAdvanced =
        oldWidget.state.battleNumber != widget.state.battleNumber;
    if (enemyDamaged || battleAdvanced) {
      _hitController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enemy = widget.state.enemy;
    final hpFraction = enemy.currentHp / enemy.maxHp;
    final hitPulse = Curves.easeOut.transform(_hitController.value);
    final bossLive = GameLogic.isBossBattle(enemy.level);
    final floorNumber = _floorForBattle(widget.state.battleNumber);
    final roomNumber = _roomForBattle(widget.state.battleNumber);
    final roomData = _roomMarkersForFloor();
    final currentRoom = roomData[roomNumber - 1];

    return Container(
      height: 352,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: bossLive ? const Color(0xFFB89B55) : const Color(0xFF707C57),
          width: 1.4,
        ),
        image: DecorationImage(
          image: AssetImage(KenneyAssets.floorStone),
          repeat: ImageRepeat.repeat,
          fit: BoxFit.none,
          scale: 0.5,
          filterQuality: FilterQuality.none,
          opacity: 0.35,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF786A46), Color(0xFF4F5436), Color(0xFF1B190F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFE5D29A).withValues(alpha: 0.28),
                    Colors.transparent,
                    const Color(0xFF000000).withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: _SceneBadge(
              label: 'FLOOR $floorNumber',
              accent: bossLive
                  ? const Color(0xFFE9C873)
                  : const Color(0xFFC9D59B),
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: _SceneBadge(
              label: bossLive ? 'BOSS ROOM' : 'ROOM $roomNumber/10',
              accent: const Color(0xFFFFE2A3),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 80),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final roomSize = constraints.maxWidth < 700 ? 58.0 : 72.0;
                  final heroOffsets = <Offset>[
                    const Offset(-26, -10),
                    const Offset(0, 18),
                    const Offset(26, -10),
                  ];
                  final heroCenter = Offset(
                    currentRoom.position.dx * constraints.maxWidth,
                    currentRoom.position.dy * constraints.maxHeight,
                  );

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(KenneyAssets.floorDirt),
                              repeat: ImageRepeat.repeat,
                              fit: BoxFit.none,
                              scale: 0.5,
                              filterQuality: FilterQuality.none,
                              opacity: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF524B32),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < roomData.length - 1; i++)
                        _DungeonCorridorSegment(
                          start: roomData[i].position,
                          end: roomData[i + 1].position,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          isActive: i < roomNumber - 1,
                        ),
                      for (final room in roomData)
                        _DungeonRoomNode(
                          data: room,
                          roomSize: roomSize,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          isCleared: room.roomIndex < roomNumber,
                          isCurrent: room.roomIndex == roomNumber,
                          isBossRoom: room.roomIndex == roomData.length,
                        ),
                      Positioned(
                        left: 0,
                        top: 6,
                        child: _FloorTower(currentFloor: floorNumber),
                      ),
                      Positioned(
                        right: 0,
                        top: 8,
                        child: _CurrentRoomCard(
                          floorNumber: floorNumber,
                          roomNumber: roomNumber,
                          roomTitle: currentRoom.title,
                        ),
                      ),
                      for (var i = 0; i < widget.state.heroes.length; i++)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeInOut,
                          left: heroCenter.dx + heroOffsets[i].dx - 14,
                          top: heroCenter.dy + heroOffsets[i].dy - 14,
                          child: _TopDownHeroToken(
                            pulse: widget.pulse,
                            heroIndex: i,
                            isDimmed: !widget.state.heroes[i].isAlive,
                          ),
                        ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        left: heroCenter.dx - 18,
                        top: heroCenter.dy - 54 - (bossLive ? 10 : 0),
                        child: _TopDownEnemyToken(
                          enemy: enemy,
                          pulse: widget.pulse,
                          hitPulse: hitPulse,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xE011100B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF5B5336)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FLOOR $floorNumber - ${currentRoom.title.toUpperCase()}',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: const Color(0xFFFFE8AA),
                          ),
                        ),
                      ),
                      Text(
                        '${enemy.name} HP ${enemy.currentHp}/${enemy.maxHp}',
                        style: const TextStyle(fontSize: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  KenneyProgressBar(
                    height: 12,
                    value: hpFraction,
                    color: bossLive
                        ? KenneyBarColor.yellow
                        : KenneyBarColor.green,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Team attack ${widget.state.totalAttack} - reward ${enemy.rewardGold}g',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: hitPulse > 0.05 ? 1 : 0,
                        duration: const Duration(milliseconds: 80),
                        child: Text(
                          hitPulse > 0.2 ? 'HIT!' : ' ',
                          style: GoogleFonts.pressStart2p(
                            fontSize: 10,
                            color: const Color(0xFFFFE17D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DungeonCorridorSegment extends StatelessWidget {
  const _DungeonCorridorSegment({
    required this.start,
    required this.end,
    required this.width,
    required this.height,
    required this.isActive,
  });

  final Offset start;
  final Offset end;
  final double width;
  final double height;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final startPx = Offset(start.dx * width, start.dy * height);
    final endPx = Offset(end.dx * width, end.dy * height);
    final left = startPx.dx < endPx.dx ? startPx.dx : endPx.dx;
    final top = startPx.dy < endPx.dy ? startPx.dy : endPx.dy;
    final segmentWidth = (startPx.dx - endPx.dx)
        .abs()
        .clamp(10, double.infinity)
        .toDouble();
    final segmentHeight = (startPx.dy - endPx.dy)
        .abs()
        .clamp(10, double.infinity)
        .toDouble();
    final isHorizontal = segmentWidth > segmentHeight;

    return Positioned(
      left: left + (isHorizontal ? 0 : -5),
      top: top + (isHorizontal ? -5 : 0),
      child: KenneySprite(
        asset: isActive
            ? KenneyAssets.corridorActive
            : KenneyAssets.corridorInactive,
        width: isHorizontal ? segmentWidth : 10,
        height: isHorizontal ? 10 : segmentHeight,
        fit: BoxFit.fill,
      ),
    );
  }
}

class _SceneBadge extends StatelessWidget {
  const _SceneBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD413120D),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent),
      ),
      child: Text(
        label,
        style: GoogleFonts.pressStart2p(fontSize: 8, color: accent),
      ),
    );
  }
}

class _DungeonRoomNode extends StatelessWidget {
  const _DungeonRoomNode({
    required this.data,
    required this.roomSize,
    required this.width,
    required this.height,
    required this.isCleared,
    required this.isCurrent,
    required this.isBossRoom,
  });

  final _DungeonRoomMarkerData data;
  final double roomSize;
  final double width;
  final double height;
  final bool isCleared;
  final bool isCurrent;
  final bool isBossRoom;

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? roomSize + 8 : roomSize;
    final center = Offset(data.position.dx * width, data.position.dy * height);
    final border = isBossRoom
        ? const Color(0xFFE6C46B)
        : isCurrent
        ? const Color(0xFFC9D59B)
        : const Color(0xFF7A6D46);

    final roomAsset = isBossRoom
        ? KenneyAssets.stairsBoss
        : isCleared
        ? KenneyAssets.roomCleared
        : isCurrent
        ? KenneyAssets.doorOpen
        : KenneyAssets.doorClosed;

    return Positioned(
      left: center.dx - (size / 2),
      top: center.dy - (size / 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isCleared ? const Color(0x884A5533) : const Color(0x88262218),
          borderRadius: BorderRadius.circular(isBossRoom ? 24 : 12),
          border: Border.all(color: border, width: isCurrent ? 2.2 : 1.4),
          boxShadow: isCurrent
              ? const [
                  BoxShadow(
                    color: Color(0x55E5D29A),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KenneySprite(asset: roomAsset, size: isCurrent ? 28 : 24),
            const SizedBox(height: 2),
            Text(
              'R${data.roomIndex}',
              style: GoogleFonts.pressStart2p(
                fontSize: 7,
                color: const Color(0xFFF4EBC9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorTower extends StatelessWidget {
  const _FloorTower({required this.currentFloor});

  final int currentFloor;

  @override
  Widget build(BuildContext context) {
    final floors = <int>[
      if (currentFloor > 1) currentFloor - 1,
      currentFloor,
      currentFloor + 1,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: floors
          .map(
            (floor) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: floor == currentFloor
                    ? const Color(0xFF332D1D)
                    : const Color(0xCC17140E),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: floor == currentFloor
                      ? const Color(0xFFE4D08E)
                      : const Color(0xFF62573A),
                ),
              ),
              child: Text(
                'F$floor',
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: floor == currentFloor
                      ? const Color(0xFFFFE9AA)
                      : const Color(0xFFB6AA80),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CurrentRoomCard extends StatelessWidget {
  const _CurrentRoomCard({
    required this.floorNumber,
    required this.roomNumber,
    required this.roomTitle,
  });

  final int floorNumber;
  final int roomNumber;
  final String roomTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD613120D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6D6242)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'FLOOR $floorNumber',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: const Color(0xFFFFE39A),
            ),
          ),
          const SizedBox(height: 4),
          Text('Room $roomNumber', style: const TextStyle(fontSize: 19)),
          Text(
            roomTitle,
            style: const TextStyle(fontSize: 17, color: Color(0xFFD7CAA0)),
          ),
        ],
      ),
    );
  }
}

class _TopDownHeroToken extends StatelessWidget {
  const _TopDownHeroToken({
    required this.pulse,
    required this.heroIndex,
    required this.isDimmed,
  });

  final double pulse;
  final int heroIndex;
  final bool isDimmed;

  @override
  Widget build(BuildContext context) {
    final bob = lerpDouble(-2, 2, pulse) ?? 0;

    return Opacity(
      opacity: isDimmed ? 0.45 : 1,
      child: Transform.translate(
        offset: Offset(0, bob),
        child: KenneySprite(
          asset: KenneyAssets.heroSpriteFor(heroIndex),
          size: 32,
        ),
      ),
    );
  }
}

class _TopDownEnemyToken extends StatelessWidget {
  const _TopDownEnemyToken({
    required this.enemy,
    required this.pulse,
    required this.hitPulse,
  });

  final EnemyUnit enemy;
  final double pulse;
  final double hitPulse;

  @override
  Widget build(BuildContext context) {
    final scale = lerpDouble(1, 1.06, pulse) ?? 1;
    final shift = (hitPulse * 8) * (pulse > 0.5 ? -1 : 1);
    final bossLive = GameLogic.isBossBattle(enemy.level);

    return Transform.translate(
      offset: Offset(shift, 0),
      child: Transform.scale(
        scale: scale - (hitPulse * 0.08),
        child: KenneySprite(
          asset: KenneyAssets.enemySpriteFor(enemy),
          size: bossLive ? 40 : 32,
        ),
      ),
    );
  }
}

class _HeroDeck extends StatelessWidget {
  const _HeroDeck({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final frontliners = state.heroes.take(2).toList();
    final reserve = state.heroes.skip(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'HERO PANELS',
              style: GoogleFonts.pressStart2p(
                fontSize: 10,
                color: const Color(0xFFFFE7A7),
              ),
            ),
            const Spacer(),
            Text(
              '${state.aliveHeroes}/${state.heroes.length} alive',
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 680;
            if (stacked) {
              return Column(
                children: [
                  for (var i = 0; i < frontliners.length; i++) ...[
                    _HeroPanel(
                      hero: frontliners[i],
                      state: state,
                      title: _roleLabelFor(i),
                      heroIndex: i,
                    ),
                    if (i != frontliners.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            }

            return Row(
              children: [
                for (var i = 0; i < frontliners.length; i++) ...[
                  Expanded(
                    child: _HeroPanel(
                      hero: frontliners[i],
                      state: state,
                      title: _roleLabelFor(i),
                      heroIndex: i,
                    ),
                  ),
                  if (i != frontliners.length - 1) const SizedBox(width: 8),
                ],
              ],
            );
          },
        ),
        if (reserve.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF15130D),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF5E5436)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: reserve
                  .asMap()
                  .entries
                  .map(
                    (entry) => Text(
                      'RESERVE ${_roleLabelFor(entry.key + 2)} - ${entry.value.name} Lv ${entry.value.level}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.hero,
    required this.state,
    required this.title,
    required this.heroIndex,
  });

  final PartyHero hero;
  final GameState state;
  final String title;
  final int heroIndex;

  @override
  Widget build(BuildContext context) {
    final maxHp = state.effectiveHeroMaxHp(hero);
    final attack = state.effectiveHeroAttack(hero);
    final defense = state.effectiveHeroDefense(hero);
    final hpFraction = maxHp == 0 ? 0.0 : hero.currentHp / maxHp;
    final barColor = hpFraction <= 0.25
        ? KenneyBarColor.red
        : hpFraction <= 0.5
        ? KenneyBarColor.yellow
        : KenneyBarColor.green;

    return KenneyPanel(
      padding: const EdgeInsets.all(10),
      style: KenneyPanelStyle.inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(
                asset: KenneyAssets.heroPortraitFor(heroIndex),
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 9,
                        color: const Color(0xFFFFEAAE),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hero.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text('Lv ${hero.level}', style: const TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: 'ATK', value: attack.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(label: 'DEF', value: defense.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'HP',
                  value: '${hero.currentHp}/$maxHp',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          KenneyProgressBar(
            height: 10,
            value: hpFraction,
            color: barColor,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF211D13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF5F5537)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: const Color(0xFFD7C88F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InventoryBoard extends StatelessWidget {
  const _InventoryBoard({
    required this.state,
    required this.onTrainParty,
    required this.onUpgradeAttack,
    required this.onUpgradeDefense,
    required this.onUpgradeVitality,
    required this.onUnlockRelic,
  });

  final GameState state;
  final VoidCallback onTrainParty;
  final VoidCallback onUpgradeAttack;
  final VoidCallback onUpgradeDefense;
  final VoidCallback onUpgradeVitality;
  final void Function(String relicId) onUnlockRelic;

  @override
  Widget build(BuildContext context) {
    final trainingCost = GameLogic.partyTrainingCostFor(state);
    final attackCost = GameLogic.upgradeCostFor(state, PartyUpgradeType.attack);
    final defenseCost = GameLogic.upgradeCostFor(
      state,
      PartyUpgradeType.defense,
    );
    final vitalityCost = GameLogic.upgradeCostFor(
      state,
      PartyUpgradeType.vitality,
    );
    final tiles = <Widget>[
      _InventoryStatTile(
        title: 'Gold',
        value: state.gold.toString(),
        subtitle: 'Run currency',
        icon: KenneyAssets.iconCoin,
      ),
      _InventoryStatTile(
        title: 'Essence',
        value: state.essence.toString(),
        subtitle: 'Relic fuel',
        icon: KenneyAssets.potionBlue,
      ),
      _InventoryStatTile(
        title: 'Battle',
        value: state.battleNumber.toString(),
        subtitle: 'Current wave',
        icon: KenneyAssets.iconSword,
      ),
      _InventoryStatTile(
        title: 'Bosses',
        value: state.bossVictories.toString(),
        subtitle: 'Clears',
        icon: KenneyAssets.iconCrown,
      ),
      _InventoryActionTile(
        title: 'TRAIN PARTY',
        body: 'Raise every hero by 1 level for $trainingCost gold.',
        buttonLabel: 'Train $trainingCost',
        onPressed: state.gold >= trainingCost ? onTrainParty : null,
      ),
      _InventoryActionTile(
        title: 'ATTACK FORGE',
        body: 'Sharpen the team weapon line. Permanent +2 attack.',
        buttonLabel: 'Forge $attackCost',
        onPressed: state.gold >= attackCost ? onUpgradeAttack : null,
      ),
      _InventoryActionTile(
        title: 'DEFENSE FORGE',
        body: 'Reinforce the party guard line. Permanent +1 defense.',
        buttonLabel: 'Forge $defenseCost',
        onPressed: state.gold >= defenseCost ? onUpgradeDefense : null,
      ),
      _InventoryActionTile(
        title: 'VITALITY FORGE',
        body: 'Increase every hero max HP by 6 and fully refill them.',
        buttonLabel: 'Forge $vitalityCost',
        onPressed: state.gold >= vitalityCost ? onUpgradeVitality : null,
      ),
      ...GameLogic.relicOrder.map(
        (relicId) => _RelicInventoryTile(
          relicId: relicId,
          state: state,
          onUnlockRelic: onUnlockRelic,
        ),
      ),
      ...state.recentLoot.map((drop) => _LootInventoryTile(drop: drop)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'INVENTORY BOARD',
          style: GoogleFonts.pressStart2p(
            fontSize: 10,
            color: const Color(0xFFFFE8AA),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 860
                ? 4
                : constraints.maxWidth >= 620
                ? 3
                : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: constraints.maxWidth >= 620 ? 1.18 : 1.0,
              children: tiles,
            );
          },
        ),
      ],
    );
  }
}

class _InventoryCellFrame extends StatelessWidget {
  const _InventoryCellFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KenneyPanel(
      padding: const EdgeInsets.all(10),
      style: KenneyPanelStyle.border,
      child: child,
    );
  }
}

class _InventoryStatTile extends StatelessWidget {
  const _InventoryStatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return _InventoryCellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(asset: icon, size: 22),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.pressStart2p(
                    fontSize: 9,
                    color: const Color(0xFFE1D29A),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFF3CF),
            ),
          ),
          Text(subtitle, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

class _InventoryActionTile extends StatelessWidget {
  const _InventoryActionTile({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _InventoryCellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(asset: KenneyAssets.forgeIconFor(title), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 9,
                    color: const Color(0xFFFFE7A7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: Text(body, style: const TextStyle(fontSize: 18))),
          const SizedBox(height: 8),
          KenneyButton(
            label: buttonLabel,
            onPressed: onPressed,
            style: KenneyButtonStyle.brown,
          ),
        ],
      ),
    );
  }
}

class _RelicInventoryTile extends StatelessWidget {
  const _RelicInventoryTile({
    required this.relicId,
    required this.state,
    required this.onUnlockRelic,
  });

  final String relicId;
  final GameState state;
  final void Function(String relicId) onUnlockRelic;

  @override
  Widget build(BuildContext context) {
    final unlocked = state.hasRelic(relicId);
    final cost = GameLogic.relicCosts[relicId]!;

    return _InventoryCellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(
                asset: KenneyAssets.relicIconFor(relicId),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  GameLogic.relicNames[relicId]!.toUpperCase(),
                  style: GoogleFonts.pressStart2p(
                    fontSize: 9,
                    color: unlocked
                        ? const Color(0xFFBDE1A2)
                        : const Color(0xFFD6CAA2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              GameLogic.relicDescriptions[relicId]!,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          unlocked
              ? KenneyButton(
                  label: 'UNLOCKED',
                  onPressed: null,
                  style: KenneyButtonStyle.grey,
                )
              : KenneyButton(
                  label: 'Forge $cost',
                  onPressed: state.essence >= cost
                      ? () => onUnlockRelic(relicId)
                      : null,
                  style: KenneyButtonStyle.brown,
                ),
        ],
      ),
    );
  }
}

class _LootInventoryTile extends StatelessWidget {
  const _LootInventoryTile({required this.drop});

  final LootDrop drop;

  @override
  Widget build(BuildContext context) {
    final accent = switch (drop.rarity) {
      LootRarity.common => const Color(0xFFB9B7A0),
      LootRarity.uncommon => const Color(0xFFB7D98A),
      LootRarity.rare => const Color(0xFFA7D6ED),
      LootRarity.epic => const Color(0xFFF2C96F),
    };

    return _InventoryCellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(
                asset: KenneyAssets.lootIconFor(drop.rarity),
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                GameLogic.rarityNames[drop.rarity]!.toUpperCase(),
                style: GoogleFonts.pressStart2p(
                  fontSize: 9,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            drop.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text('x${drop.amount}', style: const TextStyle(fontSize: 20)),
          Text(
            '+${GameLogic.lootEssenceValue(drop)} essence',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _ControlRail extends StatelessWidget {
  const _ControlRail({
    required this.state,
    required this.showLootLedger,
    required this.showForgeDrawer,
    required this.onToggleLoot,
    required this.onToggleForge,
    required this.onAdvanceTick,
    required this.onRevive,
    required this.onReset,
  });

  final GameState state;
  final bool showLootLedger;
  final bool showForgeDrawer;
  final VoidCallback onToggleLoot;
  final VoidCallback onToggleForge;
  final VoidCallback onAdvanceTick;
  final VoidCallback onRevive;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    return _PixelPanel(
      padding: const EdgeInsets.all(10),
      style: KenneyPanelStyle.brown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'UTILITY',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: const Color(0xFFFFE7A7),
            ),
          ),
          const SizedBox(height: 10),
          _RailButton(
            label: showLootLedger ? 'Hide Loot' : 'Toggle Loot',
            onPressed: onToggleLoot,
            filled: false,
          ),
          const SizedBox(height: 8),
          _RailButton(
            label: showForgeDrawer ? 'Hide Forge' : 'Toggle Forge',
            onPressed: onToggleForge,
            filled: false,
          ),
          const SizedBox(height: 8),
          _RailButton(
            label: state.isPartyDefeated ? 'Revive Party' : 'Advance 1 Tick',
            onPressed: state.isPartyDefeated ? onRevive : onAdvanceTick,
            filled: true,
          ),
          const SizedBox(height: 8),
          _RailButton(
            label: 'Reset Run',
            onPressed: () async => onReset(),
            filled: false,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF12110C),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF5C5638)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loot converts to essence automatically.'),
                SizedBox(height: 6),
                Text('Forge and relic details open below the main screen.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return KenneyButton(
      label: label,
      onPressed: onPressed,
      style: filled ? KenneyButtonStyle.red : KenneyButtonStyle.grey,
    );
  }
}

class _LootLedgerPanel extends StatelessWidget {
  const _LootLedgerPanel({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return _PixelPanel(
      padding: const EdgeInsets.all(12),
      style: KenneyPanelStyle.beige,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LOOT LEDGER',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: const Color(0xFFFFE8AA),
            ),
          ),
          const SizedBox(height: 8),
          if (state.recentLoot.isEmpty)
            const Text(
              'No drops shown yet. Clear the current enemy to populate the board.',
            )
          else
            ...state.recentLoot.map(
              (drop) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14120D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF595033)),
                  ),
                  child: Row(
                    children: [
                      KenneySprite(
                        asset: KenneyAssets.lootIconFor(drop.rarity),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${drop.name} - ${GameLogic.rarityNames[drop.rarity]}',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      Text(
                        'x${drop.amount}  +${GameLogic.lootEssenceValue(drop)}e',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ForgeDrawerPanel extends StatelessWidget {
  const _ForgeDrawerPanel({
    required this.state,
    required this.onTrainParty,
    required this.onUpgradeAttack,
    required this.onUpgradeDefense,
    required this.onUpgradeVitality,
    required this.onUnlockRelic,
  });

  final GameState state;
  final VoidCallback onTrainParty;
  final VoidCallback onUpgradeAttack;
  final VoidCallback onUpgradeDefense;
  final VoidCallback onUpgradeVitality;
  final void Function(String relicId) onUnlockRelic;

  @override
  Widget build(BuildContext context) {
    final trainingCost = GameLogic.partyTrainingCostFor(state);
    return _PixelPanel(
      padding: const EdgeInsets.all(12),
      style: KenneyPanelStyle.brown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FORGE DRAWER',
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: const Color(0xFFFFE8AA),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Train cost $trainingCost gold - Attack bonus ${state.totalAttackBonus} - Defense bonus ${state.totalDefenseBonus} - Vitality bonus ${state.totalVitalityBonus}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KenneyButton(
                label: 'Train $trainingCost',
                onPressed: state.gold >= trainingCost ? onTrainParty : null,
              ),
              KenneyButton(
                label:
                    'Attack ${GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)}',
                onPressed:
                    state.gold >=
                        GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)
                    ? onUpgradeAttack
                    : null,
              ),
              KenneyButton(
                label:
                    'Defense ${GameLogic.upgradeCostFor(state, PartyUpgradeType.defense)}',
                onPressed:
                    state.gold >=
                        GameLogic.upgradeCostFor(
                          state,
                          PartyUpgradeType.defense,
                        )
                    ? onUpgradeDefense
                    : null,
              ),
              KenneyButton(
                label:
                    'Vitality ${GameLogic.upgradeCostFor(state, PartyUpgradeType.vitality)}',
                onPressed:
                    state.gold >=
                        GameLogic.upgradeCostFor(
                          state,
                          PartyUpgradeType.vitality,
                        )
                    ? onUpgradeVitality
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GameLogic.relicOrder
                .map(
                  (relicId) => KenneyButton(
                    label:
                        '${GameLogic.relicNames[relicId]} ${GameLogic.relicCosts[relicId]}',
                    onPressed:
                        state.hasRelic(relicId) ||
                            state.essence < GameLogic.relicCosts[relicId]!
                        ? null
                        : () => onUnlockRelic(relicId),
                    style: KenneyButtonStyle.brown,
                    expanded: false,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DungeonBackdrop extends StatelessWidget {
  const _DungeonBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(KenneyAssets.wallStone),
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.none,
                  scale: 0.35,
                  filterQuality: FilterQuality.none,
                  opacity: 0.18,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF060503),
                    Color(0xFF14120B),
                    Color(0xFF262110),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(KenneyAssets.floorStone),
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.none,
                  scale: 0.4,
                  filterQuality: FilterQuality.none,
                  opacity: 0.12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DungeonRoomMarkerData {
  const _DungeonRoomMarkerData({
    required this.roomIndex,
    required this.title,
    required this.position,
  });

  final int roomIndex;
  final String title;
  final Offset position;
}

String _roleLabelFor(int index) {
  return switch (index) {
    0 => 'WARRIOR',
    1 => 'HEALER',
    2 => 'MAGE',
    _ => 'ROGUE',
  };
}

int _floorForBattle(int battleNumber) => ((battleNumber - 1) ~/ 10) + 1;

int _roomForBattle(int battleNumber) => ((battleNumber - 1) % 10) + 1;

List<_DungeonRoomMarkerData> _roomMarkersForFloor() {
  return const [
    _DungeonRoomMarkerData(
      roomIndex: 1,
      title: 'Entry Hall',
      position: Offset(0.20, 0.18),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 2,
      title: 'Watch Post',
      position: Offset(0.40, 0.18),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 3,
      title: 'Barracks',
      position: Offset(0.60, 0.18),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 4,
      title: 'Chapel',
      position: Offset(0.80, 0.18),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 5,
      title: 'Cross Hall',
      position: Offset(0.80, 0.42),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 6,
      title: 'Forge Walk',
      position: Offset(0.60, 0.42),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 7,
      title: 'Archive',
      position: Offset(0.40, 0.42),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 8,
      title: 'Vault Path',
      position: Offset(0.20, 0.42),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 9,
      title: 'Stairwell',
      position: Offset(0.20, 0.68),
    ),
    _DungeonRoomMarkerData(
      roomIndex: 10,
      title: 'Ascension Gate',
      position: Offset(0.54, 0.74),
    ),
  ];
}
