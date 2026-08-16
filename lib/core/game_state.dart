import 'dart:math';

import '../models/combat_ratings.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/gear_loadout.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/meta_depth.dart';
import '../models/mission.dart';
import '../models/pet.dart';
import '../models/vfx_quality.dart';

int _jsonInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

Map<String, int> _jsonStringIntMap(dynamic raw) {
  final out = <String, int>{};
  if (raw is! Map) return out;
  for (final e in raw.entries) {
    out['${e.key}'] = _jsonInt(e.value);
  }
  return out;
}

class GameState {
  const GameState({
    required this.heroRoster,
    required this.activeHeroIds,
    required this.enemies,
    required this.gold,
    this.lifetimeGoldEarned = 0,
    required this.essence,
    required this.bossVictories,
    required this.lastUpdated,
    required this.offlineSecondsRecovered,
    required this.attackBonus,
    required this.defenseBonus,
    required this.vitalityBonus,
    this.moveSpeedBonus = 0,
    this.attackSpeedBonus = 0,
    this.critBonus = 0,
    required this.recentLoot,
    required this.unlockedRelics,
    required this.currentRoom,
    required this.dungeonFloor,
    this.ascensionLevel = 0,
    this.equipped = const <EquipmentSlot, EquipmentItem>{},
    this.missions = const <Mission>[],
    this.gearStash = const <EquipmentItem>[],
    this.dungeonMode = DungeonMode.push,
    this.highestFloorCleared = 0,
    this.highestDungeonCleared = -1,
    this.activePet,
    this.ownedPets = const <Pet>[],
    this.sanctuaryGoldLevel = 0,
    this.sanctuaryPowerLevel = 0,
    this.sanctuaryVitalityLevel = 0,
    this.metaDepth = MetaDepthState.empty,
    this.inDungeon = false,
    this.inGauntlet = false,
    this.dungeonId = 'sandy',
    this.soulboundFragments = 0,
    this.soulboundItem,
    this.craftMaterials = const <String, int>{},
    this.craftPity = const <String, int>{},
    this.apexVault = const <EquipmentItem>[],
    this.godHandLevel = 0,
    this.layoutSeed = 0,
    this.soundMuted = false,
    this.vfxQuality = VfxQuality.full,
    this.autoSellMaxPower = 24,
    this.autoSellMaxRarity = 1,
    this.autoDisassembleMaxIlvl = 24,
    this.autoDisassembleMaxRarity = 2,
    this.rogueUnlocked = false,
    this.seenTips = const <String>[],
    this.loadouts = const <GearLoadout>[],
    this.achievements = const <String>[],
    this.codexEnemies = const <String>[],
    this.codexItems = const <String>[],
    this.challengeBossRush = false,
    this.challengeNoFlask = false,
    this.hardmodeLevel = 0,
    this.keystoneRunActive = false,
    this.keystoneRunLevel = 0,
    this.keystoneTimerMs = 0,
    this.keystoneParMs = 0,
    this.keystoneRunAffixes = const <String>[],
    this.keystoneOutcome = '',
    this.colorblindMode = false,
    this.uiTextScale = 1.0,
    this.lastDailyDate,
    this.dailyClaimed = false,
    this.seenChangelogVersion = '',
  });

  /// All unlocked heroes (bench + active).
  final List<PartyHero> heroRoster;

  /// Ordered ids of the active party (subset of [heroRoster]).
  final List<String> activeHeroIds;

  /// Active party resolved from [activeHeroIds]. Falls back to full roster
  /// when the active list is empty.
  List<PartyHero> get heroes {
    if (activeHeroIds.isEmpty) return heroRoster;
    final byId = <String, PartyHero>{for (final h in heroRoster) h.id: h};
    return [
      for (final id in activeHeroIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  final List<EnemyUnit> enemies;
  final int gold;

  /// Total gold awarded across all runs. Survives Ascend; hard reset clears it.
  final int lifetimeGoldEarned;

  final int essence;
  final int bossVictories;
  final DateTime lastUpdated;
  final int offlineSecondsRecovered;
  final int attackBonus;
  final int defenseBonus;
  final int vitalityBonus;

  /// Forge move-speed points (≈% before soft-cap). Cleared on Ascend.
  final int moveSpeedBonus;

  /// Forge attack-speed points (≈% before soft-cap). Cleared on Ascend.
  final int attackSpeedBonus;

  /// Forge crit-chance points (≈% before soft-cap). Cleared on Ascend.
  final int critBonus;

  final List<LootDrop> recentLoot;
  final List<String> unlockedRelics;
  final DungeonRoom currentRoom;
  final List<DungeonRoom> dungeonFloor;

  /// Persistent meta-progress. Survives Ascend; hard reset clears it.
  final int ascensionLevel;

  /// Legacy party loadout field (pre per-hero gear). Kept for save migration only.
  /// Prefer [PartyHero.equipped]. Cleared after migrate / Ascend.
  final Map<EquipmentSlot, EquipmentItem> equipped;

  /// Up to 3 active contracts. Refreshed on Ascend; claimed slots roll anew.
  final List<Mission> missions;

  /// Inventory / Combinator stash. Cleared on Ascend / hard reset.
  final List<EquipmentItem> gearStash;

  /// Farm loops the floor; Push advances after clear.
  final DungeonMode dungeonMode;

  /// Highest floor whose wave was cleared this run (0 = none yet).
  final int highestFloorCleared;

  /// Highest dungeon catalog index cleared (meta — survives Ascend). -1 = none.
  final int highestDungeonCleared;

  /// Active combat pet (meta — survives Ascend).
  final Pet? activePet;

  /// Owned pets (meta — survives Ascend).
  final List<Pet> ownedPets;

  /// Sanctuary meta upgrades (survive Ascend).
  final int sanctuaryGoldLevel;
  final int sanctuaryPowerLevel;
  final int sanctuaryVitalityLevel;

  /// Meta-depth prestige progress (survives Ascend).
  final MetaDepthState metaDepth;

  /// Hub vs dungeon: combat loop only runs while in dungeon.
  final bool inDungeon;

  /// Infinity Gauntlet run (AL10+ endless climb). Cleared when leaving hub.
  final bool inGauntlet;

  /// Named dungeon id (e.g. sandy).
  final String dungeonId;

  /// Soulbound prestige currency (survives Ascend).
  final int soulboundFragments;

  /// Optional permanent soulbound gear piece (survives Ascend).
  final EquipmentItem? soulboundItem;

  /// Apex crafting Materials Bag (survives Ascend). Never mixed with gear stash.
  final Map<String, int> craftMaterials;

  /// Soft/hard pity dry-streak counters per mat family (survives Ascend).
  final Map<String, int> craftPity;

  /// Unequipped Apex pieces (survives Ascend).
  final List<EquipmentItem> apexVault;

  /// God Hand upgrade level (survives Ascend).
  final int godHandLevel;

  /// Salt for procedural floor layout / encounter rolls (changes each visit).
  final int layoutSeed;

  /// Settings — survive Ascend.
  final bool soundMuted;

  /// Combat VFX detail (full / lite / minimal).
  final VfxQuality vfxQuality;

  /// True when VFX is lite or minimal (spawn gates skip bursts/floaters).
  bool get reducedVfx => vfxQuality.reduced;

  /// Auto-sell *drops on pickup* / bag cleanup when itemLevel ≤ this (0 = off).
  /// Legacy field name — treat as auto-sell max item level. Pays **gold**.
  final int autoSellMaxPower;

  /// Max [LootRarity.index] inclusive for auto-sell gold (0=common … 4=legendary).
  final int autoSellMaxRarity;

  /// Auto-disassemble junk to **essence** when itemLevel ≤ this (0 = off).
  final int autoDisassembleMaxIlvl;

  /// Max [LootRarity.index] inclusive for auto-disassemble.
  final int autoDisassembleMaxRarity;

  /// Fourth hero (Rogue) unlocked after first Ascend.
  final bool rogueUnlocked;

  /// Dismissed first-run tip ids (survives Ascend).
  final List<String> seenTips;

  /// Up to 3 saved gear presets (survives Ascend).
  final List<GearLoadout> loadouts;

  /// Unlocked local achievement ids (survives Ascend / hard reset persists
  /// only via save — no server, purely cosmetic).
  final List<String> achievements;

  /// Discovered enemy display names for the Codex (survives Ascend).
  final List<String> codexEnemies;

  /// Discovered equipment display names for the Codex (survives Ascend).
  final List<String> codexItems;

  /// Challenge toggle: packs skew to elite/boss-heavy mixes. Chosen before
  /// entering a dungeon; survives Ascend as a standing preference.
  final bool challengeBossRush;

  /// Challenge toggle: flasks are disabled entirely.
  final bool challengeNoFlask;

  /// Preferred keystone level 0–20 (0 = normal dungeon). Locked into a run on enter.
  final int hardmodeLevel;

  /// True while inside a keystone dungeon run (not Gauntlet / Daily).
  final bool keystoneRunActive;

  /// Locked key level for the active run.
  final int keystoneRunLevel;

  /// Elapsed run timer (ms); live ticks + offline catch-up.
  final int keystoneTimerMs;

  /// Par time (ms) for a timed clear; idle-friendly.
  final int keystoneParMs;

  /// Affixes locked at run start.
  final List<String> keystoneRunAffixes;

  /// '' | `timed` | `depleted` after boss resolution this run.
  final String keystoneOutcome;

  /// Accessibility: colorblind-friendly combat floater palette.
  final bool colorblindMode;

  /// Accessibility: UI text scale multiplier.
  final double uiTextScale;

  /// Last UTC calendar date (`yyyy-mm-dd`) the Daily Run was entered.
  final String? lastDailyDate;

  /// Whether today's Daily Run reward has already been claimed.
  final bool dailyClaimed;

  /// Highest changelog version the player has seen in Settings → What's New.
  final String seenChangelogVersion;

  /// Global room counter derived from the authoritative room position.
  int get battleNumber => currentRoom.globalBattleNumber;

  bool hasRelic(String relicId) => unlockedRelics.contains(relicId);

  /// Whether [specId] is unlocked for the roster (meta list or already owned).
  bool isSpecUnlocked(HeroSpecId specId) =>
      metaDepth.unlockedSpecs.contains(specId.name) ||
      heroRoster.any((h) => h.specId == specId);

  /// Max active party size (4, or 5 when slot 5 is unlocked).
  int get maxActivePartySize => metaDepth.partySlot5Unlocked ? 5 : 4;

  /// Looks up a roster hero by stable [id].
  PartyHero? rosterHero(String id) {
    for (final h in heroRoster) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Relic tier from meta-depth; owned relics with no tier recorded count as 1.
  int relicTierOf(String relicId) {
    final tier = metaDepth.relicTierOf(relicId);
    if (tier > 0) return tier;
    return hasRelic(relicId) ? 1 : 0;
  }

  int get relicAttackBonus => 4 * relicTierOf('war_banner');

  int get relicDefenseBonus => 2 * relicTierOf('iron_ward');

  int get relicVitalityBonus => 10 * relicTierOf('phoenix_ember');

  /// Flat God Hand damage from the God Hand Focus relic.
  int get relicGodHandDamageBonus => 3 * relicTierOf('god_hand_focus');

  /// Loot-find percent from Chamber Luck relic.
  int get relicLootFindPercent => 5 * relicTierOf('chamber_luck');

  /// Flat incoming damage mitigate from Iron Will relic.
  int get relicMitigateFlat => 1 * relicTierOf('iron_will');

  /// Flat attack from Ascension Level (+1 ATK per AL).
  int get ascensionAttackBonus => ascensionLevel;

  /// Flat defense from Ascension Level (+1 DEF every 2 AL).
  int get ascensionDefenseBonus => ascensionLevel ~/ 2;

  /// Flat vitality from Ascension Level (+2 HP per AL).
  int get ascensionVitalityBonus => ascensionLevel * 2;

  /// Extra gold percent from Ascension Level (+10% per AL).
  int get ascensionGoldBonusPercent => ascensionLevel * 10;

  /// Sanctuary gold find (+5% per level soft-capped, +3% per prestige).
  int get sanctuaryGoldBonusPercent =>
      softForgePercent(sanctuaryGoldLevel * 5, softAt: 100).round() +
      metaDepth.sanctuaryGoldPrestige * 3;

  int get sanctuaryAttackBonus =>
      softForgePercent(sanctuaryPowerLevel, softAt: 40).round() +
      metaDepth.sanctuaryPowerPrestige;

  int get sanctuaryVitalityBonus =>
      softForgePercent(sanctuaryVitalityLevel * 2, softAt: 80).round() +
      metaDepth.sanctuaryVitalityPrestige;

  int get sanctuaryXpBonusPercent =>
      softForgePercent(metaDepth.sanctuaryXpLevel * 4, softAt: 80).round() +
      metaDepth.sanctuaryXpPrestige * 2;

  int get petAttackBonus {
    final pet = activePet;
    if (pet == null) return 0;
    final fav =
        metaDepth.favoritePetSpecies.isNotEmpty &&
        pet.resolvedSpecies == metaDepth.favoritePetSpecies;
    return pet.totalAttackBonus + (fav ? 1 : 0);
  }

  bool get _favoritePetActive =>
      activePet != null &&
      metaDepth.favoritePetSpecies.isNotEmpty &&
      activePet!.resolvedSpecies == metaDepth.favoritePetSpecies;

  int _favoritePassiveBoost(int value) {
    if (!_favoritePetActive || value <= 0) return value;
    final bump = max(1, (value * 5 + 99) ~/ 100); // ceil 5%, min +1
    return value + bump;
  }

  /// Gold-find pets grant percent gold via [Pet.passiveValue].
  int get petGoldFindPercent {
    final pet = activePet;
    if (pet == null || pet.passive != PetPassive.goldFind) return 0;
    return _favoritePassiveBoost(pet.passiveValue(dungeonId: dungeonId));
  }

  /// Loot-find pets grant drop-rate help via [Pet.passiveValue].
  int get petLootFindPercent {
    final pet = activePet;
    if (pet == null || pet.passive != PetPassive.lootFind) {
      return relicLootFindPercent;
    }
    return _favoritePassiveBoost(pet.passiveValue(dungeonId: dungeonId)) +
        relicLootFindPercent;
  }

  /// XP-find pets grant percent XP via [Pet.passiveValue].
  int get petXpFindPercent {
    final pet = activePet;
    if (pet == null || pet.passive != PetPassive.xpFind) return 0;
    return _favoritePassiveBoost(pet.passiveValue(dungeonId: dungeonId));
  }

  /// Mitigate pets grant flat damage reduction via [Pet.passiveValue].
  int get petMitigateFlat {
    final pet = activePet;
    final relic = relicMitigateFlat;
    if (pet == null || pet.passive != PetPassive.mitigate) return relic;
    return _favoritePassiveBoost(pet.passiveValue(dungeonId: dungeonId)) +
        relic;
  }

  /// Heal-boost pets grant heal potency via [Pet.passiveValue].
  int get petHealBoost {
    final pet = activePet;
    if (pet == null || pet.passive != PetPassive.healBoost) return 0;
    return _favoritePassiveBoost(pet.passiveValue(dungeonId: dungeonId));
  }

  /// Soulbound primaries → flat ATK (melee AP path or caster Int+SP/2).
  int get soulboundAttackBonus {
    final item = soulboundItem;
    if (item == null) return 0;
    final meleeAp = 2 * item.strengthBonus + item.agilityBonus;
    final meleeAtk = (meleeAp / CombatRatings.kAp).round();
    final casterAtk = item.intellectBonus + (item.spellPowerBonus ~/ 2);
    return item.attackBonus + max(meleeAtk, casterAtk);
  }

  int get soulboundDefenseBonus {
    final item = soulboundItem;
    if (item == null) return 0;
    return item.resolvedArmor;
  }

  int get soulboundVitalityBonus {
    final item = soulboundItem;
    if (item == null) return 0;
    return item.resolvedStamina * 10;
  }

  int get soulboundRefineBonus => metaDepth.soulboundRefine;

  int get legacyAttackBonus => metaDepth.legacyPoints;

  /// Ascend Blessing pack: +2 ATK per stack.
  int get ascendBlessingAttackBonus => metaDepth.ascendBlessings * 2;

  /// Ascend Blessing pack: +1 DEF per stack.
  int get ascendBlessingDefenseBonus => metaDepth.ascendBlessings;

  /// Ascend Blessing pack: +4 VIT per stack.
  int get ascendBlessingVitalityBonus => metaDepth.ascendBlessings * 4;

  /// Ascend Blessing pack: +3% gold find per stack.
  int get ascendBlessingGoldPercent => metaDepth.ascendBlessings * 3;

  int get torchOfflineGoldPercent => metaDepth.torchKeepLevel * 8;

  /// Heirloom AL bonus applied to ATK when soulbound weapon is set.
  int get heirloomAttackBonus {
    if (soulboundItem == null || metaDepth.soulboundIsArmor) return 0;
    return metaDepth.heirloomAlBonus;
  }

  /// Heirloom AL bonus applied to VIT when soulbound armor is set.
  int get heirloomVitalityBonus {
    if (soulboundItem == null || !metaDepth.soulboundIsArmor) return 0;
    return metaDepth.heirloomAlBonus;
  }

  /// Collection score for Will ranks.
  int get collectionScore =>
      achievements.length * 2 +
      ownedPets.length +
      unlockedRelics.length * 3 +
      (codexEnemies.length + codexItems.length) ~/ 2 +
      metaDepth.zoneTrophies.length * 3 +
      metaDepth.titles.length;

  String get willRankTitle => WillRanks.titleForScore(collectionScore);

  /// Active ascend title, else the latest unlocked title.
  String get displayTitle {
    if (metaDepth.activeTitle.isNotEmpty) return metaDepth.activeTitle;
    if (metaDepth.titles.isNotEmpty) return metaDepth.titles.last;
    return '';
  }

  /// AL-gated keystone cap (0–20). AL0 → 3, grows with Ascension.
  int get effectiveMaxHardmode => min(20, max(2, 3 + ascensionLevel));

  /// Sum of all heroes' gear attack (UI / power checks).
  int get equipmentAttackBonus =>
      heroes.fold<int>(0, (s, h) => s + h.gearAttackBonus) +
      soulboundAttackBonus;

  int get equipmentDefenseBonus =>
      heroes.fold<int>(0, (s, h) => s + h.gearDefenseBonus) +
      soulboundDefenseBonus;

  int get equipmentVitalityBonus =>
      heroes.fold<int>(0, (s, h) => s + h.gearVitalityBonus) +
      soulboundVitalityBonus;

  int get gearGoldFindPercent {
    var pct = heroes.fold<int>(0, (s, h) => s + h.gearGoldFindPercent);
    if (soulboundItem?.effectId == GearEffectId.goldFind) {
      pct += soulboundItem!.effectValue;
    }
    return pct;
  }

  /// Party-wide average-ish lifesteal for legacy UI; prefer per-hero.
  int get gearLifestealPercent {
    if (heroes.isEmpty) return 0;
    final total = heroes.fold<int>(0, (s, h) => s + h.gearLifestealPercent);
    return (total / heroes.length).round();
  }

  bool get gearHasPierce =>
      heroes.any((h) => h.gearHasPierce) ||
      soulboundItem?.effectId == GearEffectId.pierce;

  ProjectilePattern get weaponPattern =>
      heroes.isEmpty ? ProjectilePattern.single : heroes.first.weaponPattern;

  /// Forge / relics / AL / sanctuary / pet / soulbound — not personal gear.
  int get metaAttackBonus =>
      attackBonus +
      relicAttackBonus +
      ascensionAttackBonus +
      sanctuaryAttackBonus +
      petAttackBonus +
      soulboundAttackBonus +
      soulboundRefineBonus +
      legacyAttackBonus +
      heirloomAttackBonus +
      ascendBlessingAttackBonus;

  int get metaDefenseBonus =>
      defenseBonus +
      relicDefenseBonus +
      ascensionDefenseBonus +
      soulboundDefenseBonus +
      soulboundRefineBonus +
      ascendBlessingDefenseBonus;

  int get metaVitalityBonus =>
      vitalityBonus +
      relicVitalityBonus +
      ascensionVitalityBonus +
      sanctuaryVitalityBonus +
      soulboundVitalityBonus +
      heirloomVitalityBonus +
      ascendBlessingVitalityBonus;

  int get totalAttackBonus =>
      metaAttackBonus + heroes.fold<int>(0, (s, h) => s + h.gearAttackBonus);

  int get totalDefenseBonus =>
      metaDefenseBonus + heroes.fold<int>(0, (s, h) => s + h.gearDefenseBonus);

  int get totalVitalityBonus =>
      metaVitalityBonus +
      heroes.fold<int>(0, (s, h) => s + h.gearVitalityBonus);

  int get totalAttack => heroes
      .where((hero) => hero.isAlive)
      .fold<int>(0, (sum, hero) => sum + effectiveHeroAttack(hero));

  int get aliveHeroes => heroes.where((hero) => hero.isAlive).length;

  List<EnemyUnit> get aliveEnemies =>
      enemies.where((enemy) => !enemy.isDefeated).toList();

  bool get areEnemiesDefeated => enemies.every((enemy) => enemy.isDefeated);

  int get partyDefenseBonus => totalDefenseBonus;

  int get partyVitalityBonus => totalVitalityBonus;

  bool get isPartyDefeated => aliveHeroes == 0;

  bool get hasLivingCaster => heroes.any(
    (hero) => hero.isAlive && hero.spec.roleTag == SpecRoleTag.caster,
  );

  bool get hasLivingHealer =>
      heroes.any((hero) => hero.isAlive && hero.spec.isHealer);

  bool get hasLivingTank =>
      heroes.any((hero) => hero.isAlive && hero.spec.isTank);

  /// Max floor the party may enter (cleared + frontier).
  int get maxReachableFloor => max(1, highestFloorCleared + 1);

  /// Caster aura: +15% of caster spell power (min +2) while a caster lives.
  int casterAuraBonusFor(PartyHero hero) {
    if (!hasLivingCaster) {
      return 0;
    }
    PartyHero? caster;
    for (final h in heroes) {
      if (h.isAlive && h.spec.roleTag == SpecRoleTag.caster) {
        caster = h;
        break;
      }
    }
    if (caster == null) return 0;
    final mageSp = caster.grownPrimaries.intel + caster.gearSpellPowerBonus;
    return max(2, (mageSp * 12) ~/ 100);
  }

  /// Tank guard DEF — only true tanks (not Arms/Fury/Ret DPS).
  /// Scales with level so plate stays ahead of leather DPS on the ARMOR sheet.
  int tankGuardBonusFor(PartyHero hero) {
    if (!hero.spec.isTank || !hero.isAlive) return 0;
    return 1 + hero.level;
  }

  /// Healer mend amount per tick (scales lightly with healer level).
  int get healerMendAmount {
    for (final hero in heroes) {
      if (hero.isAlive && hero.spec.isHealer) {
        return 2 + (hero.level ~/ 2);
      }
    }
    return 0;
  }

  EquipmentItem? equippedFor(EquipmentSlot slot) {
    for (final hero in heroes) {
      final item = hero.itemIn(slot);
      if (item != null) return item;
    }
    return equipped[slot];
  }

  EquipmentItem? equippedOn(int heroIndex, EquipmentSlot slot) {
    if (heroIndex < 0 || heroIndex >= heroes.length) return null;
    return heroes[heroIndex].itemIn(slot);
  }

  CombatRatings ratingsFor(PartyHero hero) {
    return CombatRatings.fromHeroSheet(
      hero: hero,
      gearStrength: hero.gearStrengthBonus,
      gearAgility: hero.gearAgilityBonus,
      gearStamina: hero.gearStaminaBonus,
      gearIntellect: hero.gearIntellectBonus,
      gearSpirit: hero.gearSpiritBonus,
      gearSpellPower: hero.gearSpellPowerBonus,
      gearArmor: hero.gearArmorBonus,
      gearCrit: hero.gearCritChance,
      gearFlatAttack: hero.gearAttackBonus,
      metaAttack: metaAttackBonus,
      metaDefense: metaDefenseBonus,
      metaVitality: metaVitalityBonus,
      guardBonus: tankGuardBonusFor(hero),
      auraBonus: casterAuraBonusFor(hero),
    );
  }

  int effectiveHeroAttack(PartyHero hero) => ratingsFor(hero).effectiveAttack;

  int effectiveHeroDefense(PartyHero hero) => ratingsFor(hero).defense;

  int effectiveHeroMaxHp(PartyHero hero) => ratingsFor(hero).maxHp;

  int effectiveHeroCrit(PartyHero hero) {
    final forge = softForgePercent(critBonus, softAt: 25).round();
    return (ratingsFor(hero).critChance + forge).clamp(0, 75);
  }

  int effectiveHeroSpirit(PartyHero hero) => ratingsFor(hero).spirit;

  int effectiveHeroStrength(PartyHero hero) => ratingsFor(hero).strength;

  /// Soft-caps forge % so infinite buys stay useful but don't explode combat.
  static double softForgePercent(int points, {double softAt = 40}) {
    if (points <= 0) return 0;
    final p = points.toDouble();
    if (p <= softAt) return p;
    return softAt + (p - softAt) * 0.35;
  }

  double effectiveHeroAttackSpeed(PartyHero hero) {
    final base = switch (hero.gearAffinity) {
      HeroRole.mage => 1.82,
      HeroRole.rogue => 1.55,
      HeroRole.healer => 1.43,
      HeroRole.warrior => 1.35,
    };
    final pct = hero.gearAttackSpeedBonus + softForgePercent(attackSpeedBonus);
    return base * (1 + pct / 100);
  }

  double effectiveHeroMoveSpeed(PartyHero hero) {
    final base = switch (hero.gearAffinity) {
      HeroRole.rogue => 3.25,
      HeroRole.healer => 3.2,
      HeroRole.warrior => 3.1,
      HeroRole.mage => 3.0,
    };
    final pct = hero.gearMoveSpeedBonus + softForgePercent(moveSpeedBonus);
    return base * (1 + pct / 100);
  }

  /// God Hand AOE radius in tiles.
  double get godHandRadius => 1.8 + (godHandLevel * 0.15);

  /// God Hand base damage before AL/ATK scaling.
  int get godHandBaseDamage => 8 + godHandLevel * 3;

  GameState copyWith({
    List<PartyHero>? heroes,
    List<PartyHero>? heroRoster,
    List<String>? activeHeroIds,
    List<EnemyUnit>? enemies,
    int? gold,
    int? lifetimeGoldEarned,
    int? essence,
    int? bossVictories,
    DateTime? lastUpdated,
    int? offlineSecondsRecovered,
    int? attackBonus,
    int? defenseBonus,
    int? vitalityBonus,
    int? moveSpeedBonus,
    int? attackSpeedBonus,
    int? critBonus,
    List<LootDrop>? recentLoot,
    List<String>? unlockedRelics,
    DungeonRoom? currentRoom,
    List<DungeonRoom>? dungeonFloor,
    int? ascensionLevel,
    Map<EquipmentSlot, EquipmentItem>? equipped,
    List<Mission>? missions,
    List<EquipmentItem>? gearStash,
    DungeonMode? dungeonMode,
    int? highestFloorCleared,
    int? highestDungeonCleared,
    Pet? activePet,
    List<Pet>? ownedPets,
    int? sanctuaryGoldLevel,
    int? sanctuaryPowerLevel,
    int? sanctuaryVitalityLevel,
    MetaDepthState? metaDepth,
    bool? inDungeon,
    bool? inGauntlet,
    String? dungeonId,
    int? soulboundFragments,
    EquipmentItem? soulboundItem,
    Map<String, int>? craftMaterials,
    Map<String, int>? craftPity,
    List<EquipmentItem>? apexVault,
    int? godHandLevel,
    int? layoutSeed,
    bool? soundMuted,
    VfxQuality? vfxQuality,
    bool? reducedVfx,
    int? autoSellMaxPower,
    int? autoSellMaxRarity,
    int? autoDisassembleMaxIlvl,
    int? autoDisassembleMaxRarity,
    bool? rogueUnlocked,
    List<String>? seenTips,
    List<GearLoadout>? loadouts,
    List<String>? achievements,
    List<String>? codexEnemies,
    List<String>? codexItems,
    bool? challengeBossRush,
    bool? challengeNoFlask,
    int? hardmodeLevel,
    bool? keystoneRunActive,
    int? keystoneRunLevel,
    int? keystoneTimerMs,
    int? keystoneParMs,
    List<String>? keystoneRunAffixes,
    String? keystoneOutcome,
    bool? colorblindMode,
    double? uiTextScale,
    String? lastDailyDate,
    bool? dailyClaimed,
    String? seenChangelogVersion,
    bool clearEquipped = false,
    bool clearActivePet = false,
    bool clearSoulboundItem = false,
  }) {
    var nextRoster = heroRoster ?? this.heroRoster;
    var nextActive = activeHeroIds ?? this.activeHeroIds;
    if (heroes != null) {
      nextRoster = _mergeHeroesIntoRoster(nextRoster, heroes);
      nextActive = [for (final h in heroes) h.id];
    }
    return GameState(
      heroRoster: nextRoster,
      activeHeroIds: nextActive,
      enemies: enemies ?? this.enemies,
      gold: gold ?? this.gold,
      lifetimeGoldEarned: lifetimeGoldEarned ?? this.lifetimeGoldEarned,
      essence: essence ?? this.essence,
      bossVictories: bossVictories ?? this.bossVictories,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      offlineSecondsRecovered:
          offlineSecondsRecovered ?? this.offlineSecondsRecovered,
      attackBonus: attackBonus ?? this.attackBonus,
      defenseBonus: defenseBonus ?? this.defenseBonus,
      vitalityBonus: vitalityBonus ?? this.vitalityBonus,
      moveSpeedBonus: moveSpeedBonus ?? this.moveSpeedBonus,
      attackSpeedBonus: attackSpeedBonus ?? this.attackSpeedBonus,
      critBonus: critBonus ?? this.critBonus,
      recentLoot: recentLoot ?? this.recentLoot,
      unlockedRelics: unlockedRelics ?? this.unlockedRelics,
      currentRoom: currentRoom ?? this.currentRoom,
      dungeonFloor: dungeonFloor ?? this.dungeonFloor,
      ascensionLevel: ascensionLevel ?? this.ascensionLevel,
      equipped: clearEquipped
          ? const <EquipmentSlot, EquipmentItem>{}
          : (equipped ?? this.equipped),
      missions: missions ?? this.missions,
      gearStash: gearStash ?? this.gearStash,
      dungeonMode: dungeonMode ?? this.dungeonMode,
      highestFloorCleared: highestFloorCleared ?? this.highestFloorCleared,
      highestDungeonCleared:
          highestDungeonCleared ?? this.highestDungeonCleared,
      activePet: clearActivePet ? null : (activePet ?? this.activePet),
      ownedPets: ownedPets ?? this.ownedPets,
      sanctuaryGoldLevel: sanctuaryGoldLevel ?? this.sanctuaryGoldLevel,
      sanctuaryPowerLevel: sanctuaryPowerLevel ?? this.sanctuaryPowerLevel,
      sanctuaryVitalityLevel:
          sanctuaryVitalityLevel ?? this.sanctuaryVitalityLevel,
      metaDepth: metaDepth ?? this.metaDepth,
      inDungeon: inDungeon ?? this.inDungeon,
      inGauntlet: inGauntlet ?? this.inGauntlet,
      dungeonId: dungeonId ?? this.dungeonId,
      soulboundFragments: soulboundFragments ?? this.soulboundFragments,
      soulboundItem: clearSoulboundItem
          ? null
          : (soulboundItem ?? this.soulboundItem),
      craftMaterials: craftMaterials ?? this.craftMaterials,
      craftPity: craftPity ?? this.craftPity,
      apexVault: apexVault ?? this.apexVault,
      godHandLevel: godHandLevel ?? this.godHandLevel,
      layoutSeed: layoutSeed ?? this.layoutSeed,
      soundMuted: soundMuted ?? this.soundMuted,
      vfxQuality:
          vfxQuality ??
          (reducedVfx == null
              ? this.vfxQuality
              : (reducedVfx ? VfxQuality.lite : VfxQuality.full)),
      autoSellMaxPower: autoSellMaxPower ?? this.autoSellMaxPower,
      autoSellMaxRarity: autoSellMaxRarity ?? this.autoSellMaxRarity,
      autoDisassembleMaxIlvl:
          autoDisassembleMaxIlvl ?? this.autoDisassembleMaxIlvl,
      autoDisassembleMaxRarity:
          autoDisassembleMaxRarity ?? this.autoDisassembleMaxRarity,
      rogueUnlocked: rogueUnlocked ?? this.rogueUnlocked,
      seenTips: seenTips ?? this.seenTips,
      loadouts: loadouts ?? this.loadouts,
      achievements: achievements ?? this.achievements,
      codexEnemies: codexEnemies ?? this.codexEnemies,
      codexItems: codexItems ?? this.codexItems,
      challengeBossRush: challengeBossRush ?? this.challengeBossRush,
      challengeNoFlask: challengeNoFlask ?? this.challengeNoFlask,
      hardmodeLevel: hardmodeLevel ?? this.hardmodeLevel,
      keystoneRunActive: keystoneRunActive ?? this.keystoneRunActive,
      keystoneRunLevel: keystoneRunLevel ?? this.keystoneRunLevel,
      keystoneTimerMs: keystoneTimerMs ?? this.keystoneTimerMs,
      keystoneParMs: keystoneParMs ?? this.keystoneParMs,
      keystoneRunAffixes: keystoneRunAffixes ?? this.keystoneRunAffixes,
      keystoneOutcome: keystoneOutcome ?? this.keystoneOutcome,
      colorblindMode: colorblindMode ?? this.colorblindMode,
      uiTextScale: uiTextScale ?? this.uiTextScale,
      lastDailyDate: lastDailyDate ?? this.lastDailyDate,
      dailyClaimed: dailyClaimed ?? this.dailyClaimed,
      seenChangelogVersion: seenChangelogVersion ?? this.seenChangelogVersion,
    );
  }

  /// Merges [updates] into [roster] by hero id (order preserved; new ids append).
  static List<PartyHero> _mergeHeroesIntoRoster(
    List<PartyHero> roster,
    List<PartyHero> updates,
  ) {
    final byId = <String, PartyHero>{for (final h in roster) h.id: h};
    for (final h in updates) {
      byId[h.id] = h;
    }
    final seen = <String>{};
    final merged = <PartyHero>[];
    for (final h in roster) {
      merged.add(byId[h.id]!);
      seen.add(h.id);
    }
    for (final h in updates) {
      if (seen.add(h.id)) merged.add(h);
    }
    return merged;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 4,
    'heroRoster': heroRoster.map((hero) => hero.toJson()).toList(),
    'activeHeroIds': activeHeroIds,
    'heroes': heroes.map((hero) => hero.toJson()).toList(),
    'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
    'gold': gold,
    'lifetimeGoldEarned': lifetimeGoldEarned,
    'essence': essence,
    'battleNumber': battleNumber,
    'bossVictories': bossVictories,
    'lastUpdated': lastUpdated.toIso8601String(),
    'offlineSecondsRecovered': offlineSecondsRecovered,
    'attackBonus': attackBonus,
    'defenseBonus': defenseBonus,
    'vitalityBonus': vitalityBonus,
    'moveSpeedBonus': moveSpeedBonus,
    'attackSpeedBonus': attackSpeedBonus,
    'critBonus': critBonus,
    'recentLoot': recentLoot.map((loot) => loot.toJson()).toList(),
    'unlockedRelics': unlockedRelics,
    'currentRoom': currentRoom.toJson(),
    'dungeonFloor': dungeonFloor.map((room) => room.toJson()).toList(),
    'ascensionLevel': ascensionLevel,
    'equipped': equipped.map(
      (slot, item) => MapEntry(slot.name, item.toJson()),
    ),
    'missions': missions.map((mission) => mission.toJson()).toList(),
    'gearStash': gearStash.map((item) => item.toJson()).toList(),
    'dungeonMode': dungeonMode.name,
    'highestFloorCleared': highestFloorCleared,
    'highestDungeonCleared': highestDungeonCleared,
    if (activePet != null) 'activePet': activePet!.toJson(),
    'ownedPets': ownedPets.map((pet) => pet.toJson()).toList(),
    'sanctuaryGoldLevel': sanctuaryGoldLevel,
    'sanctuaryPowerLevel': sanctuaryPowerLevel,
    'sanctuaryVitalityLevel': sanctuaryVitalityLevel,
    'metaDepth': metaDepth.toJson(),
    'inDungeon': inDungeon,
    'inGauntlet': inGauntlet,
    'dungeonId': dungeonId,
    'soulboundFragments': soulboundFragments,
    if (soulboundItem != null) 'soulboundItem': soulboundItem!.toJson(),
    'craftMaterials': craftMaterials,
    'craftPity': craftPity,
    'apexVault': apexVault.map((item) => item.toJson()).toList(),
    'godHandLevel': godHandLevel,
    'layoutSeed': layoutSeed,
    'soundMuted': soundMuted,
    'vfxQuality': vfxQuality.name,
    'reducedVfx': reducedVfx,
    'autoSellMaxPower': autoSellMaxPower,
    'autoSellMaxRarity': autoSellMaxRarity,
    'autoDisassembleMaxIlvl': autoDisassembleMaxIlvl,
    'autoDisassembleMaxRarity': autoDisassembleMaxRarity,
    'rogueUnlocked': rogueUnlocked,
    'seenTips': seenTips,
    'loadouts': loadouts.map((l) => l.toJson()).toList(),
    'achievements': achievements,
    'codexEnemies': codexEnemies,
    'codexItems': codexItems,
    'challengeBossRush': challengeBossRush,
    'challengeNoFlask': challengeNoFlask,
    'hardmodeLevel': hardmodeLevel,
    'keystoneRunActive': keystoneRunActive,
    'keystoneRunLevel': keystoneRunLevel,
    'keystoneTimerMs': keystoneTimerMs,
    'keystoneParMs': keystoneParMs,
    'keystoneRunAffixes': keystoneRunAffixes,
    'keystoneOutcome': keystoneOutcome,
    'colorblindMode': colorblindMode,
    'uiTextScale': uiTextScale,
    if (lastDailyDate != null) 'lastDailyDate': lastDailyDate,
    'dailyClaimed': dailyClaimed,
    'seenChangelogVersion': seenChangelogVersion,
  };

  /// Parses a v2-v4 save. Legacy fields are migrated.
  factory GameState.fromJson(Map<String, dynamic> json) {
    final recentLootJson = json['recentLoot'] as List<dynamic>?;
    final unlockedRelicsJson = json['unlockedRelics'] as List<dynamic>?;
    final missionsJson = json['missions'] as List<dynamic>?;
    final stashJson = json['gearStash'] as List<dynamic>?;
    final petsJson = json['ownedPets'] as List<dynamic>?;
    final activePetJson = json['activePet'] as Map<String, dynamic>?;
    final modeRaw = json['dungeonMode'] as String?;
    final soulboundJson = json['soulboundItem'] as Map<String, dynamic>?;

    final ownedPetsRaw = petsJson == null
        ? <Pet>[]
        : petsJson.cast<Map<String, dynamic>>().map(Pet.fromJson).toList();
    final activePetRaw = activePetJson == null
        ? null
        : Pet.fromJson(activePetJson);
    // Keep active pet in roster (and drop orphan active if roster empty).
    final syncedOwnedPets = activePetRaw == null
        ? ownedPetsRaw
        : ownedPetsRaw.any((p) => p.id == activePetRaw.id)
        ? ownedPetsRaw
        : [...ownedPetsRaw, activePetRaw];
    final syncedActivePet = activePetRaw == null
        ? null
        : () {
            for (final p in syncedOwnedPets) {
              if (p.id == activePetRaw.id) return p;
            }
            return syncedOwnedPets.isEmpty ? null : syncedOwnedPets.first;
          }();

    final equipped = <EquipmentSlot, EquipmentItem>{};
    final equippedJson = json['equipped'] as Map<String, dynamic>?;
    if (equippedJson != null) {
      for (final entry in equippedJson.entries) {
        final slot = EquipmentSlotX.parse(entry.key);
        equipped[slot] = EquipmentItem.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } else {
      // v2: equippedWeapon / equippedArmor
      final weaponJson = json['equippedWeapon'] as Map<String, dynamic>?;
      final armorJson = json['equippedArmor'] as Map<String, dynamic>?;
      if (weaponJson != null) {
        equipped[EquipmentSlot.weapon] = EquipmentItem.fromJson(weaponJson);
      }
      if (armorJson != null) {
        equipped[EquipmentSlot.cloak] = EquipmentItem.fromJson(armorJson);
      }
    }

    var heroes =
        (json['heroes'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(PartyHero.fromJson)
            .toList() ??
        const <PartyHero>[];
    final rosterJson = json['heroRoster'] as List<dynamic>?;
    var heroRoster = rosterJson == null
        ? List<PartyHero>.from(heroes)
        : rosterJson
              .cast<Map<String, dynamic>>()
              .map(PartyHero.fromJson)
              .toList();
    // Migrate legacy party loadout onto first hero without per-hero gear.
    final anyHeroGear = heroRoster.any((h) => h.equipped.isNotEmpty);
    var legacyEquipped = equipped;
    if (!anyHeroGear && equipped.isNotEmpty && heroRoster.isNotEmpty) {
      heroRoster = [
        heroRoster.first.copyWith(
          equipped: Map<EquipmentSlot, EquipmentItem>.from(equipped),
        ),
        ...heroRoster.skip(1),
      ];
      legacyEquipped = const <EquipmentSlot, EquipmentItem>{};
    }

    final activeRaw = json['activeHeroIds'] as List<dynamic>?;
    var activeHeroIds =
        activeRaw?.map((e) => e.toString()).toList() ??
        [for (final h in heroRoster) h.id];
    // Old saves only had `heroes` — treat that list as both roster and active.
    if (rosterJson == null && heroes.isNotEmpty) {
      heroRoster = heroes;
      activeHeroIds = [for (final h in heroes) h.id];
    }

    final rogueUnlocked = (json['rogueUnlocked'] as bool?) ?? false;
    var metaDepth = MetaDepthState.fromJson(
      json['metaDepth'] as Map<String, dynamic>?,
    );
    if (metaDepth.unlockedSpecs.isEmpty) {
      final specs = <String>{
        for (final s in HeroSpecs.starterUnlocked) s.name,
        for (final h in heroRoster) h.specId.name,
        if (rogueUnlocked) HeroSpecId.combat.name,
      };
      metaDepth = metaDepth.copyWith(unlockedSpecs: specs.toList());
    }

    return GameState(
      heroRoster: heroRoster,
      activeHeroIds: activeHeroIds,
      enemies: (json['enemies'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(EnemyUnit.fromJson)
          .toList(),
      gold: _jsonInt(json['gold']),
      lifetimeGoldEarned: _jsonInt(json['lifetimeGoldEarned']),
      essence: _jsonInt(json['essence']),
      bossVictories: _jsonInt(json['bossVictories']),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      offlineSecondsRecovered: _jsonInt(json['offlineSecondsRecovered']),
      attackBonus: _jsonInt(json['attackBonus']),
      defenseBonus: _jsonInt(json['defenseBonus']),
      vitalityBonus: _jsonInt(json['vitalityBonus']),
      moveSpeedBonus: _jsonInt(json['moveSpeedBonus']),
      attackSpeedBonus: _jsonInt(json['attackSpeedBonus']),
      critBonus: _jsonInt(json['critBonus']),
      recentLoot: recentLootJson == null
          ? <LootDrop>[]
          : recentLootJson
                .cast<Map<String, dynamic>>()
                .map(LootDrop.fromJson)
                .toList(),
      unlockedRelics: unlockedRelicsJson == null
          ? <String>[]
          : unlockedRelicsJson.cast<String>(),
      currentRoom: DungeonRoom.fromJson(
        json['currentRoom'] as Map<String, dynamic>,
      ),
      dungeonFloor: (json['dungeonFloor'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(DungeonRoom.fromJson)
          .toList(),
      ascensionLevel: _jsonInt(json['ascensionLevel']),
      equipped: legacyEquipped,
      missions: missionsJson == null
          ? <Mission>[]
          : missionsJson
                .cast<Map<String, dynamic>>()
                .map(Mission.fromJson)
                .toList(),
      gearStash: stashJson == null
          ? <EquipmentItem>[]
          : stashJson
                .cast<Map<String, dynamic>>()
                .map(EquipmentItem.fromJson)
                .toList(),
      dungeonMode: modeRaw == null
          ? DungeonMode.push
          : DungeonMode.values.byName(modeRaw),
      highestFloorCleared: _jsonInt(json['highestFloorCleared']),
      highestDungeonCleared: _jsonInt(json['highestDungeonCleared'], -1),
      activePet: syncedActivePet,
      ownedPets: syncedOwnedPets,
      sanctuaryGoldLevel: _jsonInt(json['sanctuaryGoldLevel']),
      sanctuaryPowerLevel: _jsonInt(json['sanctuaryPowerLevel']),
      sanctuaryVitalityLevel: _jsonInt(json['sanctuaryVitalityLevel']),
      metaDepth: metaDepth,
      inDungeon: (json['inDungeon'] as bool?) ?? false,
      inGauntlet: (json['inGauntlet'] as bool?) ?? false,
      dungeonId: (json['dungeonId'] as String?) ?? 'sandy',
      soulboundFragments: _jsonInt(json['soulboundFragments']),
      soulboundItem: soulboundJson == null
          ? null
          : EquipmentItem.fromJson(soulboundJson),
      craftMaterials: _jsonStringIntMap(json['craftMaterials']),
      craftPity: _jsonStringIntMap(json['craftPity']),
      apexVault:
          (json['apexVault'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>()
              .map(EquipmentItem.fromJson)
              .toList() ??
          const <EquipmentItem>[],
      godHandLevel: _jsonInt(json['godHandLevel']),
      layoutSeed: _jsonInt(json['layoutSeed']),
      soundMuted: (json['soundMuted'] as bool?) ?? false,
      vfxQuality: VfxQuality.fromJson(
        json['vfxQuality'],
        legacyReduced: json['reducedVfx'] as bool?,
      ),
      autoSellMaxPower: _jsonInt(json['autoSellMaxPower'], 24),
      autoSellMaxRarity: _jsonInt(json['autoSellMaxRarity'], 1).clamp(0, 4),
      autoDisassembleMaxIlvl: _jsonInt(json['autoDisassembleMaxIlvl'], 24),
      autoDisassembleMaxRarity: _jsonInt(
        json['autoDisassembleMaxRarity'],
        2,
      ).clamp(0, 4),
      rogueUnlocked: rogueUnlocked,
      seenTips:
          (json['seenTips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      loadouts:
          (json['loadouts'] as List<dynamic>?)
              ?.map((e) => GearLoadout.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <GearLoadout>[],
      achievements:
          (json['achievements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      codexEnemies:
          (json['codexEnemies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      codexItems:
          (json['codexItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      challengeBossRush: (json['challengeBossRush'] as bool?) ?? false,
      challengeNoFlask: (json['challengeNoFlask'] as bool?) ?? false,
      hardmodeLevel: ((json['hardmodeLevel'] as num?)?.toInt() ?? 0).clamp(
        0,
        20,
      ),
      keystoneRunActive: (json['keystoneRunActive'] as bool?) ?? false,
      keystoneRunLevel: ((json['keystoneRunLevel'] as num?)?.toInt() ?? 0)
          .clamp(0, 20),
      keystoneTimerMs: max(0, (json['keystoneTimerMs'] as num?)?.toInt() ?? 0),
      keystoneParMs: max(0, (json['keystoneParMs'] as num?)?.toInt() ?? 0),
      keystoneRunAffixes:
          (json['keystoneRunAffixes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      keystoneOutcome: (json['keystoneOutcome'] as String?) ?? '',
      colorblindMode: (json['colorblindMode'] as bool?) ?? false,
      uiTextScale: (json['uiTextScale'] as num?)?.toDouble() ?? 1.0,
      lastDailyDate: json['lastDailyDate'] as String?,
      dailyClaimed: (json['dailyClaimed'] as bool?) ?? false,
      seenChangelogVersion: (json['seenChangelogVersion'] as String?) ?? '',
    );
  }
}
