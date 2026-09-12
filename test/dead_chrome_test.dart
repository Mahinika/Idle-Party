import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/first_session_tips.dart';

/// Removed chrome must not come back as a tab, button, or day-one lesson.
void main() {
  const forbiddenLabels = <String>{
    'LOADOUTS',
    'SELL JUNK',
    'SCRAP',
    'GEAR SELL',
  };

  test('prestige shop does not offer Loadout Folio', () {
    expect(
      PrestigeShopCatalog.offered.map((i) => i.id),
      isNot(contains('loadout_slot')),
    );
  });

  test('GEAR panels have no LOADOUTS destination', () {
    expect(GearPanel.values.map((e) => e.name), isNot(contains('loadouts')));
    expect(GearPanel.values.map((e) => e.name), isNot(contains('sell')));
  });

  test('UI buttons never restore Sell junk / Scrap / LOADOUTS / GEAR Sell', () {
    final labelRe = RegExp(r"label:\s*'([^']+)'");
    final files = Directory('lib/ui')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      for (final match in labelRe.allMatches(file.readAsStringSync())) {
        final label = match.group(1)!.trim().toUpperCase();
        expect(
          forbiddenLabels.contains(label),
          isFalse,
          reason: '${file.path} still shows "$label"',
        );
      }
    }
  });

  test('first-session copy does not teach removed bag buttons', () {
    final joined = FirstSessionTips.tips.map((t) => '${t.title} ${t.body}').join('\n');
    expect(joined.toUpperCase(), isNot(contains('LOADOUTS')));
    expect(joined.toUpperCase(), isNot(contains('SELL JUNK')));
    expect(joined.toUpperCase(), isNot(contains('GEAR SELL')));
  });

  test('a new save never sees LOADOUTS jargon in first-hour INFO', () {
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 9, 12, 14),
    );
    expect(state.loadouts, isEmpty);
  });
}
