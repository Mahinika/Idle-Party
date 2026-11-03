import 'home_layout.dart';

/// Player-facing place names for the home shell.
///
/// Changelog history stays as it was written. Call this when a string is
/// shown, and only when the save is on [HomeLayout.home].
abstract final class NavCopy {
  static String playerText(String text, HomeLayout layout) {
    if (layout != HomeLayout.home || text.isEmpty) return text;
    var next = text;
    next = next.replaceAll('ESSENCE → CAMP', 'CAMP under the fight');
    next = next.replaceAll('GOLD → FORGE', 'FORGE under the fight');
    next = next.replaceAll('GOLD →', 'FORGE under the fight →');
    next = next.replaceAll('GEAR → BAG', 'HEROES → BAG');
    next = next.replaceAll('GEAR →', 'HEROES →');
    next = next.replaceAll('MORE →', 'MENU →');
    next = next.replaceAll('SCROLLS on the hub', 'SCROLLS on the fight rail');
    next = next.replaceAll('in GEAR', 'in HEROES');
    next = next.replaceAll('Gold is under GOLD', 'Gold and forge sit under the fight');
    next = next.replaceAll('The hub', 'Camp');
    next = next.replaceAll('the hub', 'camp');
    return next;
  }
}
