import 'friend_referral.dart';
import 'friend_referral_platform_io.dart';
import 'friend_referral_store_io.dart';

FriendReferralSync liveFriendReferralSync() => FriendReferralSync(
  gateway: FirestoreFriendReferralGateway(),
  readDeviceId: readFriendDeviceId,
  readInstallReferrer: readPlayInstallReferrer,
  share: shareFriendMessage,
);
