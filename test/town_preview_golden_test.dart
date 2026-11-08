import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';

import 'shell_golden_harness.dart';

/// Town-only golden. Lives under goldens/town/, not the shared after/ set
/// that PR57/58 retouch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  testWidgets('town preview golden A56', (tester) async {
    bindA56View(tester);
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: shellGoldenNow)
          .copyWith(
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
    await tester.pump();
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(TownViewport));
      for (final path in CustomAssets.townAssetPaths) {
        await precacheImage(AssetImage(path), ctx);
      }
    });
    final sw = Stopwatch()..start();
    while (HeroDollSprite.pendingLoads > 0 && sw.elapsedMilliseconds < 8000) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 16)),
      );
    }
    await tester.pump();
    await pumpGoldenFrames(tester, ms: 800);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/town/town_preview_a56.png'),
    );
  });
}
