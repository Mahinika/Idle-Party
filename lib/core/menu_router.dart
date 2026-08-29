import 'package:flutter/foundation.dart';

import '../models/loot.dart';
import 'game_state.dart';
import 'hub_chase.dart';
import 'menu_alerts.dart';

/// Top-level menu destinations (flat tab nav). Hub and dungeon share these.
enum MenuRoute { none, gear, power, quests, key, more }

/// Local focus inside GEAR (not bottom-nav destinations).
enum GearPanel { gear, bag, merge, roster }

/// Sticky POWER segments (Gold | Shop | Forever). Essence shop lives in Shop; Beast in Forever.
enum PowerSegment { forge, market, camp }

/// Player-facing POWER tab names — everyday English, same the whole game.
extension PowerSegmentLabel on PowerSegment {
  String get tabLabel => switch (this) {
    PowerSegment.forge => 'Gold',
    PowerSegment.market => 'Shop',
    PowerSegment.camp => 'Forever',
  };
}

/// Rows inside MORE (no gameplay destinations).
enum MoreSection { info, settings, credits }

/// Owns "which menu is open" for the whole game.
class MenuRouter extends ChangeNotifier {
  MenuRoute _route = MenuRoute.none;

  GearPanel _gearPanel = GearPanel.gear;
  PowerSegment _powerSegment = PowerSegment.forge;
  MoreSection _moreSection = MoreSection.info;

  String? _selectedItemId;
  String? _combineA;
  String? _combineB;
  int _equipHeroIndex = 0;
  int _abilityHeroIndex = 0;
  EquipmentSlot? _bagSlotFilter;
  int _bagFiltersScrollNonce = 0;

  MenuRoute get route => _route;
  bool get isOpen => _route != MenuRoute.none;
  GearPanel get gearPanel => _gearPanel;
  PowerSegment get powerSegment => _powerSegment;
  MoreSection get moreSection => _moreSection;

  String? get selectedItemId => _selectedItemId;
  String? get combineA => _combineA;
  String? get combineB => _combineB;
  int get equipHeroIndex => _equipHeroIndex;
  int get abilityHeroIndex => _abilityHeroIndex;
  EquipmentSlot? get bagSlotFilter => _bagSlotFilter;
  int get bagFiltersScrollNonce => _bagFiltersScrollNonce;

  /// BAG → FILTERS: MORE · SETTINGS, scrolled to bag cleanup controls.
  void openBagFilters() {
    _moreSection = MoreSection.settings;
    _route = MenuRoute.more;
    _bagFiltersScrollNonce++;
    notifyListeners();
  }

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
    GameState? state,
  }) {
    if (gear != null) _gearPanel = gear;
    if (power != null) _powerSegment = power;
    if (more != null) _moreSection = more;
    if (route == MenuRoute.gear && _route != MenuRoute.gear) {
      _bagSlotFilter = null;
    }
    _route = route;
    notifyListeners();
  }

  /// Nav taps: tapping the tab you are already on closes the sheet.
  void toggle(MenuRoute route, {GameState? state}) {
    if (_route == route) {
      close();
      return;
    }
    open(route, state: state);
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
    _route = MenuRoute.none;
    _bagSlotFilter = null;
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
    _gearPanel = panel;
    notifyListeners();
  }

  set powerSegment(PowerSegment segment) {
    if (_powerSegment == segment) return;
    _powerSegment = segment;
    notifyListeners();
  }

  set moreSection(MoreSection section) {
    if (_moreSection == section) return;
    _moreSection = section;
    notifyListeners();
  }

  void selectItem(String? id) {
    _selectedItemId = _selectedItemId == id ? null : id;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedItemId == null) return;
    _selectedItemId = null;
    notifyListeners();
  }

  set equipHeroIndex(int index) {
    if (_equipHeroIndex == index) return;
    _equipHeroIndex = index;
    notifyListeners();
  }

  set abilityHeroIndex(int index) {
    if (_abilityHeroIndex == index) return;
    _abilityHeroIndex = index;
    notifyListeners();
  }

  void browseBagSlot(EquipmentSlot slot) {
    _bagSlotFilter = slot;
    _selectedItemId = null;
    open(
      MenuRoute.gear,
      gear: _gearPanel == GearPanel.gear ? GearPanel.gear : GearPanel.bag,
    );
    _bagSlotFilter = slot;
    notifyListeners();
  }

  void clearBagSlotFilter() {
    if (_bagSlotFilter == null) return;
    _bagSlotFilter = null;
    notifyListeners();
  }

  /// Load the merge slots. Returns true once both slots are filled.
  bool putInCombinator(String id) {
    if (_combineA == id) {
      _combineA = null;
      notifyListeners();
      return false;
    }
    if (_combineB == id) {
      _combineB = null;
      notifyListeners();
      return false;
    }
    if (_combineA == null) {
      _combineA = id;
    } else if (_combineB == null) {
      _combineB = id;
    } else {
      _combineA = _combineB;
      _combineB = id;
    }
    final ready = _combineA != null && _combineB != null;
    if (ready) {
      _gearPanel = GearPanel.merge;
      _route = MenuRoute.gear;
    }
    notifyListeners();
    return ready;
  }

  void clearCombineA() {
    _combineA = null;
    notifyListeners();
  }

  void clearCombineB() {
    _combineB = null;
    notifyListeners();
  }

  void clearCombine() {
    _combineA = null;
    _combineB = null;
    _selectedItemId = null;
    notifyListeners();
  }

  void dropMissingIds(Set<String> liveIds) {
    var changed = false;
    if (_selectedItemId != null && !liveIds.contains(_selectedItemId)) {
      _selectedItemId = null;
      changed = true;
    }
    if (_combineA != null && !liveIds.contains(_combineA)) {
      _combineA = null;
      changed = true;
    }
    if (_combineB != null && !liveIds.contains(_combineB)) {
      _combineB = null;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Hub bottom destinations (progressive KEY).
  static List<MenuRoute> visibleHubTabs(GameState s) => <MenuRoute>[
    MenuRoute.gear,
    MenuRoute.power,
    if (MenuTabs.showKey(s)) MenuRoute.key,
    MenuRoute.quests,
    MenuRoute.more,
  ];

  /// Dungeon bottom destinations (no MORE/KEY — those use HUD gear).
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
    if (MenuTabs.showCamp(s)) PowerSegment.camp,
  ];
}
