/// Town navigation policy for hub shortcuts that currently share one sheet.
///
/// [HomeCatalog.entries] still *defines* WATCH and WISP (tests lock the
/// catalog). [HomeCatalog.of] drops them so rails and MENU show SCROLLS
/// as the one powerups home. POUCH stays while the reinstall offer is due.
abstract final class TownNavPolicy {
  /// Duplicate shortcuts that open the SCROLLS / powerups sheet.
  static const Set<String> duplicatePowerupIds = {
    'watch',
    'wisp',
    'menu_watch',
    'menu_wisp',
  };

  /// The one home for ad tickets, the daily Well, optional WATCH, and
  /// the WISP status line. Rewards stay in that sheet.
  static const Set<String> powerupsHomeIds = {
    'scrolls',
    'menu_scrolls',
  };

  /// One-time reinstall gold. Keep visible when the offer is due.
  static const Set<String> pouchIds = {
    'starter_pouch',
    'menu_pouch',
  };

  static bool isDuplicatePowerupShortcut(String id) =>
      duplicatePowerupIds.contains(id);

  static bool keepOnTownRails(String id) => !isDuplicatePowerupShortcut(id);

  static List<T> filterEntries<T>(
    Iterable<T> entries,
    String Function(T) idOf,
  ) =>
      entries.where((e) => keepOnTownRails(idOf(e))).toList();
}
