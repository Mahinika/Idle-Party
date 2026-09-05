
import 'package:flutter/material.dart';

import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../models/hero.dart';
import '../../models/hero_spec.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../menu_chrome.dart';

class TeamCompositionOverlay extends StatefulWidget {
  const TeamCompositionOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<TeamCompositionOverlay> createState() => _TeamCompositionOverlayState();
}

class _TeamCompositionOverlayState extends State<TeamCompositionOverlay> {
  String? _pendingSlotReplace;

  GameDirector get director => widget.director;

  void _toast(String msg) => director.showToast(msg, life: 2.4);

  @override
  Widget build(BuildContext context) {
    final state = director.state;
    final maxSlots = state.maxActivePartySize;
    final active = state.heroes;
    final hasTank = active.any((h) => h.spec.isTank);
    final hasHeal = active.any((h) => h.spec.isHealer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.inDungeon
              ? 'Leave the dungeon to change your lineup.'
              : 'Pick up to $maxSlots active heroes from your roster.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
        ),
        if (!hasTank || !hasHeal) ...[
          const SizedBox(height: 6),
          Text(
            [if (!hasTank) 'No Shield', if (!hasHeal) 'No Healer'].join(' · '),
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
        ],
        const SizedBox(height: 10),
        MenuChrome.sectionLabelScoped('ACTIVE', scope: MenuScope.account),
        const SizedBox(height: 6),
        for (var i = 0; i < maxSlots; i++) ...[
          _ActiveSlotChip(
            index: i,
            hero: i < active.length ? active[i] : null,
            selected:
                _pendingSlotReplace ==
                (i < active.length ? active[i].id : 'empty_$i'),
            locked: state.inDungeon,
            onTap: state.inDungeon
                ? null
                : () {
                    if (i < active.length) {
                      setState(() {
                        _pendingSlotReplace = active[i].id;
                      });
                    } else {
                      setState(() => _pendingSlotReplace = 'empty_$i');
                    }
                  },
            onClear: state.inDungeon || i >= active.length
                ? null
                : () {
                    final ids = [
                      for (final h in active)
                        if (h.id != active[i].id) h.id,
                    ];
                    if (ids.isEmpty) {
                      _toast('Need at least one hero');
                      return;
                    }
                    director.setActiveParty(ids);
                    setState(() => _pendingSlotReplace = null);
                  },
          ),
          const SizedBox(height: 6),
        ],
        if (!state.metaDepth.partySlot5Unlocked) ...[
          const SizedBox(height: 8),
          GameButton(
            label:
                'UNLOCK 5TH SLOT  ${GameLogic.partySlot5EssenceCost}e  AL${GameLogic.partySlot5MinAscension}+',
            style: GameButtonStyle.brown,
            onPressed:
                state.ascensionLevel >= GameLogic.partySlot5MinAscension &&
                    state.essence >= GameLogic.partySlot5EssenceCost
                ? () {
                    director.unlockPartySlot5();
                  }
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            'Same buy as ESSENCE → KEEP.',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 12),
        MenuChrome.sectionLabelScoped('ROSTER', scope: MenuScope.account),
        const SizedBox(height: 6),
        for (final classId in HeroClassId.values) ...[
          Text(
            HeroSpecs.classLabel(classId),
            style: GameTheme.body(size: 12, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 4),
          for (final specId in HeroSpecs.forClass(classId))
            _RosterSpecRow(
              def: HeroSpecs.def(specId),
              unlocked: state.isSpecUnlocked(specId),
              onRoster: state.heroRoster.any((h) => h.specId == specId),
              inActive: active.any((h) => h.specId == specId),
              disabled: state.inDungeon,
              onUnlock: () {
                director.unlockSpec(specId);
              },
              onAdd: () {
                PartyHero? hero;
                for (final h in state.heroRoster) {
                  if (h.specId == specId) {
                    hero = h;
                    break;
                  }
                }
                if (hero == null) return;
                if (active.any((h) => h.id == hero!.id)) {
                  _toast('Already active');
                  return;
                }
                if (active.length >= maxSlots) {
                  if (_pendingSlotReplace != null &&
                      !_pendingSlotReplace!.startsWith('empty_')) {
                    final ids = [
                      for (final h in active)
                        if (h.id == _pendingSlotReplace) hero.id else h.id,
                    ];
                    director.setActiveParty(ids);
                    setState(() => _pendingSlotReplace = null);
                    return;
                  }
                  _toast('Party full — tap an active slot to replace');
                  return;
                }
                director.setActiveParty([...state.activeHeroIds, hero.id]);
                setState(() => _pendingSlotReplace = null);
              },
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ActiveSlotChip extends StatelessWidget {
  const _ActiveSlotChip({
    required this.index,
    required this.hero,
    required this.selected,
    required this.locked,
    this.onTap,
    this.onClear,
  });

  final int index;
  final PartyHero? hero;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = hero == null
        ? 'SLOT ${index + 1}'
        : '${hero!.name} · ${hero!.roleLabel}';
    return Row(
      children: [
        Expanded(
          child: GameButton(
            label: label,
            style: selected ? GameButtonStyle.brown : GameButtonStyle.grey,
            onPressed: onTap,
          ),
        ),
        if (onClear != null && !locked) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: GameButton(
              label: 'X',
              style: GameButtonStyle.grey,
              expanded: false,
              onPressed: onClear,
            ),
          ),
        ],
      ],
    );
  }
}

class _RosterSpecRow extends StatelessWidget {
  const _RosterSpecRow({
    required this.def,
    required this.unlocked,
    required this.onRoster,
    required this.inActive,
    required this.disabled,
    required this.onUnlock,
    required this.onAdd,
  });

  final HeroSpecDef def;
  final bool unlocked;
  final bool onRoster;
  final bool inActive;
  final bool disabled;
  final VoidCallback onUnlock;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final status = !unlocked
        ? (def.unlockHint.isEmpty ? 'LOCKED' : def.unlockHint)
        : inActive
        ? 'ACTIVE'
        : onRoster
        ? 'BENCH'
        : 'READY';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${def.name}\n$status',
              style: GameTheme.body(
                size: 12,
                color: unlocked ? GameTheme.parchment : GameTheme.parchmentDim,
              ),
            ),
          ),
          if (!unlocked)
            GameButton(
              label: 'UNLOCK',
              expanded: false,
              style: GameButtonStyle.grey,
              onPressed: disabled ? null : onUnlock,
            )
          else if (!inActive && onRoster)
            GameButton(
              label: 'ADD',
              expanded: false,
              style: GameButtonStyle.brown,
              onPressed: disabled ? null : onAdd,
            ),
        ],
      ),
    );
  }
}

