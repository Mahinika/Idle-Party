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
    next = next.replaceAll('GOLD → FORGE', 'TRAIN under the fight');
    next = next.replaceAll('GOLD →', 'TRAIN under the fight →');
    next = next.replaceAll('GEAR → BAG', 'HEROES → BAG');
    next = next.replaceAll('GEAR →', 'HEROES →');
    next = next.replaceAll('MORE →', 'MENU →');
    // One name for the menu button (audit F081).
    next = next.replaceAll('MORE ·', 'MENU ·');
    next = next.replaceAll('badge on MORE', 'badge on MENU');
    next = next.replaceAll('SCROLLS on the hub', 'SCROLLS on the fight rail');
    next = next.replaceAll('in GEAR', 'in HEROES');
    next = next.replaceAll(
      'Gold is under GOLD',
      'Gold buys TRAIN, CAMP and MARKET under the fight.',
    );
    next = next.replaceAll('WIPED · End → hub', 'WIPED · End → town');
    next = next.replaceAll('WIPED · Retry / Hub', 'WIPED · Retry / Town');
    next = next.replaceAll('End → hub', 'End → town');
    next = next.replaceAll('Retry / Hub', 'Retry / Town');
    next = next.replaceAll('Return to hub?', 'Return to town?');
    next = next.replaceAll('Leave to hub', 'Leave to town');
    next = next.replaceAll('returns to the hub', 'returns to town');
    next = next.replaceAll('resets from hub', 'resets from town');
    next = next.replaceAll('from hub', 'from town');
    next = next.replaceAll('Hub gold', 'Camp gold');
    next = next.replaceAll('The hub', 'Camp');
    next = next.replaceAll('the hub', 'town');
    return next;
  }
}
