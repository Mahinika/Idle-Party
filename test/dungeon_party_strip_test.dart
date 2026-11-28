import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/party_cc_hint.dart';

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
      expect(find.text(hero.shownName), findsWidgets);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a long party name ellipsizes and the level stays full size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 146,
            child: PartyHudSpecLine(
              spec: 'Shadeveil',
              level: 100,
              color: Colors.white,
              extra: 'Stormwolf',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Shadeveil'), findsOneWidget);
    expect(find.text('L100'), findsOneWidget);
    final name = tester.widget<Text>(find.text('Shadeveil'));
    expect(name.data, 'Shadeveil');
    expect(name.overflow, TextOverflow.ellipsis);
    expect(
      find.ancestor(
        of: find.text('Shadeveil'),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('L100'),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home party frame is a horizontal strip without overflow', (
    tester,
  ) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    final entered = GameLogic.enterDungeon(director.state);
    final world = SpatialCombat.build(entered);
    director.debugAttachSpatial(world);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 120,
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
    await tester.pump();
    // Since audit F020 the level hides when it would cut the name, so
    // each hero shows its whole name, and the level wherever it fits.
    final levels = find.textContaining(' L').evaluate().length;
    expect(levels, inInclusiveRange(0, 3));
    for (final h in director.state.heroes) {
      final name = find.text(h.shownName.trim());
      expect(name, findsOneWidget);
      final p = tester.renderObject<RenderParagraph>(name);
      expect(p.didExceedMaxLines, isFalse, reason: h.name);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SLOW chip fits 360x640 at raw text scale 2', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    final entered = GameLogic.enterDungeon(director.state);
    final world = SpatialCombat.build(entered);
    world.heroes.first.attackSlowTimer = 2;
    director.debugAttachSpatial(world);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: PartyCornerHud(
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
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('SLOW hint mentions 65% attack speed', () {
    expect(PartyCcHint.slow, contains('65%'));
  });

  test('party CC chips list root slow and hex', () {
    final actor = SpatialActor(
      id: 'h0',
      name: 'Test',
      team: SpatialTeam.hero,
      x: 0,
      y: 0,
      hp: 100,
      maxHp: 100,
      attack: 10,
      defense: 5,
      moveSpeed: 2,
      attackRange: 1,
      attackCooldown: 1,
    )..rootTimer = 2
      ..attackSlowTimer = 1;
    expect(partyCcChipLabels(actor), ['ROOT', 'SLOW']);
    actor.rootTimer = 0;
    actor.demoShoutTimer = 3;
    expect(partyCcChipLabels(actor), ['SLOW', 'HEX']);
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
