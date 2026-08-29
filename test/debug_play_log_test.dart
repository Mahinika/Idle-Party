import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/debug_play_log.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';

void main() {
  test('lines use [IP] so emulator logcat is filterable', () {
    expect(DebugPlayLog.line('nav', 'POWER/Gold'), '[IP] nav · POWER/Gold');
  });

  test('boot detail names hub chase and AL', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 29));
    final detail = DebugPlayLog.bootDetail(state);
    expect(detail, contains('AL0'));
    expect(detail, contains('hub'));
    expect(detail, contains('chase'));
  });

  test('state delta skips tiny gold ticks and notes forge / KEY', () {
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 29));
    expect(DebugPlayLog.stateDelta(base, base.copyWith(gold: base.gold + 3)), isNull);
    final bought = base.copyWith(attackBonus: base.attackBonus + 2, gold: 10);
    expect(DebugPlayLog.stateDelta(base, bought), contains('ATK'));
    expect(
      DebugPlayLog.stateDelta(base, base.copyWith(hardmodeLevel: 4)),
      contains('KEY 0→4'),
    );
  });

  test('menu debugWhere uses everyday POWER tab names', () {
    final router = MenuRouter();
    expect(router.debugWhere, 'closed');
    router.open(MenuRoute.power, power: PowerSegment.market);
    expect(router.debugWhere, 'POWER/Shop');
    router.powerSegment = PowerSegment.camp;
    expect(router.debugWhere, 'POWER/Forever');
  });
}
