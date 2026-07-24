import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kenney_assets.dart';

enum KenneyButtonStyle { brown, grey, red }

class KenneyButton extends StatelessWidget {
  const KenneyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = KenneyButtonStyle.brown,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final KenneyButtonStyle style;
  final bool expanded;

  String get _asset => switch (style) {
    KenneyButtonStyle.brown => KenneyAssets.buttonBrown,
    KenneyButtonStyle.grey => KenneyAssets.buttonGrey,
    KenneyButtonStyle.red => KenneyAssets.buttonRed,
  };

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.pressStart2p(
          fontSize: 10,
          color: const Color(0xFFFFF7D7),
        ),
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_asset),
              fit: BoxFit.fill,
              centerSlice: const Rect.fromLTWH(8, 8, 16, 16),
              filterQuality: FilterQuality.none,
              opacity: onPressed == null ? 0.45 : 1,
            ),
          ),
          child: expanded
              ? SizedBox(width: double.infinity, child: child)
              : child,
        ),
      ),
    );

    return Opacity(opacity: onPressed == null ? 0.55 : 1, child: button);
  }
}
