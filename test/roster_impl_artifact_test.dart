import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/meta/roster_panel.dart';

import 'shell_golden_harness.dart';

Future<void> _writeShot(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  testWidgets('roster role slot artifact shots', (tester) async {
    final out = Directory('/opt/cursor/artifacts/roster-impl');
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(),
    );
    addTearDown(director.dispose);

    for (final scale in <double>[1.0, 1.45]) {
      final label = scale == 1.0 ? '1.0' : '1.45';
      bindA56View(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final shellKey = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: shellGoldenScaffold(
            RepaintBoundary(
              key: shellKey,
              child: SingleChildScrollView(
                child: TeamCompositionOverlay(director: director),
              ),
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 600);
      await _writeShot(
        tester,
        shellKey,
        '${out.path}/party_slots_$label.png',
      );

      final pickerKey = GlobalKey();
      final current = director.state.heroes.first;
      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: shellGoldenScaffold(
            RepaintBoundary(
              key: pickerKey,
              child: FractionallySizedBox(
                heightFactor: 0.88,
                child: RosterSlotPickerSheet(
                  director: director,
                  slotIndex: 2,
                  currentHero: current,
                  onPick: (_) {},
                  onUnlock: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 400);
      await _writeShot(
        tester,
        pickerKey,
        '${out.path}/slot_picker_$label.png',
      );
    }

    final tank = director.state.heroes.first;
    final dps = director.state.heroes.last;
    final swapKey = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: shellGoldenMedia,
        child: shellGoldenScaffold(
          RepaintBoundary(
            key: swapKey,
            child: SizedBox(
              height: 520,
              child: RosterSwapCompareSheet(
                current: tank,
                incoming: dps,
                onSwap: () {},
                onKeep: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 400);
    await _writeShot(tester, swapKey, '${out.path}/swap_compare.png');
  });
}