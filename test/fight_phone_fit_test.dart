import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';
import 'package:idle_party/ui/shell/play_shell.dart';
import 'package:idle_party/ui/spatial_dungeon_view.dart';

/// Portrait phones the fight must fit: Samsung A56 and a short 360×640.
const _phones = <String, Size>{
  'a56': Size(360, 780),
  'small': Size(360, 640),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in _phones.entries) {
    testWidgets('fight chrome fits ${entry.key} (${entry.value.width.toInt()}x${entry.value.height.toInt()})', (
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

      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final director = await _fightDirector();
      var directorLive = true;
      addTearDown(() {
        if (directorLive) director.dispose();
      });
      final router = MenuRouter();
      addTearDown(router.dispose);

      final shot = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: MediaQuery(
            data: MediaQueryData(size: entry.value),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: PlayShell(director: director, router: router),
              ),
            ),
          ),
        ),
      );
      // Floor art decodes off the test clock. Wait until the HUD is up,
      // then let the enter toast finish so it is not part of the shot.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        if (director.dungeonTilesReady &&
            find.byType(DungeonTopHud).evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 1600));
      director.clearToast();
      await tester.pump();

      await _writeShot(tester, shot, 'fight-${entry.key}-after.png');

      expect(find.byType(DungeonTopHud), findsOneWidget);
      expect(find.byType(PartyCornerHud), findsOneWidget);
      expect(find.text('LEAVE'), findsOneWidget);

      final farm = find.byWidgetPredicate(
        (w) => w is DungeonModeChip && w.label.contains('FARM'),
      );
      final push = find.byWidgetPredicate(
        (w) => w is DungeonModeChip && w.label.contains('PUSH'),
      );
      final speed = find.byWidgetPredicate(
        (w) => w is DungeonModeChip && w.label.startsWith('SPEED'),
      );
      expect(farm, findsOneWidget);
      expect(push, findsOneWidget);
      expect(speed, findsOneWidget);
      expect(find.byType(GodHandRing), findsOneWidget);
      expect(find.bySemanticsLabel('Floor menu'), findsOneWidget);

      final screen = Rect.fromLTWH(0, 0, entry.value.width, entry.value.height);
      final controls = <String, Rect>{
        'farm': tester.getRect(farm),
        'push': tester.getRect(push),
        'speed': tester.getRect(speed),
        'fist': tester.getRect(find.byType(GodHandRing)),
        'floor': tester.getRect(find.bySemanticsLabel('Floor menu')),
        'leave': tester.getRect(
          find.ancestor(of: find.text('LEAVE'), matching: find.byType(InkWell)).first,
        ),
        'party': tester.getRect(find.byType(PartyCornerHud)),
        'top': tester.getRect(find.byType(DungeonTopHud)),
      };
      final target = find.byType(TargetCornerHud);
      if (target.evaluate().isNotEmpty) {
        final rect = tester.getRect(target);
        if (rect.width > 1 && rect.height > 1) controls['target'] = rect;
      }

      for (final item in controls.entries) {
        final r = item.value;
        // contains() excludes the right and bottom edges, and a full-bleed
        // HUD sits on x = width.
        final inside =
            r.left >= -0.5 &&
            r.top >= -0.5 &&
            r.right <= screen.width + 0.5 &&
            r.bottom <= screen.height + 0.5;
        expect(inside, isTrue, reason: '${item.key} sits outside the phone: $r');
      }

      for (final name in ['farm', 'push', 'speed', 'fist', 'floor', 'leave']) {
        final rect = controls[name]!;
        expect(
          rect.shortestSide,
          greaterThanOrEqualTo(40),
          reason: '$name is ${rect.size}, under a 40dp tap',
        );
      }

      final mustNotOverlap = [
        'farm',
        'push',
        'speed',
        'fist',
        'floor',
        'party',
        'top',
        if (controls.containsKey('target')) 'target',
        'leave',
      ];
      for (var i = 0; i < mustNotOverlap.length; i++) {
        for (var j = i + 1; j < mustNotOverlap.length; j++) {
          final a = mustNotOverlap[i];
          final b = mustNotOverlap[j];
          const inTop = {'farm', 'push', 'speed', 'fist', 'floor'};
          if ((a == 'top' && inTop.contains(b)) ||
              (b == 'top' && inTop.contains(a))) {
            continue;
          }
          final ra = controls[a]!.deflate(0.5);
          final rb = controls[b]!.deflate(0.5);
          expect(
            ra.overlaps(rb),
            isFalse,
            reason: '$a overlaps $b ($ra vs $rb)',
          );
        }
      }

      final gap = controls['party']!.top - controls['top']!.bottom;
      expect(
        gap,
        greaterThanOrEqualTo(160),
        reason: 'clear fight window is only ${gap.toStringAsFixed(0)}px',
      );

      for (final name in ['farm', 'push', 'speed']) {
        final text = tester.renderObject<RenderParagraph>(
          find.descendant(of: _chip(name, farm, push, speed), matching: find.byType(Text)),
        );
        final scale = text.getTransformTo(null).getMaxScaleOnAxis();
        expect(scale, greaterThanOrEqualTo(0.85), reason: '$name label scale $scale');
      }

      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);
      // Let sliced floor-art loads finish, then stop the director clock
      // before the tree goes away. One more beat flushes the zero-delay
      // floor-band ticket that the last frame queued.
      await tester.pump(const Duration(milliseconds: 400));
      director.dispose();
      directorLive = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    });
  }
}

Finder _chip(String name, Finder farm, Finder push, Finder speed) {
  return switch (name) {
    'farm' => farm,
    'push' => push,
    _ => speed,
  };
}

Future<GameDirector> _fightDirector() async {
  final base = GameLogic.createInitialState();
  final director = GameDirector.preview(
    initialState: base.copyWith(
      highestFloorCleared: 1,
      bossVictories: 1,
      // Entering a cave resets the floor counter. A real clear still
      // leaves the fight tools up.
      metaDepth: base.metaDepth.copyWith(lifetimeFloorClears: 1),
      seenTips: const [
        'first_run',
        'hub_enter',
        'godhand',
        'farm_push',
        'kit_abilities',
        'bag',
        'forge',
        'sanctuary',
      ],
    ),
  );
  await director.boot();
  director.enterDungeon();
  return director;
}

Future<void> _writeShot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  final dir = Directory('/opt/cursor/artifacts/screenshots');
  dir.createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
}
