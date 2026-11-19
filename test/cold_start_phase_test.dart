import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/cold_start_phase.dart';

void main() {
  test('first install opens the start menu', () {
    expect(
      decideColdStartPhase(
        showIntro: true,
        saveRecoveryBlocked: false,
        validSaveCount: 0,
        hasExistingSave: false,
      ),
      ColdStartPhase.startMenu,
    );
  });

  test('one loaded save goes straight to play', () {
    expect(
      decideColdStartPhase(
        showIntro: true,
        saveRecoveryBlocked: false,
        validSaveCount: 1,
        hasExistingSave: true,
      ),
      ColdStartPhase.play,
    );
  });

  test('two saves still open the studio card then the title menu', () {
    expect(
      decideColdStartPhase(
        showIntro: true,
        saveRecoveryBlocked: false,
        validSaveCount: 2,
        hasExistingSave: true,
      ),
      ColdStartPhase.bootIntro,
    );
  });

  test('a single unreadable-or-unloaded save does not auto-enter play', () {
    expect(
      decideColdStartPhase(
        showIntro: true,
        saveRecoveryBlocked: false,
        validSaveCount: 1,
        hasExistingSave: false,
      ),
      ColdStartPhase.bootIntro,
    );
  });

  test('recovery blocks play even when a save exists', () {
    expect(
      decideColdStartPhase(
        showIntro: true,
        saveRecoveryBlocked: true,
        validSaveCount: 1,
        hasExistingSave: true,
      ),
      ColdStartPhase.saveRecovery,
    );
  });

  test('tests that skip the intro land in play', () {
    expect(
      decideColdStartPhase(
        showIntro: false,
        saveRecoveryBlocked: false,
        validSaveCount: 0,
        hasExistingSave: false,
      ),
      ColdStartPhase.play,
    );
  });

  test('recovery still wins when tests skip the intro', () {
    expect(
      decideColdStartPhase(
        showIntro: false,
        saveRecoveryBlocked: true,
        validSaveCount: 1,
        hasExistingSave: false,
      ),
      ColdStartPhase.saveRecovery,
    );
  });
}
