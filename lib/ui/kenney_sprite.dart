import 'dart:math' as math;

import 'package:flutter/material.dart';

class KenneySprite extends StatelessWidget {
  const KenneySprite({
    super.key,
    required this.asset,
    this.size = 32,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final box = math.max(width ?? size, height ?? size);
    // Decode no larger than we paint. Kenney tiles are already tiny (decoding
    // never upscales), but custom portraits are 1024px and show as ~32px discs.
    final decodeWidth =
        (box * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(16, 1024);
    return Image.asset(
      asset,
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      cacheWidth: decodeWidth,
    );
  }
}
