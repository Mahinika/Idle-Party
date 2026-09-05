import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/seeded.dart';

/// Runs for every test file under `test/`.
///
/// Combat, loot and pet rolls all read shared static RNG (`GameLogic.random`,
/// `EquipmentFactory.random`). Without a per-test seed the same code passed in
/// one run and failed in the next depending on how many rolls earlier tests
/// consumed. Seeding here makes every test start from the same stream.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => seedAll(20260816));
  tearDown(unseedAll);
  await testMain();
}
