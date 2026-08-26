import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../models/class_ability.dart';
import '../../models/enemy.dart';
import '../../models/hero.dart';
import '../../models/hero_spec.dart';
import '../../models/loot.dart';
import '../../spatial/spatial_combat.dart';
import '../game_theme.dart';
import '../hero_doll_sprite.dart';
import '../kenney_assets.dart';
import '../kenney_sprite.dart';
import '../web_click_bridge.dart';

class PartyCornerHud extends StatefulWidget {
  const PartyCornerHud({
    super.key,
    required this.director,
    required this.selectedHeroIndex,
    required this.onSelectHero,
    required this.onOpenEquip,
    required this.onUseConsumable,
  });
  final GameDirector director;
  final int selectedHeroIndex;
  final ValueChanged<int> onSelectHero;
  final VoidCallback onOpenEquip;
  final VoidCallback onUseConsumable;

  @override
  State<PartyCornerHud> createState() => _PartyCornerHudState();
}

class _PartyCornerHudState extends State<PartyCornerHud> {
  static const _idleFade = Duration(seconds: 8);
  static const _idleFadePhone = Duration(seconds: 5);
  static const _fullOpacity = 1.0;
  static const _dimOpacity = 0.55;
  static const _dimOpacityPhone = 0.85;
  static const _hudScale = 1.0;

  Timer? _fadeTimer;
  double _opacity = _fullOpacity;

  /// Kit chips only when the player taps a strip (map stays clear by default).
  bool _kitOpen = true;

  @override
  void initState() {
    super.initState();
    _scheduleFade();
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _bump() {
    _fadeTimer?.cancel();
    if (_opacity < _fullOpacity) {
      setState(() => _opacity = _fullOpacity);
    }
    final phone = mounted && GameTheme.isPhoneWidth(context);
    _scheduleFade(phone: phone);
  }

  void _scheduleFade({bool phone = false}) {
    _fadeTimer = Timer(phone ? _idleFadePhone : _idleFade, () {
      if (!mounted) return;
      setState(() => _opacity = phone ? _dimOpacityPhone : _dimOpacity);
    });
  }

  SpatialActor? _spatialFor(SpatialWorld? world, int i) {
    if (world == null) return null;
    for (final a in world.heroes) {
      if (!a.isPet && a.assetIndex == i) return a;
    }
    return null;
  }

  static int _flaskCount(GameState state) {
    var n = 0;
    for (final h in state.heroes) {
      final c = h.itemIn(EquipmentSlot.consumable);
      if (c != null && c.iconId == 'flask') n++;
    }
    for (final g in state.gearStash) {
      if (g.slot == EquipmentSlot.consumable && g.iconId == 'flask') n++;
    }
    return n;
  }

  void _onHeroTap(int i) {
    _bump();
    final fighting =
        widget.director.spatial?.enemies.any((e) => e.isAlive) ?? false;
    if (widget.selectedHeroIndex == i && _kitOpen) {
      // Keep kit open mid-fight so a second tap doesn't hide CD chips.
      if (fighting) return;
      setState(() => _kitOpen = false);
      return;
    }
    widget.onSelectHero(i);
    setState(() => _kitOpen = true);
  }

  Future<void> _onLongPressGear() async {
    _bump();
    final fighting =
        widget.director.spatial?.enemies.any((e) => e.isAlive) ?? false;
    if (!fighting || !mounted) {
      widget.onOpenEquip();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameTheme.stoneDeep,
        title: Text(
          'Open gear?',
          style: GameTheme.pixel(size: 12, color: GameTheme.torchHot),
        ),
        content: Text(
          'You are mid-fight. Open GEAR anyway?',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'OPEN GEAR',
              style: GameTheme.body(size: 13, color: GameTheme.torchHot),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) widget.onOpenEquip();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.director.state;
    final world = widget.director.spatial;
    final canUseFlask = GameLogic.canUseConsumable(state);
    final compact = GameTheme.isCompactWidth(context);
    final phone = GameTheme.isPhoneWidth(context);
    // Thin strip: reclaim map; kit expands in place when tapped.
    final fullWidth = phone ? 168.0 : (compact ? 188.0 : 228.0);
    var partyCritical = false;
    final bossFight =
        world != null &&
        world.enemies.any(
          (e) => e.hp > 0 && !e.dormant && e.role == EnemyRole.boss,
        );
    for (var i = 0; i < state.heroes.length; i++) {
      final s = _spatialFor(world, i);
      final hp = s?.hp ?? state.heroes[i].currentHp;
      final maxHp =
          s?.effectiveMaxHp ?? state.effectiveHeroMaxHp(state.heroes[i]);
      if (maxHp <= 0) continue;
      if (hp <= 0) {
        if (bossFight ||
            (world?.enemies.any((e) => e.hp > 0 && !e.dormant) ?? false)) {
          partyCritical = true;
          break;
        }
      }
      final threshold = 0.35;
      if (hp > 0 && hp / maxHp <= threshold) {
        partyCritical = true;
        break;
      }
    }

    final flaskCount = _flaskCount(state);

    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: fullWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xCC14110C),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x665A5040)),
            ),
            padding: EdgeInsets.fromLTRB(
              phone ? 3 : 4,
              phone ? 3 : 4,
              phone ? 3 : 4,
              phone ? 3 : 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < state.heroes.length; i++) ...[
                  if (i > 0) SizedBox(height: phone ? 1.0 : 2.0),
                  WebClickScope(
                    label: state.heroes[i].name,
                    onPressed: () => _onHeroTap(i),
                    child: Semantics(
                      button: true,
                      selected: widget.selectedHeroIndex == i,
                      label:
                          '${state.heroes[i].name} '
                          '${state.heroes[i].roleLabel} — tap for kit, '
                          'long-press for gear',
                      onTap: () => _onHeroTap(i),
                      onLongPress: _onLongPressGear,
                      excludeSemantics: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onHeroTap(i),
                          onLongPress: _onLongPressGear,
                          borderRadius: BorderRadius.circular(3),
                          child: _PartyRow(
                            index: i,
                            hero: state.heroes[i],
                            selected: widget.selectedHeroIndex == i,
                            kitOpen: widget.selectedHeroIndex == i && _kitOpen,
                            compact:
                                phone || compact || state.heroes.length >= 4,
                            phone: phone,
                            inCombat: world?.enemies.any((e) => e.isAlive) ??
                                false,
                            liveHp: () {
                              final s = _spatialFor(world, i);
                              return s?.hp ?? state.heroes[i].currentHp;
                            }(),
                            maxHp: () {
                              final s = _spatialFor(world, i);
                              return s?.effectiveMaxHp ??
                                  state.effectiveHeroMaxHp(state.heroes[i]);
                            }(),
                            spatial: (widget.selectedHeroIndex == i && _kitOpen)
                                ? _spatialFor(world, i)
                                : null,
                            world: world,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canUseFlask) ...[
            SizedBox(height: phone ? 5 : 4),
            _FlaskQuickSlot(
              urgent: partyCritical,
              phone: phone,
              count: flaskCount,
              onTap: () {
                _bump();
                widget.onUseConsumable();
              },
            ),
          ],
        ],
      ),
    );

    return AnimatedOpacity(
      opacity: partyCritical ? _fullOpacity : _opacity,
      duration: const Duration(milliseconds: 400),
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (_) {
          _fadeTimer?.cancel();
          if (_opacity < _fullOpacity) {
            setState(() => _opacity = _fullOpacity);
          }
          _scheduleFade(phone: phone);
        },
        child: SizedBox(
          width: fullWidth * _hudScale,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.bottomLeft,
            child: SizedBox(width: fullWidth, child: panel),
          ),
        ),
      ),
    );
  }
}

class _FlaskQuickSlot extends StatelessWidget {
  const _FlaskQuickSlot({
    required this.onTap,
    this.urgent = false,
    this.phone = false,
    this.count = 0,
  });
  final VoidCallback onTap;
  final bool urgent;
  final bool phone;
  final int count;

  @override
  Widget build(BuildContext context) {
    final borderColor = urgent
        ? GameTheme.torchHot
        : GameTheme.bloodLit.withValues(alpha: 0.8);
    final countBit = count > 0 ? ' ×$count' : '';
    final semanticsLabel = urgent
        ? 'Use healing flask$countBit, party critical'
        : 'Use healing flask$countBit';
    return WebClickScope(
      label: semanticsLabel,
      onPressed: onTap,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              constraints: BoxConstraints(
                minHeight: phone ? GameTheme.minTouch : 0,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: phone ? 10 : 8,
                vertical: phone ? 8 : 5,
              ),
              decoration: BoxDecoration(
                color: urgent
                    ? const Color(0xEE4A2010)
                    : const Color(0xDD2A1810),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor, width: urgent ? 2 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KenneySprite(
                    asset: KenneyAssets.potionRed,
                    size: phone ? 18 : 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${urgent ? 'FLASK!' : 'FLASK'}$countBit',
                    style: GameTheme.pixel(
                      size: GameTheme.hudPixel,
                      color: urgent ? GameTheme.torchHot : GameTheme.parchment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.index,
    required this.hero,
    required this.liveHp,
    required this.maxHp,
    this.selected = false,
    this.kitOpen = false,
    this.compact = false,
    this.phone = false,
    this.inCombat = false,
    this.spatial,
    this.world,
  });

  final int index;
  final PartyHero hero;
  final int liveHp;
  final int maxHp;
  final bool selected;
  final bool kitOpen;
  final bool compact;
  final bool phone;
  final bool inCombat;
  final SpatialActor? spatial;
  final SpatialWorld? world;

  bool _abilityBuffActive(ClassAbilityDef ability, SpatialActor s) {
    return switch (ability.id) {
      AbilityId.shieldBlock => s.shieldBlockTimer > 0,
      AbilityId.shieldWall => s.shieldWallTimer > 0,
      AbilityId.lastStand => s.lastStandTimer > 0,
      AbilityId.shieldSlam => s.queuedShieldSlam,
      AbilityId.shockwave => s.shockwaveFlash > 0,
      AbilityId.powerWordShield => s.absorbShield > 0,
      AbilityId.prayerOfMending => s.pomCharges > 0,
      AbilityId.painSuppression => s.painSuppressionTimer > 0,
      AbilityId.powerInfusion => s.powerInfusionTimer > 0,
      AbilityId.innerFire => s.innerFireActive,
      AbilityId.combustion => s.combustionTimer > 0,
      AbilityId.furyRecklessness => s.combustionTimer > 0,
      AbilityId.vendetta ||
      AbilityId.coldBlood ||
      AbilityId.arcanePower => s.combustionTimer > 0,
      AbilityId.pyroblast => s.hotStreakReady,
      AbilityId.iceBlock ||
      AbilityId.arcaneIceBlock ||
      AbilityId.frostMageIceBlock => s.iceBlockTimer > 0,
      AbilityId.livingBomb => s.livingBombArmed > 0,
      AbilityId.sliceAndDice => s.sliceAndDiceTimer > 0,
      AbilityId.bladeFlurry => s.bladeFlurryTimer > 0,
      AbilityId.sweepingStrikes => s.bladeFlurryTimer > 0,
      AbilityId.holyShield => s.shieldBlockTimer > 0,
      AbilityId.beaconOfLight => s.beaconTimer > 0,
      AbilityId.divineFavor => (s.buffTimers['favor'] ?? 0) > 0,
      AbilityId.sprint => s.sprintTimer > 0,
      AbilityId.vanish => s.vanishTimer > 0,
      AbilityId.killingSpree => s.killingSpreeTimer > 0,
      _ =>
        ability.effect == AbilityEffectKind.selfBuff &&
            ((s.buffTimers['buff'] ?? 0) > 0 ||
                (s.buffTimers['shield'] ?? 0) > 0 ||
                s.powerInfusionTimer > 0 ||
                s.shieldBlockTimer > 0 ||
                s.combustionTimer > 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    final frac = maxHp <= 0 ? 0.0 : (liveHp / maxHp).clamp(0.0, 1.0);
    // Keep full shortLabel (PROT/COMBAT/…) — only ellipsis if the strip is tiny.
    final roleShort = hero.roleLabel;
    final showKit = kitOpen && spatial != null && spatial!.isAlive;
    final resource = showKit ? spatial!.rage.clamp(0.0, 100.0).toDouble() : 0.0;
    final off = hero.itemIn(EquipmentSlot.offHand);
    final hasShield = off?.offHandKind == OffHandKind.shield;
    final abilities = showKit
        ? ClassKits.hudAbilitiesAtSpec(hero.specId, hero.level)
        : const <ClassAbilityDef>[];
    final maxChips = phone ? 4 : (compact ? 3 : 4);
    final visibleAbilities = showKit
        ? _prioritizeHudAbilities(
            abilities,
            spatial: spatial!,
            resource: resource,
            hasShield: hasShield,
            maxChips: maxChips,
            world: world,
            heroHpFrac: maxHp <= 0 ? 1.0 : liveHp / maxHp,
          )
        : const <ClassAbilityDef>[];

    final hpColor = () {
      final cb = SpatialCombat.colorblindMode;
      if (liveHp <= 0) {
        return cb ? GameTheme.hudHpLowCb : GameTheme.blood;
      }
      if (frac <= 0.35) {
        return cb ? GameTheme.hudHpMidCb : GameTheme.bloodLit;
      }
      return cb ? GameTheme.hudCastOk : GameTheme.clear;
    }();

    // Default: thin strip. Kit only when tapped open.
    return Container(
      // Finger-sized on phones even though the strip paints thin.
      constraints: BoxConstraints(minHeight: phone ? GameTheme.minTouch : 0),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 3 : 4,
        vertical: showKit ? (phone ? 4 : 5) : (phone ? 2 : 3),
      ),
      decoration: BoxDecoration(
        color: selected ? const Color(0x331C1812) : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected
              ? GameTheme.torch.withValues(alpha: 0.85)
              : Colors.transparent,
          width: selected ? 1 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              HeroDollSprite(
                hero: hero,
                partyIndex: index,
                size: phone ? 12 : (compact ? 14 : 16),
              ),
              SizedBox(width: phone ? 4 : 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$roleShort L${hero.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: GameTheme.parchment,
                      ),
                    ),
                    SizedBox(height: phone ? 1 : 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: phone ? 2.5 : (compact ? 3.5 : 4.5),
                        backgroundColor: GameTheme.hudHpFill,
                        color: hpColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    if (!inCombat)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: GameLogic.xpProgress(hero),
                          minHeight: phone ? 1.5 : 2,
                          backgroundColor: GameTheme.hudManaFill,
                          color: SpatialCombat.colorblindMode
                              ? GameTheme.hudCastOk
                              : GameTheme.hudManaBright,
                        ),
                      ),
                    if (showKit) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ClassKits.resourceLabelForSpec(hero.specId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GameTheme.body(
                                size: 11,
                                color: GameTheme.parchmentDim,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: resource / 100,
                                minHeight: 3,
                                backgroundColor: GameTheme.hudHpFill,
                                color: Color(
                                  ClassKits.resourceColorForSpec(hero.specId),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${resource.round()}',
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                          if (hero.gearAffinity == HeroRole.rogue &&
                              spatial!.comboPoints > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'CP${spatial!.comboPoints}',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (spatial!.hotStreakReady) ...[
                            const SizedBox(width: 4),
                            Text(
                              'STREAK',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (spatial!.bladeFlurryTimer > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              hero.gearAffinity == HeroRole.rogue
                                  ? 'FLURRY'
                                  : 'SWEEP',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (spatial!.beaconTimer > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'BEACON',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.hudSpiritText,
                              ),
                            ),
                          ],
                          if (spatial!.absorbShield > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'ABS${spatial!.absorbShield}',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.hudManaText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: phone ? 4 : 5),
              Text(
                phone
                    ? '$liveHp ${(frac * 100).round()}%'
                    : '$liveHp',
                style: GameTheme.body(
                  size: phone ? 10 : 12,
                  color: GameTheme.parchmentDim,
                ),
              ),
            ],
          ),
          if (showKit && visibleAbilities.isNotEmpty) ...[
            const SizedBox(height: 3),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final ability in visibleAbilities)
                  _InlineAbilityChip(
                    ability: ability,
                    cdLeft: spatial!.abilityCd[ability.id.name] ?? 0,
                    rage: resource,
                    hasShield: hasShield,
                    activeBuff: _abilityBuffActive(ability, spatial!),
                    focusHpFrac: _focusHpFrac(spatial!, world),
                    bombUp: _focusBombUp(spatial!, world),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Prefer active / ready chips so a 4-hero HUD stays readable.
  SpatialActor? _focusEnemy(SpatialActor spatial, SpatialWorld? world) {
    final id = spatial.focusEnemyId;
    if (id == null || world == null) return null;
    for (final e in world.enemies) {
      if (e.id == id && e.hp > 0) return e;
    }
    return null;
  }

  double _focusHpFrac(SpatialActor spatial, SpatialWorld? world) {
    final focus = _focusEnemy(spatial, world);
    if (focus == null || focus.effectiveMaxHp <= 0) return 1.0;
    return (focus.hp / focus.effectiveMaxHp).clamp(0.0, 1.0);
  }

  bool _focusBombUp(SpatialActor spatial, SpatialWorld? world) {
    final focus = _focusEnemy(spatial, world);
    return focus != null && focus.livingBombTimer >= 2;
  }

  /// Prefer active / ready chips so a 4-hero HUD stays readable.
  List<ClassAbilityDef> _prioritizeHudAbilities(
    List<ClassAbilityDef> abilities, {
    required SpatialActor spatial,
    required double resource,
    required bool hasShield,
    required int maxChips,
    SpatialWorld? world,
    double heroHpFrac = 1.0,
  }) {
    if (abilities.length <= maxChips) return abilities;

    final focusHp = _focusHpFrac(spatial, world);
    final bombUp = _focusBombUp(spatial, world);
    final partyHealthy = heroHpFrac > 0.45;
    final defOrder = <AbilityId, int>{
      for (var i = 0; i < ClassKits.all.length; i++) ClassKits.all[i].id: i,
    };

    int rank(ClassAbilityDef a) {
      if (_abilityBuffActive(a, spatial)) return 0;
      final gated = a.requiresShield && !hasShield;
      final cd = spatial.abilityCd[a.id.name] ?? 0;
      final noRage = resource + 0.001 < a.resourceCost;
      final execFrac = a.gate.executeHpFrac;
      final execWaiting = execFrac != null && focusHp > execFrac;
      final bombWaiting = a.gate.livingBombRefresh && bombUp;
      final demoteWall = partyHealthy &&
          (a.id == AbilityId.shieldWall || a.id == AbilityId.lastStand);
      if (!gated && cd <= 0.05 && !noRage && !execWaiting && !bombWaiting) {
        return demoteWall ? 2 : 1;
      }
      if (cd > 0.05) return demoteWall ? 3 : 2;
      return demoteWall ? 4 : 3;
    }

    int fantasyBias(ClassAbilityDef a) {
      // Lower = prefer. Fantasy signatures beat fillers / long CD walls.
      return switch (a.id) {
        AbilityId.pyroblast => 0,
        AbilityId.combustion => 2,
        AbilityId.aimedShot || AbilityId.chimeraShot => 0,
        AbilityId.steadyShot => 3,
        AbilityId.charge || AbilityId.taunt => 0,
        AbilityId.shieldWall || AbilityId.lastStand => partyHealthy ? 6 : 2,
        _ => 4,
      };
    }

    final ranked = [...abilities]
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        final byFantasy = fantasyBias(a).compareTo(fantasyBias(b));
        if (byFantasy != 0) return byFantasy;
        final byUnlock = a.unlockLevel.compareTo(b.unlockLevel);
        if (byUnlock != 0) return byUnlock;
        final byDmg = b.coeff.compareTo(a.coeff);
        if (byDmg != 0) return byDmg;
        return (defOrder[a.id] ?? 0).compareTo(defOrder[b.id] ?? 0);
      });
    return ranked.take(maxChips).toList();
  }
}

class _InlineAbilityChip extends StatelessWidget {
  const _InlineAbilityChip({
    required this.ability,
    required this.cdLeft,
    required this.rage,
    required this.hasShield,
    required this.activeBuff,
    this.focusHpFrac = 1.0,
    this.bombUp = false,
  });

  final ClassAbilityDef ability;
  final double cdLeft;
  final double rage;
  final bool hasShield;
  final bool activeBuff;
  final double focusHpFrac;
  final bool bombUp;

  @override
  Widget build(BuildContext context) {
    final gated = ability.requiresShield && !hasShield;
    final onCd = cdLeft > 0.05;
    final noRage = rage + 0.001 < ability.resourceCost;
    final isCast = ability.resolvedFireMode == AbilityFireMode.cast;
    final justFired = ability.justFiredHud(cdLeft);
    final execFrac = ability.gate.executeHpFrac;
    final execWaiting = execFrac != null && focusHpFrac > execFrac;
    final bombWaiting = ability.gate.livingBombRefresh && bombUp;
    final softGated = execWaiting || bombWaiting;
    final ready = isCast && !gated && !onCd && !noRage && !softGated;
    final border = justFired
        ? GameTheme.torchHot
        : activeBuff
        ? GameTheme.torchHot
        : ready
        ? GameTheme.clear
        : gated
        ? GameTheme.blood
        : GameTheme.border;
    final cdText = cdLeft < 10
        ? cdLeft.toStringAsFixed(1)
        : cdLeft.round().toString();
    final String label;
    if (gated) {
      label = '${ability.shortLabel}! (shield)';
    } else if (onCd) {
      label = '${ability.shortLabel} $cdText';
    } else if (execWaiting) {
      label = '${ability.shortLabel} ${(execFrac * 100).round()}%';
    } else if (bombWaiting) {
      label = 'Bomb';
    } else {
      label = ability.shortLabel;
    }
    final chip = Opacity(
      opacity: gated || softGated
          ? 0.4
          : (ready || activeBuff || justFired ? 1 : 0.7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: justFired
              ? GameTheme.hudPartyRowHot
              : activeBuff
              ? GameTheme.hudPartyRowWarm
              : GameTheme.hudPartyRowIdle,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: border,
            width: justFired || activeBuff || ready ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: GameTheme.body(
            size: 13,
            color: gated
                ? GameTheme.bloodLit
                : softGated
                ? GameTheme.parchmentDim
                : justFired
                ? GameTheme.torchHot
                : onCd
                ? GameTheme.parchmentDim
                : GameTheme.parchment,
          ),
        ),
      ),
    );
    return Tooltip(
      message: ability.tooltipMessage,
      waitDuration: const Duration(milliseconds: 350),
      child: GestureDetector(
        onLongPress: () {
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                gated
                    ? '${ability.tooltipMessage} - equip a shield'
                    : ability.tooltipMessage,
              ),
            ),
          );
        },
        child: chip,
      ),
    );
  }
}

class DpsMeter extends StatefulWidget {
  const DpsMeter({super.key, required this.director});
  final GameDirector director;

  @override
  State<DpsMeter> createState() => _DpsMeterState();
}

class _DpsMeterState extends State<DpsMeter> {
  bool _open = false;

  static String _heroTag(SpatialActor h) {
    final specId = h.heroSpecId;
    final raw = specId != null
        ? HeroSpecs.def(specId).shortLabel
        : switch (h.heroRole) {
            HeroRole.warrior => 'WAR',
            HeroRole.healer => 'HEAL',
            HeroRole.mage => 'MAGE',
            HeroRole.rogue => 'ROG',
            null => '---',
          };
    return switch (raw) {
      'COMBAT' => 'COM',
      _ => raw.length <= 6 ? raw : raw.substring(0, 6),
    };
  }

  static SpecRoleTag? _roleTag(SpatialActor h) {
    final specId = h.heroSpecId;
    if (specId == null) return null;
    return HeroSpecs.def(specId).roleTag;
  }

  static String _compact(int n) {
    if (n >= 10000) return '${(n / 1000).round()}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static int _perSecond(int total, double elapsed) {
    final t = elapsed < 0.5 ? 0.5 : elapsed;
    return (total / t).round();
  }

  static ({int rate, String unit}) _metric(SpatialActor h, double elapsed) {
    final tag = _roleTag(h);
    if (tag == SpecRoleTag.tank) {
      return (rate: _perSecond(h.damageTaken, elapsed), unit: 'dtps');
    }
    if (tag == SpecRoleTag.healer) {
      return (rate: _perSecond(h.healingDone, elapsed), unit: 'hps');
    }
    return (rate: _perSecond(h.damageDealt, elapsed), unit: 'dps');
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.director.spatial;
    if (world == null) return const SizedBox.shrink();

    final elapsed = world.combatElapsed;
    final rows = <({String tag, String value, double bar, bool highlight})>[];
    var peak = 0;
    var peakUnit = 'dps';
    for (final h in world.heroes) {
      if (h.isPet) continue;
      final m = _metric(h, elapsed);
      if (m.rate > peak) {
        peak = m.rate;
        peakUnit = m.unit;
      }
    }
    if (peak == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xCC14110C),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0x665A5040)),
        ),
        child: Text(
          '— dps',
          style: GameTheme.pixel(
            size: GameTheme.hudPixel,
            color: GameTheme.parchmentDim,
          ),
        ),
      );
    }
    final peakForBar = peak.clamp(1, 1 << 30);

    for (final h in world.heroes) {
      if (h.isPet) continue;
      final m = _metric(h, elapsed);
      if (m.rate < 1) continue;
      rows.add((
        tag: _heroTag(h),
        value: '${_compact(m.rate)} ${m.unit}',
        bar: m.rate / peakForBar,
        highlight: m.rate == peak,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC14110C),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x665A5040)),
      ),
      child: Text(
        _open ? 'METER ▴' : '${_compact(peak)} $peakUnit ▾',
        style: GameTheme.pixel(
          size: GameTheme.hudPixel,
          color: GameTheme.parchment,
        ),
      ),
    );

    final panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        decoration: BoxDecoration(
          color: const Color(0xCC14110C),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0x665A5040)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'METER ▴',
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: GameTheme.parchmentDim,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'dps damage · hps heal · dtps tank',
              style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
            ),
            const SizedBox(height: 3),
            for (final row in rows) ...[
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      row.tag,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(
                        size: GameTheme.hudPixel,
                        color: row.highlight
                            ? GameTheme.torchHot
                            : GameTheme.parchment,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: GameTheme.pixel(size: GameTheme.hudPixel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: row.bar.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: GameTheme.equipChipBlocked,
                  color: row.highlight ? GameTheme.torchHot : GameTheme.mossLit,
                ),
              ),
              const SizedBox(height: 3),
            ],
          ],
        ),
      ),
    );

    return WebClickScope(
      label: _open ? 'Collapse party meter' : 'Expand party meter',
      onPressed: () => setState(() => _open = !_open),
      child: Semantics(
        button: true,
        label: _open ? 'Collapse party meter' : 'Expand party meter',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(3),
            child: _open ? panel : chip,
          ),
        ),
      ),
    );
  }
}
