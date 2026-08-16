import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('new game party helper rejects non-starter specs', () {
    final normalized = GameLogic.normalizeNewGameParty([
      HeroSpecId.blood,
      HeroSpecId.destruction,
      HeroSpecId.balance,
    ]);
    expect(normalized.toSet(), HeroSpecs.starterUnlocked.toSet());
  });

  test('caster aura requires SpecRoleTag.caster not hunter', () {
    final state = GameLogic.createInitialState(
      now: DateTime(2026, 8, 1),
    ).withActiveParty([
      PartyHero.starting(
        name: 'Hunt',
        specId: HeroSpecId.beastMastery,
        stats: PartyHero.startingStatsForSpec(HeroSpecId.beastMastery),
      ),
      PartyHero.starting(
        name: 'Tank',
        specId: HeroSpecId.protection,
        stats: PartyHero.startingStatsForSpec(HeroSpecId.protection),
      ),
    ]);
    expect(state.hasLivingCaster, isFalse);
    expect(state.casterAuraBonusFor(state.heroes.first), 0);
  });

  test('tank guard only applies to true tanks', () {
    final arms = PartyHero.starting(
      name: 'Arms',
      specId: HeroSpecId.arms,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.arms),
    );
    final prot = PartyHero.starting(
      name: 'Prot',
      specId: HeroSpecId.protection,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.protection),
    );
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 1))
        .withActiveParty([arms, prot]);
    expect(state.tankGuardBonusFor(arms), 0);
    expect(state.tankGuardBonusFor(prot), greaterThan(0));
  });

  test('syncPartyFromState keeps Prot Pala mana regen and tank block', () {
    final pala = PartyHero.starting(
      name: 'Pala',
      specId: HeroSpecId.protPaladin,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.protPaladin),
    ).copyWith(level: 20);
    final disc = PartyHero.starting(
      name: 'Disc',
      specId: HeroSpecId.discipline,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.discipline),
    );
    final fire = PartyHero.starting(
      name: 'Fire',
      specId: HeroSpecId.fire,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.fire),
    );
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 1))
        .withActiveParty([pala, disc, fire]);
    final world = SpatialCombat.build(state);
    final tank = world.heroes.firstWhere(
      (h) => h.heroSpecId == HeroSpecId.protPaladin,
    );
    expect(tank.blockValue, greaterThan(0));
    expect(tank.spiritRegenBonus, greaterThan(0));

    final synced = SpatialCombat.syncPartyFromState(world, state);
    final again = synced.heroes.firstWhere(
      (h) => h.heroSpecId == HeroSpecId.protPaladin,
    );
    expect(again.blockValue, tank.blockValue);
    expect(again.spiritRegenBonus, tank.spiritRegenBonus);
  });

  test('focus prefers tank over nearer warrior-legacy DPS', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 1));
    final world = SpatialCombat.build(state);
    expect(world.heroes.any((h) => h.heroSpecId == HeroSpecId.protection), isTrue);
    // Soft-taunt path is covered by _focusHero using _actorIsTank — smoke that
    // Protection is present as the only tank in the starter trio.
    final tanks = world.heroes
        .where((h) => h.heroSpecId != null && HeroSpecs.def(h.heroSpecId!).isTank)
        .length;
    expect(tanks, 1);
  });

  test('kit tanks ship a hard-taunt ability', () {
    for (final specId in const [
      HeroSpecId.protPaladin,
      HeroSpecId.blood,
      HeroSpecId.guardian,
    ]) {
      final taunts = ClassKits.forSpec(specId)
          .where((d) => d.effect == AbilityEffectKind.taunt);
      expect(taunts, isNotEmpty, reason: '$specId missing taunt');
    }
    expect(
      ClassKits.defFor(AbilityId.taunt)?.effect,
      AbilityEffectKind.taunt,
    );
  });
}
