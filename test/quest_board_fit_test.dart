import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/kenney_assets.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/mission.dart';
import 'package:idle_party/ui/dungeon_art_warmup.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/jobs_overlay.dart';

/// The quest list area on a 360×780 phone, from the first line of the board
/// down to the sheet edge above the bottom bar (measured on the A56).
const _boardHeight = 544.0;

Mission _mission({
  required String id,
  required String title,
  required MissionType type,
  required int target,
  required int progress,
  required int gold,
  required int essence,
  bool claimed = false,
}) {
  return Mission(
    id: id,
    type: type,
    title: title,
    target: target,
    progress: progress,
    goldReward: gold,
    essenceReward: essence,
    claimed: claimed,
  );
}

void main() {
  test('the floor paint gate does not wait on hero portraits', () {
    final gate = DungeonArtWarmup.paintGate().map((asset) => asset.path).toSet();
    expect(gate, contains(KenneyAssets.stairs));
    expect(gate, contains(KenneyAssets.sword));
    expect(gate, contains(KenneyAssets.vialBlue));
    expect(gate, isNot(contains(KenneyAssets.heroKnight)));
    final heroes = DungeonArtWarmup.heroes().map((asset) => asset.path);
    expect(heroes, contains(KenneyAssets.heroKnight));
    expect(heroes, contains(KenneyAssets.heroHealer));
  });

  testWidgets('a ready contract CLAIM fits above the bottom bar', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        missions: [
          _mission(
            id: 'daily',
            title: 'Daily: Defeat 30',
            type: MissionType.defeatEnemies,
            target: 30,
            progress: 30,
            gold: 271,
            essence: 27,
            claimed: true,
          ),
          _mission(
            id: 'bounty',
            title: 'Bounty 1: Defeat 150',
            type: MissionType.defeatEnemies,
            target: 150,
            progress: 116,
            gold: 348,
            essence: 31,
          ),
          _mission(
            id: 'side',
            title: 'Clear 10 bosses',
            type: MissionType.clearBosses,
            target: 10,
            progress: 2,
            gold: 525,
            essence: 28,
          ),
          _mission(
            id: 'week',
            title: 'Week: Defeat 76 elites',
            type: MissionType.defeatElites,
            target: 76,
            progress: 76,
            gold: 953,
            essence: 36,
            claimed: true,
          ),
          _mission(
            id: 'contract',
            title: 'Contract: Clear 38 floors',
            type: MissionType.clearFloors,
            target: 38,
            progress: 38,
            gold: 853,
            essence: 32,
          ),
        ],
      ),
    );
    addTearDown(director.dispose);

    await tester.binding.setSurfaceSize(const Size(360, _boardHeight));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: _boardHeight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: JobsOverlay(director: director),
          ),
        ),
      ),
    );
    await tester.pump();

    final claim = find.widgetWithText(GameButton, 'CLAIM');
    expect(claim, findsOneWidget);
    final rect = tester.getRect(claim);
    expect(rect.height, greaterThanOrEqualTo(GameTheme.minTouch - 1));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(
      rect.bottom,
      lessThanOrEqualTo(_boardHeight),
      reason: 'CLAIM must be whole above the bar, not sliced to CLAI',
    );
  });
}
