@Tags(['lookbook'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/shell/dev_gear_lookbook.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/equipment_model_catalog.dart';

/// Renders the debug lookbook to PNGs under tool/out/lookbook/.
///
/// Run with `py -3 tool/gear_lookbook.py`. Without `--dart-define=LOOKBOOK=true`
/// this test does nothing, so CI stays fast.
void main() {
  testWidgets('write gear lookbook sheets', (tester) async {
    if (!const bool.fromEnvironment('LOOKBOOK')) return;

    const outDir = 'tool/out/lookbook';
    Directory(outDir).createSync(recursive: true);

    for (final family in BodyFamily.values) {
      await _saveFamily(tester, outDir, family, 'armor', const [
        'helm',
        'chest',
        'legs',
        'cloak',
      ]);
      await _saveFamily(tester, outDir, family, 'snap', const [
        'hands',
        'shoulder',
      ]);
      await _saveFamily(tester, outDir, family, 'weapons_a', const [
        'sword',
        'staff',
        'dagger',
        'mace',
        'axe',
      ]);
      await _saveFamily(tester, outDir, family, 'weapons_b', const [
        'bow',
        'shield',
        'frill',
        'wand',
        'gun',
        'crossbow',
        'polearm',
        'fist',
        'thrown',
      ]);
    }

    await _saveSheet(
      tester,
      '$outDir/fit_kit.png',
      _column([
        _caption('FULL KIT  helm chest legs shoulder + family weapon'),
        _row([
          for (final family in BodyFamily.values) _kitCell(family),
        ]),
      ]),
      const Size(760, 280),
    );

    await _saveSheet(
      tester,
      '$outDir/fit_materials.png',
      _column([
        _caption('CHEST on the body that wears that material'),
        _row([
          _dollCell(BodyFamily.warrior, 'chest_t0', null, 'warrior native'),
          _dollCell(
            BodyFamily.warrior,
            'chest_t0',
            ArmorType.leather,
            'warrior leather',
          ),
          _dollCell(BodyFamily.rogue, 'chest_t0', null, 'rogue native'),
          _dollCell(
            BodyFamily.rogue,
            'chest_t0',
            ArmorType.mail,
            'rogue mail',
          ),
          _dollCell(BodyFamily.mage, 'chest_t0', null, 'mage native'),
          _dollCell(
            BodyFamily.mage,
            'chest_t0',
            ArmorType.leather,
            'mage leather',
          ),
        ]),
        _row([
          _dollCell(BodyFamily.healer, 'chest_t0', null, 'healer cloth'),
          _dollCell(
            BodyFamily.healer,
            'chest_t0',
            ArmorType.leather,
            'healer leather',
          ),
          _dollCell(
            BodyFamily.healer,
            'chest_t0',
            ArmorType.mail,
            'healer mail',
          ),
          _dollCell(
            BodyFamily.healer,
            'chest_t0',
            ArmorType.plate,
            'healer plate',
          ),
        ]),
      ]),
      const Size(900, 520),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _saveFamily(
  WidgetTester tester,
  String outDir,
  BodyFamily family,
  String group,
  List<String> bases,
) {
  final rows = <Widget>[
    _caption('${family.name.toUpperCase()}  $group'),
    for (final base in bases)
      _row([
        for (final id in EquipmentModelCatalog.variants[base] ?? const [])
          _dollCell(family, id, null, id),
      ]),
  ];
  final cols = bases
      .map((base) => EquipmentModelCatalog.variants[base]?.length ?? 1)
      .fold<int>(1, (a, b) => a > b ? a : b);
  return _saveSheet(
    tester,
    '$outDir/${family.name}_$group.png',
    _column(rows),
    Size(cols * 124 + 24, bases.length * 150 + 48),
  );
}

Widget _kitCell(BodyFamily family) {
  final weapon = switch (family) {
    BodyFamily.warrior => 'sword_t0',
    BodyFamily.rogue => 'dagger_t0',
    BodyFamily.mage => 'staff_t0',
    BodyFamily.healer => 'wand_t0',
  };
  final items = <EquipmentSlot, EquipmentItem>{
    EquipmentSlot.head: gearLookbookItem('helm_t0', null),
    EquipmentSlot.chest: gearLookbookItem('chest_t0', null),
    EquipmentSlot.legs: gearLookbookItem('legs_t0', null),
    EquipmentSlot.shoulder: gearLookbookItem('shoulder_t0', null),
    EquipmentSlot.weapon: gearLookbookItem(weapon, null),
  };
  if (family == BodyFamily.warrior) {
    items[EquipmentSlot.offHand] = gearLookbookItem('shield_t0', null);
  } else if (family == BodyFamily.mage) {
    items[EquipmentSlot.offHand] = gearLookbookItem('frill_t0', null);
  }
  final hero = PartyHero.starting(
    name: 'Kit',
    specId: gearLookbookSpec(family),
    id: 'kit-${family.name}',
    equipped: items,
  );
  return _frame(family.name, HeroDollSprite(hero: hero, size: 112));
}

Widget _dollCell(
  BodyFamily family,
  String visualSetId,
  ArmorType? material,
  String label,
) {
  final item = gearLookbookItem(visualSetId, material);
  final hero = PartyHero.starting(
    name: 'Look',
    specId: gearLookbookSpec(family),
    id: 'sheet-${family.name}-$visualSetId-${material?.name ?? 'native'}',
    equipped: {item.slot: item},
  );
  return _frame(label, HeroDollSprite(hero: hero, size: 96));
}

Widget _frame(String label, Widget doll) {
  return SizedBox(
    width: 120,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: const TextStyle(color: Color(0xFFE6C36A), fontSize: 9),
        ),
        doll,
      ],
    ),
  );
}

Widget _caption(String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFFF4E4C4), fontSize: 13),
    ),
  );
}

Widget _row(List<Widget> children) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  );
}

Widget _column(List<Widget> children) {
  return ColoredBox(
    color: const Color(0xFF16141C),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

Future<void> _saveSheet(
  WidgetTester tester,
  String path,
  Widget sheet,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF16141C),
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: sheet),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}
