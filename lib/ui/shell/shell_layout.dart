import 'package:flutter/material.dart';

import '../game_theme.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// Brick-style shell layout tokens and small wrappers.
///
/// Spacing stays on [GameTheme.edgeGap] / [GameTheme.clusterGap]; this class
/// groups them for menu sheets, hub rows, and bottom sheets so padding does not
/// drift screen by screen.
abstract final class ShellLayout {
  static const double sheetHorizontal = GameTheme.edgeGap;
  static const double sheetVertical = 8;
  static const double sectionGap = GameTheme.clusterGap;
  static const double blockGap = 10;

  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(
    sheetHorizontal,
    sheetVertical,
    sheetHorizontal,
    16,
  );

  static const EdgeInsets scrollBodyPadding = EdgeInsets.fromLTRB(2, 0, 2, 16);

  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(4, 0, 4, 8);

  static const EdgeInsets hubScenePadding = EdgeInsets.fromLTRB(
    GameTheme.edgeGap,
    8,
    GameTheme.edgeGap,
    4,
  );

  static Widget gap([double height = sectionGap]) => SizedBox(height: height);

  static Widget blockGapWidget() => const SizedBox(height: blockGap);

  static Widget divider() => Container(
    height: 1,
    color: GameTheme.borderLit.withValues(alpha: 0.22),
  );

  /// Muted intro copy under a sheet title.
  static Widget hint(String text, {int maxLines = 4}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
    );
  }

  static Widget sectionHeader(String title, {MenuScope? scope}) {
    if (scope == null) return MenuChrome.sectionLabel(title);
    return MenuChrome.sectionLabelScoped(title, scope: scope);
  }

  /// Menu list / shop row surface.
  static Widget card({
    required Widget child,
    bool selected = false,
    EdgeInsets padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
  }) {
    return Container(
      padding: padding,
      decoration: MenuChrome.listCard(selected: selected),
      child: child,
    );
  }

  /// Hub banner / TODAY stack — lighter than menu [card].
  static Widget hubCard({
    required Widget child,
    bool selected = false,
    EdgeInsets padding = const EdgeInsets.all(8),
  }) {
    return Container(
      padding: padding,
      decoration: MenuChrome.hubPanel(selected: selected),
      child: child,
    );
  }

  /// Secondary sheet control (All packs · Show picks only).
  static Widget sheetLink({
    required String label,
    required VoidCallback onTap,
    String? semanticsLabel,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: WebClickScope(
        label: semanticsLabel ?? label,
        onPressed: onTap,
        child: Semantics(
          button: true,
          label: semanticsLabel ?? label,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(
                label,
                style: GameTheme.menuTitle(size: 11, color: GameTheme.torch),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const EdgeInsets seamPadding = EdgeInsets.fromLTRB(8, 4, 8, 0);

  /// Pair of grey secondary actions (SHOP restore · redeem, etc.).
  static const double shellIconSize = 20;

  static Widget secondaryActionRow({required List<Widget> children}) {
    assert(children.isNotEmpty && children.length <= 3);
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: sectionGap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
