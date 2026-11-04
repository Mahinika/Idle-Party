import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/theme.dart';

void main() {
  test('ShellLayout spacing aliases GameTheme gaps', () {
    expect(ShellLayout.sheetHorizontal, GameTheme.edgeGap);
    expect(ShellLayout.sectionGap, GameTheme.clusterGap);
    expect(ShellLayout.sheetPadding.left, GameTheme.edgeGap);
  });

  testWidgets('shell chrome golden at A56 logical size', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textTheme: TextTheme(bodyMedium: GameTheme.body()),
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(1),
          ),
          child: Scaffold(
            backgroundColor: GameTheme.ink,
            body: SingleChildScrollView(
              padding: ShellLayout.sheetPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('SHELL', style: GameTheme.menuTitle()),
                  ShellLayout.gap(),
                  ShellLayout.hint('Muted hint copy for sheets.'),
                  ShellLayout.gap(),
                  ShellLayout.card(
                    child: Text(
                      'List card',
                      style: GameTheme.body(color: GameTheme.torchHot),
                    ),
                  ),
                  ShellLayout.gap(),
                  ShellLayout.hubCard(
                    selected: true,
                    child: Text(
                      'Hub panel',
                      style: GameTheme.body(size: 14),
                    ),
                  ),
                  ShellLayout.gap(),
                  GameButton(
                    label: 'PRIMARY',
                    style: GameButtonStyle.brown,
                    primary: true,
                    onPressed: () {},
                  ),
                  ShellLayout.gap(4),
                  ShellLayout.secondaryActionRow(
                    children: [
                      GameButton(
                        label: 'SECONDARY A',
                        style: GameButtonStyle.grey,
                        dense: true,
                        onPressed: () {},
                      ),
                      GameButton(
                        label: 'SECONDARY B',
                        style: GameButtonStyle.grey,
                        dense: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/shell_chrome_a56.png'),
    );
  });
}
