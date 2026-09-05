import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/play_store_update.dart';
import 'package:idle_party/ui/hub/hub_header.dart';
import 'package:idle_party/ui/play_update_required_screen.dart';

void main() {
  test('Play listing URL is English en-US', () {
    expect(PlayStoreUpdate.packageId, 'com.idleparty.app');
    expect(PlayStoreUpdate.listingUri.host, 'play.google.com');
    expect(PlayStoreUpdate.listingUri.queryParameters['hl'], 'en');
    expect(PlayStoreUpdate.listingUri.queryParameters['gl'], 'US');
  });

  test('preview director stays quiet (no Play probe in tests)', () {
    final director = GameDirector.preview();
    expect(PlayStoreUpdate.isSupported, isFalse);
    expect(director.showPlayUpdateNotice, isFalse);
    director.dismissPlayUpdateNotice();
    expect(director.state.metaDepth.dismissedPlayUpdateVersionCode, 0);
  });

  test('LATER persists dismissed Play versionCode', () {
    final director = GameDirector.preview();
    director.debugForcePlayUpdateNotice();
    expect(director.showPlayUpdateNotice, isTrue);
    director.dismissPlayUpdateNotice();
    expect(director.showPlayUpdateNotice, isFalse);
    expect(director.state.metaDepth.dismissedPlayUpdateVersionCode, 999999);
  });

  test('mandatory gate flag clears when Play probe is quiet', () {
    final director = GameDirector.preview();
    director.debugForceMandatoryPlayUpdate();
    expect(director.mandatoryPlayUpdateRequired, isTrue);
    return director.checkMandatoryPlayUpdate().then((blocked) {
      expect(blocked, isFalse);
      expect(director.mandatoryPlayUpdateRequired, isFalse);
    });
  });

  testWidgets('mandatory update screen has no LATER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayUpdateRequiredScreen(onUpdate: () {}),
      ),
    );
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(find.text('UPDATE'), findsOneWidget);
    expect(find.text('LATER'), findsNothing);
  });

  testWidgets('hub banner copy is English', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HubPlayUpdateBanner(onUpdate: () {}, onLater: () {}),
        ),
      ),
    );
    expect(find.text('UPDATE ON GOOGLE PLAY'), findsOneWidget);
    expect(find.text('A newer Idle Party is ready.'), findsOneWidget);
    expect(find.text('GET UPDATE'), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
  });
}
