import 'package:flutter/material.dart';

import '../core/game_logic.dart';
import '../core/party_name_filter.dart';
import '../core/starter_gear.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../assets/custom_assets.dart';
import 'game_theme.dart';
import 'hero_doll_sprite.dart';
import 'hero_look_row.dart';
import 'kenney_button.dart';
import 'kenney_sprite.dart';
import 'menu_chrome.dart';

/// Pick exactly [GameLogic.starterPartySize] unique specs for a new run.
///
/// Each slot keeps its own [HeroRace]. The editor under the cards switches
/// between **CLASS** (starter kits only) and **RACE** (Cataclysm races).
class NewGamePartyPicker extends StatefulWidget {
  const NewGamePartyPicker({
    super.key,
    required this.onConfirm,
    required this.onBack,
    this.initialSpecs,
  });

  final void Function(
    List<HeroSpecId> specs,
    String partyName,
    List<HeroRace> races,
  )
  onConfirm;
  final VoidCallback onBack;
  final List<HeroSpecId>? initialSpecs;

  @override
  State<NewGamePartyPicker> createState() => _NewGamePartyPickerState();
}

enum _PartyEditTab { classTab, raceTab }

class _NewGamePartyPickerState extends State<NewGamePartyPicker> {
  late final List<HeroSpecId?> _slots;
  late final TextEditingController _nameCtrl;
  late HeroClassId _filter;
  int _activeSlot = 0;
  _PartyEditTab _tab = _PartyEditTab.classTab;
  bool _nameError = false;
  String? _pickHint;
  late final List<HeroRace> _looks;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialSpecs ?? HeroSpecs.starterUnlocked;
    _slots = List<HeroSpecId?>.filled(GameLogic.starterPartySize, null);
    _looks = List<HeroRace>.filled(
      GameLogic.starterPartySize,
      HeroRace.human,
    );
    for (var i = 0; i < _slots.length && i < seed.length; i++) {
      _slots[i] = seed[i];
    }
    _filter = _classForSlot(0);
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  HeroClassId _classForSlot(int index) {
    final spec = _slots[index];
    if (spec != null) return HeroSpecs.def(spec).classId;
    return HeroSpecs.def(HeroSpecs.starterUnlocked.first).classId;
  }

  void _selectSlot(int index) {
    setState(() {
      _activeSlot = index;
      _filter = _classForSlot(index);
      _pickHint = null;
    });
  }

  void _tryStart() {
    if (!_ready) return;
    final name = PartyNameFilter.sanitize(_nameCtrl.text);
    if (name == null) {
      setState(() => _nameError = true);
      return;
    }
    widget.onConfirm([for (final s in _slots) s!], name, List.of(_looks));
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

  String get _activeKitLabel {
    final spec = _slots[_activeSlot];
    if (spec == null) return 'Slot ${_activeSlot + 1}';
    return HeroSpecs.def(spec).shortLabel;
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
        _filter = HeroSpecs.def(id).classId;
        _tab = _PartyEditTab.classTab;
      });
      return;
    }
    setState(() {
      _pickHint = null;
      _slots[_activeSlot] = id;
      final next = _nextEmptySlot(after: _activeSlot);
      if (next != null) {
        _activeSlot = next;
        _filter = _classForSlot(next);
      } else {
        _filter = HeroSpecs.def(id).classId;
      }
    });
  }

  PartyHero _previewHero(HeroSpecId specId, HeroRace race, {int? slot}) {
    final def = HeroSpecs.def(specId);
    return PartyHero.starting(
      name: def.defaultName,
      specId: specId,
      race: race,
      id: 'new_party_${slot ?? _activeSlot}_${specId.name}',
      // Same stack as after START — bare undertunic alone looks like a stick.
      equipped: StarterGear.forSpec(specId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final starterSpecs = [
      for (final id in HeroSpecs.forClass(_filter))
        if (HeroSpecs.starterUnlocked.contains(id)) id,
    ];
    final warn = _softWarn;
    final blockReason = _startBlockReason;
    final starterClasses = <HeroClassId>[
      for (final id in HeroSpecs.starterUnlocked) HeroSpecs.def(id).classId,
    ];
    final seenClass = <HeroClassId>{};
    final classTabs = <HeroClassId>[
      for (final c in starterClasses)
        if (seenClass.add(c)) c,
    ];
    final statusLine = _pickHint ?? warn;

    return Scaffold(
      backgroundColor: GameTheme.ink,
      body: MenuChrome.playSafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'NEW PARTY',
                textAlign: TextAlign.center,
                style: GameTheme.menuTitle(size: 18),
              ),
              const SizedBox(height: 6),
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
                  isDense: true,
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
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _slots.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _SlotCard(
                        index: i,
                        specId: _slots[i],
                        look: _looks[i],
                        selected: _activeSlot == i,
                        hero: _slots[i] == null
                            ? null
                            : _previewHero(_slots[i]!, _looks[i], slot: i),
                        onTap: () => _selectSlot(i),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              MenuChrome.segmented(
                dense: true,
                labels: const ['CLASS', 'RACE'],
                selectedIndex: _tab == _PartyEditTab.classTab ? 0 : 1,
                onSelect: (i) => setState(() {
                  _tab = i == 0
                      ? _PartyEditTab.classTab
                      : _PartyEditTab.raceTab;
                  _pickHint = null;
                }),
              ),
              const SizedBox(height: 6),
              Text(
                _tab == _PartyEditTab.classTab
                    ? 'Class for $_activeKitLabel — Shield / Healer / Damage'
                    : 'Race for $_activeKitLabel · ${_looks[_activeSlot].label}',
                textAlign: TextAlign.center,
                style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
              ),
              if (statusLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  statusLine,
                  textAlign: TextAlign.center,
                  style: GameTheme.body(size: 12, color: GameTheme.torchHot),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: MenuChrome.panel(opaque: true),
                  child: _tab == _PartyEditTab.raceTab
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          child: HeroLookRow(
                            value: _looks[_activeSlot],
                            compact: true,
                            title: 'RACE',
                            columns: 4,
                            dollFor: (race) => _previewHero(
                              _slots[_activeSlot] ??
                                  HeroSpecs.starterUnlocked.first,
                              race,
                            ),
                            onChanged: (race) => setState(
                              () => _looks[_activeSlot] = race,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                              child: SizedBox(
                                height: 34,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final classId in classTabs)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: GameButton(
                                          label: HeroSpecs.classLabel(classId)
                                              .toUpperCase(),
                                          expanded: false,
                                          dense: true,
                                          style: _filter == classId
                                              ? GameButtonStyle.brown
                                              : GameButtonStyle.grey,
                                          onPressed: () => setState(
                                            () => _filter = classId,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(8),
                                children: [
                                  for (final specId in starterSpecs)
                                    _SpecPickRow(
                                      def: HeroSpecs.def(specId),
                                      taken: _slots.contains(specId),
                                      preview: _previewHero(
                                        specId,
                                        _looks[_activeSlot],
                                      ),
                                      onTap: () => _pick(specId),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'More kits unlock as you grow.',
                                    textAlign: TextAlign.center,
                                    style: GameTheme.body(
                                      size: 12,
                                      color: GameTheme.parchmentDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (!_ready && blockReason != null) ...[
                Text(
                  blockReason,
                  textAlign: TextAlign.center,
                  style: GameTheme.body(
                    size: 12,
                    color: GameTheme.parchmentDim,
                  ),
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
    required this.look,
    required this.selected,
    required this.onTap,
    required this.hero,
  });

  final int index;
  final HeroSpecId? specId;
  final HeroRace look;
  final bool selected;
  final VoidCallback onTap;
  final PartyHero? hero;

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
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Column(
              children: [
                if (hero == null)
                  KenneySprite(
                    asset: CustomAssets.heroKnight,
                    size: 48,
                  )
                else
                  HeroDollSprite(
                    hero: hero!,
                    partyIndex: index,
                    size: 48,
                  ),
                const SizedBox(height: 4),
                Text(
                  def?.shortLabel ?? 'SLOT ${index + 1}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(size: 12, color: GameTheme.parchment),
                ),
                Text(
                  def?.roleTag.plainLabel ?? 'Tap',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.body(
                    size: 10,
                    color: GameTheme.parchmentDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  look.shortLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GameTheme.pixel(
                    size: GameTheme.hudPixel,
                    color: look == HeroRace.human
                        ? GameTheme.parchmentDim
                        : GameTheme.mossLit,
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
    required this.taken,
    required this.onTap,
    required this.preview,
  });

  final HeroSpecDef def;
  final bool taken;
  final VoidCallback onTap;
  final PartyHero preview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GameTheme.radiusSm),
          child: DecoratedBox(
            decoration: MenuChrome.listCard(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  HeroDollSprite(
                    hero: preview,
                    partyIndex: 0,
                    size: 40,
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
                          def.plainRoleLine,
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
                    style: GameTheme.body(
                      size: 13,
                      color: taken ? GameTheme.mossLit : GameTheme.torchHot,
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
