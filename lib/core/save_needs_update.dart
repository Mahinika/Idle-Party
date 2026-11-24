/// A save written by a newer build. Callers must leave the bytes alone.
class SaveNeedsAppUpdate implements Exception {
  const SaveNeedsAppUpdate();

  static const String message = 'Update the app to load this save';

  @override
  String toString() => message;
}
