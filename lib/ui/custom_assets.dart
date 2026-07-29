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
        _ => petEgg,
      };

  /// Pet instance ids look like `ember_pup_12345`.
  static String petForInstanceId(String petId) {
    for (final key in const [
      'ember_pup',
      'cave_bat',
      'loot_sprite',
      'warden_cub',
    ]) {
      if (petId == key || petId.startsWith('${key}_')) {
        return petForTemplateId(key);
      }
    }
    return petEgg;
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

  // —— Hub dungeon portraits ——
  static const String portraitSandy = '$_root/portraits/sandy.png';
  static const String portraitGoblin = '$_root/portraits/goblin.png';
  static const String portraitKing = '$_root/portraits/king.png';
  static const String portraitUnderworld = '$_root/portraits/underworld.png';
  static const String portraitDead = '$_root/portraits/dead.png';
  static const String portraitHell = '$_root/portraits/hell.png';
  static const String portraitCrystal = '$_root/portraits/crystal.png';

  static String dungeonPortrait(String dungeonId) => switch (dungeonId) {
        'sandy' => portraitSandy,
        'goblin' => portraitGoblin,
        'king' => portraitKing,
        'underworld' => portraitUnderworld,
        'dead' => portraitDead,
        'hell' => portraitHell,
        'crystal' => portraitCrystal,
        _ => portraitSandy,
      };

  // —— Intro / hub / dungeon painted scenes ——
  static const String introLogo = '$_root/ui/intro_logo.png';
  /// Full-bleed cold-start scene (party facing into the cave).
  static const String introScene = '$_root/ui/intro_scene.png';
  /// Hub keep / gate plaza behind translucent chrome.
  static const String hubScene = '$_root/ui/hub_scene.png';
  /// Generic combat stage backdrop (fallback).
  static const String dungeonBackdrop = '$_root/ui/dungeon_backdrop.png';

  static const String backdropSandy = '$_root/ui/backdrops/sandy.png';
  static const String backdropGoblin = '$_root/ui/backdrops/goblin.png';
  static const String backdropKing = '$_root/ui/backdrops/king.png';
  static const String backdropUnderworld = '$_root/ui/backdrops/underworld.png';
  static const String backdropDead = '$_root/ui/backdrops/dead.png';
  static const String backdropHell = '$_root/ui/backdrops/hell.png';
  static const String backdropCrystal = '$_root/ui/backdrops/crystal.png';

  static String dungeonBackdropFor(String dungeonId) => switch (dungeonId) {
        'sandy' => backdropSandy,
        'goblin' => backdropGoblin,
        'king' => backdropKing,
        'underworld' => backdropUnderworld,
        'dead' => backdropDead,
        'hell' => backdropHell,
        'crystal' => backdropCrystal,
        _ => dungeonBackdrop,
      };

  // —— Party heroes (intro-matched pixel style) ——
  static const String heroKnight = '$_root/heroes/knight.png';
  static const String heroHealer = '$_root/heroes/healer.png';
  static const String heroWizard = '$_root/heroes/wizard.png';
  static const String heroRogue = '$_root/heroes/rogue.png';

  static String heroForIndex(int index) => switch (index) {
        0 => heroKnight,
        1 => heroHealer,
        2 => heroWizard,
        _ => heroRogue,
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
}
