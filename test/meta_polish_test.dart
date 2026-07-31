import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/game_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('meta spends announce via toast', () async {
    GameAudio.muted = true;
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 7, 30))
          .copyWith(essence: 500, soundMuted: true),
    );
    await director.boot(deferCombatLoop: true);

    director.upgradeGodHand();
    expect(director.toast, contains('God Hand'));
    expect(director.state.godHandLevel, 1);

    director.upgradeSanctuary('gold');
    expect(director.toast, contains('Gold Find'));

    final beforePets = director.state.ownedPets.length;
    director.hatchPet();
    expect(director.state.ownedPets.length, beforePets + 1);
    expect(director.toast, contains('Hatched'));
  });
}
