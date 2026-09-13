import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/local_reminders.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/story_lore.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/first_session_tips.dart';
import 'package:idle_party/ui/hub/hub_today_card.dart';

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
    expect(chase.progressLabel, 'Boss 0/1');
    expect(chase.progressLabel, isNot(contains('Ascend')));
  });

  test('BASICS / PARTY guides skip WotLK and name the three jobs', () {
    final state = GameLogic.createInitialState(now: now);
    final basics = GameGuides.topicsFor(state).firstWhere((t) => t.id == 'basics');
    expect(basics.body.toUpperCase(), isNot(contains('WOTLK')));
    expect(basics.body.toLowerCase(), contains('shield'));
    expect(basics.body.toLowerCase(), contains('healer'));
    expect(basics.body.toLowerCase(), contains('damage'));
    expect(basics.body.toLowerCase(), contains('enter dungeon'));
    expect(basics.body.toLowerCase(), contains('tap the fight'));
    expect(basics.body.toUpperCase(), isNot(contains('FORGE')));
    expect(basics.body.toUpperCase(), isNot(contains('MARKET')));
    expect(basics.body.toUpperCase(), isNot(contains('ESSENCE')));
    expect(basics.body.toUpperCase(), isNot(contains('PETS')));
    expect(basics.body.toUpperCase(), isNot(contains('KEY')));

    final party = GameGuides.topics.firstWhere((t) => t.id == 'party');
    expect(party.body.toUpperCase(), isNot(contains('WOTLK')));
    expect(party.body.toLowerCase(), contains('shield'));
    expect(party.body.toLowerCase(), contains('healer'));
    expect(party.body.toLowerCase(), contains('damage'));
  });

  test('first-hour guides hide advanced topics', () {
    final state = GameLogic.createInitialState(now: now);
    final early = GameGuides.topicsFor(state);
    final ids = early.map((t) => t.id).toSet();
    expect(ids, containsAll(['basics', 'combat', 'party', 'bag_equip']));
    expect(ids, isNot(contains('god_hand')));
    expect(ids, isNot(contains('powerups')));
    expect(ids, isNot(contains('combinator')));
    expect(ids, isNot(contains('gauntlet')));
    final world = early.firstWhere((t) => t.id == 'world_path');
    expect(world.body.toUpperCase(), isNot(contains('KEY')));
    expect(world.body.toUpperCase(), isNot(contains('ENDGAME')));
    expect(world.body.toUpperCase(), isNot(contains('GAUNTLET')));
  });

  test('first tip points at ENTER DUNGEON, not a menu dictionary', () {
    final tip = FirstSessionTips.tips.first;
    expect(tip.id, 'first_run');
    expect(tip.body.toLowerCase(), contains('enter'));
    expect(tip.body.toLowerCase(), contains('fights'));
    expect(tip.body, isNot(contains('Combat Rogue')));
  });

  test('plain chrome is on for a fresh save', () {
    final state = GameLogic.createInitialState(now: now);
    expect(GameLogic.plainPlayerChrome(state), isTrue);
    expect(GameLogic.plainPlayerChrome(state.copyWith(bossVictories: 1)), isFalse);
    expect(LocalReminders.shouldOfferOptIn(state), isFalse);
  });

  test('first-hour vault ready stays off TODAY until a boss', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    expect(GameLogic.plainPlayerChrome(state), isTrue);
    expect(GameLogic.canClaimDailyVault(state), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.title, contains('Grow the party'));
  });

  test('first-hour bag upgrades stay on the cave, not EQUIP', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      gearStash: [
        EquipmentItem(
          id: 'up_1',
          name: 'Test Blade',
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.epic,
          attackBonus: 40,
          strengthBonus: 30,
          itemLevel: 90,
        ),
      ],
    );
    expect(MenuAlerts.bagUpgradeCount(state), greaterThan(0));
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.detail.toLowerCase(), contains('cave'));
    expect(chase.kind, isNot(HubChaseKind.equipBag));
    expect(chase.kind, isNot(HubChaseKind.marketUpgrade));
  });

  test('first-hour MetaPulse has no KEY crumbs', () {
    final state = GameLogic.createInitialState(now: now);
    final chase = HubChase.forState(state, now: now);
    final crumbs = HubMetaPulse.crumbsFor(
      state: state,
      chaseKind: chase.kind,
      chaseUrgency: chase.urgency,
      now: now,
    );
    expect(crumbs, isEmpty);
    expect(crumbs.join(' ').toUpperCase(), isNot(contains('KEY')));
  });

  test('first-hour bottom bar is GEAR and MORE until unlock', () {
    final fresh = GameLogic.createInitialState(now: now);
    expect(
      MenuRouter.visibleHubTabs(fresh),
      equals(const [MenuRoute.gear, MenuRoute.more]),
    );
    expect(MenuTabs.showShop(fresh), isFalse);
    expect(MenuRouter.visibleHubTabs(fresh.copyWith(highestFloorCleared: 1)),
      contains(MenuRoute.gold),
    );
    expect(MenuTabs.showShop(fresh.copyWith(bossVictories: 1)), isTrue);
  });

  test('after first boss INFO still hides KEY and endgame topics', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
    );
    expect(GameLogic.plainPlayerChrome(state), isFalse);
    expect(GameLogic.endgameUnlocked(state), isFalse);
    final early = GameGuides.topicsFor(state);
    final ids = early.map((t) => t.id).toSet();
    expect(ids, containsAll(['basics', 'world_path', 'ascend', 'dailies']));
    expect(ids, isNot(contains('hardmode')));
    expect(ids, isNot(contains('gauntlet')));
    expect(ids, isNot(contains('rift')));
    expect(ids, isNot(contains('greater_rift')));
    expect(ids, isNot(contains('ashen_crown')));
    expect(ids, isNot(contains('gates')));
    final joined = early.map((t) => t.body).join('\n');
    expect(RegExp(r'\bKEY\b').hasMatch(joined), isFalse);
    expect(joined.toUpperCase(), isNot(contains('GAUNTLET')));
    expect(joined.toUpperCase(), isNot(contains('ENDGAME')));
    final world = early.firstWhere((t) => t.id == 'world_path');
    expect(world.body.toLowerCase(), contains('tidehold'));
    expect(world.body.toLowerCase(), contains('party mean level'));
  });

  test('AL20 INFO shows the endgame-bridge topic before KEY unlocks', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      bossVictories: 1,
      ascensionLevel: GameLogic.maxAscensionLevel,
      heroRoster: [
        for (final h in base.heroRoster) h.copyWith(level: 88, xp: 0),
      ],
    );
    expect(GameLogic.endgameUnlocked(state), isFalse);
    expect(GameGuides.showEndgameBridgeGuides(state), isTrue);
    final ids = GameGuides.topicsFor(state).map((t) => t.id).toSet();
    expect(ids, contains('gates'));
    expect(ids, isNot(contains('hardmode')));
    expect(ids, isNot(contains('gauntlet')));
  });

  test('party max level INFO includes KEY and Gauntlet', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      bossVictories: 1,
      heroRoster: [
        for (final h in base.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    expect(GameLogic.endgameUnlocked(state), isTrue);
    final ids = GameGuides.topicsFor(state).map((t) => t.id).toSet();
    expect(ids, containsAll(['hardmode', 'gauntlet', 'gates', 'ashen_crown']));
  });

  test('after first boss TODAY is one cave today, not Daily Run', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
    );
    expect(GameLogic.showDailyRunOnHub(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.title.toLowerCase(), contains('cave'));
    expect(chase.detail.toUpperCase(), isNot(contains('DAILY RUN')));
  });

  test('What’s New lead is a new-player sentence', () {
    final lead = FirstSessionTips.tips.first.body.toLowerCase();
    expect(lead, contains('fights'));
    final market = FirstSessionTips.tips.firstWhere((t) => t.id == 'market');
    expect(market.body.toUpperCase(), isNot(contains('SELL JUNK')));
  });

  test('first-hour BAG idle copy does not teach ESSENCE', () {
    final fresh = GameLogic.createInitialState(now: now);
    expect(MenuAlerts.bagPanelHint(fresh), isEmpty);
    expect(MenuAlerts.bagPanelHint(fresh).toUpperCase(), isNot(contains('ESSENCE')));
    expect(MenuAlerts.bagStatusLine(fresh), isNot(contains('MERGE')));

    final afterFloor = fresh.copyWith(highestFloorCleared: 1);
    expect(
      MenuAlerts.bagPanelHint(afterFloor).toUpperCase(),
      isNot(contains('ESSENCE')),
    );

    final withEssence = fresh.copyWith(essence: 8, highestFloorCleared: 1);
    expect(MenuTabs.showCamp(withEssence), isTrue);
    expect(MenuAlerts.bagPanelHint(withEssence), isEmpty);
  });
}
