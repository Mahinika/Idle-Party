/// Idle Party UI theme — start here for menus and chrome.
///
/// | Piece | File | Use for |
/// |-------|------|---------|
/// | [GameTheme] | `game_theme.dart` | colors, type, radii, touch |
/// | [MenuChrome] | `menu_chrome.dart` | panels, tabs, chips, dialogs |
/// | [GameButton] | `kenney_button.dart` | brown / grey / red / ghost actions |
/// | [GameIcon] / [UiIcon] | `game_icon.dart` | pixel chrome icons |
///
/// Visual families (do not mix): menu sheet ≈ GEAR · hub · combat HUD · brand.
/// Guide: `docs/UI_THEME.md`.
///
/// **Do not:** Material Icons, emoji in labels, or raw hex colors outside
/// [GameTheme] (combat VFX excepted).
library;

export 'game_button.dart';
export 'game_icon.dart';
export 'game_theme.dart';
export 'menu_chrome.dart';
