import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/remote_tune.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/core/wisp_gift.dart';

void main() {
  tearDown(RemoteTune.reset);

  test('shipped defaults match the lantern and leave the bundle lit', () {
    expect(RemoteTune.defaultDailyCap, WispGift.releaseDailyCap);
    expect(RemoteTune.defaultFirstDelaySec * 1000, WispGift.releaseFirstDelayMs);
    expect(RemoteTune.defaultIntervalSec * 1000, WispGift.releaseIntervalMs);
    expect(RemoteTune.defaultVisibleSec * 1000, WispGift.releaseVisibleMs);
    expect(RemoteTune.wispFromRemote, isFalse);
    expect(WispGift.intervalMs, 20 * 1000);

    final bundle = ShopCatalog.byId['perm_scrolls_all']!;
    expect(bundle.permMask, AdBoost.permAll);
    expect(RemoteTune.highlights(bundle), isTrue);
    expect(RemoteTune.pin(ShopCatalog.extraPacks), ShopCatalog.extraPacks);
  });

  test('out of range and unknown shop ids stay on the shipped game', () {
    RemoteTune.apply(
      dailyCap: 0,
      firstDelaySec: 1,
      intervalSec: 99999,
      visibleSec: 2,
      shopFeaturedId: 'not_a_sku',
      fromRemote: true,
    );

    expect(RemoteTune.wispDailyCap, RemoteTune.defaultDailyCap);
    expect(RemoteTune.wispFirstDelayMs, RemoteTune.defaultFirstDelaySec * 1000);
    expect(RemoteTune.wispIntervalMs, RemoteTune.defaultIntervalSec * 1000);
    expect(RemoteTune.wispVisibleMs, RemoteTune.defaultVisibleSec * 1000);
    expect(RemoteTune.shopFeaturedId, isEmpty);
    expect(RemoteTune.wispFromRemote, isFalse);
    expect(WispGift.firstDelayMs, 20 * 1000);
  });

  test('a published lantern interval does not replace the shipped cadence', () {
    RemoteTune.apply(intervalSec: 120, dailyCap: 3, fromRemote: true);

    expect(RemoteTune.wispFromRemote, isFalse);
    expect(RemoteTune.wispIntervalMs, RemoteTune.defaultIntervalSec * 1000);
    expect(RemoteTune.wispDailyCap, RemoteTune.defaultDailyCap);
    expect(WispGift.intervalMs, 20 * 1000);
    // Debug builds keep the fast loop. A published cap of 3 must not land.
    expect(WispGift.dailyCap, 1000000);
  });

  test('feature flags default on and can turn off', () {
    expect(RemoteTune.firstClimbAutoContinue, isTrue);
    expect(RemoteTune.firstClimbPlayNow, isTrue);
    expect(RemoteTune.welcomeBackFirstReturnShort, isTrue);
    expect(RemoteTune.townEnabled, isTrue);
    expect(RemoteTune.townSquareActive(false), isTrue);
    RemoteTune.apply(firstClimbAutoContinue: false);
    expect(RemoteTune.firstClimbAutoContinue, isFalse);
    RemoteTune.reset();
    expect(RemoteTune.firstClimbAutoContinue, isTrue);
    expect(RemoteTune.townEnabled, isTrue);
    expect(RemoteTune.readBool('off', true), isFalse);
    expect(RemoteTune.readBool(1, false), isTrue);
    expect(
      RemoteTune.featureFlag('0', shippedDefault: true),
      isFalse,
    );
    expect(
      RemoteTune.featureFlag(null, shippedDefault: true),
      isTrue,
    );
  });

  test('town_enabled defaults on and can disable town square', () {
    expect(RemoteTune.defaultTownEnabled, isTrue);
    expect(RemoteTune.defaults[RemoteTune.keyTownEnabled], isTrue);
    RemoteTune.apply(townEnabled: false);
    expect(RemoteTune.townEnabled, isFalse);
    expect(RemoteTune.townSquareActive(false), isFalse);
    expect(RemoteTune.townSquareActive(true), isFalse);
    RemoteTune.reset();
    expect(RemoteTune.townEnabled, isTrue);
  });

  test('a shop id lights that row and pins it first', () {
    RemoteTune.apply(shopFeaturedId: 'supporter_qol', fromRemote: true);

    expect(RemoteTune.wispFromRemote, isFalse);
    expect(WispGift.intervalMs, 20 * 1000);
    final supporter = ShopCatalog.byId['supporter_qol']!;
    final bundle = ShopCatalog.byId['perm_scrolls_all']!;
    expect(RemoteTune.highlights(supporter), isTrue);
    expect(RemoteTune.highlights(bundle), isFalse);
    expect(RemoteTune.pin(ShopCatalog.extraPacks).first.id, 'supporter_qol');
    expect(
      RemoteTune.pin(ShopCatalog.foreverBundle).first.id,
      'perm_scrolls_all',
    );
  });
}
