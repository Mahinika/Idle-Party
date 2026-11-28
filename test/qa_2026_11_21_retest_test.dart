import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_audio.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/character_equip_panel.dart';
import 'package:idle_party/ui/floater_banner_stack.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/menu_surface.dart';
import 'package:idle_party/ui/shell/wisp_gift_overlay.dart';

void main() {
  test('loot and status words share a lane; DODGE stays on the body', () {
    expect(FloaterBannerStack.usesSharedLane('Head'), isTrue);
    expect(FloaterBannerStack.usesSharedLane('Belt'), isTrue);
    expect(FloaterBannerStack.usesSharedLane('DEAD SETPIECE'), isTrue);
    expect(FloaterBannerStack.usesSharedLane('SWORD & BOARD'), isTrue);
    expect(FloaterBannerStack.usesSharedLane('ELITE DOWN'), isTrue);
    expect(FloaterBannerStack.usesSharedLane('ABSORB'), isTrue);
    expect(FloaterBannerStack.usesSharedLane('DODGE'), isFalse);
    expect(FloaterBannerStack.usesSharedLane('BLOCK'), isFalse);
    expect(FloaterBannerStack.usesSharedLane('PARRY'), isFalse);
    expect(FloaterBannerStack.usesSharedLane('+54g'), isFalse);
    expect(FloaterBannerStack.usesSharedLane('18'), isFalse);
  });

  test('a disposed engine does not retry a failed asset load', () {
    final generation = GameAudio.debugAssetLoadGeneration;
    expect(
      GameAudio.debugRetryAssetLoad(
        attempt: 0,
        ready: true,
        generation: generation,
        nowGeneration: generation,
      ),
      isTrue,
    );
    expect(
      GameAudio.debugRetryAssetLoad(
        attempt: 1,
        ready: true,
        generation: generation,
        nowGeneration: generation,
      ),
      isFalse,
    );
    GameAudio.disposeEngine();
    expect(GameAudio.debugAssetLoadGeneration, generation + 1);
    expect(
      GameAudio.debugRetryAssetLoad(
        attempt: 0,
        ready: true,
        generation: generation,
        nowGeneration: GameAudio.debugAssetLoadGeneration,
      ),
      isFalse,
    );
  });

  testWidgets('GEAR, SHOP, and SETTINGS keep their own subtitles', (
    tester,
  ) async {
    final clock = DateTime.now().toUtc();
    var state = GameLogic.createInitialState(
      now: clock,
    ).copyWith(homeLayout: HomeLayout.home, bossVictories: 1);
    state = state.copyWith(
      missions: [
        for (var i = 0; i < state.missions.length; i++)
          i < 2
              ? state.missions[i].copyWith(progress: state.missions[i].target)
              : state.missions[i],
      ],
    );
    expect(HubChase.forState(state).title, 'Claim quest rewards');
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);

    Future<void> open(MenuRoute route, {MoreSection? more}) async {
      router.open(route, more: more);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: Stack(
                children: [
                  MenuSurface(director: director, router: router, home: true),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await open(MenuRoute.gear);
    expect(find.text('Equip the party'), findsOneWidget);
    expect(find.text('Claim quest rewards'), findsNothing);

    await open(MenuRoute.shop);
    expect(find.textContaining('Ad-free'), findsWidgets);
    expect(find.text('Claim quest rewards'), findsNothing);

    await open(MenuRoute.more, more: MoreSection.settings);
    expect(find.text('Sound, display, bag, and account'), findsOneWidget);
    expect(find.text('Claim quest rewards'), findsNothing);

    router.open(MenuRoute.more);
    await tester.pump();
    expect(find.text('Settings, guides, and the rest.'), findsOneWidget);
  });

  testWidgets('hero tab keeps the level and ellipsizes the name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = GameLogic.createInitialState();
    final heroes = [
      for (var i = 0; i < base.heroes.length; i++)
        base.heroes[i].copyWith(
          name: i == 0 ? 'Judicar of the Long Watch' : base.heroes[i].name,
          level: i == 0 ? 14 : base.heroes[i].level,
        ),
    ];
    final state = base.copyWith(heroes: heroes);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.45)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CharacterEquipPanel(
              state: state,
              heroIndex: 0,
              onSelectHero: (_) {},
              selectedItemId: null,
              onSelectItem: (_) {},
              onUnequip: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final chipText = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('hero-tab-name-0')),
    );
    expect(chipText.text.toPlainText(), contains('Judic'));
    expect(chipText.didExceedMaxLines, isTrue);
    expect(
      find.bySemanticsLabel(RegExp(r'Judic.*Lv14')),
      findsOneWidget,
    );
    final textRect = tester.getRect(
      find.byKey(const ValueKey('hero-tab-name-0')),
    );
    final chip = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const ValueKey('hero-tab-name-0')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(textRect.right, lessThanOrEqualTo(chip.right + 0.5));
    expect(textRect.left, greaterThanOrEqualTo(chip.left));
  });

  testWidgets('CC badge stays inside its party chip', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = GameLogic.enterDungeon(GameLogic.createInitialState());
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    final world = SpatialCombat.build(state);
    world.heroes.first.attackSlowTimer = 3;
    director.debugAttachSpatial(world);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: PartyCornerHud(
              director: director,
              selectedHeroIndex: 0,
              onSelectHero: (_) {},
              onOpenEquip: () {},
              homeRow: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final cc = find.byKey(homeChipCcKey);
    expect(cc, findsOneWidget);
    final ccRect = tester.getRect(cc);
    final chip = tester.getRect(
      find.ancestor(of: cc, matching: find.byType(Column)).first,
    );
    expect(ccRect.right, lessThanOrEqualTo(chip.right + 1));
    expect(ccRect.left, greaterThanOrEqualTo(chip.left - 1));
    expect(find.text('SLOW'), findsOneWidget);
  });

  testWidgets('toast clearance clears the lantern hint', (tester) async {
    late double bare;
    late double hinted;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.45)),
        child: Builder(
          builder: (context) {
            bare = WispGiftOverlay.toastTopClearance(context, hint: false);
            hinted = WispGiftOverlay.toastTopClearance(context, hint: true);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(bare, greaterThanOrEqualTo(48));
    expect(hinted, greaterThan(bare));
  });
}
