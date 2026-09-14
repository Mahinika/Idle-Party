import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/blessing_constellation.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/god_hand_mastery.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/local_season.dart';
import 'package:idle_party/core/mission_board.dart';
import 'package:idle_party/core/party_power.dart';
import 'package:idle_party/core/ashen_crown.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('endgame bounty ladder extends past 1000', () {
    expect(MissionBoard.bountyTargetsEndgame.last, 25000);
    expect(MissionBoard.bountyRungMax(endgame: true), 5);
    final md = const MetaDepthState(bountyRung: 5);
    expect(md.bountyRung, 5);
  });

  test('month pass ready when monthly KEY met', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      metaDepth: state.metaDepth.copyWith(
        monthPassKey: '2026-08',
        monthlyBestTimedKey: 8,
        claimedMonthGoals: const [],
      ),
    );
    final month = LocalSeasonCatalog.forMonthKey('2026-08');
    expect(LocalSeasonCatalog.monthPassReady(state, month), isTrue);
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.monthGoal);
    expect(chase.urgency, HubChaseUrgency.ready);
    final claimed = GameLogic.claimMonthPass(state);
    expect(
      LocalSeasonCatalog.monthPassReady(claimed, month),
      isFalse,
    );
  });

  test('party power and constellation gate', () {
    final state = GameLogic.createInitialState();
    expect(PartyPower.score(state), greaterThanOrEqualTo(0));
    expect(BlessingConstellation.unlocked(state), isFalse);
    final al20 = state.copyWith(ascensionLevel: GameLogic.maxAscensionLevel);
    expect(BlessingConstellation.unlocked(al20), isTrue);
  });

  test('Ashen Crown week resets tickets', () {
    final state = AshenCrown.ensureWeek(
      GameLogic.createInitialState(),
      now: DateTime.utc(2026, 8, 24),
    );
    expect(state.metaDepth.worldBossTickets, AshenCrown.ticketsPerWeek);
  });

  test('Ashen Crown ticket returns on leave before clear', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      heroes: [
        for (final h in state.heroes)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    state = AshenCrown.ensureWeek(state, now: DateTime.utc(2026, 8, 24));
    expect(state.metaDepth.worldBossTickets, AshenCrown.ticketsPerWeek);
    state = GameLogic.enterAshenCrown(state, practice: false);
    expect(state.inWorldBoss, isTrue);
    expect(state.worldBossPractice, isFalse);
    expect(state.metaDepth.worldBossTickets, AshenCrown.ticketsPerWeek - 1);
    state = GameLogic.leaveDungeon(state);
    expect(state.inWorldBoss, isFalse);
    expect(state.metaDepth.worldBossTickets, AshenCrown.ticketsPerWeek);
    expect(state.metaDepth.worldBossClearedWeek, isFalse);
  });

  test('director Ashen enter builds a spatial floor (not null world)', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 9, 12));
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      heroes: [
        for (final h in state.heroes)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    state = AshenCrown.ensureWeek(state, now: DateTime.utc(2026, 9, 12));
    final director = GameDirector.preview(initialState: state);
    director.enterAshenCrown(practice: true);
    expect(director.state.inWorldBoss, isTrue);
    expect(director.state.inDungeon, isTrue);
    expect(director.spatial, isNotNull);
    expect(director.spatial!.enemies, isNotEmpty);
    expect(director.spatial!.inWorldBoss, isTrue);
  });

  test('Ashen Crown week kit visits a shipped cave, not ember only', () {
    final a = AshenCrown.kitFor(now: DateTime.utc(2026, 8, 24));
    final b = AshenCrown.kitFor(now: DateTime.utc(2026, 8, 31));
    expect(a.dungeonId, isNot(equals(b.dungeonId)));
    expect(
      DungeonCatalog.all.map((d) => d.id),
      containsAll(AshenCrown.weekKits.map((k) => k.dungeonId)),
    );
    expect(
      AshenCrown.weekKits.map((k) => k.telegraph).toSet().length,
      AshenCrown.weekKits.length,
    );
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 24));
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      heroes: [
        for (final h in state.heroes)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    final when = DateTime.utc(2026, 8, 24);
    state = GameLogic.enterAshenCrown(state, practice: true, now: when);
    expect(state.inWorldBoss, isTrue);
    expect(state.dungeonId, AshenCrown.kitFor(now: when).dungeonId);
  });

  test('god hand mastery smash milestone', () {
    var state = GameLogic.createInitialState().copyWith(
      metaDepth: const MetaDepthState(godHandSmashCount: 100),
    );
    expect(GodHandMastery.ready(state, 'gh_smash_100'), isTrue);
    final essenceBefore = state.essence;
    state = GodHandMastery.claim(state, 'gh_smash_100');
    expect(GodHandMastery.ready(state, 'gh_smash_100'), isFalse);
    expect(state.essence, essenceBefore + 12);
    expect(state.metaDepth.titles, contains('Hundred Blows'));
    expect(GodHandMastery.claim(state, 'gh_smash_100').essence, state.essence);
  });

  test('god hand mastery damage and CD claims', () {
    var low = GameLogic.createInitialState().copyWith(godHandLevel: 4);
    expect(GodHandMastery.ready(low, 'gh_dmg_5'), isFalse);
    low = low.copyWith(godHandLevel: 5);
    expect(GodHandMastery.ready(low, 'gh_dmg_5'), isTrue);
    low = GodHandMastery.claim(low, 'gh_dmg_5');
    expect(low.metaDepth.titles, contains('Hand of Embers'));
    expect(GodHandMastery.ready(low, 'gh_dmg_5'), isFalse);

    var cd = GameLogic.createInitialState().copyWith(
      metaDepth: const MetaDepthState(godHandCdLevel: 3),
    );
    expect(GodHandMastery.ready(cd, 'gh_cd_4'), isFalse);
    cd = cd.copyWith(
      metaDepth: cd.metaDepth.copyWith(godHandCdLevel: 4),
    );
    expect(GodHandMastery.ready(cd, 'gh_cd_4'), isTrue);
    cd = GodHandMastery.claim(cd, 'gh_cd_4');
    expect(cd.metaDepth.titles, contains('Swift Smash'));
    expect(GodHandMastery.ready(cd, 'gh_cd_4'), isFalse);
  });

  test('STAR NODES spend, cap, and pre-AL20 point bank', () {
    var early = GameLogic.createInitialState();
    expect(BlessingConstellation.unlocked(early), isFalse);
    early = BlessingConstellation.grantPoints(early, 1);
    expect(early.metaDepth.constellationPointsEarned, 1);
    expect(BlessingConstellation.lightNode(early, 'off_atk'), early);

    var state = GameLogic.createInitialState().copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
    );
    state = BlessingConstellation.ensure(state);
    expect(
      BlessingConstellation.pointsAvailable(state),
      BlessingConstellation.starterPointsAtAl20,
    );
    expect(state.metaDepth.constellationStarterGranted, isTrue);

    state = BlessingConstellation.lightNode(state, 'off_atk');
    expect(BlessingConstellation.isLit(state, 'off_atk'), isTrue);
    expect(BlessingConstellation.atkMul(state), 1.03);
    expect(BlessingConstellation.pointsAvailable(state), 2);
    expect(BlessingConstellation.lightNode(state, 'off_atk'), state);
    expect(BlessingConstellation.lightNode(state, 'nope'), state);
    state = BlessingConstellation.lightNode(state, 'off_crit');
    expect(BlessingConstellation.pointsAvailable(state), 1);
    expect(
      BlessingConstellation.isLit(
        BlessingConstellation.lightNode(state, 'off_boss'),
        'off_boss',
      ),
      isFalse,
    );

    state = BlessingConstellation.grantPoints(state, 20);
    for (final n in BlessingConstellation.nodes) {
      state = BlessingConstellation.lightNode(state, n.$1);
    }
    expect(
      state.metaDepth.constellationNodes.length,
      BlessingConstellation.maxLit,
    );
    final blocked = BlessingConstellation.lightNode(
      state,
      BlessingConstellation.nodes
          .firstWhere((n) => !state.metaDepth.constellationNodes.contains(n.$1))
          .$1,
    );
    expect(blocked.metaDepth.constellationNodes, state.metaDepth.constellationNodes);
  });

  test('Craft Trial enters recommended cave, apex-only sheet, month lock', () {
    final fresh = GameLogic.createInitialState();
    expect(GameLogic.startApexTrial(fresh), fresh);

    var state = _withPartyMaxLevel(fresh);
    expect(GameLogic.endgameUnlocked(state), isTrue);
    final recommended = GameLogic.recommendedDungeonId(state);
    state = GameLogic.startApexTrial(state);
    expect(state.apexTrialActive, isTrue);
    expect(state.inDungeon, isTrue);
    expect(state.dungeonId, recommended);
    expect(state.metaDepth.apexTrialMonthKey, GameLogic.isoMonthKey(DateTime.now().toUtc()));
    expect(GameLogic.startApexTrial(state), state);

    const junk = EquipmentItem(
      id: 'junk_wep',
      name: 'Junk',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      attackBonus: 400,
    );
    const apex = EquipmentItem(
      id: 'apex_wep',
      name: 'Apex',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.legendary,
      attackBonus: 25,
      isApex: true,
    );
    final hero = state.heroes.first.copyWith(
      equipped: {
        EquipmentSlot.weapon: junk,
        EquipmentSlot.chest: apex,
      },
    );
    state = state.copyWith(
      heroes: [hero, ...state.heroes.skip(1)],
    );
    final trialAtk = state.effectiveHeroAttack(hero);
    final fullAtk = state
        .copyWith(apexTrialActive: false)
        .effectiveHeroAttack(hero);
    expect(fullAtk, greaterThan(trialAtk));

    final bossFloor = DungeonGenerator.bossFloorFor(state.ascensionLevel);
    final floor = DungeonGenerator.generateFloor(
      bossFloor,
      ascensionLevel: state.ascensionLevel,
      dungeonId: state.dungeonId,
    );
    expect(floor.first.type, RoomType.boss);
    state = state.copyWith(
      dungeonMode: DungeonMode.push,
      currentRoom: floor.first,
      dungeonFloor: floor,
      enemies: GameLogic.createEnemyGroup(floor.first, dungeonId: state.dungeonId),
    );
    final essenceBefore = state.essence;
    final earnedBefore = state.metaDepth.constellationPointsEarned;
    state = GameLogic.completeCurrentRoom(
      state,
      goldGain: 0,
      skipLootRoll: true,
    );
    expect(state.inDungeon, isFalse);
    expect(state.apexTrialActive, isFalse);
    expect(state.metaDepth.apexTrialCleared, isTrue);
    expect(state.essence, greaterThanOrEqualTo(essenceBefore + 20));
    expect(
      state.metaDepth.constellationPointsEarned,
      earnedBefore + BlessingConstellation.apexTrialPointReward,
    );

    final blocked = GameLogic.startApexTrial(state);
    expect(blocked.inDungeon, isFalse);
    expect(blocked.apexTrialActive, isFalse);

    final nextMonth = GameLogic.startApexTrial(
      state.copyWith(
        metaDepth: state.metaDepth.copyWith(
          apexTrialMonthKey: '2020-01',
          apexTrialCleared: true,
        ),
      ),
    );
    expect(nextMonth.apexTrialActive, isTrue);
    expect(nextMonth.inDungeon, isTrue);
    expect(nextMonth.metaDepth.apexTrialCleared, isFalse);
  });
}

GameState _withPartyMaxLevel(GameState state) => state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      heroes: [
        for (final h in state.heroes)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
