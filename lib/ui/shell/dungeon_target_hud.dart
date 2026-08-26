import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../models/enemy.dart';
import '../../spatial/spatial_combat.dart';
import '../game_theme.dart';

class TargetCornerHud extends StatelessWidget {
  const TargetCornerHud({super.key, required this.director});
  final GameDirector director;

  static String _archetypeLabel(EnemyArchetype a) => switch (a) {
        EnemyArchetype.swarm => 'SWARM',
        EnemyArchetype.brute => 'MELEE',
        EnemyArchetype.tank => 'TANK',
        EnemyArchetype.ranged => 'RANGED',
        EnemyArchetype.glass => 'GLASS',
        EnemyArchetype.support => 'SUPPORT',
      };

  @override
  Widget build(BuildContext context) {
    final world = director.spatial;
    final state = director.state;
    SpatialActor? focus;
    if (world != null) {
      final pinnedId = director.hudFocusEnemyId;
      if (pinnedId != null) {
        for (final e in world.enemies) {
          if (e.id == pinnedId && e.hp > 0 && !e.dormant) {
            focus = e;
            break;
          }
        }
      }
      if (focus == null) {
        SpatialActor? boss;
        SpatialActor? bomb;
        final leader = world.leader;
        final lx = leader?.x ?? 0;
        final ly = leader?.y ?? 0;
        double best = double.infinity;
        SpatialActor? nearest;
        for (final e in world.enemies) {
          if (e.hp <= 0 || e.dormant) continue;
          if (e.role == EnemyRole.boss) boss ??= e;
          if (e.livingBombTimer > 0) bomb ??= e;
          final dx = e.x - lx;
          final dy = e.y - ly;
          final d = dx * dx + dy * dy;
          if (d < best) {
            best = d;
            nearest = e;
          }
        }
        // Living Bomb highlights trash — don't steal the boss frame.
        if (boss != null) {
          focus = boss;
        } else if (bomb != null) {
          focus = bomb;
        } else {
          focus = nearest;
        }
      }
    }

    final enemy = focus;
    final awaitingExit = world?.awaitingExit == true;
    // Hide empty chrome — reclaim map until a foe / wipe / clear matters.
    if (enemy == null && !state.isPartyDefeated && !awaitingExit) {
      return const SizedBox.shrink();
    }

    final label = enemy == null
        ? (state.isPartyDefeated
              ? 'WIPED'
              : awaitingExit
              ? 'CLEAR'
              : '—')
        : enemy.name.toUpperCase();
    final role = enemy == null
        ? ''
        : switch (enemy.role) {
            EnemyRole.boss => 'BOSS',
            EnemyRole.elite => 'ELITE',
            EnemyRole.normal => _archetypeLabel(enemy.archetype),
          };
    final hpFrac = enemy == null || enemy.maxHp <= 0
        ? 0.0
        : (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final phone = GameTheme.isPhoneWidth(context);
    final titleColor = role == 'BOSS'
        ? GameTheme.bloodLit
        : (role == 'ELITE' ? GameTheme.torch : GameTheme.parchment);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: phone ? 200.0 : 180.0),
      child: Container(
        padding: EdgeInsets.fromLTRB(6, phone ? 3 : 4, 6, phone ? 4 : 5),
        decoration: BoxDecoration(
          color: const Color(0xCC14110C),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: role == 'BOSS'
                ? GameTheme.bloodLit.withValues(alpha: 0.7)
                : (role == 'ELITE'
                      ? GameTheme.torch.withValues(alpha: 0.55)
                      : const Color(0x665A5040)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (role.isNotEmpty)
              Text(
                role,
                style: GameTheme.pixel(
                  size: GameTheme.hudPixel,
                  color: titleColor,
                ),
              ),
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: titleColor,
              ),
            ),
            if (enemy != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: hpFrac,
                        minHeight: phone ? 3 : 4,
                        backgroundColor: GameTheme.equipChipBlocked,
                        color: hpFrac > 0.35
                            ? GameTheme.bloodLit
                            : GameTheme.blood,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${enemy.hp} ${(hpFrac * 100).round()}%',
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                state.isPartyDefeated
                    ? (state.inGauntlet || state.inAnyRiftMode
                        ? 'End → hub'
                        : 'Retry / Hub')
                    : 'Walk to stairs',
                style: GameTheme.body(size: 11, color: GameTheme.parchmentDim),
              ),
          ],
        ),
      ),
    );
  }
}
