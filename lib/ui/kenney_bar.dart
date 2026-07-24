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
