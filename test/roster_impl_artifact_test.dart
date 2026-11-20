import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/party_role_slots.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/meta/roster_panel.dart';

import 'shell_golden_harness.dart';

Future<void> _pumpUntilDolls(WidgetTester tester) async {
  final baseline = HeroDollSprite.pendingLoads;
  await pumpGoldenFrames(tester, ms: 100);
  final sw = Stopwatch()..start();
  var idle = 0;
  while (sw.elapsedMilliseconds < 15000) {
    if (HeroDollSprite.pendingLoads <= baseline) {
      idle++;
      if (idle >= 5) break;
    } else {
      idle = 0;
    }
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 16)),
    );
  }
  await pumpGoldenFrames(tester, ms: 200);
}

Future<void> _writeShot(WidgetTester tester, GlobalKey key, String path) async {
  await settleGoldenImages(tester);
  await _pumpUntilDolls(tester);
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final img = image!;
  final w = img.width;
  final h = img.height;
  final raw = await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final png = await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.png),
  );
  img.dispose();
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());

  // Dolls paint opaque pixels left of center — empty placeholders stay flat.
  final bytes = raw!;
  var vivid = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w ~/ 3; x++) {
      final i = (y * w + x) * 4;
      final r = bytes.getUint8(i);
      final g = bytes.getUint8(i + 1);
      final b = bytes.getUint8(i + 2);
      final a = bytes.getUint8(i + 3);
      if (a > 200 && (r + g + b) > 80 && (r + g + b) < 720) {
        vivid++;
      }
    }
  }
  expect(
    vivid,
    greaterThan(120),
    reason: 'Hero doll should paint visible pixels in $path (got $vivid)',
  );
}

Widget _rosterFrame({
  required GlobalKey key,
  required Widget child,
}) {
  return MediaQuery(
    data: shellGoldenMedia,
    child: shellGoldenScaffold(
      RepaintBoundary(
        key: key,
        child: child,
      ),
    ),
  );
}

GameState _artifactState() {
  final blood = PartyHero.starting(
    name: 'Sanguine',
    specId: HeroSpecId.blood,
    level: 12,
  );
  var state = GameLogic.createInitialState();
  return state.copyWith(
    ascensionLevel: 5,
    heroRoster: [...state.heroRoster, blood],
  );
}

PartyHero _tankA(GameState state) =>
    state.heroRoster.firstWhere((h) => h.specId == HeroSpecId.protection);

PartyHero _tankB(GameState state) =>
    state.heroRoster.firstWhere((h) => h.specId == HeroSpecId.blood);

void main() {
  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  testWidgets('roster role slot artifact shots', (tester) async {
    final out = Directory('/opt/cursor/artifacts/roster-impl');
    final baseState = _artifactState();

    for (final scale in <double>[1.0, 1.45]) {
      final label = scale == 1.0 ? '1.0' : '1.45';
      bindA56View(tester);
      final director = GameDirector.preview(
        initialState: baseState.copyWith(uiTextScale: scale),
      );
      addTearDown(director.dispose);

      final shellKey = GlobalKey();
      await tester.pumpWidget(
        _rosterFrame(
          key: shellKey,
          child: AnimatedBuilder(
            animation: director,
            builder: (context, _) => SingleChildScrollView(
              child: TeamCompositionOverlay(director: director),
            ),
          ),
        ),
      );
      await tester.pump();
      await pumpGoldenFrames(tester, ms: 200);
      await _pumpUntilDolls(tester);
      final labelEl = tester.element(find.text('Warrior').first);
      final effectiveScale = MediaQuery.textScalerOf(labelEl).scale(1.0);
      expect(
        effectiveScale,
        closeTo(scale, 0.02),
        reason: 'Roster overlay should honor uiTextScale $scale',
      );
      final shotPath = '${out.path}/party_slots_$label.png';
      await _writeShot(tester, shellKey, shotPath);

      final pickerKey = GlobalKey();
      await tester.pumpWidget(
        _rosterFrame(
          key: pickerKey,
          child: SizedBox(
            height: 680,
            child: RosterSlotPickerSheet(
              director: director,
              slotIndex: 2,
              currentHero: director.state.heroes.last,
              onPick: (_) {},
              onUnlock: (_) {},
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 200);
      await _writeShot(
        tester,
        pickerKey,
        '${out.path}/slot_picker_$label.png',
      );
    }

    final director = GameDirector.preview(initialState: baseState);
    addTearDown(director.dispose);

    for (final entry in [
      (0, 'pick_tank'),
      (1, 'pick_healer'),
    ]) {
      final pickerKey = GlobalKey();
      await tester.pumpWidget(
        _rosterFrame(
          key: pickerKey,
          child: SizedBox(
            height: 680,
            child: RosterSlotPickerSheet(
              director: director,
              slotIndex: entry.$1,
              currentHero: PartyRoleSlots.slotHeroes(director.state)[entry.$1],
              onPick: (_) {},
              onUnlock: (_) {},
              onBench: () {},
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 200);
      await _writeShot(
        tester,
        pickerKey,
        '${out.path}/${entry.$2}.png',
      );
    }

    final state = director.state;
    final swapKey = GlobalKey();
    await tester.pumpWidget(
      _rosterFrame(
        key: swapKey,
        child: SizedBox(
          height: 620,
          child: RosterSwapCompareSheet(
            current: _tankA(state),
            incoming: _tankB(state),
            onSwap: () {},
            onKeep: () {},
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 200);
    await _writeShot(tester, swapKey, '${out.path}/swap_compare.png');
  });
}