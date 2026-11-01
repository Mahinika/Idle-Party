/// Consent Mode v2 after the UMP check has finished.
///
/// [granted] follows `ConsentInformation.canRequestAds()`. The four Google
/// signals share that one answer: the UMP plugin has no separate purpose
/// bits, and the privacy form is Google's managed GDPR message.
///
/// Analytics collection stays on after the check, including a decline or a
/// timeout, so a denied answer can still send consent-mode pings without an
/// advertising ID. Crashlytics stays off when the player says no.
class MeasurementConsent {
  const MeasurementConsent({required this.granted});

  final bool granted;

  bool get analyticsStorage => granted;
  bool get adStorage => granted;
  bool get adUserData => granted;
  bool get adPersonalization => granted;

  /// Always on once UMP has returned.
  bool get analyticsCollection => true;

  bool get crashlytics => granted;
}
