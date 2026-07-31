/// In-game guide copy for More → Guides.
abstract final class GameGuides {
  static const topics = <GuideTopic>[
    GuideTopic(
      id: 'basics',
      title: 'BASICS',
      body:
          'Idle Party is an idle RPG: your party fights in dungeons while you watch and steer.\n\n'
          '• Hub: pick a zone on the World Path, manage gear and meta upgrades.\n'
          '• Dungeon: combat runs automatically. Tap the map to use God Hand.\n'
          '• Gold buys unlocks and market goods. Essence powers permanent meta.\n'
          '• Open MORE for Forge, Sanctuary, Pets, Guides, and more.',
    ),
    GuideTopic(
      id: 'world_path',
      title: 'WORLD PATH',
      body:
          'The hub map lists every dungeon from Sand Caverns to Crystal Spire.\n\n'
          '• Tap an unlocked zone to enter.\n'
          '• Unlock the next zone by clearing the previous boss, or by earning enough lifetime gold.\n'
          '• Locked zones show lifetime gold progress (have / need) on the hub.\n'
          '• Lifetime gold (not wallet gold) counts for gold unlocks.\n'
          '• Boss floor is shown on each node (Boss F n).',
    ),
    GuideTopic(
      id: 'combat',
      title: 'COMBAT',
      body:
          'Each floor is one combat wave on a multi-chamber map.\n\n'
          '• Clear a chamber to open gates into the next.\n'
          '• Pick up ground loot (or wait for auto-timeout), then walk to the stairs.\n'
          '• Boss floors use a special arena.\n'
          '• Party HP bars are bottom-left. Target info is bottom-right.\n'
          '• DPS meter (top-left) shows damage per hero this floor.',
    ),
    GuideTopic(
      id: 'god_hand',
      title: 'GOD HAND',
      body:
          'You are the distant will. Tap the dungeon floor to strike.\n\n'
          '• Deals area damage and briefly steers the party toward the tap.\n'
          '• Cooldown ring is top-right of the dungeon view.\n'
          '• Upgrade God Hand with essence (meta) for more damage.',
    ),
    GuideTopic(
      id: 'farm_push',
      title: 'FARM / PUSH',
      body:
          'Toggle at the top of the dungeon view.\n\n'
          '• FARM: after clearing, loop the same floor for more loot/gold.\n'
          '• PUSH: after clearing, advance to the next floor toward the boss.\n'
          '• Use Floor −1 / +1 in the ⋯ menu to travel when allowed.',
    ),
    GuideTopic(
      id: 'party',
      title: 'PARTY & ABILITIES',
      body:
          'Four heroes with Wrath of the Lich King kits:\n'
          'Warrior (Protection), Disc Priest, Fire Mage, Combat Rogue.\n\n'
          '• Tap a hero in the party HUD to select them and see abilities.\n'
          '• Hover or long-press an ability chip for name, effect, and cooldown.\n'
          '• Long-press a hero to open Equip.\n'
          '• Resources: Rage / Mana / Energy — abilities spend these.\n'
          '• Skills unlock as heroes level (Prot Shockwave, PoM, Living Bomb, '
          'Killing Spree, and more).\n'
          '• Flask button appears when you have a potion; tap to heal the party.',
    ),
    GuideTopic(
      id: 'bag_equip',
      title: 'BAG & EQUIP',
      body:
          'Loot drops on the floor, then goes to your stash (BAG).\n\n'
          '• BAG: view, sell, or equip stash gear.\n'
          '• EQUIP / PARTY: manage each hero’s slots.\n'
          '• Auto-Equip picks clear upgrades.\n'
          '• Auto-sell (Settings) can trash weak drops on pickup.\n'
          '• Compare stats before equipping — iLevel and rarity matter.',
    ),
    GuideTopic(
      id: 'combinator',
      title: 'COMBINATOR',
      body:
          'In the inventory dock, combine two gear pieces into one stronger item.\n\n'
          '• Put two items into the combinator slots, then combine.\n'
          '• Useful for upgrading junk into something wearable.\n'
          '• Soulbound gear follows special rules — check the item text.',
    ),
    GuideTopic(
      id: 'forge',
      title: 'FORGE & RELICS',
      body:
          'MORE → FORGE.\n\n'
          '• Train party power with gold / run resources.\n'
          '• Buy relics that permanently boost combat or economy.\n'
          '• Upgrade relic tiers and respec if you change builds.\n'
          '• Refine soulbound gear and speed God Hand cooldown.\n'
          '• Check “What’s New” / changelog for balance notes.',
    ),
    GuideTopic(
      id: 'sanctuary',
      title: 'SANCTUARY',
      body:
          'MORE → SANCTUARY. Spend essence on permanent tracks.\n\n'
          '• Gold Find, War Altar, Life Well, and Lore Font (XP).\n'
          '• At level 12+, prestige a track for essence and a lasting bonus.\n'
          '• Survives Ascend (meta progress).\n'
          '• Invest early — sanctuary compounds over many runs.',
    ),
    GuideTopic(
      id: 'market',
      title: 'MARKET',
      body:
          'MORE → MARKET.\n\n'
          '• Buy flasks and consumables with gold.\n'
          '• Sell stash junk when the bag is full.\n'
          '• Keep at least one flask for tough floors and bosses.',
    ),
    GuideTopic(
      id: 'pets',
      title: 'BEAST PEN',
      body:
          'MORE → BEAST PEN.\n\n'
          '• Hatch and level pets with essence.\n'
          '• Merge two same-species pets into a higher rarity.\n'
          '• Favorite a species, bond for power, buy portrait frames.\n'
          '• Active pet follows in combat and chips damage.\n'
          '• Pets are meta — they survive Ascend.',
    ),
    GuideTopic(
      id: 'prestige_shop',
      title: 'PRESTIGE SHOP',
      body:
          'MORE → PRESTIGE SHOP (AL-gated).\n\n'
          '• Spend essence on permanent stash slots, pet roster, GH CD, and more.\n'
          '• Purchases survive Ascend.\n'
          '• Unlock higher offerings as Ascension Level rises.',
    ),
    GuideTopic(
      id: 'jobs',
      title: 'JOBS / CONTRACTS',
      body:
          'MORE → JOBS.\n\n'
          '• Complete mission goals (kills, floors, gold, etc.).\n'
          '• Claim rewards when a job shows complete.\n'
          '• Weekly contract: clear 3 times under the week’s modifier, then claim essence.\n'
          '• The MORE button may show JOBS (n) when claims are ready.',
    ),
    GuideTopic(
      id: 'loadouts',
      title: 'GEAR LOADOUTS',
      body:
          'MORE → LOADOUTS.\n\n'
          '• Save up to 3 named gear presets.\n'
          '• Apply a loadout to swap party gear quickly.\n'
          '• Handy when switching Farm vs Push or Hardmode setups.',
    ),
    GuideTopic(
      id: 'hardmode',
      title: 'HARDMODE & CHALLENGES',
      body:
          'Set before entering a dungeon (hub challenge panel).\n\n'
          '• Hardmode +1…+10: huge enemy HP, damage, and pack size.\n'
          '• At HM+10: about 1000% (10×) HP, ATK, and enemy count.\n'
          '• Boss Rush / No Flask: harder clears, extra essence.\n'
          '• Hardmode also pays more gold — high risk, high reward.',
    ),
    GuideTopic(
      id: 'ascend',
      title: 'ASCEND',
      body:
          'Prestige when Ascend unlocks in the hub.\n\n'
          '• Resets run gear, hero levels, stash, and floor progress.\n'
          '• Keeps: essence, relics, sanctuary, pets, soulbound, God Hand, '
          'highest dungeon cleared, lifetime gold.\n'
          '• Grants essence and raises Ascension Level (AL).\n'
          '• AL makes later runs tougher but richer in meta power.',
    ),
    GuideTopic(
      id: 'daily',
      title: 'DAILY RUN',
      body:
          'A daily echo dungeon appears on the hub when available.\n\n'
          '• Clear the required floor(s) for a flat essence reward.\n'
          '• May let you visit a locked zone for the day.\n'
          '• Claim once per day — good free essence.',
    ),
    GuideTopic(
      id: 'codex',
      title: 'CODEX & ACHIEVEMENTS',
      body:
          'MORE → CODEX / ACHIEVEMENTS.\n\n'
          '• Codex records monsters and items you have seen.\n'
          '• Achievements track milestones and grant rewards.\n'
          '• Discovery happens automatically as you play.',
    ),
    GuideTopic(
      id: 'ui',
      title: 'UI TIPS',
      body:
          '• Party frame (bottom-left) shrinks on phones and fades after idle — tap to wake.\n'
          '• DPS meter appears once heroes deal damage.\n'
          '• Settings: text scale, reduced VFX, colorblind floaters, auto-sell.\n'
          '• MORE → GUIDES brings you back here anytime.\n'
          '• Escape / back closes overlays.',
    ),
  ];
}

class GuideTopic {
  const GuideTopic({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;
}
