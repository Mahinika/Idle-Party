import '../models/hero_spec.dart';

/// Original Idle Party art (AI-generated pixel icons/portraits).
/// Prefer these for identity; fall back to Kenney for world tiles.
abstract final class CustomAssets {
  static const String _root = 'assets/custom';

  // —— Pets ——
  static const String petEgg = '$_root/pets/egg.png';
  static const String petEmberPup = '$_root/pets/ember_pup.png';
  static const String petCaveBat = '$_root/pets/cave_bat.png';
  static const String petLootSprite = '$_root/pets/loot_sprite.png';
  static const String petWardenCub = '$_root/pets/warden_cub.png';

  static String petForTemplateId(String templateId) => switch (templateId) {
        'ember_pup' => petEmberPup,
        'cave_bat' => petCaveBat,
        'loot_sprite' => petLootSprite,
        'warden_cub' => petWardenCub,
        'ash_fox' => enemySpider,
        'spark_pup' => enemySlime,
        'spirit_moth' => enemyGhost,
        'xp_wisp' => enemyCrystalMite,
        'shrine_owl' => enemyBat,
        'gold_grub' => enemyRat,
        'coin_imp' => enemyCultist,
        'vault_beetle' => enemyCrystalWraith,
        'mire_toad' => enemyCrab,
        _ => petEgg,
      };

  /// Unique portrait paths used by [petForTemplateId] (preload set).
  static List<String> get petPortraitPaths => const [
        petEmberPup,
        petCaveBat,
        petLootSprite,
        petWardenCub,
        petEgg,
        enemySpider,
        enemySlime,
        enemyGhost,
        enemyCrystalMite,
        enemyBat,
        enemyRat,
        enemyCultist,
        enemyCrystalWraith,
        enemyCrab,
      ];

  /// Pet instance ids look like `ember_pup_12345`.
  /// Combat actors use `classpet_*` / `temppet_*` — map by name theme.
  static String petForInstanceId(String petId) {
    if (petId.startsWith('classpet_') || petId.startsWith('temppet_')) {
      return petForCombatActorId(petId);
    }
    for (final key in const [
      'ember_pup',
      'ash_fox',
      'spark_pup',
      'cave_bat',
      'spirit_moth',
      'xp_wisp',
      'shrine_owl',
      'loot_sprite',
      'gold_grub',
      'coin_imp',
      'vault_beetle',
      'warden_cub',
      'mire_toad',
    ]) {
      if (petId == key || petId.startsWith('${key}_')) {
        return petForTemplateId(key);
      }
    }
    return petEgg;
  }

  /// Class / temp combat pets (`classpet_*`, `temppet_water_*`, …).
  static String petForCombatActorId(String petId, [String? displayName]) {
    final key = '${petId}_${displayName ?? ''}'.toLowerCase();
    if (key.contains('water') || key.contains('elemental')) {
      return enemyCrystalWraith;
    }
    if (key.contains('wolf') ||
        key.contains('spirit') ||
        key.contains('feral')) {
      return petWardenCub;
    }
    if (key.contains('ghoul') ||
        key.contains('army') ||
        key.contains('dead') ||
        key.contains('skel')) {
      return enemyGhost;
    }
    if (key.contains('demon') || key.contains('imp') || key.contains('fel')) {
      return enemySpider;
    }
    if (key.contains('beast') || key.contains('pet') || key.contains('hunter')) {
      return petCaveBat;
    }
    if (key.contains('totem') || key.contains('element')) {
      return enemyGolem;
    }
    return petEmberPup;
  }

  // —— Armor / jewelry slot icons ——
  static const String iconHelm = '$_root/icons/helm.png';
  static const String iconChest = '$_root/icons/chest.png';
  static const String iconCloak = '$_root/icons/cloak.png';
  static const String iconBoots = '$_root/icons/boots.png';
  static const String iconGloves = '$_root/icons/gloves.png';
  static const String iconRing = '$_root/icons/ring.png';
  static const String iconShoulders = '$_root/icons/shoulders.png';
  static const String iconBelt = '$_root/icons/belt.png';
  static const String iconNeck = '$_root/icons/neck.png';
  static const String iconWrist = '$_root/icons/wrist.png';
  static const String iconLegs = '$_root/icons/legs.png';
  static const String iconTrinket = '$_root/icons/trinket.png';
  static const String iconTome = '$_root/icons/tome.png';

  // —— Weapons / off-hand / consumable ——
  static const String iconSword = '$_root/icons/sword.png';
  static const String iconSwordAlt = '$_root/icons/sword_alt.png';
  static const String iconDagger = '$_root/icons/dagger.png';
  static const String iconAxe = '$_root/icons/axe.png';
  static const String iconMace = '$_root/icons/mace.png';
  static const String iconStaff = '$_root/icons/staff.png';
  static const String iconStaffBlue = '$_root/icons/staff_blue.png';
  static const String iconSpear = '$_root/icons/spear.png';
  static const String iconBow = '$_root/icons/bow.png';
  static const String iconCrossbow = '$_root/icons/crossbow.png';
  static const String iconGun = '$_root/icons/gun.png';
  static const String iconWand = '$_root/icons/wand.png';
  static const String iconFist = '$_root/icons/fist.png';
  static const String iconThrown = '$_root/icons/thrown.png';
  static const String iconShield = '$_root/icons/shield.png';
  static const String iconShieldRound = '$_root/icons/shield_round.png';
  static const String iconFlask = '$_root/icons/flask.png';
  static const String iconFlaskGreen = '$_root/icons/flask_green.png';
  static const String iconFlaskBlue = '$_root/icons/flask_blue.png';
  static const String iconFlaskPurple = '$_root/icons/flask_purple.png';
  static const String iconCoinGold = '$_root/icons/coin_gold.png';
  static const String iconBook = '$_root/icons/book.png';
  static const String iconRelicWarBanner = '$_root/icons/relic_war_banner.png';
  static const String iconRelicIronWard = '$_root/icons/relic_iron_ward.png';
  static const String iconRelicPhoenixEmber = '$_root/icons/relic_phoenix_ember.png';
  static const String iconCrown = '$_root/icons/crown.png';
  static const String iconCampfire = '$_root/icons/campfire.png';
  static const String iconTrophy = '$_root/icons/trophy.png';
  static const String iconDoor = '$_root/icons/door.png';
  static const String iconStar = '$_root/icons/star.png';
  static const String iconHeart = '$_root/icons/heart.png';
  static const String iconSkull = '$_root/icons/skull.png';

  // —— Hub dungeon portraits ——
  static const String portraitSandy = '$_root/portraits/sandy.png';
  static const String portraitGoblin = '$_root/portraits/goblin.png';
  static const String portraitKing = '$_root/portraits/king.png';
  static const String portraitUnderworld = '$_root/portraits/underworld.png';
  static const String portraitDead = '$_root/portraits/dead.png';
  static const String portraitHell = '$_root/portraits/hell.png';
  static const String portraitCrystal = '$_root/portraits/crystal.png';
  static const String portraitTide = '$_root/portraits/tide.png';
  static const String portraitEmber = '$_root/portraits/ember.png';
  static const String portraitGrove = '$_root/portraits/grove.png';
  static const String portraitStorm = '$_root/portraits/storm.png';
  static const String portraitRime = '$_root/portraits/rime.png';
  static const String portraitFen = '$_root/portraits/fen.png';
  static const String portraitBrass = '$_root/portraits/brass.png';
  static const String portraitVeil = '$_root/portraits/veil.png';

  static String dungeonPortrait(String dungeonId) => switch (dungeonId) {
        'sandy' => portraitSandy,
        'goblin' => portraitGoblin,
        'king' => portraitKing,
        'underworld' => portraitUnderworld,
        'dead' => portraitDead,
        'hell' => portraitHell,
        'crystal' => portraitCrystal,
        'tide' => portraitTide,
        'ember' => portraitEmber,
        'grove' => portraitGrove,
        'storm' => portraitStorm,
        'rime' => portraitRime,
        'fen' => portraitFen,
        'brass' => portraitBrass,
        'veil' => portraitVeil,
        _ => portraitSandy,
      };

  // —— Intro / hub / dungeon painted scenes ——
  static const String introLogo = '$_root/ui/intro_logo.png';
  /// Full-bleed cold-start scene (party facing into the cave).
  static const String introScene = '$_root/ui/intro_scene.png';
  /// Hub keep / gate plaza behind translucent chrome.
  static const String hubScene = '$_root/ui/hub_scene.png';
  /// Scrollable World Path campaign map (portrait).
  static const String worldPathMap = '$_root/ui/world_path_map.png';
  /// Generic combat stage backdrop (fallback).
  static const String dungeonBackdrop = '$_root/ui/dungeon_backdrop.png';

  static const String backdropSandy = '$_root/ui/backdrops/sandy.png';
  static const String backdropGoblin = '$_root/ui/backdrops/goblin.png';
  static const String backdropKing = '$_root/ui/backdrops/king.png';
  static const String backdropUnderworld = '$_root/ui/backdrops/underworld.png';
  static const String backdropDead = '$_root/ui/backdrops/dead.png';
  static const String backdropHell = '$_root/ui/backdrops/hell.png';
  static const String backdropCrystal = '$_root/ui/backdrops/crystal.png';
  /// Owned Tidehold chamber (teal pressure + silt — not Underworld twin).
  static const String backdropTide = '$_root/ui/backdrops/tide.png';
  /// Owned Ashen Vault chamber (cooled ember — not Dead/Hell twin).
  static const String backdropEmber = '$_root/ui/backdrops/ember.png';
  /// Owned Hollow Grove chamber (roots + moss — not Sandy twin).
  static const String backdropGrove = '$_root/ui/backdrops/grove.png';
  /// Owned Stormwake Hollow arena (violet storm).
  static const String backdropStorm = '$_root/ui/backdrops/storm.png';
  /// Owned Rimeglass Rift chamber (cyan ice — quiet after the gale).
  static const String backdropRime = '$_root/ui/backdrops/rime.png';
  /// Owned Blightfen Mire chamber (bile swamp — not Grove/Tide twin).
  static const String backdropFen = '$_root/ui/backdrops/fen.png';
  /// Owned Brassvault Deep chamber (gold clockwork — not Fen/Ember twin).
  static const String backdropBrass = '$_root/ui/backdrops/brass.png';
  /// Owned Mothveil Hollow chamber (lilac silk-dust — not Brass/Storm twin).
  static const String backdropVeil = '$_root/ui/backdrops/veil.png';

  static String dungeonBackdropFor(String dungeonId) => switch (dungeonId) {
        'sandy' => backdropSandy,
        'goblin' => backdropGoblin,
        'king' => backdropKing,
        'underworld' => backdropUnderworld,
        'dead' => backdropDead,
        'hell' => backdropHell,
        'crystal' => backdropCrystal,
        'tide' => backdropTide,
        'ember' => backdropEmber,
        'grove' => backdropGrove,
        'storm' => backdropStorm,
        'rime' => backdropRime,
        'fen' => backdropFen,
        'brass' => backdropBrass,
        'veil' => backdropVeil,
        _ => dungeonBackdrop,
      };

  // —— Party heroes (intro-matched pixel style) ——
  static const String heroKnight = '$_root/heroes/knight.png';
  static const String heroHealer = '$_root/heroes/healer.png';
  static const String heroWizard = '$_root/heroes/wizard.png';
  static const String heroRogue = '$_root/heroes/rogue.png';
  static const String heroPaladin = '$_root/heroes/paladin.png';
  static const String heroHunter = '$_root/heroes/hunter.png';
  static const String heroDeathKnight = '$_root/heroes/deathknight.png';
  static const String heroShaman = '$_root/heroes/shaman.png';
  static const String heroWarlock = '$_root/heroes/warlock.png';
  static const String heroDruid = '$_root/heroes/druid.png';

  static String heroForClass(HeroClassId classId) => switch (classId) {
        HeroClassId.warrior => heroKnight,
        HeroClassId.paladin => heroPaladin,
        HeroClassId.hunter => heroHunter,
        HeroClassId.rogue => heroRogue,
        HeroClassId.priest => heroHealer,
        HeroClassId.deathKnight => heroDeathKnight,
        HeroClassId.shaman => heroShaman,
        HeroClassId.mage => heroWizard,
        HeroClassId.warlock => heroWarlock,
        HeroClassId.druid => heroDruid,
      };

  // —— Combat enemies / bosses ——
  static const String enemySlime = '$_root/enemies/slime.png';
  static const String enemyRat = '$_root/enemies/rat.png';
  static const String enemyBat = '$_root/enemies/bat.png';
  static const String enemySpider = '$_root/enemies/spider.png';
  static const String enemyGhost = '$_root/enemies/ghost.png';
  static const String enemyCultist = '$_root/enemies/cultist.png';
  static const String enemyCyclops = '$_root/enemies/cyclops.png';
  static const String enemyCrab = '$_root/enemies/crab.png';
  static const String enemyGolem = '$_root/enemies/golem.png';
  static const String enemyBossKing = '$_root/enemies/boss_king.png';
  static const String enemyBossHell = '$_root/enemies/boss_hell.png';
  static const String enemyCrystalBoss = '$_root/enemies/crystal_boss.png';
  static const String enemyCrystalWraith = '$_root/enemies/crystal_wraith.png';
  static const String enemyCrystalMite = '$_root/enemies/crystal_mite.png';
  static const String enemyBossStorm = '$_root/enemies/boss_storm.png';
  static const String enemyStormMite = '$_root/enemies/storm_mite.png';
  static const String enemyBossRime = '$_root/enemies/boss_rime.png';
  static const String enemyRimeMite = '$_root/enemies/rime_mite.png';
  static const String enemyBossFen = '$_root/enemies/boss_fen.png';
  static const String enemyFenMite = '$_root/enemies/fen_mite.png';
  static const String enemyBossBrass = '$_root/enemies/boss_brass.png';
  static const String enemyBrassMite = '$_root/enemies/brass_mite.png';
  static const String enemyBossVeil = '$_root/enemies/boss_veil.png';
  static const String enemyVeilMite = '$_root/enemies/veil_mite.png';
}
