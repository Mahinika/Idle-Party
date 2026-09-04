import 'package:flutter/material.dart';
import '../../core/game_logic.dart';
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
                'OPEN',
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

class HubHeader extends StatefulWidget {
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
    this.partyName = 'The Party',
    this.dimIncome = false,
    this.plainChrome = false,
    this.huntHint,
    this.blessingStacks = 0,
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
  final String partyName;
  final bool dimIncome;
  final bool plainChrome;

  /// Short tonight-hunt tag (TODAY title) for AL-max pill.
  final String? huntHint;

  /// Ascend Blessing stacks for KEEP one-liner.
  final int blessingStacks;

  @override
  State<HubHeader> createState() => _HubHeaderState();
}

class _HubHeaderState extends State<HubHeader> {
  /// Gold-rate breakdown stays folded so TODAY / ENTER stay higher on phone.
  bool _ratesOpen = false;

  @override
  Widget build(BuildContext context) {
    final incomeColor = widget.dimIncome
        ? GameTheme.parchmentDim
        : GameTheme.mossLit;
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
                  color: GameTheme.torch, // FEEL 274,
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(
              width: GameTheme.minTouch,
              height: GameTheme.minTouch,
              child: WebClickScope(
                label: 'Settings',
                onPressed: widget.onOpenSettings,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: widget.onOpenSettings,
                  icon: Icon(
                    Icons.settings,
                    size: 20,
                    color: GameTheme.parchment,
                  ),
                  tooltip: 'Settings',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
          Text(
            '${widget.partyName} · Boss on F${widget.bossFloor}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            HubStatPill(
              icon: KenneyAssets.coinGold,
              caption: 'Gold',
              label: '${widget.gold}',
            ),
            HubStatPill(
              icon: KenneyAssets.vialBlue,
              caption: widget.plainChrome ? 'Permanent' : 'Essence',
              label: '${widget.essence}',
            ),
            if (!widget.plainChrome)
              HubStatPill(
                icon: KenneyAssets.iconCrown,
                caption: 'Ascend',
                label: () {
                  if (widget.ascensionLevel < GameLogic.maxAscensionLevel) {
                    final bless = widget.blessingStacks > 0
                        ? ' · Blessing ×${widget.blessingStacks}'
                        : '';
                    return 'AL ${widget.ascensionLevel}$bless';
                  }
                  final hunt = widget.huntHint;
                  final huntBit = (hunt != null && hunt.isNotEmpty)
                      ? hunt
                      : 'endgame';
                  final bless = widget.blessingStacks > 0
                      ? ' · B×${widget.blessingStacks}'
                      : '';
                  return 'AL ${widget.ascensionLevel} · MAX · $huntBit$bless';
                }(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (widget.dimIncome) ...[
          Text(
            () {
              final hunt = widget.huntHint;
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
            label: _ratesOpen ? 'Hide income details' : 'Show income details',
            onPressed: () => setState(() => _ratesOpen = !_ratesOpen),
            child: Semantics(
              button: true,
              label: _ratesOpen
                  ? 'Hide income details. ${widget.incomeLine}'
                  : 'Show income details. ${widget.incomeLine}',
              onTap: () => setState(() => _ratesOpen = !_ratesOpen),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _ratesOpen = !_ratesOpen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _ratesOpen
                        ? widget.incomeLine
                        : '${widget.incomeLine} · Income ▸',
                    textAlign: TextAlign.center,
                    style: GameTheme.body(size: 13, color: incomeColor),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (!widget.dimIncome && _ratesOpen) ...[
          Text(
            widget.multiplierLine,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
          if (widget.displayTitle.isNotEmpty || widget.collectionScore > 0) ...[
            const SizedBox(height: 3),
            Text(
              widget.displayTitle.isEmpty
                  ? '${widget.willRank} · ${widget.collectionScore}'
                  : '${widget.willRank} · ${widget.displayTitle}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
          ],
          if (widget.zoneTrophies > 0 && !GameTheme.isPhoneWidth(context)) ...[
            const SizedBox(height: 2),
            Text(
              'Zone trophies ${widget.zoneTrophies}',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 12, color: GameTheme.mossLit),
            ),
          ],
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
    // Loose chips — no framed inventory boxes on the keep.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KenneySprite(asset: icon, size: 14),
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
