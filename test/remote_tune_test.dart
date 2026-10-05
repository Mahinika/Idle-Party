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

  test('a published lantern interval replaces the debug cadence', () {
    RemoteTune.apply(intervalSec: 120, fromRemote: true);

    expect(RemoteTune.wispFromRemote, isTrue);
    expect(WispGift.intervalMs, 120 * 1000);
    expect(WispGift.firstDelayMs, RemoteTune.defaultFirstDelaySec * 1000);
    expect(WispGift.dailyCap, RemoteTune.defaultDailyCap);
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
