import 'package:flutter/material.dart';
import '../custom_assets.dart';
import '../cave_atmosphere.dart';
import '../game_theme.dart';
import '../kenney_assets.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
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
  });

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDismiss,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                'TAP',
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
  });

  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Update on Google Play',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                  child: KenneyButton(
                    label: 'LATER',
                    style: KenneyButtonStyle.grey,
                    expanded: true,
                    onPressed: onLater,
                    tip: 'Hide until a newer Play build',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KenneyButton(
                    label: 'GET UPDATE',
                    style: KenneyButtonStyle.brown,
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

class HubHeader extends StatelessWidget {
  const HubHeader({
    super.key,
    required this.ascensionLevel,
    required this.bossFloor,
    required this.gold,
    required this.essence,
    required this.willRank,
    required this.collectionScore,
    required this.displayTitle,
    required this.zoneTrophies,
    required this.torch,
    required this.onOpenSettings,
    required this.incomeLine,
    required this.multiplierLine,
  });

  final int ascensionLevel;
  final int bossFloor;
  final int gold;
  final int essence;
  final String willRank;
  final int collectionScore;
  final String displayTitle;
  final int zoneTrophies;
  final double torch;
  final VoidCallback onOpenSettings;
  final String incomeLine;
  final String multiplierLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            Expanded(
              flex: 6,
              child: Text(
                'IDLE PARTY',
                textAlign: TextAlign.center,
                style: GameTheme.pixel(
                  size: 20,
                  color: Color.lerp(
                    GameTheme.torch,
                    GameTheme.torchHot,
                    torch,
                  )!,
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(
              width: GameTheme.minTouch,
              height: GameTheme.minTouch,
              child: WebClickScope(
                label: 'Settings',
                onPressed: onOpenSettings,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: onOpenSettings,
                  icon: KenneySprite(asset: KenneyAssets.iconDoor, size: 18),
                  tooltip: 'Settings',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Hero\'s Keep · Boss F$bossFloor',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            HubStatPill(icon: KenneyAssets.coinGold, label: '$gold'),
            HubStatPill(icon: KenneyAssets.vialBlue, label: '$essence'),
            HubStatPill(
              icon: KenneyAssets.iconCrown,
              label: 'AL $ascensionLevel',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(
          label: incomeLine,
          child: Text(
            incomeLine,
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.mossLit),
          ),
        ),
        Text(
          multiplierLine,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
        ),
        if (displayTitle.isNotEmpty || collectionScore > 0) ...[
          const SizedBox(height: 3),
          Text(
            displayTitle.isEmpty
                ? '$willRank · $collectionScore'
                : '$willRank · $displayTitle',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        if (zoneTrophies > 0 && !GameTheme.isPhoneWidth(context)) ...[
          const SizedBox(height: 2),
          Text(
            'Zone trophies $zoneTrophies',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.mossLit),
          ),
        ],
      ],
    );
  }
}

class HubStatPill extends StatelessWidget {
  const HubStatPill({super.key, required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Loose chips — no framed inventory boxes on the keep.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KenneySprite(asset: icon, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GameTheme.body(size: 14, color: GameTheme.parchment),
        ),
      ],
    );
  }
}

/// Painted campaign map with tappable zone markers (saga / idle path style).
