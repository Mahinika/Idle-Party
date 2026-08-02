import 'package:flutter/material.dart';

import '../core/game_logic.dart';
import '../models/hero_spec.dart';
import 'custom_assets.dart';
import 'game_theme.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';

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
                style: GameTheme.pixel(size: 16, color: GameTheme.torchHot),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose ${GameLogic.starterPartySize} starting specs',
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
                child: Container(
                  decoration: BoxDecoration(
                    color: GameTheme.stone,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF595033)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final specId in HeroSpecs.starterUnlocked)
                        if (HeroSpecs.def(specId).classId == _filter)
                          _SpecPickRow(
                            def: HeroSpecs.def(specId),
                            taken: _slots.contains(specId),
                            onTap: () => _pick(specId),
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
      color: selected ? const Color(0xFF3A3220) : GameTheme.menuCard,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? GameTheme.torch : const Color(0xFF595033),
            ),
          ),
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
                style: GameTheme.pixel(
                  size: 7,
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
    );
  }
}

class _SpecPickRow extends StatelessWidget {
  const _SpecPickRow({
    required this.def,
    required this.taken,
    required this.onTap,
  });

  final HeroSpecDef def;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: GameTheme.menuCard,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
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
                        '${def.roleTag.name} · ${def.resource.name}',
                        style: GameTheme.body(
                          size: 11,
                          color: GameTheme.parchmentDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  taken ? 'SET' : 'PICK',
                  style: GameTheme.pixel(
                    size: 7,
                    color: taken ? GameTheme.mossLit : GameTheme.torchHot,
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
