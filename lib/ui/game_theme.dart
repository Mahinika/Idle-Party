import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared Idle Party visual tokens — dark dungeon surfaces, high-contrast type.
abstract final class GameTheme {
  static const Color ink = Color(0xFF070605);
  static const Color stoneDeep = Color(0xFF12100C);
  static const Color stone = Color(0xFF1A1712);
  static const Color stoneRaised = Color(0xFF2A241A);
  static const Color panel = Color(0xFF221C14);
  static const Color panelInset = Color(0xFF16120E);
  static const Color moss = Color(0xFF3D4A32);
  static const Color mossLit = Color(0xFF8FA070);
  static const Color torch = Color(0xFFE8B84A);
  static const Color torchHot = Color(0xFFFFE8A0);
  static const Color parchment = Color(0xFFF2EBDA);
  static const Color parchmentDim = Color(0xFFC4B48A);
  static const Color blood = Color(0xFF8B3A2A);
  static const Color bloodLit = Color(0xFFE07058);
  static const Color clear = Color(0xFF8FBF78);
  static const Color border = Color(0xFF7A6840);
  static const Color borderLit = Color(0xFFD4AE55);

  /// Dark ink for light Kenney button faces.
  static const Color onLight = Color(0xFF1A120A);

  /// Minimum interactive target (Material / iOS HIG floor).
  static const double minTouch = 44;

  /// HUD pixel labels — keep readable on mobile chrome.
  static const double hudPixel = 9;
  static const double hudPixelComfort = 11;

  /// Phone / narrow layout: shortest side under tablet, or width under ~700.
  static bool isCompactWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide < 600 || size.width < 700;
  }

  /// Headers / titles (pixel).
  static TextStyle pixel({
    double size = 11,
    Color color = torchHot,
    double height = 1.4,
  }) =>
      GoogleFonts.pressStart2p(
        fontSize: size,
        color: color,
        height: height,
        shadows: const [
          Shadow(color: Color(0xCC000000), offset: Offset(1, 1), blurRadius: 0),
        ],
      );

  /// Readable body / HUD copy.
  static TextStyle body({
    double size = 17,
    Color color = parchment,
  }) =>
      GoogleFonts.vt323(
        fontSize: size,
        color: color,
        height: 1.15,
      );

  /// Button labels — large VT323 so long words stay legible.
  static TextStyle button({
    double size = 20,
    Color color = parchment,
  }) =>
      GoogleFonts.vt323(
        fontSize: size,
        color: color,
        height: 1.05,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        shadows: color == onLight
            ? const []
            : const [
                Shadow(
                  color: Color(0xAA000000),
                  offset: Offset(1, 1),
                  blurRadius: 0,
                ),
              ],
      );
}
