import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/audio_failure_report.dart';
import 'package:idle_party/core/crash_report.dart';

void main() {
  test(
    'rendering overflow is non-fatal; other framework errors stay fatal',
    () {
      expect(
        flutterErrorIsNonFatal(
          FlutterErrorDetails(
            exception: Exception(
              'A RenderFlex overflowed by 1.00 pixels on the right.',
            ),
            library: 'rendering library',
          ),
        ),
        isTrue,
      );
      expect(
        flutterErrorIsNonFatal(
          FlutterErrorDetails(
            exception: Exception('A RenderFlex overflowed by 9.8 pixels.'),
            library: 'widgets library',
          ),
        ),
        isTrue,
      );
      expect(
        flutterErrorIsNonFatal(
          FlutterErrorDetails(
            exception: Exception(
              'A RenderFlex overflowed by 160.00 pixels on the bottom.',
            ),
            library: 'widgets library',
          ),
        ),
        isTrue,
        reason: 'wipe-retry dialog vertical overflow (Crashlytics 1.13.17)',
      );
      expect(
        flutterErrorIsNonFatal(
          FlutterErrorDetails(
            exception: Exception(
              'A RenderFlex overflowed by 6.3 pixels on the right.',
            ),
            library: 'rendering library',
          ),
        ),
        isTrue,
      );
      expect(
        flutterErrorIsNonFatal(
          FlutterErrorDetails(
            exception: StateError('boot'),
            library: 'widgets library',
          ),
        ),
        isFalse,
      );
      expect(
        flutterErrorIsNonFatal(
          FlutterErrorDetails(exception: StateError('zone')),
        ),
        isFalse,
      );
    },
  );

  test('uncaught async errors are non-fatal in Crashlytics', () {
    expect(
      platformAsyncErrorIsFatal(StateError('zone'), StackTrace.current),
      isFalse,
    );
    final fatals = <bool>[];
    AppAnalytics.debugRecordPlatformError =
        (Object error, StackTrace? stack, {required bool fatal}) {
          fatals.add(fatal);
        };
    addTearDown(() => AppAnalytics.debugRecordPlatformError = null);
    AppAnalytics.debugEmitPlatformError(
      StateError('async'),
      StackTrace.current,
    );
    expect(fatals, [false]);
    expect(
      flutterErrorIsNonFatal(
        FlutterErrorDetails(exception: StateError('boot')),
      ),
      isFalse,
    );
  });

  test('an audio path is claimed once per session', () {
    AudioFailureReport.debugReset();
    addTearDown(AudioFailureReport.debugReset);
    const path = 'assets/custom/audio/music/bed_dark.ogg';
    expect(AudioFailureReport.claim(path), isTrue);
    expect(AudioFailureReport.claim(path), isFalse);
    expect(AudioFailureReport.claim(''), isFalse);
  });

  test('audio failure report is a no-op under flutter test', () {
    AudioFailureReport.debugReset();
    addTearDown(AudioFailureReport.debugReset);
    const path = 'assets/custom/audio/music/bed_dark.ogg';
    expect(
      () => AudioFailureReport.loadFailed(
        path,
        StateError('load'),
        StackTrace.empty,
      ),
      returnsNormally,
    );
    expect(
      () => AudioFailureReport.playFailed(
        path,
        StateError('play'),
        StackTrace.empty,
      ),
      returnsNormally,
    );
    // The test process does not burn the slot, so a later claim still wins.
    expect(AudioFailureReport.claim(path), isTrue);
  });
}
