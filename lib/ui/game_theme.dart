import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared Idle Party visual tokens — dark forge surfaces, crisp hierarchy.
abstract final class GameTheme {
  // —— Surfaces (cooler charcoal with warm torch accents) ——————————————
  static const Color ink = Color(0xFF06080C);
  static const Color stoneDeep = Color(0xFF0C1016);
  static const Color stone = Color(0xFF141A22);
  static const Color stoneRaised = Color(0xFF1E2733);
  static const Color panel = Color(0xFF182028);
  static const Color panelInset = Color(0xFF0F141C);
  /// Translucent list/card fill used inside overlays.
  static const Color menuCard = Color(0xB8121820);
  static const Color moss = Color(0xFF2F4A3C);
  static const Color mossLit = Color(0xFF7DCF9A);
  static const Color torch = Color(0xFFE4B04A);
  static const Color torchHot = Color(0xFFFFE2A8);
  static const Color parchment = Color(0xFFECE8DF);
  static const Color parchmentDim = Color(0xFF9AA3B0);
  static const Color blood = Color(0xFF8B3A2A);
  static const Color bloodLit = Color(0xFFE07058);
  static const Color clear = Color(0xFF7DCF9A);
  static const Color border = Color(0xFF3D4A5C);
  static const Color borderLit = Color(0xFFC9A24A);
  static const Color accentInfo = Color(0xFF6EB6FF);
  static const Color accentWarn = Color(0xFFFFB454);

  /// Dark ink for light Kenney button faces.
  static const Color onLight = Color(0xFF121820);

  /// Cross-platform comfort floor (Apple HIG / WCAG 2.5.5 AAA).
  static const double minTouch = 44;

  /// Primary CTAs (Material ~9mm / 48dp): ENTER, Ascend, MERGE.
  static const double primaryTouch = 48;

  /// Gap from screen / safe edge to HUD clusters.
  static const double edgeGap = 12;

  /// Gap between interactive clusters (Material ≥8dp).
  static const double clusterGap = 8;

  /// Bottom nav chrome height (minTouch + label padding).
  static const double bottomNavHeight = minTouch + 14;

  /// Clearance above bottom nav for floating combat HUD.
  static const double hudAboveNav = clusterGap + 4;

  /// HUD pixel labels — keep readable on mobile chrome.
  static const double hudPixel = 9;
  static const double hudPixelComfort = 11;

  /// Modern menu radii.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;

  /// Phone / narrow layout: Android Compact width (~600) or width under ~700.
  static bool isCompactWidth(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide < 600 || size.width < 700;
  }

  /// Shipping portrait phone width (Samsung A56 ≈ 360; band ~360–430).
  static bool isPhoneWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width <= 430;
  }

  /// Short phone / landscape-short: hub CTAs must collapse.
  static bool isShortHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height < 720;
  }

  /// Bottom inset for [Positioned] combat HUD inside the stage stack
  /// (above the bottom nav, with Material-friendly gap).
  static double combatHudBottom(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    // Stage [Expanded] already sits above the nav; only need cluster gap.
    return hudAboveNav + (scale > 1.05 ? 4.0 : 0.0);
  }

  /// Side inset for corner HUD.
  static double combatHudSide(BuildContext context) => edgeGap;

  /// Compose OS Dynamic Type with in-game slider (do not replace OS alone).
  static TextScaler composeTextScaler({
    required TextScaler platform,
    required double gameScale,
  }) {
    final os = platform.scale(1.0);
    final combined = (os * gameScale).clamp(0.85, 1.4);
    return TextScaler.linear(combined);
  }

  /// Headers / titles (pixel — combat HUD + tiny tags).
  static final Map<int, TextStyle> _pixelCache = <int, TextStyle>{};
  static final Map<int, TextStyle> _bodyCache = <int, TextStyle>{};
  static final Map<int, TextStyle> _buttonCache = <int, TextStyle>{};
  static final Map<int, TextStyle> _titleCache = <int, TextStyle>{};

  static TextStyle pixel({
    double size = 11,
    Color color = torchHot,
    double height = 1.4,
  }) =>
      pixelCached(size: size, color: color, height: height);

  /// Same as [pixel] — explicit name for hot paint paths.
  static TextStyle pixelCached({
    double size = 11,
    Color color = torchHot,
    double height = 1.4,
  }) {
    // Press Start below hudPixel turns to glitter on phone DPI.
    final clamped = size < hudPixel ? hudPixel : size;
    final key = Object.hash(clamped, color.toARGB32(), height);
    return _pixelCache.putIfAbsent(
      key,
      () => GoogleFonts.pressStart2p(
        fontSize: clamped,
        color: color,
        height: height,
        shadows: const [
          Shadow(
            color: Color(0x99000000),
            offset: Offset(1, 1),
            blurRadius: 0,
          ),
        ],
      ),
    );
  }

  /// Menu / sheet titles — premium forge display (not pixel glitter).
  static TextStyle menuTitle({
    double size = 18,
    Color color = parchment,
  }) {
    final key = Object.hash(size, color.toARGB32());
    return _titleCache.putIfAbsent(
      key,
      () => GoogleFonts.cinzel(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.15,
      ),
    );
  }

  /// Readable body / HUD copy.
  static TextStyle body({
    double size = 17,
    Color color = parchment,
  }) {
    final key = Object.hash(size, color.toARGB32());
    return _bodyCache.putIfAbsent(
      key,
      () => GoogleFonts.vt323(
        fontSize: size,
        color: color,
        height: 1.2,
      ),
    );
  }

  /// Button labels — large VT323 so long words stay legible.
  static TextStyle button({
    double size = 20,
    Color color = parchment,
  }) {
    final key = Object.hash(size, color.toARGB32());
    return _buttonCache.putIfAbsent(
      key,
      () => GoogleFonts.vt323(
        fontSize: size,
        color: color,
        height: 1.05,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
