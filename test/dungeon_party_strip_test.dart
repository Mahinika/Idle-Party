import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';

void main() {
  testWidgets('party strip fits a status chip without an overflow stripe', (
    tester,
  ) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    final entered = GameLogic.enterDungeon(director.state);
    final world = SpatialCombat.build(entered);
    expect(world.heroes, isNotEmpty);
    world.heroes.first.rootTimer = 2;
    director.debugAttachSpatial(world);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: PartyCornerHud(
              director: director,
              selectedHeroIndex: 0,
              onSelectHero: (_) {},
              onOpenEquip: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('ROOT'), findsWidgets);
    for (final hero in director.state.heroes) {
      expect(find.text(hero.name), findsWidgets);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('an empty hero name falls back to the role word', () {
    final hero = PartyHero.starting(
      name: '   ',
      specId: HeroSpecId.protection,
    );
    expect(
      partyStripName(hero, plainEnglish: true),
      hero.displayRoleLabel(plainEnglish: true),
    );
  });
}
