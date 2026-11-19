import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';


import 'shell_golden_harness.dart';

/// Shared home-shell harness for the audit-100 regression tests: A56
/// 360x780 and small 360x640, at 1.0 and the 1.45 text cap.
const a100Sizes = [Size(360, 780), Size(360, 640)];
final a100Scales = [1.0, GameTheme.typeScaleMax];

Future<GameDirector> a100Director({
  bool fresh = false,
  bool inDungeon = true,
  bool maxed = false,
  int? gold,
  int? essence,
  bool full = false,
  List<EquipmentItem>? stash,
}) => withShellGoldenWeek(() async {
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  var s = fresh
      ? base.copyWith(
          homeLayout: HomeLayout.home,
          vfxQuality: VfxQuality.minimal,
        )
      : base.copyWith(
          homeLayout: HomeLayout.home,
          homePanelFull: false,
          ascensionLevel: 2,
          bossVictories: 2,
          highestDungeonCleared: 1,
          highestFloorCleared: 4,
          gold: 12000,
          essence: 240,
          vfxQuality: VfxQuality.minimal,
          seenChangelogVersion: MetaSystems.currentVersion,
          metaDepth: base.metaDepth.copyWith(
            reviewPrompted: true,
            lifetimeFloorClears: 6,
          ),
        );
  if (maxed) {
    s = s.copyWith(
      heroes: [
        for (final h in s.heroes) h.copyWith(level: GameLogic.maxHeroLevel),
      ],
    );
  }
  if (gold != null) s = s.copyWith(gold: gold);
  if (essence != null) s = s.copyWith(essence: essence);
  if (full) s = s.copyWith(homePanelFull: true);
  if (stash != null) s = s.copyWith(gearStash: stash);
  if (inDungeon) s = GameLogic.enterDungeon(s);
  final d = GameDirector.preview(initialState: s);
  await d.boot(deferCombatLoop: true);
  d.dismissOfflineSummary();
  d.clearToast();
  return d;
});

Future<(GameDirector, MenuRouter)> a100Pump(
  WidgetTester tester,
  Size size,
  double scale, {
  bool fresh = false,
  bool maxed = false,
  bool inDungeon = true,
  int? gold,
  int? essence,
  bool full = false,
  // Rebuild the shell on director changes, like PlayShell does.
  bool live = false,
  List<EquipmentItem>? stash,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final director = await a100Director(
    fresh: fresh,
    maxed: maxed,
    inDungeon: inDungeon,
    gold: gold,
    essence: essence,
    full: full,
    stash: stash,
  );
  final router = MenuRouter();
  a100Live = (director, router);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: live
          ? ListenableBuilder(
              listenable: director,
              builder: (context, _) =>
                  HomeShell(director: director, router: router, onLeave: () {}),
            )
          : HomeShell(director: director, router: router, onLeave: () {}),
    ),
  );
  await tester.pump();
  return (director, router);
}

(GameDirector, MenuRouter)? a100Live;

/// A mixed bag: every rarity, many slots, item levels 8..60.
List<EquipmentItem> a100Stash([int count = 14]) {
  const slots = [
    EquipmentSlot.weapon,
    EquipmentSlot.shoulder,
    EquipmentSlot.offHand,
    EquipmentSlot.head,
    EquipmentSlot.chest,
    EquipmentSlot.boots,
    EquipmentSlot.ring,
    EquipmentSlot.neck,
    EquipmentSlot.hands,
    EquipmentSlot.legs,
    EquipmentSlot.cloak,
    EquipmentSlot.trinket,
    EquipmentSlot.waist,
    EquipmentSlot.wrist,
  ];
  return [
    for (var i = 0; i < count; i++)
      EquipmentItem(
        id: 'a100_bag_$i',
        name: 'Test Piece $i',
        slot: slots[i % slots.length],
        rarity: LootRarity.values[i % LootRarity.values.length],
        attackBonus: 4 + i,
        strengthBonus: 2 + i,
        itemLevel: 8 + i * 4,
      ),
  ];
}

/// testWidgets that tears the shell down before the timer check.
void a100TestHome(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    a100Live = null;
    await body(tester);
    final live = a100Live;
    if (live != null) {
      await tester.pumpWidget(const SizedBox.shrink());
      live.$1.dispose();
      live.$2.dispose();
      await tester.pump(const Duration(milliseconds: 20));
    }
  });
}

Future<void> a100Settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

String a100Label(Size size, double scale) =>
    '${size.width.toInt()}x${size.height.toInt()} @$scale';

/// Text [text] is drawn whole: no ellipsis, no line cut, wider than its box.
void a100ExpectWhole(WidgetTester tester, Finder text) {
  expect(text, findsWidgets);
  for (final e in text.evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
    if (!p.softWrap || p.maxLines == 1) {
      expect(
        p.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(p.size.width + 0.5),
        reason: 'cut: ${p.text.toPlainText()}',
      );
    }
  }
}

