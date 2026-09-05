import 'package:flutter/material.dart';

import '../core/game_logic.dart';
import '../core/party_name_filter.dart';
import '../models/hero_spec.dart';
import '../assets/custom_assets.dart';
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

  final void Function(List<HeroSpecId> specs, String partyName) onConfirm;
  final VoidCallback onBack;
  final List<HeroSpecId>? initialSpecs;

  @override
  State<NewGamePartyPicker> createState() => _NewGamePartyPickerState();
}

class _NewGamePartyPickerState extends State<NewGamePartyPicker> {
  late final List<HeroSpecId?> _slots;
  late final TextEditingController _nameCtrl;
  HeroClassId _filter = HeroSpecs.def(HeroSpecs.starterUnlocked.first).classId;
  int _activeSlot = 0;
  bool _nameError = false;
  String? _pickHint;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialSpecs ?? HeroSpecs.starterUnlocked;
    _slots = List<HeroSpecId?>.filled(GameLogic.starterPartySize, null);
    for (var i = 0; i < _slots.length && i < seed.length; i++) {
      _slots[i] = seed[i];
    }
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _tryStart() {
    if (!_ready) return;
    final name = PartyNameFilter.sanitize(_nameCtrl.text);
    if (name == null) {
      setState(() => _nameError = true);
      return;
    }
    widget.onConfirm([for (final s in _slots) s!], name);
  }

  bool get _ready =>
      _slots.every((s) => s != null) &&
      _slots.map((s) => s!).toSet().length == _slots.length;

  String? get _startBlockReason {
    final empty = _slots.where((s) => s == null).length;
    if (empty > 0) {
      return empty == 1
          ? 'Pick 1 more hero — each slot needs a different kit'
          : 'Pick $empty more heroes — each slot needs a different kit';
    }
    if (_slots.map((s) => s!).toSet().length != _slots.length) {
      return 'Each hero must be a different kit';
    }
    return null;
  }

  int? _nextEmptySlot({int? after}) {
    if (_slots.every((s) => s != null)) return null;
    final start = after == null ? 0 : (after + 1) % _slots.length;
    for (var i = 0; i < _slots.length; i++) {
      final idx = (start + i) % _slots.length;
      if (_slots[idx] == null) return idx;
    }
    return null;
  }

  String? get _softWarn {
    final chosen = [
      for (final s in _slots)
        if (s != null) HeroSpecs.def(s),
    ];
    if (chosen.length < GameLogic.starterPartySize) return null;
    final hasTank = chosen.any((d) => d.isTank);
    final hasHeal = chosen.any((d) => d.isHealer);
    if (!hasTank && !hasHeal) {
      return 'No Shield or Healer — the cave will hit much harder';
    }
    if (!hasTank) return 'No Shield — enemies hit the whole party more';
    if (!hasHeal) return 'No Healer — buy flasks when someone is low';
    return null;
  }

  void _pick(HeroSpecId id) {
    if (!HeroSpecs.starterUnlocked.contains(id)) return;
    final takenIndex = _slots.indexWhere((s) => s == id);
    if (takenIndex >= 0 && takenIndex != _activeSlot) {
      final def = HeroSpecs.def(id);
      setState(() {
        _pickHint =
            '${def.shortLabel} is already picked — choose Healer or Fire mage '
            'for the other slots';
        _activeSlot = takenIndex;
      });
      return;
    }
    setState(() {
      _pickHint = null;
      _slots[_activeSlot] = id;
      _activeSlot = _nextEmptySlot(after: _activeSlot) ?? _activeSlot;
    });
  }

  @override
  Widget build(BuildContext context) {
    final classSpecs = [
      for (final id in HeroSpecs.forClass(_filter))
        if (HeroSpecs.starterUnlocked.contains(id)) id,
      for (final id in HeroSpecs.forClass(_filter))
        if (!HeroSpecs.starterUnlocked.contains(id)) id,
    ];
    final warn = _softWarn;
    final blockReason = _startBlockReason;
    final starterInClass = [
      for (final id in classSpecs)
        if (HeroSpecs.starterUnlocked.contains(id)) id,
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
                'Pick ${GameLogic.starterPartySize} heroes. Easy start: one Shield, '
                'one Healer, one Damage.',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                maxLength: PartyNameFilter.maxLen,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                style: GameTheme.body(size: 15, color: GameTheme.parchment),
                cursorColor: GameTheme.torchHot,
                onChanged: (_) {
                  if (_nameError) setState(() => _nameError = false);
                },
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Party name',
                  hintText: 'The Ember Guard',
                  labelStyle: GameTheme.body(
                    size: 13,
                    color: GameTheme.parchmentDim,
                  ),
                  hintStyle: GameTheme.body(
                    size: 14,
                    color: GameTheme.parchmentDim,
                  ),
                  filled: true,
                  fillColor: GameTheme.panelInset,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                    borderSide: BorderSide(color: GameTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GameTheme.radiusSm),
                    borderSide: BorderSide(color: GameTheme.torchHot),
                  ),
                ),
              ),
              if (_nameError) ...[
                const SizedBox(height: 4),
                Text(
                  'Choose another party name',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 12, color: GameTheme.bloodLit),
                ),
              ],
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
              if (_pickHint != null) ...[
                const SizedBox(height: 8),
                Text(
                  _pickHint!,
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 12, color: GameTheme.torchHot),
                ),
              ] else if (warn != null) ...[
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
                        child: GameButton(
                          label: HeroSpecs.classLabel(classId).toUpperCase(),
                          expanded: false,
                          style: _filter == classId
                              ? GameButtonStyle.brown
                              : GameButtonStyle.grey,
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
                      if (starterInClass.length == 1) ...[
                        Text(
                          'Only one ${HeroSpecs.classLabel(_filter)} kit is open at '
                          'start — pick the other roles from another class tab.',
                          textAlign: TextAlign.center,
                          style: GameTheme.body(
                            size: 12,
                            color: GameTheme.parchmentDim,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final specId in classSpecs)
                        _SpecPickRow(
                          def: HeroSpecs.def(specId),
                          starter: HeroSpecs.starterUnlocked.contains(specId),
                          taken: _slots.contains(specId),
                          onTap: () => _pick(specId),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'More hero types unlock as you grow. You do not need another game.',
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
              if (!_ready && blockReason != null) ...[
                Text(
                  blockReason,
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: GameButton(
                      label: 'BACK',
                      style: GameButtonStyle.grey,
                      onPressed: widget.onBack,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GameButton(
                      label: 'START',
                      style: GameButtonStyle.brown,
                      onPressed: _ready ? _tryStart : null,
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
                      : CustomAssets.heroForSpec(def.id),
                  size: 40,
                ),
                const SizedBox(height: 4),
                Text(
                  def?.shortLabel ?? 'SLOT ${index + 1}',
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 13, color: GameTheme.parchment),
                ),
                Text(
                  def?.roleTag.plainLabel ?? 'Tap to pick',
                  textAlign: TextAlign.center,
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

  String get _lockLabel => 'Unlocks later';

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    KenneySprite(
                      asset: CustomAssets.heroForSpec(def.id),
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
                            locked ? _lockLabel : def.plainRoleLine,
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
