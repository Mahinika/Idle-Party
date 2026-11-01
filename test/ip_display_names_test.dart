import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/changelog.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/local_season.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/hero_anim_state.dart';

void main() {
  test('spec and class ids stay, display names do not', () {
    expect(HeroSpecs.all, hasLength(31));
    expect(HeroClassId.deathKnight.name, 'deathKnight');
    expect(HeroSpecs.def(HeroSpecId.blood).name, 'Graveward');
    expect(HeroSpecs.classLabel(HeroClassId.deathKnight), 'Graveknight');
    expect(HeroSpecs.def(HeroSpecId.retribution).name, 'Sunstrike');
    final hero = GameLogic.createInitialState().heroes.first.copyWith(
      specId: HeroSpecId.blood,
    );
    expect(hero.toJson()['specId'], 'blood');
    expect(PartyHero.fromJson(hero.toJson()).specId, HeroSpecId.blood);
  });

  test('Starhorn, Ashborn, and Dawnsong keep race ids and drop the old picture', () {
    expect(HeroRace.parse('draenei'), HeroRace.draenei);
    expect(HeroRace.parse('bloodelf').label, 'Dawnsong');
    expect(HeroRace.parse('forsaken').label, 'Ashborn');
    expect(HeroRace.parse('undead'), HeroRace.forsaken);
    final hero = GameLogic.createInitialState().heroes.first.copyWith(
      race: HeroRace.bloodElf,
    );
    expect(hero.toJson()['race'], 'bloodElf');
    expect(
      BodyFamilyCatalog.assetFor(hero, HeroAnimKind.idle),
      isNot(contains('bloodelf')),
    );
    expect(
      BodyFamilyCatalog.raceBodyAsset(hero, HeroAnimKind.idle),
      isNull,
    );
  });

  test('Infinity Bound title renames on load and new clears use Spirebound', () {
    expect(LocalSeasonCatalog.gauntletTitles[100], 'Spirebound');
    final base = GameLogic.createInitialState().metaDepth.toJson();
    base['titles'] = ['Infinity Bound', 'Spire Climber'];
    base['activeTitle'] = 'Infinity Bound';
    final loaded = MetaDepthState.fromJson(base);
    expect(loaded.titles, ['Spirebound', 'Spire Climber']);
    expect(loaded.activeTitle, 'Spirebound');
    expect(loaded.toJson()['titles'], isNot(contains('Infinity Bound')));
  });

  test('Frost Rain keeps the blizzard save id', () {
    final def = ClassKits.defFor(AbilityId.blizzard);
    expect(def, isNotNull);
    expect(AbilityId.blizzard.name, 'blizzard');
    expect(def!.name, 'Frost Rain');
    expect(def.shortLabel, 'Hail');
    expect(def.name.toLowerCase(), isNot(contains('blizzard')));
  });

  test('patch notes do not name WoW, Blizzard, or Flame Shock', () {
    final notes = ChangelogCatalog.releases
        .map((release) => release.bullets.join('\n'))
        .join('\n');
    expect(notes, isNot(contains('WoW')));
    expect(notes, isNot(contains('Blizzard')));
    expect(notes, isNot(contains('Flame Shock')));
    expect(notes, isNot(contains('Frost Mage')));
    expect(notes, isNot(contains('WotLK')));
    expect(notes, isNot(contains('Cataclysm')));
    expect(notes.toLowerCase(), isNot(contains('warcraft')));
  });
}
