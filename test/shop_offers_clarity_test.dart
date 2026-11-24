import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/kenney_button.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/core/shop_hub_offer.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';

void main() {
  final now = DateTime.utc(2026, 11, 22, 12);

  test('featured window favors ad_free then Delver Kit', () {
  var state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            shopOfferStartedMs: now.millisecondsSinceEpoch,
          ),
    );
    state = ShopHubOffer.ensureWindow(state, now: now);
    final unowned = ShopHubOffer.featuredItem(state, now: now, playListsAdFree: true);
    expect(unowned?.id, 'ad_free');
    expect(ShopHubOffer.featuredTitle(unowned!), 'Ad-free welcome');

    final adFree = ShopCatalog.byId['ad_free']!;
    state = ShopBilling.applyPurchase(state, adFree, now: now);
    final next = ShopHubOffer.featuredItem(state, now: now, playListsAdFree: true);
    expect(next?.id, 'supporter_qol');
    expect(ShopHubOffer.featuredTitle(next!), "Delver's Kit");
  });

  test('featured falls through to Delver Kit when Play does not list ad_free', () {
    var state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      metaDepth: MetaDepthState(shopOfferStartedMs: now.millisecondsSinceEpoch),
    );
    final item = ShopHubOffer.featuredItem(state, now: now, playListsAdFree: false);
    expect(item?.id, 'supporter_qol');
  });

  test('CAMP free level label names recommended track', () {
    final state = GameLogic.createInitialState().copyWith(
      ascensionLevel: 1,
      sanctuaryPowerLevel: 5,
    );
    expect(
      SanctuaryOverlay.watchFreeLabel(state),
      'Watch · free Gold level',
    );
  });

  test('cinder and season rows hide until Play lists them', () {
    expect(
      ShopCatalog.shelf().map((e) => e.id),
      ['ad_free', 'long_away', 'supporter_qol'],
    );
    final listed = ShopCatalog.shelf(
      playListed: {'cinder_pouch', 'season_pass_premium'},
    ).map((e) => e.id);
    expect(listed, contains('cinder_pouch'));
    expect(listed, contains('season_pass_premium'));
  });

  test('cinder tag shows first-buy doubler until purchased once', () {
    expect(
      ShopDock.rowTag(ShopCatalog.byId['cinder_pouch']!),
      'First buy ×2 (16)',
    );
    expect(
      ShopDock.rowTag(
        ShopCatalog.byId['cinder_pouch']!,
        cinderPouchDoubled: true,
      ),
      '8 Cinders',
    );
  });

  test('month pass claim chase names premium when owned', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
      metaDepth: state.metaDepth.copyWith(
        monthPassKey: '2026-08',
        monthlyBestTimedKey: 8,
        paidSeasonPass: true,
      ),
    );
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.monthGoal);
    expect(chase.detail, contains('+5 Cinders'));

    final free = state.copyWith(
      metaDepth: state.metaDepth.copyWith(paidSeasonPass: false),
    );
    final freeChase = HubChase.forState(free);
    expect(freeChase.detail, contains('Premium: +50% essence and +5 Cinders'));
    expect(freeChase.detail, contains('open SHOP'));
  });

  test('season pass premium description is explicit one-time unlock', () {
    final item = ShopCatalog.byId['season_pass_premium']!;
    expect(item.description, contains('Not a subscription'));
    expect(item.description, contains('+50% essence'));
  });

  testWidgets('Welcome Back upsells Long Away when hub chest capped', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        bossVictories: 1,
        homeLayout: HomeLayout.home,
      ),
    );
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);

    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: director.state,
        secondsApplied: 12 * 3600,
        secondsAway: 20 * 3600,
        goldGained: 500,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
        hubChestCapSec: 12 * 3600,
        wasInDungeon: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GameButton(
              label: 'OPEN',
              onPressed: () => showOfflineProgressDialog(
                context,
                director,
                router: router,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Chest filled at 12h'), findsOneWidget);
    expect(find.textContaining('Long Away fills 24h'), findsOneWidget);
  });
}