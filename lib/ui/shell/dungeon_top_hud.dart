import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/gold_income.dart';
import '../../core/keystone.dart';
import '../../core/menu_alerts.dart';
import '../../core/rift.dart';
import '../../core/greater_rift.dart';
import '../../models/dungeon_mode.dart';
import '../../models/dungeon_zoom.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_sprite.dart';
import '../kenney_button.dart';
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
    this.onOpenMore,
    this.onOpenKey,
    this.onOpenForge,
    this.onOpenParty,
  });

  final GameState state;
  final GameDirector director;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenContracts;
  final VoidCallback? onOpenMore;
  final VoidCallback? onOpenKey;
  final VoidCallback? onOpenForge;
  final VoidCallback? onOpenParty;

  static String _godHandStyleLabel(int style) => switch (style.clamp(0, 2)) {
        0 => 'BAL',
        1 => 'FOCUS',
        2 => 'WIDE',
        _ => 'BAL',
      };

  List<PopupMenuEntry<String>> _floorMenuItems({
    required int floor,
    required bool includeExtras,
  }) {
    final maxFloor = state.maxReachableFloor;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        enabled: false,
        child: Text(
          (state.inGauntlet || state.inAnyRiftMode)
              ? 'Gauntlet — no floor jump'
              : 'Floor · F$floor'
                  '${state.keystoneRunActive ? ' · KEY+${state.keystoneRunLevel}' : ''}',
          style: GameTheme.pixel(
            size: GameTheme.hudPixel,
            color: GameTheme.torchHot,
          ),
        ),
      ),
    ];
    for (var f = 1; f <= maxFloor; f++) {
      final here = f == floor;
      final unlocked = GameLogic.canTravelToFloor(state, f);
      items.add(
        PopupMenuItem(
          value: 'floor_$f',
          enabled: unlocked && !here,
          child: Text(
            here
                ? 'F$f · here'
                : unlocked
                    ? 'F$f'
                    : 'F$f · locked',
            style: GameTheme.pixel(
              size: GameTheme.hudPixel,
              color: here
                  ? GameTheme.torchHot
                  : unlocked
                      ? GameTheme.parchment
                      : GameTheme.parchmentDim,
            ),
          ),
        ),
      );
    }
    final canDown = GameLogic.canTravelToFloor(state, floor - 1);
    final canUp = GameLogic.canTravelToFloor(state, floor + 1);
    items.add(const PopupMenuDivider());
    items.add(
      PopupMenuItem(
        value: 'down',
        enabled: canDown,
        child: Text(
          canDown ? 'FLOOR −1' : 'FLOOR −1 · locked',
          style: GameTheme.pixel(size: GameTheme.hudPixel),
        ),
      ),
    );
    items.add(
      PopupMenuItem(
        value: 'up',
        enabled: canUp,
        child: Text(
          canUp ? 'FLOOR +1' : 'FLOOR +1 · locked',
          style: GameTheme.pixel(size: GameTheme.hudPixel),
        ),
      ),
    );
    if (includeExtras) {
      final claimable = state.missions.where((m) => m.canClaim).length;
      if (claimable > 0) {
        items.add(
          PopupMenuItem(
            value: 'quests',
            child: Text(
              'QUESTS ($claimable)',
              style: GameTheme.pixel(size: GameTheme.hudPixel),
            ),
          ),
        );
      }
      items.add(const PopupMenuDivider());
      if (onOpenKey != null) {
        items.add(
          PopupMenuItem(
            value: 'key',
            child: Text(
              'KEYSTONE',
              style: GameTheme.pixel(size: GameTheme.hudPixel),
            ),
          ),
        );
      }
      items.add(
        PopupMenuItem(
          value: 'more',
          child: Text(
            'MORE',
            style: GameTheme.pixel(size: GameTheme.hudPixel),
          ),
        ),
      );
      items.add(
        PopupMenuItem(
          value: 'settings',
          child: Text(
            'SETTINGS',
            style: GameTheme.pixel(size: GameTheme.hudPixel),
          ),
        ),
      );
    }
    return items;
  }

    void _requestTravel(BuildContext context, int target) {
    final fighting =
        director.spatial?.enemies.any((e) => e.isAlive) ?? false;
    if (!fighting) {
      director.travelToFloor(target);
      return;
    }
    showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Leave this fight?',
        content: Text(
          'Enemies are still alive on this floor.\n\n'
          'Jump to F$target anyway? Progress on this chamber is lost.',
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
            label: 'JUMP',
            style: KenneyButtonStyle.brown,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) director.travelToFloor(target);
    });
  }

  void _onFloorMenu(BuildContext context, String value, int floor) {
    if (value.startsWith('floor_')) {
      final target = int.tryParse(value.substring(6));
      if (target != null) _requestTravel(context, target);
      return;
    }
    switch (value) {
      case 'down':
        _requestTravel(context, floor - 1);
      case 'up':
        _requestTravel(context, floor + 1);
      case 'settings':
        onOpenSettings();
      case 'more':
        (onOpenMore ?? onOpenSettings)();
      case 'key':
        onOpenKey?.call();
      case 'quests':
        onOpenContracts();
    }
  }

  void _claimAllReadyMissions() {
    director.claimAllReadyMissions();
  }

  @override
  Widget build(BuildContext context) {
    final dungeonName =
        GameLogic.dungeonNames[state.dungeonId] ?? state.dungeonId;
    final claimable = state.missions.where((m) => m.canClaim).length;
    final floor = state.currentRoom.floorNumber;
    final world = director.spatial;
    final farm = state.dungeonMode == DungeonMode.farm;
    final compact = GameTheme.isCompactWidth(context);
    final plain = GameLogic.plainPlayerChrome(state);
    // CLAIM stays visible mid-fight so quests aren't buried in MORE.
    final showClaimChip = claimable > 0;
    final softcap = GameLogic.levelsUntilSoftcap(state);
    // Starter L1 on F1 is always "behind" floor+2 — don't panic until a wipe
    // or a real gap (about 4+ levels). Prefer bag-equip when upgrades pile up.
    final bagUpgrades = MenuAlerts.bagUpgradeCount(state);
    final showSoftcap = softcap > 0 &&
        !state.inGauntlet &&
        bagUpgrades < 5 &&
        (state.wipeStreakCount >= 1 || softcap >= 4);
    final rates = GoldIncome.ratesLine(
      state,
      runGpm: director.runGoldPerMinute,
    );
    final keyBit = state.keystoneRunActive
        ? ' · KEY +${state.keystoneRunLevel}'
        : (state.hardmodeLevel > 0 ? ' · KEY +${state.hardmodeLevel}' : '');
    final keyTimerBit = state.keystoneRunActive
        ? ' · ${Keystone.formatTimer(state.keystoneTimerMs)}/'
            '${Keystone.formatTimer(state.keystoneParMs)}'
        : '';
    final zoneShort = () {
      final parts = dungeonName.split(RegExp(r"[\s']+"));
      final word =
          parts.firstWhere((p) => p.isNotEmpty, orElse: () => dungeonName);
      return word.length > 10 ? word.substring(0, 10) : word;
    }();
    final placeLine = state.inGauntlet
        ? 'Gauntlet · F$floor'
        : state.inRift
        ? Rift.progressLabel(
            kills: state.riftKills,
            target: state.riftKillTarget,
            timerMs: state.riftTimerMs,
            parMs: state.riftParMs,
            tier: state.riftTier,
          )
        : state.inGreaterRift
        ? GreaterRift.progressLabel(
            kills: state.grKills,
            target: state.grKillTarget,
            timerMs: state.grTimerMs,
            parMs: state.grParMs,
            tier: state.grTier,
          )
        : state.inWorldBoss
        ? 'Ashen Crown'
        : '$zoneShort · F$floor$keyBit$keyTimerBit';
    void setMode(DungeonMode mode) {
      final fighting = (world?.enemies.any((e) => e.isAlive) ?? false);
      if (fighting && state.dungeonMode != mode) {
        showDialog<bool>(
          context: context,
          barrierColor: MenuChrome.scrim,
          builder: (ctx) => MenuChrome.dialog(
            title: mode == DungeonMode.farm
                ? (plain ? 'Switch to Repeat?' : 'Switch to FARM?')
                : (plain ? 'Switch to Next?' : 'Switch to PUSH?'),
            content: Text(
              mode == DungeonMode.farm
                  ? (plain
                      ? 'Repeat stays on this floor after clear for more loot.\n\n'
                          'You are mid-fight — switch anyway?'
                      : 'FARM loops the same floor after clear for more loot.\n\n'
                          'You are mid-fight — switch anyway?')
                  : (plain
                      ? 'Next advances toward the boss after each clear.\n\n'
                          'You are mid-fight — switch anyway?'
                      : 'PUSH advances toward the boss after each clear.\n\n'
                          'You are mid-fight — switch anyway?'),
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
                label: 'SWITCH',
                style: KenneyButtonStyle.brown,
                expanded: false,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ).then((ok) {
          if (ok == true) director.setDungeonMode(mode);
        });
        return;
      }
      director.setDungeonMode(mode);
    }

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
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.inGauntlet)
                              DungeonModeChip(
                                label: 'GAUNTLET',
                                selected: true,
                                dense: true,
                                interactive: false,
                                onTap: () {},
                              )
                            else if (state.inRift)
                              DungeonModeChip(
                                label: Rift.progressLabel(
                                  kills: state.riftKills,
                                  target: state.riftKillTarget,
                                  timerMs: state.riftTimerMs,
                                  parMs: state.riftParMs,
                                  tier: state.riftTier,
                                ),
                                selected: true,
                                dense: true,
                                interactive: false,
                                onTap: () {},
                              )
                            else if (state.inGreaterRift)
                              DungeonModeChip(
                                label: GreaterRift.progressLabel(
                                  kills: state.grKills,
                                  target: state.grKillTarget,
                                  timerMs: state.grTimerMs,
                                  parMs: state.grParMs,
                                  tier: state.grTier,
                                ),
                                selected: true,
                                dense: true,
                                interactive: false,
                                onTap: () {},
                              )
                            else ...[
                              DungeonModeChip(
                                label: GameLogic.dungeonModeChipLabel(
                                  DungeonMode.farm,
                                  state,
                                ),
                                selected: farm,
                                dense: true,
                                tip: GameLogic.dungeonModeChipTip(
                                  DungeonMode.farm,
                                  state,
                                ),
                                onTap: () => setMode(DungeonMode.farm),
                              ),
                              const SizedBox(width: 3),
                              DungeonModeChip(
                                label: GameLogic.dungeonModeChipLabel(
                                  DungeonMode.push,
                                  state,
                                ),
                                selected: !farm,
                                dense: true,
                                tip: GameLogic.dungeonModeChipTip(
                                  DungeonMode.push,
                                  state,
                                ),
                                onTap: () => setMode(DungeonMode.push),
                              ),
                            ],
                            // Keep God Hand ≥ minTouch; only gold/essence may shrink.
                            if (world != null) ...[
                              const SizedBox(width: 4),
                              ChamberDots(world: world),
                              if (!plain) ...[
                                const SizedBox(width: 4),
                                DungeonModeChip(
                                  label: state.dungeonZoom.hudChipLabel,
                                  selected:
                                      state.dungeonZoom != DungeonZoom.normal,
                                  dense: true,
                                  tip: state.dungeonZoom.settingsHint,
                                  onTap: () {
                                    director.cycleDungeonZoom();
                                    director.showToast(
                                      director.state.dungeonZoom.settingsLabel,
                                      life: 1.4,
                                    );
                                  },
                                ),
                              ],
                              if (!plain) ...[
                                const SizedBox(width: 4),
                                Text(
                                  _godHandStyleLabel(
                                    state.metaDepth.godHandStyle,
                                  ),
                                  style: GameTheme.pixel(
                                    size: 6,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 2),
                              Semantics(
                                button: true,
                                label: plain
                                    ? 'Tap the fight — steer your party smash'
                                    : 'God Hand — tap to smash and steer',
                                child: GodHandRing(
                                  cooldown: world.godHandCooldown,
                                  maxCooldown: state.godHandCooldownSeconds,
                                  urgent: state.wipeStreakCount >= 2,
                                  readyLabel: plain
                                      ? 'Tap the fight — steer your party smash'
                                      : null,
                                  coolingLabel: plain
                                      ? 'Tap the fight cooling ${world.godHandCooldown.toStringAsFixed(1)}s'
                                      : null,
                                  onTap: () => director.godHandAtFocus(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.keystoneRunActive ||
                              state.inGauntlet ||
                              state.inAnyRiftMode) ...[
                            const SizedBox(width: 4),
                            Semantics(
                              label: 'Essence ${state.essence}',
                              child: MenuChrome.chip(
                                icon: KenneyAssets.vialBlue,
                                label: formatCount(state.essence),
                              ),
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
                        label: 'Floor menu',
                        excludeSemantics: true,
                        child: PopupMenuButton<String>(
                          tooltip: 'Floor',
                          padding: EdgeInsets.zero,
                          color: GameTheme.stoneDeep,
                          onSelected: (value) =>
                              _onFloorMenu(context, value, floor),
                          itemBuilder: (context) =>
                              _floorMenuItems(floor: floor, includeExtras: true),
                          child: Center(
                            child: Text(
                              'F$floor',
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
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (state.inGauntlet)
                                  DungeonModeChip(
                                    label: 'GAUNTLET F$floor',
                                    selected: true,
                                    interactive: false,
                                    onTap: () {},
                                  )
                                else if (state.inRift)
                                  DungeonModeChip(
                                    label: Rift.progressLabel(
                                      kills: state.riftKills,
                                      target: state.riftKillTarget,
                                      timerMs: state.riftTimerMs,
                                      parMs: state.riftParMs,
                                      tier: state.riftTier,
                                    ),
                                    selected: true,
                                    interactive: false,
                                    onTap: () {},
                                  )
                                else if (state.inGreaterRift)
                                  DungeonModeChip(
                                    label: GreaterRift.progressLabel(
                                      kills: state.grKills,
                                      target: state.grKillTarget,
                                      timerMs: state.grTimerMs,
                                      parMs: state.grParMs,
                                      tier: state.grTier,
                                    ),
                                    selected: true,
                                    interactive: false,
                                    onTap: () {},
                                  )
                                else ...[
                                  DungeonModeChip(
                                    label: GameLogic.dungeonModeChipLabel(
                                      DungeonMode.farm,
                                      state,
                                    ),
                                    selected: farm,
                                    tip: GameLogic.dungeonModeChipTip(
                                      DungeonMode.farm,
                                      state,
                                    ),
                                    onTap: () => setMode(DungeonMode.farm),
                                  ),
                                  const SizedBox(width: 4),
                                  DungeonModeChip(
                                    label: GameLogic.dungeonModeChipLabel(
                                      DungeonMode.push,
                                      state,
                                    ),
                                    selected: !farm,
                                    tip: GameLogic.dungeonModeChipTip(
                                      DungeonMode.push,
                                      state,
                                    ),
                                    onTap: () => setMode(DungeonMode.push),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                if (world != null) ...[
                                  ChamberDots(world: world),
                                  const SizedBox(width: 6),
                                  DungeonModeChip(
                                    label: state.dungeonZoom.hudChipLabel,
                                    selected:
                                        state.dungeonZoom != DungeonZoom.normal,
                                    dense: true,
                                    tip: state.dungeonZoom.settingsHint,
                                    onTap: () {
                                      director.cycleDungeonZoom();
                                      director.showToast(
                                        director
                                            .state.dungeonZoom.settingsLabel,
                                        life: 1.4,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _godHandStyleLabel(
                                      state.metaDepth.godHandStyle,
                                    ),
                                    style: GameTheme.pixel(
                                      size: GameTheme.hudPixel,
                                      color: GameTheme.parchmentDim,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Semantics(
                                    button: true,
                                    label: plain
                                        ? 'Tap the fight — steer your party smash'
                                        : 'God Hand — tap to smash and steer',
                                    child: GodHandRing(
                                      cooldown: world.godHandCooldown,
                                      maxCooldown: state.godHandCooldownSeconds,
                                      urgent: state.wipeStreakCount >= 2,
                                      readyLabel: plain
                                          ? 'Tap the fight — steer your party smash'
                                          : null,
                                      coolingLabel: plain
                                          ? 'Tap the fight cooling ${world.godHandCooldown.toStringAsFixed(1)}s'
                                          : null,
                                      onTap: () => director.godHandAtFocus(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: GameTheme.minTouch,
                          height: GameTheme.minTouch,
                          child: Semantics(
                            button: true,
                            label: 'Floor menu',
                            excludeSemantics: true,
                            child: PopupMenuButton<String>(
                              tooltip: 'Floor',
                              padding: EdgeInsets.zero,
                              color: GameTheme.stoneDeep,
                              onSelected: (value) =>
                                  _onFloorMenu(context, value, floor),
                              itemBuilder: (context) => _floorMenuItems(
                                floor: floor,
                                includeExtras: false,
                              ),
                              child: Center(
                                child: Text(
                                  'Floor',
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
          if (compact && !state.inGauntlet && !state.inAnyRiftMode)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                GameLogic.dungeonModeAfterClearHint(state, state.dungeonMode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GameTheme.body(
                  size: 10,
                  color: GameTheme.parchmentDim,
                ),
              ),
            ),
          if (compact)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                placeLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GameTheme.pixel(
                  size: 6,
                  color: GameTheme.parchmentDim,
                ),
              ),
            ),
          if (!compact)
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
          if (bagUpgrades >= 5)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      bagUpgrades == 1
                          ? 'Better gear in bag — open GEAR · EQUIP'
                          : '$bagUpgrades better items — open GEAR · EQUIP',
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ),
                  if (onOpenParty != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onOpenParty,
                      child: Text(
                        'PARTY',
                        style: GameTheme.pixel(
                          size: GameTheme.hudPixel,
                          color: GameTheme.clear,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else if (showSoftcap)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      plain
                          ? 'Too weak · buy power or better gear'
                          : 'Underleveled · ~$softcap lvl or gear',
                      textAlign: TextAlign.center,
                      style: GameTheme.body(
                        size: 11,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ),
                  if (onOpenForge != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onOpenForge,
                      child: Text(
                        plain ? 'POWER' : 'FORGE',
                        style: GameTheme.pixel(
                          size: GameTheme.hudPixel,
                          color: GameTheme.clear,
                        ),
                      ),
                    ),
                  ],
                  if (onOpenParty != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onOpenParty,
                      child: Text(
                        'PARTY',
                        style: GameTheme.pixel(
                          size: GameTheme.hudPixel,
                          color: GameTheme.clear,
                        ),
                      ),
                    ),
                  ],
                ],
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
      label: count == 1 ? 'Claim 1 quest' : 'Claim $count quests',
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
