import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/gear_session.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  test('combinator fills without changing the router destination', () {
    final router = MenuRouter();
    expect(router.session.putInCombinator('a'), isFalse);
    expect(router.route, MenuRoute.none);
    expect(router.session.putInCombinator('b'), isTrue);
    expect(router.route, MenuRoute.none);
    expect(router.session.combineA, 'a');
    expect(router.session.combineB, 'b');
  });

  test('dropMissingIds clears stale selection', () {
    final session = GearSession();
    session.selectItem('gone');
    session.dropMissingIds({'live'});
    expect(session.selectedItemId, isNull);
  });

  test('browseBagSlot opens GEAR and sets the filter', () {
    final router = MenuRouter();
    router.browseBagSlot(EquipmentSlot.weapon);
    expect(router.route, MenuRoute.gear);
    expect(router.session.bagSlotFilter, EquipmentSlot.weapon);
  });
}
