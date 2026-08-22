/// Web / non-IO: Play In-App Updates are Android-only.
Future<int?> probeAvailableVersionCode() async => null;

Future<bool> startImmediatePlayUpdate() async => false;

Future<bool> startFlexiblePlayUpdate() async => false;
