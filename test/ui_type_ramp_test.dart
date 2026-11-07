import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/ui/game_theme.dart';

/// The menu ramp is the only size source. Combat painters may still size
/// world-space labels from the dungeon tile.
void main() {
  final uiRoot = Directory('lib');
  const combatPaint = <String>{
    'dungeon_paint_actors.dart',
    'dungeon_paint_floaters.dart',
    'dungeon_tile_painter.dart',
  };

  test('reading roles stay in order and the action role is not a title', () {
    expect(GameTheme.typeTitle, greaterThan(GameTheme.typeSection));
    expect(GameTheme.typeSection, greaterThan(GameTheme.typeBody));
    expect(GameTheme.typeBody, greaterThan(GameTheme.typeHint));
    expect(GameTheme.typeButton, lessThanOrEqualTo(GameTheme.typeTitle + 2));
    expect(GameTheme.typeButtonDense, lessThanOrEqualTo(GameTheme.typeSection));
  });

  test('slider ceiling and rendered ceiling are the same', () {
    expect(GameTheme.typeScaleMax, kUiTextScaleMax);
    expect(kUiTextScaleMax, greaterThanOrEqualTo(1.45));
    final osOnly = GameTheme.composeTextScaler(
      platform: TextScaler.linear(2),
      gameScale: 1,
    );
    expect(osOnly.scale(1), GameTheme.typeScaleMax);
    final gameMax = GameTheme.composeTextScaler(
      platform: TextScaler.linear(1),
      gameScale: kUiTextScaleMax,
    );
    expect(gameMax.scale(1), kUiTextScaleMax);
    final both = GameTheme.composeTextScaler(
      platform: TextScaler.linear(1.2),
      gameScale: 1.1,
    );
    expect(both.scale(1), closeTo(1.32, 0.001));
  });

  test('hint on a menu panel meets WCAG AA', () {
    expect(GameTheme.parchmentDim.toARGB32(), 0xFFB4BCC8);
    expect(GameTheme.panel.toARGB32(), 0xFF182028);
    expect(GameTheme.parchment.toARGB32(), 0xFFECE8DF);
    expect(_contrast(0xB4, 0xBC, 0xC8, 0x18, 0x20, 0x28), greaterThanOrEqualTo(4.5));
    expect(_contrast(0xEC, 0xE8, 0xDF, 0x18, 0x20, 0x28), greaterThanOrEqualTo(4.5));
  });

  test('menus do not introduce a free font size', () {
    final banned = RegExp(
      r'GameTheme\.(body|menuTitle|pixel|pixelCached|button)\([\s\S]{0,240}?size:\s*\d',
    );
    final misses = <String>[];
    for (final file in uiRoot.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('game_theme.dart')) continue;
      if (combatPaint.contains(file.uri.pathSegments.last)) continue;
      final text = file.readAsStringSync();
      if (banned.hasMatch(text)) misses.add(file.path);
    }
    expect(misses, isEmpty);
  });

  test('menu code does not shrink type with FittedBox', () {
    const allow = <String>{
      'main.dart',
      'boot_cinematic_layer.dart',
    };
    final misses = <String>[];
    for (final file in uiRoot.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (allow.contains(file.uri.pathSegments.last)) continue;
      if (file.readAsStringSync().contains('FittedBox(')) {
        misses.add(file.path);
      }
    }
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('FittedBox('), isTrue);
    expect(misses, isEmpty);
  });
}

double _lin(int channel) {
  final s = channel / 255.0;
  if (s <= 0.04045) return s / 12.92;
  return math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _contrast(int fr, int fg, int fb, int br, int bg, int bb) {
  double lum(int r, int g, int b) =>
      0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b);
  final a = lum(fr, fg, fb);
  final b = lum(br, bg, bb);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}
