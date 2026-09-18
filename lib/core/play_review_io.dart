import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import 'flutter_test_env_io.dart' as test_env;

/// Play In-App Review. Tests / missing Play → false, never throws.
Future<bool> requestPlayInAppReview() async {
  if (test_env.inFlutterTestProcess()) return false;
  try {
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return false;
    await review.requestReview();
    return true;
  } catch (e, st) {
    debugPrint('PlayReview request failed: $e\n$st');
    return false;
  }
}
