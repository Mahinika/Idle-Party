import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/ad_free_nudge.dart';
import '../../core/build_stamp.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gold_income.dart';
import '../../core/menu_alerts.dart';
import '../../core/game_state.dart';
import '../../core/shop_store.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';
import 'home/nav_clearance.dart';
import 'home/upgrade_panel.dart';
import 'income_overlay.dart';
import 'buy_qty_toggle.dart';
import 'power_upgrade_row.dart';
import 'shell_common.dart';
import 'shell_layout.dart';

class SanctuaryOverlay extends StatefulWidget {
  const SanctuaryOverlay({
    super.key,
    required this.director,
    this.inlineUnderFight = false,
    this.expandedTrackList = false,
    this.onOpenAdFree,
    this.qty,
  });
  final GameDirector director;

  /// Set when the home panel header owns ×1 / ×10 / MAX. The body then
  /// skips its own selector.
  final BuyQty? qty;
  final bool inlineUnderFight;

  /// Bounded height (SPLIT panel or FORGE/CAMP sheet): scroll all tracks.
  final bool expandedTrackList;

  /// Opens SHOP from the one-time Ad-free line. Null hides that line.
  final VoidCallback? onOpenAdFree;

  /// A free CAMP level is still on offer today (rewarded ad, or free with
  /// ad-free).
  static bool watchFreeReady(GameState state) =>
      GameLogic.campAdClaimsToday(state) < GameLogic.campAdDailyCap;

  /// Share of the way to the track's soft-cap knee (the same knees as
  /// [GameLogic.sanctuaryTrackBonusAt]; prestige is not soft-capped).
  /// Display only. 1.0 once soft-capped.
  static double campSoftProgress(String track, int level) {
    final (points, softAt) = switch (track) {
      'gold' => (
        level * GameLogic.sanctuaryGoldPctPerLevel,
        GameLogic.sanctuaryGoldSoftAt,
      ),
      'power' => (
        level * GameLogic.sanctuaryPowerPerLevel,
        GameLogic.sanctuaryPowerSoftAt,
      ),
      'vitality' => (
        level * GameLogic.sanctuaryVitalityPerLevel,
        GameLogic.sanctuaryVitalitySoftAt,
      ),
      'xp' => (
        level * GameLogic.sanctuaryXpPctPerLevel,
        GameLogic.sanctuaryXpSoftAt,
      ),
      'defense' => (
        level * GameLogic.sanctuaryDefensePerLevel,
        GameLogic.sanctuaryDefenseSoftAt,
      ),
      _ => (0, 0.0),
    };
    if (softAt <= 0) return 0;
    return (points / softAt).clamp(0.0, 1.0);
  }

  static String _trackShortName(String track) => switch (track) {
    'gold' => 'Gold',
    'power' => 'Power',
    'vitality' => 'Vitality',
    'defense' => 'Defense',
    'xp' => 'XP',
    _ => track,
  };

  static String watchFreeLabel(GameState state) {
    final track = _trackShortName(GameLogic.recommendedSanctuaryTrack(state));
    if (state.metaDepth.adFree) {
      final left =
          GameLogic.campAdDailyCap - GameLogic.campAdClaimsToday(state);
      if (left > 0) return 'Free $track level · $left left today';
      return 'Free $track level';
    }
    return 'Watch · free $track level';
  }

  /// Caption beside the compact free-level button at large text.
  static String watchFreeCaption(GameState state) {
    final track = _trackShortName(GameLogic.recommendedSanctuaryTrack(state));
    final left =
        GameLogic.campAdDailyCap - GameLogic.campAdClaimsToday(state);
    if (left > 0) return 'Free $track level · $left left today';
    return 'Free $track level';
  }

  static const watchFreeCaptionKey = ValueKey('camp-watch-caption');

  @override
  State<SanctuaryOverlay> createState() => _SanctuaryOverlayState();
}

class _SanctuaryOverlayState extends State<SanctuaryOverlay> {
  /// Shared buy size for every CAMP row: ×1 / ×10 / MAX. Not saved.
  BuyQty _ownQty = BuyQty.one;

  BuyQty get _qty => widget.qty ?? _ownQty;

  /// Most levels one MAX tap buys on a track (same per-level price).
  static const int _campTapCap = 99;

  /// Levels one tap asks for; each row clamps to what it can afford.
  int get _buyLevels => switch (_qty) {
    BuyQty.one => 1,
    BuyQty.ten => 10,
    BuyQty.max => 1 << 20,
  };
  bool _nudgeLatched = false;
  bool _impressionQueued = false;

  GameDirector get director => widget.director;

  int _prestigeOf(GameState state, String track) => switch (track) {
    'gold' => state.metaDepth.sanctuaryGoldPrestige,
    'power' => state.metaDepth.sanctuaryPowerPrestige,
    'vitality' => state.metaDepth.sanctuaryVitalityPrestige,
    'defense' => state.metaDepth.sanctuaryDefensePrestige,
    'xp' => state.metaDepth.sanctuaryXpPrestige,
    _ => 0,
  };

  int _levelOf(GameState state, String track) => switch (track) {
    'gold' => state.sanctuaryGoldLevel,
    'power' => state.sanctuaryPowerLevel,
    'vitality' => state.sanctuaryVitalityLevel,
    'defense' => state.sanctuaryDefenseLevel,
    'xp' => state.metaDepth.sanctuaryXpLevel,
    _ => 0,
  };

  Color _trackAccent(String track) {
    if (director.state.colorblindMode) {
      return switch (track) {
        'gold' => GameTheme.parchment,
        'power' => GameTheme.parchmentDim,
        'vitality' => GameTheme.borderLit,
        'defense' => GameTheme.stoneRaised,
        'xp' => GameTheme.ink,
        _ => GameTheme.parchmentDim,
      };
    }
    return switch (track) {
      'gold' => GameTheme.statSpeed,
      'power' => GameTheme.statAttack,
      'vitality' => GameTheme.statVitality,
      'defense' => GameTheme.statArmor,
      'xp' => GameTheme.statMastery,
      _ => GameTheme.parchmentDim,
    };
  }

  String _essencePriceLabel(int cost) => '$cost essence';

  static const _tracks = <String>['gold', 'power', 'vitality', 'defense', 'xp'];

  bool get _compactPrice => widget.inlineUnderFight || widget.expandedTrackList;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final campOpen = MenuTabs.showCamp(state);
    if (widget.inlineUnderFight || widget.expandedTrackList) {
      return _scrollableTrackBody(state, campOpen);
    }
    final maxBulk = campOpen
        ? _tracks
              .map(
                (t) => GameLogic.sanctuaryBulkAffordableLevels(
                  state,
                  t,
                  maxLevels: _campTapCap,
                ),
              )
              .fold<int>(1, (a, b) => a > b ? a : b)
        : 1;
    final buyCap = maxBulk.clamp(1, _campTapCap);
    final effectiveBuy = _buyLevels.clamp(1, buyCap);

    return Padding(
      padding: ShellLayout.listPadding,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GameIcon.asset(UiIcon.campfire, size: 48),
                const SizedBox(width: 10),
                Text('CAMP', style: GameTheme.title()),
              ],
            ),
            ShellLayout.gap(8),
            CampRatesSection(director: director),
            ShellLayout.gap(8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MenuChrome.chip(
                  label: 'Ascend ${state.ascensionLevel}',
                  tone: GameTheme.torchHot,
                ),
                MenuChrome.chip(label: 'Camp tracks', selected: campOpen),
                Text(
                  '${formatCount(state.essence)} essence · survive Ascend',
                  style: GameTheme.hint(color: GameTheme.parchmentDim),
                ),
              ],
            ),
            if (campOpen) ...[ShellLayout.gap(8), _qtyToggle()],
            if (campOpen) _adFreeLine(state),
            ShellLayout.gap(8),
            if (campOpen)
              for (final track in _tracks)
                _campTrackCard(
                  state,
                  track,
                  effectiveBuy,
                  recommended:
                      track == GameLogic.recommendedSanctuaryTrack(state),
                )
            else
              ShellLayout.hint(
                'Gold Find, War Altar, Life Well, Aegis, and Lore Font appear here once Essence unlocks.',
                maxLines: 3,
              ),
            ShellLayout.gap(12),
          ],
        ),
      ),
    );
  }

  Widget _scrollableTrackBody(GameState state, bool campOpen) {
    if (!campOpen) {
      return Padding(
        padding: ShellLayout.listPadding,
        child: ShellLayout.hint(
          'CAMP tracks unlock on Essence after the first boss or an Ascend.',
          maxLines: 2,
        ),
      );
    }
    final maxBulk = _tracks
        .map(
          (t) => GameLogic.sanctuaryBulkAffordableLevels(
            state,
            t,
            maxLevels: _campTapCap,
          ),
        )
        .fold<int>(1, (a, b) => a > b ? a : b);
    final buyCap = maxBulk.clamp(1, _campTapCap);
    final effectiveBuy = _buyLevels.clamp(1, buyCap);
    final pick = GameLogic.recommendedSanctuaryTrack(state);

    final watchFree = SanctuaryOverlay.watchFreeReady(state);
    final watchChip = watchFree
        ? MenuChrome.chip(
            label: SanctuaryOverlay.watchFreeLabel(state),
            selected: true,
            onTap: () => director.watchCampAd(),
          )
        : null;
    final cards = [
      for (final track in _tracks)
        _campTrackCard(state, track, effectiveBuy, recommended: track == pick),
    ];
    final listPad = EdgeInsets.fromLTRB(
      ShellLayout.sheetHorizontal,
      4,
      ShellLayout.sheetHorizontal,
      8 + NavClearance.of(context),
    );
    if (widget.qty != null) {
      // The header owns ×1 / ×10 / MAX and the free-level button, so every
      // row here is a buy row and the first card sits right under it.
      return ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: listPad,
        children: [
          _adFreeLine(state),
          ...cards.take(1),
          // Large text: the header has no room, so the free level sits
          // under the first card (that card stays whole above the fold).
          if (watchFree && !UpgradePanel.campWatchInHeader(context))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              // A caption beside the compact button, so it is not an
              // orphan ▶ on its own row (polish7 P030).
              child: Row(
                children: [
                  UpgradePanel.campWatchCompact(
                    label: SanctuaryOverlay.watchFreeLabel(state),
                    onTap: director.watchCampAd,
                    key: UpgradePanel.campWatchListKey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        SanctuaryOverlay.watchFreeCaption(state),
                        key: SanctuaryOverlay.watchFreeCaptionKey,
                        maxLines: 2,
                        style: GameTheme.hint(color: GameTheme.parchmentDim),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...cards.skip(1),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ShellLayout.sheetHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [_qtyToggle(), ?watchChip],
              ),
              _adFreeLine(state),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: listPad,
            children: cards,
          ),
        ),
      ],
    );
  }

  void _queueImpression(bool live) {
    if (!live || _impressionQueued) return;
    _impressionQueued = true;
    _nudgeLatched = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      director.markAdFreeNudgeShown();
    });
  }

  bool _showAdFreeLine(GameState state) {
    final openShop = widget.onOpenAdFree;
    if (openShop == null) return false;
    final live = AdFreeNudge.show(
      meta: state.metaDepth,
      playListsAdFree: AdFreeNudge.offerReady(
        playListsAdFree: ShopStore.storeLists(AdFreeNudge.productId),
        sideloadQaBuild: BuildStamp.gitSha.isNotEmpty,
        debugBuild: kDebugMode,
      ),
      place: AdFreeNudgePlace.camp,
      campCapSpent:
          GameLogic.campAdClaimsToday(state) >= GameLogic.campAdDailyCap,
    );
    _queueImpression(live);
    return live || _nudgeLatched;
  }

  Widget _adFreeLine(GameState state) {
    if (!_showAdFreeLine(state)) return const SizedBox.shrink();
    final onTap = widget.onOpenAdFree;
    if (onTap == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: WebClickScope(
        label: AdFreeNudge.line,
        onPressed: onTap,
        child: Semantics(
          button: true,
          label: AdFreeNudge.line,
          onTap: onTap,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: GameTheme.minTouch,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AdFreeNudge.line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(color: GameTheme.torchHot),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _trackIcon(String track) => switch (track) {
    'gold' => UiIcon.gold,
    'power' => UiIcon.sword,
    'vitality' => UiIcon.heart,
    'defense' => UiIcon.shieldRound,
    'xp' => UiIcon.star,
    _ => UiIcon.campfire,
  };

  static String _trackTitle(String track) => switch (track) {
    'gold' => 'Gold Find',
    'power' => 'War Altar (Attack)',
    'vitality' => 'Life Well (Stamina)',
    'defense' => 'Aegis (Armor)',
    'xp' => 'Lore Font',
    _ => track,
  };

  Widget _qtyToggle() {
    return BuyQtyToggle(
      value: _qty,
      onChanged: (q) => setState(() => _ownQty = q),
    );
  }

  Widget _campTrackCard(
    GameState state,
    String track,
    int buyLevels, {
    bool recommended = false,
  }) {
    final level = _levelOf(state, track);
    final prestige = _prestigeOf(state, track);
    final cost = GameLogic.sanctuaryCost(level);
    final maxForTrack = GameLogic.sanctuaryBulkAffordableLevels(
      state,
      track,
      maxLevels: _campTapCap,
    );
    // clamp(1, 0) throws when this track costs more than the wallet.
    final buyN = maxForTrack < 1 ? 1 : buyLevels.clamp(1, maxForTrack);
    final canAffordOne = state.essence >= cost;

    String? detail;
    if (track == 'gold') {
      final hubDelta = GoldIncome.nextGoldFindDeltaPerMinute(state);
      final campPct = GameLogic.sanctuaryTrackBonusAt(
        'gold',
        state.sanctuaryGoldLevel + 1,
      );
      final nowPct = GameLogic.sanctuaryTrackBonusAt(
        'gold',
        state.sanctuaryGoldLevel,
      );
      final combatDelta = campPct - nowPct;
      detail = 'Next +${hubDelta}g/min hub · +$combatDelta% find';
    } else if (track == 'power') {
      detail = 'Speeds hub AFK essence';
    }

    if (_compactPrice || !canAffordOne) {
      detail = canAffordOne
          ? null
          : 'Need ${cost - state.essence} more essence';
    }

    final bulk = buyN > 1 && maxForTrack >= buyN;
    final price = bulk ? GameLogic.sanctuaryBulkCost(state, track, buyN) : cost;
    final live = bulk || canAffordOne;
    final trailing = PowerUpgradePriceChip(
      label: _essencePriceLabel(price),
      primary: recommended && live,
      quantity: live ? (bulk ? buyN : 1) : null,
      essence: true,
      onPressed: bulk
          ? () {
              director.upgradeSanctuaryBulk(track, maxLevels: buyN);
              setState(() {});
            }
          : canAffordOne
          ? () {
              director.upgradeSanctuary(track);
              setState(() {});
            }
          : null,
    );
    final buys = bulk ? buyN : 1;
    final keep = prestige * GameLogic.sanctuaryPrestigeKeepAmount(track);
    final now = GameLogic.sanctuaryTrackBonusAt(track, level) + keep;
    final next = GameLogic.sanctuaryTrackBonusAt(track, level + buys) + keep;
    final (unit, unitNext) = switch (track) {
      'gold' => ('% find', '%'),
      'power' => (' AP', ''),
      'vitality' => (' STA', ''),
      'defense' => (' Armor', ''),
      'xp' => ('% XP', '%'),
      _ => ('', ''),
    };
    final lv = prestige > 0 ? 'Lv$level P$prestige' : 'Lv$level';
    return PowerUpgradeRow(
      accent: _trackAccent(track),
      leading: UpgradeIconTile(
        icon: _trackIcon(track),
        accent: _trackAccent(track),
      ),
      title: _trackTitle(track),
      tag: recommended ? 'BEST' : null,
      subtitle: '$lv · +$now$unit',
      gainNext: '+$next$unitNext',
      detail: detail,
      progress: SanctuaryOverlay.campSoftProgress(track, level),
      selected: recommended,
      dense: true,
      trailing: trailing,
    );
  }
}
