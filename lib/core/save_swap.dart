import 'package:flutter/foundation.dart';

import 'game_storage.dart';

/// What a durable swap did to the two parties.
///
/// [committed] means the active file is the new party and the displaced file
/// is the parked one. The caller must adopt that active file: a false or
/// thrown result after the bytes landed is not a reason to keep the old
/// memory and autosave over it.
///
/// [aborted] means the active file was never replaced. The caller keeps the
/// party it already had in memory.
///
/// [unresolved] means a journal still holds a party that must not be
/// overwritten. The caller must not autosave, upload, or start another swap.
enum SaveSwapOutcome { idle, committed, aborted, unresolved }

/// Crash-safe replace of the active slot, and of the two device copies.
///
/// A process kill between two preference writes used to publish one party
/// and delete the other's only copy. Each step is a named phase plus the
/// bytes needed to finish it. [recover] is safe to call on every boot: with
/// no journal it returns [SaveSwapOutcome.idle].
abstract final class SaveSwap {
  static Future<SaveSwapOutcome> recover(
    GameStorage storage, {
    int? slot,
  }) async {
    try {
      return await _recover(storage, slot: slot);
    } catch (error, stack) {
      debugPrint('SaveSwap recover failed: $error\n$stack');
      return SaveSwapOutcome.unresolved;
    }
  }

  /// Move an r1/r2 global journal onto the slot whose bytes prove it.
  ///
  /// Slot 0 still uses the unsuffixed keys, so it needs no move. Slots 1–4
  /// written by those test builds used the global journal while the party
  /// lived in the slot. Returns true when a global journal remains and no
  /// single slot can be proven, so the caller keeps saving off. Never
  /// deletes those bytes and never assigns them to a slot that does not
  /// match.
  static Future<bool> migrateLegacyGlobalJournal(GameStorage storage) async {
    try {
      return await _migrateLegacy(storage);
    } catch (error, stack) {
      debugPrint('SaveSwap legacy journal failed: $error\n$stack');
      return true;
    }
  }

  static Future<SaveSwapOutcome> commitReplacement({
    required GameStorage storage,
    required String nextJson,
    required String previousJson,
  }) {
    final slot = storage.activeSlotIndex;
    return _guard(
      storage,
      slot,
      () => _commitReplacement(
        storage: storage,
        activeJson: nextJson,
        displacedJson: previousJson,
        slot: slot,
      ),
    );
  }

  /// Swap the active file with the displaced device copy.
  ///
  /// Refuses while a journal already exists. A second attempt must not
  /// replace the hold that is the only copy of the parked party.
  static Future<SaveSwapOutcome> commitSwap({
    required GameStorage storage,
    required String newActiveJson,
    required String newDisplacedJson,
  }) {
    final slot = storage.activeSlotIndex;
    return _guard(
      storage,
      slot,
      () => _commitSwap(
        storage: storage,
        activeJson: newDisplacedJson,
        displacedJson: newActiveJson,
        slot: slot,
      ),
    );
  }

  static Future<SaveSwapOutcome> _guard(
    GameStorage storage,
    int slot,
    Future<SaveSwapOutcome> Function() body,
  ) async {
    String? before;
    try {
      before = await storage.loadActiveRaw();
    } catch (error, stack) {
      debugPrint('SaveSwap could not read before the swap: $error\n$stack');
      return SaveSwapOutcome.unresolved;
    }
    try {
      return await body();
    } catch (error, stack) {
      debugPrint('SaveSwap failed: $error\n$stack');
      try {
        await storage.reloadDurable();
        final journal = await storage.loadExtra(
          GameStorage.journalKeyFor(slot),
        );
        final active = await storage.loadActiveRaw();
        if (journal == null && active == before) {
          return SaveSwapOutcome.aborted;
        }
        final outcome = await recover(storage, slot: slot);
        if (outcome == SaveSwapOutcome.idle) {
          // The journal is gone, but this call did not prove which party
          // landed. Idle would let the caller autosave old memory over it.
          return SaveSwapOutcome.unresolved;
        }
        return outcome;
      } catch (nested, nestedStack) {
        debugPrint('SaveSwap reconcile failed: $nested\n$nestedStack');
        return SaveSwapOutcome.unresolved;
      }
    }
  }

  static Future<bool> _migrateLegacy(GameStorage storage) async {
    final phase = await storage.loadExtra(GameStorage.journalKey);
    if (phase == null) return false;
    // Slot 0 already uses these unsuffixed keys. Recover owns that journal.
    if (storage.activeSlotIndex <= 0) return false;
    final staging = await storage.loadExtra(GameStorage.stagingKey);
    final hold = await storage.loadExtra(GameStorage.holdKey);
    final displaced = await storage.loadExtra(GameStorage.displacedKey);
    if (staging == null && hold == null && displaced == null) {
      final removed = await storage.writeExtra(GameStorage.journalKey, null);
      await storage.reloadDurable();
      return !removed ||
          await storage.loadExtra(GameStorage.journalKey) != null;
    }
    if (await _finishFinishedMigration(
      storage,
      staging: staging,
      hold: hold,
      displaced: displaced,
    )) {
      return await storage.loadExtra(GameStorage.journalKey) != null;
    }
    final evidence = <String>{?staging, ?hold, ?displaced};
    final matches = <int>[];
    for (var slot = 0; slot < GameStorage.slotCount; slot++) {
      final raw = await storage.loadSlotRaw(slot);
      if (raw != null && evidence.contains(raw)) matches.add(slot);
    }
    final started = <int>[];
    for (var slot = 1; slot < GameStorage.slotCount; slot++) {
      final own = await storage.loadExtra(GameStorage.journalKeyFor(slot));
      if (own != null) started.add(slot);
    }
    if (started.length > 1) return true;
    int? target;
    if (started.length == 1) {
      final slot = started.single;
      final raw = await storage.loadSlotRaw(slot);
      final belongs =
          (raw != null && evidence.contains(raw)) ||
          await _slotHoldsPayload(
            storage,
            slot,
            staging: staging,
            hold: hold,
            displaced: displaced,
          );
      if (!belongs) return true;
      target = slot;
    }
    if (target == null) {
      // Two slots with the same bytes are not a unique owner. The current
      // slot is not a tie-break. Slot 0 already owns the unsuffixed keys.
      if (matches.length != 1) return true;
      if (matches.single <= 0) return false;
      target = matches.single;
    }
    final copied =
        await _copyProven(
          storage,
          GameStorage.stagingKey,
          GameStorage.stagingKeyFor(target),
        ) &&
        await _copyProven(
          storage,
          GameStorage.holdKey,
          GameStorage.holdKeyFor(target),
        ) &&
        await _copyProven(
          storage,
          GameStorage.displacedKey,
          GameStorage.displacedKeyFor(target),
        ) &&
        await _copyProven(
          storage,
          GameStorage.journalKey,
          GameStorage.journalKeyFor(target),
        );
    if (!copied) return true;
    await storage.reloadDurable();
    if (await storage.loadExtra(GameStorage.journalKeyFor(target)) == null) {
      return true;
    }
    for (final key in [
      GameStorage.stagingKey,
      GameStorage.holdKey,
      GameStorage.displacedKey,
      GameStorage.journalKey,
    ]) {
      if (!await storage.writeExtra(key, null)) return true;
    }
    await storage.reloadDurable();
    return await storage.loadExtra(GameStorage.journalKey) != null;
  }

  /// A slot that already holds every remaining global payload finished the
  /// copy. The leftover marker can go. A payload that is not on that slot
  /// stays, so this does not guess.
  static Future<bool> _finishFinishedMigration(
    GameStorage storage, {
    required String? staging,
    required String? hold,
    required String? displaced,
  }) async {
    for (var slot = 1; slot < GameStorage.slotCount; slot++) {
      if (await storage.loadExtra(GameStorage.journalKeyFor(slot)) != null) {
        continue;
      }
      if (!await _slotHoldsPayload(
        storage,
        slot,
        staging: staging,
        hold: hold,
        displaced: displaced,
      )) {
        continue;
      }
      for (final key in [
        GameStorage.stagingKey,
        GameStorage.holdKey,
        GameStorage.displacedKey,
        GameStorage.journalKey,
      ]) {
        if (!await storage.writeExtra(key, null)) return false;
      }
      await storage.reloadDurable();
      return true;
    }
    return false;
  }

  static Future<bool> _slotHoldsPayload(
    GameStorage storage,
    int slot, {
    required String? staging,
    required String? hold,
    required String? displaced,
  }) async {
    final raw = await storage.loadSlotRaw(slot);
    final staged = await storage.loadExtra(GameStorage.stagingKeyFor(slot));
    final held = await storage.loadExtra(GameStorage.holdKeyFor(slot));
    final parked = await storage.loadExtra(GameStorage.displacedKeyFor(slot));
    var saw = false;
    bool covered(String? global, String? local) {
      if (global == null) return true;
      saw = true;
      return local == global || raw == global;
    }

    final ok =
        covered(staging, staged) &&
        covered(hold, held) &&
        covered(displaced, parked);
    return saw && ok;
  }

  /// Copy [from] to [to] when [to] is empty or already the same bytes.
  /// A different existing value is left alone.
  static Future<bool> _copyProven(
    GameStorage storage,
    String from,
    String to,
  ) async {
    final value = await storage.loadExtra(from);
    if (value == null) return true;
    final existing = await storage.loadExtra(to);
    if (existing != null && existing != value) return false;
    if (existing == value) return true;
    if (!await storage.writeExtra(to, value)) return false;
    await storage.reloadDurable();
    return await storage.loadExtra(to) == value;
  }

  static Future<SaveSwapOutcome> _recover(
    GameStorage storage, {
    int? slot,
  }) async {
    await storage.reloadDurable();
    final index = slot ?? storage.activeSlotIndex;
    final phase = await storage.loadExtra(GameStorage.journalKeyFor(index));
    if (phase == null) return SaveSwapOutcome.idle;
    final staging = await storage.loadExtra(GameStorage.stagingKeyFor(index));
    final hold = await storage.loadExtra(GameStorage.holdKeyFor(index));
    final displaced = await storage.loadExtra(
      GameStorage.displacedKeyFor(index),
    );
    final active = await storage.loadSlotRaw(index);

    if (phase == 'commit') {
      if (active != null && staging != null && active == staging) {
        return _finishClear(storage, index, SaveSwapOutcome.committed);
      }
      return _finishClear(storage, index, SaveSwapOutcome.aborted);
    }

    if (phase == 'park') {
      return _finishClear(storage, index, SaveSwapOutcome.aborted);
    }

    if (phase == 'swap-stage') {
      // Active already equals staging: the forward write landed and the
      // hold is the only remaining copy of the live party. Publishing that
      // hold is the retry. Clearing it as an abort deletes that party.
      if (staging != null &&
          hold != null &&
          active != null &&
          active == staging) {
        return _publishHeldParty(storage, index, hold);
      }
      if (staging != null &&
          hold != null &&
          active != null &&
          active != hold) {
        return _completeOpenSwap(storage, index, staging: staging, hold: hold);
      }
      return _finishClear(storage, index, SaveSwapOutcome.aborted);
    }

    if (phase == 'swap-commit' || phase == 'swap-publish') {
      if (hold != null &&
          displaced == hold &&
          active != null &&
          active != hold) {
        // Staging can already be gone. Both finals are on disk.
        return _finishClear(storage, index, SaveSwapOutcome.committed);
      }
      if (staging == null &&
          hold == null &&
          active != null &&
          displaced != null &&
          active != displaced &&
          phase == 'swap-publish') {
        // Cleanup deleted staging and hold after the publish. The journal
        // is the only leftover. The two parties are already in place.
        return _finishClear(storage, index, SaveSwapOutcome.committed);
      }
      if (staging == null && hold == null && phase == 'swap-commit') {
        // Cleanup started before the active write. Active is the pre-image.
        return _finishClear(storage, index, SaveSwapOutcome.aborted);
      }
      if (staging != null && active == staging && hold != null) {
        return _publishHeldParty(storage, index, hold);
      }
      if (hold != null && active == hold && active != staging) {
        return _finishClear(storage, index, SaveSwapOutcome.aborted);
      }
      if (staging != null &&
          hold != null &&
          active != null &&
          active != staging &&
          active != hold) {
        return _completeOpenSwap(storage, index, staging: staging, hold: hold);
      }
      return SaveSwapOutcome.unresolved;
    }

    return SaveSwapOutcome.unresolved;
  }

  /// Finish a swap whose live party (hold) differs from the last autosave
  /// (active). Leaving this unresolved forever dropped the live party on
  /// the next session. The hold becomes the device copy and staging becomes
  /// active. A failed write deletes nothing.
  /// Write the held party into the parked copy, then drop the journal.
  /// A failed publish leaves the hold in place.
  static Future<SaveSwapOutcome> _publishHeldParty(
    GameStorage storage,
    int index,
    String hold,
  ) async {
    final parked = await storage.loadExtra(GameStorage.displacedKeyFor(index));
    if (parked != hold) {
      final published = await storage.writeExtra(
        GameStorage.displacedKeyFor(index),
        hold,
      );
      await storage.reloadDurable();
      final durable = await storage.loadExtra(
        GameStorage.displacedKeyFor(index),
      );
      if (!published || durable != hold) return SaveSwapOutcome.unresolved;
    }
    return _finishClear(storage, index, SaveSwapOutcome.committed);
  }

  static Future<SaveSwapOutcome> _completeOpenSwap(
    GameStorage storage,
    int slot, {
    required String staging,
    required String hold,
  }) async {
    if (storage.activeSlotIndex != slot) return SaveSwapOutcome.unresolved;
    // Name the commit before replacing active. A kill after the active
    // write is then the swap-commit path, which publishes the hold.
    // Leaving the phase on swap-stage made the next retry treat the new
    // active as an abort and delete the hold.
    final marked = await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'swap-commit',
    );
    await storage.reloadDurable();
    if (!marked ||
        await storage.loadExtra(GameStorage.journalKeyFor(slot)) !=
            'swap-commit') {
      return SaveSwapOutcome.unresolved;
    }
    final wroteActive = await storage.writeActiveRaw(staging);
    await storage.reloadDurable();
    if (!wroteActive || await storage.loadActiveRaw() != staging) {
      return SaveSwapOutcome.unresolved;
    }
    final wroteHold = await storage.writeExtra(
      GameStorage.displacedKeyFor(slot),
      hold,
    );
    await storage.reloadDurable();
    if (!wroteHold ||
        await storage.loadExtra(GameStorage.displacedKeyFor(slot)) != hold) {
      return SaveSwapOutcome.unresolved;
    }
    return _finishClear(storage, slot, SaveSwapOutcome.committed);
  }

  /// A recovery that finished the swap is the result. Anything else that is
  /// not still unresolved is an abort: the caller keeps the party it had.
  static SaveSwapOutcome _keepCommitted(SaveSwapOutcome outcome) {
    if (outcome == SaveSwapOutcome.committed ||
        outcome == SaveSwapOutcome.unresolved) {
      return outcome;
    }
    return SaveSwapOutcome.aborted;
  }

  static Future<SaveSwapOutcome> _finishClear(
    GameStorage storage,
    int slot,
    SaveSwapOutcome whenClear,
  ) async {
    if (!await _clear(storage, slot)) return SaveSwapOutcome.unresolved;
    return whenClear;
  }

  static Future<SaveSwapOutcome> _commitReplacement({
    required GameStorage storage,
    required String activeJson,
    required String displacedJson,
    required int slot,
  }) async {
    if (!_sameSlot(storage, slot)) return SaveSwapOutcome.aborted;
    if (await storage.loadExtra(GameStorage.journalKeyFor(slot)) != null) {
      return SaveSwapOutcome.unresolved;
    }
    // A parked party that is neither the current file nor the incoming
    // file is a third party. Replacing it would destroy that copy. Refuse
    // before any write so a crash cannot lose it either.
    final existingParked = await storage.loadExtra(
      GameStorage.displacedKeyFor(slot),
    );
    if (existingParked != null &&
        existingParked != activeJson &&
        existingParked != displacedJson) {
      return SaveSwapOutcome.aborted;
    }
    final staged = await storage.writeExtra(
      GameStorage.stagingKeyFor(slot),
      activeJson,
    );
    final marked = await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'park',
    );
    if (!staged || !marked) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    final parked = await storage.writeExtra(
      GameStorage.displacedKeyFor(slot),
      displacedJson,
    );
    if (!parked) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    await storage.reloadDurable();
    final displaced = await storage.loadExtra(
      GameStorage.displacedKeyFor(slot),
    );
    if (displaced != displacedJson) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    final commit = await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'commit',
    );
    if (!commit) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    final wrote = await storage.writeActiveRaw(activeJson);
    await storage.reloadDurable();
    final active = await storage.loadActiveRaw();
    if (!wrote || active != activeJson) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    return _clearAndProve(
      storage,
      slot,
      activeJson: activeJson,
      displacedJson: displacedJson,
    );
  }

  static Future<SaveSwapOutcome> _commitSwap({
    required GameStorage storage,
    required String activeJson,
    required String displacedJson,
    required int slot,
  }) async {
    if (!_sameSlot(storage, slot)) return SaveSwapOutcome.aborted;
    if (await storage.loadExtra(GameStorage.journalKeyFor(slot)) != null) {
      return SaveSwapOutcome.unresolved;
    }
    final staged = await storage.writeExtra(
      GameStorage.stagingKeyFor(slot),
      displacedJson,
    );
    final held = await storage.writeExtra(
      GameStorage.holdKeyFor(slot),
      activeJson,
    );
    final marked = await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'swap-stage',
    );
    if (!staged || !held || !marked) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    final committing = await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'swap-commit',
    );
    if (!committing) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    final wrote = await storage.writeActiveRaw(displacedJson);
    await storage.reloadDurable();
    final active = await storage.loadActiveRaw();
    if (!wrote || active != displacedJson) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    final published = await storage.writeExtra(
      GameStorage.journalKeyFor(slot),
      'swap-publish',
    );
    if (!published) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    final parked = await storage.writeExtra(
      GameStorage.displacedKeyFor(slot),
      activeJson,
    );
    await storage.reloadDurable();
    final displaced = await storage.loadExtra(
      GameStorage.displacedKeyFor(slot),
    );
    if (!parked || displaced != activeJson) {
      return _keepCommitted(await recover(storage, slot: slot));
    }
    return _clearAndProve(
      storage,
      slot,
      activeJson: displacedJson,
      displacedJson: activeJson,
    );
  }

  /// Cleanup runs only after both parties are in their final files.
  /// A throw from the reload or the readback is reconciled against those
  /// files. When they match, the swap is committed even though the call
  /// threw. When they cannot be read, the result stays unresolved so the
  /// next autosave cannot overwrite them.
  static Future<SaveSwapOutcome> _clearAndProve(
    GameStorage storage,
    int slot, {
    required String activeJson,
    required String displacedJson,
  }) async {
    try {
      if (!await _clear(storage, slot)) return SaveSwapOutcome.unresolved;
      final durableActive = await storage.loadActiveRaw();
      final durableDisplaced = await storage.loadExtra(
        GameStorage.displacedKeyFor(slot),
      );
      if (durableActive == activeJson && durableDisplaced == displacedJson) {
        return SaveSwapOutcome.committed;
      }
      return SaveSwapOutcome.unresolved;
    } catch (error, stack) {
      debugPrint(
        'SaveSwap cleanup failed after the parties landed: $error\n$stack',
      );
      try {
        await storage.reloadDurable();
        final journal = await storage.loadExtra(
          GameStorage.journalKeyFor(slot),
        );
        final active = await storage.loadActiveRaw();
        final displaced = await storage.loadExtra(
          GameStorage.displacedKeyFor(slot),
        );
        if (journal == null &&
            active == activeJson &&
            displaced == displacedJson) {
          return SaveSwapOutcome.committed;
        }
      } catch (nested, nestedStack) {
        debugPrint(
          'SaveSwap could not re-read the parties: $nested\n$nestedStack',
        );
      }
      return SaveSwapOutcome.unresolved;
    }
  }

  static bool _sameSlot(GameStorage storage, int slot) =>
      storage.activeSlotIndex == slot;

  static Future<bool> _clear(GameStorage storage, int slot) async {
    final stagingKey = GameStorage.stagingKeyFor(slot);
    final holdKey = GameStorage.holdKeyFor(slot);
    final journalKey = GameStorage.journalKeyFor(slot);
    if (!await storage.writeExtra(stagingKey, null)) return false;
    if (!await storage.writeExtra(holdKey, null)) return false;
    if (!await storage.writeExtra(journalKey, null)) return false;
    await storage.reloadDurable();
    final staging = await storage.loadExtra(stagingKey);
    final hold = await storage.loadExtra(holdKey);
    final journal = await storage.loadExtra(journalKey);
    return staging == null && hold == null && journal == null;
  }
}
