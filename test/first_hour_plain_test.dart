import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/first_session_tips.dart';

/// First-hour copy must make sense without WoW / RPG homework.
void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('starter jobs use Shield / Healer / Damage, not tank jargon', () {
    expect(HeroSpecs.def(HeroSpecId.protection).plainRoleLine, contains('Shield'));
    expect(HeroSpecs.def(HeroSpecId.discipline).plainRoleLine, contains('Healer'));
    expect(HeroSpecs.def(HeroSpecId.fire).plainRoleLine, contains('Damage'));
    expect(SpecRoleTag.tank.plainLabel, 'Shield');
    expect(SpecRoleTag.healer.plainLabel, 'Healer');
    expect(SpecRoleTag.meleeDps.plainLabel, 'Damage');
  });

  test('intro never asks for another game or fifteen gates', () {
    expect(StoryLore.introTagline.toLowerCase(), contains('party'));
    expect(StoryLore.introSubline.toLowerCase(), contains('no other game'));
    final intro = StoryLore.introBeats.map((b) => '${b.title} ${b.body}').join(' ');
    expect(intro.toLowerCase(), isNot(contains('fifteen')));
    expect(intro.toLowerCase(), isNot(contains('distant will')));
    expect(intro.toLowerCase(), contains('fight'));
  });

  test('fresh TODAY chase is the cave, not kit teasers', () {
    final state = GameLogic.createInitialState(now: now);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.detail.toLowerCase(), contains('cave'));
    expect(chase.detail.toLowerCase(), contains('fights'));
    expect(chase.detail, isNot(contains('Combat Rogue')));
    expect(chase.detail, isNot(contains('AL1')));
    expect(chase.detail, isNot(contains('Arms')));

    final contract = ChaseContract.fromState(state, now: now);
    expect(contract.ascendTeaser, isNull);
    expect(contract.detail, chase.detail);
  });

  test('BASICS / PARTY guides skip WotLK and name the three jobs', () {
    final basics = GameGuides.topics.firstWhere((t) => t.id == 'basics');
    expect(basics.body.toUpperCase(), isNot(contains('WOTLK')));
    expect(basics.body.toLowerCase(), contains('shield'));
    expect(basics.body.toLowerCase(), contains('healer'));
    expect(basics.body.toLowerCase(), contains('damage'));
    expect(basics.body.toLowerCase(), contains('enter dungeon'));

    final party = GameGuides.topics.firstWhere((t) => t.id == 'party');
    expect(party.body.toUpperCase(), isNot(contains('WOTLK')));
    expect(party.body.toLowerCase(), contains('shield'));
    expect(party.body.toLowerCase(), contains('healer'));
    expect(party.body.toLowerCase(), contains('damage'));
  });

  test('first tip points at ENTER DUNGEON, not a menu dictionary', () {
    final tip = FirstSessionTips.tips.first;
    expect(tip.id, 'first_run');
    expect(tip.body.toLowerCase(), contains('enter'));
    expect(tip.body.toLowerCase(), contains('fights'));
    expect(tip.body, isNot(contains('Combat Rogue')));
  });
}
