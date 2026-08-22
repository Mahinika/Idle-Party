import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gold_income.dart';
import '../../core/keystone.dart';
import '../../models/dungeon_mode.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import '../spatial_dungeon_view.dart';
import 'shell_common.dart';

class DungeonTopHud extends StatelessWidget {
  const DungeonTopHud({
    super.key,
    required this.state,
    required this.director,
    required this.onOpenSettings,
    required this.onOpenContracts,
  });

  final GameState state;
  final GameDirector director;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenContracts;

  void _claimAllReadyMissions() {
    for (final mission in state.missions) {
      if (mission.isComplete) {
        director.claimMission(mission.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dungeonName =
        GameLogic.dungeonNames[state.dungeonId] ?? state.dungeonId;
    final claimable = state.missions.where((m) => m.isComplete).length;
    final floor = state.currentRoom.floorNumber;
    final world = director.spatial;
    final farm = state.dungeonMode == DungeonMode.farm;
    final compact = GameTheme.isCompactWidth(context);
    // CLAIM stays visible mid-fight so contracts aren't buried in MORE.
    final showClaimChip = claimable > 0;
    final softcap = GameLogic.levelsUntilSoftcap(state);
    final rates = GoldIncome.ratesLine(
      state,
      runGpm: director.runGoldPerMinute,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        compact ? 4 : 6,
        4,
        compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameTheme.ink.withValues(alpha: 0.82),
            GameTheme.stoneDeep.withValues(alpha: 0.55),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: GameTheme.border.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          compact
              ? Row(
                  children: [
                    if (state.inGauntlet)
                      DungeonModeChip(
                        label: 'GAUNTLET',
                        selected: true,
                        dense: true,
                        onTap: () {},
                      )
                    else ...[
                      DungeonModeChip(
                        label: 'FARM',
                        selected: farm,
                        dense: true,
                        onTap: () => director.setDungeonMode(DungeonMode.farm),
                      ),
                      const SizedBox(width: 3),
                      DungeonModeChip(
                        label: 'PUSH',
                        selected: !farm,
                        dense: true,
                        onTap: () => director.setDungeonMode(DungeonMode.push),
                      ),
                    ],
                    // Shrink dots / God Hand / gold when CLAIM + ⋯ crowd 360px.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (world != null) ...[
                              const SizedBox(width: 4),
                              ChamberDots(world: world),
                              const SizedBox(width: 4),
                              GodHandRing(
                                cooldown: world.godHandCooldown,
                                urgent: state.wipeStreakCount >= 2,
                                onTap: () => director.godHandAtFocus(),
                              ),
                            ],
                            const SizedBox(width: 4),
                            Semantics(
                              label: 'Gold ${state.gold}',
                              child: MenuChrome.chip(
                                icon: KenneyAssets.coinGold,
                                label: formatCount(state.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showClaimChip) ...[
                      const SizedBox(width: 2),
                      MissionClaimChip(
                        count: claimable,
                        dense: true,
                        onTap: _claimAllReadyMissions,
                        onLongPress: onOpenContracts,
                      ),
                      const SizedBox(width: 2),
                    ],
                    SizedBox(
                      width: GameTheme.minTouch,
                      height: GameTheme.minTouch,
                      child: Semantics(
                        button: true,
                        label: 'Floor / settings',
                        excludeSemantics: true,
                        child: PopupMenuButton<String>(
                          tooltip: 'Floor / settings',
                          padding: EdgeInsets.zero,
                          color: GameTheme.stoneDeep,
                          onSelected: (value) {
                            switch (value) {
                              case 'down':
                                director.travelToFloor(floor - 1);
                              case 'up':
                                director.travelToFloor(floor + 1);
                              case 'settings':
                                onOpenSettings();
                              case 'contracts':
                                onOpenContracts();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Text(
                                'F$floor'
                                '${state.keystoneRunActive ? ' KEY+${state.keystoneRunLevel}' : ''}'
                                ' · ${formatCount(state.gold)}g',
                                style: GameTheme.pixel(
                                  size: GameTheme.hudPixel,
                                  color: GameTheme.torchHot,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'down',
                              enabled: GameLogic.canTravelToFloor(
                                state,
                                floor - 1,
                              ),
                              child: Text(
                                'FLOOR −1',
                                style: GameTheme.pixel(
                                  size: GameTheme.hudPixel,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'up',
                              enabled: GameLogic.canTravelToFloor(
                                state,
                                floor + 1,
                              ),
                              child: Text(
                                'FLOOR +1',
                                style: GameTheme.pixel(
                                  size: GameTheme.hudPixel,
                                ),
                              ),
                            ),
                            if (claimable > 0)
                              PopupMenuItem(
                                value: 'contracts',
                                child: Text(
                                  'CONTRACTS ($claimable)',
                                  style: GameTheme.pixel(
                                    size: GameTheme.hudPixel,
                                  ),
                                ),
                              ),
                            PopupMenuItem(
                              value: 'settings',
                              child: Text(
                                'SETTINGS',
                                style: GameTheme.pixel(
                                  size: GameTheme.hudPixel,
                                ),
                              ),
                            ),
                          ],
                          child: const Center(
                            child: Icon(
                              Icons.more_horiz,
                              size: 22,
                              color: GameTheme.torchHot,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$dungeonName  F$floor'
                            '${state.keystoneRunActive ? '  KEY+${state.keystoneRunLevel}' : ''}'
                            '${state.keystoneRunActive ? '  ${Keystone.formatTimer(state.keystoneTimerMs)}/${Keystone.formatTimer(state.keystoneParMs)}' : ''}'
                            '${state.keystoneOutcome == 'timed'
                                ? '  TIMED'
                                : state.keystoneOutcome == 'depleted'
                                ? '  DEPLETED'
                                : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: GameTheme.pixel(size: GameTheme.hudPixel),
                          ),
                        ),
                        if (showClaimChip) ...[
                          const SizedBox(width: 4),
                          MissionClaimChip(
                            count: claimable,
                            onTap: _claimAllReadyMissions,
                            onLongPress: onOpenContracts,
                          ),
                        ],
                        const SizedBox(width: 4),
                        MenuChrome.chip(
                          icon: KenneyAssets.coinGold,
                          label: formatCount(state.gold),
                        ),
                        const SizedBox(width: 4),
                        MenuChrome.chip(
                          icon: KenneyAssets.vialBlue,
                          label: formatCount(state.essence),
                        ),
                        SizedBox(
                          width: GameTheme.minTouch,
                          height: GameTheme.minTouch,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: onOpenSettings,
                            icon: KenneySprite(
                              asset: KenneyAssets.iconDoor,
                              size: 18,
                            ),
                            tooltip: 'Settings',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (state.inGauntlet)
                          DungeonModeChip(
                            label: 'GAUNTLET F$floor',
                            selected: true,
                            onTap: () {},
                          )
                        else ...[
                          DungeonModeChip(
                            label: 'FARM',
                            selected: farm,
                            onTap: () =>
                                director.setDungeonMode(DungeonMode.farm),
                          ),
                          const SizedBox(width: 4),
                          DungeonModeChip(
                            label: 'PUSH',
                            selected: !farm,
                            onTap: () =>
                                director.setDungeonMode(DungeonMode.push),
                          ),
                        ],
                        const SizedBox(width: 6),
                        if (world != null) ...[
                          ChamberDots(world: world),
                          const SizedBox(width: 6),
                          GodHandRing(
                            cooldown: world.godHandCooldown,
                            urgent: state.wipeStreakCount >= 2,
                            onTap: () => director.godHandAtFocus(),
                          ),
                        ],
                        const Spacer(),
                        SizedBox(
                          width: GameTheme.minTouch,
                          height: GameTheme.minTouch,
                          child: Semantics(
                            button: true,
                            label: 'Floor travel',
                            excludeSemantics: true,
                            child: PopupMenuButton<String>(
                              tooltip: 'Floor travel',
                              padding: EdgeInsets.zero,
                              color: GameTheme.stoneDeep,
                              onSelected: (value) {
                                switch (value) {
                                  case 'down':
                                    director.travelToFloor(floor - 1);
                                  case 'up':
                                    director.travelToFloor(floor + 1);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'down',
                                  enabled: GameLogic.canTravelToFloor(
                                    state,
                                    floor - 1,
                                  ),
                                  child: Text(
                                    'FLOOR −1',
                                    style: GameTheme.pixel(
                                      size: GameTheme.hudPixel,
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'up',
                                  enabled: GameLogic.canTravelToFloor(
                                    state,
                                    floor + 1,
                                  ),
                                  child: Text(
                                    'FLOOR +1',
                                    style: GameTheme.pixel(
                                      size: GameTheme.hudPixel,
                                    ),
                                  ),
                                ),
                              ],
                              child: Center(
                                child: Text(
                                  'F±',
                                  style: GameTheme.pixel(
                                    size: GameTheme.hudPixel,
                                    color: GameTheme.torchHot,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Semantics(
              label: rates,
              child: Text(
                rates,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 11, color: GameTheme.mossLit),
              ),
            ),
          ),
          if (softcap > 0 && !state.inGauntlet)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Underleveled · train ~$softcap lvl or farm gear',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 11, color: GameTheme.torchHot),
              ),
            ),
        ],
      ),
    );
  }
}

class MissionClaimChip extends StatelessWidget {
  const MissionClaimChip({
    super.key,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.dense = false,
  });
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 1 ? 'Claim 1 mission' : 'Claim $count missions',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 6 : 8,
                vertical: dense ? 4 : 6,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GameTheme.hudFarmGreen,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: GameTheme.clear),
              ),
              child: Text(
                dense ? 'C$count' : 'CLAIM $count',
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: GameTheme.clear,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
