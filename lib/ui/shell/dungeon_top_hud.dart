import 'package:flutter/material.dart';
import '../../core/ashen_crown.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/keystone.dart';
import '../../core/menu_alerts.dart';
import '../../core/rift.dart';
import '../../core/greater_rift.dart';
import '../../models/dungeon_mode.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../spatial_dungeon_view.dart';
import 'wallet_strip.dart';

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
                  '${GameLogic.showKeystoneJargon(state) && state.keystoneRunActive ? ' · KEY+${state.keystoneRunLevel}' : ''}',
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
              'KEY',
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
    final world = director.spatial;
    final alive = world?.enemies.any((e) => e.isAlive) ?? false;
    // Mid-chamber: living pack, damaged/killed enemies, loot on ground, or timer.
    final midFloor = world != null &&
        (alive ||
            world.combatElapsed > 1.0 ||
            world.groundLoot.isNotEmpty ||
            world.enemies.any((e) => e.hp < e.maxHp));
    if (!midFloor) {
      director.travelToFloor(target);
      return;
    }
    final keyNote = GameLogic.showKeystoneJargon(state) &&
            (state.keystoneRunActive || state.hardmodeLevel > 0)
        ? '\n\nKEY timer keeps running — a jump can burn the par.'
        : '';
    showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Leave this floor?',
        content: Text(
          alive
              ? 'Enemies are still alive on this floor.\n\n'
                  'Jump to F$target anyway? Progress on this chamber is lost.'
                  '$keyNote'
              : 'This floor is mid-run (progress or loot still out).\n\n'
                  'Jump to F$target anyway? Chamber progress is lost.'
                  '$keyNote',
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
            label: 'JUMP',
            style: GameButtonStyle.brown,
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
    final plain = GameLogic.plainPlayerChrome(state);
    final showClaimChip = claimable > 0;
    final softcap = GameLogic.levelsUntilSoftcap(state);
    final bagUpgrades = MenuAlerts.bagUpgradeCount(state);
    final showSoftcap = softcap > 0 &&
        !state.inGauntlet &&
        bagUpgrades < 5 &&
        (state.wipeStreakCount >= 1 || softcap >= 4);
    final jargon = GameLogic.showKeystoneJargon(state);
    final keyBit = !jargon
        ? ''
        : state.keystoneRunActive
            ? ' · KEY +${state.keystoneRunLevel}'
            : (state.hardmodeLevel > 0 ? ' · KEY +${state.hardmodeLevel}' : '');
    // Timer is its own chip — never ellipsis behind zone/KEY in placeLine.
    final keyTimerLabel = state.keystoneRunActive
        ? Keystone.formatTimer(state.keystoneTimerMs)
        : null;
    final zoneShort = () {
      final parts = dungeonName.split(RegExp(r"[\s']+"));
      final word =
          parts.firstWhere((p) => p.isNotEmpty, orElse: () => dungeonName);
      return word.length > 10 ? word.substring(0, 10) : word;
    }();
    final awaitingExit = director.spatial?.awaitingExit == true;
    final placeLine = state.isPartyDefeated
        ? (state.inGauntlet || state.inAnyRiftMode
            ? 'WIPED · End → hub'
            : 'WIPED · Retry / Hub')
        : awaitingExit
        ? '$zoneShort · F$floor · GO stairs'
        : state.inGauntlet
        ? 'CLIMB · F$floor'
        : state.inRift
        ? Rift.progressLabel(
            progress01: state.riftProgress01,
            timerMs: state.riftTimerMs,
            tier: state.riftTier,
            guardianActive: state.riftGuardianActive,
          )
        : state.inGreaterRift
        ? GreaterRift.progressLabel(
            progress01: state.grProgress01,
            timerMs: state.grTimerMs,
            parMs: state.grParMs,
            tier: state.grTier,
            guardianActive: state.grGuardianActive,
          )
        : state.inWorldBoss
        ? AshenCrown.kitByDungeonId(state.dungeonId).title
        : '$zoneShort · F$floor$keyBit';
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
              GameButton(
                label: 'CANCEL',
                style: GameButtonStyle.grey,
                expanded: false,
                onPressed: () => Navigator.pop(ctx, false),
              ),
              GameButton(
                label: 'SWITCH',
                style: GameButtonStyle.brown,
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

    Widget modeRow() {
      if (state.inGauntlet) {
        final floor = state.currentRoom.floorNumber;
        final nextBoss = ((floor ~/ 5) + 1) * 5;
        return DungeonModeChip(
          label: 'GAUNTLET F$floor',
          selected: true,
          dense: true,
          interactive: false,
          tip:
              'Spire climb — not a 16th cave. Next boss F$nextBoss. No FARM. Wipe or leave → hub.',
          onTap: () {},
        );
      }
      if (state.inRift) {
        return DungeonModeChip(
          label: Rift.hudChipLabel(
            progress01: state.riftProgress01,
            tier: state.riftTier,
            guardianActive: state.riftGuardianActive,
          ),
          selected: true,
          dense: true,
          interactive: false,
          maxLabelWidth: 140,
          tip:
              'Stormwake farm — fill progress, kill the Guardian. Gold and gear mid-run. No fail timer.',
          onTap: () {},
        );
      }
      if (state.inGreaterRift) {
        return DungeonModeChip(
          label: GreaterRift.hudChipLabel(
            progress01: state.grProgress01,
            tier: state.grTier,
            guardianActive: state.grGuardianActive,
          ),
          selected: true,
          dense: true,
          interactive: false,
          maxLabelWidth: 140,
          tip:
              'Mothveil ranked — fill progress, kill the Guardian under the timer. No mid-run gear.',
          onTap: () {},
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DungeonModeChip(
            label: GameLogic.dungeonModeChipLabel(DungeonMode.farm, state),
            selected: farm,
            dense: true,
            tip: GameLogic.dungeonModeChipTip(DungeonMode.farm, state),
            onTap: () => setMode(DungeonMode.farm),
          ),
          const SizedBox(width: 4),
          DungeonModeChip(
            label: GameLogic.dungeonModeChipLabel(DungeonMode.push, state),
            selected: !farm,
            dense: true,
            tip: GameLogic.dungeonModeChipTip(DungeonMode.push, state),
            onTap: () => setMode(DungeonMode.push),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameTheme.ink.withValues(alpha: 0.78),
            GameTheme.stoneDeep.withValues(alpha: 0.28),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: GameTheme.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // One strip — do not Flexible-expand FARM/PUSH (that stretched them).
          Row(
            children: [
              Expanded(
                child: Text(
                  placeLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 11,
                    color: awaitingExit || state.isPartyDefeated
                        ? GameTheme.clear
                        : GameTheme.parchment,
                  ),
                ),
              ),
              if (keyTimerLabel != null) ...[
                const SizedBox(width: 4),
                Text(
                  keyTimerLabel,
                  maxLines: 1,
                  style: GameTheme.pixel(
                    size: GameTheme.hudPixel,
                    color: GameTheme.torchHot,
                  ),
                ),
              ],
              modeRow(),
              if (world != null) ...[
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
                    dense: true,
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
              if (showClaimChip) ...[
                const SizedBox(width: 2),
                MissionClaimChip(
                  count: claimable,
                  dense: true,
                  onTap: _claimAllReadyMissions,
                  onLongPress: onOpenContracts,
                ),
              ],
              SizedBox(
                width: 32,
                height: 30,
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
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WalletStrip(
                gold: state.gold,
                essence: state.essence,
                dense: true,
                showEssence: MenuTabs.showCamp(state),
              ),
            ),
          ),
          if (!state.inGauntlet &&
              !state.inAnyRiftMode &&
              awaitingExit &&
              !state.isPartyDefeated)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      GameLogic.dungeonModeAfterClearHint(
                        state,
                        state.dungeonMode,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.body(
                        size: 10,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ),
                  if (!(director.exitHoldActive))
                    Semantics(
                      button: true,
                      label: 'HOLD — skip walk, finish floor now',
                      child: GameButton(
                        label: 'HOLD',
                        tip: 'Skip the stairs walk and finish this floor now',
                        style: GameButtonStyle.brown,
                        dense: true,
                        expanded: false,
                        onPressed: director.startExitHold,
                      ),
                    ),
                ],
              ),
            ),
          if (showSoftcap)
            Padding(
              padding: const EdgeInsets.only(top: 1),
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
                        size: 10,
                        color: GameTheme.torchHot,
                      ),
                    ),
                  ),
                  if (onOpenForge != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onOpenForge,
                      child: Text(
                        'GOLD',
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
                        'GEAR',
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
            constraints: BoxConstraints(
              minHeight: dense ? 28 : GameTheme.minTouch,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 6 : 8,
                vertical: dense ? 3 : 6,
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
