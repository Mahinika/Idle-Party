
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/play_games_bridge.dart';
import '../../core/play_games_scores.dart';
import '../../core/play_leaderboard_ids.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// Shared busy flag + Play Games sign-in / cloud restore dialogs.
mixin _PlayGamesActions<T extends StatefulWidget> on State<T> {
  bool playGamesBusy = false;

  GameDirector get playGamesDirector;

  Future<void> runPlayGames(Future<void> Function() action) async {
    if (playGamesBusy) return;
    setState(() => playGamesBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => playGamesBusy = false);
    }
  }

  Future<void> signInPlayGamesFlow() => runPlayGames(() async {
    final director = playGamesDirector;
    final ok = await director.signInPlayGames();
    if (!ok || !mounted) return;
    final cloud = await director.loadPlayGamesCloud();
    if (cloud == null || !mounted) return;
    final conflict = director.peekCloudConflict(cloud);
    if (conflict != CloudConflict.askUser) return;
    final useCloud = await showDialog<bool>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Cloud save differs',
        content: Text(
          'This device:\n${director.playGamesConflictHint(director.state)}\n\n'
          'Play Games:\n${director.playGamesConflictHint(cloud)}\n\n'
          'Which save should we keep?',
          style: GameTheme.body(size: 14, color: GameTheme.parchment),
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'KEEP DEVICE',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GameButton(
            label: 'USE CLOUD',
            style: GameButtonStyle.brown,
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (useCloud == true) {
      await director.restoreFromPlayGames(force: true);
    }
  });

  Future<void> restorePlayGamesFlow() => runPlayGames(() async {
    final director = playGamesDirector;
    final cloud = await director.loadPlayGamesCloud();
    if (cloud == null) {
      director.showToast('No Play Games save found', life: 2.2);
      return;
    }
    final conflict = director.peekCloudConflict(cloud);
    if (conflict == CloudConflict.askUser && mounted) {
      final useCloud = await showDialog<bool>(
        context: context,
        barrierColor: MenuChrome.scrim,
        builder: (ctx) => MenuChrome.dialog(
          title: 'Restore from Play Games?',
          content: Text(
            'This device:\n${director.playGamesConflictHint(director.state)}\n\n'
            'Play Games:\n${director.playGamesConflictHint(cloud)}',
            style: GameTheme.body(size: 14, color: GameTheme.parchment),
          ),
          actions: [
            MenuChrome.dialogCancel(
              label: 'CANCEL',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            GameButton(
              label: 'RESTORE',
              style: GameButtonStyle.red,
              expanded: false,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (useCloud != true) return;
      await director.restoreFromPlayGames(force: true);
      return;
    }
    await director.restoreFromPlayGames(
      force: conflict == CloudConflict.preferCloud,
    );
  });
}

/// KEY tab: seasonal Timed KEY + Gauntlet boards (Google hosts).
class PlayGamesBoardsSection extends StatefulWidget {
  const PlayGamesBoardsSection({super.key, required this.director});
  final GameDirector director;

  @override
  State<PlayGamesBoardsSection> createState() => _PlayGamesBoardsSectionState();
}

class _PlayGamesBoardsSectionState extends State<PlayGamesBoardsSection>
    with _PlayGamesActions {
  @override
  GameDirector get playGamesDirector => widget.director;

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final md = director.state.metaDepth;
    final month = md.leaderboardSeasonKey.isNotEmpty
        ? md.leaderboardSeasonKey
        : GameLogic.isoMonthKey(DateTime.now().toUtc());
    final timedLabel = md.seasonBestTimedKey > 0
        ? PlayGamesScores.formatTimedLabel(
            md.seasonBestTimedKey,
            md.seasonBestTimedClearMs,
          )
        : 'No timed KEY yet';
    final gauntletLabel = md.seasonBestGauntletFloor > 0
        ? 'Gauntlet F${md.seasonBestGauntletFloor}'
        : 'No Gauntlet floor yet';
    final grLabel = md.seasonBestGrTier > 0
        ? PlayGamesScores.formatGreaterRiftLabel(
            md.seasonBestGrTier,
            md.seasonBestGrClearMs,
          )
        : 'No Greater Rift yet';
    final boardsReady = PlayLeaderboardIds.hasBoards(month);
    final grBoardReady = PlayLeaderboardIds.hasGreaterRiftBoard(month);
    final signedIn = PlayGamesBridge.isSignedInCached || md.playGamesOptIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BOARDS',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          grBoardReady
              ? 'Season $month · Timed KEY + Gauntlet + Greater Rift (Play Games)'
              : 'Season $month · Timed KEY + Gauntlet (Play Games) · GR board pending',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        Text(
          timedLabel,
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        Text(
          gauntletLabel,
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        Text(
          grLabel,
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        if (!signedIn) ...[
          const SizedBox(height: 8),
          GameButton(
            label: 'SIGN IN TO RANK',
            style: GameButtonStyle.brown,
            onPressed: playGamesBusy ? null : signInPlayGamesFlow,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'KEY BOARD',
                style: GameButtonStyle.grey,
                onPressed: playGamesBusy || !boardsReady
                    ? null
                    : () => runPlayGames(director.showPlayTimedLeaderboard),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'GAUNTLET BOARD',
                style: GameButtonStyle.grey,
                onPressed: playGamesBusy || !boardsReady
                    ? null
                    : () => runPlayGames(director.showPlayGauntletLeaderboard),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GameButton(
          label: 'GR BOARD',
          style: GameButtonStyle.grey,
          onPressed: playGamesBusy || !grBoardReady
              ? null
              : () => runPlayGames(director.showPlayGreaterRiftLeaderboard),
        ),
        const SizedBox(height: 6),
        Text(
          boardsReady
              ? signedIn
                    ? 'New season PBs submit while signed in. Cloud save: SETTINGS.'
                    : 'Sign in to submit ranks. Cloud save stays under SETTINGS.'
              : 'Leaderboard IDs not set yet — add them in Play Console, then '
                    'paste into play_leaderboard_ids.dart.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (!grBoardReady) ...[
          const SizedBox(height: 4),
          Text(
            'Greater Rift board ID empty — create in Play Console, then paste.',
            style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
          ),
        ],
      ],
    );
  }
}

/// MORE → SETTINGS: Play Games sign-in + cloud backup (boards live under KEY).
class PlayGamesSection extends StatefulWidget {
  const PlayGamesSection({super.key, required this.director});
  final GameDirector director;

  @override
  State<PlayGamesSection> createState() => _PlayGamesSectionState();
}

class _PlayGamesSectionState extends State<PlayGamesSection>
    with _PlayGamesActions {
  @override
  GameDirector get playGamesDirector => widget.director;

  @override
  Widget build(BuildContext context) {
    final md = widget.director.state.metaDepth;
    final month = md.leaderboardSeasonKey.isNotEmpty
        ? md.leaderboardSeasonKey
        : GameLogic.isoMonthKey(DateTime.now().toUtc());
    final signedIn = PlayGamesBridge.isSignedInCached || md.playGamesOptIn;
    final lastBackup = PlayGamesBridge.lastCloudUploadAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PLAY GAMES',
          style: GameTheme.body(size: 13, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Season $month · cloud backup. Boards: KEY.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (lastBackup != null) ...[
          const SizedBox(height: 4),
          Text(
            'Last cloud backup · ${lastBackup.toLocal()}',
            style: GameTheme.body(size: 11, color: GameTheme.mossLit),
          ),
        ],
        const SizedBox(height: 8),
        GameButton(
          label: signedIn ? 'SIGNED IN' : 'SIGN IN WITH PLAY GAMES',
          style: GameButtonStyle.brown,
          onPressed: playGamesBusy || signedIn ? null : signInPlayGamesFlow,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'BACKUP NOW',
                style: GameButtonStyle.grey,
                onPressed: playGamesBusy
                    ? null
                    : () => runPlayGames(() async {
                        await widget.director.backupToPlayGames();
                      }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'RESTORE',
                style: GameButtonStyle.grey,
                onPressed: playGamesBusy ? null : restorePlayGamesFlow,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
