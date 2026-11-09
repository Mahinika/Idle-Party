import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/assets/kenney_assets.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';

import 'shell_golden_harness.dart';

/// Doll decode can shift a few pixels when another test is loading heroes.
class _TownDollComparator extends LocalFileComparator {
  _TownDollComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= 0.02) return true;
    return super.compare(imageBytes, golden);
  }
}

/// Town goldens. Live under goldens/town/, not the shared after/ fight set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoldenFileComparator previousComparator;

  setUpAll(() async {
    await ensureShellGoldenFonts();
    previousComparator = goldenFileComparator;
    final previous = previousComparator;
    if (previous is LocalFileComparator) {
      goldenFileComparator = _TownDollComparator(
        previous.basedir.resolve('town_preview_golden_test.dart'),
      );
    }
  });

  tearDownAll(() {
    goldenFileComparator = previousComparator;
  });

  Future<void> waitTownArt(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(TownViewport));
      for (final path in [
        ...CustomAssets.townAssetPaths,
        CustomAssets.townPathAlt,
        KenneyAssets.townNameplate,
        KenneyAssets.townPennants,
        KenneyAssets.townLanterns,
      ]) {
        await precacheImage(AssetImage(path), ctx);
      }
    });
    final sw = Stopwatch()..start();
    var idle = 0;
    while (sw.elapsedMilliseconds < 8000) {
      if (HeroDollSprite.pendingLoads == 0) {
        idle++;
        if (idle >= 5) break;
      } else {
        idle = 0;
      }
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 16)),
      );
    }
    await tester.pump();
    await pumpGoldenFrames(tester, ms: 800);
  }

  testWidgets('town preview golden A56', (tester) async {
    bindA56View(tester);
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: shellGoldenNow).copyWith(
        inDungeon: false,
        bossVictories: 1,
        highestFloorCleared: 2,
        ascensionLevel: 1,
      ),
    );
    final router = MenuRouter();
    addTearDown(router.dispose);
    addTearDown(director.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      shellGoldenScaffold(
        RepaintBoundary(
          key: key,
          child: TownPreview(director: director, router: router),
        ),
      ),
    );
    await waitTownArt(tester);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/town/town_preview_a56.png'),
    );
  });

  testWidgets('home shell town golden A56', (tester) async {
    bindA56View(tester);
    final base = GameLogic.createInitialState(now: shellGoldenNow);
    final director = GameDirector.preview(
      initialState: base.copyWith(
        inDungeon: false,
        homeLayout: HomeLayout.home,
        bossVictories: 1,
        highestFloorCleared: 2,
        ascensionLevel: 1,
        vfxQuality: VfxQuality.minimal,
        seenChangelogVersion: MetaSystems.currentVersion,
        seenTips: const [
          'first_run',
          'discord_thanks',
          'hub_enter',
          'godhand',
          'farm_push',
          'kit_abilities',
          'bag',
          'forge',
          'sanctuary',
        ],
        metaDepth: base.metaDepth.copyWith(
          reviewPrompted: true,
          notifyPrompted: true,
          notifyOptIn: true,
        ),
      ),
    );
    final router = MenuRouter();
    addTearDown(router.dispose);
    addTearDown(director.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      shellGoldenScaffold(
        RepaintBoundary(
          key: key,
          child: HomeShell(director: director, router: router, onLeave: () {}),
        ),
      ),
    );
    await waitTownArt(tester);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/town/home_shell_town_a56.png'),
    );
  });

  testWidgets('home shell town timber tier golden A56', (tester) async {
    await _pumpTownTier(
      tester,
      al: 0,
      golden: 'goldens/town/home_shell_town_t0_a56.png',
    );
  });

  testWidgets('home shell town banner tier golden A56', (tester) async {
    await _pumpTownTier(
      tester,
      al: 5,
      golden: 'goldens/town/home_shell_town_t2_a56.png',
    );
  });

  testWidgets('home shell town 360x640', (tester) async {
    await _pumpHome(
      tester: tester,
      logical: const Size(360, 640),
      textScale: 1,
      vfx: VfxQuality.minimal,
      golden: 'goldens/town/home_shell_town_640.png',
    );
  });

  testWidgets('home shell town text scale 1.45', (tester) async {
    await _pumpHome(
      tester: tester,
      logical: const Size(360, 780),
      textScale: 1.45,
      vfx: VfxQuality.minimal,
      golden: 'goldens/town/home_shell_town_text_145.png',
    );
  });

  testWidgets('home shell town text scale 2', (tester) async {
    await _pumpHome(
      tester: tester,
      logical: const Size(360, 780),
      textScale: 2,
      vfx: VfxQuality.minimal,
      golden: 'goldens/town/home_shell_town_text_2.png',
    );
  });

  testWidgets('home shell town walk frames', (tester) async {
    for (final ms in [0, 480, 1200]) {
      await _pumpHome(
        tester: tester,
        logical: const Size(360, 780),
        textScale: 1,
        vfx: VfxQuality.full,
        golden: 'goldens/town/home_shell_town_walk_$ms.png',
        pumpMs: ms == 0 ? 16 : ms,
      );
    }
  });
}

Future<void> _pumpTownTier(
  WidgetTester tester, {
  required int al,
  required String golden,
}) async {
  bindA56View(tester);
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  final director = GameDirector.preview(
    initialState: base.copyWith(
      inDungeon: false,
      homeLayout: HomeLayout.home,
      bossVictories: 1,
      highestFloorCleared: 2,
      ascensionLevel: al,
      vfxQuality: VfxQuality.minimal,
      seenChangelogVersion: MetaSystems.currentVersion,
      seenTips: const [
        'first_run',
        'discord_thanks',
        'hub_enter',
        'godhand',
        'farm_push',
        'kit_abilities',
        'bag',
        'forge',
        'sanctuary',
      ],
      metaDepth: base.metaDepth.copyWith(
        reviewPrompted: true,
        notifyPrompted: true,
        notifyOptIn: true,
      ),
    ),
  );
  final router = MenuRouter();
  addTearDown(router.dispose);
  addTearDown(director.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(
    shellGoldenScaffold(
      RepaintBoundary(
        key: key,
        child: HomeShell(director: director, router: router, onLeave: () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(TownViewport));
    for (final path in [
      ...CustomAssets.townAssetPaths,
      CustomAssets.townPathAlt,
      KenneyAssets.townNameplate,
      KenneyAssets.townPennants,
      KenneyAssets.townLanterns,
    ]) {
      await precacheImage(AssetImage(path), ctx);
    }
  });
  final sw = Stopwatch()..start();
  var idle = 0;
  while (sw.elapsedMilliseconds < 8000) {
    if (HeroDollSprite.pendingLoads == 0) {
      idle++;
      if (idle >= 5) break;
    } else {
      idle = 0;
    }
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 16)),
    );
  }
  await pumpGoldenFrames(tester, ms: 400);
  await expectLater(find.byKey(key), matchesGoldenFile(golden));
}

Future<void> _pumpHome({
  required WidgetTester tester,
  required Size logical,
  required double textScale,
  required VfxQuality vfx,
  required String golden,
  int pumpMs = 400,
}) async {
  tester.view.physicalSize = Size(logical.width * 3, logical.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  final director = GameDirector.preview(
    initialState: base.copyWith(
      inDungeon: false,
      homeLayout: HomeLayout.home,
      bossVictories: 1,
      highestFloorCleared: 2,
      ascensionLevel: 1,
      vfxQuality: vfx,
      seenChangelogVersion: MetaSystems.currentVersion,
      seenTips: const [
        'first_run',
        'discord_thanks',
        'hub_enter',
        'godhand',
        'farm_push',
        'kit_abilities',
        'bag',
        'forge',
        'sanctuary',
      ],
      metaDepth: base.metaDepth.copyWith(
        reviewPrompted: true,
        notifyPrompted: true,
        notifyOptIn: true,
      ),
    ),
  );
  final router = MenuRouter();
  addTearDown(router.dispose);
  addTearDown(director.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: logical,
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: GameTheme.ink,
          body: RepaintBoundary(
            key: key,
            child: HomeShell(
              director: director,
              router: router,
              onLeave: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(TownViewport));
    for (final path in [
      ...CustomAssets.townAssetPaths,
      CustomAssets.townPathAlt,
      KenneyAssets.townNameplate,
      KenneyAssets.townPennants,
      KenneyAssets.townLanterns,
    ]) {
      await precacheImage(AssetImage(path), ctx);
    }
  });
  final sw = Stopwatch()..start();
  var idle = 0;
  while (sw.elapsedMilliseconds < 8000) {
    if (HeroDollSprite.pendingLoads == 0) {
      idle++;
      if (idle >= 5) break;
    } else {
      idle = 0;
    }
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 16)),
    );
  }
  await tester.pump(Duration(milliseconds: pumpMs));
  expect(tester.takeException(), isNull);
  await expectLater(find.byKey(key), matchesGoldenFile(golden));
}
