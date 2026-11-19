import 'package:flutter/material.dart';

import '../../../core/game_director.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/menu_alerts.dart';
import '../../../core/menu_router.dart';
import '../../chunky_face.dart';
import '../../game_icon.dart';
import '../../game_theme.dart';
import '../../web_click_bridge.dart';
import '../buy_qty_toggle.dart';
import '../forge_overlay.dart';
import '../market_overlay.dart';
import '../sanctuary_overlay.dart';
import '../shell_layout.dart';
import 'nav_clearance.dart';

enum HomeGoldPanel { forge, camp, market }

/// FORGE, CAMP, and MARKET under the fight. The fight keeps running.
class UpgradePanel extends StatefulWidget {
  const UpgradePanel({
    super.key,
    required this.director,
    required this.router,
    this.sheetPanel,
    this.focusPanel,
    this.focusGeneration = 0,
  });

  final GameDirector director;
  final MenuRouter router;

  /// When set, only the body for this tab (sheet owns the segmented header).
  final HomeGoldPanel? sheetPanel;

  /// SPLIT fight: a GOLD / MARKET intent moves the segmented control here.
  final HomeGoldPanel? focusPanel;
  final int focusGeneration;

  /// At large text the three tab labels need the whole header row, so the
  /// CAMP free level drops below the first track card instead.
  static bool campWatchInHeader(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) <= 1.2;

  /// The CAMP free-level button in the split header.
  static const campWatchKey = ValueKey('upgrade-panel-camp-watch');

  /// CAMP's free level as one compact 48x48 button. The same button sits
  /// in the header at 1.0 and under the first card at large text (F058).
  static Widget campWatchCompact({
    required String label,
    required VoidCallback onTap,
    required Key key,
  }) {
    return WebClickScope(
      label: label,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Tooltip(
          message: label,
          child: Material(
            key: key,
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: SizedBox.square(
                dimension: GameTheme.primaryTouch,
                child: Center(
                  child: ChunkyFace(
                    tone: ChunkyTone.stone,
                    highlight: true,
                    minHeight: GameTheme.chunkyFace,
                    padding: const EdgeInsets.all(4),
                    child: GameIcon.asset(UiIcon.watchAd, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The free-level button under the first CAMP card at large text.
  static const campWatchListKey = ValueKey('upgrade-panel-camp-watch-list');

  /// The one lock card while FORGE / CAMP / MARKET are still closed.
  static const lockedCardKey = ValueKey('upgrade-panel-locked');
  static const lockedProgressKey = ValueKey('upgrade-panel-locked-progress');

  /// The dock opens at the first boss, on floor 2: floors cleared of 2.
  static double lockProgress(GameState state) =>
      (state.highestFloorCleared.clamp(0, 2)) / 2;

  static String lockProgressLine(GameState state) =>
      'Floors cleared: ${state.highestFloorCleared.clamp(0, 2)}/2';

  @override
  State<UpgradePanel> createState() => _UpgradePanelState();
}

class _UpgradePanelState extends State<UpgradePanel> {
  _Panel _mode = _Panel.forge;

  /// One ×1 / ×10 / MAX pick for FORGE and CAMP under the fight. Not saved.
  BuyQty _qty = BuyQty.one;

  /// SPLIT MARKET filter; the header dropdown and the list share it.
  bool _marketUpgradesOnly = true;

  /// FORGE MAX slice (long-press MAX). 100% is the plain MAX.
  ForgeGoldSpendMode _slice = ForgeGoldSpendMode.pct100;

  ForgeGoldSpendMode get _forgeMode => switch (_qty) {
    BuyQty.one => ForgeGoldSpendMode.one,
    BuyQty.ten => ForgeGoldSpendMode.x10,
    BuyQty.max => _slice,
  };

  @override
  void initState() {
    super.initState();
    widget.router.addListener(_onRoute);
  }

  @override
  void dispose() {
    widget.router.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    if (widget.router.route != MenuRoute.gold) return;
    if (_mode != _Panel.forge) setState(() => _mode = _Panel.forge);
  }

  @override
  void didUpdateWidget(covariant UpgradePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focusPanel;
    if (focus != null && widget.focusGeneration != oldWidget.focusGeneration) {
      _mode = _Panel.values[focus.index];
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final open = MenuTabs.showGold(state);
    final embedded = widget.sheetPanel != null;
    final active = embedded ? _Panel.values[widget.sheetPanel!.index] : _mode;
    return Material(
      color: embedded ? Colors.transparent : GameTheme.panel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final headerCap = constraints.maxHeight.isFinite
              ? constraints.maxHeight * 0.5
              : null;
          return Column(
            children: [
              if (!embedded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: headerCap == null
                          ? double.infinity
                          : headerCap.clamp(
                              GameTheme.minTouch,
                              double.infinity,
                            ),
                    ),
                    child: _header(open),
                  ),
                ),
              Expanded(child: _body(state, open, active, embedded)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(GameState state, bool open, _Panel mode, bool embedded) {
    if (!open) return _locked(state, mode);
    final inline = widget.sheetPanel == null && !state.homePanelFull;
    switch (mode) {
      case _Panel.market:
        return MarketOverlay(
          director: widget.director,
          inlineUnderFight: inline,
          expandedTrackList: embedded,
          controlsInHeader: inline,
          upgradesOnly: inline ? _marketUpgradesOnly : null,
          onUpgradesOnlyChanged: inline
              ? (v) => setState(() => _marketUpgradesOnly = v)
              : null,
        );
      case _Panel.camp:
        return SanctuaryOverlay(
          director: widget.director,
          inlineUnderFight: inline,
          expandedTrackList: embedded,
          onOpenAdFree: _openAdFreeShop,
          qty: embedded ? null : _qty,
        );
      case _Panel.forge:
        return ForgeOverlay(
          director: widget.director,
          inlineUnderFight: inline,
          expandedTrackList: embedded,
          spendMode: embedded ? null : _forgeMode,
        );
    }
  }

  /// One row: FORGE · CAMP · MARKET as icon tabs, then ×1 / ×10 / MAX,
  /// or in SPLIT MARKET the flask dropdown and the reroll chip.
  Widget _header(bool open) {
    final showQty = open && _mode != _Panel.market;
    final marketControls =
        open && _mode == _Panel.market && !widget.director.state.homePanelFull;
    return Row(
      children: [
        for (final p in _Panel.values) ...[
          if (p.index > 0) const SizedBox(width: 4),
          Expanded(child: _tab(p)),
        ],
        if (showQty) ...[
          const SizedBox(width: 8),
          BuyQtyToggle(
            value: _qty,
            maxLabel: _mode == _Panel.forge
                ? ForgeOverlay.maxLabelFor(_forgeMode)
                : 'MAX',
            onChanged: (q) => setState(() {
              _qty = q;
              if (q == BuyQty.max) _slice = ForgeGoldSpendMode.pct100;
            }),
            onMaxLongPress: _mode == _Panel.forge ? _pickSlice : null,
          ),
        ],
        if (showQty &&
            _mode == _Panel.camp &&
            UpgradePanel.campWatchInHeader(context) &&
            SanctuaryOverlay.watchFreeReady(widget.director.state)) ...[
          const SizedBox(width: 4),
          _campWatchButton(widget.director.state),
        ],
        if (marketControls) ...[
          const SizedBox(width: 8),
          MarketHeaderControls(
            director: widget.director,
            upgradesOnly: _marketUpgradesOnly,
            onUpgradesOnlyChanged: (v) =>
                setState(() => _marketUpgradesOnly = v),
          ),
        ],
      ],
    );
  }

  /// CAMP's free level, in the header like MARKET's reroll, so the track
  /// list starts with a buy card. 48x48 tap; the label is in semantics.
  Widget _campWatchButton(GameState state) => UpgradePanel.campWatchCompact(
    label: SanctuaryOverlay.watchFreeLabel(state),
    onTap: widget.director.watchCampAd,
    key: UpgradePanel.campWatchKey,
  );

  void _pickSlice() {
    ForgeOverlay.pickWalletSlice(
      context,
      _forgeMode,
      gold: widget.director.state.gold,
    ).then((mode) {
      if (mode == null || !mounted) return;
      setState(() {
        _qty = BuyQty.max;
        _slice = mode;
      });
    });
  }

  static const _tabLabels = ['FORGE', 'CAMP', 'MARKET'];

  Widget _tab(_Panel p) {
    final selected = _mode == p;
    final label = _tabLabels[p.index];
    void select() => setState(() => _mode = p);
    final ink = selected ? GameTheme.torchHot : GameTheme.parchmentDim;
    return WebClickScope(
      label: label,
      onPressed: select,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: select,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: select,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            // 48 dp tap area around a 40 dp face. At large text the face
            // grows into the margin instead of overflowing.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: GameTheme.primaryTouch,
              ),
              child: Center(
                heightFactor: 1,
                child: ChunkyFace(
                  tone: ChunkyTone.stone,
                  raised: !selected,
                  highlight: selected,
                  minHeight: GameTheme.chunkyFace + 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 1,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GameIcon.asset(
                        UiIcon.goldDockSegment[p.index],
                        size: 18,
                        color: selected ? null : GameTheme.parchmentDim,
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.hint(color: ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAdFreeShop() {
    final router = widget.router;
    final popSheet = widget.sheetPanel != null;
    widget.director.openAdFreeFromScrollsNudge();
    if (popSheet && context.mounted) Navigator.of(context).pop();
    router.open(MenuRoute.shop);
  }

  /// Locked-dock line for the picked tab ("MARKET opens after …").
  static String lockHintFor(int tabIndex) =>
      '${_tabLabels[tabIndex]} opens after the first boss (F2).';

  Widget _locked(GameState state, _Panel mode) {
    final lockHint = lockHintFor(mode.index);
    return ListView(
      padding: ShellLayout.listPadding.copyWith(
        bottom: ShellLayout.listPadding.bottom + NavClearance.of(context),
      ),
      // The lock card first and alone: no party filler above it (F039).
      children: [
        ShellLayout.card(
          child: Row(
            key: UpgradePanel.lockedCardKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GameIcon.asset(
                    UiIcon.goldDockSegment[mode.index],
                    size: 28,
                    color: GameTheme.parchmentDim,
                  ),
                  const Positioned(
                    right: -4,
                    bottom: -4,
                    child: GameIcon.glyph(
                      UiGlyph.lock,
                      size: 14,
                      color: GameTheme.parchment,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Say how close it is, not only that it is shut (polish7 P031).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShellLayout.hint(lockHint, maxLines: 3),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        key: UpgradePanel.lockedProgressKey,
                        value: UpgradePanel.lockProgress(state),
                        minHeight: 6,
                        backgroundColor: GameTheme.stoneDeep,
                        color: GameTheme.torch,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      UpgradePanel.lockProgressLine(state),
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Panel { forge, camp, market }
