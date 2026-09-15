import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ad_boost.dart';
import '../../models/meta_depth.dart';
import '../game_icon.dart';
import '../game_theme.dart';

/// Active SCROLLS: distinct owned icons + remaining time, stacked top → bottom.
class ScrollBuffStack extends StatefulWidget {
  const ScrollBuffStack({
    super.key,
    required this.meta,
    this.nowMs,
  });

  final MetaDepthState meta;
  final int? nowMs;

  @override
  State<ScrollBuffStack> createState() => _ScrollBuffStackState();
}

class _ScrollBuffStackState extends State<ScrollBuffStack> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(ScrollBuffStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTick();
  }

  void _syncTick() {
    final live = widget.nowMs == null;
    if (!live) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chips = AdBoost.hudChips(widget.meta, nowMs: widget.nowMs);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final chip in chips) _ScrollBuffPip(chip: chip),
      ],
    );
  }
}

class _ScrollBuffPip extends StatelessWidget {
  const _ScrollBuffPip({required this.chip});

  final AdScrollHudChip chip;

  static Color tintFor(AdBuffId id) => switch (id) {
        AdBuffId.atk => GameTheme.bloodLit,
        AdBuffId.gold => GameTheme.torch,
        AdBuffId.xp => GameTheme.mossLit,
        AdBuffId.move => GameTheme.accentInfo,
        AdBuffId.loot => GameTheme.rarityLegendary,
        AdBuffId.speed => GameTheme.accentWarn,
        AdBuffId.bundle => GameTheme.torchHot,
        AdBuffId.offline => GameTheme.hudManaBright,
      };

  static String assetFor(AdBuffId id) => switch (id) {
        AdBuffId.atk => UiIcon.sword,
        AdBuffId.gold => UiIcon.gold,
        AdBuffId.xp => UiIcon.tome,
        AdBuffId.move => UiIcon.boots,
        AdBuffId.loot => UiIcon.chest,
        AdBuffId.speed => UiIcon.wand,
        AdBuffId.bundle => UiIcon.sword,
        AdBuffId.offline => UiIcon.campfire,
      };

  @override
  Widget build(BuildContext context) {
    final on = chip.active;
    final tint = on ? tintFor(chip.id) : GameTheme.parchmentDim;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        label: on ? '${chip.shortLabel} ${chip.timeLabel}' : '${chip.shortLabel} off',
        child: SizedBox(
          width: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: GameTheme.hudWell,
                  borderRadius: BorderRadius.circular(GameTheme.radiusHud),
                  border: Border.all(color: tint, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: GameIcon.asset(
                    assetFor(chip.id),
                    size: 16,
                    color: on ? null : GameTheme.parchmentDim,
                  ),
                ),
              ),
              if (on && chip.timeLabel.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  chip.timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: GameTheme.pixel(
                    size: GameTheme.hudPixel,
                    color: tint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
