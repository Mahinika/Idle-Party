import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/friend_referral.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/play_leaderboard_ids.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/meta/prestige_shop.dart';

void main() {
  test('prestige haveLine is honest about Dawn Tithe / Apothecary / stash', () {
    final state = GameLogic.createInitialState().copyWith(
      metaDepth: const MetaDepthState(
        stashBonusSlots: 4,
        marketDiscountLevel: 2,
        dailyEssenceBonusLevel: 3,
        petRosterCapBonus: 2,
      ),
    );
    expect(
      PrestigeShopOverlay.haveLine(state, 'daily_essence'),
      contains('Dawn Tithe'),
    );
    expect(
      PrestigeShopOverlay.haveLine(state, 'daily_essence'),
      contains('+15e'),
    );
    expect(
      PrestigeShopOverlay.haveLine(state, 'flask_discount'),
      contains('bandages'),
    );
    expect(
      PrestigeShopOverlay.haveLine(state, 'stash_slot'),
      contains('stash slots'),
    );
    expect(
      PrestigeShopOverlay.haveLine(state, 'roster_cap'),
      startsWith('PETS'),
    );
  });

  test('prestige catalog PETS Kennel replaces Beast Kennel', () {
    expect(PrestigeShopCatalog.byId('roster_cap')?.name, 'PETS Kennel');
    expect(
      PrestigeShopCatalog.byId('roster_cap')?.description,
      contains('PETS'),
    );
  });

  test('Ad-free welcome mentions WISP without inventing Play IDs', () {
    final item = ShopCatalog.offered.firstWhere((e) => e.id == 'ad_free');
    expect(item.description, contains('WISP'));
    expect(item.description, isNot(contains('Cgk')));
  });

  test('friend tip cap is 30', () {
    expect(FriendReferral.maxFriends, 30);
  });

  test('reuse notice for Sep/Oct boards stays soft', () {
    expect(PlayLeaderboardIds.reusedBoardNotice('2026-09'), isNotNull);
    expect(PlayLeaderboardIds.reusedBoardNotice('2026-10'), contains('August'));
    expect(PlayLeaderboardIds.reusedBoardNotice('2026-08'), isNull);
  });

  test('forge MOVE/HASTE/CRIT gains are 2 points each', () {
    expect(GameLogic.forgeMoveGain, 2);
    expect(GameLogic.forgeHasteGain, 2);
    expect(GameLogic.forgeCritGain, 2);
  });
}
