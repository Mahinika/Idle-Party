import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/reinstall_pouch.dart';

void main() {
  test('reinstall pouch marks due and grants once', () {
    var state = GameLogic.createInitialState();
    expect(ReinstallPouch.showOffer(state), isFalse);
    state = ReinstallPouch.markDue(state);
    expect(ReinstallPouch.showOffer(state), isTrue);
    expect(ReinstallPouch.goldAmount(state), 2500);
    state = ReinstallPouch.grant(state);
    expect(ReinstallPouch.showOffer(state), isFalse);
    expect(state.gold, 2500);
    expect(state.metaDepth.reinstallPouchClaimed, isTrue);
  });
}
