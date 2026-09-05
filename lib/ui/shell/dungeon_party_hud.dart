import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/party_meter.dart';
import '../../models/class_ability.dart';
import '../../models/enemy.dart';
import '../../models/hero.dart';
import '../../models/hero_spec.dart';
import '../../models/loot.dart';
import '../../models/spec_mastery.dart';
import '../../spatial/spatial_combat.dart';
import '../game_icon.dart';
import '../game_theme.dart';
import '../hero_doll_sprite.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

class PartyCornerHud extends StatefulWidget {
  const PartyCornerHud({
    super.key,
    required this.director,
    required this.selectedHeroIndex,
    required this.onSelectHero,
    required this.onOpenEquip,
  });
  final GameDirector director;
  final int selectedHeroIndex;
  final ValueChanged<int> onSelectHero;
  final VoidCallback onOpenEquip;

  @override
  State<PartyCornerHud> createState() => _PartyCornerHudState();
}

class _PartyCornerHudState extends State<PartyCornerHud> {
  static const _idleFade = Duration(seconds: 8);
  static const _idleFadePhone = Duration(seconds: 3);
  static const _fullOpacity = 1.0;
  static const _dimOpacity = 0.42;
  static const _dimOpacityPhone = 0.32;

  Timer? _fadeTimer;
  double _opacity = _fullOpacity;

  /// Kit chips only when the player taps a strip (map stays clear by default).
  bool _kitOpen = false;

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
    final phone = mounted;
    _scheduleFade(phone: phone);
  }

  void _scheduleFade({bool phone = false}) {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(phone ? _idleFadePhone : _idleFade, () {
      if (!mounted) return;
      final world = widget.director.spatial;
      final state = widget.director.state;
      // Stay bright only while someone is critically low — map stays readable
      // mid-fight when the party is healthy.
      for (var i = 0; i < state.heroes.length; i++) {
        final s = _spatialFor(world, i);
        final hp = s?.hp ?? state.heroes[i].currentHp;
        final maxHp =
            s?.effectiveMaxHp ?? state.effectiveHeroMaxHp(state.heroes[i]);
        if (maxHp > 0 && hp > 0 && hp / maxHp <= 0.35) {
          _scheduleFade(phone: phone);
          return;
        }
      }
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

  void _onHeroTap(int i) {
    _bump();
    if (widget.selectedHeroIndex == i && _kitOpen) {
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
      barrierColor: MenuChrome.scrim,
      builder: (ctx) => MenuChrome.dialog(
        title: 'Open gear?',
        content: Text(
          'You are mid-fight. Open GEAR anyway?',
          style: GameTheme.body(size: 15, color: GameTheme.parchment),
        ),
        actions: [
          MenuChrome.dialogCancel(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GameButton(
            label: 'OPEN GEAR',
            expanded: false,
            onPressed: () => Navigator.pop(ctx, true),
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
    final plainEnglish = GameLogic.plainPlayerChrome(state);
    // Thin strip: reclaim map; kit opens beside the strip (not expanding rows).
    const fullWidth = 118.0;
    const rowHeight = 26.0;
    final heroCount = state.heroes.length;
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

    final keepBright = partyCritical;
    if (keepBright) {
      _fadeTimer?.cancel();
    } else if (_fadeTimer == null || !_fadeTimer!.isActive) {
      _scheduleFade(phone: true);
    }

    final selected = widget.selectedHeroIndex;
    final kitHero = (selected >= 0 && selected < state.heroes.length)
        ? state.heroes[selected]
        : null;
    final kitActor = (selected >= 0) ? _spatialFor(world, selected) : null;
    final showSideKit = _kitOpen &&
        kitHero != null &&
        kitActor != null &&
        kitActor.isAlive;

    final panel = SizedBox(
      width: fullWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: fullWidth,
            decoration: BoxDecoration(
              color: GameTheme.hudWell.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(GameTheme.radiusHud),
              border: Border.all(color: GameTheme.hudWellBorder),
            ),
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < heroCount; i++) ...[
                  if (i > 0) const SizedBox(height: 1.0),
                  SizedBox(
                    height: rowHeight,
                    child: ClipRect(
                      child: WebClickScope(
                        label: state.heroes[i].name,
                        onPressed: () => _onHeroTap(i),
                        child: Semantics(
                          button: true,
                          selected: widget.selectedHeroIndex == i,
                          label:
                              '${state.heroes[i].name} '
                              '${state.heroes[i].displayRoleLabel(plainEnglish: plainEnglish)} — tap for kit, '
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
                                plainEnglish: plainEnglish,
                                selected: widget.selectedHeroIndex == i,
                                kitOpen: false,
                                compact: true,
                                phone: true,
                                stripOnly: true,
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
                                spatial: _spatialFor(world, i),
                                world: world,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showSideKit)
            Positioned(
              left: fullWidth + 4,
              bottom: 0,
              child: _KitSidePanel(
                hero: kitHero,
                plainEnglish: plainEnglish,
                spatial: kitActor,
                world: world,
              ),
            ),
        ],
      ),
    );

    return AnimatedOpacity(
      opacity: keepBright ? _fullOpacity : _opacity,
      duration: const Duration(milliseconds: 400),
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (_) {
          _fadeTimer?.cancel();
          if (_opacity < _fullOpacity) {
            setState(() => _opacity = _fullOpacity);
          }
          if (!keepBright) {
            _scheduleFade(phone: true);
          }
        },
        child: panel,
      ),
    );
  }
}

/// Healing flask — sits bottom-right in the dungeon (away from the party strip).
class DungeonFlaskButton extends StatelessWidget {
  const DungeonFlaskButton({
    super.key,
    required this.director,
    required this.onTap,
  });

  final GameDirector director;
  final VoidCallback onTap;

  static int flaskCount(GameState state) {
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

  static bool partyCritical(GameDirector director) {
    final state = director.state;
    final world = director.spatial;
    final bossFight =
        world != null &&
        world.enemies.any(
          (e) => e.hp > 0 && !e.dormant && e.role == EnemyRole.boss,
        );
    for (var i = 0; i < state.heroes.length; i++) {
      final hero = state.heroes[i];
      SpatialActor? s;
      if (world != null) {
        for (final a in world.heroes) {
          if (!a.isPet && a.assetIndex == i) {
            s = a;
            break;
          }
        }
      }
      final hp = s?.hp ?? hero.currentHp;
      final maxHp = s?.effectiveMaxHp ?? state.effectiveHeroMaxHp(hero);
      if (maxHp <= 0) continue;
      if (hp <= 0) {
        if (bossFight ||
            (world?.enemies.any((e) => e.hp > 0 && !e.dormant) ?? false)) {
          return true;
        }
      }
      if (hp > 0 && hp / maxHp <= 0.35) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    if (!GameLogic.canUseConsumable(state)) {
      return const SizedBox.shrink();
    }
    final urgent = partyCritical(director);
    final count = flaskCount(state);
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
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: urgent
                    ? GameTheme.hudFlaskUrgent
                    : GameTheme.hudFlaskIdle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon.asset(UiIcon.flask, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    'FLASK$countBit',
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

/// Ability chips sit beside the party strip so row heights stay fixed.
class _KitSidePanel extends StatelessWidget {
  const _KitSidePanel({
    required this.hero,
    required this.spatial,
    required this.plainEnglish,
    this.world,
  });

  final PartyHero hero;
  final SpatialActor spatial;
  final bool plainEnglish;
  final SpatialWorld? world;

  @override
  Widget build(BuildContext context) {
    final roleShort = hero.displayRoleLabel(plainEnglish: plainEnglish);
    final isRunic = HeroSpecs.def(hero.specId).resource == SpecResource.runic;
    final resource = spatial.rage.clamp(0.0, 100.0).toDouble();
    final off = hero.itemIn(EquipmentSlot.offHand);
    final hasShield = off?.offHandKind == OffHandKind.shield;
    final abilities = ClassKits.hudAbilitiesAtSpec(hero.specId, hero.level);
    final visible = abilities.length <= 4
        ? abilities
        : abilities.take(4).toList(growable: false);
    final maxHp = spatial.effectiveMaxHp;
    final frac = maxHp <= 0 ? 0.0 : (spatial.hp / maxHp).clamp(0.0, 1.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        decoration: MenuChrome.hudWell(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$roleShort L${hero.level}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTheme.pixel(
                size: GameTheme.hudPixel,
                color: GameTheme.torchHot,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    ClassKits.resourceLabelForSpec(hero.specId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.body(
                      size: 10,
                      color: GameTheme.parchmentDim,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: isRunic ? frac : resource / 100,
                      minHeight: 3,
                      backgroundColor: GameTheme.hudHpFill,
                      color: Color(
                        ClassKits.resourceColorForSpec(hero.specId),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (visible.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final ability in visible)
                    _InlineAbilityChip(
                      ability: ability,
                      cdLeft: spatial.abilityCd[ability.id.name] ?? 0,
                      rage: resource,
                      hasShield: hasShield,
                      activeBuff: false,
                      focusHpFrac: 1,
                      bombUp: false,
                      isRunic: isRunic,
                      isHealer: hero.gearAffinity == HeroRole.healer,
                    ),
                ],
              ),
            ],
          ],
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
    this.plainEnglish = false,
    this.selected = false,
    this.kitOpen = false,
    this.compact = false,
    this.phone = false,
    this.stripOnly = false,
    this.inCombat = false,
    this.spatial,
    this.world,
  });

  final int index;
  final PartyHero hero;
  final int liveHp;
  final int maxHp;
  final bool plainEnglish;
  final bool selected;
  final bool kitOpen;
  final bool compact;
  final bool phone;
  /// Phone dungeon strip: fixed height, no kit / XP / companion lines.
  final bool stripOnly;
  final bool inCombat;
  final SpatialActor? spatial;
  final SpatialWorld? world;

  static const int _runicPipCount = 6;

  static int _runicPipsFilled(double resource) =>
      (resource / 100.0 * _runicPipCount).floor().clamp(0, _runicPipCount);

  static String _runicPipLabel(double resource) {
    final filled = _runicPipsFilled(resource);
    return '${'R' * filled}${'·' * (_runicPipCount - filled)}';
  }

  static bool _showsComboPoints(HeroSpecId specId) =>
      switch (specId) {
        HeroSpecId.combat ||
        HeroSpecId.subtlety ||
        HeroSpecId.assassination ||
        HeroSpecId.feral => true,
        _ => false,
      };

  static String? _companionLine(
    SpatialActor? spatial,
    SpatialWorld? world,
    HeroSpecId specId,
  ) {
    if (spatial == null || world == null || !spatial.isAlive) return null;
    final ownerId = spatial.id;
    switch (specId) {
      case HeroSpecId.beastMastery:
        for (final p in world.pets) {
          if (p.petOwnerId == ownerId &&
              p.hp > 0 &&
              (p.id.startsWith('classpet_') || p.id.startsWith('pet_'))) {
            return p.name;
          }
        }
        return null;
      case HeroSpecId.demonology:
        for (final p in world.pets) {
          if (p.petOwnerId == ownerId &&
              p.id.startsWith('classpet_') &&
              p.hp > 0) {
            return p.name;
          }
        }
        return null;
      case HeroSpecId.unholy:
        final parts = <String>[];
        for (final p in world.pets) {
          if (p.petOwnerId != ownerId || p.hp <= 0) continue;
          if (p.id.startsWith('temppet_garg_') && p.petLifeTimer > 0) {
            parts.add('Garg ${p.petLifeTimer.ceil()}s');
          } else if (p.id.startsWith('temppet_army_') && p.petLifeTimer > 0) {
            parts.add('Army ${p.petLifeTimer.ceil()}s');
          } else if (p.id.startsWith('classpet_')) {
            parts.add(p.name);
          }
        }
        return parts.isEmpty ? null : parts.join(' · ');
      default:
        return null;
    }
  }

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
    final roleShort = hero.displayRoleLabel(plainEnglish: plainEnglish);
    final kitActor = spatial;
    final showKit =
        !stripOnly && kitOpen && kitActor != null && kitActor.isAlive;
    final isRunic = HeroSpecs.def(hero.specId).resource == SpecResource.runic;
    final resource = showKit ? kitActor.rage.clamp(0.0, 100.0).toDouble() : 0.0;
    final companionLine = stripOnly
        ? null
        : _companionLine(spatial, world, hero.specId);
    final off = hero.itemIn(EquipmentSlot.offHand);
    final hasShield = off?.offHandKind == OffHandKind.shield;
    final abilities = showKit
        ? ClassKits.hudAbilitiesAtSpec(hero.specId, hero.level)
        : const <ClassAbilityDef>[];
    final maxChips = phone ? 4 : (compact ? 3 : 4);
    final visibleAbilities = showKit
        ? _prioritizeHudAbilities(
            abilities,
            spatial: kitActor,
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

    if (stripOnly) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? GameTheme.hudRowSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected
                ? GameTheme.torch.withValues(alpha: 0.85)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            HeroDollSprite(
              hero: hero,
              partyIndex: index,
              size: 11,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 2.5,
                      backgroundColor: GameTheme.hudHpFill,
                      color: hpColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
        color: selected ? GameTheme.hudRowSelected : Colors.transparent,
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
                      () {
                        final kind = SpecMastery.kindFor(hero.specId);
                        if (kind == null || !showKit) {
                          return '$roleShort L${hero.level}';
                        }
                        final pts = SpecMastery.masteryPointsFrom(
                          hero.gearMasteryBonus,
                          hero.level,
                        ).round();
                        return '$roleShort L${hero.level} · '
                            '${SpecMastery.playerLabel(kind)} $pts';
                      }(),
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
                    if (companionLine != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        companionLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTheme.body(
                          size: 10,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ],
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
                          if (isRunic) ...[
                            Expanded(
                              child: Text(
                                _runicPipLabel(resource),
                                maxLines: 1,
                                style: GameTheme.pixel(
                                  size: 7,
                                  color: Color(
                                    ClassKits.resourceColorForSpec(hero.specId),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(1),
                                child: LinearProgressIndicator(
                                  value: resource / 100,
                                  minHeight: 3,
                                  backgroundColor: GameTheme.hudHpFill,
                                  color: Color(
                                    ClassKits.resourceColorForSpec(
                                      hero.specId,
                                    ),
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
                          ],
                          if (_showsComboPoints(hero.specId) &&
                              kitActor.comboPoints > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'CP${kitActor.comboPoints}',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (kitActor.hotStreakReady) ...[
                            const SizedBox(width: 4),
                            Text(
                              'STREAK',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.torchHot,
                              ),
                            ),
                          ],
                          if (kitActor.bladeFlurryTimer > 0) ...[
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
                          if (kitActor.beaconTimer > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'BEACON',
                              style: GameTheme.pixel(
                                size: 6,
                                color: GameTheme.hudSpiritText,
                              ),
                            ),
                          ],
                          if (kitActor.absorbShield > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              'ABS${kitActor.absorbShield}',
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
                '$liveHp/$maxHp',
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
                    cdLeft: kitActor.abilityCd[ability.id.name] ?? 0,
                    rage: resource,
                    hasShield: hasShield,
                    activeBuff: _abilityBuffActive(ability, kitActor),
                    focusHpFrac: _focusHpFrac(kitActor, world),
                    bombUp: _focusBombUp(kitActor, world),
                    isRunic: isRunic,
                    isHealer: hero.gearAffinity == HeroRole.healer,
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
        AbilityId.charge ||
        AbilityId.taunt ||
        AbilityId.handOfReckoning ||
        AbilityId.darkCommand ||
        AbilityId.growl => 0,
        AbilityId.armsExecute || AbilityId.furyExecute => 0,
        AbilityId.sealOfCommand => 0,
        AbilityId.bloodthirst ||
        AbilityId.whirlwind ||
        AbilityId.ragingBlow => 0,
        AbilityId.powerWordShield ||
        AbilityId.penance ||
        AbilityId.painSuppression => 1,
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
    this.isRunic = false,
    this.isHealer = false,
  });

  final ClassAbilityDef ability;
  final double cdLeft;
  final double rage;
  final bool hasShield;
  final bool activeBuff;
  final double focusHpFrac;
  final bool bombUp;
  final bool isRunic;
  final bool isHealer;

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
      label = '${ability.shortLabel}·up';
    } else {
      label = isRunic && ability.resourceCost > 0
          ? '${ability.shortLabel}·${ability.resourceCost}'
          : ability.shortLabel;
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
            size: isHealer ? 14 : 13,
            color: gated
                ? GameTheme.bloodLit
                : softGated
                ? GameTheme.parchmentDim
                : justFired
                ? GameTheme.torchHot
                : onCd
                ? GameTheme.parchmentDim
                : isHealer
                ? GameTheme.hudSpiritText
                : GameTheme.parchment,
          ),
        ),
      ),
    );
    final tip = gated
        ? '${ability.tooltipMessage} — equip a shield'
        : ability.tooltipMessage;
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 350),
      child: GestureDetector(
        onLongPress: () {
          showDialog<void>(
            context: context,
            barrierColor: MenuChrome.scrim,
            builder: (ctx) => MenuChrome.dialog(
              title: ability.name,
              content: Text(
                tip,
                style: GameTheme.body(size: 15, color: GameTheme.parchment),
              ),
              actions: [
                GameButton(
                  label: 'OK',
                  style: GameButtonStyle.brown,
                  expanded: false,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
        child: chip,
      ),
    );
  }
}

class DpsMeter extends StatefulWidget {
  const DpsMeter({
    super.key,
    required this.director,
    this.onOpenChanged,
  });
  final GameDirector director;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<DpsMeter> createState() => _DpsMeterState();
}

class _DpsMeterState extends State<DpsMeter> {
  bool _open = false;

  void _setOpen(bool value) {
    if (_open == value) return;
    setState(() => _open = value);
    widget.onOpenChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.director.spatial;
    if (world == null) return const SizedBox.shrink();

    final snap = PartyMeter.fromHeroes(
      world.heroes,
      elapsed: world.combatElapsed,
    );
    if (snap.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: MenuChrome.hudWell(),
        child: Text(
          '0 DPS',
          style: GameTheme.pixel(
            size: GameTheme.hudPixel,
            color: GameTheme.parchmentDim,
          ),
        ),
      );
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: MenuChrome.hudWell(),
      child: Text(
        _open ? 'METER ▴' : '${snap.chipLabel} ▾',
        style: GameTheme.pixel(
          size: GameTheme.hudPixel,
          color: GameTheme.parchment,
        ),
      ),
    );

    final panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 156),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
        decoration: MenuChrome.hudWell(),
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
              'Bars match unit. Tank/healer also show damage.',
              style: GameTheme.body(size: 10, color: GameTheme.parchmentDim),
            ),
            const SizedBox(height: 3),
            for (final row in snap.rows) ...[
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
                      row.valueLabel,
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
      onPressed: () => _setOpen(!_open),
      child: Semantics(
        button: true,
        label: _open ? 'Collapse party meter' : 'Expand party meter',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _setOpen(!_open),
            borderRadius: BorderRadius.circular(3),
            child: _open ? panel : chip,
          ),
        ),
      ),
    );
  }
}
