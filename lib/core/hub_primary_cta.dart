import 'hub_chase.dart';
import 'hub_endgame_act.dart';

/// Resolves hub brown/grey CTAs so TODAY chase owns the primary button.
///
/// Enter-family chases fold into ENTER / ENTER KEY / DAILY RUN.
/// Hunt and claim chases (Gauntlet, vault, week→GAUNTLET, …) stay primary
/// on the ENDGAME board; on PATH the selected zone's ENTER is primary.
/// plain ENTER becomes secondary when the zone is unlocked.
class HubPrimaryCta {
  const HubPrimaryCta({
    required this.primaryLabel,
    required this.hideInlineChaseAction,
    required this.showKeyDial,
    this.secondaryLabel,
    this.ashenPracticeSecondary = false,
  });

  final String primaryLabel;
  final String? secondaryLabel;

  /// When true, TODAY card omits the small grey chase chip (folded into primary).
  final bool hideInlineChaseAction;

  /// KEY dial affordance under the stack — only when chase is KEY-shaped.
  final bool showKeyDial;

  /// Ashen Crown: grey PRACTICE under the paid enter CTA.
  final bool ashenPracticeSecondary;

  /// Labels that mean “run the selected zone” (fold into big ENTER*).
  static bool isEnterFamilyLabel(String? label) {
    if (label == null) return false;
    if (label == 'ENTER' || label == 'DAILY' || label == 'DAILY RUN') {
      return true;
    }
    return label.startsWith('ENTER KEY');
  }

  static bool chaseIsEnterFamily(HubChase chase, String? label) {
    if (chase.kind == HubChaseKind.keystone ||
        chase.kind == HubChaseKind.dailyRun) {
      return true;
    }
    return isEnterFamilyLabel(label);
  }

  static String enterDungeonLabel({
    required HubChase chase,
    required String? chaseActionLabel,
    required int hardmodeLevel,
  }) {
    final fromLabel = chaseActionLabel != null &&
            chaseActionLabel.contains('ENTER KEY')
        ? _keyLevelFromLabel(chaseActionLabel)
        : null;
    final key = chase.keyLevel ?? fromLabel;
    if (key != null) return 'ENTER KEY +$key';
    if (chase.kind == HubChaseKind.keystone) {
      return 'ENTER KEY +${chase.keyLevel ?? hardmodeLevel}';
    }
    if (chase.kind == HubChaseKind.dailyRun) return 'DAILY RUN';
    return 'ENTER DUNGEON';
  }

  static int? _keyLevelFromLabel(String label) {
    final m = RegExp(r'ENTER KEY \+(\d+)').firstMatch(label);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static bool isReadyClaim(HubChase chase) {
    if (chase.urgency != HubChaseUrgency.ready) return false;
    switch (chase.kind) {
      case HubChaseKind.claimDailyVault:
      case HubChaseKind.claimMissions:
      case HubChaseKind.monthGoal:
      case HubChaseKind.meetHero:
      case HubChaseKind.equipBag:
      case HubChaseKind.weekGoal:
      case HubChaseKind.ascend:
        return true;
      default:
        return false;
    }
  }

  static HubPrimaryCta resolve({
    required HubChase chase,
    required String? chaseActionLabel,
    required bool hasChaseAction,
    required bool unlockedSelected,
    required int hardmodeLevel,
    required bool showKeystoneJargon,
    required bool endgameUnlocked,
    HubEndgameHunt? mapHunt,
    bool showEndgameMap = true,
  }) {
    final enterLabel = enterDungeonLabel(
      chase: chase,
      chaseActionLabel: chaseActionLabel,
      hardmodeLevel: hardmodeLevel,
    );
    final canEnter = unlockedSelected;
    final label = hasChaseAction ? chaseActionLabel : null;

    if (mapHunt != null && endgameUnlocked) {
      final huntLabel = HubEndgameAct.nodeFor(mapHunt).enterLabel;
      if (label != null && isReadyClaim(chase)) {
        return HubPrimaryCta(
          primaryLabel: label,
          secondaryLabel: huntLabel,
          hideInlineChaseAction: true,
          showKeyDial: false,
        );
      }
      final ashen = mapHunt == HubEndgameHunt.ashen;
      return HubPrimaryCta(
        primaryLabel: huntLabel,
        secondaryLabel: ashen ? 'PRACTICE' : null,
        hideInlineChaseAction: true,
        showKeyDial: false,
        ashenPracticeSecondary: ashen,
      );
    }

    // PATH board: the selected zone owns the brown button. TODAY may still
    // be Gauntlet/Rift — that hunt stays grey so a dungeon tap cannot
    // start the Spire climb.
    if (endgameUnlocked && !showEndgameMap && canEnter) {
      if (label != null && isReadyClaim(chase)) {
        return HubPrimaryCta(
          primaryLabel: label,
          secondaryLabel: enterLabel,
          hideInlineChaseAction: true,
          showKeyDial: showKeystoneJargon,
        );
      }
      if (label != null && HubEndgameAct.isEnterLabel(label)) {
        return HubPrimaryCta(
          primaryLabel: enterLabel,
          secondaryLabel: label,
          hideInlineChaseAction: true,
          showKeyDial: false,
        );
      }
    }

    if (chase.kind == HubChaseKind.doneForToday && label != null) {
      return HubPrimaryCta(
        primaryLabel: label,
        secondaryLabel: canEnter ? 'ENTER DUNGEON' : null,
        hideInlineChaseAction: true,
        showKeyDial: showKeystoneJargon,
      );
    }

    if (label != null && chaseIsEnterFamily(chase, label)) {
      final primary = isEnterFamilyLabel(label) && label.contains('ENTER KEY')
          ? label
          : enterLabel;
      return HubPrimaryCta(
        primaryLabel: primary,
        secondaryLabel: null,
        hideInlineChaseAction: true,
        showKeyDial: showKeystoneJargon &&
            (chase.kind == HubChaseKind.keystone ||
                chase.kind == HubChaseKind.dailyVaultProgress),
      );
    }

    if (label != null) {
      // Chase owns primary: claims, Ascend, Gauntlet/Rift/Ashen, week→hunt, …
      String? secondary;
      var ashenPractice = false;
      if (chase.kind == HubChaseKind.ashenCrown && endgameUnlocked) {
        secondary = 'PRACTICE';
        ashenPractice = true;
      } else if (canEnter && enterLabel != label) {
        secondary = enterLabel;
      }
      return HubPrimaryCta(
        primaryLabel: label,
        secondaryLabel: secondary,
        hideInlineChaseAction: true,
        showKeyDial: showKeystoneJargon &&
            (chase.kind == HubChaseKind.keystone ||
                chase.kind == HubChaseKind.dailyVaultProgress ||
                chase.kind == HubChaseKind.weekGoal),
        ashenPracticeSecondary: ashenPractice,
      );
    }

    return HubPrimaryCta(
      primaryLabel: enterLabel,
      secondaryLabel: null,
      hideInlineChaseAction: false,
      showKeyDial: showKeystoneJargon,
    );
  }
}
