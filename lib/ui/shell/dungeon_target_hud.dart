import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../models/enemy.dart';
import '../../spatial/spatial_combat.dart';
import '../game_theme.dart';
import '../menu_chrome.dart';
import 'shell_common.dart';

/// Reserved height for the fight target strip under the top HUD row.
double targetStripHeight(TextScaler scaler) {
  final raw = scaler.scale(1);
  final scale = raw.clamp(1.0, GameTheme.typeScaleMax);
  final vPad = scale >= 1.4 ? 1.0 : 2.0;
  // Measured from combat + hint on two lines (name row + HP row).
  // Name row may wrap to two lines on wide targets; reserve two at 1.45.
  final titleLine = GameTheme.hudPixelComfort * 1.2 * scale;
  final hpLine = GameTheme.hudPixel * 1.35 * scale;
  final hpRow = math.max(hpLine, GameTheme.minTouch);
  final between = 2.0;
  // Accessibility > 1.45 (stress tests): grow the reserved slot.
  final slack = raw > GameTheme.typeScaleMax
      ? (raw - GameTheme.typeScaleMax) * GameTheme.hudPixel * 1.2
      : 0.0;
  const layoutSlack = 6.0;
  return vPad + titleLine + between + hpRow + vPad + slack + layoutSlack;
}

/// Top inset for the short boss callout, below the target strip.
double bossIntroBannerTop(double textScale) {
  final scale = textScale.clamp(1.0, GameTheme.typeScaleMax);
  return targetStripHeight(TextScaler.linear(scale)) + 6;
}

/// Timed "BOSS — name" callout. Sits in open map, not on the corner frame.
class BossIntroBanner extends StatelessWidget {
  const BossIntroBanner({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: GameTheme.toastDangerBottom,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GameTheme.torchHot),
            ),
            child: Text(
              'BOSS — $name',
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GameTheme.combat(comfort: true, color: GameTheme.torchHot),
            ),
          ),
        ),
      ),
    );
  }
}

class TargetCornerHud extends StatelessWidget {
  const TargetCornerHud({
    super.key,
    required this.director,
    this.edgeInset = true,
    this.minTitleWidth = 0,
    this.hpRowTrailing,
  });

  final GameDirector director;

  /// Home top bar already pads the width — skip a second inset there.
  final bool edgeInset;

  /// Keeps the enemy title readable when the row also carries quest chips.
  final double minTitleWidth;

  /// Floor badge, DPS pill, and quest chip on the HP row (line 2).
  final List<Widget>? hpRowTrailing;

  /// Enemy name on the target strip (line 1).
  static const Key titleKey = ValueKey('target-corner-title');

  static const Key stripKey = ValueKey('target-strip-hud');

  static const Key roleTagKey = ValueKey('target-corner-role-tag');

  /// Smallest target strip the row should reserve before wrapping quest chips.
  static double minLayoutWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final hintStyle = GameTheme.hint(color: GameTheme.parchmentDim);
    final hpNum = TextPainter(
      text: TextSpan(text: '9999', style: hintStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    const wellPadding = 16.0;
    const innerPadding = 8.0 * 2;
    const gaps = 8.0;
    const tagReserve = 44.0;
    return tagReserve + hpNum.width + wellPadding + innerPadding + gaps + 48;
  }

  static String? _roleTagLabel({
    required EnemyRole role,
    required EnemyArchetype archetype,
  }) {
    if (role == EnemyRole.boss) return 'BOSS';
    if (role == EnemyRole.elite) return 'ELITE';
    if (archetype == EnemyArchetype.swarm) return 'SWARM';
    return null;
  }

  static Color _roleTagColor(String tag) => switch (tag) {
    'BOSS' => GameTheme.bloodLit,
    'ELITE' => GameTheme.torch,
    'SWARM' => GameTheme.mossLit,
    _ => GameTheme.parchmentDim,
  };

  SpatialActor? _focusEnemy(SpatialWorld? world, GameDirector director) {
    if (world == null) return null;
    SpatialActor? focus;
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
      if (boss != null) {
        focus = boss;
      } else if (bomb != null) {
        focus = bomb;
      } else {
        focus = nearest;
      }
    } else if (focus.livingBombTimer > 0) {
      for (final e in world.enemies) {
        if (e.hp > 0 && !e.dormant && e.role == EnemyRole.boss) {
          focus = e;
          break;
        }
      }
    }
    return focus;
  }

  @override
  Widget build(BuildContext context) {
    final world = director.spatial;
    final state = director.state;
    final height = targetStripHeight(MediaQuery.textScalerOf(context));
    final edge = edgeInset ? GameTheme.edgeGap : 0.0;
    final enemy = _focusEnemy(world, director);
    final awaitingExit = world?.awaitingExit == true;

    if (awaitingExit && !state.isPartyDefeated) {
      return _stripShell(
        context,
        height: height,
        edge: edge,
        borderColor: GameTheme.clear.withValues(alpha: 0.7),
        child: _twoLineBody(
          title: Text(
            'CLEAR',
            key: titleKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.combat(color: GameTheme.clear),
          ),
          secondary: Text(
            _stairsHint(world),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.hint(color: GameTheme.parchmentDim),
          ),
        ),
      );
    }

    final showEmpty =
        enemy == null && !state.isPartyDefeated && !awaitingExit;
    final label = enemy == null
        ? (state.isPartyDefeated
              ? 'WIPED'
              : awaitingExit
              ? 'CLEAR'
              : '—')
        : enemy.name.toUpperCase();
    final roleTag = enemy == null
        ? null
        : _roleTagLabel(role: enemy.role, archetype: enemy.archetype);
    final hpFrac = enemy == null || enemy.maxHp <= 0
        ? 0.0
        : (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final swarmPack =
        enemy != null &&
        enemy.archetype == EnemyArchetype.swarm &&
        world != null;
    final foeCount = swarmPack
        ? world.enemies.where((e) => e.hp > 0 && !e.dormant && e.isAlive).length
        : 0;
    final borderColor = showEmpty
        ? GameTheme.hudWellBorder.withValues(alpha: 0.35)
        : roleTag == 'BOSS'
        ? GameTheme.bloodLit.withValues(alpha: 0.7)
        : (roleTag == 'ELITE'
              ? GameTheme.torch.withValues(alpha: 0.55)
              : GameTheme.hudWellBorder);
    final bombBit = enemy != null && enemy.livingBombTimer > 0
        ? ' · BOMB ${formatCombatSeconds(enemy.livingBombTimer)}'
        : '';
    final nameLine = '$label$bombBit';
    final hpLabel = enemy == null
        ? ''
        : swarmPack
        ? '$foeCount foes'
        : (SpatialCombat.compactNumbers
              ? SpatialCombat.compactCount(enemy.hp)
              : '${enemy.hp}');

    final title = Tooltip(
      message: roleTag == null ? nameLine : '$roleTag · $nameLine',
      child: Text(
        nameLine,
        key: titleKey,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.clip,
        style: GameTheme.combat(
          color: showEmpty
              ? GameTheme.parchmentDim.withValues(alpha: 0.55)
              : GameTheme.parchment,
        ),
      ),
    );
    final titleRow = Row(
      children: [
        if (roleTag != null) ...[
          _TargetRoleTag(label: roleTag, color: _roleTagColor(roleTag)),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: minTitleWidth > 0
              ? ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minTitleWidth),
                  child: title,
                )
              : title,
        ),
      ],
    );

    final trailing = hpRowTrailing;
    Widget? hpRow;
    if (enemy != null && hpLabel.isNotEmpty) {
      hpRow = Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 32),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: hpFrac,
                        minHeight: 3,
                        backgroundColor: GameTheme.equipChipBlocked,
                        color:
                            hpFrac > 0.35 ? GameTheme.bloodLit : GameTheme.blood,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hpLabel,
                    maxLines: 1,
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
                ],
              ),
            ),
          ),
          ...?trailing,
        ],
      );
    } else if (enemy == null && state.isPartyDefeated) {
      hpRow = Text(
        state.inGauntlet || state.inAnyRiftMode ? 'End → hub' : 'Retry / Hub',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GameTheme.hint(color: GameTheme.parchmentDim),
      );
    }

    return _stripShell(
      context,
      height: height,
      edge: edge,
      borderColor: borderColor,
      dim: showEmpty,
      child: _twoLineBody(title: titleRow, secondary: hpRow),
    );
  }

  Widget _twoLineBody({required Widget title, Widget? secondary}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        if (secondary != null) ...[
          const SizedBox(height: 2),
          secondary,
        ],
      ],
    );
  }

  Widget _stripShell(
    BuildContext context, {
    required double height,
    required double edge,
    required Color borderColor,
    required Widget child,
    bool dim = false,
  }) {
    return KeyedSubtree(
      key: stripKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(edge, 0, edge, 0),
        child: SizedBox(
          height: height,
          child: Opacity(
            opacity: dim ? 0.55 : 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 1, 8, 1),
              decoration: MenuChrome.hudWell(borderColor: borderColor),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  static String _stairsHint(SpatialWorld? world) {
    if (world == null) return 'GO stairs';
    final leader = world.leader;
    if (leader == null) return 'GO stairs';
    final ex = world.map.exitPoint.$1 + 0.5;
    final ey = world.map.exitPoint.$2 + 0.5;
    final dx = ex - leader.x;
    final dy = ey - leader.y;
    if (dx * dx + dy * dy < 1.2) return 'Stairs · here';
    String horiz = dx.abs() < 0.35 ? '' : (dx > 0 ? 'E' : 'W');
    String vert = dy.abs() < 0.35 ? '' : (dy > 0 ? 'N' : 'S');
    final dir = '$vert$horiz';
    return dir.isEmpty ? 'GO stairs' : 'GO stairs · $dir';
  }
}

class _TargetRoleTag extends StatelessWidget {
  const _TargetRoleTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: TargetCornerHud.roleTagKey,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.85)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: GameTheme.combat(color: color),
      ),
    );
  }
}