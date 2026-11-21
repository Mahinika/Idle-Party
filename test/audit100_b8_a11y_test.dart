import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/game_icon.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';
import 'package:idle_party/ui/shell/settings_overlay.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

/// Audit 100, batch 8: text and accessibility sweep.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  Future<void> pumpBody(
    WidgetTester t,
    Size size,
    double scale,
    Widget Function() body,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: body()),
      ),
    );
    await a100Settle(t);
  }

  for (final size in a100Sizes) {
    for (final scale in a100Scales) {
      final tag = a100Label(size, scale);

      testWidgets('F084/F085 SOUND said once, big switch $tag', (t) async {
        final d = await a100Director();
        await pumpBody(
          t,
          size,
          scale,
          () => SettingsOverlay(director: d, onClose: () {}),
        );
        final page = find.byType(TabBarView);
        // The tab names SOUND; the page does not repeat it as a header.
        expect(
          find.descendant(of: page, matching: find.text('SOUND')),
          findsNothing,
        );
        // The long rules sit in a fold, closed by default.
        expect(find.text('How sound works'), findsOneWidget);
        expect(find.textContaining('Mute turns everything off'), findsNothing);
        final mute = find.ancestor(
          of: find.text('Mute all sound'),
          matching: find.byType(InkWell),
        );
        final mark = find.descendant(
          of: mute.first,
          matching: find.byKey(MenuChrome.toggleMarkKey),
        );
        expect(mark, findsOneWidget);
        final r = t.getRect(mark);
        expect(r.width, greaterThanOrEqualTo(52));
        expect(r.height, greaterThanOrEqualTo(30));
        expect(r.right, lessThanOrEqualTo(size.width));
        a100ExpectWhole(t, find.text('Mute all sound'));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        d.dispose();
      });

      testWidgets('F058 CAMP free level: same 48dp button at any scale $tag', (
        t,
      ) async {
        await pumpBody(
          t,
          size,
          scale,
          () => Center(
            child: UpgradePanel.campWatchCompact(
              label: 'Watch · free level',
              onTap: () {},
              key: UpgradePanel.campWatchListKey,
            ),
          ),
        );
        final r = t.getRect(find.byKey(UpgradePanel.campWatchListKey));
        expect(r.width, closeTo(GameTheme.primaryTouch, 0.01));
        expect(r.height, closeTo(GameTheme.primaryTouch, 0.01));
        // No wide text chip: the label lives in the tooltip / semantics.
        expect(find.text('Watch · free level'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w is Tooltip && w.message == 'Watch · free level',
          ),
          findsOneWidget,
        );
      });
    }
  }

  testWidgets('F097 every GameIconButton has a tooltip', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              GameIconButton(
                label: 'Close',
                glyph: UiGlyph.close,
                onPressed: () {},
              ),
              GameIconButton(
                label: 'Swap',
                tooltip: 'Swap this quest',
                asset: UiIcon.watchAd,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Swap this quest'), findsOneWidget);
    // One semantics label per button, not label + tooltip twice.
    final h = t.ensureSemantics();
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    h.dispose();
  });

  testWidgets('F097 the home screen has no icon button without a hint', (
    t,
  ) async {
    final (d, router) = await a100Pump(
      t,
      const Size(360, 780),
      1.0,
      full: true,
    );
    await a100Settle(t);
    final icons = find.byType(GameIconButton);
    for (final e in icons.evaluate()) {
      final w = e.widget as GameIconButton;
      expect((w.tooltip ?? w.label).trim(), isNotEmpty);
      expect(
        find.descendant(of: find.byWidget(w), matching: find.byType(Tooltip)),
        findsOneWidget,
      );
    }
    final raw = find.byType(IconButton);
    for (final e in raw.evaluate()) {
      expect((e.widget as IconButton).tooltip, isNotNull);
    }
    await t.pumpWidget(const SizedBox.shrink());
    d.dispose();
    router.dispose();
    await t.pump();
  });

  test('F097 source scan: every IconButton in lib sets a tooltip', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!RegExp(r'(^|[^A-Za-z])IconButton(\.\w+)?\(').hasMatch(l)) {
          continue;
        }
        final window = lines.skip(i).take(20).join('\n');
        if (!window.contains('tooltip:')) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
