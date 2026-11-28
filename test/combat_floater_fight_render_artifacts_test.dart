import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final artifacts = Directory('/opt/cursor/artifacts');
  if (!artifacts.existsSync()) {
    test('artifacts dir missing on this runner', () {}, skip: 'No /opt/cursor/artifacts');
    return;
  }

  test('copies real A56 fight renders to artifacts', () {
    final after = File('test/goldens/after/fight_hit_a56.png');
    final minimal = File('test/goldens/after/fight_hit_min_a56.png');
    final ticker = File('test/goldens/widgets/combat_fight_ticker_a56.png');
    final before = File('test/goldens/before/fight_hit_a56.png');
    expect(after.existsSync(), isTrue);
    expect(minimal.existsSync(), isTrue);
    expect(ticker.existsSync(), isTrue);
    expect(before.existsSync(), isTrue);
    before.copySync('${artifacts.path}/combat-floater-fight-before-a56.png');
    after.copySync('${artifacts.path}/combat-floater-fight-after-a56.png');
    minimal.copySync('${artifacts.path}/combat-floater-fight-minimal-a56.png');
    ticker.copySync('${artifacts.path}/combat-floater-fight-ticker-a56.png');
  });
}