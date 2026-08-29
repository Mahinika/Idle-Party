import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/game_director.dart';
import '../core/game_logic.dart';
import '../core/wipe_advice.dart';
import '../core/hero_identity.dart';
import '../core/meta_systems.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/vfx_quality.dart';
import '../spatial/spatial_combat.dart';
import '../spatial/tile_map.dart';
import 'custom_assets.dart';
import 'decoded_image_cache.dart';
import 'dungeon_environment.dart';
import 'game_theme.dart';
import 'hero_paper_doll.dart';
import 'kenney_assets.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';
import 'meta_overlays.dart';
import 'web_click_bridge.dart';

/// Top-down tile dungeon — painted, not 100+ Image widgets.
class SpatialDungeonView extends StatefulWidget {
  const SpatialDungeonView({super.key, required this.director});

  final GameDirector director;

  @override
  State<SpatialDungeonView> createState() => _SpatialDungeonViewState();
}

class _SpatialDungeonViewState extends State<SpatialDungeonView> {
  List<ui.Image> _floorReady = const [];
  List<ui.Image> _wallReady = const [];
  ui.Image? _stairs;
  ui.Image? _stairsBoss;
  ui.Image? _doorClosed;
  ui.Image? _doorOpen;
  ui.Image? _zoneStairs;
  ui.Image? _zoneStairsBoss;
  ui.Image? _zoneDoorClosed;
  ui.Image? _zoneDoorOpen;
  Map<MapPropKind, ui.Image?> _propImages = const {};
  ui.Image? _hero0;
  ui.Image? _hero1;
  ui.Image? _hero2;
  ui.Image? _hero3;
  final Map<HeroClassId, ui.Image?> _heroesByClass = {};
  ui.Image? _charAtlas;
  ui.Image? _chest;
  ui.Image? _coin;
  ui.Image? _sword;
  ui.Image? _vial;
  final Map<String, ui.Image> _lootByPath = <String, ui.Image>{};
  final Map<String, ui.Image> _petsByPath = <String, ui.Image>{};
  List<ui.Image?> _enemySprites = const [];
  String? _loadedDungeonId;
  bool _sharedLoaded = false;
  bool _offlineDialogShown = false;

  bool get _tilesReady =>
      _floorReady.isNotEmpty &&
      _wallReady.isNotEmpty &&
      (_zoneStairs ?? _stairs) != null &&
      (_zoneStairsBoss ?? _stairsBoss) != null &&
      (_zoneDoorClosed ?? _doorClosed) != null &&
      (_zoneDoorOpen ?? _doorOpen) != null;

  @override
  void initState() {
    super.initState();
    _loadImages(widget.director.state.dungeonId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOffline());
  }

  Future<void> _maybeShowOffline() async {
    if (_offlineDialogShown ||
        !mounted ||
        widget.director.offlineSummary == null) {
      return;
    }
    _offlineDialogShown = true;
    await showOfflineProgressDialog(context, widget.director);
  }

  @override
  void didUpdateWidget(covariant SpatialDungeonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.director.state.dungeonId;
    if (id != _loadedDungeonId) {
      _loadImages(id);
    }
  }

  Future<void> _loadImages(String dungeonId) async {
    Future<ui.Image> load(
      String asset, {
      int? targetWidth,
      int? targetHeight,
    }) => DecodedImageCache.load(
      asset,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    final floorPaths = KenneyAssets.floorVariantsForDungeon(dungeonId);
    final wallPaths = KenneyAssets.wallVariantsForDungeon(dungeonId);
    final propKinds = KenneyAssets.propPoolForDungeon(dungeonId).toSet()
      ..add(MapPropKind.chest);

    // Shared combat icons — decode once, keep across dungeon switches.
    if (!_sharedLoaded) {
      final lootPaths = <String>{
        KenneyAssets.chestClosed,
        KenneyAssets.coinGold,
        KenneyAssets.sword,
        KenneyAssets.swordAlt,
        KenneyAssets.axe,
        KenneyAssets.dagger,
        KenneyAssets.hammer,
        KenneyAssets.staff,
        KenneyAssets.staffBlue,
        KenneyAssets.spear,
        KenneyAssets.bow,
        KenneyAssets.crossbow,
        KenneyAssets.gun,
        KenneyAssets.wand,
        KenneyAssets.fist,
        KenneyAssets.thrown,
        KenneyAssets.shield,
        KenneyAssets.shieldRound,
        KenneyAssets.book,
        KenneyAssets.helmet,
        KenneyAssets.chestArmor,
        KenneyAssets.cloak,
        KenneyAssets.boots,
        KenneyAssets.gloves,
        KenneyAssets.shoulders,
        KenneyAssets.belt,
        CustomAssets.iconRing,
        CustomAssets.iconNeck,
        CustomAssets.iconWrist,
        CustomAssets.iconLegs,
        CustomAssets.iconTrinket,
        CustomAssets.iconTome,
        KenneyAssets.ring,
        KenneyAssets.potionRed,
        KenneyAssets.potionGreen,
        KenneyAssets.potionBlue,
        KenneyAssets.vialBlue,
        KenneyAssets.iconBow,
      }.toList();

      final petPaths = CustomAssets.petPortraitPaths;

      final shared = await Future.wait([
        load(KenneyAssets.stairs, targetWidth: 64),
        load(KenneyAssets.stairsBoss, targetWidth: 64),
        load(KenneyAssets.doorClosed, targetWidth: 64),
        load(KenneyAssets.doorOpen, targetWidth: 64),
        load(KenneyAssets.heroKnight, targetWidth: 128),
        load(KenneyAssets.heroHealer, targetWidth: 128),
        load(KenneyAssets.heroWizard, targetWidth: 128),
        load(KenneyAssets.heroRogue, targetWidth: 128),
        load(CustomAssets.heroPaladin, targetWidth: 128),
        load(CustomAssets.heroHunter, targetWidth: 128),
        load(CustomAssets.heroDeathKnight, targetWidth: 128),
        load(CustomAssets.heroShaman, targetWidth: 128),
        load(CustomAssets.heroWarlock, targetWidth: 128),
        load(CustomAssets.heroDruid, targetWidth: 128),
        // Keep native size — paper-doll src rects assume full atlas pixels.
        load(RoguelikeCharAtlas.assetPath),
        load(KenneyAssets.chestClosed, targetWidth: 64),
        load(KenneyAssets.coinGold, targetWidth: 48),
        load(KenneyAssets.sword, targetWidth: 48),
        load(KenneyAssets.vialBlue, targetWidth: 48),
        ...lootPaths.map((a) => load(a, targetWidth: 64)),
        ...petPaths.map((a) => load(a, targetWidth: 96)),
      ]);
      if (!mounted) return;

      var i = 0;
      _stairs = shared[i++];
      _stairsBoss = shared[i++];
      _doorClosed = shared[i++];
      _doorOpen = shared[i++];
      _hero0 = shared[i++];
      _hero1 = shared[i++];
      _hero2 = shared[i++];
      _hero3 = shared[i++];
      _heroesByClass
        ..clear()
        ..[HeroClassId.warrior] = _hero0
        ..[HeroClassId.priest] = _hero1
        ..[HeroClassId.mage] = _hero2
        ..[HeroClassId.rogue] = _hero3
        ..[HeroClassId.paladin] = shared[i++]
        ..[HeroClassId.hunter] = shared[i++]
        ..[HeroClassId.deathKnight] = shared[i++]
        ..[HeroClassId.shaman] = shared[i++]
        ..[HeroClassId.warlock] = shared[i++]
        ..[HeroClassId.druid] = shared[i++];
      _charAtlas = shared[i++];
      _chest = shared[i++];
      _coin = shared[i++];
      _sword = shared[i++];
      _vial = shared[i++];
      _lootByPath
        ..clear()
        ..addEntries([
          for (final path in lootPaths) MapEntry(path, shared[i++]),
        ]);
      _petsByPath
        ..clear()
        ..addEntries([
          for (final path in petPaths) MapEntry(path, shared[i++]),
        ]);
      _sharedLoaded = true;
    }

    // Only this zone's enemies — the catalog holds 24 sprites but a zone can
    // spawn at most a handful. Indices stay catalog-aligned because the
    // painter looks sprites up by `EnemyUnit.assetIndex`.
    final catalog = KenneyAssets.enemySpriteCatalog;
    final zoneEnemyAssets = KenneyAssets.enemySpritesForDungeon(dungeonId);
    final customDungeon = CustomAssets.usesCustomDungeonArt(dungeonId);
    final structuralPaths = customDungeon
        ? <String>[
            KenneyAssets.exitSpriteFor(boss: false, dungeonId: dungeonId),
            KenneyAssets.exitSpriteFor(boss: true, dungeonId: dungeonId),
            KenneyAssets.gateSprite(open: false, dungeonId: dungeonId),
            KenneyAssets.gateSprite(open: true, dungeonId: dungeonId),
          ]
        : const <String>[];

    final zone = await Future.wait([
      ...floorPaths.map((a) => load(a, targetWidth: 64)),
      ...wallPaths.map((a) => load(a, targetWidth: 64)),
      ...propKinds.map(
        (k) => load(
          KenneyAssets.propAsset(k, dungeonId: dungeonId),
          targetWidth: 64,
        ),
      ),
      ...zoneEnemyAssets.map((a) => load(a, targetWidth: 128)),
      ...structuralPaths.map((a) => load(a, targetWidth: 64)),
    ]);
    if (!mounted) return;

    var zi = 0;
    final floorVariants = zone.sublist(zi, zi + floorPaths.length);
    zi += floorPaths.length;
    final wallVariants = zone.sublist(zi, zi + wallPaths.length);
    zi += wallPaths.length;
    final propKindList = propKinds.toList();
    final propImages = <MapPropKind, ui.Image>{};
    for (final kind in propKindList) {
      propImages[kind] = zone[zi++];
    }
    final enemySprites = List<ui.Image?>.filled(catalog.length, null);
    for (final asset in zoneEnemyAssets) {
      enemySprites[KenneyAssets.enemySpriteCatalogIndex(asset)] = zone[zi++];
    }
    ui.Image? zoneStairs;
    ui.Image? zoneStairsBoss;
    ui.Image? zoneDoorClosed;
    ui.Image? zoneDoorOpen;
    if (customDungeon) {
      zoneStairs = zone[zi++];
      zoneStairsBoss = zone[zi++];
      zoneDoorClosed = zone[zi++];
      zoneDoorOpen = zone[zi++];
    }

    setState(() {
      _loadedDungeonId = dungeonId;
      _floorReady = floorVariants;
      _wallReady = wallVariants;
      _propImages = propImages;
      _enemySprites = enemySprites;
      _zoneStairs = zoneStairs;
      _zoneStairsBoss = zoneStairsBoss;
      _zoneDoorClosed = zoneDoorClosed;
      _zoneDoorOpen = zoneDoorOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final world = widget.director.spatial;
    final room = state.currentRoom;
    final farm = state.dungeonMode == DungeonMode.farm;
    final dailyEcho = MetaSystems.isActiveDailyRun(state);

    final frameColor = room.type == RoomType.boss
        ? GameTheme.borderLit
        : GameTheme.mossLit;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: frameColor.withValues(alpha: 0.85), width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          if (!widget.director.awaitingWipeChoice &&
              (state.isPartyDefeated || (world?.awaitingExit ?? false)))
            Material(
              color: state.isPartyDefeated
                  ? GameTheme.blood.withValues(alpha: 0.85)
                  : const Color(0xEE0A0907),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: state.isPartyDefeated
                    ? Text(
                        state.inGauntlet || state.inAnyRiftMode
                            ? 'WIPED — End Run returns to hub'
                            : 'WIPED — use the Retry / Hub panel',
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 15,
                          color: GameTheme.torchHot,
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.director.exitHoldActive
                                  ? 'HOLD — walk resumes soon'
                                  : 'GO — stairs are open',
                              textAlign: TextAlign.center,
                              style: GameTheme.body(
                                size: 15,
                                color: GameTheme.clear,
                              ),
                            ),
                          ),
                          if (!widget.director.exitHoldActive)
                            WebClickScope(
                              label: 'Hold at stairs',
                              onPressed: widget.director.startExitHold,
                              child: Semantics(
                                button: true,
                                label: 'Hold — pause walk to stairs for 8 seconds',
                                onTap: widget.director.startExitHold,
                                excludeSemantics: true,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: widget.director.startExitHold,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x332A4030),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: GameTheme.clear.withValues(
                                            alpha: 0.65,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'HOLD',
                                        style: GameTheme.pixel(
                                          size: GameTheme.hudPixel,
                                          color: GameTheme.clear,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final camera = _TileCamera.forWorld(
                  world,
                  constraints,
                  targetCols: state.dungeonZoom.targetCols,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    WebClickScope(
                      label: 'Dungeon map',
                      onPressed: () {
                        if (widget.director.awaitingWipeChoice) return;
                        if (state.isPartyDefeated) {
                          widget.director.reviveParty();
                          return;
                        }
                        // Mid-fight: pin nearest to party. Idle/clear: fist only.
                        final fighting =
                            world?.enemies.any((e) => e.isAlive) ?? false;
                        if (!fighting || world == null) return;
                        final alive =
                            world.heroes.where((h) => h.hp > 0).toList();
                        if (alive.isEmpty) return;
                        var cx = 0.0;
                        var cy = 0.0;
                        for (final h in alive) {
                          cx += h.x;
                          cy += h.y;
                        }
                        widget.director.setHudFocusAtWorld(
                          cx / alive.length,
                          cy / alive.length,
                        );
                      },
                      child: Semantics(
                        button: true,
                        label:
                            'Dungeon map — tap to pin target while fighting; '
                            'long-press for God Hand; fist button also works',
                        onTap: () {
                          if (widget.director.awaitingWipeChoice) return;
                          if (state.isPartyDefeated) {
                            widget.director.reviveParty();
                            return;
                          }
                          final fighting =
                              world?.enemies.any((e) => e.isAlive) ?? false;
                          if (!fighting || world == null) return;
                          final alive =
                              world.heroes.where((h) => h.hp > 0).toList();
                          if (alive.isEmpty) return;
                          var cx = 0.0;
                          var cy = 0.0;
                          for (final h in alive) {
                            cx += h.x;
                            cy += h.y;
                          }
                          widget.director.setHudFocusAtWorld(
                            cx / alive.length,
                            cy / alive.length,
                          );
                        },
                        onLongPress: widget.director.godHandAtFocus,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            if (widget.director.awaitingWipeChoice) return;
                            if (state.isPartyDefeated) {
                              widget.director.reviveParty();
                              return;
                            }
                            final tileX = camera.camX +
                                details.localPosition.dx / camera.tileSize;
                            final tileY = camera.camY +
                                details.localPosition.dy / camera.tileSize;
                            // Mid-pack: pin target HUD — fist / long-press for GH.
                            final fighting =
                                world?.enemies.any((e) => e.isAlive) ?? false;
                            if (fighting) {
                              widget.director.setHudFocusAtWorld(tileX, tileY);
                            }
                            // Idle / clear: map tap does not fire God Hand.
                          },
                          onLongPressStart: (details) {
                            if (widget.director.awaitingWipeChoice) return;
                            if (state.isPartyDefeated) return;
                            final tileX = camera.camX +
                                details.localPosition.dx / camera.tileSize;
                            final tileY = camera.camY +
                                details.localPosition.dy / camera.tileSize;
                            widget.director.godHandAtWorld(tileX, tileY);
                          },
                          child:
                              world == null ||
                                  !_tilesReady ||
                                  _enemySprites.isEmpty ||
                                  _sword == null ||
                                  _vial == null ||
                                  _charAtlas == null
                              ? ColoredBox(
                                  color: GameTheme.stone,
                                  child: Center(
                                    child: Text(
                                      'Loading floor…',
                                      style: GameTheme.body(
                                        size: 15,
                                        color: GameTheme.parchmentDim,
                                      ),
                                    ),
                                  ),
                                )
                              : RepaintBoundary(
                                  child: CustomPaint(
                                    size: Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                    painter: _TileRoomPainter(
                                      world: world,
                                      party: state.heroes,
                                      floorVariants: _floorReady,
                                      wallVariants: _wallReady,
                                      stairs: _zoneStairs ?? _stairs!,
                                      stairsBoss: _zoneStairsBoss ?? _stairsBoss!,
                                      doorClosed: _zoneDoorClosed ?? _doorClosed!,
                                      doorOpen: _zoneDoorOpen ?? _doorOpen!,
                                      propImages: _propImages,
                                      roomType: room.type,
                                      dungeonId: state.dungeonId,
                                      layoutSeed: world.map.layoutSeed,
                                      clearedChambers: world.clearedChambers,
                                      charAtlas: _charAtlas!,
                                      heroes: <ui.Image?>[
                                        _hero0,
                                        _hero1,
                                        _hero2,
                                        _hero3,
                                      ],
                                      heroesByClass: _heroesByClass,
                                      enemies: _enemySprites,
                                      chest: _chest!,
                                      coin: _coin!,
                                      sword: _sword!,
                                      vial: _vial!,
                                      lootByPath: _lootByPath,
                                      petsByPath: _petsByPath,
                                      camera: camera,
                                      vfxQuality: state.vfxQuality,
                                      visualFrame: widget.director.visualFrame,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (world != null && world.bossBannerTimer > 0)
                      Align(
                        alignment: const Alignment(0, -0.72),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEE3A1810),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GameTheme.torchHot),
                          ),
                          child: Text(
                            'BOSS — ${world.bossBannerName}',
                            style: GameTheme.pixel(
                              size: GameTheme.hudPixelComfort,
                              color: GameTheme.torchHot,
                            ),
                          ),
                        ),
                      ),
                    if (widget.director.clearSummary != null)
                      Align(
                        alignment: Alignment(
                          0,
                          (world != null && world.bossBannerTimer > 0)
                              ? 0.08
                              : -0.35,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEE1A2410),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: GameTheme.clear),
                          ),
                          child: Text(
                            widget.director.clearSummary!,
                            style: GameTheme.pixel(
                              size: GameTheme.hudPixelComfort,
                              color: GameTheme.clear,
                            ),
                          ),
                        ),
                      ),
                    if (widget.director.offlineSummary != null)
                      Align(
                        alignment: const Alignment(0, -0.55),
                        child: GestureDetector(
                          onTap: () => showOfflineProgressDialog(
                            context,
                            widget.director,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xEE1A2030),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: GameTheme.mossLit),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.director.offlineSummary!.headline,
                                  textAlign: TextAlign.center,
                                  style: GameTheme.pixel(
                                    size: GameTheme.hudPixel,
                                    color: GameTheme.mossLit,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap for details',
                                  style: GameTheme.body(
                                    size: 12,
                                    color: GameTheme.parchmentDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.director.awaitingWipeChoice)
                      ColoredBox(
                        color: MenuChrome.scrim,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: DecoratedBox(
                              decoration: MenuChrome.hubPanel(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'PARTY WIPED',
                                      style: GameTheme.pixel(
                                        size: 12,
                                        color: GameTheme.bloodLit,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      state.inGauntlet
                                          ? 'Gauntlet run ends here. PB F${state.metaDepth.gauntletBestFloor}. Return to hub to climb again.'
                                          : state.inGreaterRift
                                          ? 'Greater Rift ends here. Best tier ${state.metaDepth.grBestTier}. Return to hub to climb again.'
                                          : state.inRift
                                          ? 'Rift run ends here. Best tier ${state.metaDepth.riftBestTier}. Return to hub to try again.'
                                          : dailyEcho
                                          ? 'RETRY this floor · HUB ends run'
                                          : farm
                                          ? 'RETRY restarts this floor (F${state.currentRoom.floorNumber}). HUB ends the run.'
                                          : () {
                                              final safe = state
                                                  .highestFloorCleared
                                                  .clamp(1, 999);
                                              final cur =
                                                  state.currentRoom.floorNumber;
                                              if (safe >= cur) {
                                                return 'RETRY restarts this floor (F$cur, still PUSH). HUB ends the run.';
                                              }
                                              return 'RETRY retreats to F$safe (last cleared, still PUSH). HUB ends the run.';
                                            }(),
                                      textAlign: TextAlign.center,
                                      style: GameTheme.body(
                                        size: 15,
                                        color: GameTheme.parchmentDim,
                                      ),
                                    ),
                                    if (dailyEcho) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Claim needs a clear',
                                        textAlign: TextAlign.center,
                                        style: GameTheme.body(
                                          size: 12,
                                          color: GameTheme.parchmentDim,
                                        ),
                                      ),
                                    ],
                                    if (state.wipeAdviceLine.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        state.wipeAdviceLine,
                                        textAlign: TextAlign.center,
                                        style: GameTheme.body(
                                          size: 15,
                                          color: GameTheme.torchHot,
                                        ),
                                      ),
                                      if (WipeAdvice.hubHintFor(
                                            state.wipeAdviceLine,
                                          ) !=
                                          null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          WipeAdvice.hubHintFor(
                                            state.wipeAdviceLine,
                                          )!,
                                          textAlign: TextAlign.center,
                                          style: GameTheme.body(
                                            size: 13,
                                            color: GameTheme.parchmentDim,
                                          ),
                                        ),
                                      ],
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      WipeAdvice.timingFootnote,
                                      textAlign: TextAlign.center,
                                      style: GameTheme.body(
                                        size: 12,
                                        color: GameTheme.parchmentDim,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (!state.inGauntlet && !state.inAnyRiftMode)
                                      KenneyButton(
                                        label: (farm || dailyEcho)
                                            ? 'RETRY FLOOR'
                                            : () {
                                                final safe = state
                                                    .highestFloorCleared
                                                    .clamp(1, 999);
                                                final cur = state
                                                    .currentRoom
                                                    .floorNumber;
                                                return safe < cur
                                                    ? 'RETRY → F$safe'
                                                    : 'RETRY FLOOR';
                                              }(),
                                        tip: (farm || dailyEcho)
                                            ? 'Restarts this floor'
                                            : () {
                                                final safe = state
                                                    .highestFloorCleared
                                                    .clamp(1, 999);
                                                final cur = state
                                                    .currentRoom
                                                    .floorNumber;
                                                return safe < cur
                                                    ? 'Retreats to last cleared floor (PUSH)'
                                                    : 'Restarts this floor (still PUSH)';
                                              }(),
                                        primary: true,
                                        onPressed:
                                            widget.director.retryAfterWipe,
                                      ),
                                    if (!state.inGauntlet &&
                                        !state.inAnyRiftMode &&
                                        state.gearStash.length >=
                                            (GameLogic.maxGearStashFor(
                                                  state,
                                                ) -
                                                2)
                                                .clamp(
                                                  1,
                                                  GameLogic.maxGearStashFor(
                                                    state,
                                                  ),
                                                )) ...[
                                      const SizedBox(height: 8),
                                      KenneyButton(
                                        label: state.gearStash.length >=
                                                GameLogic.maxGearStashFor(
                                                  state,
                                                )
                                            ? 'CLEAN BAG'
                                            : 'CLEAN BAG (near full)',
                                        tip:
                                            'Sells junk / scraps leftovers so new drops fit',
                                        style: KenneyButtonStyle.grey,
                                        onPressed: () {
                                          widget.director.cleanBagJunk();
                                        },
                                      ),
                                    ],
                                    if (!state.inGauntlet && !state.inAnyRiftMode)
                                      const SizedBox(height: 8),
                                    KenneyButton(
                                      label: state.inGauntlet || state.inAnyRiftMode
                                          ? 'END RUN → HUB'
                                          : 'RETURN TO HUB',
                                      style: KenneyButtonStyle.grey,
                                      primary: true,
                                      onPressed: widget.director.hubAfterWipe,
                                    ),
                                    if (WipeAdvice.godHandHintFor(state) !=
                                        null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'After RETRY: ${WipeAdvice.godHandHintFor(state)!}',
                                        textAlign: TextAlign.center,
                                        style: GameTheme.body(
                                          size: 13,
                                          color: GameTheme.mossLit,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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

class ChamberDots extends StatelessWidget {
  const ChamberDots({super.key, required this.world});
  final SpatialWorld world;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, world.map.chambers.length);
    final cleared = world.clearedChambers.length;
    final active = world.activeChamber + 1;
    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: _ChamberDot(
              cleared: world.clearedChambers.contains(i),
              active: i == world.activeChamber,
            ),
          ),
      ],
    );
    return GestureDetector(
      onTap: () {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              'Chambers $active/$total · cleared $cleared · '
              'square=done · diamond=here · circle=ahead',
            ),
          ),
        );
      },
      child: Tooltip(
        message: 'Tap: chamber overview · square done · diamond here · circle ahead',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dots,
            if (total > 1) ...[
              const SizedBox(width: 4),
              Text(
                '$active/$total',
                style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shape + color so colorblind play can tell cleared / active / ahead.
class _ChamberDot extends StatelessWidget {
  const _ChamberDot({required this.cleared, required this.active});

  final bool cleared;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = cleared
        ? GameTheme.clear
        : (active ? GameTheme.torchHot : const Color(0xFF4A4030));
    if (cleared) {
      // Square = done.
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: GameTheme.border),
        ),
      );
    }
    if (active) {
      // Diamond = here.
      return Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: GameTheme.border),
          ),
        ),
      );
    }
    // Circle = ahead.
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: GameTheme.border),
      ),
    );
  }
}

class DungeonModeChip extends StatelessWidget {
  const DungeonModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
    this.tip,
    this.interactive = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;
  final String? tip;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = tip == null ? '$label dungeon mode' : '$label. $tip';
    final action = interactive ? onTap : null;
    final child = Container(
      constraints: BoxConstraints(minHeight: GameTheme.minTouch),
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF3A2810) : const Color(0xFF1A1610),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? GameTheme.torchHot : const Color(0xFF4A4030),
        ),
      ),
      child: Text(
        label,
        style: GameTheme.pixel(
          size: GameTheme.hudPixel,
          color: selected ? GameTheme.torchHot : GameTheme.parchmentDim,
        ),
      ),
    );
    if (!interactive) {
      return Semantics(
        label: semanticsLabel,
        child: child,
      );
    }
    return WebClickScope(
      label: semanticsLabel,
      onPressed: action,
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: semanticsLabel,
        onTap: action,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(3),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GodHandRing extends StatelessWidget {
  const GodHandRing({
    super.key,
    required this.cooldown,
    this.maxCooldown = 1.1,
    this.onTap,
    this.urgent = false,
    this.readyLabel,
    this.coolingLabel,
  });
  final double cooldown;

  /// Full CD length (matches [GameState.godHandCooldownSeconds]).
  final double maxCooldown;
  final VoidCallback? onTap;

  /// Brighter ring after repeated wipes on the same floor (nudge, not redesign).
  final bool urgent;

  /// Override ready / cooling semantics (first-hour plain English).
  final String? readyLabel;
  final String? coolingLabel;

  @override
  Widget build(BuildContext context) {
    final ready = cooldown <= 0;
    final cdMax = maxCooldown > 0.05 ? maxCooldown : 1.1;
    final t = ready ? 1.0 : (1.0 - (cooldown / cdMax).clamp(0.0, 1.0));
    final color = ready
        ? (urgent ? GameTheme.accentWarn : GameTheme.torchHot)
        : GameTheme.parchmentDim;
    final label = ready
        ? (readyLabel ??
            (urgent
                ? 'God Hand ready — TAP to steer + smash'
                : 'God Hand ready'))
        : (coolingLabel ?? 'God Hand ${cooldown.toStringAsFixed(1)}s');
    final action = onTap != null && ready ? onTap : null;
    return WebClickScope(
      label: label,
      onPressed: action,
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(14),
            child: Semantics(
              button: true,
              enabled: action != null,
              label: label,
              onTap: action,
              excludeSemantics: true,
              child: SizedBox(
                width: GameTheme.minTouch,
                height: GameTheme.minTouch,
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          painter: _GodHandRingPainter(
                            progress: t,
                            color: color,
                            ready: ready,
                          ),
                          child: Center(
                            child: ready
                                ? KenneySprite(
                                    asset: KenneyAssets.fist,
                                    size: 18,
                                    color: color,
                                  )
                                : Text(
                                    cooldown < 10
                                        ? cooldown.toStringAsFixed(1)
                                        : '${cooldown.round()}',
                                    style: GameTheme.pixel(
                                      size: 6,
                                      color: color,
                                    ),
                                  ),
                          ),
                        ),
                        if (urgent && ready)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Text(
                              '!',
                              style: GameTheme.pixel(
                                size: 8,
                                color: GameTheme.accentWarn,
                              ),
                            ),
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

class _GodHandRingPainter extends CustomPainter {
  _GodHandRingPainter({
    required this.progress,
    required this.color,
    required this.ready,
  });

  final double progress;
  final Color color;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 1.5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = GameTheme.ink.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = GameTheme.border.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ready ? 2.8 : 2.2
        ..strokeCap = StrokeCap.square,
    );
    if (ready) {
      canvas.drawCircle(
        c,
        r + 1.5,
        Paint()
          ..color = GameTheme.torch.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GodHandRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.ready != ready;
}

class _TileRoomPainter extends CustomPainter {
  _TileRoomPainter({
    required this.world,
    required this.party,
    required this.floorVariants,
    required this.wallVariants,
    required this.stairs,
    required this.stairsBoss,
    required this.doorClosed,
    required this.doorOpen,
    required this.propImages,
    required this.roomType,
    required this.dungeonId,
    required this.layoutSeed,
    required this.clearedChambers,
    required this.charAtlas,
    required this.heroes,
    required this.heroesByClass,
    required this.enemies,
    required this.chest,
    required this.coin,
    required this.sword,
    required this.vial,
    required this.lootByPath,
    required this.petsByPath,
    required this.camera,
    this.vfxQuality = VfxQuality.full,
    required this.visualFrame,
  });

  final SpatialWorld world;
  final List<PartyHero> party;
  final List<ui.Image> floorVariants;
  final List<ui.Image> wallVariants;
  final ui.Image stairs;
  final ui.Image stairsBoss;
  final ui.Image doorClosed;
  final ui.Image doorOpen;
  final Map<MapPropKind, ui.Image?> propImages;
  final RoomType roomType;
  final String dungeonId;
  final int layoutSeed;
  final Set<int> clearedChambers;
  final ui.Image charAtlas;
  final List<ui.Image?> heroes;
  final Map<HeroClassId, ui.Image?> heroesByClass;
  final List<ui.Image?> enemies;
  final ui.Image chest;
  final ui.Image coin;
  final ui.Image sword;
  final ui.Image vial;
  final Map<String, ui.Image> lootByPath;
  final Map<String, ui.Image> petsByPath;
  final _TileCamera camera;
  final VfxQuality vfxQuality;
  final int visualFrame;

  bool get reducedVfx => vfxQuality.reduced;
  bool get showAuras => vfxQuality.showActorAuras;
  bool get showGuide => vfxQuality.showGuideAndPulse;
  bool get showBursts => vfxQuality.showBurstsAndFloaters;
  bool get showGround => vfxQuality.showGroundFx;
  bool get showTrails => vfxQuality.showProjectileTrails;
  bool get showLootPulse => vfxQuality.showLootPulse;

  Size? _vignetteSize;
  Paint? _vignettePaint;
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  static int _hashPick(int x, int y, int seed, int len) {
    if (len <= 0) return 0;
    final h = x * 73856093 ^ y * 19349663 ^ seed;
    return ((h % len) + len) % len;
  }

  bool _inView(double tx, double ty, {double pad = 1.25}) {
    return tx >= camera.camX - pad &&
        tx <= camera.camX + camera.visibleCols + pad &&
        ty >= camera.camY - pad &&
        ty <= camera.camY + camera.visibleRows + pad;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = camera.tileSize;
    final originX = -camera.camX * tile;
    final originY = -camera.camY * tile;
    final ambient = DungeonEnvironment.ambient(dungeonId);
    // Let the painted zone backdrop show through void / wall space.
    _fillPaint.color = ambient.withValues(alpha: 0.55);
    canvas.drawRect(Offset.zero & size, _fillPaint);

    final startX = camera.camX.floor().clamp(0, world.cols - 1);
    final endX = (camera.camX + camera.visibleCols).ceil().clamp(0, world.cols);
    final startY = camera.camY.floor().clamp(0, world.rows - 1);
    final endY = (camera.camY + camera.visibleRows).ceil().clamp(0, world.rows);

    final floorBlend = DungeonEnvironment.floorBlend(dungeonId);
    final corridorShade = DungeonEnvironment.corridorShade(dungeonId);

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final kind = world.map.at(x, y);
        final gate = kind == TileKind.gate ? world.map.gateAt(x, y) : null;
        final gateOpen = gate != null && world.openGateIds.contains(gate.id);
        final dst = Rect.fromLTWH(
          originX + x * tile,
          originY + y * tile,
          tile + 0.5,
          tile + 0.5,
        );

        if (kind == TileKind.wall) {
          // Void fill + thin wall caps toward carved space (no solid brick mass).
          if (DungeonEnvironment.wallTouchesCarved(world.map, x, y) &&
              wallVariants.isNotEmpty) {
            final img =
                wallVariants[_hashPick(
                  x,
                  y,
                  layoutSeed + 17,
                  wallVariants.length,
                )];
            _drawWallCaps(canvas, x, y, dst, tile, img);
          }
          continue;
        }

        // All carved tiles share one floor base.
        final floorImg =
            floorVariants[_hashPick(x, y, layoutSeed, floorVariants.length)];
        _drawImage(canvas, floorImg, dst);
        // Mute Kenney tile chroma so painted backdrop + zone wash dominate.
        _fillPaint.color = floorBlend;
        canvas.drawRect(dst, _fillPaint);

        final noise = DungeonEnvironment.floorNoise(x, y, layoutSeed);
        if (noise.a > 0) {
          _fillPaint.color = noise;
          canvas.drawRect(dst, _fillPaint);
        }

        if (!DungeonEnvironment.inChamber(world.map, x, y) &&
            kind != TileKind.spawn &&
            kind != TileKind.exit) {
          _fillPaint.color = corridorShade;
          canvas.drawRect(dst, _fillPaint);
        }

        if (kind == TileKind.gate) {
          // Only the center cell of a 3-wide gate strip draws a door sprite.
          if (_isGateDoorCenter(x, y)) {
            final door = gateOpen ? doorOpen : doorClosed;
            final eastWest = DungeonEnvironment.gateRunsEastWest(
              world.map,
              x,
              y,
            );
            _drawOrientedDoor(canvas, door, dst, rotate: eastWest);
            if (!gateOpen) {
              _fillPaint.color = const Color(0x44000000);
              canvas.drawRect(dst, _fillPaint);
            }
          } else if (!gateOpen) {
            // Side cells: sealed stubs, not extra door panels.
            _fillPaint.color = const Color(0x55000000);
            canvas.drawRect(dst, _fillPaint);
          }
        } else if (kind == TileKind.exit) {
          final exitImg = roomType == RoomType.boss ? stairsBoss : stairs;
          _drawImage(canvas, exitImg, dst);
          if (world.awaitingExit) {
            if (showGuide) {
              final pulse = 0.75 + 0.25 * math.sin(visualFrame * 0.18);
              canvas.drawCircle(
                dst.center,
                tile * 0.55 * pulse,
                Paint()
                  ..color = const Color(0x6670E0A0)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = math.max(2, tile * 0.08),
              );
              canvas.drawCircle(
                dst.center,
                tile * 0.32 * pulse,
                Paint()..color = const Color(0x3380FFB0),
              );
            }
            // GO stays visible even on Minimal VFX — stairs must stay obvious.
            final go = TextPainter(
              text: TextSpan(
                text: 'GO',
                style: GameTheme.pixelCached(
                  size: math.max(GameTheme.hudPixelComfort, tile * 0.42),
                  color: const Color(0xEE80FFB0),
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            go.paint(
              canvas,
              Offset(dst.center.dx - go.width / 2, dst.top - go.height - 2),
            );
            go.dispose();
          }
        } else if (kind == TileKind.spawn) {
          _fillPaint.color = const Color(0x14C88840);
          canvas.drawRect(dst, _fillPaint);
        }
      }
    }

    // Zone atmosphere wash over terrain (under actors).
    _fillPaint.color = DungeonEnvironment.atmosphereWash(dungeonId);
    canvas.drawRect(Offset.zero & size, _fillPaint);

    // Soft vignette so the play space feels framed by the cave.
    if (_vignettePaint == null || _vignetteSize != size) {
      _vignetteSize = size;
      _vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.longestSide * 0.78,
          const [Color(0x00000000), Color(0x55000000), Color(0xBB000000)],
          const [0.28, 0.65, 1.0],
        );
    }
    canvas.drawRect(Offset.zero & size, _vignettePaint!);

    for (final chamber in world.map.chambers) {
      if (!clearedChambers.contains(chamber.index)) continue;
      // Soft clear wash only — no giant stamp clutter.
      canvas.drawRect(
        Rect.fromLTWH(
          originX + chamber.x * tile,
          originY + chamber.y * tile,
          chamber.w * tile,
          chamber.h * tile,
        ),
        Paint()..color = const Color(0x1818A050),
      );
    }

    // Lasting ground discs under actors (Consecration / Bladestorm / etc.).
    // Lite keeps these; Minimal (reduce motion) hides them.
    if (showGround) {
      for (final g in world.groundFx) {
        if (!_inView(g.x, g.y, pad: g.radius)) continue;
        final frac = (g.life / g.maxLife).clamp(0.0, 1.0);
        final c = Offset(originX + g.x * tile, originY + g.y * tile);
        final r = tile * g.radius;
        final color = Color(g.argb);
        canvas.drawCircle(
          c,
          r,
          Paint()..color = color.withValues(alpha: 0.18 * frac),
        );
        _paintGroundKind(canvas, c, r, color, frac, tile, g.kind, g.life);
      }
    }

    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

    void drawSprite(
      ui.Image image,
      Offset c,
      double scale, {
      double alpha = 1,
      Color? tint,
      bool flipX = false,
    }) {
      final s = tile * scale;
      final dst = Rect.fromCenter(center: c, width: s, height: s);
      if (flipX) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(-1, 1);
        canvas.translate(-c.dx, -c.dy);
        _drawImage(canvas, image, dst, alpha: alpha, tint: tint);
        canvas.restore();
      } else {
        _drawImage(canvas, image, dst, alpha: alpha, tint: tint);
      }
    }

    for (final prop in world.map.props) {
      if (!_inView(prop.x + 0.5, prop.y + 0.5, pad: 0.75)) continue;
      final img = propImages[prop.kind];
      if (img == null) continue;
      final c = center(prop.x + 0.5, prop.y + 0.5);
      // Soft ground shadow so clutter reads against flat floor tiles.
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, tile * 0.18),
          width: tile * 0.55,
          height: tile * 0.22,
        ),
        Paint()..color = const Color(0x66000000),
      );
      drawSprite(img, c, 0.80);
    }

    void drawBar(Offset c, int hp, int maxHp, double width) {
      final frac = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
      final top = c.dy - tile * 0.55;
      final left = c.dx - width / 2;
      final cb = SpatialCombat.colorblindMode;
      final Color fill;
      if (hp <= 0) {
        fill = cb ? const Color(0xFFD55E00) : const Color(0xFFE05050);
      } else if (frac <= 0.35) {
        fill = cb ? const Color(0xFFE69F00) : const Color(0xFFE87850);
      } else {
        fill = cb ? const Color(0xFF009E73) : const Color(0xFFE05050);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, 4),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xAA000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width * frac, 4),
          const Radius.circular(1),
        ),
        Paint()..color = fill,
      );
    }

    for (final loot in world.groundLoot) {
      if (!_inView(loot.x, loot.y)) continue;
      final bob = math.sin(loot.age * 9) * 0.12;
      final path = KenneyAssets.lootDropIconFor(loot.drop);
      final img =
          lootByPath[path] ??
          switch (loot.kind) {
            GroundLootKind.gold => coin,
            GroundLootKind.essence => vial,
            GroundLootKind.gear => sword,
            GroundLootKind.chest => chest,
          };
      final c = center(loot.x, loot.y + bob);
      final glow = switch (loot.drop.rarity) {
        LootRarity.common => const Color(0x66C8C0A8),
        LootRarity.uncommon => const Color(0x8870C050),
        LootRarity.rare => const Color(0x9950A0FF),
        LootRarity.epic => const Color(0xBBFFE08A),
        LootRarity.legendary => const Color(0xDDFF8C40),
      };
      final pulse = showLootPulse ? 0.85 + 0.15 * math.sin(loot.age * 6) : 1.0;
      _fillPaint.color = glow;
      canvas.drawCircle(
        c,
        tile * (0.32 + loot.drop.rarity.index * 0.04) * pulse,
        _fillPaint,
      );
      if (showLootPulse && loot.age > 0.28) {
        SpatialActor? magnet;
        var best = 4.6;
        for (final h in world.heroes) {
          if (h.hp <= 0) continue;
          final dx = h.x - loot.x;
          final dy = h.y - loot.y;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < best && d > 0.55) {
            best = d;
            magnet = h;
          }
        }
        if (magnet != null) {
          final hc = center(magnet.x, magnet.y);
          _strokePaint
            ..color = glow.withValues(alpha: 0.45)
            ..strokeWidth = math.max(1.2, tile * 0.055);
          canvas.drawLine(c, hc, _strokePaint);
        }
      }
      if (showLootPulse && loot.drop.rarity.index >= LootRarity.rare.index) {
        _strokePaint
          ..color = glow.withValues(alpha: 0.35)
          ..strokeWidth = 2;
        canvas.drawCircle(c, tile * 0.42 * pulse, _strokePaint);
      }
      drawSprite(img, c, loot.kind == GroundLootKind.chest ? 0.55 : 0.48);
    }

    if (showGuide &&
        world.pulseTimer > 0 &&
        world.pulseX != null &&
        world.pulseY != null) {
      final progress = (1 - world.pulseTimer / 0.35).clamp(0.0, 1.0);
      canvas.drawCircle(
        center(world.pulseX!, world.pulseY!),
        tile * (0.4 + progress * 2.4),
        Paint()
          ..color = const Color(0xDFFFF0A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, tile * 0.1),
      );
    }

    // God Hand aim marker + radius while guiding the party.
    if (showGuide &&
        world.guideTimer > 0 &&
        world.guideX != null &&
        world.guideY != null) {
      final gc = center(world.guideX!, world.guideY!);
      final pulse = 0.85 + 0.15 * math.sin(world.guideTimer * 10);
      final r = tile * world.godHandRadius * pulse;
      canvas.drawCircle(
        gc,
        r,
        Paint()
          ..color = const Color(0x55FFE080)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, tile * 0.06),
      );
      canvas.drawCircle(
        gc,
        tile * 0.22 * pulse,
        Paint()..color = const Color(0xAAFFF0A0),
      );
      canvas.drawCircle(
        gc,
        tile * 0.1,
        Paint()..color = const Color(0xFFFFF8D0),
      );
    }

    for (final p in world.projectiles) {
      if (p.delay > 0) continue;
      if (!_inView(p.x, p.y)) continue;
      final c = center(p.x, p.y);
      final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
      final angle = speed > 0.01 ? math.atan2(p.vy, p.vx) : 0.0;
      final baseColor = switch (p.style) {
        SpellBoltStyle.fire =>
          p.label == 'PYRO' ? const Color(0xFFFF4010) : const Color(0xFFFF9030),
        SpellBoltStyle.holy => const Color(0xFFFFF0A0),
        SpellBoltStyle.frost => const Color(0xFF90D8FF),
        SpellBoltStyle.arcane => const Color(0xFFC070FF),
        SpellBoltStyle.shadow => const Color(0xFFB060E0),
        SpellBoltStyle.nature => const Color(0xFF70D070),
        SpellBoltStyle.lightning => const Color(0xFFB8F0FF),
        SpellBoltStyle.arrow => const Color(0xFFD8C070),
        SpellBoltStyle.weapon =>
          p.team == SpatialTeam.hero
              ? (p.isCrit ? const Color(0xFFFFF0C0) : const Color(0xFFFFE08A))
              : const Color(0xFFFF6A4A),
      };
      final zoneTint = DungeonEnvironment.projectileTint(dungeonId);
      final color = Color.lerp(baseColor, zoneTint, 0.28)!;
      final len = tile * (p.pierce ? 0.55 : (0.35 + p.radius));
      final thick = math.max(2.0, tile * (0.08 + p.radius * 0.45));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);

      void drawTrailBolt() {
        if (!showTrails) {
          // Lite/Minimal: short bright slash nub — readable on phone.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -len * 0.35,
                -thick * 0.55,
                len * 0.75,
                thick * 1.1,
              ),
              Radius.circular(thick * 0.45),
            ),
            Paint()..color = color,
          );
          canvas.drawCircle(
            Offset(len * 0.35, 0),
            thick * 0.65,
            Paint()..color = Colors.white.withValues(alpha: 0.9),
          );
          return;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.85, -thick * 1.05, len * 1.15, thick * 2.1),
            Radius.circular(thick),
          ),
          Paint()..color = color.withValues(alpha: 0.32),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.55, -thick * 0.55, len, thick * 1.1),
            Radius.circular(thick * 0.5),
          ),
          Paint()..color = color,
        );
        canvas.drawCircle(
          Offset(len * 0.45, 0),
          thick * 0.85,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }

      void drawOrb({required double core, Color? glow}) {
        if (showTrails) {
          canvas.drawCircle(
            Offset(-len * 0.15, 0),
            thick * 1.5,
            Paint()..color = (glow ?? color).withValues(alpha: 0.22),
          );
        }
        canvas.drawCircle(Offset.zero, thick * core, Paint()..color = color);
        canvas.drawCircle(
          Offset.zero,
          thick * 0.4,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }

      switch (p.style) {
        case SpellBoltStyle.fire:
          // Fireball: orb + trailing flame wedge.
          drawOrb(core: p.label == 'PYRO' ? 1.35 : 1.05);
          final flame = Path()
            ..moveTo(-len * 0.85, 0)
            ..lineTo(-len * 0.15, -thick * 1.15)
            ..lineTo(-len * 0.05, 0)
            ..lineTo(-len * 0.15, thick * 1.15)
            ..close();
          canvas.drawPath(
            flame,
            Paint()..color = const Color(0xCCFF5010),
          );
        case SpellBoltStyle.holy:
          drawOrb(core: 1.1, glow: const Color(0xFFFFF8D0));
          canvas.drawLine(
            Offset(0, -thick * 1.4),
            Offset(0, thick * 1.4),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = math.max(1.4, thick * 0.35)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            Offset(-thick * 1.05, 0),
            Offset(thick * 1.05, 0),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = math.max(1.4, thick * 0.35)
              ..strokeCap = StrokeCap.round,
          );
        case SpellBoltStyle.frost:
          // Icy shard / frostbolt orb
          canvas.drawCircle(
            Offset(-len * 0.2, 0),
            thick * 1.4,
            Paint()..color = color.withValues(alpha: 0.2),
          );
          final ice = Path()
            ..moveTo(len * 0.55, 0)
            ..lineTo(-len * 0.35, -thick * 1.1)
            ..lineTo(-len * 0.15, 0)
            ..lineTo(-len * 0.35, thick * 1.1)
            ..close();
          canvas.drawPath(ice, Paint()..color = color);
          canvas.drawCircle(
            Offset.zero,
            thick * 0.55,
            Paint()..color = const Color(0xFFE8F8FF),
          );
        case SpellBoltStyle.arcane:
          drawOrb(core: 1.15, glow: const Color(0xFFE0A0FF));
          canvas.drawCircle(
            Offset.zero,
            thick * 1.35,
            Paint()
              ..color = color.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, thick * 0.25),
          );
        case SpellBoltStyle.shadow:
          canvas.drawCircle(
            Offset(-len * 0.25, 0),
            thick * 1.7,
            Paint()..color = const Color(0x66201040),
          );
          drawOrb(core: 1.05, glow: const Color(0xFF602090));
          // Eye slits so Death Coil / Shadow Bolt read as shadow, not purple fire.
          canvas.drawCircle(
            Offset(-thick * 0.25, -thick * 0.2),
            thick * 0.18,
            Paint()..color = const Color(0xFFFFE080),
          );
          canvas.drawCircle(
            Offset(thick * 0.28, -thick * 0.2),
            thick * 0.18,
            Paint()..color = const Color(0xFFFFE080),
          );
        case SpellBoltStyle.nature:
          drawOrb(core: 1.05, glow: const Color(0xFFA0E080));
          // Leaf tip
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(len * 0.35, 0),
              width: thick * 1.4,
              height: thick * 0.7,
            ),
            Paint()..color = const Color(0xFFB8F090),
          );
        case SpellBoltStyle.lightning:
          // Zigzag bolt
          final zig = Path()
            ..moveTo(-len * 0.55, -thick * 0.2)
            ..lineTo(-len * 0.1, thick * 0.9)
            ..lineTo(len * 0.05, -thick * 0.6)
            ..lineTo(len * 0.55, thick * 0.15);
          canvas.drawPath(
            zig,
            Paint()
              ..color = color.withValues(alpha: 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = thick * 1.6
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawPath(
            zig,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = thick * 0.55
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(
            Offset(len * 0.55, 0),
            thick * 0.65,
            Paint()..color = Colors.white,
          );
        case SpellBoltStyle.arrow:
          // Shaft
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -len * 0.65,
                -thick * 0.28,
                len * 1.05,
                thick * 0.56,
              ),
              Radius.circular(thick * 0.2),
            ),
            Paint()..color = const Color(0xFF8A6230),
          );
          // Fletching
          final fletch = Path()
            ..moveTo(-len * 0.55, 0)
            ..lineTo(-len * 0.85, -thick * 1.15)
            ..lineTo(-len * 0.4, 0)
            ..lineTo(-len * 0.85, thick * 1.15)
            ..close();
          canvas.drawPath(fletch, Paint()..color = const Color(0xFFC05040));
          // Arrowhead
          final head = Path()
            ..moveTo(len * 0.55, 0)
            ..lineTo(len * 0.15, -thick * 1.05)
            ..lineTo(len * 0.2, 0)
            ..lineTo(len * 0.15, thick * 1.05)
            ..close();
          canvas.drawPath(head, Paint()..color = const Color(0xFFD0D4D8));
        case SpellBoltStyle.weapon:
          drawTrailBolt();
      }
      canvas.restore();
    }

    if (world.isTreasure) {
      final ex = world.map.exitPoint;
      drawSprite(chest, center(ex.$1 + 0.5, ex.$2 + 0.5), 1.1);
    }

    for (final enemy in world.enemies) {
      if (enemy.dormant || !_inView(enemy.x, enemy.y)) continue;
      final img = enemies.isEmpty
          ? null
          : enemies[enemy.assetIndex.clamp(0, enemies.length - 1)];
      if (img == null) continue;
      final flash = enemy.attackFlash;
      final c = center(enemy.x, enemy.y);
      final scale =
          (enemy.role == EnemyRole.boss ? 1.05 : 0.9) * (1 + flash * 0.18);
      drawSprite(img, c, scale, alpha: enemy.isAlive ? 1 : 0.2);
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.35 * flash,
          Paint()..color = const Color(0x66FFE8A0),
        );
      }
      if (enemy.isAlive) {
        if (enemy.livingBombTimer > 0) {
          final pulse = 0.85 + 0.15 * math.sin(enemy.livingBombTimer * 10);
          canvas.drawCircle(
            c,
            tile * 0.5 * pulse,
            Paint()..color = const Color(0x66FF5020),
          );
          canvas.drawCircle(
            c,
            tile * 0.5 * pulse,
            Paint()
              ..color = const Color(0xCCFF7030)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.07),
          );
          // Fuse spark
          canvas.drawCircle(
            Offset(c.dx, c.dy - tile * 0.42),
            tile * 0.1,
            Paint()..color = const Color(0xFFFFF0A0),
          );
        }
        if (enemy.sunderStacks > 0 && enemy.sunderTimer > 0) {
          canvas.drawCircle(
            c,
            tile * 0.4,
            Paint()
              ..color = const Color(0x88C0A070)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, tile * 0.05),
          );
        }
        if (enemy.rootTimer > 0) {
          canvas.drawCircle(
            c,
            tile * 0.36,
            Paint()..color = const Color(0x6680D0FF),
          );
          // Stun stars
          for (var i = 0; i < 3; i++) {
            final a = enemy.rootTimer * 4 + i * 2.1;
            canvas.drawCircle(
              Offset(
                c.dx + math.cos(a) * tile * 0.42,
                c.dy + math.sin(a) * tile * 0.28 - tile * 0.35,
              ),
              tile * 0.07,
              Paint()..color = const Color(0xFFFFF0A0),
            );
          }
        }
        if (showAuras && enemy.enrageTimer > 0) {
          final pulse = 0.9 + 0.1 * math.sin(enemy.enrageTimer * 12);
          canvas.drawCircle(
            c,
            tile * 0.52 * pulse,
            Paint()
              ..color = const Color(0xAAFF3030)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, tile * 0.08),
          );
          canvas.drawCircle(
            c,
            tile * 0.28,
            Paint()..color = const Color(0x44FF5020),
          );
        }
        drawBar(c, enemy.hp, enemy.maxHp, tile * 0.85);
      }
    }

    for (final hero in world.heroes) {
      final idx = hero.assetIndex
          .clamp(0, math.max(0, party.length - 1))
          .toInt();
      final partyHero = party.isEmpty ? null : party[idx];
      final flash = hero.attackFlash;
      var c = center(hero.x, hero.y);
      // Prefer smoothed face aim; fall back to attack punch aim.
      final aimX = (hero.faceAimX != 0 || hero.faceAimY != 0)
          ? hero.faceAimX
          : hero.attackAimX;
      final aimY = (hero.faceAimX != 0 || hero.faceAimY != 0)
          ? hero.faceAimY
          : hero.attackAimY;
      // Melee lunge toward the target while attacking (warrior especially).
      if (flash > 0.02 && (aimX != 0 || aimY != 0)) {
        final adx = aimX - hero.x;
        final ady = aimY - hero.y;
        final alen = math.sqrt(adx * adx + ady * ady);
        if (alen > 0.05) {
          final punch = hero.heroRole == HeroRole.warrior ? 0.38 : 0.22;
          c = Offset(
            c.dx + (adx / alen) * tile * punch * flash,
            c.dy + (ady / alen) * tile * punch * flash,
          );
        }
      } else if (aimX != 0 || aimY != 0) {
        // Tiny lean toward facing so idle kits don't look glued forward.
        final adx = aimX - hero.x;
        final ady = aimY - hero.y;
        final alen = math.sqrt(adx * adx + ady * ady);
        if (alen > 0.08) {
          c = Offset(
            c.dx + (adx / alen) * tile * 0.06,
            c.dy + (ady / alen) * tile * 0.04,
          );
        }
      }
      final flipX = (aimX - hero.x) < -0.15;
      final scale =
          0.95 * (1 + flash * (hero.heroRole == HeroRole.warrior ? 0.32 : 0.2));
      final alpha = hero.isAlive ? 1.0 : 0.25;
      // Prefer class sprite from active party hero when available.
      ui.Image? img;
      Color? tint;
      if (partyHero != null) {
        img = heroesByClass[HeroIdentity.spriteClassFor(partyHero.specId)];
        final argb = HeroIdentity.tintArgb(partyHero.specId);
        if (argb != null) tint = Color(argb);
      }
      img ??= heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
      if (img != null) {
        drawSprite(
          img,
          c,
          scale,
          alpha: hero.vanishTimer > 0 ? 0.35 : alpha,
          tint: tint,
          flipX: flipX,
        );
      } else if (partyHero != null) {
        final walk = flash > 0.05
            ? 1
            : ((hero.x + hero.y) * 3).floor().abs() % 2;
        HeroPaperDoll.paint(
          canvas,
          charAtlas,
          c,
          tile * scale,
          hero: partyHero,
          partyIndex: idx,
          walkFrame: walk,
          alpha: hero.vanishTimer > 0 ? 0.35 : alpha,
        );
      }
      // WoW-style persistent auras
      if (showAuras && hero.iceBlockTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.62,
          Paint()..color = const Color(0x5540B0FF),
        );
        canvas.drawCircle(
          c,
          tile * 0.62,
          Paint()
            ..color = const Color(0xCCA0E8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.1),
        );
      }
      // Power Word: Shield — physical bubble around the target (WoW-style).
      if (showAuras && hero.absorbShield > 0) {
        final pulse =
            0.92 + 0.08 * math.sin(hero.x * 3 + hero.absorbShield * 0.2);
        final br = tile * 0.72 * pulse;
        // Soft filled dome
        canvas.drawCircle(c, br, Paint()..color = const Color(0x5548A0E8));
        canvas.drawCircle(
          c,
          br * 0.82,
          Paint()..color = const Color(0x3340B0FF),
        );
        // Outer rim
        canvas.drawCircle(
          c,
          br,
          Paint()
            ..color = const Color(0xEE90D8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.5, tile * 0.1),
        );
        // Specular highlight (top-left) like a glass bubble
        canvas.drawArc(
          Rect.fromCircle(
            center: c.translate(-br * 0.15, -br * 0.2),
            radius: br * 0.55,
          ),
          -2.4,
          1.2,
          false,
          Paint()
            ..color = const Color(0xAAF0FFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06)
            ..strokeCap = StrokeCap.round,
        );
      }
      if (showAuras && hero.combustionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.5,
          Paint()
            ..color = const Color(0x88FF5020)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
      }
      if (showAuras && hero.painSuppressionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.52,
          Paint()
            ..color = const Color(0x88FF8080)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
      }
      if (showAuras && hero.fortitudeTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.44,
          Paint()
            ..color = const Color(0x55FFE8A0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, tile * 0.05),
        );
      }
      if (showAuras && hero.bladeFlurryTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.7,
          Paint()
            ..color = const Color(0x55FF8060)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.05),
        );
      }
      if (showAuras && hero.killingSpreeTimer > 0) {
        final pulse = 0.9 + 0.1 * math.sin(hero.killingSpreeTimer * 14);
        canvas.drawCircle(
          c,
          tile * 0.65 * pulse,
          Paint()
            ..color = const Color(0x88FF3030)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      }
      if (showAuras && hero.powerInfusionTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.58,
          Paint()
            ..color = const Color(0x88C070FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
        canvas.drawCircle(
          c,
          tile * 0.35,
          Paint()..color = const Color(0x44E0A0FF),
        );
      }
      if (showAuras && hero.pomCharges > 0) {
        for (var i = 0; i < hero.pomCharges.clamp(0, 5); i++) {
          final a = hero.x + i * 1.25 + hero.pomCharges;
          canvas.drawCircle(
            Offset(
              c.dx + math.cos(a) * tile * 0.48,
              c.dy + math.sin(a) * tile * 0.48,
            ),
            tile * 0.08,
            Paint()..color = const Color(0xFFFFF0A0),
          );
        }
      }
      if (showAuras &&
          hero.innerFireActive &&
          hero.heroRole == HeroRole.healer) {
        canvas.drawCircle(
          c,
          tile * 0.38,
          Paint()
            ..color = const Color(0x55FFE8A0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, tile * 0.05),
        );
      }
      if (showAuras && hero.sliceAndDiceTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.46,
          Paint()
            ..color = const Color(0x88FFD070)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, tile * 0.05),
        );
      }
      if (showAuras && hero.sprintTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.4,
          Paint()..color = const Color(0x44FFFFA0),
        );
      }
      if (showAuras && hero.shieldWallTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.55,
          Paint()
            ..color = const Color(0x8890B8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      } else if (showAuras && hero.shieldBlockTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.48,
          Paint()
            ..color = const Color(0x779AD0FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
      }
      if (showAuras && hero.lastStandTimer > 0) {
        canvas.drawCircle(
          c,
          tile * 0.6,
          Paint()
            ..color = const Color(0x88FFA040)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.08),
        );
      }
      // Generic kit buffTimers (shield / buff) when no dedicated aura fired.
      if (showAuras) {
        final shieldT = hero.buffTimers['shield'] ?? 0;
        final buffT = hero.buffTimers['buff'] ?? 0;
        if (shieldT > 0 &&
            hero.shieldBlockTimer <= 0 &&
            hero.shieldWallTimer <= 0 &&
            hero.absorbShield <= 0) {
          canvas.drawCircle(
            c,
            tile * 0.5,
            Paint()
              ..color = const Color(0x7790C0FF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.06),
          );
        }
        if (buffT > 0 &&
            hero.combustionTimer <= 0 &&
            hero.powerInfusionTimer <= 0) {
          canvas.drawCircle(
            c,
            tile * 0.46,
            Paint()
              ..color = const Color(0x66E0A060)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.4, tile * 0.05),
          );
        }
      }
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.42 * flash,
          Paint()
            ..color = hero.heroRole == HeroRole.warrior
                ? const Color(0x99FFE080)
                : const Color(0x77FFF0C0),
        );
      }
      if (hero.isAlive) {
        drawBar(c, hero.hp, hero.effectiveMaxHp, tile * 0.8);
      }
    }

    for (final pet in world.pets) {
      final flash = pet.attackFlash;
      final c = center(pet.x, pet.y);
      final isClass = pet.id.startsWith('classpet_');
      final isTemp = pet.id.startsWith('temppet_');
      final petPath = isClass || isTemp
          ? CustomAssets.petForCombatActorId(pet.id, pet.name)
          : CustomAssets.petForInstanceId(
              pet.id.startsWith('pet_') ? pet.id.substring(4) : pet.id,
            );
      final petImg = petsByPath[petPath];
      final ringArgb = isTemp
          ? 0xAA90D8FF
          : isClass
          ? 0xAA50E0A8
          : 0xAAFFE08A;
      canvas.drawCircle(
        c,
        tile * 0.4,
        Paint()
          ..color = Color(ringArgb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, tile * 0.055),
      );
      final scale =
          (isClass ? 0.78 : isTemp ? 0.72 : 0.68) * (1 + flash * 0.22);
      drawSprite(petImg ?? coin, c, scale);
      if (flash > 0.02) {
        canvas.drawCircle(
          c,
          tile * 0.32 * flash,
          Paint()..color = const Color(0x66FFE8A0),
        );
      }
    }

    if (showBursts) {
      for (final burst in world.bursts) {
        final kind = burst.slash ? SpatialBurstKind.slash : burst.kind;
        if (kind == SpatialBurstKind.slash && burst.angle != null) {
          // Prefer longer slash window for readability.
          final alpha = (burst.life / 0.42).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final sweep = 1.45;
          final start = burst.angle! - sweep * 0.5;
          final r = tile * burst.radius * (0.7 + (1 - alpha) * 0.45);
          final paint = Paint()
            ..color = Color(burst.argb).withValues(alpha: alpha * 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(3.5, tile * 0.22)
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            start,
            sweep * alpha.clamp(0.4, 1.0),
            false,
            paint,
          );
          // Soft inner glow
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.72),
            start,
            sweep * alpha.clamp(0.4, 1.0),
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.0, tile * 0.1)
              ..strokeCap = StrokeCap.round,
          );
          // Tip spark at the leading edge of the swing
          final tipAng = start + sweep * 0.85;
          canvas.drawCircle(
            Offset(c.dx + math.cos(tipAng) * r, c.dy + math.sin(tipAng) * r),
            math.max(2.0, tile * 0.08),
            Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
          );
        } else if (kind == SpatialBurstKind.ring) {
          final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.55 + (1 - alpha) * 0.7);
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.5, tile * 0.12),
          );
          canvas.drawCircle(
            c,
            r * 0.72,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, tile * 0.06),
          );
        } else if (kind == SpatialBurstKind.cone && burst.angle != null) {
          final alpha = (burst.life / 0.45).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.85 + (1 - alpha) * 0.35);
          final sweep = 1.15;
          final start = burst.angle! - sweep * 0.5;
          final path = Path()
            ..moveTo(c.dx, c.dy)
            ..arcTo(Rect.fromCircle(center: c, radius: r), start, sweep, false)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.45),
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, tile * 0.08),
          );
        } else if (kind == SpatialBurstKind.spark) {
          final alpha = (burst.life / 0.35).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.4 + alpha * 0.4);
          canvas.drawCircle(
            c,
            r,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.9),
          );
          canvas.drawCircle(
            c,
            r * 0.4,
            Paint()..color = Colors.white.withValues(alpha: alpha),
          );
          for (var i = 0; i < 4; i++) {
            final a = i * math.pi / 2 + burst.life * 8;
            canvas.drawCircle(
              Offset(
                c.dx + math.cos(a) * r * 1.3,
                c.dy + math.sin(a) * r * 1.3,
              ),
              r * 0.25,
              Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.7),
            );
          }
        } else if (kind == SpatialBurstKind.beam ||
            kind == SpatialBurstKind.rain ||
            kind == SpatialBurstKind.shards ||
            kind == SpatialBurstKind.flame ||
            kind == SpatialBurstKind.cross ||
            kind == SpatialBurstKind.poison ||
            kind == SpatialBurstKind.skull) {
          _paintSpellBurst(canvas, burst, tile, center);
        } else {
          final maxLife = 0.45;
          final alpha = (burst.life / maxLife).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (1.2 - alpha * 0.35);
          canvas.drawCircle(
            c,
            r,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.55),
          );
          canvas.drawCircle(
            c,
            r * 0.55,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.85),
          );
        }
      }
    }

    if (showBursts) {
      final floaters = world.floaters;
      final tp = TextPainter(textDirection: TextDirection.ltr);
      final maxW = tile * 4.4;
      for (var i = 0; i < floaters.length; i++) {
        final floater = floaters[i];
        if (!_inView(floater.x, floater.y, pad: 0.5)) continue;
        final speech = floater.kind == SpatialFloaterKind.speech;
        final fadeFor = speech
            ? 1.35
            : (floater.priority >= 1 ? 1.15 : 0.7);
        final alpha = (floater.life / fadeFor).clamp(0.0, 1.0);
        final size = tile *
            (speech ? 0.28 : 0.32) *
            SpatialCombat.floaterReadScale(floater.priority);
        tp.text = TextSpan(
          text: floater.text,
          style: GameTheme.pixelCached(
            size: math.max(GameTheme.hudPixel, size),
            color: Color(floater.argb).withValues(alpha: alpha),
          ),
        );
        tp.layout(maxWidth: maxW);
        final c = center(floater.x, floater.y);
        if (speech) {
          final padX = tile * 0.12;
          final padY = tile * 0.06;
          final bubble = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c.dx - tp.width / 2 - padX,
              c.dy - tp.height / 2 - padY,
              tp.width + padX * 2,
              tp.height + padY * 2,
            ),
            Radius.circular(tile * 0.12),
          );
          canvas.drawRRect(
            bubble,
            Paint()..color = const Color(0xCC1A1420).withValues(alpha: alpha),
          );
          canvas.drawRRect(
            bubble,
            Paint()
              ..color = Color(floater.argb).withValues(alpha: alpha * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, tile * 0.03),
          );
        }
        tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
      }
      tp.dispose();
    }
  }

  void _paintGroundKind(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double frac,
    double tile,
    SpatialGroundFxKind kind,
    double life,
  ) {
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.6 * frac)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, tile * 0.06);
    canvas.drawCircle(c, r, stroke);
    switch (kind) {
      case SpatialGroundFxKind.disc:
        return;
      case SpatialGroundFxKind.holy:
        // Consecration: spokes + inner ring.
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * r * 0.2, c.dy + math.sin(a) * r * 0.2),
            Offset(c.dx + math.cos(a) * r * 0.92, c.dy + math.sin(a) * r * 0.92),
            Paint()
              ..color = const Color(0xAAFFF6C0).withValues(alpha: 0.55 * frac)
              ..strokeWidth = math.max(1.2, tile * 0.045)
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(
          c,
          r * 0.38,
          Paint()
            ..color = const Color(0x66FFF0A0).withValues(alpha: 0.45 * frac)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, tile * 0.05),
        );
      case SpatialGroundFxKind.frost:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + life * 0.4;
          final p = Path()
            ..moveTo(c.dx + math.cos(a) * r * 0.25, c.dy + math.sin(a) * r * 0.25)
            ..lineTo(
              c.dx + math.cos(a) * r * 0.88,
              c.dy + math.sin(a) * r * 0.88,
            )
            ..lineTo(
              c.dx + math.cos(a + 0.22) * r * 0.55,
              c.dy + math.sin(a + 0.22) * r * 0.55,
            )
            ..close();
          canvas.drawPath(
            p,
            Paint()..color = const Color(0x88C8F0FF).withValues(alpha: 0.45 * frac),
          );
        }
      case SpatialGroundFxKind.fire:
        for (var i = 0; i < 4; i++) {
          final a = i * 1.7 + life;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                c.dx + math.cos(a) * r * 0.35,
                c.dy + math.sin(a) * r * 0.28,
              ),
              width: r * 0.55,
              height: r * 0.38,
            ),
            Paint()..color = const Color(0x66FF5018).withValues(alpha: 0.4 * frac),
          );
        }
      case SpatialGroundFxKind.rain:
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final ox = math.cos(a) * r * 0.55;
          final oy = math.sin(a) * r * 0.55;
          final drop = ((life * 3 + i * 0.4) % 1.0);
          canvas.drawLine(
            Offset(c.dx + ox, c.dy + oy - r * 0.22 * drop),
            Offset(c.dx + ox, c.dy + oy + r * 0.12),
            Paint()
              ..color = color.withValues(alpha: 0.7 * frac)
              ..strokeWidth = math.max(1.2, tile * 0.04)
              ..strokeCap = StrokeCap.round,
          );
        }
      case SpatialGroundFxKind.shadow:
        canvas.drawCircle(
          c,
          r * 0.55,
          Paint()..color = const Color(0x55201040).withValues(alpha: 0.5 * frac),
        );
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.72),
          life,
          2.2,
          false,
          Paint()
            ..color = const Color(0xAA9050D0).withValues(alpha: 0.55 * frac)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07)
            ..strokeCap = StrokeCap.round,
        );
      case SpatialGroundFxKind.nature:
        for (var i = 0; i < 5; i++) {
          final a = i * 1.26 + 0.3;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                c.dx + math.cos(a) * r * 0.55,
                c.dy + math.sin(a) * r * 0.55,
              ),
              width: r * 0.28,
              height: r * 0.16,
            ),
            Paint()..color = const Color(0x8878E060).withValues(alpha: 0.5 * frac),
          );
        }
      case SpatialGroundFxKind.steel:
        for (var i = 0; i < 3; i++) {
          final a = life * 6 + i * 2.1;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * (0.45 + i * 0.18)),
            a,
            1.4,
            false,
            Paint()
              ..color = const Color(0xCCFFE08A).withValues(alpha: 0.55 * frac)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, tile * 0.08)
              ..strokeCap = StrokeCap.round,
          );
        }
    }
  }

  void _paintSpellBurst(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) center,
  ) {
    final alpha = (burst.life / 0.45).clamp(0.0, 1.0);
    final c = center(burst.x, burst.y);
    final r = tile * burst.radius * (0.7 + (1 - alpha) * 0.35);
    final color = Color(burst.argb);
    switch (burst.kind) {
      case SpatialBurstKind.beam:
        final end = burst.x2 != null && burst.y2 != null
            ? center(burst.x2!, burst.y2!)
            : Offset(c.dx, c.dy - r * 2.2);
        final glow = Paint()
          ..color = color.withValues(alpha: alpha * 0.45)
          ..strokeWidth = math.max(4, tile * 0.16)
          ..strokeCap = StrokeCap.round;
        final core = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.95)
          ..strokeWidth = math.max(1.6, tile * 0.055)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c, end, glow);
        // Zigzag so lightning isn't a boring line.
        final dx = end.dx - c.dx;
        final dy = end.dy - c.dy;
        final zig = Path()..moveTo(c.dx, c.dy);
        for (var i = 1; i <= 3; i++) {
          final t = i / 4;
          final side = (i.isOdd ? 1.0 : -1.0) * r * 0.35;
          final nx = -dy / (math.sqrt(dx * dx + dy * dy) + 0.001);
          final ny = dx / (math.sqrt(dx * dx + dy * dy) + 0.001);
          zig.lineTo(c.dx + dx * t + nx * side, c.dy + dy * t + ny * side);
        }
        zig.lineTo(end.dx, end.dy);
        canvas.drawPath(zig, core);
        canvas.drawCircle(end, r * 0.35, Paint()..color = Colors.white.withValues(alpha: alpha));
      case SpatialBurstKind.rain:
        for (var i = 0; i < 7; i++) {
          final a = i * 0.9;
          final ox = math.cos(a) * r * 0.7;
          final oy = math.sin(a) * r * 0.45;
          final fall = (1 - alpha) * r * 0.5;
          canvas.drawLine(
            Offset(c.dx + ox, c.dy + oy - r * 0.8 + fall),
            Offset(c.dx + ox, c.dy + oy - r * 0.15 + fall),
            Paint()
              ..color = color.withValues(alpha: alpha * 0.85)
              ..strokeWidth = math.max(1.4, tile * 0.05)
              ..strokeCap = StrokeCap.round,
          );
        }
      case SpatialBurstKind.shards:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + burst.life * 2;
          final p = Path()
            ..moveTo(c.dx + math.cos(a) * r * 1.15, c.dy + math.sin(a) * r * 1.15)
            ..lineTo(
              c.dx + math.cos(a + 0.35) * r * 0.25,
              c.dy + math.sin(a + 0.35) * r * 0.25,
            )
            ..lineTo(
              c.dx + math.cos(a - 0.35) * r * 0.25,
              c.dy + math.sin(a - 0.35) * r * 0.25,
            )
            ..close();
          canvas.drawPath(p, Paint()..color = color.withValues(alpha: alpha * 0.9));
        }
        canvas.drawCircle(
          c,
          r * 0.28,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
        );
      case SpatialBurstKind.flame:
        for (var i = 0; i < 5; i++) {
          final a = i * 1.256 + (1 - alpha);
          final p = Path()
            ..moveTo(c.dx, c.dy)
            ..quadraticBezierTo(
              c.dx + math.cos(a + 0.4) * r * 0.5,
              c.dy + math.sin(a + 0.4) * r * 0.5,
              c.dx + math.cos(a) * r * 1.15,
              c.dy + math.sin(a) * r * 1.15,
            )
            ..quadraticBezierTo(
              c.dx + math.cos(a - 0.4) * r * 0.5,
              c.dy + math.sin(a - 0.4) * r * 0.5,
              c.dx,
              c.dy,
            );
          canvas.drawPath(p, Paint()..color = color.withValues(alpha: alpha * 0.7));
        }
        canvas.drawCircle(
          c,
          r * 0.32,
          Paint()..color = const Color(0xFFFFF0A0).withValues(alpha: alpha),
        );
      case SpatialBurstKind.cross:
        final arm = r * 1.05;
        final holy = Paint()
          ..color = color.withValues(alpha: alpha * 0.9)
          ..strokeWidth = math.max(2.2, tile * 0.09)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx, c.dy - arm), Offset(c.dx, c.dy + arm), holy);
        canvas.drawLine(
          Offset(c.dx - arm * 0.7, c.dy - arm * 0.15),
          Offset(c.dx + arm * 0.7, c.dy - arm * 0.15),
          holy,
        );
        canvas.drawCircle(
          c,
          r * 0.28,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.85),
        );
      case SpatialBurstKind.poison:
        for (var i = 0; i < 4; i++) {
          final a = i * 1.57 + 0.4;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                c.dx + math.cos(a) * r * 0.65,
                c.dy + math.sin(a) * r * 0.65 + r * 0.15 * (1 - alpha),
              ),
              width: r * 0.38,
              height: r * 0.55,
            ),
            Paint()..color = color.withValues(alpha: alpha * 0.75),
          );
        }
        canvas.drawCircle(c, r * 0.28, Paint()..color = const Color(0xAAE8FFC0).withValues(alpha: alpha));
      case SpatialBurstKind.skull:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 1.5, height: r * 1.7),
          Paint()..color = color.withValues(alpha: alpha * 0.75),
        );
        canvas.drawCircle(
          Offset(c.dx - r * 0.28, c.dy - r * 0.12),
          r * 0.18,
          Paint()..color = const Color(0xFFFFE080).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(c.dx + r * 0.28, c.dy - r * 0.12),
          r * 0.18,
          Paint()..color = const Color(0xFFFFE080).withValues(alpha: alpha),
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.28), width: r * 0.7, height: r * 0.4),
          0.2,
          math.pi - 0.4,
          false,
          Paint()
            ..color = const Color(0xAA201028).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.05),
        );
      default:
        canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: alpha * 0.6));
    }
  }

  bool _isGateDoorCenter(int x, int y) {
    final map = world.map;
    final left = map.at(x - 1, y) == TileKind.gate;
    final right = map.at(x + 1, y) == TileKind.gate;
    final up = map.at(x, y - 1) == TileKind.gate;
    final down = map.at(x, y + 1) == TileKind.gate;
    if ((left && right) || (up && down)) return true; // middle of 3-strip
    if (!left && !right && !up && !down) return true; // lone gate
    return false; // strip end — no door panel
  }

  void _drawWallCaps(
    Canvas canvas,
    int x,
    int y,
    Rect dst,
    double tile,
    ui.Image wall,
  ) {
    final map = world.map;
    final t = tile * 0.34;
    // Filled strips are cheaper than clip+blit per edge.
    void strip(Rect r) {
      _drawImage(canvas, wall, r);
      _fillPaint.color = const Color(0x66000000);
      canvas.drawRect(r, _fillPaint);
    }

    if (DungeonEnvironment.isCarved(map.at(x, y + 1))) {
      strip(Rect.fromLTWH(dst.left, dst.bottom - t, dst.width, t));
    }
    if (DungeonEnvironment.isCarved(map.at(x, y - 1))) {
      strip(Rect.fromLTWH(dst.left, dst.top, dst.width, t));
    }
    if (DungeonEnvironment.isCarved(map.at(x + 1, y))) {
      strip(Rect.fromLTWH(dst.right - t, dst.top, t, dst.height));
    }
    if (DungeonEnvironment.isCarved(map.at(x - 1, y))) {
      strip(Rect.fromLTWH(dst.left, dst.top, t, dst.height));
    }
  }

  void _drawOrientedDoor(
    Canvas canvas,
    ui.Image door,
    Rect dst, {
    required bool rotate,
  }) {
    // Crop baked wall lip from the top ~20% of Kenney door tiles.
    final src = Rect.fromLTWH(
      0,
      door.height * 0.18,
      door.width.toDouble(),
      door.height * 0.82,
    );
    final doorDst = Rect.fromCenter(
      center: dst.center.translate(0, dst.height * 0.04),
      width: dst.width * 0.92,
      height: dst.height * 0.88,
    );

    if (!rotate) {
      _drawImageSrc(canvas, door, src, doorDst);
      return;
    }
    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    canvas.rotate(math.pi / 2);
    _drawImageSrc(
      canvas,
      door,
      src,
      Rect.fromCenter(
        center: Offset.zero,
        width: doorDst.width,
        height: doorDst.height,
      ),
    );
    canvas.restore();
  }

  void _drawImageSrc(
    Canvas canvas,
    ui.Image image,
    Rect src,
    Rect dst, {
    double alpha = 1,
    Color? tint,
  }) {
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    canvas.drawImageRect(image, src, dst, paint);
  }

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect dst, {
    double alpha = 1,
    Color? tint,
  }) {
    _drawImageSrc(
      canvas,
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      alpha: alpha,
      tint: tint,
    );
  }

  @override
  bool shouldRepaint(covariant _TileRoomPainter oldDelegate) {
    return visualFrame != oldDelegate.visualFrame ||
        dungeonId != oldDelegate.dungeonId ||
        reducedVfx != oldDelegate.reducedVfx ||
        vfxQuality != oldDelegate.vfxQuality ||
        camera.camX != oldDelegate.camera.camX ||
        camera.camY != oldDelegate.camera.camY ||
        camera.tileSize != oldDelegate.camera.tileSize ||
        !identical(world, oldDelegate.world) ||
        !identical(floorVariants, oldDelegate.floorVariants) ||
        !identical(enemies, oldDelegate.enemies);
  }
}

class _TileCamera {
  const _TileCamera({
    required this.camX,
    required this.camY,
    required this.tileSize,
    required this.visibleCols,
    required this.visibleRows,
  });

  final double camX;
  final double camY;
  final double tileSize;
  final double visibleCols;
  final double visibleRows;

  factory _TileCamera.forWorld(
    SpatialWorld? world,
    BoxConstraints constraints, {
    double targetCols = 20,
  }) {
    if (world == null) {
      return const _TileCamera(
        camX: 0,
        camY: 0,
        tileSize: 1,
        visibleCols: 1,
        visibleRows: 1,
      );
    }
    // Phone product: zoom setting picks how many tiles fit across the stage.
    final cols = math.min(targetCols, world.cols.toDouble());
    final tileSize = constraints.maxWidth / cols;
    final visibleRows = constraints.maxHeight / tileSize;
    final leader =
        world.leader ?? (world.heroes.isNotEmpty ? world.heroes.first : null);
    final centerX = leader?.x ?? world.cols / 2;
    final centerY = leader?.y ?? world.rows / 2;
    final maxCamX = math.max(0.0, world.cols - cols);
    final maxCamY = math.max(0.0, world.rows - visibleRows);
    return _TileCamera(
      camX: (centerX - cols / 2).clamp(0.0, maxCamX).toDouble(),
      camY: (centerY - visibleRows / 2).clamp(0.0, maxCamY).toDouble(),
      tileSize: tileSize,
      visibleCols: cols,
      visibleRows: visibleRows,
    );
  }
}
