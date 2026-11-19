import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/theme.dart';

import 'shell_golden_harness.dart';

/// Root for small per-widget / per-menu goldens (not the full-shell
/// `goldens/after/` set).
String get widgetGoldenRoot => const String.fromEnvironment(
  'WIDGET_GOLDEN_ROOT',
  defaultValue: 'goldens/widgets',
);

/// Pump a single widget or menu on the A56 logical surface and compare
/// a golden.
///
/// Generate and regenerate on Linux with the Flutter pin from
/// `.github/workflows/ci.yml`. Always re-run the whole test file; a
/// single named test renders differently.
Future<void> pumpWidgetGolden(
  WidgetTester tester,
  Widget child, {
  required String name,
  ThemeData? theme,
  Color? background,
}) async {
  bindA56View(tester);
  await ensureShellGoldenFonts();
  await tester.pumpWidget(
    MediaQuery(
      data: shellGoldenMedia,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme:
            theme ??
            ThemeData(textTheme: TextTheme(bodyMedium: GameTheme.body())),
        home: Scaffold(
          backgroundColor: background ?? GameTheme.ink,
          body: child,
        ),
      ),
    ),
  );
  await pumpGoldenFrames(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$widgetGoldenRoot/$name'),
  );
}
