import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../core/keystone.dart';
import '../core/local_reminders.dart';
import '../core/menu_alerts.dart';
import '../core/menu_router.dart';
import '../core/nav_intent.dart';
import 'confirm_dialogs.dart';
import 'meta/notify_opt_in.dart';
import 'cave_atmosphere.dart';
import '../assets/custom_assets.dart';
import 'feedback_toast.dart';
import 'game_theme.dart';
import 'menu_chrome.dart';
import 'spatial_dungeon_view.dart';
import 'shell/dungeon_loot_log.dart';
import 'shell/dungeon_party_hud.dart';
import 'shell/dungeon_target_hud.dart';
import 'shell/dungeon_top_hud.dart';
import 'shell/boost_ad_button.dart';
import 'shell/home/director_select.dart';
import 'shell/scroll_buff_stack.dart';

/// Idle Party dungeon scene: full-bleed stage + corner HUD.
/// Shared menu sheets + bottom bar are owned by [PlayShell], not this scene.
class Is2Shell extends StatefulWidget {
  const Is2Shell({
    super.key,
    required this.director,
    required this.router,
    required this.pulse,
    this.onLeaveDungeon,
    this.homeChrome = false,
    this.extraBottomInset = 0,
  });

  final GameDirector director;
  final MenuRouter router;
  final double pulse;
  final VoidCallback? onLeaveDungeon;

  /// Fight-first shell draws its own top bar, party row, and rails.
  final bool homeChrome;

  /// Extra camera inset when [homeChrome] (usually 0; the panel is a sibling).
  final double extraBottomInset;

  @override
  State<Is2Shell> createState() => _Is2ShellState();
}

class _Is2ShellState extends State<Is2Shell> {
  GameState get state => widget.director.state;
  MenuRouter get router => widget.router;
  bool _dpsMeterOpen = false;
  bool _offeredPing = false;
  final GlobalKey _topHudKey = GlobalKey();

  /// Until the top HUD is measured. Two rows (place line + 44dp actions).
  double _topChromePx = 96;

  void _readTopChrome() {
    final box = _topHudKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final next = box.size.height;
    if ((next - _topChromePx).abs() < 1) return;
    setState(() => _topChromePx = next);
  }

  @override
  void initState() {
    super.initState();
    widget.director.addListener(_onClearForPing);
  }

  @override
  void dispose() {
    widget.director.removeListener(_onClearForPing);
    super.dispose();
  }

  /// One ask after a cleared floor, when the pack is dead. Not while a pack is up.
  void _onClearForPing() {
    if (_offeredPing || !mounted || router.isOpen) return;
    final director = widget.director;
    if (!LocalReminders.shouldOfferOnFloorClear(
      director.state,
      floorClear: director.spatial?.awaitingExit == true,
    )) {
      return;
    }
    if (!director.pauseExitForPrompt()) return;
    _offeredPing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        director.releaseExitPrompt();
        return;
      }
      NotifyOptInOverlay.show(
        context,
        director,
      ).whenComplete(director.releaseExitPrompt);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (!router.isOpen) return KeyEventResult.ignored;
      router.close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyB) {
      router.toggleGear(GearPanel.bag);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH && widget.onLeaveDungeon != null) {
      if (router.isOpen) router.close();
      if (widget.director.spatial?.awaitingExit == true) {
        widget.onLeaveDungeon!();
      } else {
        confirmLeaveDungeon(
          context,
          widget.onLeaveDungeon!,
          state: state,
          floorCleared: widget.director.spatial?.awaitingExit == true,
          keystoneActive: state.keystoneRunActive,
          keyTimer: state.keystoneRunActive
              ? Keystone.formatTimer(state.keystoneTimerMs)
              : null,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (state.inDungeon && !state.isPartyDefeated && !router.isOpen) {
        widget.director.godHandAtFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  double _partyStripHeight(BuildContext context, GameDirector d) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final partyRows = d.state.combatHeroes.length.clamp(1, 5);
    return partyRows * 32.0 * textScale +
        (GameLogic.canUseConsumable(d.state)
            ? DungeonFlaskButton.stripReserve
            : 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.director;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: ListenableBuilder(
        listenable: router,
        builder: (context, _) => _buildBody(d),
      ),
    );
  }

  Widget _buildBody(GameDirector d) {
    final partyBottom = GameTheme.combatHudBottom(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: DirectorSelect<String>(
            director: d,
            select: (s) => s.dungeonId,
            builder: (context, s) => CaveAtmosphere.fullBleedScene(
              CustomAssets.dungeonBackdropFor(s.dungeonId),
            ),
          ),
        ),
        const RepaintBoundary(child: _DungeonScrimBloom()),
        // Map fills the whole scene under the floating chrome so more floor
        // stays visible under FARM / PUSH (camera gets the extra height).
        // SpatialDungeonView listens to combatFrame only around the map paint —
        // not the whole dungeon chrome tree (~60 Hz).
        Positioned.fill(
          child: ListenableBuilder(
            listenable: d.combatFrame,
            builder: (context, _) {
              final partyStrip = _partyStripHeight(context, d);
              return MenuChrome.playSafeArea(
                child: SpatialDungeonView(
                  director: d,
                  cameraTopInset: widget.homeChrome ? 8 : _topChromePx,
                  cameraBottomInset: widget.homeChrome
                      ? widget.extraBottomInset
                      : partyBottom + partyStrip + 8,
                ),
              );
            },
          ),
        ),
        MenuChrome.playSafeArea(
          top: true,
          child: Column(
            children: [
              KeyedSubtree(
                key: _topHudKey,
                child: _Is2FightTopBar(
                  director: d,
                  router: router,
                  homeChrome: widget.homeChrome,
                  onMeasured: _readTopChrome,
                ),
              ),
              Expanded(
                child: _Is2CombatCornerChrome(
                  director: d,
                  router: router,
                  homeChrome: widget.homeChrome,
                  dpsMeterOpen: _dpsMeterOpen,
                  onDpsOpenChanged: (open) {
                    if (_dpsMeterOpen == open) return;
                    setState(() => _dpsMeterOpen = open);
                  },
                  partyStripHeight: (ctx) => _partyStripHeight(ctx, d),
                ),
              ),
            ],
          ),
        ),
        if (router.isOpen)
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: GameTheme.hudDim)),
          ),
      ],
    );
  }
}

/// Classic top HUD + docked toast. Rebuilds on floor/mode/toast — not hub gold.
class _Is2FightTopBar extends StatefulWidget {
  const _Is2FightTopBar({
    required this.director,
    required this.router,
    required this.homeChrome,
    required this.onMeasured,
  });

  final GameDirector director;
  final MenuRouter router;
  final bool homeChrome;
  final VoidCallback onMeasured;

  @override
  State<_Is2FightTopBar> createState() => _Is2FightTopBarState();
}

class _Is2FightTopBarState extends State<_Is2FightTopBar> {
  late Object _token;

  @override
  void initState() {
    super.initState();
    _token = _readToken();
    widget.director.addListener(_onDirector);
    widget.router.addListener(_onDirector);
  }

  @override
  void dispose() {
    widget.director.removeListener(_onDirector);
    widget.router.removeListener(_onDirector);
    super.dispose();
  }

  void _onDirector() {
    final next = _readToken();
    if (next == _token) return;
    setState(() => _token = next);
  }

  Object _readToken() {
    final d = widget.director;
    final s = d.state;
    return (
      d.dungeonTilesReady,
      d.toast,
      d.noticeKind,
      widget.router.isOpen,
      s.dungeonId,
      s.battleNumber,
      s.dungeonMode,
      s.combatPace,
      s.keystoneRunActive,
      s.keystoneTimerMs,
      s.metaDepth.farmIntensity,
      s.farmTryMult,
      s.combatHeroes.length,
      MenuTabs.showKey(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMeasured());
    final d = widget.director;
    final state = d.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.homeChrome || !d.dungeonTilesReady)
          const SizedBox.shrink()
        else
          DungeonTopHud(
            state: state,
            director: d,
            onOpenSettings: () => widget.router.open(
              MenuRoute.more,
              more: MoreSection.settings,
            ),
            onOpenMore: () => widget.router.open(MenuRoute.more),
            onOpenKey: MenuTabs.showKey(state)
                ? () => widget.router.open(MenuRoute.key)
                : null,
            onOpenContracts: () => widget.router.apply(NavIntent.quests),
            onOpenForge: () => widget.router.open(MenuRoute.gold),
            onOpenParty: () => widget.router.toggleGear(GearPanel.gear),
          ),
        if (d.dungeonTilesReady && d.toast != null && !widget.router.isOpen)
          FeedbackToast(
            message: d.toast!,
            kind: d.noticeKind,
            maxLines: 2,
            docked: true,
          ),
      ],
    );
  }
}

/// Party, target, loot, buff pips — follows [GameDirector.combatFrame], not every notify.
class _Is2CombatCornerChrome extends StatefulWidget {
  const _Is2CombatCornerChrome({
    required this.director,
    required this.router,
    required this.homeChrome,
    required this.dpsMeterOpen,
    required this.onDpsOpenChanged,
    required this.partyStripHeight,
  });

  final GameDirector director;
  final MenuRouter router;
  final bool homeChrome;
  final bool dpsMeterOpen;
  final ValueChanged<bool> onDpsOpenChanged;
  final double Function(BuildContext context) partyStripHeight;

  @override
  State<_Is2CombatCornerChrome> createState() => _Is2CombatCornerChromeState();
}

class _Is2CombatCornerChromeState extends State<_Is2CombatCornerChrome> {
  var _tilesReady = false;
  var _awaitingWipe = false;

  @override
  void initState() {
    super.initState();
    final d = widget.director;
    _tilesReady = d.dungeonTilesReady;
    _awaitingWipe = d.awaitingWipeChoice;
    d.addListener(_onDirectorShell);
    d.combatFrame.addListener(_onCombatFrame);
  }

  @override
  void dispose() {
    final d = widget.director;
    d.removeListener(_onDirectorShell);
    d.combatFrame.removeListener(_onCombatFrame);
    super.dispose();
  }

  void _onDirectorShell() {
    final d = widget.director;
    final tiles = d.dungeonTilesReady;
    final wipe = d.awaitingWipeChoice;
    if (tiles == _tilesReady && wipe == _awaitingWipe) return;
    setState(() {
      _tilesReady = tiles;
      _awaitingWipe = wipe;
    });
  }

  void _onCombatFrame() {
    if (!mounted || !_tilesReady) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_tilesReady) return const SizedBox.shrink();
    final d = widget.director;
    final state = d.state;
    final hudSide = GameTheme.edgeGap;
    final partyBottom = GameTheme.combatHudBottom(context);
    final partyStrip = widget.partyStripHeight(context);
    const buffClear = 44.0 + 168.0;
    final lootLogBottom =
        partyBottom + (partyStrip > buffClear ? partyStrip : buffClear) + 8;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_awaitingWipe) ...[
          if (!widget.homeChrome && widget.dpsMeterOpen)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: GameTheme.hudDimSoft,
                ),
              ),
            ),
          if (!widget.homeChrome)
            Positioned(
              left: hudSide,
              top: 2,
              child: GameLogic.plainPlayerChrome(state)
                  ? const SizedBox.shrink()
                  : DpsMeter(
                      director: d,
                      onOpenChanged: widget.onDpsOpenChanged,
                    ),
            ),
          Positioned(
            right: hudSide,
            top: widget.homeChrome ? 4 : 22,
            child: TargetCornerHud(director: d),
          ),
          Positioned(
            left: 0,
            right: 0,
            top:
                bossIntroBannerTop(
                  MediaQuery.textScalerOf(context).scale(1),
                ) +
                (state.keystoneRunActive ? 22 : 0),
            child: ListenableBuilder(
              listenable: d.combatFrame,
              builder: (context, _) {
                final world = d.spatial;
                if (widget.dpsMeterOpen ||
                    world == null ||
                    world.bossBannerTimer <= 0) {
                  return const SizedBox.shrink();
                }
                return BossIntroBanner(
                  name: world.bossBannerName,
                );
              },
            ),
          ),
          if (!widget.homeChrome)
            Positioned(
              left: hudSide,
              bottom: partyBottom,
              child: PartyCornerHud(
                director: d,
                selectedHeroIndex: widget.router.session.abilityHeroIndex,
                onSelectHero: (i) {
                  widget.router.session.abilityHeroIndex = i;
                  d.cameraHeroIndex = i;
                },
                onOpenEquip: () => widget.router.toggleGear(GearPanel.gear),
              ),
            ),
          if (!widget.homeChrome)
            Positioned(
              left: hudSide,
              right: hudSide,
              bottom: lootLogBottom,
              child: DungeonLootLog(lines: d.lootLog),
            ),
          if (!widget.homeChrome)
            Positioned(
              right: hudSide,
              bottom: partyBottom + 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BoostAdButton(director: d),
                  ScrollBuffStack(
                    meta: d.state.metaDepth,
                    maxHeight: 168,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _DungeonScrimBloom extends StatelessWidget {
  const _DungeonScrimBloom();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CaveAtmosphere.readabilityScrim(top: 0.18, bottom: 0.28),
        CaveAtmosphere.torchBloom(
          intensity: 0.45,
          alignment: const Alignment(0, 0.15),
          sizeFactor: 0.7,
        ),
      ],
    );
  }
}
