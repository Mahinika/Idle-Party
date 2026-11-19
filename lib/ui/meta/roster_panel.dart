import 'package:flutter/material.dart';

import '../../assets/custom_assets.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../models/hero.dart';
import '../../models/hero_spec.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import '../shell/shell_common.dart';
import '../shell/shell_layout.dart';

class TeamCompositionOverlay extends StatefulWidget {
  /// Takes a hero out of the active party (polish7 P025).
  static const benchKey = ValueKey('roster-bench');

  /// In a cave the party is read-only; this chip says why (audit F015).
  static const String leaveToSwap = 'Leave the cave to swap';
  static const Key leaveToSwapKey = ValueKey('roster_leave_to_swap');

  /// Open party slot copy (audit F016).
  static const String emptyOpen = 'Empty — pick a hero below';
  static const String emptyLocked = 'Empty';

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
                : 'Pick up to $maxSlots active heroes from your roster.',
            maxLines: 2,
          ),
          if (!hasTank || !hasHeal) ...[
            ShellLayout.gap(6),
            Text(
              [if (!hasTank) 'No Tank', if (!hasHeal) 'No Healer'].join(' · '),
              textAlign: TextAlign.center,
              style: GameTheme.hint(color: GameTheme.torchHot),
            ),
          ],
          ShellLayout.gap(10),
          MenuChrome.sectionLabelScoped('ACTIVE', scope: MenuScope.account),
          ShellLayout.gap(6),
          // In a cave the rows stay normal; only the swap waits (audit F015).
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
          // Slot 5 is one buy button, not an "EMPTY · 80e" row plus a button
          // with the same price (audit F016).
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
          const SizedBox(height: 12),
          MenuChrome.sectionLabelScoped('ROSTER', scope: MenuScope.account),
          const SizedBox(height: 6),
          for (final classId in HeroClassId.values) ...[
            Text(
              HeroSpecs.classLabel(classId),
              style: GameTheme.hint(color: GameTheme.torchHot),
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
      ),
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
        ? (locked
              ? TeamCompositionOverlay.emptyLocked
              : TeamCompositionOverlay.emptyOpen)
        : '${hero!.shownName} · ${hero!.spec.name}';
    if (locked) {
      // Read-only row in a cave: normal ink, not a greyed-out button.
      return Semantics(
        label: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: GameTheme.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.centerLeft,
          decoration: MenuChrome.cardBox(),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GameTheme.readable(
              color: hero == null
                  ? GameTheme.parchmentDim
                  : GameTheme.parchment,
            ),
          ),
        ),
      );
    }
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
          // BENCH, not an "X" that reads as close (polish7 P025).
          GameButton(
            key: TeamCompositionOverlay.benchKey,
            label: 'BENCH',
            style: GameButtonStyle.ghost,
            expanded: false,
            dense: true,
            tip: 'Move this hero to the bench',
            onPressed: onClear,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  def.name,
                  style: GameTheme.hint(
                    color: unlocked
                        ? GameTheme.parchment
                        : GameTheme.parchmentDim,
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
          Text(
            !unlocked
                ? (def.unlockHint.isEmpty ? 'LOCKED' : def.unlockHint)
                : inActive
                ? 'ACTIVE'
                : onRoster
                ? def.plainRoleLine
                : 'READY',
            style: GameTheme.hint(
              color: inActive
                  ? GameTheme.mossLit
                  : (unlocked
                        ? GameTheme.parchmentDim
                        : GameTheme.parchmentDim),
            ),
          ),
        ],
      ),
    );
  }
}
