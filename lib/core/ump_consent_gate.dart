import 'dart:async';

/// Callbacks for one UMP consent-info update.
class UmpUpdateCallbacks {
  const UmpUpdateCallbacks({required this.onSuccess, required this.onError});

  final void Function() onSuccess;
  final void Function(Object error) onError;
}

/// Runs a UMP update, then the consent form when [showFormOnSuccess] is set.
///
/// [updateTimeout] covers only [requestUpdate]. Time on the form does not
/// trip that timer. After the form closes, [resync] runs so consent and
/// Remote Config see the answer. An update that arrives after the timeout
/// still shows the form and runs [resync] once.
Future<void> runUmpConsentGate({
  required void Function(UmpUpdateCallbacks callbacks) requestUpdate,
  required Future<void> Function() showForm,
  required Future<void> Function() resync,
  Duration updateTimeout = const Duration(seconds: 10),
  bool showFormOnSuccess = true,
}) async {
  final updated = Completer<bool>();
  var settled = false;
  var timedOut = false;
  var lateStarted = false;

  Future<void> formThenResync() async {
    await showForm();
    await resync();
  }

  requestUpdate(
    UmpUpdateCallbacks(
      onSuccess: () {
        if (!settled) {
          settled = true;
          if (!updated.isCompleted) updated.complete(true);
          return;
        }
        if (timedOut && showFormOnSuccess && !lateStarted) {
          lateStarted = true;
          unawaited(formThenResync());
        }
      },
      onError: (Object error) {
        if (settled) return;
        settled = true;
        if (!updated.isCompleted) updated.complete(false);
      },
    ),
  );

  final ok = await updated.future.timeout(
    updateTimeout,
    onTimeout: () {
      settled = true;
      timedOut = true;
      return false;
    },
  );
  if (!ok || !showFormOnSuccess) return;
  await formThenResync();
}
