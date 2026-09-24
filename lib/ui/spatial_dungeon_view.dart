import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/game_director.dart';
import 'dungeon_camera.dart';
import '../core/game_logic.dart';
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
import '../visual/body_family.dart';
import '../visual/character_visual_painter.dart';
import '../visual/character_visual_pose.dart';
import '../visual/hero_anim_controller.dart';
import '../visual/owned_gear_assets.dart';
import '../visual/hero_anim_state.dart';
import '../assets/custom_assets.dart';
import '../assets/kenney_assets.dart';
import 'decoded_image_cache.dart';
import 'dungeon_environment.dart';
import 'game_theme.dart';
import 'kenney_sprite.dart';
import 'shell/offline_banner.dart';
import 'shell/wipe_overlay.dart';
import 'web_click_bridge.dart';

part 'dungeon_tile_painter.dart';
part 'dungeon_paint_projectiles.dart';
part 'dungeon_paint_actors.dart';
part 'dungeon_paint_floaters.dart';

/// Top-down tile dungeon — painted, not 100+ Image widgets.
class SpatialDungeonView extends StatefulWidget {
  const SpatialDungeonView({super.key, required this.director});

  final GameDirector director;

  /// Map TalkBack. First hour matches the fist chip (tap the fight).
  static String mapSemanticsLabel({required bool plain}) => plain
      ? 'Dungeon map — tap to pin target while fighting; '
          'long-press to smash and steer; fist button also works'
      : 'Dungeon map — tap to pin target while fighting; '
          'long-press for God Hand; fist button also works';

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
  final Map<HeroSpecId, ui.Image?> _heroesBySpec = {};
  final Map<String, ui.Image> _bodyByPath = <String, ui.Image>{};
  ui.Image? _chest;
  ui.Image? _coin;
  ui.Image? _sword;
  ui.Image? _vial;
  final Map<String, ui.Image> _lootByPath = <String, ui.Image>{};
  final Map<String, ui.Image> _petsByPath = <String, ui.Image>{};
  List<ui.Image?> _enemySprites = const [];
  String? _loadedDungeonId;
  bool _sharedLoaded = false;
  /// Zone floor/enemy decode finished (partial OK — never block forever).
  bool _zoneArtReady = false;
  int _loadGen = 0;

  bool get _tilesReady =>
      _floorReady.isNotEmpty &&
      _wallReady.isNotEmpty &&
      (_zoneStairs ?? _stairs) != null &&
      (_zoneStairsBoss ?? _stairsBoss) != null &&
      (_zoneDoorClosed ?? _doorClosed) != null &&
      (_zoneDoorOpen ?? _doorOpen) != null;

  bool get _canPaintFloor =>
      _zoneArtReady &&
      _tilesReady &&
      _sword != null &&
      _vial != null;

  @override
  void initState() {
    super.initState();
    _loadImages(widget.director.state.dungeonId);
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
    final gen = ++_loadGen;
    // Keep painting prior tiles while a zone switch loads — never blank mid-fight.
    Future<ui.Image> load(
      String asset, {
      int? targetWidth,
      int? targetHeight,
    }) => DecodedImageCache.load(
      asset,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    Future<ui.Image?> loadSoft(
      String asset, {
      int? targetWidth,
      int? targetHeight,
    }) async {
      try {
        return await load(
          asset,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
      } catch (e, st) {
        debugPrint('DecodedImageCache soft load failed ($asset): $e\n$st');
        return null;
      }
    }

    final floorPaths = KenneyAssets.floorVariantsForDungeon(dungeonId);
    final wallPaths = KenneyAssets.wallVariantsForDungeon(dungeonId);
    final propKinds = KenneyAssets.propPoolForDungeon(dungeonId).toSet()
      ..add(MapPropKind.chest);

    // Shared combat icons — critical paint set first so resume never sticks
    // on "Loading floor…" while hundreds of paper-doll PNGs decode.
    if (!_sharedLoaded) {
      final critical = await Future.wait([
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
        load(KenneyAssets.chestClosed, targetWidth: 64),
        load(KenneyAssets.coinGold, targetWidth: 48),
        load(KenneyAssets.sword, targetWidth: 48),
        load(KenneyAssets.vialBlue, targetWidth: 48),
      ]);
      if (!mounted || gen != _loadGen) return;

      var i = 0;
      _stairs = critical[i++];
      _stairsBoss = critical[i++];
      _doorClosed = critical[i++];
      _doorOpen = critical[i++];
      _hero0 = critical[i++];
      _hero1 = critical[i++];
      _hero2 = critical[i++];
      _hero3 = critical[i++];
      _heroesByClass
        ..clear()
        ..[HeroClassId.warrior] = _hero0
        ..[HeroClassId.priest] = _hero1
        ..[HeroClassId.mage] = _hero2
        ..[HeroClassId.rogue] = _hero3
        ..[HeroClassId.paladin] = critical[i++]
        ..[HeroClassId.hunter] = critical[i++]
        ..[HeroClassId.deathKnight] = critical[i++]
        ..[HeroClassId.shaman] = critical[i++]
        ..[HeroClassId.warlock] = critical[i++]
        ..[HeroClassId.druid] = critical[i++];
      _chest = critical[i++];
      _coin = critical[i++];
      _sword = critical[i++];
      _vial = critical[i++];
      _sharedLoaded = true;
      if (mounted) setState(() {});
    }

    // Zone floors/walls ASAP — paint before deferred loot/body catalogs.
    final floorVariants = <ui.Image>[];
    for (final a in floorPaths) {
      final img = await loadSoft(a, targetWidth: 64);
      if (img != null) floorVariants.add(img);
    }
    final wallVariants = <ui.Image>[];
    for (final a in wallPaths) {
      final img = await loadSoft(a, targetWidth: 64);
      if (img != null) wallVariants.add(img);
    }
    if (!mounted || gen != _loadGen) return;

    final canPaint =
        floorVariants.isNotEmpty &&
        wallVariants.isNotEmpty &&
        _stairs != null &&
        _stairsBoss != null &&
        _doorClosed != null &&
        _doorOpen != null &&
        _sword != null &&
        _vial != null;
    setState(() {
      _loadedDungeonId = dungeonId;
      _floorReady = floorVariants;
      _wallReady = wallVariants;
      _zoneArtReady = canPaint;
    });

    // Deferred shared catalog (loot icons, pets, paper-doll overlays).
    if (_lootByPath.isEmpty || _bodyByPath.isEmpty) {
      unawaited(_loadDeferredSharedArt(gen, load: load, loadSoft: loadSoft));
    }

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

    ui.Image? zoneStairs;
    ui.Image? zoneStairsBoss;
    ui.Image? zoneDoorClosed;
    ui.Image? zoneDoorOpen;
    if (customDungeon && structuralPaths.length == 4) {
      zoneStairs = await loadSoft(structuralPaths[0], targetWidth: 64);
      zoneStairsBoss = await loadSoft(structuralPaths[1], targetWidth: 64);
      zoneDoorClosed = await loadSoft(structuralPaths[2], targetWidth: 64);
      zoneDoorOpen = await loadSoft(structuralPaths[3], targetWidth: 64);
    }
    if (!mounted || gen != _loadGen) return;
    if (zoneStairs != null ||
        zoneStairsBoss != null ||
        zoneDoorClosed != null ||
        zoneDoorOpen != null) {
      setState(() {
        _zoneStairs = zoneStairs;
        _zoneStairsBoss = zoneStairsBoss;
        _zoneDoorClosed = zoneDoorClosed;
        _zoneDoorOpen = zoneDoorOpen;
      });
    }

    final propKindList = propKinds.toList();
    final propImages = <MapPropKind, ui.Image?>{};
    for (final kind in propKindList) {
      propImages[kind] = await loadSoft(
        KenneyAssets.propAsset(kind, dungeonId: dungeonId),
        targetWidth: 64,
      );
    }

    final enemySprites = List<ui.Image?>.filled(catalog.length, null);
    for (final asset in zoneEnemyAssets) {
      enemySprites[KenneyAssets.enemySpriteCatalogIndex(asset)] =
          await loadSoft(asset, targetWidth: 128);
    }
    if (!mounted || gen != _loadGen) return;

    setState(() {
      _propImages = propImages;
      _enemySprites = enemySprites;
      if (!_zoneArtReady &&
          _floorReady.isNotEmpty &&
          _wallReady.isNotEmpty &&
          _stairs != null) {
        _zoneArtReady = true;
      }
    });
  }

  Future<void> _loadDeferredSharedArt(
    int gen, {
    required Future<ui.Image> Function(
      String asset, {
      int? targetWidth,
      int? targetHeight,
    }) load,
    required Future<ui.Image?> Function(
      String asset, {
      int? targetWidth,
      int? targetHeight,
    }) loadSoft,
  }) async {
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

    final petPaths = [
      ...CustomAssets.petPortraitPaths,
      ...CustomAssets.combatPetPortraitPaths,
    ];
    final uniqueHeroPaths = CustomAssets.uniqueHeroSpecPaths;

    final shared = await Future.wait([
      ...lootPaths.map((a) => load(a, targetWidth: 64)),
      ...petPaths.map((a) => load(a, targetWidth: 96)),
      ...uniqueHeroPaths.map((a) => load(a, targetWidth: 128)),
    ]);
    if (!mounted || gen != _loadGen) return;

    var i = 0;
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
    _heroesBySpec
      ..clear()
      ..addEntries([
        for (final spec in CustomAssets.uniqueHeroSpecs)
          MapEntry(spec, shared[i++]),
      ]);

    // Doll overlays only — BAG `*_icon` crops are never painted in a dungeon.
    final bodyPaths = [
      ...BodyFamilyCatalog.allAssetPaths,
      ...OwnedGearAssets.dollOverlayPaths,
    ];
    final bodyImages = await Future.wait(
      bodyPaths.map((path) => loadSoft(path, targetWidth: 128)),
    );
    final bodyEntries = <MapEntry<String, ui.Image>>[
      for (var i = 0; i < bodyPaths.length; i++)
        if (bodyImages[i] != null) MapEntry(bodyPaths[i], bodyImages[i]!),
    ];
    if (!mounted || gen != _loadGen) return;
    if (bodyEntries.isNotEmpty) {
      setState(() {
        _bodyByPath
          ..clear()
          ..addEntries(bodyEntries);
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final farm = state.dungeonMode == DungeonMode.farm;
    final dailyEcho = MetaSystems.isActiveDailyRun(state);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Live map + boss banner only — wipe/offline chrome stay on
                  // the ~10 Hz director notify (see GameDirector._shellNotifyEvery).
                  ListenableBuilder(
                    listenable: widget.director.combatFrame,
                    builder: (context, _) {
                      final world = widget.director.spatial;
                      final room = widget.director.state.currentRoom;
                      final camera = _TileCamera.forWorld(
                        world,
                        constraints,
                        targetCols: widget.director.state.dungeonZoom.targetCols,
                        shake: widget.director.combatShake,
                        visualFrame: widget.director.visualFrame,
                        pinHeroIndex: widget.director.cameraHeroIndex,
                      );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          WebClickScope(
                            label: 'Dungeon map',
                            onPressed: () {
                              if (widget.director.awaitingWipeChoice) return;
                              if (widget.director.state.isPartyDefeated) {
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
                              label: SpatialDungeonView.mapSemanticsLabel(
                                plain: GameLogic.plainPlayerChrome(
                                  widget.director.state,
                                ),
                              ),
                              onTap: () {
                                if (widget.director.awaitingWipeChoice) return;
                                if (widget.director.state.isPartyDefeated) {
                                  widget.director.reviveParty();
                                  return;
                                }
                                final fighting =
                                    world?.enemies.any((e) => e.isAlive) ??
                                        false;
                                if (!fighting || world == null) return;
                                final alive = world.heroes
                                    .where((h) => h.hp > 0)
                                    .toList();
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
                                  if (widget.director.awaitingWipeChoice) {
                                    return;
                                  }
                                  if (widget.director.state.isPartyDefeated) {
                                    widget.director.reviveParty();
                                    return;
                                  }
                                  final tileX = camera.camX +
                                      details.localPosition.dx /
                                          camera.tileSize;
                                  final tileY = camera.camY +
                                      details.localPosition.dy /
                                          camera.tileSize;
                                  // Mid-pack: pin target HUD — fist / long-press for GH.
                                  final fighting =
                                      world?.enemies.any((e) => e.isAlive) ??
                                          false;
                                  if (fighting) {
                                    widget.director
                                        .setHudFocusAtWorld(tileX, tileY);
                                  }
                                  // Idle / clear: map tap does not fire God Hand.
                                },
                                onLongPressStart: (details) {
                                  if (widget.director.awaitingWipeChoice) {
                                    return;
                                  }
                                  if (widget.director.state.isPartyDefeated) {
                                    return;
                                  }
                                  final tileX = camera.camX +
                                      details.localPosition.dx /
                                          camera.tileSize;
                                  final tileY = camera.camY +
                                      details.localPosition.dy /
                                          camera.tileSize;
                                  widget.director
                                      .godHandAtWorld(tileX, tileY);
                                },
                                child: world == null || !_canPaintFloor
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
                                            party: widget.director.state.heroes,
                                            floorVariants: _floorReady,
                                            wallVariants: _wallReady,
                                            stairs:
                                                _zoneStairs ?? _stairs!,
                                            stairsBoss: _zoneStairsBoss ??
                                                _stairsBoss!,
                                            doorClosed: _zoneDoorClosed ??
                                                _doorClosed!,
                                            doorOpen:
                                                _zoneDoorOpen ?? _doorOpen!,
                                            propImages: _propImages,
                                            roomType: room.type,
                                            dungeonId:
                                                widget.director.state.dungeonId,
                                            layoutSeed: world.map.layoutSeed,
                                            clearedChambers:
                                                world.clearedChambers,
                                            heroes: <ui.Image?>[
                                              _hero0,
                                              _hero1,
                                              _hero2,
                                              _hero3,
                                            ],
                                            heroesByClass: _heroesByClass,
                                            heroesBySpec: _heroesBySpec,
                                            bodyByPath: _bodyByPath,
                                            enemies: _enemySprites,
                                            chest: _chest!,
                                            coin: _coin!,
                                            sword: _sword!,
                                            vial: _vial!,
                                            lootByPath: _lootByPath,
                                            petsByPath: _petsByPath,
                                            camera: camera,
                                            vfxQuality: widget
                                                .director.state.vfxQuality,
                                            visualFrame:
                                                widget.director.visualFrame,
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
                  // Floor celebrate notice paints via PlayShell FeedbackToast
                  // (one ephemeral slot — tip / celebrate / danger).
                  DungeonOfflineChrome(director: widget.director),
                  if (widget.director.awaitingWipeChoice)
                    DungeonWipePanel(
                      director: widget.director,
                      farm: farm,
                      dailyEcho: dailyEcho,
                    ),
                ],
              );
            },
          ),

          if (!widget.director.awaitingWipeChoice && state.isPartyDefeated)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: GameTheme.blood.withValues(alpha: 0.85),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    state.inGauntlet || state.inAnyRiftMode
                        ? 'WIPED — End Run returns to hub'
                        : 'WIPED — use the Retry / Hub panel',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(
                      size: 15,
                      color: GameTheme.torchHot,
                    ),
                  ),
                ),
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
    this.onLongPress,
    this.dense = false,
    this.tip,
    this.interactive = true,
    this.maxLabelWidth,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dense;
  final String? tip;
  final bool interactive;
  /// When set, long labels ellipsis instead of stretching the top HUD.
  final double? maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = tip == null ? '$label dungeon mode' : '$label. $tip';
    final action = interactive ? onTap : null;
    final child = Container(
      constraints: BoxConstraints(
        minHeight: dense ? 30 : GameTheme.minTouch,
      ),
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 8, vertical: dense ? 4 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF3A2810) : const Color(0xFF1A1610),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? GameTheme.torchHot : const Color(0xFF4A4030),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxLabelWidth ?? double.infinity,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.pixel(
            size: GameTheme.hudPixel,
            color: selected ? GameTheme.torchHot : GameTheme.parchmentDim,
          ),
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
        onLongPress: onLongPress,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          child: InkWell(
            onTap: action,
            onLongPress: onLongPress,
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
    required this.maxCooldown,
    this.onTap,
    this.urgent = false,
    this.readyLabel,
    this.coolingLabel,
    this.dense = false,
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

  /// Phone top HUD: slightly smaller so FARM + gold + floor fit without overflow.
  final bool dense;

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
    final box = dense ? 40.0 : GameTheme.minTouch;
    final ring = dense ? 26.0 : 28.0;
    final fist = dense ? 16.0 : 18.0;
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
                width: box,
                height: box,
                child: Center(
                  child: SizedBox(
                    width: ring,
                    height: ring,
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
                                    size: fist,
                                    color: color,
                                  )
                                : Text(
                                    cooldown < 10
                                        ? cooldown.toStringAsFixed(1)
                                        : '${cooldown.round()}',
                                    style: GameTheme.pixel(
                                      size: dense ? GameTheme.hudPixel : 6,
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
    double shake = 0,
    int visualFrame = 0,
    int? pinHeroIndex,
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
    final focus = dungeonPartyFocus(
      heroes: world.heroes
          .where((h) => !h.isPet)
          .map((h) => (x: h.x, y: h.y, alive: h.isAlive, index: h.assetIndex)),
      mapCenterX: world.cols / 2,
      mapCenterY: world.rows / 2,
      pinIndex: pinHeroIndex,
    );
    final origin = dungeonCamOrigin(
      focusX: focus.x,
      focusY: focus.y,
      visibleCols: cols,
      visibleRows: visibleRows,
      shakeAmp: shake > 0.02 ? shake * 0.38 : 0,
      visualFrame: visualFrame,
    );
    final camX = origin.camX;
    final camY = origin.camY;
    return _TileCamera(
      camX: camX,
      camY: camY,
      tileSize: tileSize,
      visibleCols: cols,
      visibleRows: visibleRows,
    );
  }
}
