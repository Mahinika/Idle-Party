import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/meta_systems.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

/// In-app "What's new" changelog — marks itself seen once shown.
class WhatsNewOverlay extends StatelessWidget {
  const WhatsNewOverlay({super.key, required this.director});
  final GameDirector director;

  /// Current (or unseen) blocks. First hour: lead bullet only.
  static List<ChangelogRelease> visibleFocus(GameState state) {
    final unseen = MetaSystems.hasUnseenChangelog(state);
    final current = MetaSystems.releases.isEmpty
        ? null
        : MetaSystems.releases.first;
    final focus = unseen
        ? MetaSystems.unseenReleases(state)
        : (current == null
              ? const <ChangelogRelease>[]
              : <ChangelogRelease>[current]);
    if (!GameLogic.plainPlayerChrome(state)) return focus;
    return [for (final release in focus) release.leadOnly];
  }

  /// Older-version fold waits until first boss (KEY recap is not day-one).
  static bool showOlderVersions(GameState state) =>
      !MetaSystems.hasUnseenChangelog(state) &&
      MetaSystems.releases.length > 1 &&
      !GameLogic.plainPlayerChrome(state);

  /// Dialog host used by hub auto-show and Settings → What's New.
  static Future<void> show(BuildContext context, GameDirector director) {
    return showDialog<void>(
      context: context,
      barrierColor: MenuChrome.scrim,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxW = math.min(420.0, size.width - 32);
        final maxH = math.min(420.0, size.height * 0.78);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: DecoratedBox(
            decoration: MenuChrome.panel(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: maxW,
                height: maxH,
                child: WhatsNewOverlay(director: director),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final older = MetaSystems.releases.length <= 1
        ? const <ChangelogRelease>[]
        : MetaSystems.releases.sublist(1);
    final focus = visibleFocus(state);

    Widget releaseBlock(ChangelogRelease release) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'VERSION ${release.version}',
            style: GameTheme.menuTitle(size: 14, color: GameTheme.torch),
          ),
          const SizedBox(height: 6),
          for (final entry in release.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: GameTheme.body(size: 16, color: GameTheme.torch),
                  ),
                  Expanded(
                    child: Text(entry, style: GameTheme.body(size: 15)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "WHAT'S NEW",
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 20),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              for (final release in focus) releaseBlock(release),
              if (showOlderVersions(state) && older.isNotEmpty)
                MenuChrome.fold(
                  title: 'Older versions',
                  children: [
                    for (final release in older) releaseBlock(release),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GameButton(
          label: 'GOT IT',
          onPressed: () {
            director.markChangelogSeen();
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }
}
