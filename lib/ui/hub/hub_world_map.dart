import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/hub_endgame_act.dart';
import '../../models/dungeon_def.dart';
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
    this.hideBlurb = false,
  });

  final DungeonDef dungeon;
  final bool unlocked;
  final int partyLevel;
  final int keyLevel;
  final String? keyAffixLine;
  final bool hideBlurb;

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
          else if (!hideBlurb && dungeon.blurb.isNotEmpty)
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
    final detail = need > 1 ? 'Clear $prevName or party Lv$need' : 'Locked';
    return Text(
      '${dungeon.name} · $detail',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
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
    return Column(
      children: [
        Text(
          '$title · ENDGAME',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        Text(
          node.blurb,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
      ],
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

  static String _statusWord({
    required bool unlocked,
    required bool cleared,
    required bool selected,
    required bool frontier,
  }) {
    if (selected) return 'HERE';
    if (frontier && unlocked && !cleared) return 'NEXT';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = constraints.maxWidth;
        final mapH = constraints.maxHeight;
        if (mapW < 8 || mapH < 8) return const SizedBox.shrink();
        final discSize = (mapW * 0.078).clamp(28.0, 36.0);
        final hitSize = math.max(discSize, GameTheme.minTouch);
        const statusH = 15.0;

        final dungeons = this.dungeons;
        assert(
          dungeons.length == ZonePathMap.markerNorm.length,
          'World Path markerNorm must match DungeonCatalog (${dungeons.length} vs ${ZonePathMap.markerNorm.length})',
        );
        final n = math.min(dungeons.length, ZonePathMap.markerNorm.length);

        final pathChildren = <Widget>[
          const Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: HubWorldContinentsPainter()),
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
          final frontier =
              unlocked && !cleared && d.number == highestCleared + 1;
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
          child: Stack(clipBehavior: Clip.none, children: pathChildren),
        );
      },
    );
  }
}

/// Fitted ocean + landmasses. Hub viewport is the whole board (no scroll).
class HubWorldContinentsPainter extends CustomPainter {
  const HubWorldContinentsPainter({this.dim = false});

  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = GameTheme.mapOcean,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.22, size.height * 0.58),
        width: size.width * 0.42,
        height: size.height * 0.28,
      ),
      Paint()..color = GameTheme.mapShallow.withValues(alpha: dim ? 0.35 : 0.7),
    );

    void land(Offset c, double nw, double nh, Color color) {
      final rect = Rect.fromCenter(
        center: Offset(c.dx * size.width, c.dy * size.height),
        width: nw * size.width,
        height: nh * size.height,
      );
      canvas.drawOval(
        rect,
        Paint()..color = color.withValues(alpha: dim ? 0.42 : 0.92),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = GameTheme.border.withValues(alpha: dim ? 0.22 : 0.5),
      );
    }

    land(const Offset(0.36, 0.14), 0.44, 0.22, GameTheme.mapFrost);
    land(const Offset(0.48, 0.10), 0.20, 0.12, GameTheme.mapFrost);
    land(const Offset(0.74, 0.18), 0.30, 0.18, GameTheme.mapStormLand);
    land(const Offset(0.24, 0.40), 0.34, 0.24, GameTheme.mapCrown);
    land(const Offset(0.38, 0.42), 0.16, 0.12, GameTheme.mapDeep);
    land(const Offset(0.58, 0.36), 0.30, 0.20, GameTheme.moss);
    land(const Offset(0.84, 0.36), 0.26, 0.22, GameTheme.mapVeilLand);
    land(const Offset(0.11, 0.56), 0.18, 0.14, GameTheme.mapTide);
    land(const Offset(0.18, 0.62), 0.10, 0.08, GameTheme.mapTide);
    land(const Offset(0.46, 0.60), 0.30, 0.20, GameTheme.mapBlight);
    land(const Offset(0.80, 0.56), 0.24, 0.18, GameTheme.mapBrassLand);
    land(const Offset(0.26, 0.78), 0.38, 0.24, GameTheme.mapDune);
    land(const Offset(0.66, 0.82), 0.36, 0.22, GameTheme.mapAsh);

    if (dim) return;
    _label(canvas, size, 'FROST', const Offset(0.34, 0.04));
    _label(canvas, size, 'DUNES', const Offset(0.22, 0.90));
    _label(canvas, size, 'ASH', const Offset(0.66, 0.92));
    _label(canvas, size, 'VEIL', const Offset(0.86, 0.24));
    _label(canvas, size, 'CROWN', const Offset(0.18, 0.28));
  }

  static void _label(Canvas canvas, Size size, String text, Offset norm) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GameTheme.body(size: 9, color: GameTheme.parchmentDim),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(norm.dx * size.width - tp.width / 2, norm.dy * size.height),
    );
  }

  @override
  bool shouldRepaint(covariant HubWorldContinentsPainter oldDelegate) =>
      oldDelegate.dim != dim;
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
  });

  final String name;
  final String portraitDungeonId;
  final double discSize;
  final double hitSize;
  final bool unlocked;
  final bool cleared;
  final bool selected;
  final Animation<double>? pulse;
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
    final iconSize = discSize * 0.82;

    Widget portrait = KenneySprite(
      asset: KenneyAssets.dungeonPortraitFor(portraitDungeonId),
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
            child: ClipOval(child: portrait),
          )
        : _discShell(pulseValue: 0, child: ClipOval(child: portrait));

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
                child: Center(child: disc),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _discShell({required double pulseValue, required Widget child}) {
    return SizedBox(
      width: discSize,
      height: discSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GameTheme.hudMapCaption.withValues(alpha: 0.75),
          border: Border.all(
            color: _ringColor(pulseValue),
            width: selected ? 2.5 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: GameTheme.torch.withValues(alpha: 0.45),
                    blurRadius: 10 + pulseValue * 3,
                  ),
                ]
              : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}
