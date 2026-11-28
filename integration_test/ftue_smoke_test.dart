// FTUE smoke for device runs. Primary gate: `.github/workflows/emulator-smoke.yml`
// (boot + logcat). To add this flow locally or in CI:
//   flutter test integration_test/ftue_smoke_test.dart -d <device_id>
//
// Scope: new game from preview state — hub renders and SHOP catalog is readable
// without walking a full boss (long fight paths stay in widget tests).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new save reaches hub SHOP row', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(),
    );
    addTearDown(director.dispose);
    await director.boot();

    await tester.pumpWidget(
      MaterialApp(home: ShopDock(director: director)),
    );
    await tester.pump();

    final adFree = ShopCatalog.byId['ad_free']!;
    expect(find.text(adFree.name), findsOneWidget);
    for (final line in adFree.shelfBullets) {
      expect(find.textContaining(line), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}