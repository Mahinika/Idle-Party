import 'package:flutter/foundation.dart';



import '../models/loot.dart';

import 'debug_play_log.dart';

import 'game_state.dart';

import 'gear_session.dart';

import 'hub_chase.dart';

import 'menu_alerts.dart';

import 'nav_intent.dart';



/// Top-level menu destinations (flat tab nav). Hub and dungeon share these.

enum MenuRoute { none, gear, gold, shop, essence, key, more }



/// Local focus inside GEAR (not bottom-nav destinations).

enum GearPanel { gear, bag, merge, roster }



/// Local focus inside GOLD — forge tracks vs gold market.

enum GoldPanel { tracks, market }



/// Local focus inside ESSENCE — lasting essence sinks.

enum EssencePanel { tracks, keep, relics, pets }



/// Rows inside MORE (settings, meta overlays, info).

enum MoreSection {

  info,

  settings,

  credits,

  craft,

  quests,

}



/// Player-facing MORE meta row names.

extension MoreSectionLabel on MoreSection {

  String get rowLabel => switch (this) {

    MoreSection.info => 'INFO',

    MoreSection.settings => 'SETTINGS',

    MoreSection.credits => 'CREDITS',

    MoreSection.craft => 'CRAFT',

    MoreSection.quests => 'QUESTS',

  };



  bool get isMetaOverlay =>

      this == MoreSection.craft || this == MoreSection.quests;

}



/// Primary destinations for the shared bottom bar (hub or dungeon).

class DestinationGraph {

  const DestinationGraph({required this.destinations});



  final List<MenuRoute> destinations;



  int get slotCount => destinations.length;



  static DestinationGraph hub(GameState s) => DestinationGraph(

    destinations: MenuRouter.visibleHubTabs(s),

  );



  static DestinationGraph dungeon(GameState s) => DestinationGraph(

    destinations: MenuRouter.visibleDungeonTabs(s),

  );

}



/// Owns "which menu is open" for the whole game.

class MenuRouter extends ChangeNotifier {

  MenuRouter() {

    session.addListener(notifyListeners);

  }



  final GearSession session = GearSession();



  MenuRoute _route = MenuRoute.none;



  GearPanel _gearPanel = GearPanel.gear;

  GoldPanel _goldPanel = GoldPanel.tracks;

  EssencePanel _essencePanel = EssencePanel.tracks;

  MoreSection _moreSection = MoreSection.info;



  MenuRoute get route => _route;

  bool get isOpen => _route != MenuRoute.none;

  GearPanel get gearPanel => _gearPanel;

  GoldPanel get goldPanel => _goldPanel;

  EssencePanel get essencePanel => _essencePanel;

  MoreSection get moreSection => _moreSection;



  @override

  void dispose() {

    session.dispose();

    super.dispose();

  }



  void _emitNav(String before) {

    if (before != debugWhere) DebugPlayLog.nav(debugWhere);

  }



  /// Apply a typed intent (cross-destination jumps go through here).

  void apply(NavIntent intent) {

    if (intent.scrollBagFilters) session.bumpBagFiltersScroll();

    open(

      intent.route,

      gear: intent.gear,

      gold: intent.goldPanel,

      essence: intent.essencePanel,

      more: intent.more,

    );

  }



  /// BAG -> FILTERS: MORE · SETTINGS, scrolled to bag cleanup controls.

  void openBagFilters() => apply(NavIntent.bagFilters);



  /// Debug playtest location.

  String get debugWhere => switch (_route) {

    MenuRoute.none => 'closed',

    MenuRoute.gear => 'GEAR/${_gearPanel.name}',

    MenuRoute.gold => 'GOLD/${_goldPanel.name}',

    MenuRoute.shop => 'SHOP',

    MenuRoute.essence => 'ESSENCE/${_essencePanel.name}',

    MenuRoute.key => 'KEY',

    MenuRoute.more => 'MORE/${_moreSection.name}',

  };



  String get title => switch (_route) {

    MenuRoute.none => '',

    MenuRoute.gear => switch (_gearPanel) {

      GearPanel.gear => 'GEAR',

      GearPanel.bag => 'BAG',

      GearPanel.merge => 'MERGE',

      GearPanel.roster => 'ROSTER',

    },

    MenuRoute.gold => switch (_goldPanel) {

      GoldPanel.tracks => 'GOLD',

      GoldPanel.market => 'MARKET',

    },

    MenuRoute.shop => 'SHOP',

    MenuRoute.essence => switch (_essencePanel) {

      EssencePanel.tracks => 'ESSENCE',

      EssencePanel.keep => 'KEEP',

      EssencePanel.relics => 'RELICS',

      EssencePanel.pets => 'PETS',

    },

    MenuRoute.key => 'KEY',

    MenuRoute.more => switch (_moreSection) {

      MoreSection.info => 'INFO',

      MoreSection.settings => 'SETTINGS',

      MoreSection.credits => 'CREDITS',

      MoreSection.craft => 'CRAFT',

      MoreSection.quests => 'QUESTS',

    },

  };



  /// One-line job under the sheet title — same words hub and dungeon.

  String get jobHint => switch (_route) {

    MenuRoute.none => '',

    MenuRoute.gear => switch (_gearPanel) {

      GearPanel.gear => 'Equip the party',

      GearPanel.bag => 'Loot waiting to equip',

      GearPanel.merge => 'Combine same-slot junk',

      GearPanel.roster => 'Meet and swap kits',

    },

    MenuRoute.gold => switch (_goldPanel) {

      GoldPanel.tracks => 'Run power bought with gold',

      GoldPanel.market => 'Flasks · bandages · buy upgrades',

    },

    MenuRoute.shop => 'Boosts · ad-free',

    MenuRoute.essence => switch (_essencePanel) {

      EssencePanel.tracks => 'Spend essence on lasting tracks',

      EssencePanel.keep => 'God Hand · Blessing · permanent buys',

      EssencePanel.relics => 'Party auras that keep on Ascend',

      EssencePanel.pets => 'Hatch and level pets',

    },

    MenuRoute.key => 'KEY dial · Gauntlet · Ranked GR · Farm Rift · Ashen',

    MenuRoute.more => switch (_moreSection) {

      MoreSection.info => 'Guides · codex · What\'s New',

      MoreSection.settings => 'Sound · zoom · save',

      MoreSection.credits => 'Art credits',

      MoreSection.craft => 'Any zone shard · Apex that keeps',

      MoreSection.quests => 'Daily · Bounty · Side',

    },

  };



  /// Live bag counts so the sheet does not say "waiting" when BiS is empty.

  String jobHintFor(GameState state) {

    if (_route == MenuRoute.gear && _gearPanel == GearPanel.bag) {

      final n = MenuAlerts.bagUpgradeCount(state);

      if (n <= 0) {

        return state.gearStash.isEmpty

            ? 'Bag empty — farm for drops'

            : 'No BiS upgrades — CLEAN BAG or MERGE junk';

      }

      return n == 1

          ? '1 upgrade waiting — tap EQUIP 1'

          : '$n upgrades waiting — tap EQUIP $n';

    }

    return jobHint;

  }



  void open(

    MenuRoute route, {

    GearPanel? gear,

    GoldPanel? gold,

    EssencePanel? essence,

    MoreSection? more,

  }) {

    final before = debugWhere;

    if (gear != null) _gearPanel = gear;

    if (gold != null) _goldPanel = gold;

    if (essence != null) _essencePanel = essence;

    if (more != null) _moreSection = more;

    if (route == MenuRoute.gear && _route != MenuRoute.gear) {

      session.clearBagSlotFilter();

    }

    if (route == MenuRoute.gold && gold == null && _route != MenuRoute.gold) {

      _goldPanel = GoldPanel.tracks;

    }

    if (route == MenuRoute.essence &&

        essence == null &&

        _route != MenuRoute.essence) {

      _essencePanel = EssencePanel.tracks;

    }

    _route = route;

    _emitNav(before);

    notifyListeners();

  }



  /// Nav taps: tapping the tab you are already on closes the sheet.

  void toggle(MenuRoute route) {

    if (_route == route) {

      close();

      return;

    }

    open(route);

  }



  void toggleGear([GearPanel panel = GearPanel.gear]) {

    if (_route == MenuRoute.gear && _gearPanel == panel) {

      close();

      return;

    }

    open(MenuRoute.gear, gear: panel);

  }



  void close() {

    if (_route == MenuRoute.none) return;

    final before = debugWhere;

    _route = MenuRoute.none;

    session.clearBagSlotFilter();

    _emitNav(before);

    notifyListeners();

  }



  /// Hub chase / offline "open GEAR" with the right panel pre-selected.

  void openForHubChase(GameState state, HubChaseKind kind) {

    switch (kind) {

      case HubChaseKind.meetHero:

        open(

          MenuRoute.gear,

          gear: MenuTabs.showRoster(state) ? GearPanel.roster : GearPanel.gear,

        );

      case HubChaseKind.equipBag:

        open(MenuRoute.gear, gear: GearPanel.bag);

      default:

        open(MenuRoute.gear);

    }

  }



  set gearPanel(GearPanel panel) {

    if (_gearPanel == panel) return;

    final before = debugWhere;

    _gearPanel = panel;

    _emitNav(before);

    notifyListeners();

  }



  set goldPanel(GoldPanel panel) {

    if (_goldPanel == panel) return;

    final before = debugWhere;

    _goldPanel = panel;

    _emitNav(before);

    notifyListeners();

  }



  set essencePanel(EssencePanel panel) {

    if (_essencePanel == panel) return;

    final before = debugWhere;

    _essencePanel = panel;

    _emitNav(before);

    notifyListeners();

  }



  set moreSection(MoreSection section) {

    if (_moreSection == section) return;

    final before = debugWhere;

    _moreSection = section;

    _emitNav(before);

    notifyListeners();

  }



  void browseBagSlot(EquipmentSlot slot) {

    open(

      MenuRoute.gear,

      gear: _gearPanel == GearPanel.gear ? GearPanel.gear : GearPanel.bag,

    );

    session.setBagSlotFilter(slot);

  }



  /// Hub bottom destinations (TT2-style). First five match dungeon; KEY is a

  /// sixth hub-only slot after MORE when jargon unlocks (dungeon uses LEAVE).

  static List<MenuRoute> visibleHubTabs(GameState s) => <MenuRoute>[

    MenuRoute.gear,

    MenuRoute.gold,

    MenuRoute.shop,

    MenuRoute.essence,

    MenuRoute.more,

    if (MenuTabs.showKey(s)) MenuRoute.key,

  ];



  /// Dungeon bar destinations (+ LEAVE in [AppBottomBar] = six slots).

  /// Same five as hub; KEY stays hub / top-HUD mid-fight.

  static List<MenuRoute> visibleDungeonTabs(GameState s) => const <MenuRoute>[

    MenuRoute.gear,

    MenuRoute.gold,

    MenuRoute.shop,

    MenuRoute.essence,

    MenuRoute.more,

  ];



  static List<GearPanel> visibleGearPanels(GameState s) => <GearPanel>[

    GearPanel.gear,

    GearPanel.bag,

    if (MenuTabs.showMerge(s)) GearPanel.merge,

    if (MenuTabs.showRoster(s)) GearPanel.roster,

  ];



  static List<GoldPanel> visibleGoldPanels(GameState s) => const <GoldPanel>[

    GoldPanel.tracks,

    GoldPanel.market,

  ];



  static List<EssencePanel> visibleEssencePanels(GameState s) => <EssencePanel>[

    EssencePanel.tracks,

    if (MenuTabs.showKeep(s)) EssencePanel.keep,

    if (MenuTabs.showRelics(s)) EssencePanel.relics,

    if (MenuTabs.showBeast(s)) EssencePanel.pets,

  ];



  /// Meta rows inside MORE (QUESTS / Craft). Relics live under ESSENCE.

  static List<MoreSection> visibleMoreMetaRows(GameState s) => <MoreSection>[

    if (MenuTabs.showQuests(s)) MoreSection.quests,

    if (MenuTabs.showCraft(s)) MoreSection.craft,

  ];

}

