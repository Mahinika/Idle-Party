import 'package:flutter/material.dart';
import '../../core/game_director.dart';
import '../../core/game_logic.dart';
import '../../core/game_state.dart';
import '../../core/party_name_filter.dart';
import '../../models/dungeon_def.dart';
import '../../models/pet.dart';
import '../../assets/custom_assets.dart';
import '../game_theme.dart';
import '../kenney_button.dart';
import '../kenney_sprite.dart';
import '../menu_chrome.dart';
import '../web_click_bridge.dart';

class BeastOverlay extends StatefulWidget {
  const BeastOverlay({super.key, required this.director});
  final GameDirector director;

  @override
  State<BeastOverlay> createState() => _BeastOverlayState();
}

class _BeastOverlayState extends State<BeastOverlay> {
  String? _mergeA;
  String? _mergeB;

  GameDirector get director => widget.director;
  GameState get state => director.state;

  void _toggleMerge(String petId) {
    setState(() {
      if (_mergeA == petId) {
        _mergeA = null;
        return;
      }
      if (_mergeB == petId) {
        _mergeB = null;
        return;
      }
      if (_mergeA == null) {
        _mergeA = petId;
      } else if (_mergeB == null) {
        _mergeB = petId;
      } else {
        _mergeA = _mergeB;
        _mergeB = petId;
      }
    });
  }

  Future<void> _promptRename(Pet pet) async {
    WebClickBridge.pushLayer();
    String? next;
    try {
      next = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => _RenamePetDialog(
          speciesName: pet.speciesName,
          currentName: pet.name,
        ),
      );
    } finally {
      WebClickBridge.popLayer();
    }
    if (!mounted || next == null) return;
    director.renamePet(pet.id, next);
  }

  void _doMerge() {
    final a = _mergeA;
    final b = _mergeB;
    if (a == null || b == null) return;
    director.mergePets(a, b);
    setState(() {
      _mergeA = null;
      _mergeB = null;
    });
  }

  PetFrame _nextFrame(PetFrame current) {
    final idx = (current.index + 1) % PetFrame.values.length;
    final next = PetFrame.values[idx == 0 ? 1 : idx];
    return next;
  }

  static String _passiveLabel(Pet pet) {
    if (pet.passive == PetPassive.attack) return '';
    final name = switch (pet.passive) {
      PetPassive.attack => 'ATK',
      PetPassive.goldFind => 'GOLD',
      PetPassive.lootFind => 'LOOT',
      PetPassive.xpFind => 'XP',
      PetPassive.mitigate => 'MIT',
      PetPassive.healBoost => 'HEAL',
    };
    final v = pet.passiveValue(dungeonId: pet.affinityDungeonId);
    return '$name${v > 0 ? ' +$v' : ''}';
  }

  static String _affinityLabel(String dungeonId) {
    if (dungeonId.isEmpty) return '';
    // Compact first word from catalog name (never invent aliases).
    final name = DungeonCatalog.byId(dungeonId).name;
    return name.replaceAll("'s", '').split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final cap = state.metaDepth.basePetRosterCap;
    final canMerge = _mergeA != null && _mergeB != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Roster ${state.ownedPets.length}/$cap',
          textAlign: TextAlign.center,
          style: GameTheme.menuTitle(size: 16, color: GameTheme.torchHot),
        ),
        const SizedBox(height: 4),
        Text(
          'Favorite species: +1 ATK and a stronger passive while that pet is ACTIVE. '
          'Bond +1 ATK every 5 ranks. Frames are looks only.',
          textAlign: TextAlign.center,
          style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
        ),
        if (state.metaDepth.favoritePetSpecies.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Favorite: ${PetCatalog.byId(state.metaDepth.favoritePetSpecies)?.name ?? state.metaDepth.favoritePetSpecies}',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
        ],
        const SizedBox(height: 8),
        if (state.ownedPets.isEmpty) ...[
          const SizedBox(height: 8),
          Center(child: KenneySprite(asset: CustomAssets.petEgg, size: 56)),
          const SizedBox(height: 10),
          Text(
            'No pets yet',
            textAlign: TextAlign.center,
            style: GameTheme.menuTitle(size: 16, color: GameTheme.torchHot),
          ),
          const SizedBox(height: 6),
          Text(
            'Hatch an egg with essence — random species and rarity. '
            'Companions fight beside the party and grant passives (gold, loot, mitigate…).',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 14, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Text(
            canMerge
                ? (GameLogic.canMergePets(state, _mergeA!, _mergeB!)
                      ? 'CONFIRM — both become one higher-rarity pet'
                      : 'Need the same species and same rarity (legendary cannot merge)')
                : 'Tap MERGE on two same-species pets of the same rarity',
            textAlign: TextAlign.center,
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 6),
          if (canMerge)
            GameButton(
              label: 'CONFIRM MERGE',
              style: GameButtonStyle.red,
              onPressed:
                  _mergeA != null &&
                      _mergeB != null &&
                      GameLogic.canMergePets(state, _mergeA!, _mergeB!)
                  ? _doMerge
                  : null,
            ),
          const SizedBox(height: 8),
          for (final pet in state.ownedPets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: MenuChrome.listCard(
                  selected:
                      pet.id == _mergeA ||
                      pet.id == _mergeB ||
                      state.activePet?.id == pet.id,
                  borderColor: pet.id == _mergeA || pet.id == _mergeB
                      ? GameTheme.clear
                      : state.activePet?.id == pet.id
                      ? GameTheme.torch
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        KenneySprite(
                          asset: CustomAssets.petForInstanceId(pet.id),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final passive = _passiveLabel(pet);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${pet.name}  |  ${pet.rarity.name}'
                                    '${pet.frame != PetFrame.none ? '  [${pet.frame.name}]' : ''}',
                                    style: GameTheme.body(
                                      size: 15,
                                      color: GameTheme.parchment,
                                    ),
                                  ),
                                  Text(
                                    '${pet.hasNickname ? '${pet.speciesName}  ' : ''}'
                                    'Lv${pet.level}  ATK +${pet.totalAttackBonus}'
                                    '${passive.isEmpty ? '' : '  $passive'}'
                                    '  · aff ${_affinityLabel(pet.affinityDungeonId)}'
                                    '${pet.bondLevel > 0 ? '  bond${pet.bondLevel}' : ''}',
                                    style: GameTheme.body(
                                      size: 13,
                                      color: GameTheme.parchmentDim,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (state.activePet?.id == pet.id)
                          Text(
                            'ACTIVE',
                            style: GameTheme.body(
                              size: 12,
                              color: GameTheme.torchHot,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GameButton(
                      label: 'RENAME',
                      style: GameButtonStyle.grey,
                      dense: true,
                      tip: 'Give this pet its own name',
                      onPressed: () => _promptRename(pet),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GameButton(
                            label: state.activePet?.id == pet.id
                                ? 'ACTIVE'
                                : 'SET ACTIVE',
                            style: GameButtonStyle.grey,
                            onPressed: state.activePet?.id == pet.id
                                ? null
                                : () => director.setActivePet(pet.id),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GameButton(
                            label: pet.level >= GameLogic.maxPetLevel
                                ? 'LEVEL MAX'
                                : 'LEVEL ${GameLogic.petLevelUpCost(pet)}e · +1 ATK',
                            onPressed:
                                pet.level < GameLogic.maxPetLevel &&
                                    state.essence >=
                                        GameLogic.petLevelUpCost(pet)
                                ? () => director.levelUpPet(pet.id)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GameButton(
                            label: pet.id == _mergeA || pet.id == _mergeB
                                ? 'MERGING'
                                : 'MERGE',
                            style: pet.id == _mergeA || pet.id == _mergeB
                                ? GameButtonStyle.brown
                                : GameButtonStyle.grey,
                            onPressed: () => _toggleMerge(pet.id),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GameButton(
                            label:
                                state.metaDepth.favoritePetSpecies ==
                                    pet.resolvedSpecies
                                ? 'FAVORITED'
                                : 'FAVORITE',
                            style:
                                state.metaDepth.favoritePetSpecies ==
                                    pet.resolvedSpecies
                                ? GameButtonStyle.brown
                                : GameButtonStyle.grey,
                            onPressed: () => director.setFavoritePetSpecies(
                              pet.resolvedSpecies,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GameButton(
                            label: pet.bondLevel >= GameLogic.maxPetBondLevel
                                ? 'BOND MAX'
                                : 'BOND ${GameLogic.bondPetCost(pet.bondLevel)}e'
                                      '${(pet.bondLevel + 1) ~/ 5 > pet.bondLevel ~/ 5 ? ' · +1 ATK' : ''}',
                            style: GameButtonStyle.grey,
                            onPressed:
                                pet.bondLevel < GameLogic.maxPetBondLevel &&
                                    state.essence >=
                                        GameLogic.bondPetCost(pet.bondLevel)
                                ? () => director.bondPet(pet.id)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final next = _nextFrame(pet.frame);
                              final cost = GameLogic.petFrameCost(next);
                              return GameButton(
                                label: pet.frame == PetFrame.crystal
                                    ? 'FRAME MAX'
                                    : 'FRAME ${next.name} ${cost}e · looks',
                                style: GameButtonStyle.grey,
                                onPressed:
                                    pet.frame == PetFrame.crystal ||
                                        state.essence < cost
                                    ? null
                                    : () => director.buyPetFrame(pet.id, next),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const KenneySprite(asset: CustomAssets.petEgg, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: state.ownedPets.length >= cap
                    ? 'ROSTER FULL'
                    : 'HATCH ${GameLogic.hatchPetCost(state)}e',
                onPressed:
                    state.ownedPets.length < cap &&
                        state.essence >= GameLogic.hatchPetCost(state)
                    ? director.hatchPet
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RenamePetDialog extends StatefulWidget {
  const _RenamePetDialog({
    required this.speciesName,
    required this.currentName,
  });

  final String speciesName;
  final String currentName;

  @override
  State<_RenamePetDialog> createState() => _RenamePetDialogState();
}

class _RenamePetDialogState extends State<_RenamePetDialog> {
  late final TextEditingController _ctrl;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentName.length,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final next = PartyNameFilter.sanitize(
      _ctrl.text,
      whenEmpty: widget.speciesName,
    );
    if (next == null) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GameTheme.sheet,
      title: Text(
        'RENAME',
        style: GameTheme.body(size: 16, color: GameTheme.parchment),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.speciesName,
            style: GameTheme.body(size: 13, color: GameTheme.parchmentDim),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: PartyNameFilter.maxLen,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            style: GameTheme.body(size: 15, color: GameTheme.parchment),
            cursorColor: GameTheme.torchHot,
            onChanged: (_) {
              if (_error) setState(() => _error = false);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Grubby',
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
                borderSide: BorderSide(color: GameTheme.torch),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ? 'Choose another name' : 'Blank uses ${widget.speciesName}',
            style: GameTheme.body(size: 12, color: GameTheme.parchmentDim),
          ),
        ],
      ),
      actions: [
        MenuChrome.dialogCancel(
          label: 'CLOSE',
          onPressed: () => Navigator.of(context).pop(),
        ),
        GameButton(
          label: 'NAME',
          style: GameButtonStyle.brown,
          expanded: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
