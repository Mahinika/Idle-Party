import 'friend_referral.dart';
import 'friend_referral_live_stub.dart'
    if (dart.library.io) 'friend_referral_live_io.dart'
    as impl;

FriendReferralSync liveFriendReferralSync() => impl.liveFriendReferralSync();
