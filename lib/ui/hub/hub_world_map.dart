import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/hub_endgame_act.dart';
import '../../models/dungeon_def.dart';
import '../../assets/custom_assets.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import '../shell/shell_layout.dart';
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
    this.hideBlurb = false,
    this.compact = true,
  });

  final DungeonDef dungeon;
  final bool unlocked;
  final int partyLevel;
  final int keyLevel;
  final String? keyAffixLine;
  final bool hideBlurb;
  final bool compact;

  String _oneLineUnlocked() {
    if (keyLevel > 0) {
      return keyAffixLine != null && keyAffixLine!.isNotEmpty
          ? '${dungeon.name} · KEY +$keyLevel'
          : '${dungeon.name} · KEY +$keyLevel';
    }
    return dungeon.name;
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: dungeon.name,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Boss: ${dungeon.bossName}',
              style: GameTheme.section(color: GameTheme.parchmentDim),
            ),
            if (keyLevel > 0) ...[
              const SizedBox(height: 6),
              Text(
                keyAffixLine != null && keyAffixLine!.isNotEmpty
                    ? 'KEY +$keyLevel · $keyAffixLine'
                    : 'KEY +$keyLevel',
                style: GameTheme.hint(color: GameTheme.torchHot),
              ),
            ],
            if (dungeon.blurb.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                dungeon.blurb,
                style: GameTheme.hint(color: GameTheme.parchmentDim),
              ),
            ],
          ],
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'CLOSE',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (unlocked) {
      if (compact) {
        return Semantics(
          button: true,
          label: '${_oneLineUnlocked()}. Tap for zone details',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showDetail(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KenneySprite(
                    asset: KenneyAssets.dungeonIconFor(dungeon.id),
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _oneLineUnlocked(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.section(color: GameTheme.parchmentDim),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Column(
        children: [
          Text(
            '${dungeon.name} · Boss: ${dungeon.bossName}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.section(color: GameTheme.parchmentDim),
          ),
          if (keyLevel > 0)
            Text(
              keyAffixLine != null && keyAffixLine!.isNotEmpty
                  ? 'KEY +$keyLevel · $keyAffixLine'
                  : 'KEY +$keyLevel',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.hint(color: GameTheme.torchHot),
            )
          else if (!hideBlurb && dungeon.blurb.isNotEmpty)
            Text(
              dungeon.blurb,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
        ],
      );
    }
    final need = DungeonCatalog.unlockHeroLevel(dungeon);
    final prevName = dungeon.number <= 0
        ? 'Sandy'
        : DungeonCatalog.all[dungeon.number - 1].name;
    return Text(
      '${dungeon.name} · party Lv$partyLevel / $need · clear $prevName · gold does not unlock',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GameTheme.section(color: GameTheme.parchmentDim),
    );
  }
}

class SelectedHuntCaption extends StatelessWidget {
  const SelectedHuntCaption({
    super.key,
    required this.hunt,
    this.grBestTier = 0,
  });

  final HubEndgameHunt hunt;
  final int grBestTier;

  @override
  Widget build(BuildContext context) {
    final node = HubEndgameAct.nodeFor(hunt);
    final title = HubEndgameAct.titleFor(hunt, grBestTier: grBestTier);
    return Padding(
      padding: ShellLayout.hubScenePadding.copyWith(top: 0, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.section(color: GameTheme.torchHot),
          ),
          ShellLayout.gap(2),
          ShellLayout.hint(node.blurb, maxLines: 2),
        ],
      ),
    );
  }
}

class ZonePathMap extends StatelessWidget {
  const ZonePathMap({
    super.key,
    required this.dungeons,
    required this.selectedId,
    required this.partyLevel,
    required this.highestCleared,
    required this.onSelect,
    this.pulse,
  });

  final List<DungeonDef> dungeons;
  final String selectedId;
  final int partyLevel;
  final int highestCleared;

  /// HERE-ring torch only — not a full-map rebuild every tick.
  final Animation<double>? pulse;
  final ValueChanged<String> onSelect;

  /// `world_path_map.png` is 864×1152. Contain-fit uses this so lands
  /// are not stretched into the hub's leftover band.
  static const double mapAspect = 864 / 1152;

  /// Short boards scroll instead of vanishing. A 100 px slot still paints.
  static const double minBoardHeight = 120;

  /// Marker centers on the continent board (catalog order 0…14).
  /// Not a vertical road — clusters are lands (frost, dunes, ash, veil…).
  static const List<Offset> markerNorm = [
    Offset(0.20, 0.78), // sandy — dune coast
    Offset(0.34, 0.74), // goblin — dune hills
    Offset(0.20, 0.38), // king — crownlands
    Offset(0.36, 0.42), // underworld — deep highland
    Offset(0.42, 0.58), // dead — blight
    Offset(0.58, 0.82), // hell — ash isles
    Offset(0.28, 0.14), // crystal — frost
    Offset(0.12, 0.56), // tide — western isles
    Offset(0.74, 0.78), // ember — ash caldera
    Offset(0.58, 0.36), // grove — green belt
    Offset(0.74, 0.18), // storm — storm reach
    Offset(0.46, 0.12), // rime — frost rift
    Offset(0.54, 0.62), // fen — blight mire
    Offset(0.80, 0.56), // brass — brass coast
    Offset(0.86, 0.34), // veil — moth woods
  ];

  /// Overlay word on a ring. Continent art already names the land.
  static String ringLabel({
    required bool unlocked,
    required bool cleared,
    required bool selected,
    required bool frontier,
  }) {
    if (selected) return 'HERE';
    if (frontier && unlocked && !cleared) return 'NEXT';
    return '';
  }

  /// Image rect after [BoxFit.contain] inside [box].
  static Rect containRect(Size box) {
    final aspect = mapAspect;
    if (box.width <= 0 || box.height <= 0) return Rect.zero;
    final boxAspect = box.width / box.height;
    if (boxAspect > aspect) {
      final h = box.height;
      final w = h * aspect;
      return Rect.fromLTWH((box.width - w) / 2, 0, w, h);
    }
    final w = box.width;
    final h = w / aspect;
    return Rect.fromLTWH(0, (box.height - h) / 2, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        if (boxW < 8 || !boxW.isFinite) return const SizedBox.shrink();
        final rawH = constraints.maxHeight;
        final innerH = !rawH.isFinite
            ? boxW / mapAspect
            : math.max(rawH, minBoardHeight);
        final board = _board(context, Size(boxW, innerH));
        if (rawH.isFinite && rawH + 0.5 < innerH) {
          return SingleChildScrollView(
            child: SizedBox(width: boxW, height: innerH, child: board),
          );
        }
        return SizedBox(width: boxW, height: innerH, child: board);
      },
    );
  }

  Widget _board(BuildContext context, Size box) {
    final image = containRect(box);
    final discSize = (image.width * 0.16).clamp(32.0, 44.0);
    final hitSize = math.max(discSize + 6, GameTheme.minTouch + 4);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // Hint is 12px * line height 1.2. Leave room so HERE is not clipped.
    final statusH = 26.0 * textScale;

    final dungeons = this.dungeons;
    assert(
      dungeons.length == ZonePathMap.markerNorm.length,
      'World Path markerNorm must match DungeonCatalog (${dungeons.length} vs ${ZonePathMap.markerNorm.length})',
    );
    final n = math.min(dungeons.length, ZonePathMap.markerNorm.length);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final pathChildren = <Widget>[
      Positioned.fill(
        child: ExcludeSemantics(
          child: Image.asset(
            CustomAssets.worldPathMap,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
            cacheWidth: (image.width * dpr).round().clamp(256, 1024),
          ),
        ),
      ),
    ];

    for (var i = 0; i < n; i++) {
      final d = dungeons[i];
      final anchor = ZonePathMap.markerNorm[i];
      final unlocked = DungeonCatalog.isUnlocked(
        d.id,
        partyLevel,
        highestCleared,
      );
      final cleared = highestCleared >= d.number;
      final selected = d.id == selectedId;
      final frontier = unlocked && !cleared && d.number == highestCleared + 1;
      final statusWord = ringLabel(
        unlocked: unlocked,
        cleared: cleared,
        selected: selected,
        frontier: frontier,
      );
      final labelH = statusWord.isEmpty ? 0.0 : statusH;
      final columnW = math.max(hitSize, 96.0);
      final cx = image.left + anchor.dx * image.width;
      final cy = image.top + anchor.dy * image.height;
      final totalH = hitSize + labelH;
      final left = (cx - columnW / 2)
          .clamp(0.0, math.max(0.0, box.width - columnW))
          .toDouble();
      final top = (cy - hitSize / 2)
          .clamp(0.0, math.max(0.0, box.height - totalH))
          .toDouble();
      pathChildren.add(
        Positioned(
          left: left,
          top: top,
          width: columnW,
          height: totalH,
          child: MapZoneMarker(
            name: d.name,
            portraitDungeonId: d.id,
            discSize: discSize,
            hitSize: hitSize,
            unlocked: unlocked,
            cleared: cleared,
            selected: selected,
            pulse: selected ? pulse : null,
            statusWord: statusWord,
            onTap: () => onSelect(d.id),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
      child: Stack(clipBehavior: Clip.hardEdge, children: pathChildren),
    );
  }
}

class MapZoneMarker extends StatelessWidget {
  const MapZoneMarker({
    super.key,
    required this.name,
    required this.portraitDungeonId,
    required this.discSize,
    required this.hitSize,
    required this.unlocked,
    required this.cleared,
    required this.selected,
    required this.statusWord,
    required this.onTap,
    this.pulse,
    this.iconAsset,
  });

  final String name;
  final String portraitDungeonId;
  final double discSize;
  final double hitSize;
  final bool unlocked;
  final bool cleared;
  final bool selected;
  final Animation<double>? pulse;
  final String? iconAsset;
  final String statusWord;
  final VoidCallback onTap;

  Color get _statusColor {
    if (selected) return GameTheme.torchHot;
    if (cleared) return GameTheme.mossLit;
    if (unlocked) return GameTheme.torch;
    return GameTheme.parchmentDim;
  }

  Color _ringColor(double pulseValue) {
    if (selected) {
      return Color.lerp(GameTheme.torch, GameTheme.torchHot, pulseValue)!;
    }
    if (cleared) return GameTheme.mossLit.withValues(alpha: 0.55);
    if (unlocked) return GameTheme.torch.withValues(alpha: 0.35);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = '$name, $statusWord${selected ? ', selected' : ''}';
    final borderW = selected ? 2.0 : (cleared ? 1.0 : 0.0);
    final iconSize = discSize - borderW * 2;

    Widget portrait = KenneySprite(
      asset: iconAsset ?? KenneyAssets.dungeonIconFor(portraitDungeonId),
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

    final disc = selected && pulse != null
        ? AnimatedBuilder(
            animation: pulse!,
            builder: (context, child) {
              final p = pulse!.value;
              return _discShell(pulseValue: p, child: child!);
            },
            child: portrait,
          )
        : _discShell(pulseValue: 0, child: portrait);

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
              SizedBox(
                width: hitSize,
                height: hitSize,
                child: Center(child: disc),
              ),
              if (statusWord.isNotEmpty)
                Text(
                  statusWord,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GameTheme.hint(color: _statusColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _discShell({required double pulseValue, required Widget child}) {
    final borderW = selected ? 2.0 : (cleared ? 1.0 : 0.0);
    return SizedBox(
      width: discSize,
      height: discSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GameTheme.radiusHud),
          border: borderW > 0
              ? Border.all(color: _ringColor(pulseValue), width: borderW)
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(borderW),
          child: Center(child: child),
        ),
      ),
    );
  }
}
