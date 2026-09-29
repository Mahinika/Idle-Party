import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'friend_referral.dart';

/// Firebase friend list. Soft-fails when Auth or Firestore is off.
class FirestoreFriendReferralGateway implements FriendReferralGateway {
  bool get _androidLive {
    if (test_env.inFlutterTestProcess()) return false;
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<FirebaseFirestore?> _db() async {
    if (!_androidLive) return null;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      return FirebaseFirestore.instance;
    } catch (e, st) {
      debugPrint('Friend list unavailable: $e\n$st');
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _codeRef(
    FirebaseFirestore db,
    String code,
  ) => db.collection('friendCodes').doc(code);

  @override
  Future<void> ensureCode({
    required String code,
    required String deviceId,
  }) async {
    final db = await _db();
    if (db == null) return;
    final ref = _codeRef(db, code);
    try {
      final snap = await ref.get();
      if (snap.exists) return;
      await ref.set({
        'ownerDevice': deviceId,
        'claims': 0,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('Friend code register failed: $e\n$st');
    }
  }

  @override
  Future<int?> claimCount({
    required String code,
    required String deviceId,
  }) async {
    final db = await _db();
    if (db == null) return null;
    try {
      final snap = await _codeRef(db, code).get();
      if (!snap.exists) return 0;
      final n = (snap.data()?['claims'] as num?)?.toInt() ?? 0;
      return n.clamp(0, FriendReferral.maxFriends);
    } catch (e, st) {
      debugPrint('Friend code read failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<FriendClaimStatus> claim({
    required String code,
    required String deviceId,
  }) async {
    final db = await _db();
    if (db == null) return FriendClaimStatus.unavailable;
    final codeRef = _codeRef(db, code);
    final claimRef = db.collection('friendClaims').doc(deviceId);
    try {
      return await db.runTransaction((tx) async {
        final existing = await tx.get(claimRef);
        if (existing.exists) return FriendClaimStatus.duplicate;
        final codeSnap = await tx.get(codeRef);
        if (!codeSnap.exists) return FriendClaimStatus.unknownCode;
        final owner = codeSnap.data()?['ownerDevice'] as String? ?? '';
        if (owner == deviceId) return FriendClaimStatus.self;
        final claims = (codeSnap.data()?['claims'] as num?)?.toInt() ?? 0;
        if (claims >= FriendReferral.maxFriends) return FriendClaimStatus.full;
        tx.update(codeRef, {'claims': claims + 1});
        tx.set(claimRef, {
          'code': code,
          'device': deviceId,
          'at': FieldValue.serverTimestamp(),
        });
        return FriendClaimStatus.accepted;
      });
    } catch (e, st) {
      debugPrint('Friend claim failed: $e\n$st');
      return FriendClaimStatus.unavailable;
    }
  }
}
