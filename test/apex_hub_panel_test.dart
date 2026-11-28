import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/apex_craft.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/apex_forge_panel.dart';
import 'package:idle_party/ui/theme.dart';

void main() {
  testWidgets('CRAFT sheet is hero then slot then one craft button', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(bossVictories: 1),
    );
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: SingleChildScrollView(
              child: ApexHubPanel(director: director),
            ),
          ),
        ),
      ),
    );

    expect(find.text('HERO'), findsOneWidget);
    expect(find.text('SLOT'), findsOneWidget);
    expect(find.text('RECIPE'), findsOneWidget);
    expect(find.text('CRAFT R1'), findsOneWidget);
    expect(find.text('Max rank 3'), findsOneWidget);
    expect(find.text('Rank 4 unlocks at Ascend 5'), findsOneWidget);
    expect(find.text('MAX RANK'), findsNothing);
    expect(find.text('PARTY GOALS'), findsNothing);
    expect(find.text('FARM TARGET'), findsNothing);
    expect(find.text('CHANGE GOAL'), findsNothing);
    expect(find.text('OWNED R0'), findsNothing);
  });

  testWidgets('MAX RANK shows only at this Ascend cap', (tester) async {
    await _pumpCraft(tester, _craftState());
    expect(find.text('CRAFT R1'), findsOneWidget);
    expect(find.text('MAX RANK'), findsNothing);

    await _pumpCraft(tester, _craftState(pieceRank: 3));
    expect(find.text('MAX RANK'), findsOneWidget);
    expect(find.text('UPGRADE → R4'), findsNothing);
    expect(find.text('Max rank 3'), findsOneWidget);
    expect(find.text('Rank 4 unlocks at Ascend 5'), findsOneWidget);

    await _pumpCraft(tester, _craftState(al: 5, pieceRank: 3));
    expect(find.text('UPGRADE → R4'), findsOneWidget);
    expect(find.text('MAX RANK'), findsNothing);
    expect(find.text('Max rank 4'), findsOneWidget);
    expect(find.text('Rank 5 unlocks at Ascend 10'), findsOneWidget);

    await _pumpCraft(tester, _craftState(al: 20, pieceRank: 7));
    expect(find.text('MAX RANK'), findsOneWidget);
    expect(find.text('Max rank 7'), findsOneWidget);
    expect(find.textContaining('unlocks at'), findsNothing);
  });

  testWidgets('rank hint fits a 360 phone at text scale 1.45', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = GameTheme.typeScaleMax;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpCraft(tester, _craftState(pieceRank: 3), bindView: false);
    expect(tester.takeException(), isNull);
    expect(find.text('Max rank 3'), findsOneWidget);
    expect(find.text('Rank 4 unlocks at Ascend 5'), findsOneWidget);
    expect(find.text('MAX RANK'), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
  });
}

GameState _craftState({int al = 0, int? pieceRank}) {
  final piece = pieceRank == null
      ? null
      : ApexCraft.buildItem(
          classId: HeroClassId.warrior,
          role: SpecRoleTag.tank,
          slot: EquipmentSlot.weapon,
          rank: pieceRank,
          ascensionLevel: al,
        );
  return GameLogic.createInitialState().copyWith(
    bossVictories: 1,
    ascensionLevel: al,
    apexVault: piece == null ? const <EquipmentItem>[] : [piece],
    metaDepth: const MetaDepthState(
      apexCraftClassId: 'warrior',
      apexCraftRoleTag: 'tank',
      apexCraftSlot: 'weapon',
    ),
  );
}

Future<void> _pumpCraft(
  WidgetTester tester,
  GameState state, {
  bool bindView = true,
}) async {
  if (bindView) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final director = GameDirector.preview(initialState: state);
  addTearDown(director.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 640,
          child: SingleChildScrollView(child: ApexHubPanel(director: director)),
        ),
      ),
    ),
  );
  await tester.pump();
}
