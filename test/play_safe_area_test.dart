import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/overlay_scaffold.dart';

void main() {
  testWidgets('playSafeArea strips status-bar padding like full-height GEAR', (
    tester,
  ) async {
    late double topInset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: 48, bottom: 24),
          viewPadding: EdgeInsets.only(top: 48, bottom: 24),
        ),
        child: MaterialApp(
          home: MenuChrome.playSafeArea(
            child: Builder(
              builder: (context) {
                topInset = MediaQuery.paddingOf(context).top;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    expect(topInset, 0);
  });

  testWidgets('full-height overlay sheet also strips top inset', (tester) async {
    late double topInset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          padding: EdgeInsets.only(top: 48, bottom: 24),
          viewPadding: EdgeInsets.only(top: 48, bottom: 24),
        ),
        child: MaterialApp(
          home: Stack(
            children: [
              OverlayScrim(
                title: 'GEAR',
                onClose: () {},
                heightFactor: 1,
                child: Builder(
                  builder: (context) {
                    topInset = MediaQuery.paddingOf(context).top;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(topInset, 0);
  });
}
