import 'game_storage.dart';

/// What a save transaction proved about the two parties.
enum SaveSwapOutcome {
  /// No journal was present.
  idle,

  /// Both parties are in their final places and the journal is gone.
  /// The caller must adopt this active file. Memory must not stay on the
  /// pre-swap party, or the next autosave writes it over the committed file.
  committed,

  /// The active slot was not replaced. The previous parties are intact and
  /// the journal is gone. The caller keeps the in-memory party.
  aborted,

  /// A copy still exists only in the journal. The caller must not autosave,
  /// upload, or delete the side files. The next launch retries.
  unresolved,
}

/// Crash-safe replace of the active save.
///
/// Side files are per slot. A failed marker does not mean the swap failed:
/// the result is whatever a durable reload can prove. A publish that did not
/// land leaves the journal in place.
abstract final class SaveSwap {
  static Future<SaveSwapOutcome> recover(
    GameStorage storage, {
    int? slot,
  }) async {
    final index = slot ?? storage.activeSlotIndex;
    await storage.reloadDurable();
    final phase = await storage.loadExtra(GameStorage.journalKeyFor(index));
    if (phase == null) return SaveSwapOutcome.idle;
    final active = await storage.loadSlotRaw(index);
    final staging = await storage.loadExtra(GameStorage.stagingKeyFor(index));
    final hold = await storage.loadExtra(GameStorage.holdKeyFor(index));
    final displaced = await storage.loadExtra(
      GameStorage.displacedKeyFor(index),
    );

    if (phase == 'park' || phase == 'swap-stage') {
      final cleared = await _clear(
        storage,
        index,
        staging: true,
        hold: true,
        journal: true,
      );
      return cleared ? SaveSwapOutcome.aborted : SaveSwapOutcome.unresolved;
    }
    if (phase == 'commit') {
      final cleared = await _clear(
        storage,
        index,
        staging: true,
        hold: false,
        journal: true,
      );
      if (!cleared) return SaveSwapOutcome.unresolved;
      if (staging != null && active == staging) {
        return SaveSwapOutcome.committed;
      }
      return SaveSwapOutcome.aborted;
    }
    if (phase == 'swap-commit' || phase == 'swap-publish') {
      if (staging != null && active == staging && hold != null) {
        if (displaced != hold) {
          final published = await storage.writeExtra(
            GameStorage.displacedKeyFor(index),
            hold,
          );
          await storage.reloadDurable();
          final seen = await storage.loadExtra(
            GameStorage.displacedKeyFor(index),
          );
          if (!published || seen != hold) return SaveSwapOutcome.unresolved;
        }
        final cleared = await _clear(
          storage,
          index,
          staging: true,
          hold: true,
          journal: true,
        );
        if (!cleared) return SaveSwapOutcome.unresolved;
        final finalActive = await storage.loadSlotRaw(index);
        final finalDisplaced = await storage.loadExtra(
          GameStorage.displacedKeyFor(index),
        );
        if (finalActive == staging && finalDisplaced == hold) {
          return SaveSwapOutcome.committed;
        }
        return SaveSwapOutcome.unresolved;
      }
      if (hold != null && active == hold && active != staging) {
        final cleared = await _clear(
          storage,
          index,
          staging: true,
          hold: true,
          journal: true,
        );
        return cleared ? SaveSwapOutcome.aborted : SaveSwapOutcome.unresolved;
      }
      return SaveSwapOutcome.unresolved;
    }
    return SaveSwapOutcome.unresolved;
  }

  /// Parks [previousJson] then commits [nextJson] as the active slot.
  static Future<SaveSwapOutcome> commitReplacement({
    required GameStorage storage,
    required String nextJson,
    required String previousJson,
  }) async {
    if (nextJson.isEmpty) return SaveSwapOutcome.aborted;
    final slot = storage.activeSlotIndex;
    if (previousJson.isNotEmpty) {
      final parked = await storage.loadExtra(GameStorage.displacedKeyFor(slot));
      if (parked != null && parked != previousJson && parked != nextJson) {
        return SaveSwapOutcome.aborted;
      }
      if (!await _sameSlot(storage, slot)) return SaveSwapOutcome.unresolved;
      if (!await storage.writeExtra(GameStorage.journalKeyFor(slot), 'park')) {
        return SaveSwapOutcome.aborted;
      }
      if (!await storage.writeExtra(
        GameStorage.displacedKeyFor(slot),
        previousJson,
      )) {
        await recover(storage, slot: slot);
        return SaveSwapOutcome.aborted;
      }
    }
    if (!await _sameSlot(storage, slot)) return SaveSwapOutcome.unresolved;
    if (!await storage.writeExtra(GameStorage.journalKeyFor(slot), 'commit')) {
      return SaveSwapOutcome.unresolved;
    }
    if (!await storage.writeExtra(GameStorage.stagingKeyFor(slot), nextJson)) {
      return recover(storage, slot: slot);
    }
    final wrote = await storage.writeActiveRaw(nextJson);
    await storage.reloadDurable();
    if (!await _sameSlot(storage, slot)) return SaveSwapOutcome.unresolved;
    final readBack = await storage.loadActiveRaw();
    if (!wrote || readBack != nextJson) {
      final outcome = await recover(storage, slot: slot);
      if (outcome == SaveSwapOutcome.committed) return outcome;
      return outcome == SaveSwapOutcome.idle
          ? SaveSwapOutcome.aborted
          : outcome;
    }
    final cleared = await _clear(
      storage,
      slot,
      staging: true,
      hold: false,
      journal: true,
    );
    await storage.reloadDurable();
    final active = await storage.loadActiveRaw();
    final displaced = await storage.loadExtra(
      GameStorage.displacedKeyFor(slot),
    );
    if (active != nextJson) return SaveSwapOutcome.unresolved;
    if (previousJson.isNotEmpty && displaced != previousJson) {
      return SaveSwapOutcome.unresolved;
    }
    if (!cleared) return SaveSwapOutcome.unresolved;
    return SaveSwapOutcome.committed;
  }

  /// Active becomes [newActiveJson]. The previous active bytes become the
  /// device copy only after [newActiveJson] is durable.
  static Future<SaveSwapOutcome> commitSwap({
    required GameStorage storage,
    required String newActiveJson,
    required String newDisplacedJson,
  }) async {
    if (newActiveJson.isEmpty || newDisplacedJson.isEmpty) {
      return SaveSwapOutcome.aborted;
    }
    final slot = storage.activeSlotIndex;
    await storage.reloadDurable();
    final displaced = await storage.loadExtra(
      GameStorage.displacedKeyFor(slot),
    );
    final active = await storage.loadActiveRaw();
    if (displaced == null || active == null) return SaveSwapOutcome.aborted;
    if (!await _sameSlot(storage, slot)) return SaveSwapOutcome.unresolved;
    if (!await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'swap-stage',
    )) {
      return SaveSwapOutcome.aborted;
    }
    if (!await storage.writeExtra(
      GameStorage.holdKeyFor(slot),
      newDisplacedJson,
    )) {
      await recover(storage, slot: slot);
      return SaveSwapOutcome.aborted;
    }
    if (!await storage.writeExtra(
      GameStorage.stagingKeyFor(slot),
      newActiveJson,
    )) {
      await recover(storage, slot: slot);
      return SaveSwapOutcome.aborted;
    }
    if (!await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'swap-commit',
    )) {
      return SaveSwapOutcome.unresolved;
    }
    final wrote = await storage.writeActiveRaw(newActiveJson);
    await storage.reloadDurable();
    if (!await _sameSlot(storage, slot)) return SaveSwapOutcome.unresolved;
    final readBack = await storage.loadActiveRaw();
    if (!wrote || readBack != newActiveJson) {
      return recover(storage, slot: slot);
    }
    if (!await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'swap-publish',
    )) {
      return recover(storage, slot: slot);
    }
    if (!await storage.writeExtra(
      GameStorage.displacedKeyFor(slot),
      newDisplacedJson,
    )) {
      return recover(storage, slot: slot);
    }
    final cleared = await _clear(
      storage,
      slot,
      staging: true,
      hold: true,
      journal: true,
    );
    await storage.reloadDurable();
    final finalActive = await storage.loadActiveRaw();
    final finalDisplaced = await storage.loadExtra(
      GameStorage.displacedKeyFor(slot),
    );
    if (finalActive == newActiveJson && finalDisplaced == newDisplacedJson) {
      return cleared ? SaveSwapOutcome.committed : SaveSwapOutcome.unresolved;
    }
    return SaveSwapOutcome.unresolved;
  }

  static Future<bool> _sameSlot(GameStorage storage, int slot) async {
    await storage.reloadDurable();
    return storage.activeSlotIndex == slot;
  }

  static Future<bool> _clear(
    GameStorage storage,
    int slot, {
    required bool staging,
    required bool hold,
    required bool journal,
  }) async {
    var ok = true;
    if (staging) {
      ok =
          await storage.writeExtra(GameStorage.stagingKeyFor(slot), null) && ok;
    }
    if (hold) {
      ok = await storage.writeExtra(GameStorage.holdKeyFor(slot), null) && ok;
    }
    if (journal) {
      ok =
          await storage.writeExtra(GameStorage.journalKeyFor(slot), null) && ok;
    }
    await storage.reloadDurable();
    if (staging &&
        await storage.loadExtra(GameStorage.stagingKeyFor(slot)) != null) {
      ok = false;
    }
    if (hold && await storage.loadExtra(GameStorage.holdKeyFor(slot)) != null) {
      ok = false;
    }
    if (journal &&
        await storage.loadExtra(GameStorage.journalKeyFor(slot)) != null) {
      ok = false;
    }
    return ok;
  }
}
