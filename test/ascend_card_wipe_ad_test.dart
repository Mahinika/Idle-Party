import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_rewarded.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/confirm_dialogs.dart';
import 'package:idle_party/ui/shell/wipe_overlay.dart';

void main() {
  test('Ascend card names the blessing, the wipe, and the essence', () {
    final state = GameLogic.createInitialState().copyWith(
      bossVictories: GameLogic.bossesRequiredForAscension(0),
      essence: 40,
    );
    final lines = ascendWorthLines(state);
    expect(lines, hasLength(3));
    expect(lines[0], contains('Gain:'));
    expect(lines[0], contains('AL1'));
    expect(
      lines[0],
      contains(
        '+${GameLogic.ascendBlessingAtk} AP, '
        '+${GameLogic.ascendBlessingDef} Armor, '
        '+${GameLogic.ascendBlessingVit} STA, '
        '+${GameLogic.ascendBlessingGoldPct}% gold',
      ),
    );
    expect(
      lines[1],
      'Lose: gold, regular gear, market listings, loadouts, GOLD tracks, and this run\'s floors.',
    );
    final reward =
        GameLogic.ascendEssenceReward(1) +
        MetaSystems.ascendMilestoneReward(0, 1) +
        MetaSystems.ascendStreakEssence(state);
    expect(lines[2], 'Essence: +${reward}e. You keep 40e.');
    expect(lines.join(' '), isNot(contains('Keep:')));
  });

  testWidgets('Ascend confirm shows the three lines', (tester) async {
    final state = GameLogic.createInitialState().copyWith(
      bossVictories: GameLogic.bossesRequiredForAscension(0),
      essence: 40,
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmAscend(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gain: AL1'), findsOneWidget);
    expect(find.textContaining('Lose: gold, regular gear'), findsOneWidget);
    expect(find.textContaining('market listings'), findsOneWidget);
    expect(find.textContaining('loadouts'), findsOneWidget);
    expect(find.textContaining('Essence:'), findsOneWidget);
    expect(find.textContaining('Keep:'), findsNothing);
    expect(find.text('CONFIRM ASCEND'), findsOneWidget);
    expect(director.state.ascensionLevel, 0);
  });

  testWidgets('wipe screen offers an optional ad and does not grant a ticket', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final director = GameDirector.preview();
    await tester.pumpWidget(
      MaterialApp(
        home: DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
      ),
    );
    expect(find.text('PARTY WIPED'), findsOneWidget);
    expect(find.text('RETRY FLOOR'), findsOneWidget);
    expect(find.text('WATCH AD · +1 ticket'), findsOneWidget);
    expect(
      find.text('Optional. The party goes again without an ad.'),
      findsOneWidget,
    );
    final tickets = director.state.metaDepth.adTickets;
    await tester.tap(find.text('WATCH AD · +1 ticket'));
    await tester.pump();
    await tester.pump();
    expect(director.state.metaDepth.adTickets, tickets);
    expect(find.text('PARTY WIPED'), findsOneWidget);
    expect(find.text('RETRY FLOOR'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    director.dispose();
  });

  testWidgets('ad-free hides the wipe ad', (tester) async {
    final fresh = GameLogic.createInitialState();
    final director = GameDirector.preview(
      initialState: fresh.copyWith(
        metaDepth: fresh.metaDepth.copyWith(adFree: true),
      ),
    );
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
      ),
    );
    expect(find.text('PARTY WIPED'), findsOneWidget);
    expect(find.textContaining('WATCH AD'), findsNothing);
  });

  test('a timed-out wipe ad arms the retry countdown again', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugOpenWipeChoice();
    director.debugFinishWipeAd(AdWatchResult.rewarded);
    expect(director.wipeAutoSeconds.value, 0);
    director.debugFinishWipeAd(AdWatchResult.failed);
    expect(director.wipeAutoSeconds.value, 3);
    director.debugFinishWipeAd(AdWatchResult.unavailable);
    expect(director.wipeAutoSeconds.value, 3);
  });
}
