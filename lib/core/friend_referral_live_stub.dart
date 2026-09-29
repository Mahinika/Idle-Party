import 'friend_referral.dart';

/// Web playtest has no Play install referrer and no friend list.
FriendReferralSync liveFriendReferralSync() =>
    FriendReferralSync(gateway: MemoryFriendReferralGateway()..offline = true);
