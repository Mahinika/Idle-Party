import 'package:flutter/material.dart';

import '../../assets/custom_assets.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/gear/gear_upgrade_copy.dart';
import '../../core/party_role_slots.dart';
import '../../models/hero.dart';
import '../../models/hero_spec.dart';
import '../game_theme.dart';
import '../hero_doll_sprite.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import '../shell/shell_common.dart';
import '../shell/shell_layout.dart';

class TeamCompositionOverlay extends StatefulWidget {
  static const benchKey = ValueKey('roster-bench');
  static const String leaveToSwap = 'Leave the cave to swap';
  static const Key leaveToSwapKey = ValueKey('roster_leave_to_swap');
  static const String emptyOpen = 'Empty — tap to pick';
  static const String emptyLocked = 'Empty';

  const TeamCompositionOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<TeamCompositionOverlay> createState() => _TeamCompositionOverlayState();
}

class _TeamCompositionOverlayState extends State<TeamCompositionOverlay> {
  GameDirector get director => widget.director;

  Future<void> _openSlot(int slotIndex) async {
    final state = director.state;
    if (state.inDungeon) return;
    final slots = PartyRoleSlots.slotHeroes(state);
    final current = slotIndex < slots.length ? slots[slotIndex] : null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RosterSlotPickerSheet(
        director: director,
        slotIndex: slotIndex,
        currentHero: current,
        onPick: (hero) async {
          Navigator.pop(ctx);
          if (current != null && current.id != hero.id) {
            final swap = await _confirmSwap(current, hero);
            if (!mounted) return;
            if (swap == true) {
              director.setPartySlot(slotIndex, heroId: hero.id);
            }
          } else {
            director.setPartySlot(slotIndex, heroId: hero.id);
          }
        },
        onUnlock: (specId) {
          Navigator.pop(ctx);
          director.unlockSpec(specId);
        },
        onBench: current == null
            ? null
            : () {
                Navigator.pop(ctx);
                director.setPartySlot(slotIndex, heroId: null);
              },
      ),
    );
  }

  Future<bool?> _confirmSwap(PartyHero current, PartyHero incoming) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RosterSwapCompareSheet(
        current: current,
        incoming: incoming,
        onSwap: () => Navigator.pop(ctx, true),
        onKeep: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final maxSlots = state.maxActivePartySize;
    final slotHeroes = PartyRoleSlots.slotHeroes(state);
    final hasTank = slotHeroes.any(
      (h) => h != null && HeroSpecs.partyRole(h.specId) == PartyRoleBucket.tank,
    );
    final hasHeal = slotHeroes.any(
      (h) => h != null && HeroSpecs.partyRole(h.specId) == PartyRoleBucket.healer,
    );

    return Padding(
      padding: ShellLayout.listPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KenneySprite(asset: CustomAssets.townInn(1), size: 48),
              const SizedBox(width: 10),
              Text('INN', style: GameTheme.title()),
            ],
          ),
          ShellLayout.gap(6),
          ShellLayout.hint(
            state.inDungeon
                ? 'Leave the dungeon to change your lineup.'
                : 'Fixed roles: TANK · HEALER · DPS. Tap a slot to swap.',
            maxLines: 3,
          ),
          if (!hasTank || !hasHeal) ...[
            ShellLayout.gap(6),
            Text(
              [if (!hasTank) 'No Tank in party', if (!hasHeal) 'No Healer in party'].join(' · '),
              textAlign: TextAlign.center,
              style: GameTheme.hint(color: GameTheme.torchHot),
            ),
          ],
          ShellLayout.gap(10),
          MenuChrome.sectionLabelScoped('ACTIVE', scope: MenuScope.account),
          ShellLayout.gap(6),
          if (state.inDungeon) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: KeyedSubtree(
                key: TeamCompositionOverlay.leaveToSwapKey,
                child: MenuChrome.chip(
                  label: TeamCompositionOverlay.leaveToSwap,
                ),
              ),
            ),
            ShellLayout.gap(6),
          ],
          for (var i = 0; i < maxSlots; i++) ...[
            _RoleSlotCard(
              slotIndex: i,
              hero: i < slotHeroes.length ? slotHeroes[i] : null,
              locked: state.inDungeon,
              onTap: state.inDungeon ? null : () => _openSlot(i),
              onBench: state.inDungeon || (i >= slotHeroes.length || slotHeroes[i] == null)
                  ? null
                  : () => director.setPartySlot(i, heroId: null),
            ),
            const SizedBox(height: 6),
          ],
          if (!state.metaDepth.partySlot5Unlocked && maxSlots < 5) ...[
            GameButton(
              label:
                  state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
                      state.essence >= GameLogic.partySlot5EssenceCost
                  ? 'UNLOCK SLOT 5 · ${formatCount(GameLogic.partySlot5EssenceCost)} essence'
                  : 'SLOT 5 · ${formatCount(GameLogic.partySlot5EssenceCost)} essence · Ascend ${GameLogic.partySlot5MinAscension}',
              style: GameButtonStyle.essence,
              dense: true,
              onPressed:
                  state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
                      state.essence >= GameLogic.partySlot5EssenceCost
                  ? () => director.unlockPartySlot5()
                  : null,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _RoleSlotCard extends StatelessWidget {
  const _RoleSlotCard({
    required this.slotIndex,
    required this.hero,
    required this.locked,
    this.onTap,
    this.onBench,
  });

  final int slotIndex;
  final PartyHero? hero;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onBench;

  @override
  Widget build(BuildContext context) {
    final roleLabel = PartyRoleSlots.slotLabel(slotIndex);
    final spec = hero?.spec;
    final subtitle = spec == null
        ? (locked ? TeamCompositionOverlay.emptyLocked : TeamCompositionOverlay.emptyOpen)
        : '${hero!.shownName} · ${spec.displayClassName}';

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          MenuChrome.chip(label: roleLabel),
          const SizedBox(width: 8),
          if (hero != null)
            HeroDollSprite(hero: hero!, partyIndex: slotIndex, size: 40)
          else
            SizedBox(
              width: 40,
              height: 40,
              child: DecoratedBox(
                decoration: MenuChrome.cardBox(),
                child: Center(
                  child: Text(
                    '+',
                    style: GameTheme.section(color: GameTheme.parchmentDim),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec?.displayClassName ?? 'Open slot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.readable(color: GameTheme.parchment),
                ),
                Text(
                  spec?.displaySpecName ?? roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.hint(color: GameTheme.parchmentDim),
                ),
                if (spec != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GameTheme.hint(color: GameTheme.parchmentDim),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (locked) {
      return Semantics(
        label: subtitle,
        child: DecoratedBox(
          decoration: MenuChrome.cardBox(),
          child: body,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(GameTheme.radiusSm),
              child: DecoratedBox(
                decoration: MenuChrome.cardBox(),
                child: body,
              ),
            ),
          ),
        ),
        if (onBench != null) ...[
          const SizedBox(width: 6),
          GameButton(
            key: TeamCompositionOverlay.benchKey,
            label: 'BENCH',
            style: GameButtonStyle.ghost,
            expanded: false,
            dense: true,
            tip: 'Clear this slot',
            onPressed: onBench,
          ),
        ],
      ],
    );
  }
}

class RosterSlotPickerSheet extends StatelessWidget {
  const RosterSlotPickerSheet({
    required this.director,
    required this.slotIndex,
    required this.currentHero,
    required this.onPick,
    required this.onUnlock,
    this.onBench,
  });

  final GameDirector director;
  final int slotIndex;
  final PartyHero? currentHero;
  final ValueChanged<PartyHero> onPick;
  final ValueChanged<HeroSpecId> onUnlock;
  final VoidCallback? onBench;

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final role = PartyRoleSlots.bucketForSlot(slotIndex);
    final activeIds = {
      for (final id in state.activeHeroIds)
        if (id.isNotEmpty) id,
    };

    final rosterHeroes = <PartyHero>[
      for (final h in state.heroRoster)
        if (HeroSpecs.partyRole(h.specId) == role) h,
    ];

    final missingSpecs = <HeroSpecId>[
      for (final id in HeroSpecs.specsForPartyRole(role))
        if (!state.heroRoster.any((h) => h.specId == id)) id,
    ];

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: DecoratedBox(
        decoration: MenuChrome.panel(opaque: true),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    MenuChrome.chip(label: PartyRoleSlots.slotLabel(slotIndex)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pick ${role.name.toUpperCase()}',
                        style: GameTheme.title(),
                      ),
                    ),
                  ],
                ),
              ),
              if (onBench != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GameButton(
                    label: 'BENCH CURRENT',
                    style: GameButtonStyle.grey,
                    dense: true,
                    onPressed: onBench,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final hero in rosterHeroes)
                      _HeroPickCard(
                        hero: hero,
                        activeInSlot: activeIds.contains(hero.id),
                        onPick: () => onPick(hero),
                      ),
                    for (final specId in missingSpecs)
                      _LockedSpecPickCard(
                        def: HeroSpecs.def(specId),
                        canUnlock: GameLogic.canUnlockSpec(state, specId),
                        unlocked: state.isSpecUnlocked(specId),
                        onUnlock: () => onUnlock(specId),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPickCard extends StatelessWidget {
  const _HeroPickCard({
    required this.hero,
    required this.activeInSlot,
    required this.onPick,
  });

  final PartyHero hero;
  final bool activeInSlot;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final spec = hero.spec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: MenuChrome.listCard(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              MenuChrome.chip(label: spec.roleTag.plainLabel.toUpperCase()),
              const SizedBox(width: 8),
              HeroDollSprite(hero: hero, partyIndex: 0, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.displayClassName,
                      style: GameTheme.readable(color: GameTheme.parchment),
                    ),
                    Text(
                      spec.displaySpecName,
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                    Text(
                      spec.kitDetailLine,
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                    Text(
                      hero.shownName,
                      style: GameTheme.hint(color: GameTheme.torchHot),
                    ),
                  ],
                ),
              ),
              GameButton(
                label: activeInSlot ? 'ACTIVE' : 'PICK',
                expanded: false,
                dense: true,
                style: activeInSlot ? GameButtonStyle.grey : GameButtonStyle.brown,
                onPressed: activeInSlot ? null : onPick,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedSpecPickCard extends StatelessWidget {
  const _LockedSpecPickCard({
    required this.def,
    required this.canUnlock,
    required this.unlocked,
    required this.onUnlock,
  });

  final HeroSpecDef def;
  final bool canUnlock;
  final bool unlocked;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: MenuChrome.listCard(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              MenuChrome.chip(label: def.roleTag.plainLabel.toUpperCase()),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.displayClassName,
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                    Text(
                      def.displaySpecName,
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                    Text(
                      def.kitDetailLine,
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                    Text(
                      unlocked
                          ? 'On roster after unlock'
                          : (def.unlockHint.isEmpty ? 'LOCKED' : def.unlockHint),
                      style: GameTheme.hint(color: GameTheme.parchmentDim),
                    ),
                  ],
                ),
              ),
              GameButton(
                label: 'UNLOCK',
                expanded: false,
                dense: true,
                style: GameButtonStyle.grey,
                onPressed: canUnlock ? onUnlock : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RosterSwapCompareSheet extends StatelessWidget {
  const RosterSwapCompareSheet({
    required this.current,
    required this.incoming,
    required this.onSwap,
    required this.onKeep,
  });

  final PartyHero current;
  final PartyHero incoming;
  final VoidCallback onSwap;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final diff = incoming.spec.versusLine(current.spec);
    return FractionallySizedBox(
      heightFactor: 0.65,
      child: DecoratedBox(
        decoration: MenuChrome.panel(opaque: true),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('SWAP HERO', textAlign: TextAlign.center, style: GameTheme.title()),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CompareHeroCard(hero: current, tag: 'CURRENT')),
                    const Padding(
                      padding: EdgeInsets.only(top: 36),
                      child: Text('→', style: TextStyle(fontSize: 22)),
                    ),
                    Expanded(child: _CompareHeroCard(hero: incoming, tag: 'PICK')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  diff,
                  textAlign: TextAlign.center,
                  style: GameTheme.hint(color: GameTheme.torchHot),
                ),
                const SizedBox(height: 16),
                GameButton(
                  label: 'SWAP IN',
                  style: GameButtonStyle.go,
                  onPressed: onSwap,
                ),
                const SizedBox(height: 6),
                GameButton(
                  label: 'KEEP',
                  style: GameButtonStyle.grey,
                  onPressed: onKeep,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareHeroCard extends StatelessWidget {
  const _CompareHeroCard({required this.hero, required this.tag});

  final PartyHero hero;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final spec = hero.spec;
    return DecoratedBox(
      decoration: MenuChrome.cardBox(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(tag, style: GameTheme.section(color: GameTheme.parchmentDim)),
            const SizedBox(height: 4),
            HeroDollSprite(hero: hero, partyIndex: 0, size: 52),
            const SizedBox(height: 6),
            Text(
              spec.displayClassName,
              textAlign: TextAlign.center,
              style: GameTheme.readable(color: GameTheme.parchment),
            ),
            Text(
              spec.displaySpecName,
              textAlign: TextAlign.center,
              style: GameTheme.hint(color: GameTheme.parchmentDim),
            ),
            Text(
              hero.shownName,
              textAlign: TextAlign.center,
              style: GameTheme.hint(color: GameTheme.torchHot),
            ),
          ],
        ),
      ),
    );
  }
}