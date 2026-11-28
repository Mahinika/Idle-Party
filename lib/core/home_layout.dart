/// Which play shell a save uses. Classic was the hub + dungeon bar.
/// Every load opens on home. The classic name stays so old JSON and
/// NavCopy tests still compile. [fromJson] never returns classic.
enum HomeLayout {
  classic,
  home;

  static HomeLayout fromJson(Object? raw) => HomeLayout.home;
}
