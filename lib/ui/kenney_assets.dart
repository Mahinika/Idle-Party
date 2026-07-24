import '../core/game_logic.dart';
import '../models/enemy.dart';
import '../models/loot.dart';

abstract final class KenneyAssets {
  static const String _tiny = 'assets/kenney/tiny_dungeon';
  static const String _ui = 'assets/kenney/ui_adventure';
  static const String _bars = 'assets/kenney/ui_bars';
  static const String _icons = 'assets/kenney/icons';
  static const String _runes = 'assets/kenney/runes';

  // Tiny Dungeon sprites
  static const String floorStone = '$_tiny/floor_stone.png';
  static const String floorDirt = '$_tiny/floor_dirt.png';
  static const String wallStone = '$_tiny/wall_stone.png';
  static const String corridorActive = '$_tiny/corridor_active.png';
  static const String corridorInactive = '$_tiny/corridor_inactive.png';
  static const String doorClosed = '$_tiny/door_closed.png';
  static const String doorOpen = '$_tiny/door_open.png';
  static const String stairsBoss = '$_tiny/stairs_boss.png';
  static const String roomCleared = '$_tiny/room_cleared.png';
  static const String chestClosed = '$_tiny/chest_closed.png';
  static const String chestOpen = '$_tiny/chest_open.png';

  static const String heroKnight = '$_tiny/hero_knight.png';
  static const String heroWizard = '$_tiny/hero_wizard.png';
  static const String heroRogue = '$_tiny/hero_rogue.png';
  static const String heroHealer = '$_tiny/hero_healer.png';

  static const String enemySlime = '$_tiny/enemy_slime.png';
  static const String enemyGolem = '$_tiny/enemy_golem.png';
  static const String enemyBoss = '$_tiny/enemy_boss.png';

  static const String sword = '$_tiny/sword.png';
  static const String shield = '$_tiny/shield.png';
  static const String potionRed = '$_tiny/potion_red.png';
  static const String potionBlue = '$_tiny/potion_blue.png';
  static const String coinGold = '$_tiny/coin_gold.png';
  static const String meat = '$_tiny/meat.png';
  static const String book = '$_tiny/book.png';

  // UI panels & buttons
  static const String panelBrown = '$_ui/panel_brown.png';
  static const String panelBeige = '$_ui/panel_beige.png';
  static const String panelInsetBrown = '$_ui/panelInset_brown.png';
  static const String panelBorder = '$_ui/panel-border-015.png';
  static const String buttonBrown = '$_ui/button_brown.png';
  static const String buttonGrey = '$_ui/button_grey.png';
  static const String buttonRed = '$_ui/button_red.png';
  static const String hexagonBrown = '$_ui/hexagon_brown.png';
  static const String hexagonBrownDark = '$_ui/hexagon_brown_dark.png';

  // Progress bars (rounded, ui_adventure)
  static const String progressGreen = '$_ui/progress_green.png';
  static const String progressGreenBorder = '$_ui/progress_green_border.png';
  static const String progressRed = '$_ui/progress_red.png';
  static const String progressRedBorder = '$_ui/progress_red_border.png';
  static const String progressBlue = '$_ui/progress_blue.png';
  static const String progressBlueBorder = '$_ui/progress_blue_border.png';
  static const String progressWhite = '$_ui/progress_white.png';

  // HP bar segments
  static const String barBackLeft = '$_bars/barBack_horizontalLeft.png';
  static const String barBackMid = '$_bars/barBack_horizontalMid.png';
  static const String barBackRight = '$_bars/barBack_horizontalRight.png';
  static const String barGreenLeft = '$_bars/barGreen_horizontalLeft.png';
  static const String barGreenMid = '$_bars/barGreen_horizontalMid.png';
  static const String barGreenRight = '$_bars/barGreen_horizontalRight.png';
  static const String barRedLeft = '$_bars/barRed_horizontalLeft.png';
  static const String barRedMid = '$_bars/barRed_horizontalMid.png';
  static const String barRedRight = '$_bars/barRed_horizontalRight.png';
  static const String barYellowLeft = '$_bars/barYellow_horizontalLeft.png';
  static const String barYellowMid = '$_bars/barYellow_horizontalMid.png';
  static const String barYellowRight = '$_bars/barYellow_horizontalRight.png';

  // Icons
  static const String iconCoin = '$_icons/coin.png';
  static const String iconSword = '$_icons/sword.png';
  static const String iconCrown = '$_icons/crown.png';
  static const String iconCampfire = '$_icons/campfire.png';
  static const String iconShield = '$_icons/shield_icon.png';
  static const String iconTrophy = '$_icons/trophy.png';
  static const String iconDoor = '$_icons/door.png';
  static const String iconStar = '$_icons/star.png';
  static const String iconHeart = '$_icons/heart.png';
  static const String iconSkull = '$_icons/skull.png';

  // Relics
  static const String relicWarBanner = '$_runes/war_banner.png';
  static const String relicIronWard = '$_runes/iron_ward.png';
  static const String relicPhoenixEmber = '$_runes/phoenix_ember.png';

  static String heroSpriteFor(int index) => switch (index) {
    0 => heroKnight,
    1 => heroHealer,
    2 => heroWizard,
    _ => heroRogue,
  };

  static String heroPortraitFor(int index) => heroSpriteFor(index);

  static String enemySpriteFor(EnemyUnit enemy) => switch (enemy.role) {
    EnemyRole.boss => enemyBoss,
    EnemyRole.elite => enemyGolem,
    EnemyRole.normal => enemySlime,
  };

  static String lootIconFor(LootRarity rarity) => switch (rarity) {
    LootRarity.common => coinGold,
    LootRarity.uncommon => meat,
    LootRarity.rare => potionBlue,
    LootRarity.epic => chestClosed,
  };

  static String equipmentIconFor(EquipmentItem item) => switch (item.slot) {
    EquipmentSlot.weapon => sword,
    EquipmentSlot.armor => shield,
  };

  static String lootDropIconFor(LootDrop drop) {
    final item = drop.equipment;
    if (item != null) {
      return equipmentIconFor(item);
    }
    return lootIconFor(drop.rarity);
  }

  static String relicIconFor(String relicId) => switch (relicId) {
    GameLogic.warBannerRelic => relicWarBanner,
    GameLogic.ironWardRelic => relicIronWard,
    GameLogic.phoenixEmberRelic => relicPhoenixEmber,
    _ => relicWarBanner,
  };

  static String forgeIconFor(String title) {
    final upper = title.toUpperCase();
    if (upper.contains('ATTACK')) {
      return sword;
    }
    if (upper.contains('DEFENSE')) {
      return shield;
    }
    if (upper.contains('VITALITY')) {
      return potionRed;
    }
    if (upper.contains('TRAIN')) {
      return book;
    }
    return meat;
  }
}
