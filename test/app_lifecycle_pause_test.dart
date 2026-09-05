import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';

void main() {
  test('appPaused freezes spatialTick combat', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
    );
    await director.boot();
    director.enterDungeon();
    expect(director.state.inDungeon, isTrue);
    expect(director.spatial, isNotNull);

    final frameBefore = director.visualFrame;
    director.spatialTick();
    expect(director.visualFrame, greaterThan(frameBefore));

    final pausedFrame = director.visualFrame;
    director.setAppPaused(true);
    expect(director.appPaused, isTrue);
    director.spatialTick();
    director.spatialTick();
    expect(director.visualFrame, pausedFrame);

    director.setAppPaused(false);
    director.spatialTick();
    expect(director.visualFrame, greaterThan(pausedFrame));
  });

  test('uiPaused still freezes combat independently of appPaused', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 7, 4)),
    );
    await director.boot();
    director.enterDungeon();
    director.spatialTick();
    final frame = director.visualFrame;
    director.setUiPaused(true);
    director.spatialTick();
    expect(director.visualFrame, frame);
    director.setUiPaused(false);
    director.spatialTick();
    expect(director.visualFrame, greaterThan(frame));
  });
}
