import 'package:flutter/material.dart';

import '../core/ascend_roadmap.dart';
import '../core/game_logic.dart';
import '../models/hero_spec.dart';
import 'custom_assets.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

/// Pick exactly [GameLogic.starterPartySize] unique specs for a new run.
class NewGamePartyPicker extends StatefulWidget {
  const NewGamePartyPicker({
    super.key,
    required this.onConfirm,
    required this.onBack,
    this.initialSpecs,
  });

  final ValueChanged<List<HeroSpecId>> onConfirm;
  final VoidCallback onBack;
  final List<HeroSpecId>? initialSpecs;

  @override
  State<NewGamePartyPicker> createState() => _NewGamePartyPickerState();
}

class _NewGamePartyPickerState extends State<NewGamePartyPicker> {
  late final List<HeroSpecId?> _slots;
  HeroClassId _filter = HeroSpecs.def(HeroSpecs.starterUnlocked.first).classId;
  int _activeSlot = 0;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialSpecs ?? HeroSpecs.starterUnlocked;
    _slots = List<HeroSpecId?>.filled(GameLogic.starterPartySize, null);
    for (var i = 0; i < _slots.length && i < seed.length; i++) {
      _slots[i] = seed[i];
    }
  }

  bool get _ready =>
      _slots.every((s) => s != null) &&
      _slots.map((s) => s!).toSet().length == _slots.length;

  String? get _softWarn {
    final chosen = [for (final s in _slots) if (s != null) HeroSpecs.def(s)];
    if (chosen.length < GameLogic.starterPartySize) return null;
    final hasTank = chosen.any((d) => d.isTank);
    final hasHeal = chosen.any((d) => d.isHealer);
    if (!hasTank && !hasHeal) return 'No tank or healer — hard mode';
    if (!hasTank) return 'No tank tagged — glass cannon OK';
    if (!hasHeal) return 'No healer tagged — flasks matter more';
    return null;
  }

  void _pick(HeroSpecId id) {
    if (!HeroSpecs.starterUnlocked.contains(id)) return;
    setState(() {
      for (var i = 0; i < _slots.length; i++) {
        if (i != _activeSlot && _slots[i] == id) {
          _slots[i] = null;
        }
      }
      _slots[_activeSlot] = id;
      if (_activeSlot < _slots.length - 1) {
        _activeSlot++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final warn = _softWarn;
    final classSpecs = [
      for (final id in HeroSpecs.forClass(_filter))
        if (HeroSpecs.starterUnlocked.contains(id)) id,
      for (final id in HeroSpecs.forClass(_filter))
        if (!HeroSpecs.starterUnlocked.contains(id)) id,
    ];
    return Scaffold(
      backgroundColor: GameTheme.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'NEW PARTY',
                textAlign: TextAlign.center,
                style: GameTheme.menuTitle(size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick ${GameLogic.starterPartySize} starters. More kits after Ascend.',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < _slots.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _SlotCard(
                        index: i,
                        specId: _slots[i],
                        selected: _activeSlot == i,
                        onTap: () => setState(() => _activeSlot = i),
                      ),
                    ),
                  ],
                ],
              ),
              if (warn != null) ...[
                const SizedBox(height: 8),
                Text(
                  warn,
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 12, color: GameTheme.torchHot),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final classId in {
                      for (final id in HeroSpecs.starterUnlocked)
                        HeroSpecs.def(id).classId,
                    })
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: KenneyButton(
                          label: HeroSpecs.classLabel(classId).toUpperCase(),
                          expanded: false,
                          style: _filter == classId
                              ? KenneyButtonStyle.brown
                              : KenneyButtonStyle.grey,
                          onPressed: () => setState(() => _filter = classId),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: MenuChrome.panel(opaque: true),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final specId in classSpecs)
                        _SpecPickRow(
                          def: HeroSpecs.def(specId),
                          starter: HeroSpecs.starterUnlocked.contains(specId),
                          taken: _slots.contains(specId),
                          onTap: () => _pick(specId),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Rogues, hunters, DKs and more unlock as you Ascend.',
                        textAlign: TextAlign.center,
                        style: GameTheme.body(
                          size: 12,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: KenneyButton(
                      label: 'BACK',
                      style: KenneyButtonStyle.grey,
                      onPressed: widget.onBack,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KenneyButton(
                      label: 'START',
                      style: KenneyButtonStyle.brown,
                      onPressed: _ready
                          ? () => widget.onConfirm(
                                [for (final s in _slots) s!],
                              )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.index,
    required this.specId,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final HeroSpecId? specId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final def = specId == null ? null : HeroSpecs.def(specId!);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GameTheme.radiusSm),
        child: DecoratedBox(
          decoration: MenuChrome.cardBox(selected: selected),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                KenneySprite(
                  asset: def == null
                      ? CustomAssets.heroKnight
                      : CustomAssets.heroForClass(def.classId),
                  size: 40,
                ),
                const SizedBox(height: 4),
                Text(
                  def?.shortLabel ?? 'SLOT ${index + 1}',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 13,
                    color: GameTheme.parchment,
                  ),
                ),
                Text(
                  def?.name ?? 'Tap to pick',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 11,
                    color: GameTheme.parchmentDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecPickRow extends StatelessWidget {
  const _SpecPickRow({
    required this.def,
    required this.starter,
    required this.taken,
    required this.onTap,
  });

  final HeroSpecDef def;
  final bool starter;
  final bool taken;
  final VoidCallback onTap;

  String get _lockLabel {
    final al = AscendRoadmap.ascendLevelForKit(def.id);
    if (al != null) return 'AL$al';
    if (def.unlockHint.isNotEmpty) return def.unlockHint;
    return 'Later';
  }

  @override
  Widget build(BuildContext context) {
    final locked = !starter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: locked ? null : onTap,
            borderRadius: BorderRadius.circular(GameTheme.radiusSm),
            child: DecoratedBox(
              decoration: MenuChrome.listCard(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    KenneySprite(
                      asset: CustomAssets.heroForClass(def.classId),
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${def.shortLabel}  ${def.name}',
                            style: GameTheme.body(
                              size: 14,
                              color: GameTheme.parchment,
                            ),
                          ),
                          Text(
                            locked
                                ? _lockLabel
                                : '${def.roleTag.name} · ${def.resource.name}',
                            style: GameTheme.body(
                              size: 11,
                              color: GameTheme.parchmentDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      locked
                          ? 'LOCKED'
                          : taken
                              ? 'SET'
                              : 'PICK',
                      style: GameTheme.body(
                        size: 13,
                        color: locked
                            ? GameTheme.parchmentDim
                            : taken
                                ? GameTheme.mossLit
                                : GameTheme.torchHot,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
