import 'package:flutter/foundation.dart';

import '../models/loot.dart';
import 'debug_play_log.dart';
import 'game_state.dart';
import 'gear_session.dart';
import 'hub_chase.dart';
import 'menu_alerts.dart';
import 'nav_intent.dart';

/// Top-level menu destinations (flat tab nav). Hub and dungeon share these.
enum MenuRoute { none, gear, power, quests, key, more }

/// Local focus inside GEAR (not bottom-nav destinations).
enum GearPanel { gear, bag, merge, roster }

/// Sticky POWER segments (Gold | Shop | Relics | Craft | Essence).
enum PowerSegment { forge, market, relics, craft, camp }

/// Player-facing POWER tab names — everyday English, same the whole game.
extension PowerSegmentLabel on PowerSegment {
  String get tabLabel => switch (this) {
    PowerSegment.forge => 'Gold',
    PowerSegment.market => 'Shop',
    PowerSegment.relics => 'Relics',
    PowerSegment.craft => 'Craft',
    PowerSegment.camp => 'Essence',
  };
}

/// Rows inside MORE (no gameplay destinations).
enum MoreSection { info, settings, credits }

/// Primary destinations plus optional overflow family (dungeon KEY/MORE).
class DestinationGraph {
  const DestinationGraph({
    required this.destinations,
    this.overflow = const <MenuRoute>[],
  });

  final List<MenuRoute> destinations;
  final List<MenuRoute> overflow;

  bool get hasOverflow => overflow.isNotEmpty;

  int get slotCount => destinations.length + (hasOverflow ? 1 : 0);

  bool overflowContains(MenuRoute route) => overflow.contains(route);

  static DestinationGraph hub(GameState s) => DestinationGraph(
    destinations: MenuRouter.visibleHubTabs(s),
  );

  static DestinationGraph dungeon(GameState s) => DestinationGraph(
    destinations: MenuRouter.visibleDungeonTabs(s),
    overflow: <MenuRoute>[
      if (MenuTabs.showKey(s)) MenuRoute.key,
      MenuRoute.more,
    ],
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
  PowerSegment _powerSegment = PowerSegment.forge;
  MoreSection _moreSection = MoreSection.info;

  MenuRoute get route => _route;
  bool get isOpen => _route != MenuRoute.none;
  GearPanel get gearPanel => _gearPanel;
  PowerSegment get powerSegment => _powerSegment;
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
      power: intent.power,
      more: intent.more,
    );
  }

  /// BAG → FILTERS: MORE · SETTINGS, scrolled to bag cleanup controls.
  void openBagFilters() => apply(NavIntent.bagFilters);

  /// Debug playtest location (Gold/Shop/Relics/Craft/Essence).
  String get debugWhere => switch (_route) {
    MenuRoute.none => 'closed',
    MenuRoute.gear => 'GEAR/${_gearPanel.name}',
    MenuRoute.power => 'POWER/${_powerSegment.tabLabel}',
    MenuRoute.quests => 'QUESTS',
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
    MenuRoute.power => 'POWER',
    MenuRoute.quests => 'QUESTS',
    MenuRoute.key => 'KEYSTONE',
    MenuRoute.more => switch (_moreSection) {
      MoreSection.info => 'INFO',
      MoreSection.settings => 'SETTINGS',
      MoreSection.credits => 'CREDITS',
    },
  };

  void open(
    MenuRoute route, {
    GearPanel? gear,
    PowerSegment? power,
    MoreSection? more,
  }) {
    final before = debugWhere;
    if (gear != null) _gearPanel = gear;
    if (power != null) _powerSegment = power;
    if (more != null) _moreSection = more;
    if (route == MenuRoute.gear && _route != MenuRoute.gear) {
      session.clearBagSlotFilter();
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

  /// Hub chase / offline “open GEAR” with the right panel pre-selected.
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

  set powerSegment(PowerSegment segment) {
    if (_powerSegment == segment) return;
    final before = debugWhere;
    _powerSegment = segment;
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

  /// Hub bottom destinations (progressive KEY).
  static List<MenuRoute> visibleHubTabs(GameState s) => <MenuRoute>[
    MenuRoute.gear,
    MenuRoute.power,
    if (MenuTabs.showKey(s)) MenuRoute.key,
    MenuRoute.quests,
    MenuRoute.more,
  ];

  /// Dungeon primary bar destinations (KEY/MORE are overflow).
  static List<MenuRoute> visibleDungeonTabs(GameState s) => const <MenuRoute>[
    MenuRoute.gear,
    MenuRoute.power,
    MenuRoute.quests,
  ];

  static List<GearPanel> visibleGearPanels(GameState s) => <GearPanel>[
    GearPanel.gear,
    GearPanel.bag,
    if (MenuTabs.showMerge(s)) GearPanel.merge,
    if (MenuTabs.showRoster(s)) GearPanel.roster,
  ];

  static List<PowerSegment> visiblePowerSegments(GameState s) => <PowerSegment>[
    PowerSegment.forge,
    PowerSegment.market,
    if (MenuTabs.showRelics(s)) PowerSegment.relics,
    if (MenuTabs.showCraft(s)) PowerSegment.craft,
    if (MenuTabs.showCamp(s)) PowerSegment.camp,
  ];
}
