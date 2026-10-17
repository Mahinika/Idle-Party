import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/hub/hub_header.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10);

  test('AL-cap pill teases hunt — never MAX', () {
    final label = HubHeader.alCapPillLabel(
      ascensionLevel: GameLogic.maxAscensionLevel,
      huntHint: 'to Lv${GameLogic.maxHeroLevel}',
      blessingStacks: 3,
      showBlessingStacks: true,
    );
    expect(
      label,
      'AL ${GameLogic.maxAscensionLevel} · to Lv${GameLogic.maxHeroLevel} · Blessing ×3',
    );
    expect(label.contains('MAX'), isFalse);
  });

  test('AL-cap pill fallback is next hunt not endgame MAX', () {
    final label = HubHeader.alCapPillLabel(
      ascensionLevel: GameLogic.maxAscensionLevel,
    );
    expect(label, 'AL ${GameLogic.maxAscensionLevel} · next hunt');
    expect(label.contains('MAX'), isFalse);
  });

  test('AL20 sub-max chase detail skips done wording', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      bossVictories: 99,
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      metaDepth: base.metaDepth.copyWith(dailyVaultClaimed: true),
      heroRoster: [
        for (final h in base.heroRoster) h.copyWith(level: 88, xp: 0),
      ],
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.detail.toUpperCase(), contains('KEY'));
    expect(chase.detail, isNot(contains('AL20')));
    expect(chase.detail.toLowerCase().contains('done'), isFalse);
    expect(chase.title, contains('${GameLogic.maxHeroLevel}'));
  });

  testWidgets('six-digit gold shares the hub row with AL and Settings', (
    tester,
  ) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) overflows.add(text);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    Future<void> pumpHeader({
      required double width,
      required int level,
      bool plain = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: HubHeader(
                  ascensionLevel: level,
                  gold: 591053,
                  essence: 174100,
                  willRank: '',
                  collectionScore: 0,
                  displayTitle: '',
                  onOpenSettings: () {},
                  onOpenAscend: () {},
                  incomeLine: '+413/m',
                  multiplierLine: '',
                  hubGoldRate: '+413/m · 12h',
                  blessingStacks: 3,
                  showBlessingStacks: true,
                  plainChrome: plain,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpHeader(width: 336, level: 3);
    expect(find.text('AL 3'), findsOneWidget);
    await pumpHeader(width: 360, level: 3);
    await pumpHeader(width: 336, level: GameLogic.maxAscensionLevel);
    expect(find.textContaining('AL ${GameLogic.maxAscensionLevel}'), findsOneWidget);
    await pumpHeader(width: 336, level: 3, plain: true);

    expect(find.text('591,053g'), findsOneWidget);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    expect(overflows, isEmpty);
  });
}
