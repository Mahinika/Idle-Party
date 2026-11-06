import 'game_storage.dart';

/// Crash-safe replace of the active save.
///
/// The device copy is written before the active slot changes, and it is not
/// replaced with the incoming file until the active slot has been read back.
/// A failed write leaves the previous bytes in place and returns false.
abstract final class SaveSwap {
  static Future<void> recover(GameStorage storage) async {
    final phase = await storage.loadExtra(GameStorage.journalKey);
    if (phase == null) return;
    final active = await storage.loadActiveRaw();
    final staging = await storage.loadExtra(GameStorage.stagingKey);
    if (phase == 'park' || phase == 'swap-stage') {
      await storage.writeExtra(GameStorage.stagingKey, null);
      await storage.writeExtra(GameStorage.holdKey, null);
      await storage.writeExtra(GameStorage.journalKey, null);
      return;
    }
    if (phase == 'commit') {
      await storage.writeExtra(GameStorage.stagingKey, null);
      await storage.writeExtra(GameStorage.journalKey, null);
      return;
    }
    if (phase == 'swap-commit' || phase == 'swap-publish') {
      final hold = await storage.loadExtra(GameStorage.holdKey);
      if (staging != null &&
          active != null &&
          active == staging &&
          hold != null) {
        final published = await storage.writeExtra(
          GameStorage.displacedKey,
          hold,
        );
        if (!published) return;
      }
      await storage.writeExtra(GameStorage.stagingKey, null);
      await storage.writeExtra(GameStorage.holdKey, null);
      await storage.writeExtra(GameStorage.journalKey, null);
    }
  }

  /// Parks [previousJson] then commits [nextJson] as the active slot.
  ///
  /// False means the active slot was not replaced. A device copy that was
  /// already different from both files is left untouched.
  static Future<bool> commitReplacement({
    required GameStorage storage,
    required String nextJson,
    required String previousJson,
  }) async {
    if (nextJson.isEmpty) return false;
    if (previousJson.isNotEmpty) {
      final parked = await storage.loadExtra(GameStorage.displacedKey);
      if (parked != null && parked != previousJson && parked != nextJson) {
        return false;
      }
      if (!await storage.writeExtra(GameStorage.journalKey, 'park')) {
        return false;
      }
      if (!await storage.writeExtra(GameStorage.displacedKey, previousJson)) {
        await storage.writeExtra(GameStorage.journalKey, null);
        return false;
      }
    }
    if (!await storage.writeExtra(GameStorage.journalKey, 'commit')) {
      return false;
    }
    if (!await storage.writeExtra(GameStorage.stagingKey, nextJson)) {
      await recover(storage);
      return false;
    }
    if (!await storage.writeActiveRaw(nextJson)) {
      await recover(storage);
      return false;
    }
    final readBack = await storage.loadActiveRaw();
    if (readBack != nextJson) {
      await recover(storage);
      return false;
    }
    final stagingGone = await storage.writeExtra(GameStorage.stagingKey, null);
    final journalGone = await storage.writeExtra(GameStorage.journalKey, null);
    if (!stagingGone || !journalGone) return false;
    final active = await storage.loadActiveRaw();
    final displaced = await storage.loadExtra(GameStorage.displacedKey);
    if (active != nextJson) return false;
    if (previousJson.isNotEmpty && displaced != previousJson) return false;
    return true;
  }

  /// Active becomes [newActiveJson]. The previous active bytes become the
  /// device copy only after [newActiveJson] has been read back.
  static Future<bool> commitSwap({
    required GameStorage storage,
    required String newActiveJson,
    required String newDisplacedJson,
  }) async {
    if (newActiveJson.isEmpty || newDisplacedJson.isEmpty) return false;
    final displaced = await storage.loadExtra(GameStorage.displacedKey);
    final active = await storage.loadActiveRaw();
    if (displaced == null || active == null) return false;
    if (!await storage.writeExtra(GameStorage.journalKey, 'swap-stage')) {
      return false;
    }
    if (!await storage.writeExtra(GameStorage.holdKey, newDisplacedJson)) {
      await storage.writeExtra(GameStorage.journalKey, null);
      return false;
    }
    if (!await storage.writeExtra(GameStorage.stagingKey, newActiveJson)) {
      await storage.writeExtra(GameStorage.journalKey, null);
      await storage.writeExtra(GameStorage.holdKey, null);
      return false;
    }
    if (!await storage.writeExtra(GameStorage.journalKey, 'swap-commit')) {
      return false;
    }
    if (!await storage.writeActiveRaw(newActiveJson)) {
      await recover(storage);
      return false;
    }
    final readBack = await storage.loadActiveRaw();
    if (readBack != newActiveJson) {
      await recover(storage);
      return false;
    }
    if (!await storage.writeExtra(GameStorage.journalKey, 'swap-publish')) {
      await recover(storage);
      return false;
    }
    if (!await storage.writeExtra(GameStorage.displacedKey, newDisplacedJson)) {
      await recover(storage);
      final recoveredDisplaced = await storage.loadExtra(
        GameStorage.displacedKey,
      );
      final recoveredActive = await storage.loadActiveRaw();
      return recoveredActive == newActiveJson &&
          recoveredDisplaced == newDisplacedJson;
    }
    await storage.writeExtra(GameStorage.stagingKey, null);
    await storage.writeExtra(GameStorage.holdKey, null);
    await storage.writeExtra(GameStorage.journalKey, null);
    final finalActive = await storage.loadActiveRaw();
    final finalDisplaced = await storage.loadExtra(GameStorage.displacedKey);
    return finalActive == newActiveJson && finalDisplaced == newDisplacedJson;
  }
}
