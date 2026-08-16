import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../models/enemy.dart';
import '../../spatial/spatial_combat.dart';
import '../game_theme.dart';

class TargetCornerHud extends StatelessWidget {
  const TargetCornerHud({super.key, required this.director});
  final GameDirector director;

  @override
  Widget build(BuildContext context) {
    final world = director.spatial;
    final state = director.state;
    SpatialActor? focus;
    if (world != null) {
      for (final e in world.enemies) {
        if (e.hp <= 0 || e.dormant) continue;
        if (e.livingBombTimer > 0) {
          focus = e;
          break;
        }
      }
      if (focus == null) {
        final leader = world.leader;
        final lx = leader?.x ?? 0;
        final ly = leader?.y ?? 0;
        double best = double.infinity;
        for (final e in world.enemies) {
          if (e.hp <= 0 || e.dormant) continue;
          final dx = e.x - lx;
          final dy = e.y - ly;
          final d = dx * dx + dy * dy;
          if (d < best) {
            best = d;
            focus = e;
          }
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
            EnemyRole.normal => '',
          };
    final hpFrac = enemy == null || enemy.maxHp <= 0
        ? 0.0
        : (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final phone = GameTheme.isPhoneWidth(context);
    // Name only — role is color/border so the chip stays one readable line.
    final titleColor = role == 'BOSS'
        ? GameTheme.bloodLit
        : (role == 'ELITE' ? GameTheme.torch : GameTheme.parchment);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: phone ? 128.0 : 148.0),
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
            Row(
              children: [
                if (role.isNotEmpty) ...[
                  Text(
                    role == 'BOSS' ? 'B' : 'E',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: titleColor,
                    ),
                  ),
                ),
                if (enemy != null)
                  Text(
                    '${(hpFrac * 100).round()}%',
                    style: GameTheme.body(
                      size: 11,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
              ],
            ),
            if (enemy != null) ...[
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: hpFrac,
                  minHeight: phone ? 3 : 4,
                  backgroundColor: const Color(0xFF2A241C),
                  color: hpFrac > 0.35
                      ? GameTheme.bloodLit
                      : GameTheme.blood,
                ),
              ),
            ] else
              Text(
                state.isPartyDefeated
                    ? (state.inGauntlet ? 'End → hub' : 'Retry / Hub')
                    : 'Walk to stairs',
                style: GameTheme.body(
                  size: 11,
                  color: GameTheme.parchmentDim,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
