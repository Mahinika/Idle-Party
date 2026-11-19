import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';

void main() {
  test('fight seam rails list left then right catalog entries', () {
    final town = GameLogic.createInitialState(
      now: DateTime(2026, 11, 4),
    ).copyWith(homeLayout: HomeLayout.home, bossVictories: 1);
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(town),
    );
    addTearDown(director.dispose);
    final entries = FightSeamRails.visibleEntries(director.state, director);
    expect(entries.map((e) => e.id), contains('scrolls'));
    expect(entries.first.id, 'scrolls');
    // Same save in town: no rail, the buildings and MENU take over (F100).
    expect(FightSeamRails.visibleEntries(town, director), isEmpty);
  });
}
