import 'package:flutter/material.dart';

import 'game_button.dart';
import 'game_icon.dart';
import 'game_theme.dart';
import 'web_click_bridge.dart';

/// RUN / TODAY / ACCOUNT scope for section headers and chips.
enum MenuScope { run, today, account }

/// Shared menu chrome — tokens + reusable widgets.
///
/// Visual guide: `docs/UI_THEME.md` (menu sheets ≈ GEAR; hub/HUD are separate families).
/// Colors live on [GameTheme]; this class is widgets + decorations.
abstract final class MenuChrome {
  static const Color scrim = GameTheme.scrim;
  static const Color card = GameTheme.card;
  static const Color cardRaised = GameTheme.cardRaised;
  static const Color sheet = GameTheme.sheet;

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
          color: GameTheme.shadow,
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
                color: GameTheme.shadowFaint,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
    );
  }

  /// Combat HUD chip well (party strip, target, DPS meter).
  static BoxDecoration hudWell({Color? borderColor}) {
    return BoxDecoration(
      color: GameTheme.hudWell,
      borderRadius: BorderRadius.circular(GameTheme.radiusHud),
      border: Border.all(color: borderColor ?? GameTheme.hudWellBorder),
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

  /// Dialog secondary action — ghost GameButton, not Material [TextButton].
  static Widget dialogCancel({
    required String label,
    required VoidCallback onPressed,
  }) {
    return GameButton(
      label: label,
      style: GameButtonStyle.ghost,
      expanded: false,
      onPressed: onPressed,
    );
  }

  /// Tab label that also registers with [WebClickBridge] (CanvasKit playtest).
  static Widget bridgedTab(String label, {required VoidCallback onSelect}) {
    return bridgedTabScoped(label, onSelect: onSelect);
  }

  /// Tab with a tiny RUN / ACCOUNT scope line (POWER pillar clarity).
  static Widget bridgedTabScoped(
    String label, {
    String? scope,
    required VoidCallback onSelect,
  }) {
    final semantics = scope == null ? label : '$label · $scope';
    return Tab(
      child: WebClickScope(
        label: semantics,
        onPressed: onSelect,
        child: Semantics(
          button: true,
          label: semantics,
          onTap: onSelect,
          excludeSemantics: true,
          child: scope == null
              ? Text(label)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    Text(
                      scope,
                      style: GameTheme.pixel(
                        size: 8,
                        color: GameTheme.parchmentDim,
                      ),
                    ),
                  ],
                ),
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
        // Always scroll on the shipping phone chrome so labels stay readable.
        final scroll = scrollable ?? true;
        const labelSize = 13.0;
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
                horizontal: scroll ? 10 : 2,
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

  /// Compact exclusive choices in one row (spend ×1 / 5% / …).
  ///
  /// Prefer this over a Wrap of [chip]s — InkWell chips expand to the Wrap's
  /// max width and stack full-width on phone.
  static Widget segmented({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
    bool dense = false,
  }) {
    assert(labels.isNotEmpty);
    return Container(
      height: dense ? 36 : GameTheme.minTouch,
      decoration: BoxDecoration(
        color: GameTheme.panelInset.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        border: Border.all(color: GameTheme.border.withValues(alpha: 0.75)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                color: GameTheme.border.withValues(alpha: 0.45),
              ),
            Expanded(
              child: WebClickScope(
                label: labels[i],
                onPressed: () => onSelect(i),
                child: Semantics(
                  button: true,
                  selected: i == selectedIndex,
                  label: labels[i],
                  onTap: () => onSelect(i),
                  excludeSemantics: true,
                  child: Material(
                    color: i == selectedIndex
                        ? GameTheme.torch.withValues(alpha: 0.22)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Center(
                        child: Text(
                          labels[i],
                          style: GameTheme.pixel(
                            size: GameTheme.hudPixel,
                            color: i == selectedIndex
                                ? GameTheme.torchHot
                                : GameTheme.parchmentDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
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
        GameIcon.asset(icon, size: 14),
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
    // IntrinsicWidth: Material/InkWell otherwise expand to max width inside Wrap.
    return WebClickScope(
      label: value == null ? label : '$label $value',
      onPressed: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: value == null ? label : '$label $value',
        onTap: onTap,
        excludeSemantics: true,
        child: IntrinsicWidth(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: body,
            ),
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
      'RUN' || 'GOLD' => GameTheme.scopeRun,
      'TODAY' => GameTheme.scopeToday,
      'ACCOUNT' || 'PERMANENT' => GameTheme.scopeAccount,
      _ => GameTheme.parchmentDim,
    };
    return chip(label: key, tone: tone);
  }

  /// Low-emphasis navigation (hub shortcuts, “see KEY”).
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

  /// Square pixel toggle thumb (settings rows) — not Material Switch.
  static Widget toggleMark({required bool value}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value
            ? GameTheme.mossLit.withValues(alpha: 0.55)
            : GameTheme.stone.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(GameTheme.radiusHud),
        border: Border.all(
          color: value ? GameTheme.torchHot : GameTheme.border,
          width: value ? 1.5 : 1,
        ),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: value ? GameTheme.torchHot : GameTheme.parchmentDim,
          borderRadius: BorderRadius.circular(GameTheme.radiusHud),
        ),
      ),
    );
  }

  /// Discrete horizontal slider (text scale / bag filters).
  static Widget slider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return _MenuSlider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
    );
  }

  /// Expand/collapse block — replaces Material ExpansionTile in menus.
  static Widget fold({
    required String title,
    String? subtitle,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return _MenuFold(
      title: title,
      subtitle: subtitle,
      initiallyExpanded: initiallyExpanded,
      children: children,
    );
  }
}

class _MenuSlider extends StatelessWidget {
  const _MenuSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  void _setFromLocal(double localX, double width) {
    if (width <= 0) return;
    final t = (localX / width).clamp(0.0, 1.0);
    final raw = min + t * (max - min);
    final step = (max - min) / divisions;
    final snapped = (raw / step).round() * step;
    onChanged(snapped.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setFromLocal(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _setFromLocal(d.localPosition.dx, w),
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: GameTheme.stone.withValues(alpha: 0.95),
                    borderRadius:
                        BorderRadius.circular(GameTheme.radiusHud),
                    border: Border.all(color: GameTheme.border),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: t,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: GameTheme.torch.withValues(alpha: 0.85),
                      borderRadius:
                          BorderRadius.circular(GameTheme.radiusHud),
                    ),
                  ),
                ),
                Positioned(
                  left: (w - 16) * t,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: GameTheme.torchHot,
                      borderRadius:
                          BorderRadius.circular(GameTheme.radiusHud),
                      border: Border.all(color: GameTheme.borderLit),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuFold extends StatefulWidget {
  const _MenuFold({
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<_MenuFold> createState() => _MenuFoldState();
}

class _MenuFoldState extends State<_MenuFold> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GameTheme.body(
                            size: 13,
                            color: GameTheme.torchHot,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    _open ? 'HIDE' : 'SHOW',
                    style: GameTheme.body(
                      size: 12,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...widget.children,
      ],
    );
  }
}
