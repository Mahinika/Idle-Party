/// Consent Mode v2 after the UMP check has finished.
///
/// [granted] follows `ConsentInformation.canRequestAds()`. The four Google
/// signals share that one answer: the UMP plugin has no separate purpose
/// bits, and the privacy form is Google's managed GDPR message.
///
/// Analytics collection stays on after the check, including a decline or a
/// timeout, so a denied answer can still send consent-mode pings without an
/// advertising ID. Crash reports stay on for a decline too. They do not
/// include an advertising ID.
class MeasurementConsent {
  const MeasurementConsent({required this.granted});

  final bool granted;

  bool get analyticsStorage => granted;
  bool get adStorage => granted;
  bool get adUserData => granted;
  bool get adPersonalization => granted;

  /// Always on once UMP has returned.
  bool get analyticsCollection => true;

  /// On for a decline. No advertising ID is attached.
  bool get crashlytics => true;
}
