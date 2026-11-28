import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/logic_notices.dart';

void main() {
  test('IP-383 LEAVE toast explains a bag merge spend', () async {
    LogicNotices.reset();
    const mergeSpend = 149;
    final now = DateTime.utc(2026, 11, 21);
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: now).copyWith(gold: 500 - mergeSpend),
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    await director.boot();
    LogicNotices.reset();
    LogicNotices.recordAutoMerge(merged: 1, goldSpent: mergeSpend);
    director.leaveDungeon();
    expect(director.state.inDungeon, isFalse);
    expect(director.toast, isNotNull);
    expect(director.toast!.toLowerCase(), contains('merge'));
    expect(director.toast!, contains('$mergeSpend'));
  });
}