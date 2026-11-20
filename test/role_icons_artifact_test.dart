import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/meta/roster_panel.dart';
import 'package:idle_party/ui/party_role_icon.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';

import 'shell_golden_harness.dart';

const _artifactDir = '/opt/cursor/artifacts/role-icons';

Future<void> _pumpUntilDolls(WidgetTester tester) async {
  final baseline = HeroDollSprite.pendingLoads;
  await pumpGoldenFrames(tester, ms: 100);
  final sw = Stopwatch()..start();
  var idle = 0;
  while (sw.elapsedMilliseconds < 8000) {
    if (HeroDollSprite.pendingLoads <= baseline) {
      idle++;
      if (idle >= 3) break;
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

Future<void> _writeShot(WidgetTester tester, GlobalKey key, String name) async {
  await settleGoldenImages(tester);
  await _pumpUntilDolls(tester);
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final img = image!;
  final png = await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.png),
  );
  img.dispose();
  final dir = Directory(_artifactDir);
  dir.createSync(recursive: true);
  File('$_artifactDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

GameState _partyState() => GameLogic.enterDungeon(
      GameLogic.createInitialState(
        now: DateTime(2026, 11, 20),
        partySpecs: const [
          HeroSpecId.protection,
          HeroSpecId.discipline,
          HeroSpecId.fire,
        ],
      ),
    );

void main() {
  testWidgets('fight party strip role icons at 1.0 and 1.45', (tester) async {
    final shotKey = GlobalKey();
    for (final scale in [1.0, 1.45]) {
      final director = GameDirector.preview(initialState: _partyState());
      addTearDown(director.dispose);
      director.debugAttachSpatial(SpatialCombat.build(director.state));

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: shotKey,
            child: SizedBox(
              width: 360,
              height: 88,
              child: PartyCornerHud(
                director: director,
                selectedHeroIndex: 0,
                onSelectHero: (_) {},
                onOpenEquip: () {},
                homeRow: true,
              ),
            ),
          ),
        ),
      );
      await pumpGoldenFrames(tester, ms: 300);
      expect(find.text('Tank'), findsNothing);
      expect(find.byKey(PartyRoleIcon.keyFor(PartyRoleBucket.tank)), findsWidgets);
      final suffix = scale == 1.0 ? '1.0' : '1.45';
      await _writeShot(tester, shotKey, 'fight_party_strip_$suffix');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('inn roster header copy', (tester) async {
    final shotKey = GlobalKey();
    final innDirector = GameDirector.preview(
      initialState: _partyState().copyWith(inDungeon: false, ascensionLevel: 1),
    );
    addTearDown(innDirector.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: shotKey,
          child: TeamCompositionOverlay(director: innDirector),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 300);
    expect(find.textContaining('Tap ADD'), findsNothing);
    expect(find.textContaining('Fixed roles: TANK'), findsOneWidget);
    await _writeShot(tester, shotKey, 'inn_roster_header');
  });
}