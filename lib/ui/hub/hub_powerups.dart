import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../core/ad_rewarded.dart';
import '../../core/game_director.dart';
import '../../core/game_state.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

/// Compact hub POWERUPS chip — tap opens the watch-ad sheet.
class HubPowerupsCard extends StatelessWidget {
  const HubPowerupsCard({
    super.key,
    required this.state,
    required this.onOpen,
  });

  final GameState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final until = state.metaDepth.adBoostUntilMs;
    final active = AdBoost.isActive(until);
    final left = AdBoost.formatRemaining(until);
    final capped = AdBoost.atStackCap(until);
    final status = capped
        ? 'CAP FULL · later'
        : active
        ? '×2 · +${AdBoost.attackPercent}% ATK · $left'
        : 'WATCH · ${AdBoost.hoursPerAd}h · ×2 gold · +${AdBoost.attackPercent}% ATK';
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: WebClickScope(
        label: 'POWERUPS',
        onPressed: onOpen,
        child: Semantics(
          button: true,
          label: 'POWERUPS. $status',
          onTap: onOpen,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: Ink(
                decoration: MenuChrome.hubPanel(selected: active),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44 /* FEEL 251 */),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        KenneySprite(
                          asset: KenneyAssets.potionBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'POWERUPS',
                          style: GameTheme.body(
                            size: 12,
                            color: active
                                ? GameTheme.torchHot
                                : GameTheme.parchment,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: GameTheme.body(
                              size: 11,
                              color: active
                                  ? GameTheme.torchHot
                                  : GameTheme.parchmentDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: explain the boost, then watch ad (or playtest grant).
Future<void> openPowerupsSheet(
  BuildContext context,
  GameDirector director,
) async {
  WebClickBridge.pushLayer();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: director,
          builder: (ctx, _) {
            final until = director.state.metaDepth.adBoostUntilMs;
            final active = AdBoost.isActive(until);
            final left = AdBoost.formatRemaining(until);
            final capped = AdBoost.atStackCap(until);
            final realAds = AdRewarded.realAdsAvailable;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: MenuChrome.sheet,
                  borderRadius: MenuChrome.sheetRadius,
                  border: Border.all(
                    color: GameTheme.borderLit.withValues(alpha: 0.45),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MenuChrome.sheetHandle(),
                      Text('POWERUPS', style: GameTheme.menuTitle(size: 18)),
                      const SizedBox(height: 8),
                      Text(
                        'Watch a short ad for ${AdBoost.hoursPerAd} hours of '
                        'double gold and +${AdBoost.attackPercent}% attack. '
                        'Watch again to add another ${AdBoost.hoursPerAd} hours '
                        '(up to 24 hours). Optional — fights never pause for an '
                        'ad.',
                        style: GameTheme.body(
                          size: 15,
                          color: GameTheme.parchment,
                        ),
                      ),
                      const SizedBox(height: 10),
                      MenuChrome.statRow(
                        label: 'Gold',
                        value: active
                            ? '×2 now'
                            : '×2 for ${AdBoost.hoursPerAd} hours',
                      ),
                      MenuChrome.statRow(
                        label: 'Attack',
                        value: '+${AdBoost.attackPercent}%',
                      ),
                      MenuChrome.statRow(
                        label: 'Time left',
                        value: active ? left : 'None',
                      ),
                      const SizedBox(height: 12),
                      if (capped) ...[
                        Text(
                          'Stacked to 24h — wait until some time burns off, '
                          'then watch again.',
                          style: GameTheme.body(
                            size: 13,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (realAds)
                        KenneyButton(
                          label: capped
                              ? 'FULL · WAIT FOR BURN'
                              : 'WATCH AD · +${AdBoost.hoursPerAd} HOURS',
                          style: KenneyButtonStyle.brown,
                          primary: true,
                          onPressed: capped
                              ? null
                              : () {
                                  // Keep sheet open; grant + toast land after dismiss.
                                  unawaited(director.watchPowerupAd());
                                },
                        )
                      else ...[
                        Text(
                          'Ads play on the Android app. This playtest can '
                          'preview a boost.',
                          style: GameTheme.body(
                            size: 13,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                        const SizedBox(height: 8),
                        KenneyButton(
                          label: capped
                              ? 'FULL · WAIT FOR BURN'
                              : 'PREVIEW +${AdBoost.hoursPerAd} HOURS',
                          style: KenneyButtonStyle.brown,
                          primary: true,
                          onPressed: capped
                              ? null
                              : () => director.grantPowerupHour(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      KenneyButton(
                        label: 'CLOSE',
                        style: KenneyButtonStyle.grey,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    WebClickBridge.popLayer();
  }
}
