import 'package:flutter/material.dart';

import 'game_theme.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'web_click_bridge.dart';

/// Shared forge-menu chrome — layered glass panels, soft torch edges.
///
/// Visual guide: `docs/UI_THEME.md` (GEAR sheet is the reference look).
abstract final class MenuChrome {
  static const Color scrim = Color(0xE006080C);
  static const Color card = Color(0xB8121820);
  static const Color cardRaised = Color(0xCC1A2430);
  static const Color sheet = Color(0xF0121820);

  static BorderRadius get panelRadius =>
      BorderRadius.circular(GameTheme.radiusMd);
  static BorderRadius get sheetRadius => const BorderRadius.vertical(
        top: Radius.circular(GameTheme.radiusLg),
      );

  static BoxDecoration panel({
    BorderRadius? borderRadius,
    bool opaque = false,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: opaque
            ? [
                GameTheme.panel,
                GameTheme.stoneDeep,
              ]
            : [
                GameTheme.panel.withValues(alpha: 0.94),
                GameTheme.stoneDeep.withValues(alpha: 0.96),
              ],
      ),
      borderRadius: borderRadius ?? panelRadius,
      border: Border.all(
        color: GameTheme.borderLit.withValues(alpha: 0.45),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: GameTheme.torch.withValues(alpha: 0.08),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 0),
        ),
        const BoxShadow(
          color: Color(0x99000000),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    );
  }

  static BoxDecoration cardBox({bool selected = false, bool inset = false}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: selected
            ? [
                GameTheme.stoneRaised.withValues(alpha: 0.95),
                GameTheme.stone.withValues(alpha: 0.9),
              ]
            : inset
                ? [
                    GameTheme.panelInset.withValues(alpha: 0.9),
                    card,
                  ]
                : [
                    cardRaised,
                    card,
                  ],
      ),
      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
      border: Border.all(
        color: selected
            ? GameTheme.torchHot.withValues(alpha: 0.9)
            : GameTheme.border.withValues(alpha: 0.85),
        width: selected ? 1.5 : 1,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: GameTheme.torch.withValues(alpha: 0.18),
                blurRadius: 10,
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
    );
  }

  static BoxDecoration rowTile() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          GameTheme.stoneRaised.withValues(alpha: 0.92),
          GameTheme.stone.withValues(alpha: 0.88),
        ],
      ),
      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
      border: Border.all(color: GameTheme.border.withValues(alpha: 0.9)),
    );
  }

  static Widget sheetHandle() {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: GameTheme.borderLit.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  /// Section label for dense menus (GEAR / PROGRESS / …).
  static Widget sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6, top: 2),
      child: Text(
        text.toUpperCase(),
        style: GameTheme.body(
          size: 13,
          color: GameTheme.accentInfo.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  /// GEAR-style inset tab rail (torch wash on selected tab).
  static Widget tabRail({
    required TabController controller,
    required List<Widget> tabs,
    ValueChanged<int>? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: GameTheme.panelInset.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          border: Border.all(
            color: GameTheme.border.withValues(alpha: 0.7),
          ),
        ),
        child: TabBar(
          controller: controller,
          onTap: onTap,
          labelStyle: GameTheme.body(size: 16),
          unselectedLabelStyle: GameTheme.body(size: 16),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: GameTheme.torch.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(GameTheme.radiusSm - 2),
          ),
          labelColor: GameTheme.torchHot,
          unselectedLabelColor: GameTheme.parchmentDim,
          dividerColor: Colors.transparent,
          tabs: tabs,
        ),
      ),
    );
  }

  /// List / mission / shop row — same well as GEAR inset cards.
  static BoxDecoration listCard({
    bool selected = false,
    bool inset = false,
    Color? borderColor,
  }) {
    final base = cardBox(selected: selected, inset: inset);
    if (borderColor == null) return base;
    return base.copyWith(
      border: Border.all(
        color: borderColor,
        width: selected ? 1.5 : 1.1,
      ),
    );
  }

  /// Cave-styled modal bottom sheet (MORE menus, etc.).
  ///
  /// Pass either a flat [items] list or grouped [sections] (preferred).
  /// Optional [icon] is a Kenney/Custom asset path shown left of the label.
  static Future<void> showMenuSheet({
    required BuildContext context,
    required String title,
    List<({String label, VoidCallback onTap, String? icon})>? items,
    List<
            ({
              String header,
              List<({String label, VoidCallback onTap, String? icon})> items,
            })>?
        sections,
  }) {
    assert(
      items != null || sections != null,
      'showMenuSheet requires items or sections',
    );
    final resolved = sections ??
        [(header: '', items: items!)];
    WebClickBridge.pushLayer();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: scrim,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DecoratedBox(
              decoration: panel(borderRadius: sheetRadius, opaque: true),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sheetHandle(),
                    Text(
                      title,
                      style: GameTheme.menuTitle(size: 20),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 1,
                      color: GameTheme.borderLit.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var s = 0; s < resolved.length; s++) ...[
                              if (resolved[s].header.isNotEmpty) ...[
                                if (s > 0) const SizedBox(height: 8),
                                sectionLabel(resolved[s].header),
                              ],
                              for (final item in resolved[s].items)
                                menuRow(
                                  label: item.label,
                                  icon: item.icon,
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
                    const SizedBox(height: 10),
                    KenneyButton(
                      label: 'CLOSE',
                      style: KenneyButtonStyle.grey,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(WebClickBridge.popLayer);
  }

  static Widget menuRow({
    required String label,
    required VoidCallback onTap,
    String? trailing,
    String? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: WebClickScope(
        label: label,
        onPressed: onTap,
        child: Semantics(
          button: true,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: GameTheme.minTouch),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: rowTile(),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GameTheme.panelInset.withValues(alpha: 0.8),
                          borderRadius:
                              BorderRadius.circular(GameTheme.radiusSm),
                          border: Border.all(
                            color: GameTheme.border.withValues(alpha: 0.7),
                          ),
                        ),
                        child: KenneySprite(asset: icon, size: 18),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: GameTheme.body(size: 18, color: GameTheme.parchment),
                      ),
                    ),
                    if (trailing != null)
                      Text(
                        trailing,
                        style: GameTheme.body(
                          size: 14,
                          color: GameTheme.parchmentDim,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: GameTheme.parchmentDim.withValues(alpha: 0.7),
                      ),
                  ],
                ),
              ),
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
        side: BorderSide(
          color: GameTheme.borderLit.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      title: Text(title, style: GameTheme.menuTitle(size: 18)),
      content: content,
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: actions,
    );
  }
}
