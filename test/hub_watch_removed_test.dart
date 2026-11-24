import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classic hub screen does not mount BoostAdButton HUD', () {
    final src = File('lib/ui/hub_screen.dart').readAsStringSync();
    expect(src.contains('BoostAdButton'), isFalse);
    expect(src.contains('shell/boost_ad_button.dart'), isFalse);
  });
}