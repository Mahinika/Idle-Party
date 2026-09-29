import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'game_logic.dart';
import 'game_state.dart';

/// One new install that counted toward a friend's code.
enum FriendClaimStatus {
  accepted,
  duplicate,
  self,
  full,
  unknownCode,
  unavailable,
}

/// Result of a friend-list call that may change the save.
class FriendReferralOutcome {
  const FriendReferralOutcome(this.state, {this.toast});

  final GameState state;
  final String? toast;
}

/// In-memory friend list. Firestore follows the same rules.
class FriendReferralBook {
  final Map<String, ({String ownerDevice, int claims})> _codes = {};
  final Map<String, String> _deviceCode = {};

  void ensureCode({required String code, required String deviceId}) {
    _codes.putIfAbsent(code, () => (ownerDevice: deviceId, claims: 0));
  }

  int claimsOf(String code) => _codes[code]?.claims ?? 0;

  bool owns(String code, String deviceId) =>
      _codes[code]?.ownerDevice == deviceId;

  FriendClaimStatus claim({required String code, required String deviceId}) {
    if (_deviceCode.containsKey(deviceId)) return FriendClaimStatus.duplicate;
    final row = _codes[code];
    if (row == null) return FriendClaimStatus.unknownCode;
    if (row.ownerDevice == deviceId) return FriendClaimStatus.self;
    if (row.claims >= FriendReferral.maxFriends) return FriendClaimStatus.full;
    _codes[code] = (ownerDevice: row.ownerDevice, claims: row.claims + 1);
    _deviceCode[deviceId] = code;
    return FriendClaimStatus.accepted;
  }
}

/// Talks to the friend list. Tests use [MemoryFriendReferralGateway].
abstract class FriendReferralGateway {
  Future<void> ensureCode({required String code, required String deviceId});

  Future<int?> claimCount({required String code, required String deviceId});

  Future<FriendClaimStatus> claim({
    required String code,
    required String deviceId,
  });
}

class MemoryFriendReferralGateway implements FriendReferralGateway {
  MemoryFriendReferralGateway([FriendReferralBook? book])
    : book = book ?? FriendReferralBook();

  final FriendReferralBook book;
  bool offline = false;

  @override
  Future<void> ensureCode({
    required String code,
    required String deviceId,
  }) async {
    if (offline) return;
    book.ensureCode(code: code, deviceId: deviceId);
  }

  @override
  Future<int?> claimCount({
    required String code,
    required String deviceId,
  }) async {
    if (offline) return null;
    return book.claimsOf(code);
  }

  @override
  Future<FriendClaimStatus> claim({
    required String code,
    required String deviceId,
  }) async {
    if (offline) return FriendClaimStatus.unavailable;
    return book.claim(code: code, deviceId: deviceId);
  }
}

/// Codes, Play links, and ticket payout. No network.
abstract final class FriendReferral {
  static const int ticketsPerFriend = 10;
  static const int maxFriends = 30;
  static const int codeLength = 8;

  /// Empty Play referrer reads before giving up. One empty read used to
  /// stick the flag, so a friend's install never paid the inviter.
  static const int referrerGiveUpTries = 6;
  static const String packageId = 'com.idleparty.app';

  /// No I / O / 0 / 1 — those look alike in a text message.
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static final RegExp codePattern = RegExp('^[$alphabet]{$codeLength}\$');
  static final RegExp _referrerPattern = RegExp(
    'ref=([$alphabet]{$codeLength})',
    caseSensitive: false,
  );

  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  static bool isValidCode(String raw) => codePattern.hasMatch(normalize(raw));

  static String newCode(math.Random random) {
    final buffer = StringBuffer();
    for (var i = 0; i < codeLength; i++) {
      buffer.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Stable id for one Android install. Not the raw Android id.
  static String deviceKey(String androidId) =>
      sha256.convert(utf8.encode('idle-party-friend:$androidId')).toString();

  static String playLink(String code) {
    final referrer = Uri.encodeComponent('ref=$code');
    return 'https://play.google.com/store/apps/details'
        '?id=$packageId&referrer=$referrer';
  }

  static String shareMessage(String code) =>
      'Play Idle Party with me. Code $code.\n${playLink(code)}';

  static String? codeFromReferrer(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var text = raw.trim();
    for (var i = 0; i < 3; i++) {
      final found = _codeIn(text);
      if (found != null) return found;
      try {
        final decoded = Uri.decodeQueryComponent(text);
        if (decoded == text) return null;
        text = decoded;
      } catch (_) {
        return null;
      }
    }
    return _codeIn(text);
  }

  static String? _codeIn(String text) {
    final ref = _referrerPattern.firstMatch(text);
    if (ref != null) {
      final code = normalize(ref.group(1)!);
      if (isValidCode(code)) return code;
    }
    final whole = normalize(text);
    return isValidCode(whole) ? whole : null;
  }

  /// New friends to pay, already capped at [maxFriends].
  static int newFriends({required int serverClaims, required int alreadyPaid}) {
    final capped = serverClaims.clamp(0, maxFriends);
    final paid = alreadyPaid.clamp(0, maxFriends);
    if (capped <= paid) return 0;
    return capped - paid;
  }

  static GameState withPayout(GameState state, int serverClaims) {
    final paid = state.metaDepth.friendClaimsPaid;
    final n = newFriends(serverClaims: serverClaims, alreadyPaid: paid);
    if (n <= 0) return state;
    final withTickets = GameLogic.grantAdTicket(
      state,
      count: n * ticketsPerFriend,
    );
    return withTickets.copyWith(
      metaDepth: withTickets.metaDepth.copyWith(friendClaimsPaid: paid + n),
    );
  }

  /// Friend sync starts from a snapshot. Fold only its ticket and invite
  /// changes onto the live save so a slow list read cannot wipe newer tickets.
  static GameState mergeOnto(
    GameState live,
    GameState start,
    GameState outcome,
  ) {
    if (identical(start, outcome)) return live;
    final gain = outcome.metaDepth.adTickets - start.metaDepth.adTickets;
    final o = outcome.metaDepth;
    final l = live.metaDepth;
    final tickets = (l.adTickets + gain).clamp(0, 9999);
    final code = o.friendCode.isNotEmpty ? o.friendCode : l.friendCode;
    final paid = math.max(l.friendClaimsPaid, o.friendClaimsPaid);
    final used = o.friendInviteUsed.isNotEmpty
        ? o.friendInviteUsed
        : l.friendInviteUsed;
    final tries = math.max(l.friendReferrerTries, o.friendReferrerTries);
    final checked = o.friendReferrerTries > 0
        ? o.friendReferrerChecked
        : (l.friendReferrerChecked || o.friendReferrerChecked);
    if (tickets == l.adTickets &&
        code == l.friendCode &&
        paid == l.friendClaimsPaid &&
        used == l.friendInviteUsed &&
        tries == l.friendReferrerTries &&
        checked == l.friendReferrerChecked) {
      return live;
    }
    return live.copyWith(
      metaDepth: l.copyWith(
        adTickets: tickets,
        friendCode: code,
        friendClaimsPaid: paid,
        friendInviteUsed: used,
        friendReferrerTries: tries,
        friendReferrerChecked: checked,
      ),
    );
  }
}

/// Applies the friend list onto a save. Network and Play sit behind callbacks.
class FriendReferralSync {
  FriendReferralSync({
    required this.gateway,
    this.readDeviceId,
    this.readInstallReferrer,
    this.share,
    math.Random? random,
  }) : _random = random ?? math.Random.secure();

  final FriendReferralGateway gateway;
  final Future<String?> Function()? readDeviceId;
  final Future<String?> Function()? readInstallReferrer;
  final Future<void> Function(String message)? share;
  final math.Random _random;

  Future<FriendReferralOutcome> sync(GameState state) async {
    final deviceId = await _device();
    if (deviceId == null) return FriendReferralOutcome(state);
    var next = state;
    final own = next.metaDepth.friendCode;
    if (FriendReferral.isValidCode(own)) {
      try {
        await gateway.ensureCode(code: own, deviceId: deviceId);
        final count = await gateway.claimCount(code: own, deviceId: deviceId);
        if (count != null) {
          final paid = FriendReferral.withPayout(next, count);
          if (!identical(paid, next)) {
            final gained = paid.metaDepth.adTickets - next.metaDepth.adTickets;
            next = paid;
            return _maybeClaimReferrer(
              next,
              deviceId,
              toast: gained > 0 ? '$gained Ad Tickets from a friend' : null,
            );
          }
        }
      } catch (_) {}
    }
    return _maybeClaimReferrer(next, deviceId);
  }

  Future<FriendReferralOutcome> shareInvite(GameState state) async {
    var next = state;
    if (!FriendReferral.isValidCode(next.metaDepth.friendCode)) {
      next = next.copyWith(
        metaDepth: next.metaDepth.copyWith(
          friendCode: FriendReferral.newCode(_random),
        ),
      );
    }
    final code = next.metaDepth.friendCode;
    final deviceId = await _device();
    if (deviceId != null) {
      try {
        await gateway.ensureCode(code: code, deviceId: deviceId);
      } catch (_) {}
    }
    final send = share;
    if (send == null) {
      return FriendReferralOutcome(
        next,
        toast: 'Could not open the share sheet',
      );
    }
    try {
      await send(FriendReferral.shareMessage(code));
    } catch (_) {
      return FriendReferralOutcome(
        next,
        toast: 'Could not open the share sheet',
      );
    }
    return FriendReferralOutcome(next);
  }

  Future<FriendReferralOutcome> applyCode(GameState state, String raw) async {
    final code = FriendReferral.codeFromReferrer(raw);
    if (code == null) {
      return FriendReferralOutcome(state, toast: 'Enter a friend code');
    }
    if (code == state.metaDepth.friendCode) {
      return FriendReferralOutcome(state, toast: 'That is your own code');
    }
    if (state.metaDepth.friendInviteUsed.isNotEmpty) {
      return FriendReferralOutcome(
        state,
        toast: 'This phone already used a friend code',
      );
    }
    final deviceId = await _device();
    if (deviceId == null) {
      return FriendReferralOutcome(
        state,
        toast: 'Could not reach the friend list. Try again.',
      );
    }
    final FriendClaimStatus status;
    try {
      status = await gateway.claim(code: code, deviceId: deviceId);
    } catch (_) {
      return FriendReferralOutcome(
        state,
        toast: _toastFor(FriendClaimStatus.unavailable),
      );
    }
    return FriendReferralOutcome(
      _afterClaim(state, code, status, fromInstall: false),
      toast: _toastFor(status),
    );
  }

  Future<FriendReferralOutcome> _maybeClaimReferrer(
    GameState state,
    String deviceId, {
    String? toast,
  }) async {
    final md = state.metaDepth;
    if (md.friendInviteUsed.isNotEmpty) {
      return FriendReferralOutcome(state, toast: toast);
    }
    // tries == 0 with the flag set is an old empty read. Look again.
    if (md.friendReferrerChecked && md.friendReferrerTries > 0) {
      return FriendReferralOutcome(state, toast: toast);
    }
    final read = readInstallReferrer;
    if (read == null) {
      return FriendReferralOutcome(state, toast: toast);
    }
    String? referrer;
    try {
      referrer = await read();
    } catch (_) {
      return FriendReferralOutcome(_noteReferrerMiss(state), toast: toast);
    }
    final code = FriendReferral.codeFromReferrer(referrer);
    if (code == null) {
      final empty = referrer == null || referrer.trim().isEmpty;
      return FriendReferralOutcome(
        empty ? _noteReferrerMiss(state) : _noteReferrerDone(state),
        toast: toast,
      );
    }
    if (code == state.metaDepth.friendCode) {
      return FriendReferralOutcome(
        state.copyWith(
          metaDepth: state.metaDepth.copyWith(
            friendReferrerChecked: true,
            friendReferrerTries: math.max(1, state.metaDepth.friendReferrerTries),
            friendInviteUsed: code,
          ),
        ),
        toast: toast,
      );
    }
    final FriendClaimStatus status;
    try {
      status = await gateway.claim(code: code, deviceId: deviceId);
    } catch (_) {
      return FriendReferralOutcome(state, toast: toast);
    }
    if (status == FriendClaimStatus.unavailable) {
      return FriendReferralOutcome(state, toast: toast);
    }
    return FriendReferralOutcome(
      _afterClaim(state, code, status, fromInstall: true),
      toast: toast,
    );
  }

  GameState _afterClaim(
    GameState state,
    String code,
    FriendClaimStatus status, {
    required bool fromInstall,
  }) {
    if (status == FriendClaimStatus.full && fromInstall) {
      return _noteReferrerDone(state);
    }
    final stop = switch (status) {
      FriendClaimStatus.accepted ||
      FriendClaimStatus.duplicate ||
      FriendClaimStatus.self => true,
      _ => false,
    };
    if (!stop) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        friendInviteUsed: code,
        friendReferrerChecked: true,
        friendReferrerTries: math.max(1, state.metaDepth.friendReferrerTries),
      ),
    );
  }

  /// Empty or failed Play read. Keep looking until [FriendReferral.referrerGiveUpTries].
  GameState _noteReferrerMiss(GameState state) {
    final tries = state.metaDepth.friendReferrerTries + 1;
    final giveUp = tries >= FriendReferral.referrerGiveUpTries;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        friendReferrerTries: tries,
        friendReferrerChecked: giveUp,
      ),
    );
  }

  /// Referrer was present and was not a friend code, or the code is full.
  GameState _noteReferrerDone(GameState state) {
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        friendReferrerTries: math.max(1, state.metaDepth.friendReferrerTries + 1),
        friendReferrerChecked: true,
      ),
    );
  }

  String _toastFor(FriendClaimStatus status) => switch (status) {
    FriendClaimStatus.accepted =>
      'Code applied. Your friend gets 10 Ad Tickets.',
    FriendClaimStatus.duplicate => 'This phone already used a friend code',
    FriendClaimStatus.self => 'That is your own code',
    FriendClaimStatus.full => 'That friend already has enough invites',
    FriendClaimStatus.unknownCode => 'Unknown friend code',
    FriendClaimStatus.unavailable =>
      'Could not reach the friend list. Try again.',
  };

  Future<String?> _device() async {
    final read = readDeviceId;
    if (read == null) return null;
    try {
      final id = await read();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (_) {
      return null;
    }
  }
}
