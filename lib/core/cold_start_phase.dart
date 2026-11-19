/// Which screen to show after a cold-start boot finishes.
///
/// The mandatory Play update gate is checked before this and stays in
/// front when it blocks. Recovery also wins. A single loaded save goes
/// straight into play so a process kill (common when the player leaves
/// for a moment) does not replay the studio card and title menu.
enum ColdStartPhase { saveRecovery, startMenu, bootIntro, play }

/// Decides the first screen after [GameDirector.boot] on a cold start.
ColdStartPhase decideColdStartPhase({
  required bool showIntro,
  required bool saveRecoveryBlocked,
  required int validSaveCount,
  required bool hasExistingSave,
}) {
  if (saveRecoveryBlocked) return ColdStartPhase.saveRecovery;
  if (!showIntro) return ColdStartPhase.play;
  if (validSaveCount <= 0) return ColdStartPhase.startMenu;
  if (validSaveCount == 1 && hasExistingSave) return ColdStartPhase.play;
  return ColdStartPhase.bootIntro;
}
