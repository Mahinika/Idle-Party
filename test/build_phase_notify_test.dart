import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setDungeonTilesReady during build does not setState', (
    tester,
  ) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    final errors = await _captureBuildErrors(tester, () async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedBuilder(
            animation: director,
            builder: (context, _) {
              director.setDungeonTilesReady(true);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
    });
    expect(errors, isEmpty);
    expect(director.dungeonTilesReady, isTrue);
  });

  testWidgets('clearToast during build does not setState', (tester) async {
    final director = GameDirector.preview();
    director.showToast('Party wiped');
    expect(director.toast, 'Party wiped');
    final errors = await _captureBuildErrors(tester, () async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedBuilder(
            animation: director,
            builder: (context, _) {
              director.clearToast();
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
    });
    expect(errors, isEmpty);
    expect(director.toast, isNull);
    director.dispose();
  });
}

Future<List<String>> _captureBuildErrors(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('setState()') || text.contains('markNeedsBuild')) {
      errors.add(text);
    } else {
      previous?.call(details);
    }
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}
