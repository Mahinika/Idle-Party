import 'package:flutter/material.dart';

import 'kenney_assets.dart';

enum KenneyBarColor { green, yellow, red }

class KenneyProgressBar extends StatelessWidget {
  const KenneyProgressBar({
    super.key,
    required this.value,
    this.height = 14,
    this.color = KenneyBarColor.green,
  });

  final double value;
  final double height;
  final KenneyBarColor color;

  (String, String, String) get _fillAssets => switch (color) {
    KenneyBarColor.green => (
      KenneyAssets.barGreenLeft,
      KenneyAssets.barGreenMid,
      KenneyAssets.barGreenRight,
    ),
    KenneyBarColor.yellow => (
      KenneyAssets.barYellowLeft,
      KenneyAssets.barYellowMid,
      KenneyAssets.barYellowRight,
    ),
    KenneyBarColor.red => (
      KenneyAssets.barRedLeft,
      KenneyAssets.barRedMid,
      KenneyAssets.barRedRight,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final fill = _fillAssets;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                KenneyAssets.barBackLeft,
                height: height,
                fit: BoxFit.fitHeight,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
              ),
              Expanded(
                child: Image.asset(
                  KenneyAssets.barBackMid,
                  height: height,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  isAntiAlias: false,
                ),
              ),
              Image.asset(
                KenneyAssets.barBackRight,
                height: height,
                fit: BoxFit.fitHeight,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
              ),
            ],
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: clamped == 0 ? 0.001 : clamped,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    fill.$1,
                    height: height,
                    fit: BoxFit.fitHeight,
                    filterQuality: FilterQuality.none,
                    isAntiAlias: false,
                  ),
                  Expanded(
                    child: Image.asset(
                      fill.$2,
                      height: height,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      isAntiAlias: false,
                    ),
                  ),
                  Image.asset(
                    fill.$3,
                    height: height,
                    fit: BoxFit.fitHeight,
                    filterQuality: FilterQuality.none,
                    isAntiAlias: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rounded progress bar using the ui_adventure progress_* assets.
// Uses the _border image as background frame and the fill image clipped
// to [value].
// ─────────────────────────────────────────────────────────────────────────────

class RpgProgressBar extends StatelessWidget {
  const RpgProgressBar({
    super.key,
    required this.value,
    this.height = 18,
    this.color = KenneyBarColor.green,
  });

  final double value;
  final double height;
  final KenneyBarColor color;

  String get _borderAsset => switch (color) {
    KenneyBarColor.green => KenneyAssets.progressGreenBorder,
    // No yellow rounded fill in the pack — use white border + yellow tint in paint.
    KenneyBarColor.yellow => KenneyAssets.progressBlueBorder,
    KenneyBarColor.red => KenneyAssets.progressRedBorder,
  };

  String get _fillAsset => switch (color) {
    KenneyBarColor.green => KenneyAssets.progressGreen,
    KenneyBarColor.yellow => KenneyAssets.progressWhite,
    KenneyBarColor.red => KenneyAssets.progressRed,
  };

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _borderAsset,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            isAntiAlias: false,
          ),
          if (clamped > 0.01)
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: clamped,
                child: color == KenneyBarColor.yellow
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFFFD54A),
                          BlendMode.modulate,
                        ),
                        child: Image.asset(
                          _fillAsset,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
                          isAntiAlias: false,
                        ),
                      )
                    : Image.asset(
                        _fillAsset,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.none,
                        isAntiAlias: false,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
