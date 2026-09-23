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
      } catch (_) {
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
    required this.heroes,
    required this.heroesByClass,
    required this.heroesBySpec,
    required this.bodyByPath,
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
  final List<ui.Image?> heroes;
  final Map<HeroClassId, ui.Image?> heroesByClass;
  final Map<HeroSpecId, ui.Image?> heroesBySpec;
  final Map<String, ui.Image> bodyByPath;
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
  bool get showPriorityFloaters => vfxQuality.showPriorityFloaters;
  bool get showGround => vfxQuality.showGroundFx;
  bool get showTrails => vfxQuality.showProjectileTrails;
  bool get showLootPulse => vfxQuality.showLootPulse;

  Size? _vignetteSize;
  String? _vignetteDungeonId;
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

        // Boss rooms use the second floor tile (the landmark plate).
        final bossPlate = roomType == RoomType.boss && floorVariants.length > 1;
        final floorImg = bossPlate
            ? floorVariants[1]
            : floorVariants[_hashPick(x, y, layoutSeed, floorVariants.length)];
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
            } else {
              // Open door always reads as progress (even Minimal VFX).
              canvas.drawRect(
                dst.deflate(tile * 0.08),
                Paint()
                  ..color = const Color(0x88FFE08A)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = math.max(1.5, tile * 0.06),
              );
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
    if (_vignettePaint == null ||
        _vignetteSize != size ||
        _vignetteDungeonId != dungeonId) {
      _vignetteSize = size;
      _vignetteDungeonId = dungeonId;
      _vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.longestSide * 0.78,
          DungeonEnvironment.vignetteColors(dungeonId),
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
        Paint()..color = DungeonEnvironment.propShadow(dungeonId),
      );
      if (DungeonEnvironment.isTorchProp(prop.kind) && !reducedVfx) {
        final pulse = 0.85 + 0.15 * math.sin(visualFrame * 0.12);
        canvas.drawCircle(
          c.translate(0, -tile * 0.18),
          tile * 0.72 * pulse,
          Paint()
            ..shader = ui.Gradient.radial(
              c.translate(0, -tile * 0.18),
              tile * 0.72 * pulse,
              const [Color(0x55F0B038), Color(0x18E08828), Color(0x00E08828)],
              const [0.0, 0.45, 1.0],
            ),
        );
      }
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
      final progress = (1 - world.pulseTimer / 0.55).clamp(0.0, 1.0);
      final pc = center(world.pulseX!, world.pulseY!);
      final outer = tile * (0.55 + progress * 2.8);
      canvas.drawCircle(
        pc,
        outer,
        Paint()
          ..color = Color.fromRGBO(255, 230, 120, 0.85 * (1 - progress * 0.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.5, tile * 0.12),
      );
      canvas.drawCircle(
        pc,
        outer * 0.55,
        Paint()
          ..color = Color.fromRGBO(255, 248, 200, 0.55 * (1 - progress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.8, tile * 0.08),
      );
      canvas.drawCircle(
        pc,
        tile * 0.35 * (1 - progress * 0.4),
        Paint()..color = Color.fromRGBO(255, 240, 180, 0.4 * (1 - progress)),
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
      final ring = Color(world.godHandArgb);
      canvas.drawCircle(
        gc,
        r,
        Paint()
          ..color = ring.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, tile * 0.06),
      );
      canvas.drawCircle(
        gc,
        tile * 0.22 * pulse,
        Paint()..color = ring.withValues(alpha: 0.75),
      );
      canvas.drawCircle(
        gc,
        tile * 0.1,
        Paint()..color = ring,
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
          p.label == 'PYRO' ? const Color(0xFFFF4010) : const Color(0xFFFF3C10),
        SpellBoltStyle.holy => const Color(0xFFFFF8E0),
        SpellBoltStyle.frost => const Color(0xFF4EE4FF),
        SpellBoltStyle.arcane => const Color(0xFFE040FF),
        SpellBoltStyle.shadow => const Color(0xFF9040D0),
        SpellBoltStyle.demon => const Color(0xFF70FF40),
        SpellBoltStyle.nature => const Color(0xFF2EAA55),
        SpellBoltStyle.poison => const Color(0xFFE4F04A),
        SpellBoltStyle.lightning => const Color(0xFFB8F0FF),
        SpellBoltStyle.arrow => const Color(0xFFD8C070),
        SpellBoltStyle.weapon =>
          p.team == SpatialTeam.hero
              ? (p.isCrit ? const Color(0xFFFFF0C0) : const Color(0xFFFFE08A))
              : const Color(0xFFFF6A4A),
      };
      final zoneTint = DungeonEnvironment.projectileTint(dungeonId);
      final color = Color.lerp(baseColor, zoneTint, 0.10)!;
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

      void shadowEyes() {
        final slit = Paint()..color = const Color(0xFFFFE080);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(-thick * 0.28, -thick * 0.15),
              width: thick * 0.42,
              height: thick * 0.16,
            ),
            Radius.circular(thick * 0.08),
          ),
          slit,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(thick * 0.28, -thick * 0.15),
              width: thick * 0.42,
              height: thick * 0.16,
            ),
            Radius.circular(thick * 0.08),
          ),
          slit,
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
          shadowEyes();
        case SpellBoltStyle.demon:
          canvas.drawCircle(
            Offset(-len * 0.2, 0),
            thick * 1.6,
            Paint()..color = const Color(0x66402010),
          );
          drawOrb(core: 1.1, glow: const Color(0xFF40C020));
          canvas.drawCircle(
            Offset.zero,
            thick * 0.35,
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
        case SpellBoltStyle.poison:
          drawOrb(core: 1.0, glow: const Color(0xFFA0E040));
          canvas.drawCircle(
            Offset(len * 0.25, thick * 0.35),
            thick * 0.35,
            Paint()..color = const Color(0xAA70B020),
          );
          canvas.drawCircle(
            Offset(len * 0.4, -thick * 0.25),
            thick * 0.28,
            Paint()..color = const Color(0xAA90D040),
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
      final hit = enemy.hitFlash;
      final isBoss = enemy.role == EnemyRole.boss;
      final isElite = enemy.role == EnemyRole.elite;
      final zoneTint = DungeonEnvironment.projectileTint(dungeonId);
      var c = center(enemy.x, enemy.y);
      final scale =
          (isBoss ? 1.42 : (isElite ? 1.18 : 0.9)) *
          (1 + flash * 0.18 + hit * 0.12);
      final moving = enemy.vx.abs() > 0.05 || enemy.vy.abs() > 0.05;
      if (moving && enemy.isAlive) {
        final phase = ((enemy.x + enemy.y).abs() * 2.5 + visualFrame * 0.08) % 1.0;
        c += CharacterVisualPainter.clipMotion(
          HeroAnimKind.walk,
          phase,
          tile * scale,
        );
      }
      if (isBoss && enemy.isAlive) {
        canvas.drawCircle(
          c,
          tile * 0.58,
          Paint()..color = const Color(0x55000000),
        );
        canvas.drawCircle(
          c,
          tile * 0.52,
          Paint()
            ..color = zoneTint.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.8, tile * 0.07),
        );
      }
      drawSprite(img, c, scale, alpha: enemy.isAlive ? 1 : 0.2);
      if (hit > 0.02 && enemy.isAlive) {
        canvas.drawCircle(
          c,
          tile * (isBoss ? 0.42 : 0.34) * (0.55 + hit),
          Paint()
            ..color = zoneTint.withValues(alpha: 0.55 * hit.clamp(0.0, 1.0)),
        );
      }
      if (enemy.isAlive &&
          enemy.fireCooldown > 0 &&
          enemy.fireCooldown < 0.45 &&
          enemy.attackCooldown > 0) {
        final wind = (1.0 - (enemy.fireCooldown / 0.45)).clamp(0.0, 1.0);
        final reach = isBoss ? 0.72 : (isElite ? 0.5 : 0.38);
        final job = switch (enemy.archetype) {
          EnemyArchetype.swarm => const Color(0xFFE8E040),
          EnemyArchetype.brute => const Color(0xFFE07040),
          EnemyArchetype.tank => const Color(0xFFE8C060),
          EnemyArchetype.ranged => const Color(0xFF40C8E8),
          EnemyArchetype.glass => const Color(0xFFE060C0),
          EnemyArchetype.support => const Color(0xFF70E090),
        };
        final tell = Color.lerp(job, zoneTint, 0.22)!;
        canvas.drawCircle(
          c,
          tile * (reach + wind * (isBoss ? 0.28 : 0.12)),
          Paint()
            ..color = tell.withValues(alpha: 0.35 + wind * 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(
              isBoss ? 2.4 : 1.6,
              tile * (isBoss ? 0.09 : 0.05),
            ),
        );
      }
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
        if (SpatialCombat.alwaysShowEnemyHp ||
            enemy.hp < enemy.maxHp ||
            enemy.hp <= 0) {
          drawBar(c, enemy.hp, enemy.maxHp, tile * 0.85);
        }
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
      final alpha = hero.isAlive ? 1.0 : 0.25;
      final paintAlpha = hero.vanishTimer > 0 ? 0.35 : alpha;
      if (partyHero != null) {
        final moving = hero.vx.abs() > 0.05 || hero.vy.abs() > 0.05;
        final signals = HeroAnimSignals(
          moving: moving,
          attacking: flash > 0.02,
          casting: hero.castFlash > 0.02 || hero.castingTimer > 0.05,
          hit: hero.hitFlash > 0.02,
          dead: !hero.isAlive,
          blocking: hero.shieldBlockTimer > 0,
          attackFlash: flash,
          castFlash: hero.castFlash,
          hitFlash: hero.hitFlash,
        );
        final walkPhase =
            ((hero.x + hero.y).abs() * 2.5 + visualFrame * 0.08) % 1.0;
        final anim = HeroAnimController.snapshot(
          signals,
          walkPhase: walkPhase,
        );
        // Unique form PNG (Druid forms / Shadow) → owned paper-doll → class PNG.
        final useFormSprite =
            CustomAssets.hasUniqueHeroSprite(partyHero.specId);
        final formImg =
            useFormSprite ? heroesBySpec[partyHero.specId] : null;
        final bodyPath = BodyFamilyCatalog.assetFor(partyHero, anim.kind);
        ui.Image? bodyImg =
            useFormSprite ? null : bodyByPath[bodyPath];
        final usingOwnedBody = bodyImg != null;
        Color? tint;
        if (bodyImg == null && formImg == null) {
          bodyImg = heroesBySpec[partyHero.specId] ??
              heroesByClass[HeroIdentity.spriteClassFor(partyHero.specId)];
          final argb = HeroIdentity.tintArgb(partyHero.specId);
          if (argb != null) tint = Color(argb);
        }
        bodyImg ??= heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
        // Form sprites are 96px; owned denser bodies read larger than Kenney.
        // Plate reads broader than leather at HUD size; forms keep their PNG.
        final read = usingOwnedBody
            ? BodyFamilyCatalog.hudReadScale(
                BodyFamilyCatalog.familyFor(partyHero),
              )
            : 1.0;
        final scale = (formImg != null
                ? 1.42
                : (usingOwnedBody ? 1.72 * read : 0.95)) *
            (1 + flash * (hero.heroRole == HeroRole.warrior ? 0.32 : 0.2));
        final motion = CharacterVisualPainter.clipMotion(
          anim.kind,
          anim.progress,
          tile * scale,
          flipX: flipX,
        );
        if (formImg != null) {
          // Persistent form bodies — no gear overlays (silhouette is the kit).
          // Same step bob as the paper doll so a walk is not a frozen PNG.
          drawSprite(
            formImg,
            c + motion,
            scale,
            alpha: paintAlpha,
            flipX: flipX,
          );
        } else if (bodyImg != null) {
          if (usingOwnedBody) {
            final ownedPose = CharacterVisualPoseCache.resolve(
              heroId: hero.id,
              hero: partyHero,
              anim: anim,
              flipX: flipX,
              partyIndex: idx,
              owned: true,
            );
            CharacterVisualPainter.paintOwnedHero(
              canvas,
              c,
              tile * scale,
              body: bodyImg,
              images: bodyByPath,
              pose: ownedPose,
              alpha: paintAlpha,
            );
          } else {
            drawSprite(
              bodyImg,
              c,
              scale,
              alpha: paintAlpha,
              tint: tint,
              flipX: flipX,
            );
          }
        } else {
          final img = heroes[hero.assetIndex.clamp(0, heroes.length - 1)];
          if (img != null) {
            final scale = 0.95 *
                (1 +
                    flash *
                        (hero.heroRole == HeroRole.warrior ? 0.32 : 0.2));
            drawSprite(img, c, scale, alpha: paintAlpha, flipX: flipX);
          }
        }
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
      if (hero.isAlive &&
          showGuide &&
          hero.castingTimer > 0.02 &&
          hero.castingDuration > 0.05) {
        final progress =
            (1.0 - (hero.castingTimer / hero.castingDuration)).clamp(0.0, 1.0);
        final ringR = tile * 0.52;
        final rect = Rect.fromCircle(center: c, radius: ringR);
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2,
          false,
          Paint()
            ..color = const Color(0x55FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, tile * 0.06),
        );
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * progress,
          false,
          Paint()
            ..color = const Color(0xEEFFE08A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.2, tile * 0.09)
            ..strokeCap = StrokeCap.round,
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
        if (kind == SpatialBurstKind.slash) {
          final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final sweep = 1.45;
          final start = (burst.angle ?? (burst.life * 9)) - sweep * 0.5;
          final r = tile * burst.radius * (0.75 + (1 - alpha) * 0.4);
          final rect = Rect.fromCircle(center: c, radius: r);
          final sweepDraw = sweep * alpha.clamp(0.45, 1.0);
          canvas.drawArc(
            rect,
            start,
            sweepDraw,
            false,
            Paint()
              ..color = const Color(0xE6100C08).withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(5.5, tile * 0.32)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawArc(
            rect,
            start,
            sweepDraw,
            false,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(3.2, tile * 0.2)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.72),
            start,
            sweepDraw,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.8, tile * 0.09)
              ..strokeCap = StrokeCap.round,
          );
          final tipAng = start + sweepDraw * 0.9;
          canvas.drawCircle(
            Offset(c.dx + math.cos(tipAng) * r, c.dy + math.sin(tipAng) * r),
            math.max(2.2, tile * 0.09),
            Paint()..color = Colors.white.withValues(alpha: alpha),
          );
        } else if (kind == SpatialBurstKind.ring) {
          final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.55 + (1 - alpha) * 0.7);
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = const Color(0xCC100C08).withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(4.2, tile * 0.2),
          );
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.95)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.4, tile * 0.11),
          );
          canvas.drawCircle(
            c,
            r * 0.7,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.4, tile * 0.055),
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
          final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
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
          final maxLife = 0.55;
          final alpha = (burst.life / maxLife).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (1.15 - alpha * 0.28);
          canvas.drawCircle(
            c,
            r,
            Paint()..color = const Color(0xAA100C08).withValues(alpha: alpha * 0.85),
          );
          canvas.drawCircle(
            c,
            r * 0.82,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.7),
          );
          canvas.drawCircle(
            c,
            r * 0.42,
            Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
          );
        }
      }
    }

    if (showBursts || showPriorityFloaters) {
      final floaters = world.floaters;
      final tp = TextPainter(textDirection: TextDirection.ltr);
      final maxW = tile * 4.4;
      for (var i = 0; i < floaters.length; i++) {
        final floater = floaters[i];
        if (!showBursts && floater.priority < 2) continue;
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
        final anchor = speech
            ? Offset(c.dx - tp.width / 2, c.dy - tp.height / 2)
            : Offset(c.dx + tile * 0.46 - tp.width / 2, c.dy - tile * 0.22);
        tp.paint(canvas, anchor);
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
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x99100C08).withValues(alpha: 0.85 * frac)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.2, tile * 0.11),
    );
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
            Paint()..color = const Color(0x882EAA55).withValues(alpha: 0.5 * frac),
          );
        }
      case SpatialGroundFxKind.poison:
        for (var i = 0; i < 4; i++) {
          final a = i * 1.6;
          canvas.drawCircle(
            Offset(
              c.dx + math.cos(a) * r * 0.45,
              c.dy + math.sin(a) * r * 0.45,
            ),
            r * 0.12,
            Paint()..color = const Color(0xAAE4F04A).withValues(alpha: 0.55 * frac),
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
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = center(burst.x, burst.y);
    final r = tile * burst.radius * (0.78 + (1 - alpha) * 0.32);
    final color = Color(burst.argb);
    final ink = Paint()
      ..color = const Color(0xE6100C08).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3.4, tile * 0.13)
      ..strokeCap = StrokeCap.round;
    switch (burst.kind) {
      case SpatialBurstKind.beam:
        final end = burst.x2 != null && burst.y2 != null
            ? center(burst.x2!, burst.y2!)
            : Offset(c.dx, c.dy - r * 2.4);
        final dx = end.dx - c.dx;
        final dy = end.dy - c.dy;
        final len = math.sqrt(dx * dx + dy * dy) + 0.001;
        final nx = -dy / len;
        final ny = dx / len;
        final zig = Path()..moveTo(c.dx, c.dy);
        for (var i = 1; i <= 4; i++) {
          final t = i / 5;
          final side = (i.isOdd ? 1.0 : -1.0) * r * 0.42;
          zig.lineTo(c.dx + dx * t + nx * side, c.dy + dy * t + ny * side);
        }
        zig.lineTo(end.dx, end.dy);
        canvas.drawPath(zig, ink);
        canvas.drawPath(
          zig,
          Paint()
            ..color = color.withValues(alpha: alpha * 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.4, tile * 0.09)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          zig,
          Paint()
            ..color = Colors.white.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.1, tile * 0.04)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          end,
          r * 0.42,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      case SpatialBurstKind.rain:
        for (var i = 0; i < 8; i++) {
          final a = i * 0.85;
          final ox = math.cos(a) * r * 0.75;
          final oy = math.sin(a) * r * 0.35;
          final fall = (1 - alpha) * r * 0.7;
          final a0 = Offset(c.dx + ox, c.dy + oy - r * 1.05 + fall);
          final a1 = Offset(c.dx + ox, c.dy + oy - r * 0.12 + fall);
          canvas.drawLine(
            a0,
            a1,
            Paint()
              ..color = const Color(0xCC100C08).withValues(alpha: alpha)
              ..strokeWidth = math.max(3.0, tile * 0.1)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            a0,
            a1,
            Paint()
              ..color = color.withValues(alpha: alpha)
              ..strokeWidth = math.max(1.6, tile * 0.055)
              ..strokeCap = StrokeCap.round,
          );
        }
      case SpatialBurstKind.shards:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + (1 - alpha) * 0.4;
          final p = Path()
            ..moveTo(
              c.dx + math.cos(a) * r * 1.25,
              c.dy + math.sin(a) * r * 1.25,
            )
            ..lineTo(
              c.dx + math.cos(a + 0.28) * r * 0.22,
              c.dy + math.sin(a + 0.28) * r * 0.22,
            )
            ..lineTo(
              c.dx + math.cos(a - 0.28) * r * 0.22,
              c.dy + math.sin(a - 0.28) * r * 0.22,
            )
            ..close();
          canvas.drawPath(
            p,
            Paint()..color = const Color(0xDD100C08).withValues(alpha: alpha),
          );
          canvas.drawPath(p, Paint()..color = color.withValues(alpha: alpha));
        }
        canvas.drawCircle(
          c,
          r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      case SpatialBurstKind.flame:
        // Petals bias upward so fire reads as rising, not a tinted disc.
        for (var i = 0; i < 5; i++) {
          final a = -1.15 + i * 0.55 + (1 - alpha) * 0.2;
          final lift = r * 0.35 * (1 - alpha);
          final p = Path()
            ..moveTo(c.dx, c.dy + r * 0.15)
            ..quadraticBezierTo(
              c.dx + math.cos(a + 0.35) * r * 0.45,
              c.dy + math.sin(a + 0.35) * r * 0.45 - lift,
              c.dx + math.cos(a) * r * 1.2,
              c.dy + math.sin(a) * r * 1.2 - lift,
            )
            ..quadraticBezierTo(
              c.dx + math.cos(a - 0.35) * r * 0.45,
              c.dy + math.sin(a - 0.35) * r * 0.45 - lift,
              c.dx,
              c.dy + r * 0.15,
            );
          canvas.drawPath(
            p,
            Paint()..color = const Color(0xBB100C08).withValues(alpha: alpha),
          );
          canvas.drawPath(
            p,
            Paint()..color = color.withValues(alpha: alpha * 0.88),
          );
        }
        canvas.drawCircle(
          c,
          r * 0.34,
          Paint()..color = const Color(0xFFFFF0A0).withValues(alpha: alpha),
        );
      case SpatialBurstKind.cross:
        final arm = r * 1.15;
        canvas.drawLine(
          Offset(c.dx, c.dy - arm),
          Offset(c.dx, c.dy + arm * 0.55),
          ink,
        );
        canvas.drawLine(
          Offset(c.dx - arm * 0.75, c.dy - arm * 0.12),
          Offset(c.dx + arm * 0.75, c.dy - arm * 0.12),
          ink,
        );
        final holy = Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeWidth = math.max(2.4, tile * 0.1)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(c.dx, c.dy - arm),
          Offset(c.dx, c.dy + arm * 0.55),
          holy,
        );
        canvas.drawLine(
          Offset(c.dx - arm * 0.75, c.dy - arm * 0.12),
          Offset(c.dx + arm * 0.75, c.dy - arm * 0.12),
          holy,
        );
        canvas.drawCircle(
          c,
          r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      case SpatialBurstKind.poison:
        for (var i = 0; i < 5; i++) {
          final a = -0.4 + i * 0.55;
          final fall = r * 0.45 * (1 - alpha);
          final drip = Offset(
            c.dx + math.sin(a) * r * 0.55,
            c.dy + math.cos(a) * r * 0.15 + fall,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: drip,
              width: r * 0.32,
              height: r * 0.62,
            ),
            Paint()..color = const Color(0xCC100C08).withValues(alpha: alpha),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: drip,
              width: r * 0.24,
              height: r * 0.5,
            ),
            Paint()..color = color.withValues(alpha: alpha * 0.9),
          );
        }
        canvas.drawCircle(
          c,
          r * 0.26,
          Paint()..color = const Color(0xAAE8FFC0).withValues(alpha: alpha),
        );
      case SpatialBurstKind.skull:
        final head = Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * 0.08),
          width: r * 1.55,
          height: r * 1.7,
        );
        canvas.drawOval(
          head.inflate(r * 0.08),
          Paint()..color = const Color(0xDD100C08).withValues(alpha: alpha),
        );
        canvas.drawOval(
          head,
          Paint()..color = color.withValues(alpha: alpha * 0.92),
        );
        canvas.drawCircle(
          Offset(c.dx - r * 0.3, c.dy - r * 0.18),
          r * 0.2,
          Paint()..color = const Color(0xFF100C08).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(c.dx + r * 0.3, c.dy - r * 0.18),
          r * 0.2,
          Paint()..color = const Color(0xFF100C08).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(c.dx - r * 0.3, c.dy - r * 0.18),
          r * 0.08,
          Paint()..color = const Color(0xFFFFE080).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(c.dx + r * 0.3, c.dy - r * 0.18),
          r * 0.08,
          Paint()..color = const Color(0xFFFFE080).withValues(alpha: alpha),
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * 0.32),
            width: r * 0.72,
            height: r * 0.42,
          ),
          0.25,
          math.pi - 0.5,
          false,
          Paint()
            ..color = const Color(0xEE100C08).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
      default:
        canvas.drawCircle(
          c,
          r,
          Paint()..color = color.withValues(alpha: alpha * 0.7),
        );
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
        !identical(enemies, oldDelegate.enemies) ||
        !identical(heroesByClass, oldDelegate.heroesByClass) ||
        !identical(heroesBySpec, oldDelegate.heroesBySpec) ||
        !identical(bodyByPath, oldDelegate.bodyByPath);
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
