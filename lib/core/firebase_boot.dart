import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// One shared Firebase app init for Analytics, Remote Config, and Firestore.
abstract final class FirebaseBoot {
  static Completer<void>? _inFlight;

  static Future<void> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    final existing = _inFlight;
    if (existing != null) return existing.future;
    final flight = Completer<void>();
    _inFlight = flight;
    try {
      await Firebase.initializeApp();
      flight.complete();
    } catch (e, st) {
      flight.completeError(e, st);
      rethrow;
    } finally {
      if (identical(_inFlight, flight)) _inFlight = null;
    }
  }
}