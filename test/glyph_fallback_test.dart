import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:idle_party/ui/game_theme.dart';

/// Polish 7 #1: VT323 and Cinzel have no "→" (≈350 uses in copy), so lines
/// like "GOLD → MARKET" rendered with a hole. [GameTheme] styles fall back
/// to the bundled IdleArrows pixel font for those glyphs.

/// Code points in a TrueType cmap (formats 4 and 12).
Set<int> _cmap(String path) {
  final b = ByteData.sublistView(File(path).readAsBytesSync());
  final numTables = b.getUint16(4);
  var cmapOff = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes([
      for (var k = 0; k < 4; k++) b.getUint8(rec + k),
    ]);
    if (tag == 'cmap') cmapOff = b.getUint32(rec + 8);
  }
  expect(cmapOff, isNonNegative, reason: path);
  final out = <int>{};
  final n = b.getUint16(cmapOff + 2);
  for (var i = 0; i < n; i++) {
    final sub = cmapOff + b.getUint32(cmapOff + 4 + 8 * i + 4);
    final format = b.getUint16(sub);
    if (format == 4) {
      final segX2 = b.getUint16(sub + 6);
      final ends = sub + 14;
      final starts = ends + segX2 + 2;
      final deltas = starts + segX2;
      final ranges = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = b.getUint16(ends + 2 * s);
        final start = b.getUint16(starts + 2 * s);
        final delta = b.getUint16(deltas + 2 * s);
        final rangeAt = ranges + 2 * s;
        final range = b.getUint16(rangeAt);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          final glyph = range == 0
              ? (c + delta) & 0xFFFF
              : b.getUint16(rangeAt + range + 2 * (c - start));
          if (glyph != 0) out.add(c);
        }
      }
    } else if (format == 12) {
      final groups = b.getUint32(sub + 12);
      for (var g = 0; g < groups; g++) {
        final at = sub + 16 + 12 * g;
        for (var c = b.getUint32(at); c <= b.getUint32(at + 4); c++) {
          out.add(c);
        }
      }
    }
  }
  return out;
}

/// Non-ASCII characters inside string literals under lib/ (not comments).
Map<int, String> _copyGlyphs() {
  final lit = RegExp(r"'(?:[^'\\\n]|\\.)*'|" r'"(?:[^"\\\n]|\\.)*"');
  final out = <int, String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    // Look-alike letters for the name filter, never drawn.
    if (f.path.endsWith('party_name_filter.dart')) continue;
    for (final line in f.readAsLinesSync()) {
      final t = line.trimLeft();
      if (t.startsWith('//')) continue;
      for (final m in lit.allMatches(line)) {
        for (final r in m.group(0)!.runes) {
          if (r > 127) out.putIfAbsent(r, () => f.path);
        }
      }
    }
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every glyph in the copy is in the body/title font or IdleArrows', () {
    final arrows = _cmap(GameTheme.glyphFallbackAsset);
    final copy = _copyGlyphs();
    expect(copy.keys, contains(0x2192), reason: 'copy still uses →');
    for (final font in ['VT323-Regular.ttf', 'Cinzel-Bold.ttf']) {
      final own = _cmap('assets/fonts/$font');
      expect(own.contains(0x2192), isFalse, reason: '$font gained →?');
      final missing = [
        for (final e in copy.entries)
          if (!own.contains(e.key) && !arrows.contains(e.key))
            '${String.fromCharCode(e.key)} U+${e.key.toRadixString(16)} '
                '(${e.value})',
      ];
      expect(missing, isEmpty, reason: '$font has no glyph for these');
    }
  });

  test('body, button and title styles fall back to IdleArrows', () {
    for (final s in [
      GameTheme.body(),
      GameTheme.hint(),
      GameTheme.readable(),
      GameTheme.button(),
      GameTheme.menuTitle(),
      GameTheme.title(),
    ]) {
      expect(s.fontFamilyFallback, contains(GameTheme.glyphFallbackFamily));
    }
  });

  testWidgets('"→" draws ink in body text (it was a hole)', (tester) async {
    await tester.runAsync(GameTheme.loadGlyphFallback);
    await tester.runAsync(
      () => GoogleFonts.pendingFonts([GoogleFonts.vt323(fontSize: 20)]),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: GameTheme.ink,
              child: Text(
                '→',
                style: GameTheme.body(size: 40, color: GameTheme.parchment),
              ),
            ),
          ),
        ),
      ),
    );
    final p = tester.renderObject<RenderParagraph>(find.text('→'));
    // IdleArrows advance is 400/1000 em, VT323's cell.
    expect(p.size.width, closeTo(16, 0.5));
    final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final lit = await tester.runAsync(() async {
      final img = await rb.toImage();
      final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var n = 0;
      for (var i = 0; i < d.lengthInBytes; i += 4) {
        if (d.getUint8(i) > 128) n++;
      }
      return n;
    });
    // VT323 alone draws nothing for U+2192; the arrow is ~30 px².
    expect(lit, greaterThan(20));
  });
}
