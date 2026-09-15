import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/greater_rift.dart';
import 'package:idle_party/core/rift.dart';
import 'package:idle_party/core/rift_pacing.dart';
import 'package:idle_party/models/dungeon_room.dart';

void main() {
  test('par follows kills × threat / refKps, then clamp', () {
    const kills = 40;
    const threat = 2.0;
    const refKps = 0.5;
    const guardian = 10000;
    final raw = guardian + (kills * threat / refKps * 1000).round();
    expect(
      RiftPacing.parTimeMs(
        killTarget: kills,
        threatMul: threat,
        refKps: refKps,
        guardianMs: guardian,
        minMs: 1000,
        maxMs: 999000,
      ),
      raw,
    );
    expect(
      RiftPacing.parTimeMs(
        killTarget: kills,
        threatMul: threat,
        refKps: refKps,
        guardianMs: guardian,
        minMs: 200000,
        maxMs: 300000,
      ),
      200000,
    );
  });

  test('Farm and GR clocks grow with work instead of shrinking', () {
    expect(Rift.parTimeMs(20), greaterThanOrEqualTo(Rift.parTimeMs(1)));
    expect(GreaterRift.parTimeMs(20), greaterThanOrEqualTo(GreaterRift.parTimeMs(1)));
    expect(Rift.parTimeMs(1), greaterThan(GreaterRift.parTimeMs(1)));
    expect(GreaterRift.parTimeMs(1), 60000);
  });

  test('same-party GR20 is a few times GR1 work, not a 100× fuse', () {
    double work(int t) => RiftPacing.workPerSecond(
          killTarget: GreaterRift.killTarget(t),
          threatMul: GreaterRift.threatMul(t),
          parMs: GreaterRift.parTimeMs(t),
        );
    final ratio = work(20) / work(1);
    expect(ratio, greaterThan(2));
    expect(ratio, lessThan(8));
    expect(GreaterRift.threatMul(20) / GreaterRift.threatMul(1), lessThan(5));
  });

  test('Farm density adds bodies; threat is the HP tax', () {
    final now = DateTime.utc(2026, 8, 24);
    final room = DungeonRoom(
      floorNumber: 1,
      roomIndex: 0,
      type: RoomType.normal,
      enemyLevel: 100,
      enemyCount: 8,
    );
    var hub = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
    );
    hub = hub.copyWith(
      heroRoster: [
        for (final h in hub.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    final plain = GameLogic.createEnemyGroup(room, fromState: hub);
    final farm = GameLogic.createEnemyGroup(
      room,
      fromState: hub.copyWith(inRift: true, riftTier: 20),
    );
    expect(farm.length, greaterThan(plain.length));
    final farmHp = farm.fold<int>(0, (s, e) => s + e.stats.maxHp);
    final plainHp = plain.fold<int>(0, (s, e) => s + e.stats.maxHp);
    expect(farmHp, greaterThan(plainHp));
  });
}
