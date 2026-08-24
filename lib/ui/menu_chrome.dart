import 'package:flutter/material.dart';

import 'game_theme.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'web_click_bridge.dart';

/// RUN / TODAY / ACCOUNT scope for section headers and chips.
enum MenuScope { run, today, account }

/// Shared menu chrome — tokens + reusable widgets.
///
/// Visual guide: `docs/UI_THEME.md` (menu sheets ≈ GEAR; hub/HUD are separate families).
abstract final class MenuChrome {
  static const Color scrim = Color(0xE006080C);
  static const Color card = Color(0xB8121820);
  static const Color cardRaised = Color(0xCC1A2430);
  static const Color sheet = Color(0xF0121820);

  static BorderRadius get panelRadius =>
      BorderRadius.circular(GameTheme.radiusMd);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(GameTheme.radiusLg));

  static BoxDecoration panel({
    BorderRadius? borderRadius,
    bool opaque = false,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: opaque
            ? [GameTheme.panel, GameTheme.stoneDeep]
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
            ? [GameTheme.panelInset.withValues(alpha: 0.9), card]
            : [cardRaised, card],
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

  /// Hub banners / offline row — lighter than menu sheet [cardBox].
  static BoxDecoration hubPanel({bool selected = false}) {
    return BoxDecoration(
      color: GameTheme.panel.withValues(alpha: selected ? 0.62 : 0.52),
      borderRadius: BorderRadius.circular(GameTheme.radiusSm),
      border: Border.all(
        color: selected
            ? GameTheme.torch.withValues(alpha: 0.45)
            : GameTheme.border.withValues(alpha: 0.65),
        width: selected ? 1.4 : 1,
      ),
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
          color: GameTheme.scopeAccount.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  /// RUN / TODAY / ACCOUNT scope for POWER and hub section headers.
  static Widget sectionLabelScoped(
    String title, {
    MenuScope? scope,
  }) {
    final tone = scope == null
        ? GameTheme.scopeAccount
        : switch (scope) {
            MenuScope.run => GameTheme.scopeRun,
            MenuScope.today => GameTheme.scopeToday,
            MenuScope.account => GameTheme.scopeAccount,
          };
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6, top: 2),
      child: Row(
        children: [
          if (scope != null) ...[
            scopeChip(scope.name.toUpperCase()),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: GameTheme.body(
                size: 13,
                color: tone.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact +/- for sliders (settings filters, KEY level).
  static Widget stepperButton({
    required String label,
    required String sign,
    VoidCallback? onPressed,
    double size = GameTheme.minTouch,
  }) {
    final enabled = onPressed != null;
    return WebClickScope(
      label: label,
      onPressed: onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: cardBox(inset: true),
                child: Text(sign, style: GameTheme.pixel(size: 10)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dialog secondary action — ghost Kenney face, not Material [TextButton].
  static Widget dialogCancel({
    required String label,
    required VoidCallback onPressed,
  }) {
    return KenneyButton(
      label: label,
      style: KenneyButtonStyle.ghost,
      expanded: false,
      onPressed: onPressed,
    );
  }

  /// Tab label that also registers with [WebClickBridge] (CanvasKit playtest).
  static Widget bridgedTab(String label, {required VoidCallback onSelect}) {
    return Tab(
      child: WebClickScope(
        label: label,
        onPressed: onSelect,
        child: Semantics(
          button: true,
          label: label,
          onTap: onSelect,
          excludeSemantics: true,
          child: Text(label),
        ),
      ),
    );
  }

  /// GEAR-style inset tab rail (torch wash on selected tab).
  ///
  /// On phone width (or 5+ tabs), scrolls instead of crushing labels.
  static Widget tabRail({
    required TabController controller,
    required List<Widget> tabs,
    ValueChanged<int>? onTap,
    bool? scrollable,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = GameTheme.isPhoneWidth(context);
        // Always scroll on the shipping phone chrome so labels stay readable
        // (wide browsers used to crush five tabs into one row).
        final scroll = scrollable ?? true;
        final labelSize = phone ? 13.0 : 16.0;
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
              isScrollable: scroll,
              tabAlignment: scroll ? TabAlignment.start : TabAlignment.fill,
              labelPadding: EdgeInsets.symmetric(
                horizontal: scroll ? (phone ? 10 : 14) : (phone ? 2 : 4),
              ),
              labelStyle: GameTheme.body(size: labelSize),
              unselectedLabelStyle: GameTheme.body(size: labelSize),
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
      },
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
      border: Border.all(color: borderColor, width: selected ? 1.5 : 1.1),
    );
  }

  /// Small pill of information (HUD counters, stat tiles, filters).
  ///
  /// One shape for the whole game — before this there were eight hand-rolled
  /// chips that drifted apart in padding, radius and font size.
  static Widget chip({
    required String label,
    String? icon,
    String? value,
    bool selected = false,
    bool stacked = false,
    Color? tone,
    VoidCallback? onTap,
    double minWidth = 0,
  }) {
    final labelStyle = GameTheme.pixel(
      size: GameTheme.hudPixel,
      color: stacked ? GameTheme.parchmentDim : (tone ?? GameTheme.torchHot),
    );
    final valueStyle = GameTheme.body(
      size: stacked ? 18 : 14,
      color: tone ?? GameTheme.torchHot,
    );
    final parts = <Widget>[
      if (icon != null) ...[
        KenneySprite(asset: icon, size: 14),
        SizedBox(width: stacked ? 0 : 4, height: stacked ? 3 : 0),
      ],
      Text(label, style: labelStyle),
      if (value != null) ...[
        SizedBox(width: stacked ? 0 : 6, height: stacked ? 3 : 0),
        Text(value, style: valueStyle),
      ],
    ];
    final body = Container(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: onTap == null ? 0 : GameTheme.minTouch,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: stacked ? 10 : 6,
        vertical: stacked ? 8 : 4,
      ),
      alignment: Alignment.center,
      decoration: cardBox(selected: selected, inset: stacked),
      child: stacked
          ? Column(mainAxisSize: MainAxisSize.min, children: parts)
          : Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
    if (onTap == null) return body;
    return WebClickScope(
      label: value == null ? label : '$label $value',
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: value == null ? label : '$label $value',
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: body,
          ),
        ),
      ),
    );
  }

  /// Tab-owned status (QUESTS claim hint, GUIDE What's New) — not global META noise.
  static Widget tabBanner(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.body(size: 12, color: GameTheme.torchHot),
      ),
    );
  }

  /// RUN / TODAY / ACCOUNT scope chip for section headers and guides.
  static Widget scopeChip(String scope) {
    final key = scope.toUpperCase();
    final tone = switch (key) {
      'RUN' => GameTheme.scopeRun,
      'TODAY' => GameTheme.scopeToday,
      'ACCOUNT' => GameTheme.scopeAccount,
      _ => GameTheme.parchmentDim,
    };
    return chip(label: key, tone: tone);
  }

  /// Low-emphasis navigation (hub shortcuts, “see META → KEY”).
  static Widget textLink({
    required String label,
    VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return WebClickScope(
      label: label,
      onPressed: onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GameTheme.body(
                  size: 13,
                  color: enabled ? GameTheme.torchHot : GameTheme.parchmentDim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One `label … value` line (offline summary, forge costs, compare sheets).
  static Widget statRow({
    required String label,
    required String value,
    Color? tone,
    double size = 15,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GameTheme.body(size: size, color: GameTheme.parchmentDim),
            ),
          ),
          Text(
            value,
            style: GameTheme.body(
              size: size + 1,
              color: tone ?? GameTheme.torchHot,
            ),
          ),
        ],
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
