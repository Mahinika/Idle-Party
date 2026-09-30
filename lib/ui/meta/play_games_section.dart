
import 'package:flutter/foundation.dart';
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
  PlayBoardKind _kind = PlayBoardKind.timedKey;
  String? _activeKey;
  int _loadGen = 0;
  bool _loading = false;
  bool _failed = false;
  List<PlayBoardRow>? _rows;

  @override
  GameDirector get playGamesDirector => widget.director;

  void _queueLoad(String month, PlayBoardKind kind) {
    final key = '$month|${kind.name}';
    if (_activeKey == key) return;
    _activeKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeKey != key) return;
      _load(month, kind);
    });
  }

  Future<void> _load(String month, PlayBoardKind kind) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _failed = false;
    });
    if (kind == PlayBoardKind.partyPower) {
      PlayGamesBridge.notePartyPower(
        score: GameLogic.partyPowerScore(widget.director.state),
        partyName: widget.director.state.partyName,
      );
      await PlayGamesBridge.flushPendingScores();
    }
    if (!mounted || gen != _loadGen) return;
    final snap = await PlayGamesBridge.loadBoard(
      kind: kind,
      monthKey: month,
      yourPartyName: widget.director.state.partyName,
    );
    if (!mounted || gen != _loadGen) return;
    setState(() {
      _loading = false;
      _failed = snap.failed;
      _rows = snap.rows;
    });
  }

  void _refresh(String month) {
    setState(() {
      _activeKey = null;
      _failed = false;
      _rows = null;
    });
    _queueLoad(month, _kind);
  }

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    final md = director.state.metaDepth;
    final month = md.leaderboardSeasonKey.isNotEmpty
        ? md.leaderboardSeasonKey
        : GameLogic.isoMonthKey(DateTime.now().toUtc());
    final playSupported = PlayGamesBridge.isSupported;
    final monthBoards = PlayLeaderboardIds.hasBoards(month);
    final boardsReady = PlayLeaderboardIds.boardsAvailable(
      month,
      playGamesSupported: playSupported,
    );
    // Opt-in alone is not enough — need a real signed-in session so we do
    // not paint an empty rank list.
    final signedInLive = PlayGamesBridge.isSignedInCached;
    final showLiveBoards = boardsReady && signedInLive;
    // All-time party power stays up when the new month has no Console ids.
    final partyLive = playSupported &&
        signedInLive &&
        PlayLeaderboardIds.hasPartyPowerBoard &&
        !monthBoards;
    // Debug playtest (emulator) can flip the three lists without Play sign-in.
    // A month with no Console ids stays honest instead of a fake season list.
    final preview = kDebugMode && !showLiveBoards && !partyLive && monthBoards;

    // Sideload / missing IDs / signed out: honesty only — no dead
    // KEY/GR board buttons that look like an empty live leaderboard.
    if (!showLiveBoards && !preview && !partyLive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Season $month',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          Text(
            PlayLeaderboardIds.unavailableMessage(
              playGamesSupported: playSupported,
              monthKey: month,
            ),
            style: GameTheme.body(size: 13, color: GameTheme.parchment),
          ),
          if (playSupported && !signedInLive) ...[
            const SizedBox(height: 8),
            GameButton(
              label: 'SIGN IN TO RANK',
              style: GameButtonStyle.brown,
              onPressed: playGamesBusy ? null : signInPlayGamesFlow,
            ),
            const SizedBox(height: 6),
            Text(
              'Cloud save stays under SETTINGS.',
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
          ],
        ],
      );
    }

    final grBoardReady =
        !partyLive &&
        (preview || PlayLeaderboardIds.hasGreaterRiftBoard(month));
    final partyBoardReady = preview || PlayLeaderboardIds.hasPartyPowerBoard;
    final seasonChips = !partyLive && (showLiveBoards || preview);
    final kind = partyLive
        ? PlayBoardKind.partyPower
        : !grBoardReady && _kind == PlayBoardKind.greaterRift
        ? PlayBoardKind.timedKey
        : _kind;
    if ((showLiveBoards || partyLive) &&
        (kind != PlayBoardKind.partyPower || partyBoardReady)) {
      _queueLoad(month, kind);
    }
    final shownRows = preview ? PlayBoardPreview.rows(kind) : _rows;

    final yours = switch (kind) {
      PlayBoardKind.timedKey => md.seasonBestTimedKey > 0
          ? PlayGamesScores.formatTimedLabel(
              md.seasonBestTimedKey,
              md.seasonBestTimedClearMs,
            )
          : 'No timed KEY yet',
      PlayBoardKind.gauntlet => md.seasonBestGauntletFloor > 0
          ? 'F${md.seasonBestGauntletFloor}'
          : 'No Gauntlet floor yet',
      PlayBoardKind.greaterRift => md.seasonBestGrTier > 0
          ? PlayGamesScores.formatGreaterRiftLabel(
              md.seasonBestGrTier,
              md.seasonBestGrClearMs,
            )
          : 'No Ranked GR yet',
      PlayBoardKind.partyPower => '${GameLogic.partyPowerScore(director.state)}',
    };
    final yoursLine = '${director.state.partyName} · $yours';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Season $month',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        const SizedBox(height: 6),
        if (partyLive)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              PlayLeaderboardIds.monthBoardsPendingMessage,
              style: GameTheme.body(size: 13, color: GameTheme.parchment),
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (seasonChips) ...[
              MenuChrome.chip(
                label: 'KEY',
                selected: kind == PlayBoardKind.timedKey,
                onTap: () => _select(PlayBoardKind.timedKey),
              ),
              MenuChrome.chip(
                label: 'GAUNTLET',
                selected: kind == PlayBoardKind.gauntlet,
                onTap: () => _select(PlayBoardKind.gauntlet),
              ),
              if (grBoardReady)
                MenuChrome.chip(
                  label: 'GR',
                  selected: kind == PlayBoardKind.greaterRift,
                  onTap: () => _select(PlayBoardKind.greaterRift),
                ),
            ],
            MenuChrome.chip(
              label: 'PARTY',
              selected: kind == PlayBoardKind.partyPower,
              onTap: () => _select(PlayBoardKind.partyPower),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          yoursLine,
          style: GameTheme.body(size: 13, color: GameTheme.parchment),
        ),
        if (kind == PlayBoardKind.partyPower) ...[
          const SizedBox(height: 4),
          Text(
            'Level, worn gear, Ascend, and blessings.',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 6),
        if (preview)
          ..._rankRows(shownRows!)
        else if (kind == PlayBoardKind.partyPower && !partyBoardReady)
          Text(
            'A public party list is not on Play yet.',
            style: GameTheme.body(size: 13, color: GameTheme.parchment),
          )
        else if (_loading && (_rows == null || _rows!.isEmpty))
          Text(
            'Loading ranks…',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          )
        else if (_failed && (_rows == null || _rows!.isEmpty))
          Text(
            'Could not load ranks.',
            style: GameTheme.body(size: 13, color: GameTheme.parchment),
          )
        else if (_rows != null && _rows!.isEmpty)
          Text(
            kind == PlayBoardKind.partyPower
                ? 'No party scores yet.'
                : 'No scores yet this season.',
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          )
        else if (_rows != null)
          ..._rankRows(_rows!),
        if (!preview && _loading && _rows != null && _rows!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Updating…',
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
          ),
        if (!preview &&
            (kind != PlayBoardKind.partyPower || partyBoardReady)) ...[
          const SizedBox(height: 6),
          GameButton(
            label: _failed ? 'RETRY' : 'REFRESH',
            style: GameButtonStyle.ghost,
            dense: true,
            onPressed: playGamesBusy || _loading ? null : () => _refresh(month),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          preview
              ? PlayBoardPreview.notice
              : kind == PlayBoardKind.partyPower && !partyBoardReady
              ? 'Your party power stays on this device.'
              : 'A new record sends itself while you are signed in. Cloud save: SETTINGS.',
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
      ],
    );
  }

  void _select(PlayBoardKind kind) {
    if (kind == _kind) return;
    _loadGen++;
    setState(() {
      _kind = kind;
      _activeKey = null;
      _failed = false;
      _rows = null;
    });
  }

  List<Widget> _rankRows(List<PlayBoardRow> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (i > 0 && row.rank > rows[i - 1].rank + 1) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '·',
              textAlign: TextAlign.center,
              style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
            ),
          ),
        );
      }
      final tone = row.isYou ? GameTheme.torchHot : GameTheme.parchment;
      out.add(
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: MenuChrome.listCard(selected: row.isYou),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '#${row.rank}',
                  style: GameTheme.body(size: 13, color: tone),
                ),
              ),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 13, color: tone),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  row.scoreLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GameTheme.body(size: 12, color: tone),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return out;
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
          GameLogic.showKeystoneJargon(widget.director.state)
              ? 'Season $month · cloud backup. Boards: KEY.'
              : 'Season $month · cloud backup.',
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
