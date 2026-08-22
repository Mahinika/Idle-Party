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
    final detail = active
        ? '×2 gold · +${AdBoost.attackPercent}% ATK · $left left'
        : 'Watch ad · 1 hour of ×2 gold and +${AdBoost.attackPercent}% ATK';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: WebClickScope(
        label: 'POWERUPS',
        onPressed: onOpen,
        child: Semantics(
          button: true,
          label: 'POWERUPS. $detail',
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
                  constraints: const BoxConstraints(
                    minHeight: GameTheme.minTouch,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        KenneySprite(asset: KenneyAssets.potionBlue, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'POWERUPS',
                                style: GameTheme.body(
                                  size: 13,
                                  color: active
                                      ? GameTheme.torchHot
                                      : GameTheme.parchment,
                                ),
                              ),
                              Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GameTheme.body(
                                  size: 12,
                                  color: GameTheme.parchmentDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          active ? left : 'WATCH',
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.torchHot,
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
                        'Watch a short ad for 1 hour of double gold and '
                        '+${AdBoost.attackPercent}% attack. Watch again to add '
                        'another hour (up to 24 hours). Optional — fights never '
                        'pause for an ad.',
                        style: GameTheme.body(
                          size: 15,
                          color: GameTheme.parchment,
                        ),
                      ),
                      const SizedBox(height: 10),
                      MenuChrome.statRow(
                        label: 'Gold',
                        value: active ? '×2 now' : '×2 for 1 hour',
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
                      if (realAds)
                        KenneyButton(
                          label: capped
                              ? 'STACKED TO 24H'
                              : 'WATCH AD · +1 HOUR',
                          style: KenneyButtonStyle.brown,
                          primary: true,
                          onPressed: capped
                              ? null
                              : () {
                                  director.watchPowerupAd();
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
                              ? 'STACKED TO 24H'
                              : 'PREVIEW +1 HOUR',
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
