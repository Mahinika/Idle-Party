import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/dungeon_generator.dart';
import 'core/game_director.dart';
import 'core/game_logic.dart';
import 'core/game_state.dart';
import 'models/dungeon_mode.dart';
import 'models/dungeon_room.dart';
import 'models/enemy.dart';
import 'models/hero.dart';
import 'models/loot.dart';
import 'models/mission.dart';
import 'ui/is2_shell.dart';
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

// ════════════════════════════════════════════════════════════════════════════
// Game Home Page
// ════════════════════════════════════════════════════════════════════════════

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _director.boot();
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
          body: Stack(
            children: [
              const _DungeonBackdrop(),
              SafeArea(
                child: _director.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Is2Shell(
                        director: _director,
                        pulse: 0.5,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HUD Bar
// ════════════════════════════════════════════════════════════════════════════

class _HudBar extends StatelessWidget {
  const _HudBar({required this.state, required this.onReset});

  final GameState state;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 6 : 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xCC0D0B07),
        border: Border(bottom: BorderSide(color: Color(0xFF4E4526), width: 2)),
      ),
      child: isMobile && screenWidth < 400
          ? _buildCompactHudBar()
          : _buildStandardHudBar(),
    );
  }

  Widget _buildStandardHudBar() {
    return Row(
      children: [
        KenneySprite(asset: KenneyAssets.heroKnight, size: 28),
        const SizedBox(width: 8),
        Text(
          'IDLE PARTY',
          style: GoogleFonts.pressStart2p(
            fontSize: 11,
            color: const Color(0xFFFFEDB5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _HudChip(
          icon: KenneyAssets.iconCoin,
          value: state.gold.toString(),
          label: 'GOLD',
        ),
        const SizedBox(width: 12),
        _HudChip(
          icon: KenneyAssets.potionBlue,
          value: state.essence.toString(),
          label: 'ESS',
        ),
        const SizedBox(width: 12),
        _HudChip(
          icon: KenneyAssets.iconCrown,
          value: state.bossVictories.toString(),
          label: 'BOSS',
        ),
        const SizedBox(width: 12),
        _HudChip(
          icon: KenneyAssets.iconStar,
          value: state.ascensionLevel.toString(),
          label: 'AL',
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async => onReset(),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: KenneySprite(asset: KenneyAssets.iconSkull, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHudBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KenneySprite(asset: KenneyAssets.heroKnight, size: 24),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'IDLE PARTY',
                style: GoogleFonts.pressStart2p(
                  fontSize: 9,
                  color: const Color(0xFFFFEDB5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async => onReset(),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: KenneySprite(asset: KenneyAssets.iconSkull, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _HudChip(
              icon: KenneyAssets.iconCoin,
              value: state.gold.toString(),
              label: 'GOLD',
            ),
            _HudChip(
              icon: KenneyAssets.potionBlue,
              value: state.essence.toString(),
              label: 'ESS',
            ),
            _HudChip(
              icon: KenneyAssets.iconCrown,
              value: state.bossVictories.toString(),
              label: 'BOSS',
            ),
            _HudChip(
              icon: KenneyAssets.iconStar,
              value: state.ascensionLevel.toString(),
              label: 'AL',
            ),
          ],
        ),
      ],
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KenneySprite(asset: icon, size: isMobile ? 12 : 14),
        const SizedBox(width: 3),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.pressStart2p(
                fontSize: isMobile ? 5 : 6,
                color: const Color(0xFFB8A870),
                height: 1.0,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: const Color(0xFFFFF0C8),
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Side Battle Stage
// ════════════════════════════════════════════════════════════════════════════

class _SideBattleStage extends StatefulWidget {
  const _SideBattleStage({
    required this.state,
    required this.pulse,
    required this.onAdvanceTick,
    required this.onRevive,
    required this.onSetDungeonMode,
    required this.onTravelFloor,
  });

  final GameState state;
  final double pulse;
  final VoidCallback onAdvanceTick;
  final VoidCallback onRevive;
  final void Function(DungeonMode mode) onSetDungeonMode;
  final void Function(int floor) onTravelFloor;

  @override
  State<_SideBattleStage> createState() => _SideBattleStageState();
}

class _SideBattleStageState extends State<_SideBattleStage>
    with TickerProviderStateMixin {
  late final AnimationController _hitController;
  late final AnimationController _moveController;

  @override
  void initState() {
    super.initState();
    _hitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(covariant _SideBattleStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEnemyHp = oldWidget.state.enemies.fold<int>(
      0,
      (sum, e) => sum + e.currentHp,
    );
    final newEnemyHp = widget.state.enemies.fold<int>(
      0,
      (sum, e) => sum + e.currentHp,
    );
    final roomChanged =
        oldWidget.state.battleNumber != widget.state.battleNumber ||
        oldWidget.state.currentRoom.floorNumber !=
            widget.state.currentRoom.floorNumber;
    final enemyDamaged = !roomChanged && oldEnemyHp > newEnemyHp;

    if (enemyDamaged || roomChanged) {
      _hitController.forward(from: 0);
    }

    // Trigger movement animation when entering new room
    if (roomChanged) {
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hitController.dispose();
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_hitController, _moveController]),
      builder: (context, _) {
        final state = widget.state;
        final room = state.currentRoom;
        final isTreasureRoom = room.type == RoomType.treasure;
        final bossLive = room.type == RoomType.boss;
        final floorNumber = room.floorNumber;
        final roomNumber = room.roomIndex + 1;
        final zoneName = DungeonGenerator.zoneNameForFloor(floorNumber);
        final hitPulse = Curves.easeOut.transform(_hitController.value);
        final aliveEnemies = state.aliveEnemies;
        final roomGold = state.enemies.fold<int>(
          0,
          (sum, e) => sum + e.rewardGold,
        );

        return Container(
          height: 310,
          margin: const EdgeInsets.fromLTRB(6, 3, 6, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: bossLive
                  ? const Color(0xFFB89B55)
                  : const Color(0xFF606C48),
              width: 1.5,
            ),
            image: DecorationImage(
              image: AssetImage(KenneyAssets.floorStone),
              repeat: ImageRepeat.repeat,
              fit: BoxFit.none,
              scale: 0.5,
              filterQuality: FilterQuality.none,
              opacity: 0.18,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6E6040), Color(0xFF3A3D26), Color(0xFF141210)],
            ),
          ),
          child: Stack(
            children: [
              if (bossLive)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.85,
                        colors: [
                          const Color(0xFFE5C86A).withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                top: 6,
                child: _SceneBadge(
                  label: '$zoneName  ·  FLOOR $floorNumber',
                  accent: bossLive
                      ? const Color(0xFFE9C873)
                      : const Color(0xFFC9D59B),
                ),
              ),
              Positioned(
                right: 8,
                top: 6,
                child: _SceneBadge(
                  label: bossLive
                      ? 'BOSS ROOM'
                      : isTreasureRoom
                      ? 'TREASURE'
                      : 'ROOM $roomNumber / 10',
                  accent: const Color(0xFFFFE2A3),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 34,
                child: Row(
                  children: [
                    Expanded(
                      child: KenneyButton(
                        label: state.dungeonMode == DungeonMode.farm
                            ? 'FARM ✓'
                            : 'FARM',
                        onPressed: () =>
                            widget.onSetDungeonMode(DungeonMode.farm),
                        style: state.dungeonMode == DungeonMode.farm
                            ? KenneyButtonStyle.red
                            : KenneyButtonStyle.brown,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: KenneyButton(
                        label: state.dungeonMode == DungeonMode.push
                            ? 'PUSH ✓'
                            : 'PUSH',
                        onPressed: () =>
                            widget.onSetDungeonMode(DungeonMode.push),
                        style: state.dungeonMode == DungeonMode.push
                            ? KenneyButtonStyle.red
                            : KenneyButtonStyle.brown,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 44,
                      child: KenneyButton(
                        label: '◀',
                        onPressed: GameLogic.canTravelToFloor(
                              state,
                              floorNumber - 1,
                            )
                            ? () => widget.onTravelFloor(floorNumber - 1)
                            : null,
                        style: KenneyButtonStyle.brown,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 44,
                      child: KenneyButton(
                        label: '▶',
                        onPressed: GameLogic.canTravelToFloor(
                              state,
                              floorNumber + 1,
                            )
                            ? () => widget.onTravelFloor(floorNumber + 1)
                            : null,
                        style: KenneyButtonStyle.brown,
                      ),
                    ),
                  ],
                ),
              ),
              // Central enemy area (LARGE)
              Positioned(
                left: 0,
                right: 0,
                top: 78,
                bottom: 50,
                child: Stack(
                  children: [
                    // Movement transition effect
                    if (_moveController.value > 0)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 1.0 - _moveController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.width < 600
                            ? 100
                            : 120,
                        child: GestureDetector(
                          onTap: widget.onAdvanceTick,
                          child: isTreasureRoom
                              ? _TreasureChestView(pulse: widget.pulse)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (final enemy in state.enemies) ...[
                                      _SideEnemyView(
                                        enemy: enemy,
                                        pulse: widget.pulse,
                                        hitPulse: hitPulse,
                                        compact: state.enemies.length > 1,
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ),
                    // "Moving to next room" indicator
                    if (_moveController.value > 0.1)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Opacity(
                          opacity: ((1.0 - _moveController.value) * 2).clamp(
                            0.0,
                            1.0,
                          ),
                          child: Text(
                            '→ Moving to next room...',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.pressStart2p(
                              fontSize: 9,
                              color: const Color(0xFFFFD700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Heroes below enemy (smaller)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                height: 70,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _SideHeroGroup(
                    heroes: state.heroes,
                    state: state,
                    pulse: widget.pulse,
                    moveAnimation: _moveController.value,
                  ),
                ),
              ),
              // Bottom action bar
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Row(
                  children: [
                    SizedBox(
                      width: 190,
                      child: KenneyButton(
                        label: state.isPartyDefeated
                            ? 'REVIVE PARTY'
                            : 'Advance 1 Tick',
                        onPressed: state.isPartyDefeated
                            ? widget.onRevive
                            : widget.onAdvanceTick,
                        style: state.isPartyDefeated
                            ? KenneyButtonStyle.red
                            : KenneyButtonStyle.brown,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isTreasureRoom
                            ? 'Treasure chest ahead...'
                            : state.isPartyDefeated
                            ? (state.dungeonMode == DungeonMode.push &&
                                      state.currentRoom.floorNumber >
                                          state.highestFloorCleared
                                  ? 'Push failed — retreating...'
                                  : 'Party down — restarting floor...')
                            : '${aliveEnemies.length}x foes  +${roomGold}g',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFD9CBB0),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: hitPulse > 0.05 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 80),
                      child: Text(
                        'HIT!',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 8,
                          color: const Color(0xFFFFE17D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SideHeroGroup extends StatelessWidget {
  const _SideHeroGroup({
    required this.heroes,
    required this.state,
    required this.pulse,
    required this.moveAnimation,
  });

  final List<PartyHero> heroes;
  final GameState state;
  final double pulse;
  final double moveAnimation;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final walkSway = (pulse - 0.5) * 8;
    final transition = Curves.easeInOut.transform(
      moveAnimation.clamp(0.0, 1.0),
    );
    // Enter from right and settle close to the center while transitioning room.
    final transitionOffset = moveAnimation > 0
        ? (lerpDouble(130.0, -18.0, transition) ?? 0.0)
        : 0.0;

    return Transform.translate(
      offset: Offset(walkSway + transitionOffset, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: heroes.asMap().entries.map((entry) {
          final i = entry.key;
          final hero = entry.value;
          final maxHp = state.effectiveHeroMaxHp(hero);
          final hpFrac = maxHp == 0
              ? 0.0
              : (hero.currentHp / maxHp).clamp(0.0, 1.0);
          final bob = lerpDouble(-2.0, 2.0, pulse) ?? 0.0;
          final barColor = hpFrac <= 0.25
              ? KenneyBarColor.red
              : hpFrac <= 0.5
              ? KenneyBarColor.yellow
              : KenneyBarColor.green;
          final heroSize = isMobile ? 24.0 : 32.0;
          final nameBoxWidth = isMobile ? 28.0 : 36.0;
          final nameSize = isMobile ? 7.0 : 8.0;

          return Opacity(
            opacity: hero.isAlive ? 1.0 : 0.35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, bob),
                  child: KenneySprite(
                    asset: KenneyAssets.heroSpriteFor(i),
                    size: heroSize,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: nameBoxWidth,
                  child: KenneyProgressBar(
                    value: hpFrac,
                    height: isMobile ? 5 : 7,
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 1),
                SizedBox(
                  width: nameBoxWidth,
                  child: Text(
                    hero.name.split(' ').first,
                    style: TextStyle(fontSize: nameSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SideEnemyView extends StatelessWidget {
  const _SideEnemyView({
    required this.enemy,
    required this.pulse,
    required this.hitPulse,
    required this.compact,
  });

  final EnemyUnit enemy;
  final double pulse;
  final double hitPulse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isBoss = enemy.role == EnemyRole.boss;
    final isDead = enemy.isDefeated;
    final hpFraction = enemy.maxHp == 0
        ? 0.0
        : (enemy.currentHp / enemy.maxHp).clamp(0.0, 1.0);
    final scale = isDead ? 1.0 : (lerpDouble(1.0, 1.1, pulse) ?? 1.0);
    final shift = isDead ? 0.0 : (hitPulse * 14) * (pulse > 0.5 ? -1 : 1);
    final baseSize = isBoss
        ? (isMobile ? 70.0 : 100.0)
        : (isMobile ? 50.0 : 80.0);
    final enemySize = compact ? baseSize * 0.62 : baseSize;
    final hpBarWidth = compact
        ? (isMobile ? 52.0 : 76.0)
        : (isMobile ? 120.0 : 180.0);

    return Opacity(
      opacity: isDead ? 0.25 : 1.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(shift, 0),
            child: Transform.scale(
              scale: scale - (hitPulse * 0.12),
              child: KenneySprite(
                asset: KenneyAssets.enemySpriteFor(enemy),
                size: enemySize,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            enemy.name,
            style: GoogleFonts.pressStart2p(
              fontSize: compact ? (isMobile ? 5 : 6) : (isMobile ? 7 : 8),
              color: isBoss ? const Color(0xFFE9C873) : const Color(0xFFD4C9A2),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: hpBarWidth,
            child: RpgProgressBar(
              value: hpFraction,
              height: compact ? (isMobile ? 8 : 10) : (isMobile ? 12 : 16),
              color: isBoss ? KenneyBarColor.yellow : KenneyBarColor.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreasureChestView extends StatelessWidget {
  const _TreasureChestView({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bob = lerpDouble(-3.0, 3.0, pulse) ?? 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(0, bob),
          child: KenneySprite(
            asset: KenneyAssets.chestClosed,
            size: isMobile ? 56.0 : 84.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Opening chest...',
          style: GoogleFonts.pressStart2p(
            fontSize: isMobile ? 7 : 8,
            color: const Color(0xFFFFE17D),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Tab Selector
// ════════════════════════════════════════════════════════════════════════════

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.activeTab, required this.onSelect});

  final int activeTab;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabBtn(
          label: 'BOARD',
          index: 0,
          active: activeTab == 0,
          onTap: onSelect,
        ),
        const SizedBox(width: 6),
        _TabBtn(
          label: 'FORGE',
          index: 1,
          active: activeTab == 1,
          onTap: onSelect,
        ),
        const SizedBox(width: 6),
        _TabBtn(
          label: 'BAG',
          index: 2,
          active: activeTab == 2,
          onTap: onSelect,
        ),
        const SizedBox(width: 6),
        _TabBtn(
          label: 'JOBS',
          index: 3,
          active: activeTab == 3,
          onTap: onSelect,
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.index,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool active;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                active ? KenneyAssets.buttonBrown : KenneyAssets.buttonGrey,
              ),
              fit: BoxFit.fill,
              centerSlice: const Rect.fromLTWH(10, 10, 12, 12),
              filterQuality: FilterQuality.none,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.pressStart2p(
                fontSize: 10,
                color: active
                    ? const Color(0xFFFFF7D7)
                    : const Color(0xFFADA38A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ════════════════════════════════════════════════════════════════════════════

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
  Widget build(BuildContext context) =>
      KenneyPanel(padding: padding, style: style, child: child);
}

// ════════════════════════════════════════════════════════════════════════════
// Hero Deck
// ════════════════════════════════════════════════════════════════════════════

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
            KenneySprite(asset: KenneyAssets.iconHeart, size: 18),
            const SizedBox(width: 6),
            Text(
              'HEROES',
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
            final stacked = constraints.maxWidth < 520;
            if (stacked) {
              return Column(
                children: [
                  for (var i = 0; i < frontliners.length; i++) ...[
                    _HeroPanel(
                      hero: frontliners[i],
                      state: state,
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
                    (e) => Text(
                      '${e.value.roleLabel} · ${e.value.name} Lv ${e.value.level} · ${e.value.passiveLabel}',
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
    required this.heroIndex,
  });

  final PartyHero hero;
  final GameState state;
  final int heroIndex;

  @override
  Widget build(BuildContext context) {
    final maxHp = state.effectiveHeroMaxHp(hero);
    final attack = state.effectiveHeroAttack(hero);
    final defense = state.effectiveHeroDefense(hero);
    final hpFraction = maxHp == 0
        ? 0.0
        : (hero.currentHp / maxHp).clamp(0.0, 1.0);
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
                size: 50,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.roleLabel,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: const Color(0xFFFFEAAE),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hero.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hero.passiveLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFD7CAA0),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  KenneySprite(asset: KenneyAssets.iconStar, size: 14),
                  Text(
                    'Lv ${hero.level}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'ATK',
                  value: attack.toString(),
                  icon: KenneyAssets.iconSword,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MiniStat(
                  label: 'DEF',
                  value: defense.toString(),
                  icon: KenneyAssets.iconShield,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MiniStat(
                  label: 'HP',
                  value: '${hero.currentHp}/$maxHp',
                  icon: KenneyAssets.iconHeart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RpgProgressBar(height: 18, value: hpFraction, color: barColor),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF211D13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF5F5537)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                KenneySprite(asset: icon!, size: 12),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.pressStart2p(
                  fontSize: 7,
                  color: const Color(0xFFD7C88F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Inventory Board — BOARD tab
// ════════════════════════════════════════════════════════════════════════════

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
      _EquipmentSlotTile(
        label: 'WEAPON',
        item: state.equippedWeapon,
        emptyIcon: KenneyAssets.sword,
      ),
      _EquipmentSlotTile(
        label: 'ARMOR',
        item: state.equippedArmor,
        emptyIcon: KenneyAssets.shield,
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
        Row(
          children: [
            KenneySprite(asset: KenneyAssets.chestOpen, size: 22),
            const SizedBox(width: 8),
            Text(
              'INVENTORY BOARD',
              style: GoogleFonts.pressStart2p(
                fontSize: 10,
                color: const Color(0xFFFFE8AA),
              ),
            ),
          ],
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
  Widget build(BuildContext context) => KenneyPanel(
    padding: const EdgeInsets.all(10),
    style: KenneyPanelStyle.border,
    child: child,
  );
}

class _InventoryStatTile extends StatelessWidget {
  const _InventoryStatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });
  final String title, value, subtitle, icon;

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
  final String title, body, buttonLabel;
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
  final void Function(String) onUnlockRelic;

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
              KenneySprite(asset: KenneyAssets.relicIconFor(relicId), size: 28),
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

class _EquipmentSlotTile extends StatelessWidget {
  const _EquipmentSlotTile({
    required this.label,
    required this.item,
    required this.emptyIcon,
  });

  final String label;
  final EquipmentItem? item;
  final String emptyIcon;

  @override
  Widget build(BuildContext context) {
    final equipped = item;
    final accent = equipped == null
        ? const Color(0xFF9A9070)
        : switch (equipped.rarity) {
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
                asset: equipped == null
                    ? emptyIcon
                    : KenneyAssets.equipmentIconFor(equipped),
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.pressStart2p(fontSize: 9, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            equipped?.name ?? 'Empty',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (equipped == null)
            const Text('Auto-equip better drops', style: TextStyle(fontSize: 16))
          else ...[
            Text(
              GameLogic.rarityNames[equipped.rarity]!,
              style: TextStyle(fontSize: 16, color: accent),
            ),
            Text(
              '+${equipped.attackBonus} ATK  +${equipped.defenseBonus} DEF  +${equipped.vitalityBonus} HP',
              style: const TextStyle(fontSize: 16),
            ),
          ],
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
    final outcomeLabel = switch (drop.outcome) {
      LootOutcome.equipped => 'EQUIPPED',
      LootOutcome.replaced => 'UPGRADED',
      LootOutcome.stashed => drop.essenceGained > 0
          ? 'STASH (+${drop.essenceGained}e)'
          : 'STASH',
      LootOutcome.essence => drop.essenceGained > 0
          ? '+${drop.essenceGained}e'
          : '+${GameLogic.lootEssenceValue(drop)}e',
    };
    return _InventoryCellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(
                asset: KenneyAssets.lootDropIconFor(drop),
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                GameLogic.rarityNames[drop.rarity]!.toUpperCase(),
                style: GoogleFonts.pressStart2p(fontSize: 9, color: accent),
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
          Text(outcomeLabel, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Bag — inventory + recent loot
// ════════════════════════════════════════════════════════════════════════════

class _BagPanel extends StatelessWidget {
  const _BagPanel({
    required this.state,
    required this.onEquip,
    required this.onUnequip,
    required this.onSell,
  });

  final GameState state;
  final void Function(String itemId) onEquip;
  final void Function(EquipmentSlot slot) onUnequip;
  final void Function(String itemId) onSell;

  @override
  Widget build(BuildContext context) {
    return _PixelPanel(
      padding: const EdgeInsets.all(12),
      style: KenneyPanelStyle.beige,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KenneySprite(asset: KenneyAssets.chestOpen, size: 22),
              const SizedBox(width: 8),
              Text(
                'BAG',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: const Color(0xFFFFE8AA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Equipped',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: const Color(0xFFD7CAA0),
            ),
          ),
          const SizedBox(height: 6),
          if (state.equippedWeapon != null)
            _BagItemRow(
              item: state.equippedWeapon!,
              tag: 'W',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneyButton(
                    label: 'UNEQ',
                    onPressed: () => onUnequip(EquipmentSlot.weapon),
                    style: KenneyButtonStyle.brown,
                    expanded: false,
                  ),
                  const SizedBox(width: 4),
                  KenneyButton(
                    label: 'SELL',
                    onPressed: () => onSell(state.equippedWeapon!.id),
                    style: KenneyButtonStyle.grey,
                    expanded: false,
                  ),
                ],
              ),
            )
          else
            const Text('No weapon', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          if (state.equippedArmor != null)
            _BagItemRow(
              item: state.equippedArmor!,
              tag: 'A',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneyButton(
                    label: 'UNEQ',
                    onPressed: () => onUnequip(EquipmentSlot.armor),
                    style: KenneyButtonStyle.brown,
                    expanded: false,
                  ),
                  const SizedBox(width: 4),
                  KenneyButton(
                    label: 'SELL',
                    onPressed: () => onSell(state.equippedArmor!.id),
                    style: KenneyButtonStyle.grey,
                    expanded: false,
                  ),
                ],
              ),
            )
          else
            const Text('No armor', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            'Stash ${state.gearStash.length}/${GameLogic.maxGearStash}',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: const Color(0xFFD7CAA0),
            ),
          ),
          const SizedBox(height: 6),
          if (state.gearStash.isEmpty)
            const Text(
              'Empty stash — clear rooms for gear.',
              style: TextStyle(fontSize: 18),
            )
          else
            ...state.gearStash.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _BagItemRow(
                  item: item,
                  tag: item.slot == EquipmentSlot.weapon ? 'W' : 'A',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KenneyButton(
                        label: 'EQ',
                        onPressed: () => onEquip(item.id),
                        style: KenneyButtonStyle.brown,
                        expanded: false,
                      ),
                      const SizedBox(width: 4),
                      KenneyButton(
                        label: 'SELL',
                        onPressed: () => onSell(item.id),
                        style: KenneyButtonStyle.grey,
                        expanded: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Recent drops',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: const Color(0xFFD7CAA0),
            ),
          ),
          const SizedBox(height: 6),
          if (state.recentLoot.isEmpty)
            const Text('No drops yet.', style: TextStyle(fontSize: 18))
          else
            ...state.recentLoot.take(4).map(
              (drop) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${drop.name} — ${switch (drop.outcome) {
                    LootOutcome.equipped => 'EQUIP',
                    LootOutcome.replaced => 'UPGRADE',
                    LootOutcome.stashed => 'STASH',
                    LootOutcome.essence => '+e',
                  }}',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BagItemRow extends StatelessWidget {
  const _BagItemRow({
    required this.item,
    required this.tag,
    required this.trailing,
  });

  final EquipmentItem item;
  final String tag;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF14120D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF595033)),
      ),
      child: Row(
        children: [
          Text(
            '[$tag]',
            style: GoogleFonts.pressStart2p(
              fontSize: 8,
              color: const Color(0xFFFFE8AA),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.name}  P${item.powerScore}  '
              '+${item.attackBonus}/+${item.defenseBonus}/+${item.vitalityBonus}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Missions — JOBS tab
// ════════════════════════════════════════════════════════════════════════════

class _MissionsPanel extends StatelessWidget {
  const _MissionsPanel({
    required this.state,
    required this.onClaimMission,
  });

  final GameState state;
  final void Function(String missionId) onClaimMission;

  @override
  Widget build(BuildContext context) {
    return _PixelPanel(
      padding: const EdgeInsets.all(12),
      style: KenneyPanelStyle.beige,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KenneySprite(asset: KenneyAssets.book, size: 22),
              const SizedBox(width: 8),
              Text(
                'CONTRACTS',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: const Color(0xFFFFE8AA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete jobs for gold and essence. Board refreshes on Ascend.',
            style: TextStyle(fontSize: 17, color: Color(0xFFD7CAA0)),
          ),
          const SizedBox(height: 12),
          if (state.missions.isEmpty)
            const Text('No contracts available.', style: TextStyle(fontSize: 18))
          else
            ...state.missions.map(
              (mission) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissionCard(
                  mission: mission,
                  onClaim: mission.isComplete
                      ? () => onClaimMission(mission.id)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onClaim});

  final Mission mission;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mission.type) {
      MissionType.defeatEnemies => KenneyAssets.iconSkull,
      MissionType.clearBosses => KenneyAssets.iconCrown,
      MissionType.earnGold => KenneyAssets.iconCoin,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF14120D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: mission.isComplete
              ? const Color(0xFFB7D98A)
              : const Color(0xFF595033),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KenneySprite(asset: icon, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.title.toUpperCase(),
                  style: GoogleFonts.pressStart2p(
                    fontSize: 9,
                    color: const Color(0xFFFFE7A7),
                  ),
                ),
              ),
              Text(
                '${mission.progress}/${mission.target}',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RpgProgressBar(
            height: 14,
            value: mission.progressFraction,
            color: mission.isComplete
                ? KenneyBarColor.green
                : KenneyBarColor.yellow,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '+${mission.goldReward}g  +${mission.essenceReward}e',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              SizedBox(
                width: 120,
                child: KenneyButton(
                  label: mission.isComplete ? 'CLAIM' : 'ACTIVE',
                  onPressed: onClaim,
                  style: mission.isComplete
                      ? KenneyButtonStyle.red
                      : KenneyButtonStyle.grey,
                  expanded: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Forge Drawer — FORGE tab
// ════════════════════════════════════════════════════════════════════════════

class _ForgeDrawerPanel extends StatefulWidget {
  const _ForgeDrawerPanel({
    required this.state,
    required this.onTrainParty,
    required this.onUpgradeAttack,
    required this.onUpgradeDefense,
    required this.onUpgradeVitality,
    required this.onUnlockRelic,
    required this.onAscend,
    required this.onCombineGear,
    required this.onHatchPet,
    required this.onSetActivePet,
    required this.onUpgradeSanctuary,
  });

  final GameState state;
  final VoidCallback onTrainParty;
  final VoidCallback onUpgradeAttack;
  final VoidCallback onUpgradeDefense;
  final VoidCallback onUpgradeVitality;
  final void Function(String relicId) onUnlockRelic;
  final VoidCallback onAscend;
  final void Function({
    required String primaryId,
    required String secondaryId,
  })
  onCombineGear;
  final VoidCallback onHatchPet;
  final void Function(String petId) onSetActivePet;
  final void Function(String track) onUpgradeSanctuary;

  @override
  State<_ForgeDrawerPanel> createState() => _ForgeDrawerPanelState();
}

class _ForgeDrawerPanelState extends State<_ForgeDrawerPanel> {
  String? _primaryId;
  String? _secondaryId;

  GameState get state => widget.state;

  List<EquipmentItem> get _combinablePieces {
    final pieces = <EquipmentItem>[
      ...state.gearStash,
      if (state.equippedWeapon != null) state.equippedWeapon!,
      if (state.equippedArmor != null) state.equippedArmor!,
    ];
    return pieces;
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_primaryId == id) {
        _primaryId = _secondaryId;
        _secondaryId = null;
        return;
      }
      if (_secondaryId == id) {
        _secondaryId = null;
        return;
      }
      if (_primaryId == null) {
        _primaryId = id;
        return;
      }
      if (_secondaryId == null) {
        _secondaryId = id;
        return;
      }
      _primaryId = _secondaryId;
      _secondaryId = id;
    });
  }

  @override
  void didUpdateWidget(covariant _ForgeDrawerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = _combinablePieces.map((item) => item.id).toSet();
    if (_primaryId != null && !ids.contains(_primaryId)) {
      _primaryId = null;
    }
    if (_secondaryId != null && !ids.contains(_secondaryId)) {
      _secondaryId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainingCost = GameLogic.partyTrainingCostFor(state);
    final bossesNeeded = GameLogic.bossesRequiredForAscension(
      state.ascensionLevel,
    );
    final canAscend = GameLogic.canAscend(state);
    final nextLevel = state.ascensionLevel + 1;
    final ascendReward = GameLogic.ascendEssenceReward(nextLevel);
    final primary =
        _primaryId == null ? null : GameLogic.findGear(state, _primaryId!);
    final secondary =
        _secondaryId == null ? null : GameLogic.findGear(state, _secondaryId!);
    final canCombine = primary != null &&
        secondary != null &&
        GameLogic.canCombine(primary, secondary);
    final combineCost =
        canCombine ? GameLogic.combineCost(primary, secondary) : 0;
    final canAffordCombine = canCombine && state.gold >= combineCost;

    return _PixelPanel(
      padding: const EdgeInsets.all(12),
      style: KenneyPanelStyle.brown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KenneySprite(asset: KenneyAssets.book, size: 22),
              const SizedBox(width: 8),
              Text(
                'FORGE DRAWER',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: const Color(0xFFFFE8AA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ATK +${state.totalAttackBonus}  DEF +${state.totalDefenseBonus}  VIT +${state.totalVitalityBonus}',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Gear  W:${state.equippedWeapon?.name ?? '-'}  A:${state.equippedArmor?.name ?? '-'}  '
            '(+${state.equipmentAttackBonus}/+${state.equipmentDefenseBonus}/+${state.equipmentVitalityBonus})',
            style: const TextStyle(fontSize: 17, color: Color(0xFFD7CAA0)),
          ),
          const SizedBox(height: 6),
          Text(
            'AL ${state.ascensionLevel}  (+${state.ascensionGoldBonusPercent}% gold)  '
            'Bosses ${state.bossVictories}/$bossesNeeded',
            style: const TextStyle(fontSize: 18, color: Color(0xFFD7CAA0)),
          ),
          const SizedBox(height: 10),
          KenneyButton(
            label: canAscend
                ? 'Ascend → AL$nextLevel (+${ascendReward}e)'
                : 'Ascend ($bossesNeeded bosses)',
            onPressed: canAscend ? widget.onAscend : null,
            style: KenneyButtonStyle.red,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KenneyButton(
                label: 'Train $trainingCost',
                onPressed:
                    state.gold >= trainingCost ? widget.onTrainParty : null,
              ),
              KenneyButton(
                label:
                    'Attack ${GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)}',
                onPressed:
                    state.gold >=
                        GameLogic.upgradeCostFor(state, PartyUpgradeType.attack)
                    ? widget.onUpgradeAttack
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
                    ? widget.onUpgradeDefense
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
                    ? widget.onUpgradeVitality
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
                        : () => widget.onUnlockRelic(relicId),
                    style: KenneyButtonStyle.brown,
                    expanded: false,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'COMBINATOR',
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: const Color(0xFFFFE8AA),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick two same-slot pieces. Primary keeps most stats; secondary adds half.',
            style: TextStyle(fontSize: 17, color: Color(0xFFD7CAA0)),
          ),
          const SizedBox(height: 8),
          if (_combinablePieces.isEmpty)
            const Text(
              'No gear yet. Clear rooms to fill the stash.',
              style: TextStyle(fontSize: 18),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _combinablePieces.map((item) {
                final selected =
                    item.id == _primaryId || item.id == _secondaryId;
                final tag = item.id == state.equippedWeapon?.id ||
                        item.id == state.equippedArmor?.id
                    ? 'EQ'
                    : 'ST';
                final slot = item.slot == EquipmentSlot.weapon ? 'W' : 'A';
                return KenneyButton(
                  label:
                      '[$tag$slot] ${item.name} P${item.powerScore}${selected ? ' ✓' : ''}',
                  onPressed: () => _toggleSelect(item.id),
                  style: selected
                      ? KenneyButtonStyle.red
                      : KenneyButtonStyle.brown,
                  expanded: false,
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          KenneyButton(
            label: !canCombine
                ? 'Combine (pick 2 same slot)'
                : canAffordCombine
                    ? 'Combine $combineCost g'
                    : 'Combine $combineCost g (need gold)',
            onPressed: canAffordCombine
                ? () {
                    widget.onCombineGear(
                      primaryId: _primaryId!,
                      secondaryId: _secondaryId!,
                    );
                    setState(() {
                      _primaryId = null;
                      _secondaryId = null;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            'PETS',
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: const Color(0xFFFFE8AA),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active: ${state.activePet?.name ?? '-'} '
            '(+${state.petAttackBonus} ATK)',
            style: const TextStyle(fontSize: 17, color: Color(0xFFD7CAA0)),
          ),
          const SizedBox(height: 6),
          KenneyButton(
            label: state.essence >= GameLogic.hatchPetCost(state)
                ? 'Hatch pet ${GameLogic.hatchPetCost(state)}e'
                : 'Hatch pet ${GameLogic.hatchPetCost(state)}e (need ess)',
            onPressed: state.essence >= GameLogic.hatchPetCost(state)
                ? widget.onHatchPet
                : null,
          ),
          if (state.ownedPets.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: state.ownedPets.map((pet) {
                final active = state.activePet?.id == pet.id;
                return KenneyButton(
                  label:
                      '${pet.name} +${pet.totalAttackBonus}${active ? ' ✓' : ''}',
                  onPressed: () => widget.onSetActivePet(pet.id),
                  style: active
                      ? KenneyButtonStyle.red
                      : KenneyButtonStyle.brown,
                  expanded: false,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'SANCTUARY',
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: const Color(0xFFFFE8AA),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Permanent upgrades. Survives Ascend.',
            style: TextStyle(fontSize: 17, color: Color(0xFFD7CAA0)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final track in <String>['gold', 'power', 'vitality'])
                KenneyButton(
                  label:
                      '${GameLogic.sanctuaryNames[track]} Lv'
                      '${switch (track) {
                        'gold' => state.sanctuaryGoldLevel,
                        'power' => state.sanctuaryPowerLevel,
                        _ => state.sanctuaryVitalityLevel,
                      }} '
                      '${GameLogic.sanctuaryCost(switch (track) {
                        'gold' => state.sanctuaryGoldLevel,
                        'power' => state.sanctuaryPowerLevel,
                        _ => state.sanctuaryVitalityLevel,
                      })}e',
                  onPressed:
                      state.essence >=
                          GameLogic.sanctuaryCost(switch (track) {
                            'gold' => state.sanctuaryGoldLevel,
                            'power' => state.sanctuaryPowerLevel,
                            _ => state.sanctuaryVitalityLevel,
                          })
                      ? () => widget.onUpgradeSanctuary(track)
                      : null,
                  style: KenneyButtonStyle.brown,
                  expanded: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Dungeon Mini Map
// ════════════════════════════════════════════════════════════════════════════

class _DungeonMiniMap extends StatefulWidget {
  const _DungeonMiniMap({required this.state, required this.pulse});

  final GameState state;
  final double pulse;

  @override
  State<_DungeonMiniMap> createState() => _DungeonMiniMapState();
}

class _DungeonMiniMapState extends State<_DungeonMiniMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _travelController;
  late int _fromRoomIndex;

  @override
  void initState() {
    super.initState();
    _fromRoomIndex = widget.state.currentRoom.roomIndex;
    _travelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _DungeonMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFloor = oldWidget.state.currentRoom.floorNumber;
    final newFloor = widget.state.currentRoom.floorNumber;
    final oldRoom = oldWidget.state.currentRoom.roomIndex;
    final newRoom = widget.state.currentRoom.roomIndex;

    if (oldFloor != newFloor) {
      _fromRoomIndex = 0;
      _travelController.value = 1.0;
      return;
    }

    if (oldRoom != newRoom) {
      _fromRoomIndex = oldRoom;
      _travelController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _travelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final floorNum = state.currentRoom.floorNumber;
    final roomNum = state.currentRoom.roomIndex + 1;
    final zoneName = DungeonGenerator.zoneNameForFloor(floorNum);
    final rooms = state.dungeonFloor;
    final markerBob = lerpDouble(-1.0, 1.0, widget.pulse) ?? 0.0;
    final layout = _buildLabyrinthLayout(rooms, floorNum);
    final toRoomIndex = state.currentRoom.roomIndex;
    final travel = Curves.easeInOut.transform(_travelController.value);
    final fromPos = layout.nodePositionForRoom(_fromRoomIndex);
    final toPos = layout.nodePositionForRoom(toRoomIndex);
    final markerPos = Offset.lerp(fromPos, toPos, travel) ?? toPos;

    String roomIconFor(DungeonRoom room, bool isCurrent, bool isVisited) {
      if (isCurrent) {
        return KenneyAssets.iconDoor;
      }
      if (isVisited) {
        return KenneyAssets.roomCleared;
      }
      return switch (room.type) {
        RoomType.boss => KenneyAssets.iconCrown,
        RoomType.elite => KenneyAssets.iconSkull,
        RoomType.treasure => KenneyAssets.chestClosed,
        RoomType.normal => KenneyAssets.corridorInactive,
      };
    }

    return KenneyPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      style: KenneyPanelStyle.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KenneySprite(asset: KenneyAssets.iconSword, size: 16),
              const SizedBox(width: 6),
              Text(
                'FLOOR $floorNum MAP  ·  $zoneName',
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: const Color(0xFFD7C88F),
                ),
              ),
              const Spacer(),
              Text('Room $roomNum / 10', style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: LayoutBuilder(
              builder: (context, constraints) {
                Offset toPx(Offset unit) =>
                    Offset(unit.dx * constraints.maxWidth, unit.dy * 72);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LabyrinthPathPainter(
                          layout: layout,
                          visitedRoomIndex: roomNum - 1,
                        ),
                      ),
                    ),
                    for (final node in layout.nodes)
                      Positioned(
                        left: toPx(node.position).dx - 12,
                        top: toPx(node.position).dy - 11,
                        child: _MapRoomNode(
                          room: rooms[node.roomIndex],
                          isCurrentRoom: node.roomIndex == toRoomIndex,
                          isVisited: node.roomIndex < roomNum,
                          icon: roomIconFor(
                            rooms[node.roomIndex],
                            node.roomIndex == toRoomIndex,
                            node.roomIndex < roomNum,
                          ),
                        ),
                      ),
                    Positioned(
                      left: toPx(markerPos).dx - 8,
                      top: toPx(markerPos).dy - 22 + markerBob,
                      child: IgnorePointer(
                        child: KenneySprite(
                          asset: KenneyAssets.heroSpriteFor(0),
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoomNode extends StatelessWidget {
  const _MapRoomNode({
    required this.room,
    required this.isCurrentRoom,
    required this.isVisited,
    required this.icon,
  });

  final DungeonRoom room;
  final bool isCurrentRoom;
  final bool isVisited;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final isBoss = room.type == RoomType.boss;
    return Container(
      width: 24,
      height: 22,
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrentRoom
              ? const Color(0xFFFFD700)
              : isVisited
              ? const Color(0xFF90EE90)
              : const Color(0xFF6B7450),
          width: isCurrentRoom ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
        color: isCurrentRoom
            ? const Color(0xFF3A3417)
            : isVisited
            ? const Color(0xFF1B2C1B)
            : const Color(0xFF2A2420),
      ),
      child: Center(
        child: KenneySprite(asset: icon, size: isBoss ? 10 : 9),
      ),
    );
  }
}

class _LabyrinthPathPainter extends CustomPainter {
  const _LabyrinthPathPainter({
    required this.layout,
    required this.visitedRoomIndex,
  });

  final _LabyrinthLayout layout;
  final int visitedRoomIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final clearedPaint = Paint()
      ..color = const Color(0xFF85C983)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final futurePaint = Paint()
      ..color = const Color(0xFF6B7450)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    Offset toPx(Offset unit) => Offset(unit.dx * size.width, unit.dy * 72);

    for (final edge in layout.edges) {
      final from = toPx(layout.nodes[edge.fromIndex].position);
      final to = toPx(layout.nodes[edge.toIndex].position);
      final isCleared = edge.toIndex <= visitedRoomIndex;
      canvas.drawLine(from, to, isCleared ? clearedPaint : futurePaint);
    }

    for (final branch in layout.branchStubs) {
      canvas.drawLine(toPx(branch.$1), toPx(branch.$2), futurePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LabyrinthPathPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.visitedRoomIndex != visitedRoomIndex;
  }
}

class _LabyrinthLayout {
  const _LabyrinthLayout({
    required this.nodes,
    required this.edges,
    required this.branchStubs,
  });

  final List<_MapNodeDef> nodes;
  final List<_MapEdgeDef> edges;
  final List<(Offset, Offset)> branchStubs;

  Offset nodePositionForRoom(int roomIndex) {
    return nodes[roomIndex.clamp(0, nodes.length - 1)].position;
  }
}

class _MapNodeDef {
  const _MapNodeDef({required this.roomIndex, required this.position});

  final int roomIndex;
  final Offset position;
}

class _MapEdgeDef {
  const _MapEdgeDef({required this.fromIndex, required this.toIndex});

  final int fromIndex;
  final int toIndex;
}

_LabyrinthLayout _buildLabyrinthLayout(
  List<DungeonRoom> rooms,
  int floorNumber,
) {
  if (rooms.isEmpty) {
    return const _LabyrinthLayout(nodes: [], edges: [], branchStubs: []);
  }

  final random = math.Random(floorNumber * 1297 + rooms.length * 17);
  final lanes = <int>[1];
  for (int i = 1; i < rooms.length; i++) {
    final previous = lanes[i - 1];
    final move = random.nextInt(3) - 1; // -1, 0, +1
    final lane = (previous + move).clamp(0, 2);
    lanes.add(lane);
  }

  final nodes = <_MapNodeDef>[];
  final edges = <_MapEdgeDef>[];
  final branches = <(Offset, Offset)>[];
  final yLanes = [0.18, 0.48, 0.78];

  for (int i = 0; i < rooms.length; i++) {
    final x = rooms.length == 1
        ? 0.08
        : lerpDouble(0.08, 0.94, i / (rooms.length - 1))!;
    final y = yLanes[lanes[i]];
    nodes.add(_MapNodeDef(roomIndex: i, position: Offset(x, y)));

    if (i > 0) {
      edges.add(_MapEdgeDef(fromIndex: i - 1, toIndex: i));
    }

    if (i < rooms.length - 1 && random.nextDouble() < 0.35) {
      final branchSign = random.nextBool() ? 1.0 : -1.0;
      final branchStart = Offset(x, y);
      final branchEnd = Offset(
        (x + 0.03).clamp(0.0, 1.0),
        (y + branchSign * 0.14).clamp(0.1, 0.88),
      );
      branches.add((branchStart, branchEnd));
    }
  }

  return _LabyrinthLayout(nodes: nodes, edges: edges, branchStubs: branches);
}

// ════════════════════════════════════════════════════════════════════════════
// Dungeon Backdrop
// ════════════════════════════════════════════════════════════════════════════

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

// ════════════════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════════════════
