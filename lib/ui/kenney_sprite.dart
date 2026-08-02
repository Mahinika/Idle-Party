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
    return Image.asset(
      asset,
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
    );
  }
}
