/// Town navigation policy for hub shortcuts that currently share one sheet.
///
/// [HomeCatalog.entries] still *defines* WATCH, WISP, and menu mirrors of
/// rail shortcuts (tests lock the catalog). [HomeCatalog.of] drops duplicates
/// so each feature has one home: rails keep SCROLLS / QUESTS / VAULT / DAILY;
/// MENU keeps PATCH NOTES, SETTINGS, INFO, GUIDES, CRAFT, REDEEM, FLOORS.
abstract final class TownNavPolicy {
  /// Duplicate shortcuts that open the SCROLLS / powerups sheet.
  static const Set<String> duplicatePowerupIds = {
    'watch',
    'wisp',
    'menu_watch',
    'menu_wisp',
  };

  /// MENU grid cells that duplicate a visible rail shortcut.
  static const Set<String> duplicateMenuRailIds = {
    'menu_scrolls',
    'menu_vault',
    'menu_daily',
    'menu_pouch',
    'menu_update',
    'menu_quests',
  };

  /// The one home for ad tickets, the daily Well, and the WISP status line.
  static const Set<String> powerupsHomeIds = {
    'scrolls',
  };

  /// One-time reinstall gold. Keep visible when the offer is due.
  static const Set<String> pouchIds = {
    'starter_pouch',
    'menu_pouch',
  };

  /// F100 (Robert, Nov 19): in town the buildings are the entry points and
  /// the quick rail is hidden. Every rail entry keeps one home in town:
  /// a building (`building:<id>`) or its MENU grid cell. In the dungeon the
  /// rail is unchanged.
  static const Map<String, String> townHomeOfRail = {
    'quests': 'building:guild',
    'vault': 'building:vault',
    'scrolls': 'menu_scrolls',
    'starter_pouch': 'menu_pouch',
    'daily': 'menu_daily',
    'update': 'menu_update',
  };

  /// MENU cells that only show in town, standing in for hidden rail entries
  /// that have no building.
  static const Set<String> townMenuFromRail = {
    'menu_scrolls',
    'menu_pouch',
    'menu_daily',
    'menu_update',
  };

  /// Town MENU grid: the usual cells plus the rail entries with no building.
  static bool keepOnTownMenuGrid(String id) =>
      keepOnMenuGrid(id) || townMenuFromRail.contains(id);

  static List<T> filterTownMenuGrid<T>(
    Iterable<T> entries,
    String Function(T) idOf,
  ) =>
      entries.where((e) => keepOnTownMenuGrid(idOf(e))).toList();

  static bool isDuplicatePowerupShortcut(String id) =>
      duplicatePowerupIds.contains(id);

  static bool isDuplicateMenuRail(String id) => duplicateMenuRailIds.contains(id);

  static bool keepOnTownRails(String id) =>
      !isDuplicatePowerupShortcut(id) && !isDuplicateMenuRail(id);

  /// Rail homes stay off the MENU grid. [powerupsHomeIds] is SCROLLS.
  static bool keepOnMenuGrid(String id) =>
      keepOnTownRails(id) && !powerupsHomeIds.contains(id);

  static List<T> filterEntries<T>(
    Iterable<T> entries,
    String Function(T) idOf,
  ) =>
      entries.where((e) => keepOnTownRails(idOf(e))).toList();

  static List<T> filterMenuGrid<T>(
    Iterable<T> entries,
    String Function(T) idOf,
  ) =>
      entries.where((e) => keepOnMenuGrid(idOf(e))).toList();
}
