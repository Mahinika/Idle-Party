import 'package:flutter/material.dart';

import '../../models/hero.dart';
import '../../models/hero_spec.dart';
import '../../models/loot.dart';
import '../../models/proficiency.dart';
import '../../visual/body_family.dart';
import '../../visual/equipment_model_catalog.dart';
import '../../visual/owned_gear_assets.dart';
import '../equipment_icon.dart';
import '../game_theme.dart';
import '../hero_doll_sprite.dart';

/// Debug-only gallery: one doll and two icon sizes per active gear model.
///
/// Nothing here is saved. Open it from MORE → SETTINGS in a debug build.
class DevGearLookbook extends StatefulWidget {
  const DevGearLookbook({super.key});

  @override
  State<DevGearLookbook> createState() => _DevGearLookbookState();
}

class _DevGearLookbookState extends State<DevGearLookbook> {
  ArmorType? _material;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: BodyFamily.values.length,
      child: Scaffold(
        backgroundColor: GameTheme.ink,
        appBar: AppBar(
          backgroundColor: GameTheme.stoneDeep,
          foregroundColor: GameTheme.parchment,
          title: const Text('GEAR LOOKBOOK'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final family in BodyFamily.values)
                Tab(text: family.name.toUpperCase()),
            ],
          ),
        ),
        body: Column(
          children: [
            _materialBar(),
            Expanded(
              child: TabBarView(
                children: [
                  for (final family in BodyFamily.values)
                    _FamilyPage(family: family, material: _material),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _materialBar() {
    final choices = <ArmorType?>[null, ...ArmorType.values];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (final mat in choices)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(mat?.name.toUpperCase() ?? 'NATIVE'),
                selected: _material == mat,
                onSelected: (_) => setState(() => _material = mat),
              ),
            ),
        ],
      ),
    );
  }
}

class _FamilyPage extends StatelessWidget {
  const _FamilyPage({required this.family, required this.material});

  final BodyFamily family;
  final ArmorType? material;

  @override
  Widget build(BuildContext context) {
    final allowed = OwnedGearAssets.kFamilyMaterials[family] ?? const <String>[];
    final mat = material == null || allowed.contains(material!.name)
        ? material
        : null;
    final rows = <String, List<String>>{};
    for (final base in EquipmentModelCatalog.familyBases) {
      rows[base] = EquipmentModelCatalog.variants[base] ?? const [];
    }
    for (final base in EquipmentModelCatalog.sharedBases) {
      rows[base] = EquipmentModelCatalog.variants[base] ?? const [];
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in rows.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              entry.key.toUpperCase(),
              style: GameTheme.body(size: 12, color: GameTheme.torch),
            ),
          ),
          SizedBox(
            height: 132,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final id in entry.value)
                  _LookCell(
                    family: family,
                    visualSetId: id,
                    material: EquipmentModelCatalog.familyBases.contains(entry.key)
                        ? mat
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LookCell extends StatelessWidget {
  const _LookCell({
    required this.family,
    required this.visualSetId,
    required this.material,
  });

  final BodyFamily family;
  final String visualSetId;
  final ArmorType? material;

  @override
  Widget build(BuildContext context) {
    final item = gearLookbookItem(visualSetId, material);
    final hero = PartyHero.starting(
      name: 'Look',
      specId: gearLookbookSpec(family),
      id: 'look-${family.name}-$visualSetId-${material?.name ?? 'native'}',
      equipped: {item.slot: item},
    );
    return Semantics(
      label: '${family.name} $visualSetId ${material?.name ?? 'native'}',
      child: Container(
        width: 96,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(4),
        color: GameTheme.panel,
        child: Column(
          children: [
            HeroDollSprite(hero: hero, size: 64),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EquipmentIcon(item: item, hero: hero, size: 26),
                const SizedBox(width: 4),
                EquipmentIcon(item: item, hero: hero, size: 42),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

/// Spec the debug lookbook uses for each body.
HeroSpecId gearLookbookSpec(BodyFamily family) => switch (family) {
  BodyFamily.warrior => HeroSpecId.protection,
  BodyFamily.rogue => HeroSpecId.combat,
  BodyFamily.mage => HeroSpecId.fire,
  BodyFamily.healer => HeroSpecId.discipline,
};

/// Same item the debug lookbook paints. The sheet tool uses this so a
/// picture on disk matches the phone.
///
/// [asOffHand] puts a weapon in the off hand. Staff, polearm, bow, gun, and
/// crossbow are two-hand, so the game hides an off-hand worn with them.
EquipmentItem gearLookbookItem(
  String visualSetId,
  ArmorType? material, {
  bool asOffHand = false,
}) {
  final base = EquipmentModelCatalog.baseToken(visualSetId);
  final slot = asOffHand
      ? EquipmentSlot.offHand
      : switch (base) {
          'helm' => EquipmentSlot.head,
          'chest' => EquipmentSlot.chest,
          'legs' => EquipmentSlot.legs,
          'cloak' => EquipmentSlot.cloak,
          'hands' => EquipmentSlot.hands,
          'shoulder' => EquipmentSlot.shoulder,
          'shield' || 'frill' => EquipmentSlot.offHand,
          _ => EquipmentSlot.weapon,
        };
  final weaponType = switch (base) {
    'sword' => WeaponType.sword,
    'staff' => WeaponType.staff,
    'dagger' => WeaponType.dagger,
    'mace' => WeaponType.mace,
    'axe' => WeaponType.axe,
    'bow' => WeaponType.bow,
    'wand' => WeaponType.wand,
    'gun' => WeaponType.gun,
    'crossbow' => WeaponType.crossbow,
    'polearm' => WeaponType.polearm,
    'fist' => WeaponType.fist,
    'thrown' => WeaponType.thrown,
    _ => null,
  };
  return EquipmentItem(
    id: 'look-$visualSetId${asOffHand ? '-off' : ''}',
    name: visualSetId,
    slot: slot,
    rarity: LootRarity.common,
    visualSetId: visualSetId,
    armorType: material,
    weaponType: weaponType,
    handed: weaponType == null
        ? null
        : ClassProficiency.defaultHanded(weaponType),
    offHandKind: asOffHand
        ? OffHandKind.weapon
        : switch (base) {
            'shield' => OffHandKind.shield,
            'frill' => OffHandKind.frill,
            _ => null,
          },
  );
}
