import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../assets/custom_assets.dart';
import '../../../assets/kenney_assets.dart';
import '../../../core/chase_dispatcher.dart';
import '../../../core/first_climb_coach.dart';
import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/hub_primary_cta.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../../core/town_access.dart';
import '../../../models/dungeon_def.dart';
import '../../../models/hero.dart';
import '../../../models/town_building.dart';
import 'town_ambient.dart';
import 'town_life.dart';
import 'town_scene.dart';
import '../../chase_bind.dart';
import '../../coach_pulse.dart';
import '../../confirm_dialogs.dart';
import '../../hub/hub_powerups.dart';
import '../../first_session_tips.dart';
import '../../game_theme.dart';
import '../../hero_doll_sprite.dart';
import '../../kenney_button.dart';
import '../../menu_chrome.dart';
import '../../meta/farm_strength_picker.dart';
import '../../web_click_bridge.dart';
import '../menu_surface.dart';
import 'director_select.dart';
import 'nav_clearance.dart';

/// Out-of-dungeon town on [HomeShell]: party on the square, distinct
/// buildings, one ENTER. [TownPreview] is the isolated harness.
class TownViewport extends StatefulWidget {
  const TownViewport({super.key, required this.director, required this.router});

  final GameDirector director;
  final MenuRouter router;

  @override
  State<TownViewport> createState() => _TownViewportState();
}

class _TownViewportState extends State<TownViewport> {
  String? _lockedTitle;
  String? _lockedBody;
  DateTime? _tapMuteUntil;
  Timer? _tapMuteTimer;

  GameDirector get director => widget.director;
  MenuRouter get router => widget.router;

  static const Duration _postSheetTapMute = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    widget.router.addListener(_onRouterClosed);
  }

  @override
  void dispose() {
    _tapMuteTimer?.cancel();
    widget.router.removeListener(_onRouterClosed);
    super.dispose();
  }

  void _onRouterClosed() {
    if (widget.router.isOpen) return;
    final until = DateTime.now().add(_postSheetTapMute);
    _tapMuteTimer?.cancel();
    if (mounted) {
      setState(() => _tapMuteUntil = until);
    } else {
      _tapMuteUntil = until;
    }
    _tapMuteTimer = Timer(_postSheetTapMute, () {
      if (!mounted) return;
      if (_tapMuteUntil == until) {
        setState(() => _tapMuteUntil = null);
      }
    });
  }

  bool get _townTapsMuted =>
      _tapMuteUntil != null && DateTime.now().isBefore(_tapMuteUntil!);

  ChasePlan _enterDungeonPlan(GameState state, HubChase chase) {
    final zoneId = GameLogic.recommendedDungeonId(state);
    return ChasePlan(
      label: HubPrimaryCta.enterDungeonLabel(
        chase: chase,
        chaseActionLabel: null,
        hardmodeLevel: state.hardmodeLevel,
      ),
      op: ChaseOp.enter,
      zoneId: zoneId,
    );
  }

  void _clearLocked() {
    if (_lockedTitle == null) return;
    setState(() {
      _lockedTitle = null;
      _lockedBody = null;
    });
  }

  void _showLocked(String title, String body) {
    router.close();
    setState(() {
      _lockedTitle = title;
      _lockedBody = body;
    });
  }

  void _openBuilding(TownBuilding building) {
    final state = director.state;
    switch (building.id) {
      case TownBuildingId.forge:
        if (!TownAccess.forgeOpen(state)) {
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
          return;
        }
        _clearLocked();
        // The one entry to CRAFT outside the MENU grid, on purpose
        // (Robert, audit F099): the town FORGE is the Apex station.
        router.open(MenuRoute.more, more: MoreSection.craft);
        router.pushSub();
      case TownBuildingId.market:
        if (!TownAccess.marketOpen(state)) {
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
          return;
        }
        _clearLocked();
        router.open(MenuRoute.gold, gold: GoldPanel.market);
      case TownBuildingId.inn:
        if (!TownAccess.innOpen(state)) {
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
          return;
        }
        _clearLocked();
        router.open(MenuRoute.gear, gear: GearPanel.roster);
        router.pushSub();
      case TownBuildingId.guild:
        if (!TownAccess.guildOpen(state)) {
          _showLocked(
            building.label,
            TownAccess.lockedCopy(building.id, state),
          );
          return;
        }
        _clearLocked();
        router.open(MenuRoute.more, more: MoreSection.quests);
      case TownBuildingId.vault:
        if (TownAccess.vaultClaimable(state)) {
          _clearLocked();
          director.claimDailyVault();
          return;
        }
        _showLocked(building.label, TownAccess.lockedCopy(building.id, state));
    }
  }

  bool _badge(TownBuildingId id, GameState state) {
    return switch (id) {
      TownBuildingId.forge => false,
      TownBuildingId.market => !MenuAlerts.marketAlert(state).isQuiet,
      TownBuildingId.inn => state.metaDepth.pendingHeroReveals.isNotEmpty,
      TownBuildingId.guild => state.missions.any((m) => m.canClaim),
      TownBuildingId.vault => TownAccess.vaultClaimable(state),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameTheme.stoneDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _square(context)),
          // Cave name, ENTER, and the rails still follow every director tick.
          // The square does not: a gold tick must not rebuild its images.
          ListenableBuilder(
            listenable: director,
            builder: (context, _) => _chrome(context),
          ),
        ],
      ),
    );
  }

  Widget _square(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DirectorSelect<TownPaintToken>(
          director: director,
          select: TownPaintToken.of,
          builder: (context, state) {
            final motion = townFolkMotionEnabled(
              quality: state.vfxQuality,
              disableAnimations: MediaQuery.disableAnimationsOf(context),
            );
            final token = TownPaintToken.of(state).withMotion(motion);
            return LayoutBuilder(
              builder: (context, constraints) {
                return _Hold(
                  key: const ValueKey('town-paint'),
                  token: token,
                  child: _TownSquare(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    state: state,
                    tier: TownTier.paintedIndex(state.ascensionLevel),
                    onTap: _openBuilding,
                    badgeOf: (id) => _badge(id, state),
                  ),
                );
              },
            );
          },
        ),
        if (_lockedTitle != null && _lockedBody != null)
          Positioned.fill(
            child: _TownLockedNote(
              title: _lockedTitle!,
              body: _lockedBody!,
              onClose: _clearLocked,
            ),
          ),
      ],
    );
  }

  Widget _chrome(BuildContext context) {
    final state = director.state;
    final chase = HubChase.forState(state);
    final plan = ChaseDispatcher.plan(chase, state: state);
    final held = director.vaultClaimHold;
    final label = held ? 'CLAIM VAULT' : (plan.label ?? 'ENTER');
    final tomorrow = chase.title.startsWith('Tomorrow:') ? chase.title : null;
    final cave = DungeonCatalog.byId(state.dungeonId).name;
    final al = state.ascensionLevel;
    final primaryIsEnter =
        plan.op == ChaseOp.enter || plan.op == ChaseOp.enterKey;
    final zoneId = GameLogic.recommendedDungeonId(state);
    final zoneUnlocked = ChaseDispatcher.zoneUnlocked(state, zoneId);
    final cta = HubPrimaryCta.resolve(
      chase: chase,
      chaseActionLabel: plan.label,
      hasChaseAction: plan.label != null && plan.op != ChaseOp.none,
      unlockedSelected: zoneUnlocked,
      hardmodeLevel: state.hardmodeLevel,
      showKeystoneJargon: GameLogic.showKeystoneJargon(state),
      endgameUnlocked: GameLogic.endgameUnlocked(state),
    );
    final enterLabel = primaryIsEnter
        ? null
        : (cta.secondaryLabel ??
            (zoneUnlocked
                ? HubPrimaryCta.enterDungeonLabel(
                    chase: chase,
                    chaseActionLabel: null,
                    hardmodeLevel: state.hardmodeLevel,
                  )
                : null));
    final showSecondaryEnter =
        !primaryIsEnter && enterLabel != null && zoneUnlocked;
    final showAscendBesideEnter = showSecondaryEnter &&
        GameLogic.canAscend(state) &&
        plan.op != ChaseOp.confirmAscend;
    final showAscendBelow = !showSecondaryEnter &&
        GameLogic.canAscend(state) &&
        plan.op != ChaseOp.confirmAscend &&
        plan.op != ChaseOp.enter &&
        plan.op != ChaseOp.enterKey;
    final enterPlan = _enterDungeonPlan(state, chase);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // No quick rail in town (Robert, audit F100): the buildings are the
        // entry points; SCROLLS / DAILY / POUCH / UPDATE moved to MENU.
        DecoratedBox(
          decoration: MenuChrome.panel(opaque: true),
          child: Padding(
            // Under HomeShell the raised FIGHT circle rises into this card.
            // Keep ENTER above it.
            padding: EdgeInsets.fromLTRB(
              10,
              6,
              10,
              8 + NavClearance.of(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Town tier and cave on one line, so the town scene keeps
                // more height above the card (Robert, "Fixa resten" item 5).
                Row(
                  key: townHeaderKey,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        townProgressLine(ascensionLevel: al, cave: cave),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.hint(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '—',
                        style: GameTheme.hint(color: GameTheme.parchmentDim),
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: Text(
                        cave,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.section(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (tomorrow != null) ...[
                  Text(
                    tomorrow,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(color: GameTheme.torchHot),
                  ),
                  const SizedBox(height: 4),
                ],
                // Pick FARM strength before the run (Robert, Nov 19): only
                // when this button enters a normal cave, a floor is cleared
                // and no KEY is dialled (a KEY run has no FARM strength).
                if (showTownFarmPicker(state, plan)) ...[
                  FarmStrengthPicker(director: director, compact: true),
                  const SizedBox(height: 6),
                ],
                IgnorePointer(
                  ignoring: _townTapsMuted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The coach says "Tap ENTER." — pulse the button it means
                      // (audit F093).
                      CoachPulse(
                        key: TownEnterCoach.pulseKey,
                        active: TownEnterCoach.active(state),
                        child: WebClickScope(
                          label: label,
                          onPressed: held
                              ? null
                              : () => runChasePlan(
                                  context: context,
                                  director: director,
                                  router: router,
                                  plan: plan,
                                  onEnterDungeon: (id) {
                                    router.close();
                                    director.enterDungeon(dungeonId: id);
                                  },
                                ),
                          child: GameButton(
                            label: label,
                            style: GameButtonStyle.go,
                            primary: true,
                            onPressed: held
                                ? null
                                : () => runChasePlan(
                              context: context,
                              director: director,
                              router: router,
                              plan: plan,
                              onEnterDungeon: (id) {
                                router.close();
                                director.enterDungeon(dungeonId: id);
                              },
                            ),
                          ),
                        ),
                      ),
                      if (showSecondaryEnter) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: GameButton(
                                label: enterLabel,
                                style: GameButtonStyle.brown,
                                primary: true,
                                onPressed: () => runChasePlan(
                                  context: context,
                                  director: director,
                                  router: router,
                                  plan: enterPlan,
                                  onEnterDungeon: (id) {
                                    router.close();
                                    director.enterDungeon(dungeonId: id);
                                  },
                                ),
                              ),
                            ),
                            if (showAscendBesideEnter) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: GameButton(
                                  label: 'ASCEND',
                                  style: GameButtonStyle.brown,
                                  primary: true,
                                  onPressed: () =>
                                      confirmAscend(context, director),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (showAscendBelow) ...[
                        const SizedBox(height: 6),
                        GameButton(
                          label: 'ASCEND',
                          style: GameButtonStyle.brown,
                          primary: true,
                          onPressed: () => confirmAscend(context, director),
                        ),
                      ],
                      if (MenuTabs.showScrolls(state)) ...[
                        const SizedBox(height: 6),
                        HubPowerupsFab(
                          state: state,
                          onOpen: () => openPowerupsSheet(context, director),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Town card header row: town tier — cave name.
const Key townHeaderKey = ValueKey('town-card-header');

/// Red wash on the square when the next cave is Hell's Gate.
const Key townHellWashKey = ValueKey('town-hell-wash');

/// Town ENTER shows the FARM strength picker when the button starts a
/// normal cave run, at least one floor is cleared and KEY is +0.
bool showTownFarmPicker(GameState state, ChasePlan plan) =>
    plan.op == ChaseOp.enter &&
    state.hardmodeLevel <= 0 &&
    FarmStrengthPicker.showBeforeEnter(state);

class _TownSquare extends StatelessWidget {
  const _TownSquare({
    required this.size,
    required this.state,
    required this.tier,
    required this.onTap,
    required this.badgeOf,
  });

  final Size size;
  final GameState state;
  final int tier;
  final ValueChanged<TownBuilding> onTap;
  final bool Function(TownBuildingId id) badgeOf;

  @override
  Widget build(BuildContext context) {
    final layout = TownSceneLayout.pack(
      size,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    final guild = TownBuilding.byId(TownBuildingId.guild);
    final vault = TownBuilding.byId(TownBuildingId.vault);
    final vaultPath = TownAccess.vaultClaimedToday(state)
        ? CustomAssets.townVaultOpen
        : CustomAssets.townVaultShut;
    final motion = townFolkMotionEnabled(
      quality: state.vfxQuality,
      disableAnimations: MediaQuery.disableAnimationsOf(context),
    );
    final partyDoll = layout.lane.height >= 48 && size.width >= 360
        ? 40.0
        : (size.height < 380 ? 34.0 : 42.0);
    final folkYardHeight = TownFolkSheet.yardHeightForPartyDoll(partyDoll);
    final labels = <(String, Rect)>[
      (guild.label, layout.guildLabel),
      (vault.label, layout.vaultLabel),
      for (var i = 0; i < TownBuilding.frontRow.length; i++)
        (TownBuilding.frontRow[i].label, layout.frontLabels[i]),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: _TownBackdrop()),
        Positioned(
          left: 0,
          right: 0,
          top: layout.grassTop,
          bottom: 0,
          child: Image.asset(
            CustomAssets.townGround,
            // Native pixels. scaleDown would shrink a tile that is larger
            // than the lawn and bring the repeat back.
            fit: BoxFit.none,
            repeat: ImageRepeat.repeat,
            alignment: Alignment.topLeft,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
        for (final spur in layout.approaches) _approach(spur),
        for (final street in layout.streets) _street(street),
        for (final shade in layout.contacts)
          _sprite(
            shade,
            CustomAssets.townContact,
            fit: BoxFit.contain,
            align: Alignment.bottomCenter,
          ),
        for (final tree in layout.trees)
          _sprite(
            tree,
            tree.width > 60
                ? CustomAssets.townTreeRound
                : CustomAssets.townTreeTall,
            fit: BoxFit.contain,
            align: Alignment.bottomCenter,
          ),
        for (final planting in layout.plantings)
          if (!_coversLabel(planting.rect, labels))
            _sprite(
              planting.rect,
              _plantingAsset(planting.asset),
              fit: BoxFit.contain,
              align: Alignment.bottomCenter,
            ),
        Positioned.fill(
          child: TownAmbientLayer(
            layout: layout,
            size: size,
          ),
        ),
        _building(layout.guild, guild, guild.assetPath(tier)),
        _building(layout.vault, vault, vaultPath),
        _sprite(layout.well, CustomAssets.townWell),
        Positioned.fill(
          child: TownFolkLayer(
            motion: motion && layout.folkScale > 0,
            lane: layout.folkScale > 0
                ? layout.lane
                : Rect.fromLTWH(8, math.max(0, size.height - 52), 120, 36),
            scale: layout.folkScale > 0 ? layout.folkScale : 1,
            yardHeight: folkYardHeight,
          ),
        ),
        for (var i = 0; i < TownBuilding.frontRow.length; i++)
          _building(
            layout.front[i],
            TownBuilding.frontRow[i],
            TownBuilding.frontRow[i].assetPath(tier),
          ),
        for (final patch in layout.thresholds)
          if (!_coversLabel(patch, labels))
            _sprite(
              patch,
              CustomAssets.townWorn,
              fit: BoxFit.contain,
              align: Alignment.bottomCenter,
            ),
        if (TownTier.showArcade(state.ascensionLevel))
          Positioned(
            left: layout.doorPath.left + 16,
            right: 16,
            top: layout.doorPath.top,
            height: 14,
            child: const IgnorePointer(child: _TownArcade()),
          ),
        Positioned(
          left: layout.party.left,
          right: size.width - layout.party.right,
          bottom: 0,
          height: layout.party.height,
          child: _PartyRow(
            heroes: state.heroes,
            doll: partyDoll,
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: _TownDuskWash())),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: math.max(28, layout.grassTop + 8),
          child: const IgnorePointer(child: _TownSkyFog()),
        ),
        if (state.dungeonId == 'hell')
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(key: townHellWashKey, color: GameTheme.townHellWash),
            ),
          ),
        if (TownTier.showPennants(state.ascensionLevel) && layout.grassTop > 26)
          const Positioned(
            left: 16,
            right: 16,
            top: 2,
            height: 22,
            child: IgnorePointer(child: _TownPennants()),
          ),
        for (final (label, rect) in labels) _nameChip(label, rect),
      ],
    );
  }

  bool _coversLabel(Rect flower, List<(String, Rect)> labels) {
    for (final (_, label) in labels) {
      if (flower.overlaps(label.inflate(2))) return true;
    }
    return false;
  }

  /// Two cobble courses. The join is the shared mortar column in both tiles.
  Widget _street(Rect rect) {
    final scale = rect.height / 36.0;
    final joint = 180.0 * scale;
    final leftW = math.min(joint, rect.width);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: ClipRect(
          child: Row(
            children: [
              SizedBox(
                width: leftW,
                height: rect.height,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      CustomAssets.townPath,
                      height: rect.height,
                      fit: BoxFit.fitHeight,
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              if (rect.width > leftW + 1)
                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: Offset(-joint, 0),
                        child: Image.asset(
                          CustomAssets.townPathAlt,
                          height: rect.height,
                          fit: BoxFit.fitHeight,
                          filterQuality: FilterQuality.none,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A cobble spur. Native pixels, repeated only when the yard is taller
  /// than the sprite. The sprite's mortar joins, so the repeat is not a line.
  Widget _approach(Rect rect) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: ClipRect(
          child: Image.asset(
            CustomAssets.townApproach,
            fit: BoxFit.none,
            repeat: ImageRepeat.repeatY,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }

  String _plantingAsset(String key) {
    return switch (key) {
      'shrub' => CustomAssets.townShrub,
      'wild' => CustomAssets.townWild,
      'herbs' => CustomAssets.townHerbs,
      'meadow' => CustomAssets.townMeadow,
      'thicket' => CustomAssets.townThicket,
      'scuff' => CustomAssets.townScuff,
      _ => CustomAssets.townShrub,
    };
  }

  Widget _sprite(
    Rect rect,
    String asset, {
    BoxFit fit = BoxFit.contain,
    Alignment align = Alignment.bottomCenter,
  }) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Image.asset(
          asset,
          fit: fit,
          alignment: align,
          filterQuality: FilterQuality.none,
          excludeFromSemantics: true,
        ),
      ),
    );
  }

  Widget _building(Rect rect, TownBuilding building, String asset) {
    return Positioned.fromRect(
      rect: rect,
      child: _TownBuildingButton(
        building: building,
        assetPath: asset,
        badge: badgeOf(building.id),
        onTap: () => onTap(building),
      ),
    );
  }

  Widget _nameChip(String label, Rect rect) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              KenneyAssets.townNameplate,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              excludeFromSemantics: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GameTheme.hint(color: GameTheme.parchment),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner darkening. One static radial fill, no blur and no ticker.
class _TownDuskWash extends StatelessWidget {
  const _TownDuskWash();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.15),
          radius: 1.05,
          colors: [GameTheme.townWashNone, GameTheme.townVignette],
          stops: [0.72, 1],
        ),
      ),
    );
  }
}

/// Light plum mist over the sky band only. Static. Not a shader tick.
class _TownSkyFog extends StatelessWidget {
  const _TownSkyFog();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameTheme.townFog, GameTheme.townFogNone],
        ),
      ),
    );
  }
}

class _TownBackdrop extends StatelessWidget {
  const _TownBackdrop();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CustomAssets.townBackdrop,
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.none,
      excludeFromSemantics: true,
    );
  }
}

class _TownPennants extends StatelessWidget {
  const _TownPennants();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      KenneyAssets.townPennants,
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.none,
      excludeFromSemantics: true,
    );
  }
}

class _TownArcade extends StatelessWidget {
  const _TownArcade();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      KenneyAssets.townLanterns,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.none,
      excludeFromSemantics: true,
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.heroes, required this.doll});

  final List<PartyHero> heroes;
  final double doll;

  @override
  Widget build(BuildContext context) {
    final standW = doll * heroes.length;
    return Semantics(
      label: 'Party resting in town',
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset(
            CustomAssets.townContact,
            width: standW,
            height: 14,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < heroes.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: HeroDollSprite(
                      hero: heroes[i],
                      partyIndex: i,
                      size: doll,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TownBuildingButton extends StatelessWidget {
  const _TownBuildingButton({
    required this.building,
    required this.assetPath,
    required this.badge,
    required this.onTap,
  });

  final TownBuilding building;
  final String assetPath;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantics = badge
        ? '${building.label}, something waiting. ${building.description}'
        : '${building.label}. ${building.description}';
    return WebClickScope(
      label: building.label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: semantics,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('town-${building.id.name}'),
          onTap: onTap,
          child: _TownBuildingArt(
            assetPath: assetPath,
            badgeKey: badge ? ValueKey('town-alert-${building.id.name}') : null,
          ),
        ),
      ),
    );
  }
}

/// Building sprite plus its alert. The sprite is bottom-aligned "contain"
/// inside a wider rect, so the alert is pinned to the painted roof corner,
/// not the empty rect corner where it read as a torch (polish7 P011).
class _TownBuildingArt extends StatefulWidget {
  const _TownBuildingArt({required this.assetPath, this.badgeKey});

  final String assetPath;
  final Key? badgeKey;

  /// Alert face and its dark contrast ring.
  static const double alert = 22;
  static const double ring = 28;

  @override
  State<_TownBuildingArt> createState() => _TownBuildingArtState();
}

class _TownBuildingArtState extends State<_TownBuildingArt> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(_onImage);
  Size? _art;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _TownBuildingArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _art = null;
      _resolve();
    }
  }

  void _resolve() {
    final next = AssetImage(
      widget.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    if (mounted && size != _art) setState(() => _art = size);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.assetPath,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.none,
    );
    final badgeKey = widget.badgeKey;
    if (badgeKey == null) return image;
    return LayoutBuilder(
      builder: (context, box) {
        final outer = Offset.zero & box.biggest;
        var roof = outer;
        final art = _art;
        if (art != null && art.width > 0 && art.height > 0) {
          final fitted = applyBoxFit(BoxFit.contain, art, box.biggest);
          roof = Alignment.bottomCenter.inscribe(fitted.destination, outer);
        }
        const r = _TownBuildingArt.ring;
        final left = (roof.right - r * 0.75).clamp(0.0, outer.width - r);
        final top = (roof.top - r * 0.35).clamp(0.0, outer.height - r);
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            image,
            Positioned(
              left: left,
              top: top,
              width: r,
              height: r,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameTheme.ink.withValues(alpha: 0.78),
                    border: Border.all(color: GameTheme.torchHot, width: 2),
                  ),
                  child: Center(
                    child: Image.asset(
                      CustomAssets.townAlert,
                      key: badgeKey,
                      width: _TownBuildingArt.alert,
                      height: _TownBuildingArt.alert,
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TownLockedNote extends StatelessWidget {
  const _TownLockedNote({
    required this.title,
    required this.body,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MenuChrome.scrim,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DecoratedBox(
                  decoration: MenuChrome.panel(opaque: true),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // One exit: the CLOSE button below (polish7 P002).
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GameTheme.section(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: GameTheme.readable(),
                        ),
                        const SizedBox(height: GameTheme.clusterGap),
                        WebClickScope(
                          label: 'CLOSE',
                          onPressed: onClose,
                          child: GameButton(label: 'CLOSE', onPressed: onClose),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// When the first-session coach points at ENTER on the town card.
abstract final class TownEnterCoach {
  static const Key pulseKey = ValueKey('town-enter-coach');

  static bool active(GameState state) {
    if (state.inDungeon) return false;
    final climb = FirstClimbCoach.line(state, inDungeon: false);
    if (climb != null) return climb.contains('ENTER');
    final tip = FirstSessionTips.active(state, inDungeon: false);
    return tip?.target == CoachTarget.enter;
  }
}

/// Below the pennant tier the line names the town ([cave] is shown big
/// under it, so it is not repeated here).
/// At the tier it keeps [TownTier.progressLine], which says banners.
String townProgressLine({required int ascensionLevel, required String cave}) {
  if (TownTier.showPennants(ascensionLevel)) {
    return TownTier.progressLine(ascensionLevel);
  }
  // The cave name is the big line right under this one (audit F090).
  return ascensionLevel >= 1 ? 'Stone town' : 'Timber town';
}

/// What the town square paints. Gold is not in here, so a wallet tick
/// does not rebuild the buildings, the lawn, or the walkers.
class TownPaintToken {
  const TownPaintToken({
    required this.ascension,
    required this.dungeonId,
    required this.vaultOpen,
    required this.marketBadge,
    required this.innBadge,
    required this.guildBadge,
    required this.vaultBadge,
    required this.vfx,
    required this.portraits,
    this.motion = true,
  });

  final int ascension;
  final String dungeonId;
  final bool vaultOpen;
  final bool marketBadge;
  final bool innBadge;
  final bool guildBadge;
  final bool vaultBadge;
  final String vfx;
  final String portraits;
  final bool motion;

  static TownPaintToken of(GameState state) {
    final portraits = StringBuffer();
    for (final hero in state.heroes) {
      portraits
        ..write(hero.id)
        ..write('|')
        ..write(hero.specId.name)
        ..write('|')
        ..write(hero.level)
        ..write('|')
        ..write(hero.race.name)
        ..write('|')
        ..write(hero.sex.name);
      for (final entry in hero.equipped.entries) {
        final item = entry.value;
        portraits
          ..write('|')
          ..write(entry.key.name)
          ..write(':')
          ..write(item.id)
          ..write(':')
          ..write(item.visualSetId)
          ..write(':')
          ..write(item.iconId);
      }
      portraits.write(';');
    }
    return TownPaintToken(
      ascension: state.ascensionLevel,
      dungeonId: state.dungeonId,
      vaultOpen: TownAccess.vaultClaimedToday(state),
      marketBadge: !MenuAlerts.marketAlert(state).isQuiet,
      innBadge: state.metaDepth.pendingHeroReveals.isNotEmpty,
      guildBadge: state.missions.any((m) => m.canClaim),
      vaultBadge: TownAccess.vaultClaimable(state),
      vfx: state.vfxQuality.name,
      portraits: portraits.toString(),
    );
  }

  TownPaintToken withMotion(bool value) {
    if (value == motion) return this;
    return TownPaintToken(
      ascension: ascension,
      dungeonId: dungeonId,
      vaultOpen: vaultOpen,
      marketBadge: marketBadge,
      innBadge: innBadge,
      guildBadge: guildBadge,
      vaultBadge: vaultBadge,
      vfx: vfx,
      portraits: portraits,
      motion: value,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TownPaintToken &&
        other.ascension == ascension &&
        other.dungeonId == dungeonId &&
        other.vaultOpen == vaultOpen &&
        other.marketBadge == marketBadge &&
        other.innBadge == innBadge &&
        other.guildBadge == guildBadge &&
        other.vaultBadge == vaultBadge &&
        other.vfx == vfx &&
        other.portraits == portraits &&
        other.motion == motion;
  }

  @override
  int get hashCode => Object.hash(
    ascension,
    dungeonId,
    vaultOpen,
    marketBadge,
    innBadge,
    guildBadge,
    vaultBadge,
    vfx,
    portraits,
    motion,
  );
}

/// Returns the same child widget when [token] is unchanged, so a parent
/// rebuild (the root director listener) does not recreate [Image.asset]s.
class _Hold extends StatefulWidget {
  const _Hold({super.key, required this.token, required this.child});

  final TownPaintToken token;
  final Widget child;

  @override
  State<_Hold> createState() => _HoldState();
}

class _HoldState extends State<_Hold> {
  late TownPaintToken _token;
  late Widget _child;

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _child = widget.child;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token != _token) {
      _token = widget.token;
      _child = widget.child;
    }
    return _child;
  }
}

/// 360×780 harness so tests and previews pump the town without HomeShell.
class TownPreview extends StatelessWidget {
  const TownPreview({
    super.key,
    required this.director,
    required this.router,
    this.textScale = 1.0,
    this.size = phoneSize,
  });

  final GameDirector director;
  final MenuRouter router;
  final double textScale;
  final Size size;

  static const Size phoneSize = Size(360, 780);
  static const Size shortSize = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
      child: SizedBox.fromSize(
        size: size,
        child: ListenableBuilder(
          listenable: Listenable.merge([router, director]),
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                TownViewport(director: director, router: router),
                if (router.isOpen)
                  MenuSurface(director: director, router: router, home: false),
              ],
            );
          },
        ),
      ),
    );
  }
}
