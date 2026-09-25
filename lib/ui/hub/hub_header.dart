import 'package:flutter/material.dart';
import '../../core/game_logic.dart';
import '../../assets/custom_assets.dart';
import '../cave_atmosphere.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../shell/wallet_strip.dart';
import '../web_click_bridge.dart';

class HubSceneBackdrop extends StatelessWidget {
  const HubSceneBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CaveAtmosphere.fullBleedScene(
          CustomAssets.hubScene,
          alignment: const Alignment(0, -0.08),
        ),
        CaveAtmosphere.readabilityScrim(top: 0.38, bottom: 0.42),
      ],
    );
  }
}

class HubOfflineBanner extends StatelessWidget {
  const HubOfflineBanner({
    super.key,
    required this.text,
    required this.onDismiss,
    this.compact = false,
  });

  final String text;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDismiss,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 6 : 10,
          ),
          decoration: MenuChrome.hubPanel(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.mossLit,
                  ),
                ),
              ),
              Text(
                'OPEN SUMMARY',
                style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm Play-store update row. English copy only.
class HubPlayUpdateBanner extends StatelessWidget {
  const HubPlayUpdateBanner({
    super.key,
    required this.onUpdate,
    required this.onLater,
    this.compact = false,
  });

  final VoidCallback onUpdate;
  final VoidCallback onLater;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Update on Google Play',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 10,
          compact ? 5 : 8,
          compact ? 8 : 10,
          compact ? 5 : 8,
        ),
        decoration: MenuChrome.hubPanel(selected: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'UPDATE ON GOOGLE PLAY',
              textAlign: TextAlign.center,
              style: GameTheme.body(
                size: 12,
                color: GameTheme.mossLit,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A newer Idle Party is ready.',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: 'LATER',
                    style: GameButtonStyle.grey,
                    expanded: true,
                    onPressed: onLater,
                    tip: 'Hide until a newer Play build',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameButton(
                    label: 'GET UPDATE',
                    style: GameButtonStyle.brown,
                    expanded: true,
                    onPressed: onUpdate,
                    tip: 'Open Google Play',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showHubIncomeSheet(
  BuildContext context, {
  required String incomeLine,
  required String multiplierLine,
  required String displayTitle,
  required String willRank,
  required int collectionScore,
}) async {
  WebClickBridge.pushLayer();
  try {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: MenuChrome.sheet,
            borderRadius: MenuChrome.sheetRadius,
            clipBehavior: Clip.antiAlias,
            child: MenuChrome.playSafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MenuChrome.sheetHandle(),
                    Text('Income', style: GameTheme.menuTitle(size: 18)),
                    const SizedBox(height: 8),
                    Text(
                      incomeLine,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(size: 14, color: GameTheme.mossLit),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      multiplierLine,
                      textAlign: TextAlign.center,
                      style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
                    ),
                    if (displayTitle.isNotEmpty || collectionScore > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        displayTitle.isEmpty
                            ? '$willRank · $collectionScore'
                            : '$willRank · $displayTitle',
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 12,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GameButton(
                      label: 'CLOSE',
                      style: GameButtonStyle.grey,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  } finally {
    WebClickBridge.popLayer();
  }
}

class HubHeader extends StatelessWidget {
  const HubHeader({
    super.key,
    required this.ascensionLevel,
    required this.partySubline,
    required this.gold,
    required this.essence,
    required this.willRank,
    required this.collectionScore,
    required this.displayTitle,
    required this.onOpenSettings,
    required this.incomeLine,
    required this.multiplierLine,
    this.dimIncome = false,
    this.plainChrome = false,
    this.showEssence = true,
    this.huntHint,
    this.blessingStacks = 0,
    this.showBlessingStacks = false,
  });

  final int ascensionLevel;
  final String partySubline;
  final int gold;
  final int essence;
  final String willRank;
  final int collectionScore;
  final String displayTitle;
  final VoidCallback onOpenSettings;
  final String incomeLine;
  final String multiplierLine;
  final bool dimIncome;
  final bool plainChrome;
  final bool showEssence;

  /// Short tonight-hunt tag (TODAY title) for AL-max pill.
  final String? huntHint;

  /// Ascend Blessing stacks for KEEP one-liner.
  final int blessingStacks;

  /// Hide Blessing until ESSENCE / KEEP is unlocked.
  final bool showBlessingStacks;

  /// Short AL-cap pill: tease the tonight hunt — never "MAX" (not game over).
  static String alCapPillLabel({
    required int ascensionLevel,
    String? huntHint,
    int blessingStacks = 0,
    bool showBlessingStacks = false,
  }) {
    final hunt = (huntHint != null && huntHint.isNotEmpty)
        ? huntHint
        : 'next hunt';
    final bless = showBlessingStacks && blessingStacks > 0
        ? ' · Blessing ×$blessingStacks'
        : '';
    return 'AL $ascensionLevel · $hunt$bless';
  }

  @override
  Widget build(BuildContext context) {
    final incomeColor = dimIncome
        ? GameTheme.parchmentDim
        : GameTheme.mossLit;
    return Column(
      children: [
        Row(
          children: [
            WalletStrip(
              gold: gold,
              essence: essence,
              showEssence: showEssence,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'IDLE PARTY',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GameTheme.pixel(
                    size: 18,
                    color: GameTheme.torch,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            GameIconButton(
              label: 'Settings',
              asset: UiIcon.settings,
              size: 18,
              onPressed: onOpenSettings,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          partySubline,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        if (!plainChrome) ...[
          const SizedBox(height: 6),
          Center(
            child: HubStatPill(
              icon: UiIcon.ascend,
              caption: 'Ascend',
              label: () {
                if (ascensionLevel < GameLogic.maxAscensionLevel) {
                  final bless = showBlessingStacks && blessingStacks > 0
                      ? ' · Blessing ×$blessingStacks'
                      : '';
                  return 'AL $ascensionLevel$bless';
                }
                return HubHeader.alCapPillLabel(
                  ascensionLevel: ascensionLevel,
                  huntHint: huntHint,
                  blessingStacks: blessingStacks,
                  showBlessingStacks: showBlessingStacks,
                );
              }(),
            ),
          ),
        ],
        const SizedBox(height: 4),
        if (dimIncome) ...[
          Text(
            () {
              final hunt = huntHint;
              if (hunt != null && hunt.isNotEmpty) {
                return 'Tonight · $hunt';
              }
              return 'Tonight · endgame hunt';
            }(),
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.torchHot),
          ),
        ] else ...[
          WebClickScope(
            label: 'Show income details',
            onPressed: () => showHubIncomeSheet(
              context,
              incomeLine: incomeLine,
              multiplierLine: multiplierLine,
              displayTitle: displayTitle,
              willRank: willRank,
              collectionScore: collectionScore,
            ),
            child: Semantics(
              button: true,
              label: 'Show income details. $incomeLine',
              onTap: () => showHubIncomeSheet(
                context,
                incomeLine: incomeLine,
                multiplierLine: multiplierLine,
                displayTitle: displayTitle,
                willRank: willRank,
                collectionScore: collectionScore,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showHubIncomeSheet(
                  context,
                  incomeLine: incomeLine,
                  multiplierLine: multiplierLine,
                  displayTitle: displayTitle,
                  willRank: willRank,
                  collectionScore: collectionScore,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    incomeLine,
                    textAlign: TextAlign.center,
                    style: GameTheme.body(size: 13, color: incomeColor),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class HubStatPill extends StatelessWidget {
  const HubStatPill({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
  });
  final String icon;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon.asset(icon, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null) ...[
                Text(
                  caption!,
                  style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 14, color: GameTheme.parchment),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Painted campaign map with tappable zone markers (saga / idle path style).
