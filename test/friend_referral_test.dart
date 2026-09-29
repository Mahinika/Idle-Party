import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/friend_referral.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('code, link, and referrer parsing', () {
    final code = FriendReferral.newCode(math.Random(1));
    expect(code, hasLength(FriendReferral.codeLength));
    expect(FriendReferral.isValidCode(code), isTrue);
    expect(FriendReferral.isValidCode('WINTER'), isFalse);
    expect(FriendReferral.isValidCode('OOOOOOOO'), isFalse);

    final link = FriendReferral.playLink(code);
    expect(link, contains('id=com.idleparty.app'));
    expect(link, contains('referrer='));
    final message = FriendReferral.shareMessage(code);
    expect(message, contains('Code $code'));
    expect(message, contains(link));

    expect(FriendReferral.codeFromReferrer('ref=$code'), code);
    expect(FriendReferral.codeFromReferrer('ref%3D$code'), code);
    expect(
      FriendReferral.codeFromReferrer(
        'https://play.google.com/store/apps/details?id=com.idleparty.app'
        '&referrer=ref%3D$code',
      ),
      code,
    );
    expect(FriendReferral.codeFromReferrer(code), code);
    expect(FriendReferral.codeFromReferrer('utm_source=google'), isNull);
    expect(FriendReferral.deviceKey('phone').length, 64);
  });

  test('one phone once, not yourself, cap 30', () {
    final book = FriendReferralBook();
    const owner = 'owner-device';
    const code = 'ABCD2345';
    book.ensureCode(code: code, deviceId: owner);
    expect(book.claim(code: code, deviceId: owner), FriendClaimStatus.self);
    expect(book.claimsOf(code), 0);

    expect(
      book.claim(code: 'ZZZZZZZZ', deviceId: 'friend'),
      FriendClaimStatus.unknownCode,
    );

    for (var i = 0; i < FriendReferral.maxFriends; i++) {
      expect(
        book.claim(code: code, deviceId: 'friend-$i'),
        FriendClaimStatus.accepted,
      );
    }
    expect(book.claimsOf(code), FriendReferral.maxFriends);
    expect(
      book.claim(code: code, deviceId: 'one-more'),
      FriendClaimStatus.full,
    );
    expect(
      book.claim(code: code, deviceId: 'friend-0'),
      FriendClaimStatus.duplicate,
    );
  });

  test('payout is 10 tickets per new friend and stops at the cap', () {
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(friendCode: 'ABCD2345'),
    );
    final once = FriendReferral.withPayout(state, 1);
    expect(once.metaDepth.adTickets, 10);
    expect(once.metaDepth.friendClaimsPaid, 1);
    final again = FriendReferral.withPayout(once, 1);
    expect(identical(again, once), isTrue);
    final burst = FriendReferral.withPayout(state, 99);
    expect(burst.metaDepth.friendClaimsPaid, FriendReferral.maxFriends);
    expect(burst.metaDepth.adTickets, FriendReferral.maxFriends * 10);
  });

  test('legacy save defaults and Ascend keeps the code', () {
    final missing = MetaDepthState.fromJson(const <String, dynamic>{});
    expect(missing.friendCode, isEmpty);
    expect(missing.friendClaimsPaid, 0);
    expect(missing.friendInviteUsed, isEmpty);
    expect(missing.friendReferrerChecked, isFalse);
    final junk = MetaDepthState.fromJson(const <String, dynamic>{
      'friendCode': 'winter',
      'friendClaimsPaid': 80,
    });
    expect(junk.friendCode, isEmpty);
    expect(junk.friendClaimsPaid, 30);

    var state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 9, 29),
    ).copyWith(bossVictories: 1);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        friendCode: 'ABCD2345',
        friendClaimsPaid: 2,
        adTickets: 20,
      ),
    );
    final ascended = GameLogic.ascend(state, now: DateTime.utc(2026, 9, 29));
    expect(ascended.metaDepth.friendCode, 'ABCD2345');
    expect(ascended.metaDepth.friendClaimsPaid, 2);
    expect(ascended.metaDepth.adTickets, 20);
    final round = MetaDepthState.fromJson(ascended.metaDepth.toJson());
    expect(round.friendCode, 'ABCD2345');
    expect(round.friendClaimsPaid, 2);
  });

  test('share, install, and payout through the in-memory list', () async {
    final gateway = MemoryFriendReferralGateway();
    String? shared;
    final inviter = FriendReferralSync(
      gateway: gateway,
      readDeviceId: () async => FriendReferral.deviceKey('inviter'),
      readInstallReferrer: () async => null,
      share: (message) async => shared = message,
      random: math.Random(2),
    );
    final invited = await inviter.shareInvite(GameLogic.createInitialState());
    final code = invited.state.metaDepth.friendCode;
    expect(FriendReferral.isValidCode(code), isTrue);
    expect(shared, contains(code));
    expect(invited.toast, isNull);

    final friend = FriendReferralSync(
      gateway: gateway,
      readDeviceId: () async => FriendReferral.deviceKey('friend'),
      readInstallReferrer: () async => 'ref=$code',
    );
    final joined = await friend.sync(GameLogic.createInitialState());
    expect(joined.state.metaDepth.friendInviteUsed, code);
    expect(gateway.book.claimsOf(code), 1);

    final paid = await inviter.sync(invited.state);
    expect(paid.state.metaDepth.adTickets, 10);
    expect(paid.state.metaDepth.friendClaimsPaid, 1);
    expect(paid.toast, '10 Ad Tickets from a friend');

    final second = await friend.sync(joined.state);
    expect(identical(second.state, joined.state), isTrue);
    expect(gateway.book.claimsOf(code), 1);
  });

  test('own link does not pay yourself', () async {
    final gateway = MemoryFriendReferralGateway();
    final device = FriendReferral.deviceKey('same');
    final sync = FriendReferralSync(
      gateway: gateway,
      readDeviceId: () async => device,
      share: (_) async {},
      random: math.Random(3),
    );
    final invited = await sync.shareInvite(GameLogic.createInitialState());
    final code = invited.state.metaDepth.friendCode;
    final replay = FriendReferralSync(
      gateway: gateway,
      readDeviceId: () async => device,
      readInstallReferrer: () async => 'ref=$code',
    );
    final opened = await replay.sync(invited.state);
    expect(opened.state.metaDepth.adTickets, 0);
    expect(gateway.book.claimsOf(code), 0);
    expect(opened.state.metaDepth.friendReferrerChecked, isTrue);
  });

  test('director share uses the test list and keeps the code', () async {
    final director = GameDirector.preview();
    String? shared;
    director.debugSetFriendSync(
      FriendReferralSync(
        gateway: MemoryFriendReferralGateway(),
        readDeviceId: () async => FriendReferral.deviceKey('phone'),
        readInstallReferrer: () async => null,
        share: (message) async => shared = message,
        random: math.Random(4),
      ),
    );
    await director.boot();
    await director.shareFriendInvite();
    final code = director.state.metaDepth.friendCode;
    expect(FriendReferral.isValidCode(code), isTrue);
    expect(shared, contains('Play Idle Party with me'));
    expect(shared, contains(code));
  });
}
