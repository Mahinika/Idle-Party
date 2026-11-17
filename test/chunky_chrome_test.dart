import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/chunky_face.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_icon.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/ui/shell/buy_qty_toggle.dart';

/// Batch 6: chunky faces with one meaning per color.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  testWidgets('segmented: picked segment is the rose toggle, rows stay 44', (
    tester,
  ) async {
    var picked = 0;
    await pump(
      tester,
      SizedBox(
        width: 300,
        child: StatefulBuilder(
          builder: (context, setState) => MenuChrome.segmented(
            labels: const ['FARM', 'PUSH'],
            selectedIndex: picked,
            onSelect: (i) => setState(() => picked = i),
          ),
        ),
      ),
    );
    Text label(String s) => tester.widget<Text>(find.text(s));
    expect(label('FARM').style?.color, GameTheme.toggleOnText);
    expect(label('PUSH').style?.color, GameTheme.parchmentDim);
    final tap = tester.getSize(
      find.ancestor(of: find.text('PUSH'), matching: find.byType(InkWell)),
    );
    expect(tap.height, greaterThanOrEqualTo(GameTheme.minTouch));
    await tester.tap(find.text('PUSH'));
    await tester.pump();
    expect(label('PUSH').style?.color, GameTheme.toggleOnText);
  });

  testWidgets('GameButton: dark rim and a hard shadow; disabled is flat', (
    tester,
  ) async {
    BoxDecoration deco(String text) {
      final ink = tester.widget<Ink>(
        find.ancestor(of: find.text(text), matching: find.byType(Ink)),
      );
      return ink.decoration! as BoxDecoration;
    }

    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameButton(label: 'ENTER', onPressed: () {}, expanded: false),
          const GameButton(label: 'LOCKED', onPressed: null, expanded: false),
          GameButton(
            label: 'LEAVE',
            style: GameButtonStyle.red,
            onPressed: () {},
            expanded: false,
          ),
        ],
      ),
    );
    final enter = deco('ENTER');
    expect((enter.border! as Border).top.width, 2);
    expect((enter.border! as Border).top.color, GameTheme.buyGoldEdge);
    expect(enter.boxShadow!.single.color, GameTheme.chunkyShadow);
    expect(enter.boxShadow!.single.blurRadius, 0);
    expect(deco('LOCKED').boxShadow, isNull);
    expect((deco('LEAVE').border! as Border).top.color, GameTheme.chunkyRedEdge);
    expect(
      tester.getSize(find.byType(GameButton).first).height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
  });

  testWidgets('segmented with icons: the whole well is the tap and the face', (
    tester,
  ) async {
    await pump(
      tester,
      SizedBox(
        width: 330,
        child: MenuChrome.segmented(
          dense: true,
          labels: const ['FORGE', 'CAMP', 'MARKET'],
          icons: UiIcon.goldDockSegment,
          selectedIndex: 1,
          onSelect: (_) {},
        ),
      ),
    );
    final tap = tester.getSize(
      find.ancestor(of: find.text('CAMP'), matching: find.byType(InkWell)),
    );
    expect(tap.height, greaterThanOrEqualTo(GameTheme.minTouch));
  });

  testWidgets('x1/x10/MAX: the pick is a rose rim on stone, not a rose face', (
    tester,
  ) async {
    var qty = BuyQty.one;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BuyQtyToggle(
          value: qty,
          onChanged: (q) => setState(() => qty = q),
        ),
      ),
    );
    ChunkyFace face(String s) => tester.widget<ChunkyFace>(
      find.ancestor(of: find.text(s), matching: find.byType(ChunkyFace)),
    );
    Text label(String s) => tester.widget<Text>(find.text(s));

    await tester.tap(find.text('×10'));
    await tester.pump();
    final picked = face('×10');
    expect(picked.tone, ChunkyTone.stone);
    expect(picked.edgeColor, GameTheme.toggleOnTop);
    expect(picked.raised, isFalse);
    expect(label('×10').style?.color, GameTheme.toggleOnTop);
    for (final other in ['×1', 'MAX']) {
      expect(face(other).tone, ChunkyTone.stone);
      expect(face(other).edgeColor, isNull);
      expect(face(other).raised, isTrue);
      expect(label(other).style?.color, GameTheme.parchmentDim);
    }
    expect(
      find.byWidgetPredicate(
        (w) => w is ChunkyFace && w.tone == ChunkyTone.rose,
      ),
      findsNothing,
    );
    for (final s in ['×1', '×10', 'MAX']) {
      final r = tester.getSize(
        find.ancestor(of: find.text(s), matching: find.byType(InkWell)),
      );
      expect(r.height, greaterThanOrEqualTo(GameTheme.minTouch));
      expect(r.width, greaterThanOrEqualTo(BuyQtyToggle.buttonWidth));
    }
  });
}
