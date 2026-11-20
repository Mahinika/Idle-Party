import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/gear/gear_upgrade_copy.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/core/game_logic.dart';

void main() {
  test('forgeNextFloorLine names combat stat', () {
    final state = GameDirector.preview().state;
    final line = GearUpgradeCopy.forgeNextFloorLine(
      state,
      PartyUpgradeType.attack,
    );
    expect(line.toLowerCase(), contains('atk'));
    expect(line, contains('next floor'));
  });

  test('spec versus line calls out role change', () {
    final from = HeroSpecs.def(HeroSpecId.protection);
    final to = HeroSpecs.def(HeroSpecId.fire);
    final line = to.versusLine(from);
    expect(line, contains('DPS'));
    expect(line.toLowerCase(), contains('not tank'));
  });

}