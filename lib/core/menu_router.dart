import 'package:flutter/foundation.dart';



import '../models/loot.dart';

import 'debug_play_log.dart';

import 'game_state.dart';

import 'gear_session.dart';

import 'hub_chase.dart';

import 'menu_alerts.dart';

import 'nav_intent.dart';



/// Top-level menu destinations (flat tab nav). Hub and dungeon share these.

enum MenuRoute { none, gear, gold, shop, essence, key, more, map }



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

  /// True once a player (or a deep link) picked an ESSENCE panel. The hub
  /// lights a tile only then: the default [EssencePanel.tracks] is not a
  /// choice, so a plain nav open lights nothing (audit F004).
  bool _essencePicked = false;

  MoreSection _moreSection = MoreSection.info;

  int _moreInfoPane = 0;

  /// 1 when a home-shell tab is showing a sub-screen (BLESSING, QUESTS).
  int _homeDepth = 0;

  bool _mapEndgame = false;



  MenuRoute get route => _route;

  bool get isOpen => _route != MenuRoute.none;

  GearPanel get gearPanel => _gearPanel;

  GoldPanel get goldPanel => _goldPanel;

  EssencePanel get essencePanel => _essencePanel;

  /// The ESSENCE hub tile to light, or null when no panel was picked.
  EssencePanel? get essenceHubLit => _essencePicked ? _essencePanel : null;

  MoreSection get moreSection => _moreSection;

  int get moreInfoPane => _moreInfoPane;

  int get homeDepth => _homeDepth;

  bool get homeAtSub => _homeDepth > 0;

  /// Home MAP: open on ENDGAME when a wipe or chase asked for the hunts.
  bool get mapEndgame => _mapEndgame;



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

    open(

      intent.route,

      gear: intent.gear,

      gold: intent.goldPanel,

      essence: intent.essencePanel,

      more: intent.more,

      mapEndgame: intent.mapEndgame,

    );

  }



  /// Debug playtest location.

  String get debugWhere => switch (_route) {

    MenuRoute.none => 'closed',

    MenuRoute.gear => 'GEAR/${_gearPanel.name}',

    MenuRoute.gold => 'GOLD/${_goldPanel.name}',

    MenuRoute.shop => 'SHOP',

    MenuRoute.essence => 'ESSENCE/${_essencePanel.name}',

    MenuRoute.key => 'KEY',

    MenuRoute.more => 'MORE/${_moreSection.name}',

    MenuRoute.map => 'MAP',

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

      EssencePanel.keep => 'BLESSING',

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

    MenuRoute.map => 'MAP',

  };



  /// One-line job under the sheet title — same words hub and dungeon.

  String get jobHint => switch (_route) {

    MenuRoute.none => '',

    MenuRoute.gear => switch (_gearPanel) {

      GearPanel.gear => 'Equip the party',

      GearPanel.bag => 'Loot waiting to equip',

      GearPanel.merge => 'Combine same-slot junk',

      GearPanel.roster => 'Meet and swap specializations',

    },

    MenuRoute.gold => switch (_goldPanel) {

      GoldPanel.tracks => 'Train this run · Market',

      GoldPanel.market => 'Flasks · buy upgrades',

    },

    MenuRoute.shop => 'Ad-free, Long Away, and Cinder packs',

    MenuRoute.essence => switch (_essencePanel) {

      EssencePanel.tracks => 'Camp · Blessing',

      EssencePanel.keep => 'What stays after Ascend',

      EssencePanel.relics => 'Embers discover · Cinders vault',

      EssencePanel.pets => 'Hatch and level pets',

    },

    MenuRoute.key => 'Dial and hunts',

    MenuRoute.more => switch (_moreSection) {

      MoreSection.info => 'How the game works',

      MoreSection.settings => 'Sound, display, bag, and account',

      MoreSection.credits => 'Art credits',

      MoreSection.craft => 'Apex gear',

      // A plain line, not five words that look like tabs (audit F075).
      MoreSection.quests => 'Daily goals for gold and essence',

    },

    MenuRoute.map => 'Pick a cave',

  };



  /// Live bag counts so the sheet does not say "waiting" when BiS is empty.

  String jobHintFor(GameState state) {

    if (_route == MenuRoute.gear && _gearPanel == GearPanel.bag) {

      final n = MenuAlerts.bagUpgradeCount(state);

      if (n <= 0) {

        return state.gearStash.isEmpty

            ? 'Loot from fights lands here'

            : 'No upgrades in bag — SELL JUNK or MERGE junk';

      }

      return n == 1

          ? '1 upgrade — EQUIP BEST 1'

          : '$n upgrades — EQUIP BEST $n';

    }

    return jobHint;

  }



  void open(

    MenuRoute route, {

    GearPanel? gear,

    GoldPanel? gold,

    EssencePanel? essence,

    MoreSection? more,

    int? infoPane,

    bool mapEndgame = false,

    bool closeOnBack = false,

  }) {

    final before = debugWhere;

    if (gear != null) _gearPanel = gear;

    if (gold != null) _goldPanel = gold;

    if (essence != null) _essencePanel = essence;

    if (more != null) _moreSection = more;

    if (route == MenuRoute.more) _moreInfoPane = infoPane ?? 0;

    _mapEndgame = route == MenuRoute.map && mapEndgame;

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

    if (route == MenuRoute.essence) {
      if (essence != null) {
        _essencePicked = true;
      } else if (_route != MenuRoute.essence) {
        _essencePicked = false;
      }
    }

    if (route == MenuRoute.more && _route == MenuRoute.none && more == null) {
      _moreSection = MoreSection.info;
    }

    _route = route;

    // A deep link to a MENU section lands on that section, not on the MENU
    // grid one step early (audit F080). BACK still returns to the grid.
    // The town CTA passes [closeOnBack] so Android Back returns to town.
    _homeDepth =
        route == MenuRoute.more && more != null && !closeOnBack ? 1 : 0;

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



  /// One step: leave a sub-screen, or close the tab.
  bool back() {
    if (_homeDepth > 0) {
      _homeDepth = 0;
      if (_route == MenuRoute.more) _moreSection = MoreSection.info;
      notifyListeners();
      return true;
    }
    if (_route != MenuRoute.none) {
      close();
      return true;
    }
    return false;
  }

  /// Home shell: the open tab grows a sub-screen. [back] returns to the tab.
  void pushSub() {
    if (_route == MenuRoute.none || _homeDepth > 0) return;
    _homeDepth = 1;
    notifyListeners();
  }

  void close() {

    if (_route == MenuRoute.none) return;

    final before = debugWhere;

    _route = MenuRoute.none;

    _homeDepth = 0;

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

    if (!_essencePicked) {
      _essencePicked = true;
      if (_essencePanel == panel) notifyListeners();
    }

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



  /// Hub bottom destinations (TT2-style). First slots match dungeon; KEY is a

  /// sixth hub-only slot after MORE when jargon unlocks (dungeon uses LEAVE).

  /// GOLD / SHOP / ESSENCE hide until they mean something.

  static List<MenuRoute> visibleHubTabs(GameState s) => <MenuRoute>[

    MenuRoute.gear,

    if (MenuTabs.showGold(s)) MenuRoute.gold,

    if (MenuTabs.showShop(s)) MenuRoute.shop,

    if (MenuTabs.showCamp(s)) MenuRoute.essence,

    MenuRoute.more,

    if (MenuTabs.showKey(s)) MenuRoute.key,

  ];



  /// Dungeon bar destinations (+ LEAVE in [AppBottomBar] = last slot).

  /// Same gated tabs as hub; KEY stays hub / top-HUD mid-fight.

  /// Fight-first bar. FIGHT is [MenuRoute.none] and is not listed here.
  /// GOLD lives in the upgrade panel. MORE is the top MENU.
  static List<MenuRoute> visibleHomeTabs(GameState s) => <MenuRoute>[
    MenuRoute.gear,
    if (MenuTabs.showCamp(s)) MenuRoute.essence,
    if (MenuTabs.showShop(s)) MenuRoute.shop,
    if (MenuTabs.showGold(s)) MenuRoute.map,
  ];

  static DestinationGraph home(GameState s) =>
      DestinationGraph(destinations: visibleHomeTabs(s));

  static List<MenuRoute> visibleDungeonTabs(GameState s) => <MenuRoute>[

    MenuRoute.gear,

    if (MenuTabs.showGold(s)) MenuRoute.gold,

    if (MenuTabs.showShop(s)) MenuRoute.shop,

    if (MenuTabs.showCamp(s)) MenuRoute.essence,

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



  /// MORE tab rail — same family as GEAR (QUESTS / CRAFT then INFO).

  static List<MoreSection> visibleMoreSections(GameState s) => <MoreSection>[

    ...visibleMoreMetaRows(s),

    MoreSection.info,

    MoreSection.settings,

    MoreSection.credits,

  ];

}

