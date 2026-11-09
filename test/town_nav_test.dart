import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/town_nav.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';

void main() {
  group('TownNavPolicy', () {
    test('HomeCatalog still defines WATCH and WISP; of() drops them', () {
      final ids = HomeCatalog.entries.map((e) => e.id).toSet();
      expect(ids, containsAll(['watch', 'wisp', 'menu_watch', 'menu_wisp']));
      expect(ids, containsAll(['scrolls', 'menu_scrolls', 'starter_pouch']));
      final rails = {
        ...HomeCatalog.of(HomePlace.leftRail),
        ...HomeCatalog.of(HomePlace.rightRail),
      }.map((e) => e.id).toSet();
      final menu = HomeCatalog.of(HomePlace.menuGrid).map((e) => e.id).toSet();
      expect(rails.contains('watch'), isFalse);
      expect(rails.contains('wisp'), isFalse);
      expect(menu.contains('menu_watch'), isFalse);
      expect(menu.contains('menu_wisp'), isFalse);
      expect(rails, containsAll(['scrolls', 'quests', 'vault', 'daily']));
      expect(menu.contains('menu_scrolls'), isFalse);
      expect(menu.contains('menu_quests'), isFalse);
      expect(menu.contains('menu_vault'), isFalse);
      expect(menu, containsAll(['menu_patch', 'menu_settings', 'menu_craft']));
    });

    test('town filter drops duplicate powerup chips and keeps SCROLLS + POUCH', () {
      final live = HomeCatalog.entries;
      final town = TownNavPolicy.filterEntries(live, (e) => e.id);
      final ids = town.map((e) => e.id).toSet();
      expect(ids.contains('watch'), isFalse);
      expect(ids.contains('wisp'), isFalse);
      expect(ids.contains('menu_watch'), isFalse);
      expect(ids.contains('menu_wisp'), isFalse);
      expect(ids, containsAll(['scrolls', 'starter_pouch']));
      expect(ids.contains('menu_scrolls'), isFalse);
    });

    test('SCROLLS is the one powerups home on rails', () {
      expect(TownNavPolicy.powerupsHomeIds, {'scrolls'});
      expect(
        TownNavPolicy.duplicatePowerupIds,
        {'watch', 'wisp', 'menu_watch', 'menu_wisp'},
      );
      expect(
        TownNavPolicy.duplicateMenuRailIds,
        containsAll(['menu_scrolls', 'menu_quests', 'menu_vault']),
      );
    });

    test('WATCH/WISP never stay as town chips; POUCH stays while due', () {
      expect(TownNavPolicy.keepOnTownRails('scrolls'), isTrue);
      expect(TownNavPolicy.keepOnMenuGrid('scrolls'), isFalse);
      expect(TownNavPolicy.keepOnMenuGrid('menu_scrolls'), isFalse);
      expect(TownNavPolicy.keepOnTownRails('starter_pouch'), isTrue);
      expect(TownNavPolicy.keepOnMenuGrid('menu_pouch'), isFalse);
      expect(TownNavPolicy.keepOnTownRails('watch'), isFalse);
      expect(TownNavPolicy.keepOnTownRails('wisp'), isFalse);
      expect(TownNavPolicy.isDuplicatePowerupShortcut('menu_watch'), isTrue);
      expect(TownNavPolicy.isDuplicatePowerupShortcut('menu_wisp'), isTrue);
    });

    test('live catalog still badges WATCH/WISP as SCROLLS duplicates', () {
      final watch = HomeCatalog.entries.where((e) => e.id == 'watch').single;
      final wisp = HomeCatalog.entries.where((e) => e.id == 'wisp').single;
      final scrolls = HomeCatalog.entries.where((e) => e.id == 'scrolls').single;
      expect(watch.label, 'WATCH');
      expect(wisp.label, 'WISP');
      expect(scrolls.label, 'SCROLLS');
      expect(
        TownNavPolicy.filterEntries(HomeCatalog.entries, (e) => e.id)
            .map((e) => e.id),
        contains('scrolls'),
      );
    });
  });
}
