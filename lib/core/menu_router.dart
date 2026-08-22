import 'package:flutter/foundation.dart';

import '../models/loot.dart';
import 'game_state.dart';
import 'menu_alerts.dart';

/// Which menu sheet is open. Hub and dungeon share these — the same route
/// means the same words and the same content in both places.
enum MenuRoute { none, party, power, meta, settings, jobs }

/// Tabs inside PARTY. Identified by name, never by index: a tab that unlocks
/// later (MERGE, LOADOUTS, ROSTER) used to shift what a saved index meant.
enum PartyTab { gear, bag, merge, loadouts, roster }

enum PowerTab { income, forge, camp, market, shop }

enum MetaTab { key, jobs, beast, codex, guide, settings }

/// Owns "which menu is open" for the whole game.
///
/// Before this, the hub kept the answer in `main.dart` and the dungeon kept a
/// second copy in the shell, so walking into a dungeon threw away the tab and
/// the item you had selected.
class MenuRouter extends ChangeNotifier {
  MenuRoute _route = MenuRoute.none;

  /// PARTY opens on the paper doll — "what am I wearing" before "what did I loot".
  PartyTab _partyTab = PartyTab.gear;
  PowerTab _powerTab = PowerTab.income;
  MetaTab _metaTab = MetaTab.jobs;

  String? _selectedItemId;
  String? _combineA;
  String? _combineB;
  int _equipHeroIndex = 0;
  int _abilityHeroIndex = 0;
  EquipmentSlot? _bagSlotFilter;
  int _bagFiltersScrollNonce = 0;

  MenuRoute get route => _route;
  bool get isOpen => _route != MenuRoute.none;
  PartyTab get partyTab => _partyTab;
  PowerTab get powerTab => _powerTab;
  MetaTab get metaTab => _metaTab;

  String? get selectedItemId => _selectedItemId;
  String? get combineA => _combineA;
  String? get combineB => _combineB;
  int get equipHeroIndex => _equipHeroIndex;
  int get abilityHeroIndex => _abilityHeroIndex;
  EquipmentSlot? get bagSlotFilter => _bagSlotFilter;
  int get bagFiltersScrollNonce => _bagFiltersScrollNonce;

  /// BAG → FILTERS: META settings tab, scrolled to bag cleanup controls.
  void openBagFilters() {
    _metaTab = MetaTab.settings;
    _route = MenuRoute.meta;
    _bagFiltersScrollNonce++;
    notifyListeners();
  }

  /// Title shown on the sheet.
  String get title => switch (_route) {
    MenuRoute.none => '',
    MenuRoute.party => switch (_partyTab) {
      PartyTab.gear => 'GEAR',
      PartyTab.bag => 'BAG',
      PartyTab.merge => 'MERGE',
      PartyTab.loadouts => 'LOADOUTS',
      PartyTab.roster => 'ROSTER',
    },
    MenuRoute.power => 'POWER',
    MenuRoute.meta => 'META',
    MenuRoute.settings => 'SETTINGS',
    MenuRoute.jobs => 'CONTRACTS',
  };

  void open(
    MenuRoute route, {
    PartyTab? party,
    PowerTab? power,
    MetaTab? meta,
  }) {
    if (route == MenuRoute.settings) {
      _metaTab = MetaTab.settings;
      _route = MenuRoute.meta;
      notifyListeners();
      return;
    }
    if (party != null) _partyTab = party;
    if (power != null) _powerTab = power;
    if (meta != null) _metaTab = meta;
    // A fresh open from the nav shows the whole bag; slot browse sets its own
    // filter right after opening.
    if (route == MenuRoute.party && _route != MenuRoute.party) {
      _bagSlotFilter = null;
    }
    _route = route;
    notifyListeners();
  }

  /// Nav taps: tapping the tab you are already on closes the sheet.
  void toggleParty(PartyTab tab) {
    if (_route == MenuRoute.party && _partyTab == tab) {
      close();
      return;
    }
    open(MenuRoute.party, party: tab);
  }

  void toggle(MenuRoute route) {
    if (_route == route) {
      close();
      return;
    }
    open(route);
  }

  void close() {
    if (_route == MenuRoute.none) return;
    _route = MenuRoute.none;
    _bagSlotFilter = null;
    notifyListeners();
  }

  set partyTab(PartyTab tab) {
    if (_partyTab == tab) return;
    _partyTab = tab;
    notifyListeners();
  }

  set powerTab(PowerTab tab) {
    if (_powerTab == tab) return;
    _powerTab = tab;
    notifyListeners();
  }

  set metaTab(MetaTab tab) {
    if (_metaTab == tab) return;
    _metaTab = tab;
    notifyListeners();
  }

  /// Tap an item in the bag / paper doll (tapping it again deselects).
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

  /// BAG shows only gear that can fill this paper-doll slot.
  void browseBagSlot(EquipmentSlot slot) {
    _bagSlotFilter = slot;
    _selectedItemId = null;
    // Keep GEAR when the sheet already shows an inline bag; jump to BAG else.
    open(
      MenuRoute.party,
      party: _partyTab == PartyTab.gear ? PartyTab.gear : PartyTab.bag,
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
      _partyTab = PartyTab.merge;
      _route = MenuRoute.party;
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

  /// Drop ids that no longer exist in the bag (after sell / merge / auto).
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

  /// Progressive menus: a tab only exists once it can do something.
  static List<PartyTab> visiblePartyTabs(GameState s) => <PartyTab>[
    PartyTab.gear,
    PartyTab.bag,
    if (MenuTabs.showMerge(s)) PartyTab.merge,
    if (MenuTabs.showLoadouts(s)) PartyTab.loadouts,
    if (MenuTabs.showRoster(s)) PartyTab.roster,
  ];

  static List<PowerTab> visiblePowerTabs(GameState s) => <PowerTab>[
    PowerTab.income,
    PowerTab.forge,
    if (MenuTabs.showCamp(s)) PowerTab.camp,
    PowerTab.market,
    if (MenuTabs.showShop(s)) PowerTab.shop,
  ];

  static List<MetaTab> visibleMetaTabs(GameState s) => <MetaTab>[
    if (MenuTabs.showKey(s)) MetaTab.key,
    MetaTab.jobs,
    if (MenuTabs.showBeast(s)) MetaTab.beast,
    if (MenuTabs.showCodex(s)) MetaTab.codex,
    MetaTab.guide,
    MetaTab.settings,
  ];
}
