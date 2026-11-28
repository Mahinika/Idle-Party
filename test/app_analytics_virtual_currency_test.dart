import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/economy_service.dart';

void main() {
  test('virtual currency logs are sampled 1-in-10', () {
  final events = <String>[];
    AppAnalytics.debugSink = (name, params) => events.add(name);
    addTearDown(() => AppAnalytics.debugSink = null);

    for (var i = 0; i < 100; i++) {
      EconomyService.logGoldDelta(10, source: 'test');
    }
    expect(events.where((e) => e == 'earn_virtual_currency').length, lessThan(25));
    expect(events.where((e) => e == 'earn_virtual_currency').length, greaterThan(0));
  });
}