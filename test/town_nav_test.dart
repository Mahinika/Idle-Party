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
  });
}
