import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/town_nav.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';

void main() {
  group('TownNavPolicy', () {
    test('live HomeCatalog still lists WATCH and WISP (pending integration)', () {
      final ids = HomeCatalog.entries.map((e) => e.id).toSet();
      expect(ids, containsAll(['watch', 'wisp', 'menu_watch', 'menu_wisp']));
      expect(ids, containsAll(['scrolls', 'menu_scrolls', 'starter_pouch']));
    });

    test('town filter drops duplicate powerup chips and keeps SCROLLS + POUCH', () {
      final live = HomeCatalog.entries;
      final town = TownNavPolicy.filterEntries(live, (e) => e.id);
      final ids = town.map((e) => e.id).toSet();
      expect(ids.contains('watch'), isFalse);
      expect(ids.contains('wisp'), isFalse);
      expect(ids.contains('menu_watch'), isFalse);
      expect(ids.contains('menu_wisp'), isFalse);
      expect(ids, containsAll(['scrolls', 'menu_scrolls', 'starter_pouch']));
    });

    test('SCROLLS is the one powerups home', () {
      expect(TownNavPolicy.powerupsHomeIds, {'scrolls', 'menu_scrolls'});
      expect(
        TownNavPolicy.duplicatePowerupIds,
        {'watch', 'wisp', 'menu_watch', 'menu_wisp'},
      );
    });

    test('WATCH/WISP never stay as town chips; POUCH stays while due', () {
      expect(TownNavPolicy.keepOnTownRails('scrolls'), isTrue);
      expect(TownNavPolicy.keepOnTownRails('menu_scrolls'), isTrue);
      expect(TownNavPolicy.keepOnTownRails('starter_pouch'), isTrue);
      expect(TownNavPolicy.keepOnTownRails('menu_pouch'), isTrue);
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
      expect(TownNavPolicy.filterEntries(HomeCatalog.entries, (e) => e.id)
          .map((e) => e.id),
        contains('scrolls'),
      );
    });
  });
}
