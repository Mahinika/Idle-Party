import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_analytics.dart';

void main() {
  test('AppAnalytics no-ops safely under flutter test', () async {
    await AppAnalytics.init();
    await AppAnalytics.syncConsent();
    await AppAnalytics.enterDungeon(
      dungeonId: 'sandy',
      keyLevel: 0,
      floor: 1,
    );
    await AppAnalytics.leaveDungeon(dungeonId: 'sandy', floor: 1);
    await AppAnalytics.partyWipe(dungeonId: 'sandy', floor: 1, streak: 1);
    await AppAnalytics.ascend(fromAl: 0, toAl: 1);
  });
}
