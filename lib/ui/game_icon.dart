import 'package:flutter/material.dart';

import '../assets/custom_assets.dart';
import 'game_theme.dart';
import 'kenney_sprite.dart';
import 'web_click_bridge.dart';

/// Pixel chrome icons. Use these — never Material [Icons] or emoji.
///
/// Sprites are owned custom art. Tiny marks (add/close/arrows) stay as
/// painted [UiGlyph]s; settings cog and KEY use PNG like the bottom tabs.
abstract final class UiIcon {
  static const String gear = CustomAssets.iconHelm;
  static const String power = CustomAssets.iconAxe;
  static const String quests = CustomAssets.iconTrophy;
  static const String trophy = CustomAssets.iconTrophy;
  static const String more = CustomAssets.iconBook;
  static const String leave = CustomAssets.iconDoor;
  static const String gold = CustomAssets.iconCoinGold;
  static const String essence = CustomAssets.iconFlaskPurple;
  static const String ascend = CustomAssets.iconCrown;
  static const String star = CustomAssets.iconStar;
  static const String heart = CustomAssets.iconHeart;
  static const String skull = CustomAssets.iconSkull;
  static const String flask = CustomAssets.iconFlask;
  static const String flaskBlue = CustomAssets.iconFlaskBlue;
  static const String ring = CustomAssets.iconRing;
  static const String shieldRound = CustomAssets.iconShieldRound;
  static const String settings = CustomAssets.iconSettings;
  static const String key = CustomAssets.iconKey;
}

enum UiGlyph { add, close, prev, next }

/// Pixel mark: a [UiIcon] sprite or a [UiGlyph] painted in-theme.
class GameIcon extends StatelessWidget {
  const GameIcon.asset(
    this.asset, {
    super.key,
    this.size = 16,
    this.color,
  }) : glyph = null;

  const GameIcon.glyph(
    this.glyph, {
    super.key,
    this.size = 16,
    this.color,
  }) : asset = null;

  final String? asset;
  final UiGlyph? glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final g = glyph;
    if (g != null) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GlyphPainter(
            rows: _rowsFor(g),
            color: color ?? GameTheme.parchment,
          ),
        ),
      );
    }
    return KenneySprite(asset: asset!, size: size, color: color);
  }

  static List<String> _rowsFor(UiGlyph g) => switch (g) {
        UiGlyph.add => _kAdd,
        UiGlyph.close => _kClose,
        UiGlyph.prev => _kPrev,
        UiGlyph.next => _kNext,
      };
}

/// 44dp tap target for settings / close / hero arrows.
class GameIconButton extends StatelessWidget {
  const GameIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.asset,
    this.glyph,
    this.size = 20,
    this.color,
    this.width = GameTheme.minTouch,
    this.height = GameTheme.minTouch,
  }) : assert(asset != null || glyph != null);

  final String label;
  final VoidCallback? onPressed;
  final String? asset;
  final UiGlyph? glyph;
  final double size;
  final Color? color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final mark = glyph != null
        ? GameIcon.glyph(
            glyph!,
            size: size,
            color: color ??
                (enabled ? GameTheme.parchment : GameTheme.parchmentDim),
          )
        : GameIcon.asset(asset!, size: size, color: color);
    return WebClickScope(
      label: label,
      onPressed: onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          child: SizedBox(
            width: width,
            height: height,
            child: Center(child: Opacity(opacity: enabled ? 1 : 0.35, child: mark)),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.rows, required this.color});

  final List<String> rows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    final h = rows.length;
    final w = rows.first.length;
    final px = size.shortestSide / (w > h ? w : h);
    final ox = (size.width - w * px) / 2;
    final oy = (size.height - h * px) / 2;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < h; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        if (row.codeUnitAt(x) == 0x23) {
          canvas.drawRect(
            Rect.fromLTWH(ox + x * px, oy + y * px, px, px),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.color != color || old.rows != rows;
}

// `#` = lit pixel. Keep marks chunky so they sit next to custom PNG icons.
const _kAdd = <String>[
  '....#....',
  '....#....',
  '....#....',
  '....#....',
  '#########',
  '....#....',
  '....#....',
  '....#....',
  '....#....',
];

const _kClose = <String>[
  '#.......#',
  '.#.....#.',
  '..#...#..',
  '...#.#...',
  '....#....',
  '...#.#...',
  '..#...#..',
  '.#.....#.',
  '#.......#',
];

const _kPrev = <String>[
  '....#',
  '...##',
  '..##.',
  '.##..',
  '##...',
  '.##..',
  '..##.',
  '...##',
  '....#',
];

const _kNext = <String>[
  '#....',
  '##...',
  '.##..',
  '..##.',
  '...##',
  '..##.',
  '.##..',
  '##...',
  '#....',
];
