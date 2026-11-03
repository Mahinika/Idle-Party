/// Which play shell a save uses. Classic is the hub + dungeon bar.
/// Home is the fight-first shell. A save with no layout field opens on home.
enum HomeLayout {
  classic,
  home;

  static HomeLayout fromJson(Object? raw) =>
      raw == 'classic' ? HomeLayout.classic : HomeLayout.home;
}
