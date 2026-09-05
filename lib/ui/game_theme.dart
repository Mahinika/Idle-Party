import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared Idle Party visual tokens. **Color literals live here** — other UI
/// files should use these names (combat VFX may still paint raw hex).
abstract final class GameTheme {
  // —— Surfaces (cooler charcoal with warm torch accents) ——————————————
  static const Color ink = Color(0xFF06080C);
  static const Color stoneDeep = Color(0xFF0C1016);
  static const Color stone = Color(0xFF141A22);
  static const Color stoneRaised = Color(0xFF1E2733);
  static const Color panel = Color(0xFF182028);
  static const Color panelInset = Color(0xFF0F141C);

  /// Loot border colors (bag slots, gear rows).
  static const Color rarityCommon = Color(0xFF5A5040);
  static const Color rarityUncommon = Color(0xFF70C050);
  static const Color rarityRare = Color(0xFF5090E0);
  static const Color rarityLegendary = Color(0xFFFF8C40);

  /// Bag equip-chip fills (upgrade / blocked / neutral).
  static const Color equipChipBlocked = Color(0xFF2A241C);
  static const Color equipChipUpgrade = Color(0xFF2A3A1C);
  static const Color equipChipNeutral = Color(0xFF3A2A18);
  static const Color statDown = Color(0xFFE07060);

  /// WoW-style tooltip name colors (brighter than border tokens).
  static const Color tooltipCommon = Color(0xFFFFFFFF);
  static const Color tooltipUncommon = Color(0xFF1EFF00);
  static const Color tooltipRare = Color(0xFF0070DD);
  static const Color tooltipEpic = Color(0xFFA335EE);
  static const Color tooltipLegendary = Color(0xFFFF8000);
  static const Color tooltipBorderCommon = Color(0xFF9D9D9D);
  static const Color tooltipStatUp = Color(0xFF1EFF00);
  static const Color tooltipStatDown = Color(0xFFFF4040);
  static const Color tooltipGold = Color(0xFFFFD100);

  /// GEAR paper-doll backdrop.
  static const Color dollBackdropTop = Color(0xFF101820);
  static const Color dollBackdropBottom = Color(0xFF080C12);

  /// Combat HUD fills (bars, party rows, map captions).
  static const Color hudHpFill = Color(0xFF2A2218);
  static const Color hudManaFill = Color(0xFF1A2430);
  static const Color hudManaBright = Color(0xFF9AD0FF);
  static const Color hudCastOk = Color(0xFF009E73);
  static const Color hudHpLowCb = Color(0xFFD55E00);
  static const Color hudHpMidCb = Color(0xFFE69F00);
  static const Color hudHpDamage = Color(0xFFE05050);
  static const Color hudPartyRowHot = Color(0xFF4A3010);
  static const Color hudPartyRowWarm = Color(0xFF3A2A14);
  static const Color hudPartyRowIdle = Color(0xFF221810);
  static const Color hudSpiritText = Color(0xFFFFF0A8);
  static const Color hudManaText = Color(0xFF80C0FF);
  static const Color hudFarmGreen = Color(0xFF3A5018);
  static const Color hudMapCaption = Color(0xFF1A1410);

  /// RUN / TODAY / ACCOUNT scope tones (hub + POWER section headers).
  static const Color scopeRun = mossLit;
  static const Color scopeToday = accentWarn;
  static const Color scopeAccount = accentInfo;
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

  /// Drop shadows — use these instead of one-off `Color(0x88…)`.
  static const Color shadow = Color(0x99000000);
  static const Color shadowMid = Color(0x88000000);
  static const Color shadowSoft = Color(0x66000000);
  static const Color shadowFaint = Color(0x44000000);

  /// Menu sheet surfaces (alpha baked so overlays stay `const`).
  static const Color scrim = Color(0xE006080C);
  static const Color card = Color(0xB8121820);
  static const Color cardRaised = Color(0xCC1A2430);
  static const Color sheet = Color(0xF0121820);
  static const Color tooltipSheet = Color(0xF0140C08);

  /// GameButton faces.
  static const Color buttonBrownTop = Color(0xFF6B4E2E);
  static const Color buttonBrownBottom = Color(0xFF3E2A18);
  static const Color buttonGreyTop = Color(0xFF2A3340);
  static const Color buttonGreyBottom = Color(0xFF171E28);
  static const Color buttonRedTop = Color(0xFF9A4030);
  static const Color buttonRedBottom = Color(0xFF5A2018);
  static const Color buttonDisabledTop = Color(0xFF151A22);
  static const Color buttonDisabledBottom = Color(0xFF0E1218);
  static const Color buttonDisabledText = Color(0xFF5A6270);
  static const Color buttonDisabledBorder = buttonGreyTop;

  /// GEAR doll wash + bag UP/BEST chip.
  static const Color dollGlow = Color(0x5540A090);
  static const Color mossChip = Color(0xEE1E4030);

  /// Dungeon stage dim when a menu or DPS meter sits on top.
  static const Color hudDimSoft = Color(0x4414100C);
  static const Color hudDim = Color(0x6614100C);

  /// Combat HUD wells (party strip, target chip, DPS meter).
  static const Color hudWell = Color(0xCC14110C);
  static const Color hudWellBorder = Color(0x665A5040);
  static const Color hudFlaskUrgent = Color(0xEE4A2010);
  static const Color hudFlaskIdle = Color(0xDD2A1810);
  static const Color hudRowSelected = Color(0x331C1812);

  /// Tight HUD corners (not menu [radiusSm]).
  static const double radiusHud = 4;

  /// Cross-platform comfort floor (Apple HIG / WCAG 2.5.5 AAA).
  static const double minTouch = 44;

  /// Primary CTAs (Material ~9mm / 48dp): ENTER, Ascend, MERGE.
  static const double primaryTouch = 48;

  /// Gap from screen / safe edge to HUD clusters.
  static const double edgeGap = 12;

  /// Gap between interactive clusters (Material ≥8dp).
  static const double clusterGap = 8;

  /// Bottom nav chrome height (minTouch + tight label pad).
  /// Dense so GEAR / dungeon keep room above the bar.
  static const double bottomNavHeight = minTouch + 8;

  // —— Bottom nav slot fills (TT2-style color blocks) ————————————————
  static const Color navGear = Color(0xFF7A342C);
  static const Color navGold = Color(0xFF7A5528);
  static const Color navShop = Color(0xFF2E5578);
  static const Color navEssence = Color(0xFF3A4A62);
  static const Color navKey = Color(0xFF6A4420);
  static const Color navMore = Color(0xFF334050);
  static const Color navLeave = Color(0xFF8A3830);

  /// Clearance above bottom nav for floating combat HUD.
  static const double hudAboveNav = clusterGap + 6;

  /// HUD pixel labels — keep readable on mobile chrome.
  static const double hudPixel = 9;
  static const double hudPixelComfort = 11;

  /// Modern menu radii.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;

  /// Dungeon HUD density — shipping product is phone-only; always compact.
  static bool isCompactWidth(BuildContext context) => isPhoneWidth(context);

  /// Shipping portrait phone width (Samsung A56 ≈ 360; band ~360–430).
  ///
  /// Idle Party is phone-only — menus and chrome always use this layout, even
  /// when a wide browser forgets device metrics. Do not reintroduce tablet /
  /// desktop menu branches.
  static bool isPhoneWidth(BuildContext context) {
    // Width ignored on purpose — product chrome is always the phone band.
    return true;
  }

  /// Short phone / landscape-short: hub CTAs must collapse.
  static bool isShortHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height < 720;
  }

  /// Bottom inset for [Positioned] combat HUD inside the dungeon stage.
  /// Nav floats over the map in dungeon — reserve bar + home-indicator height.
  static double combatHudBottom(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final gap = hudAboveNav + (scale > 1.05 ? 4.0 : 0.0);
    final inset = MediaQuery.paddingOf(context).bottom;
    // Tip line above tabs (~14) + tab row + OS inset.
    return gap + bottomNavHeight + inset + 14;
  }

  /// Side inset for corner HUD.
  static double combatHudSide(BuildContext context) => edgeGap;

  /// Compose OS Dynamic Type with in-game slider (do not replace OS alone).
  static TextScaler composeTextScaler({
    required TextScaler platform,
    required double gameScale,
  }) {
    final os = platform.scale(1.0);
    final combined = (os * gameScale).clamp(0.80, 1.40);
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
  }) => pixelCached(size: size, color: color, height: height);

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
          Shadow(color: shadow, offset: Offset(1, 1), blurRadius: 0),
        ],
      ),
    );
  }

  /// Menu / sheet titles — premium forge display (not pixel glitter).
  static TextStyle menuTitle({double size = 18, Color color = parchment}) {
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
  static TextStyle body({double size = 17, Color color = parchment}) {
    final key = Object.hash(size, color.toARGB32());
    return _bodyCache.putIfAbsent(
      key,
      () => GoogleFonts.vt323(fontSize: size, color: color, height: 1.2),
    );
  }

  /// Button labels — large VT323 so long words stay legible.
  static TextStyle button({double size = 20, Color color = parchment}) {
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
