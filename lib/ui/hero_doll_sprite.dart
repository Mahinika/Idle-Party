import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/hero.dart';
import 'hero_paper_doll.dart';

/// Loads the Roguelike Characters atlas once and paints paper-doll heroes.
class HeroDollSprite extends StatefulWidget {
  const HeroDollSprite({
    super.key,
    required this.hero,
    this.partyIndex = 0,
    this.size = 32,
    this.walkFrame = 0,
  });

  final PartyHero hero;
  final int partyIndex;
  final double size;
  final int walkFrame;

  @override
  State<HeroDollSprite> createState() => _HeroDollSpriteState();
}

class _HeroDollSpriteState extends State<HeroDollSprite> {
  static ui.Image? _cachedAtlas;
  static Future<ui.Image>? _loading;

  ui.Image? _atlas;

  @override
  void initState() {
    super.initState();
    _ensureAtlas();
  }

  Future<void> _ensureAtlas() async {
    if (_cachedAtlas != null) {
      setState(() => _atlas = _cachedAtlas);
      return;
    }
    _loading ??= () async {
      final data = await rootBundle.load(RoguelikeCharAtlas.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    }();
    final img = await _loading!;
    _cachedAtlas = img;
    if (mounted) setState(() => _atlas = img);
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas;
    if (atlas == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _HeroDollPainter(
        atlas: atlas,
        hero: widget.hero,
        partyIndex: widget.partyIndex,
        walkFrame: widget.walkFrame,
      ),
    );
  }
}

class _HeroDollPainter extends CustomPainter {
  _HeroDollPainter({
    required this.atlas,
    required this.hero,
    required this.partyIndex,
    required this.walkFrame,
  });

  final ui.Image atlas;
  final PartyHero hero;
  final int partyIndex;
  final int walkFrame;

  @override
  void paint(Canvas canvas, Size size) {
    HeroPaperDoll.paint(
      canvas,
      atlas,
      Offset(size.width / 2, size.height / 2),
      size.shortestSide,
      hero: hero,
      partyIndex: partyIndex,
      walkFrame: walkFrame,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroDollPainter oldDelegate) {
    return oldDelegate.hero != hero ||
        oldDelegate.walkFrame != walkFrame ||
        oldDelegate.partyIndex != partyIndex ||
        oldDelegate.atlas != atlas;
  }
}
