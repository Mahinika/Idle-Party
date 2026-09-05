import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dungeon_def.dart';
import '../../assets/custom_assets.dart';
import '../game_theme.dart';
import '../../assets/kenney_assets.dart';
import '../kenney_sprite.dart';
import '../web_click_bridge.dart';

class SelectedZoneCaption extends StatelessWidget {
  const SelectedZoneCaption({
    super.key,
    required this.dungeon,
    required this.unlocked,
    required this.partyLevel,
    this.keyLevel = 0,
    this.keyAffixLine,
  });

  final DungeonDef dungeon;
  final bool unlocked;
  final int partyLevel;
  final int keyLevel;
  final String? keyAffixLine;

  @override
  Widget build(BuildContext context) {
    if (unlocked) {
      return Column(
        children: [
          Text(
            '${dungeon.name} · Boss: ${dungeon.bossName}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          if (keyLevel > 0)
            Text(
              keyAffixLine != null && keyAffixLine!.isNotEmpty
                  ? 'KEY +$keyLevel · $keyAffixLine'
                  : 'KEY +$keyLevel',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.torchHot),
            )
          else if (dungeon.blurb.isNotEmpty)
            Text(
              dungeon.blurb,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
        ],
      );
    }
    final need = DungeonCatalog.unlockHeroLevel(dungeon);
    final prevName = dungeon.number <= 0
        ? 'the start'
        : DungeonCatalog.all[dungeon.number - 1].name;
    final detail = need > 1
        ? 'Clear $prevName or party Lv$need'
        : 'Locked';
    return Text(
      '${dungeon.name} · $detail',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
    );
  }
}

class ZonePathMap extends StatefulWidget {
  const ZonePathMap({
    super.key,
    required this.dungeons,
    required this.selectedId,
    required this.partyLevel,
    required this.highestCleared,
    required this.pulse,
    required this.onSelect,
  });

  final List<DungeonDef> dungeons;
  final String selectedId;
  final int partyLevel;
  final int highestCleared;
  final double pulse;
  final ValueChanged<String> onSelect;

  /// Marker centers on painted gold rings (zone 0…14 top→bottom).
  /// Upper path from Stormwake base; endgame rings detected on rebuilt footer.
  static const List<Offset> markerNorm = [
    Offset(0.491, 0.042), // sandy — cave mouth
    Offset(0.483, 0.088), // goblin — camp
    Offset(0.474, 0.146), // king — fort wall
    Offset(0.514, 0.197), // underworld — purple crystals
    Offset(0.454, 0.249), // dead — tombs
    Offset(0.479, 0.303), // hell — spiked gate
    Offset(0.465, 0.355), // crystal — ice peaks
    Offset(0.503, 0.403), // tide — sunken ruins
    Offset(0.466, 0.449), // ember — lava door
    Offset(0.478, 0.513), // grove — dark forest
    Offset(0.485, 0.570), // storm — purple chasm
    Offset(0.544, 0.635), // rime — ice-rift ring
    Offset(0.506, 0.736), // fen — mire ring
    Offset(0.507, 0.839), // brass — vault ring
    Offset(0.499, 0.963), // veil — moth-dust ring
  ];

  static const double mapAspect = 2532 / 1024;

  @override
  State<ZonePathMap> createState() => _ZonePathMapState();
}

class _ZonePathMapState extends State<ZonePathMap> {
  final ScrollController _scroll = ScrollController();
  String? _scrolledTo;
  bool _didInitialJump = false;
  double? _lastMapH;
  double? _lastViewH;

  @override
  void didUpdateWidget(covariant ZonePathMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _scrolledTo = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime? _userPanAt; // FEEL 077

  void _ensureSelectedVisible(double mapH, double viewH) {
    if (!_scroll.hasClients) return;
    if (_userPanAt != null &&
        DateTime.now().difference(_userPanAt!) <
            const Duration(seconds: 2)) {
      return;
    }
    if (_scrolledTo == widget.selectedId &&
        _lastMapH == mapH &&
        _lastViewH == viewH) {
      return;
    }
    final idx = widget.dungeons.indexWhere((d) => d.id == widget.selectedId);
    if (idx < 0 || idx >= ZonePathMap.markerNorm.length) return;
    final y = ZonePathMap.markerNorm[idx].dy * mapH;
    // Keep HERE near vertical center of the path viewport.
    final target = (y - viewH * 0.45)
        .clamp(0.0, math.max(0.0, mapH - viewH))
        .toDouble();
    _scrolledTo = widget.selectedId;
    _lastMapH = mapH;
    _lastViewH = viewH;
    if (!_didInitialJump) {
      _didInitialJump = true;
      _scroll.jumpTo(target);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static String _statusWord({
    required bool unlocked,
    required bool cleared,
    required bool selected,
    required bool frontier,
  }) {
    // Grey portrait = locked; moss ring = cleared. Words only for the
    // node you are on and the next push, so they don't cover the icon below.
    if (selected) return 'HERE';
    if (frontier && unlocked && !cleared) return 'NEXT';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        if (mapW < 8 || viewH < 8) return const SizedBox.shrink();
        final mapH = mapW * ZonePathMap.mapAspect;
        // Disc stays readable; hit box meets phone minTouch (44).
        final discSize = (mapW * 0.092).clamp(34.0, 40.0);
        final hitSize = math.max(discSize, GameTheme.minTouch);
        const statusH = 15.0;

        final needsScroll =
            _scrolledTo != widget.selectedId ||
            _lastMapH != mapH ||
            _lastViewH != viewH;
        if (needsScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureSelectedVisible(mapH, viewH);
          });
        }

        final dungeons = widget.dungeons;
        assert(
          dungeons.length == ZonePathMap.markerNorm.length,
          'World Path markerNorm must match DungeonCatalog (${dungeons.length} vs ${ZonePathMap.markerNorm.length})',
        );
        final n = math.min(dungeons.length, ZonePathMap.markerNorm.length);

        final pathChildren = <Widget>[
          Positioned.fill(
            child: ExcludeSemantics(
              child: Image.asset(
                CustomAssets.worldPathMap,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                // Decode at the size we actually paint. The source is
                // 1024x2532; without a cap that is ~10 MB of decoded memory
                // for a map drawn ~336 logical px wide.
                cacheWidth: (mapW * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(256, 1024),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      GameTheme.ink.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];

        for (var i = 0; i < n; i++) {
          final d = dungeons[i];
          final anchor = ZonePathMap.markerNorm[i];
          final unlocked = DungeonCatalog.isUnlocked(
            d.id,
            widget.partyLevel,
            widget.highestCleared,
          );
          final cleared = widget.highestCleared >= d.number;
          final selected = d.id == widget.selectedId;
          // Frontier = lowest uncleared unlocked zone (what to push next).
          final frontier =
              unlocked && !cleared && d.number == widget.highestCleared + 1;
          final statusWord = _statusWord(
            unlocked: unlocked,
            cleared: cleared,
            selected: selected,
            frontier: frontier,
          );
          final labelH = statusWord.isEmpty ? 0.0 : statusH;
          final cx = anchor.dx * mapW;
          final cy = anchor.dy * mapH;
          final left = (cx - hitSize / 2).clamp(0.0, mapW - hitSize).toDouble();
          final top = (cy - hitSize / 2 - labelH)
              .clamp(0.0, math.max(0.0, mapH - hitSize - labelH))
              .toDouble();
          pathChildren.add(
            Positioned(
              left: left,
              top: top,
              width: hitSize,
              height: hitSize + labelH,
              child: MapZoneMarker(
                def: d,
                discSize: discSize,
                hitSize: hitSize,
                unlocked: unlocked,
                cleared: cleared,
                selected: selected,
                pulse: widget.pulse,
                statusWord: statusWord,
                onTap: () => widget.onSelect(d.id),
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              width: mapW,
              height: mapH,
              child: Stack(clipBehavior: Clip.none, children: pathChildren),
            ),
          ),
        );
      },
    );
  }
}

class MapZoneMarker extends StatelessWidget {
  const MapZoneMarker({
    super.key,
    required this.def,
    required this.discSize,
    required this.hitSize,
    required this.unlocked,
    required this.cleared,
    required this.selected,
    required this.pulse,
    required this.statusWord,
    required this.onTap,
  });

  final DungeonDef def;
  final double discSize;
  final double hitSize;
  final bool unlocked;
  final bool cleared;
  final bool selected;
  final double pulse;
  final String statusWord;
  final VoidCallback onTap;

  Color get _statusColor {
    if (selected) return GameTheme.torchHot;
    if (cleared) return GameTheme.mossLit;
    if (unlocked) return GameTheme.torch;
    return GameTheme.parchmentDim;
  }

  @override
  Widget build(BuildContext context) {
    final ring = selected
        ? Color.lerp(GameTheme.torch, GameTheme.torchHot, pulse)!
        : (cleared
              ? GameTheme.mossLit.withValues(alpha: 0.55)
              : (unlocked
                    ? GameTheme.torch.withValues(alpha: 0.35)
                    : Colors.transparent));
    final semanticsLabel =
        '${def.name}, $statusWord${selected ? ', selected' : ''}';
    final iconSize = discSize * 0.82;

    Widget portrait = KenneySprite(
      asset: KenneyAssets.dungeonPortraitFor(def.id),
      size: iconSize,
    );
    if (!unlocked) {
      portrait = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.35,
          0.35,
          0.35,
          0,
          0,
          0.35,
          0.35,
          0.35,
          0,
          0,
          0.35,
          0.35,
          0.35,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
        ]),
        child: portrait,
      );
    }

    return WebClickScope(
      label: semanticsLabel,
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: unlocked,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusWord.isNotEmpty)
                Text(
                  statusWord,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: GameTheme.body(size: 11, color: _statusColor),
                ),
              SizedBox(
                width: hitSize,
                height: hitSize,
                child: Center(
                  child: SizedBox(
                    width: discSize,
                    height: discSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: GameTheme.hudMapCaption.withValues(alpha: 0.75),
                        border: Border.all(
                          color: ring,
                          width: selected ? 2.5 : 1.2,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: GameTheme.torch.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 10 + pulse * 3,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(child: ClipOval(child: portrait)),
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
}
