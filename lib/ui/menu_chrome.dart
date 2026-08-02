import 'package:flutter/material.dart';

import 'game_theme.dart';

/// Shared cave-menu chrome — translucent panels, torch edges, soft scrims.
abstract final class MenuChrome {
  static const Color scrim = Color(0xE6050403);
  static const Color card = Color(0xB816120E);
  static const Color cardRaised = Color(0xCC221C14);
  static const Color sheet = Color(0xE012100C);

  static BorderRadius get panelRadius => BorderRadius.circular(6);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(14));

  static BoxDecoration panel({
    BorderRadius? borderRadius,
    bool opaque = false,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: opaque
            ? [GameTheme.panel, GameTheme.stoneDeep]
            : [
                GameTheme.panel.withValues(alpha: 0.88),
                GameTheme.stoneDeep.withValues(alpha: 0.92),
              ],
      ),
      borderRadius: borderRadius ?? panelRadius,
      border: Border.all(color: GameTheme.borderLit.withValues(alpha: 0.9), width: 2),
      boxShadow: [
        BoxShadow(
          color: GameTheme.torch.withValues(alpha: 0.12),
          blurRadius: 0,
          spreadRadius: 1,
        ),
        const BoxShadow(
          color: Color(0x88000000),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration cardBox({bool selected = false, bool inset = false}) {
    return BoxDecoration(
      color: selected
          ? GameTheme.stoneRaised.withValues(alpha: 0.85)
          : (inset ? card : cardRaised),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: selected
            ? GameTheme.torchHot.withValues(alpha: 0.85)
            : GameTheme.border.withValues(alpha: 0.75),
        width: selected ? 2 : 1,
      ),
    );
  }

  static BoxDecoration rowTile() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          GameTheme.stoneRaised.withValues(alpha: 0.9),
          GameTheme.stone.withValues(alpha: 0.85),
        ],
      ),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: GameTheme.borderLit.withValues(alpha: 0.65)),
    );
  }

  static Widget sheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: GameTheme.borderLit.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// Cave-styled modal bottom sheet (MORE menus, etc.).
  ///
  /// Pass either a flat [items] list or grouped [sections] (preferred).
  static Future<void> showMenuSheet({
    required BuildContext context,
    required String title,
    List<({String label, VoidCallback onTap})>? items,
    List<({String header, List<({String label, VoidCallback onTap})> items})>?
        sections,
  }) {
    assert(
      items != null || sections != null,
      'showMenuSheet requires items or sections',
    );
    final resolved = sections ??
        [(header: '', items: items!)];
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: scrim,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: DecoratedBox(
              decoration: panel(borderRadius: sheetRadius, opaque: true),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sheetHandle(),
                    Text(
                      title,
                      style: GameTheme.pixel(size: GameTheme.hudPixelComfort),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var s = 0; s < resolved.length; s++) ...[
                              if (resolved[s].header.isNotEmpty) ...[
                                if (s > 0) const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 6,
                                  ),
                                  child: Text(
                                    resolved[s].header,
                                    style: GameTheme.body(
                                      size: 12,
                                      color: GameTheme.parchmentDim,
                                    ),
                                  ),
                                ),
                              ],
                              for (final item in resolved[s].items)
                                menuRow(
                                  label: item.label,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    item.onTap();
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget menuRow({
    required String label,
    required VoidCallback onTap,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: rowTile(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GameTheme.pixel(size: GameTheme.hudPixel),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: GameTheme.body(
                      size: 14,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Themed AlertDialog shell for confirm/import flows.
  static AlertDialog dialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return AlertDialog(
      backgroundColor: sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: panelRadius,
        side: BorderSide(color: GameTheme.borderLit.withValues(alpha: 0.85), width: 2),
      ),
      title: Text(title, style: GameTheme.pixel(size: GameTheme.hudPixelComfort)),
      content: content,
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: actions,
    );
  }
}
