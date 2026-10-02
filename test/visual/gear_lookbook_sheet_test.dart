@Tags(['lookbook'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/proficiency.dart';
import 'package:idle_party/ui/decoded_image_cache.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/shell/dev_gear_lookbook.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/equipment_model_catalog.dart';
import 'package:idle_party/visual/owned_gear_assets.dart';

import 'lookbook_measure.dart';

/// Renders the debug lookbook to PNGs under tool/out/lookbook/.
///
/// Run with `py -3 tool/gear_lookbook.py`. Without `--dart-define=LOOKBOOK=true`
/// this test does nothing, so CI stays fast.
void main() {
  testWidgets('write gear lookbook sheets', (tester) async {
    if (!const bool.fromEnvironment('LOOKBOOK')) return;

    const outDir = 'tool/out/lookbook';
    Directory(outDir).createSync(recursive: true);
    final outfits = _outfits();
    final scope = _scope();
    final onlyFamily = _scopeFamily();
    await tester.runAsync(_loadFont);
    await tester.runAsync(_precache);

    final families = BodyFamily.values.where(
      (family) => onlyFamily == null || family.name == onlyFamily,
    );
    if (scope == 'all' || scope == 'body' || scope == 'armor') {
      for (final family in families) {
        final sheets = (outfits['sheets'] as Map).cast<String, dynamic>();
        for (final entry in sheets.entries) {
          if (!_wantsSheet(scope, entry.key)) continue;
          await _saveFamily(
            tester,
            outDir,
            family,
            entry.key,
            (entry.value as List).cast<String>(),
          );
        }
      }
    }
    if (scope == 'weapons') {
      final sheets = (outfits['sheets'] as Map).cast<String, dynamic>();
      for (final family in families) {
        for (final key in ['weapons_a', 'weapons_b']) {
          await _saveFamily(
            tester,
            outDir,
            family,
            key,
            (sheets[key] as List).cast<String>(),
          );
        }
      }
    }

    if (scope == 'all') {
      await _saveSheet(
        tester,
        '$outDir/fit_kit.png',
        _column([
          _caption('FULL KIT  helm chest legs shoulder + family weapon'),
          _row([
            for (final family in BodyFamily.values) _kitCell(outfits, family),
          ]),
        ]),
        const Size(760, 280),
      );
    }

    if (scope == 'summary' || scope == 'all') {
      await _saveCompare(tester, outDir, outfits);
      await _saveClassSheet(tester, outDir);
      await _saveRaceSheets(tester, outDir, outfits);
    }
    if (scope == 'weapons' || scope == 'all') {
      await _saveWeaponCompare(tester, outDir, outfits);
    }

    if (scope == 'all' || scope == 'armor') {
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
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('measure gear lookbook dolls', (tester) async {
    if (!const bool.fromEnvironment('LOOKBOOK')) return;
    await tester.runAsync(
      () => writeLookbookMeasure('tool/out/lookbook', _outfits()),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// The test font draws every letter as a block. A real font makes the
/// labels readable. Missing fonts keep the blocks; order still holds.
Future<void> _loadFont() async {
  for (final path in const [
    'C:/Windows/Fonts/arial.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/System/Library/Fonts/Supplemental/Arial.ttf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader(_font)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
    return;
  }
}

const _font = 'LookbookSans';

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

/// Stacks pieces on one body so a worn set can be compared with a bare one.
///
/// Rows follow [tool/lookbook_outfits.json]. Columns: bare, armor, layers,
/// armed, pair. This is the summary sheet.
Future<void> _saveCompare(
  WidgetTester tester,
  String outDir,
  Map<String, dynamic> outfits,
) {
  final layers = (outfits['layers'] as List).cast<String>();
  final families = (outfits['families'] as List).cast<String>();
  final weapons = (outfits['familyWeapon'] as Map).cast<String, dynamic>();
  final pairs = (outfits['pair'] as Map).cast<String, dynamic>();
  return _saveSheet(
    tester,
    '$outDir/fit_summary.png',
    _column([
      _caption('SUMMARY  bare  armor  layers  armed  pair'),
      for (final name in families)
        _row([
          _mixCell(_family(name), 'bare', const []),
          _mixCell(_family(name), 'armor', (outfits['armor'] as List).cast<String>()),
          _mixCell(_family(name), 'layers', layers),
          _mixCell(_family(name), 'armed', [
            ...layers,
            weapons[name] as String,
          ]),
          _mixCell(
            _family(name),
            'pair',
            [
              ...layers,
              ...((pairs[name] as Map)['pieces'] as List).cast<String>(),
            ],
            offHandWeapon: (pairs[name] as Map)['offHand'] as String?,
          ),
        ]),
    ]),
    const Size(5 * 124 + 24, 4 * 150 + 48),
  );
}

/// One sheet per body. Columns are the twelve races. Rows are male, then female.
/// Each doll wears the full t0 set and that body's weapon.
Future<void> _saveRaceSheets(
  WidgetTester tester,
  String outDir,
  Map<String, dynamic> outfits,
) async {
  const layers = [
    'helm_t0',
    'chest_t0',
    'legs_t0',
    'shoulder_t0',
    'cloak_t0',
    'hands_t0',
  ];
  final weapons = (outfits['familyWeapon'] as Map).cast<String, dynamic>();
  const cellW = 108.0;
  final races = HeroRace.values;
  final width = races.length * cellW + 72;
  for (final family in BodyFamily.values) {
    final weapon = weapons[family.name] as String;
    await _saveSheet(
      tester,
      '$outDir/fit_races_${family.name}.png',
      _column([
        _caption(
          '${family.name.toUpperCase()}  male then female  full kit + $weapon',
        ),
        _row([
          const SizedBox(width: 64),
          for (final race in races) _raceTag(race.shortLabel),
        ]),
        for (final sex in HeroSex.values)
          _row([
            _raceTag(sex.name, width: 64),
            for (final race in races)
              _raceCell(family, race, sex, layers, weapon),
          ]),
      ]),
      Size(width, 2 * 132 + 64),
    );
  }
}

Widget _raceTag(String label, {double width = 108}) {
  return SizedBox(
    width: width,
    height: 18,
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: const TextStyle(color: Color(0xFFE6C36A), fontSize: 9),
    ),
  );
}

Widget _raceCell(
  BodyFamily family,
  HeroRace race,
  HeroSex sex,
  List<String> layers,
  String weaponId,
) {
  final items = <EquipmentSlot, EquipmentItem>{};
  for (final id in layers) {
    final item = gearLookbookItem(id, null);
    items[item.slot] = item;
  }
  items[EquipmentSlot.weapon] = gearLookbookItem(weaponId, null);
  final hero = PartyHero.starting(
    name: '${race.assetKey} ${sex.assetKey}',
    specId: gearLookbookSpec(family),
    id: 'race-${family.name}-${race.assetKey}-${sex.assetKey}',
    equipped: items,
    race: race,
    sex: sex,
  );
  return SizedBox(
    width: 108,
    height: 120,
    child: HeroDollSprite(hero: hero, size: 96),
  );
}

/// Two columns so every class fits on one screen. Specs that share a body,
/// armor, and weapons collapse into one doll. Weapons match `StarterGear`.
Future<void> _saveClassSheet(WidgetTester tester, String outDir) {
  const layers = [
    'helm_t0',
    'chest_t0',
    'legs_t0',
    'shoulder_t0',
    'cloak_t0',
    'hands_t0',
  ];
  const cellW = 132.0;
  const tagW = 120.0;
  final classes = HeroClassId.values;
  final mid = (classes.length + 1) ~/ 2;

  List<Widget> columnFor(List<HeroClassId> ids) {
    return [
      for (final classId in ids)
        _row([
          _classTag(
            HeroSpecs.classLabel(classId),
            _classLooks(classId).first.armor.name,
          ),
          for (final kit in _classLooks(classId)) _classCell(kit, layers),
        ]),
    ];
  }

  double widthOf(List<HeroClassId> ids) {
    var kits = 1;
    for (final classId in ids) {
      final n = _classLooks(classId).length;
      if (n > kits) kits = n;
    }
    return tagW + kits * cellW;
  }

  final left = classes.sublist(0, mid);
  final right = classes.sublist(mid);
  final leftW = widthOf(left);
  final rightW = widthOf(right);
  return _saveSheet(
    tester,
    '$outDir/fit_classes.png',
    _column([
      _caption('CLASSES  armor and the weapon that spec starts with'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: leftW, child: Column(children: columnFor(left))),
          SizedBox(width: rightW, child: Column(children: columnFor(right))),
        ],
      ),
    ]),
    Size(leftW + rightW + 8, mid * 156 + 44),
  );
}

/// Same dressed body, one weapon at a time, so hands can be compared.
///
/// Rows are warrior, healer, mage, rogue.
/// Columns: sword, dagger, staff, bow, wand, gun, polearm, shield, frill.
Future<void> _saveWeaponCompare(
  WidgetTester tester,
  String outDir,
  Map<String, dynamic> outfits,
) {
  final dress = (outfits['dress'] as List).cast<String>();
  final weapons = (outfits['weapons'] as List).cast<String>();
  final families = (outfits['families'] as List).cast<String>();
  return _saveSheet(
    tester,
    '$outDir/fit_weapons.png',
    _column([
      _caption('DRESSED  sword dagger staff bow wand gun polearm shield frill'),
      for (final name in families)
        _row([
          for (final id in weapons)
            _mixCell(_family(name), id, [...dress, id]),
        ]),
    ]),
    Size(weapons.length * 124 + 24, families.length * 150 + 48),
  );
}

BodyFamily _family(String name) =>
    BodyFamily.values.firstWhere((family) => family.name == name);

/// Heaviest armor the class wears. Hunters start in leather and take mail
/// at 40, so the sheet shows the mail they grow into.
ArmorType _classArmor(HeroSpecDef spec) {
  final level = spec.classId == HeroClassId.hunter ? 40 : 1;
  return ClassProficiency.preferredArmor(spec, level)!;
}

/// Starter weapon from `StarterGear._weaponLoadout`, as lookbook art.
({
  String weaponId,
  WeaponHanded handed,
  String? offId,
  bool offIsWeapon,
  String blurb,
})
_starterLook(HeroSpecId id) {
  const sword2 = (
    weaponId: 'sword_t0',
    handed: WeaponHanded.twoHand,
    offId: null,
    offIsWeapon: false,
    blurb: '2H sword',
  );
  const axes = (
    weaponId: 'axe_t0',
    handed: WeaponHanded.oneHand,
    offId: 'axe_t0',
    offIsWeapon: true,
    blurb: 'two axes',
  );
  const maceShield = (
    weaponId: 'mace_t0',
    handed: WeaponHanded.oneHand,
    offId: 'shield_t0',
    offIsWeapon: false,
    blurb: 'mace and shield',
  );
  const daggers = (
    weaponId: 'dagger_t0',
    handed: WeaponHanded.oneHand,
    offId: 'dagger_t0',
    offIsWeapon: true,
    blurb: 'two daggers',
  );
  const maceBook = (
    weaponId: 'mace_t0',
    handed: WeaponHanded.oneHand,
    offId: 'frill_t0',
    offIsWeapon: false,
    blurb: 'mace and book',
  );
  const staff = (
    weaponId: 'staff_t0',
    handed: WeaponHanded.twoHand,
    offId: null,
    offIsWeapon: false,
    blurb: 'staff',
  );
  const mace2 = (
    weaponId: 'mace_t0',
    handed: WeaponHanded.twoHand,
    offId: null,
    offIsWeapon: false,
    blurb: '2H mace',
  );
  const pole = (
    weaponId: 'polearm_t0',
    handed: WeaponHanded.twoHand,
    offId: null,
    offIsWeapon: false,
    blurb: 'polearm',
  );
  const bow = (
    weaponId: 'bow_t0',
    handed: WeaponHanded.twoHand,
    offId: null,
    offIsWeapon: false,
    blurb: 'bow',
  );
  return switch (id) {
    HeroSpecId.protection ||
    HeroSpecId.holyPaladin ||
    HeroSpecId.protPaladin ||
    HeroSpecId.elemental ||
    HeroSpecId.restorationShaman => maceShield,
    HeroSpecId.arms || HeroSpecId.retribution || HeroSpecId.unholy => sword2,
    HeroSpecId.fury || HeroSpecId.frostDk || HeroSpecId.enhancement => axes,
    HeroSpecId.beastMastery ||
    HeroSpecId.marksmanship ||
    HeroSpecId.survival => bow,
    HeroSpecId.assassination ||
    HeroSpecId.combat ||
    HeroSpecId.subtlety => daggers,
    HeroSpecId.discipline || HeroSpecId.holyPriest => maceBook,
    HeroSpecId.blood => mace2,
    HeroSpecId.feral || HeroSpecId.guardian => pole,
    _ => staff,
  };
}

List<_ClassLook> _classLooks(HeroClassId classId) {
  final specs = HeroSpecs.forClass(classId);
  final mixed =
      specs.map((id) => HeroSpecs.def(id).gearAffinity).toSet().length > 1;
  final grouped = <String, _ClassLook>{};
  for (final id in specs) {
    final spec = HeroSpecs.def(id);
    final look = _starterLook(id);
    final armor = _classArmor(spec);
    final key =
        '${spec.gearAffinity.name}|${armor.name}|${look.weaponId}|${look.handed.name}|${look.offId}|${look.offIsWeapon}';
    final name = spec.name.split(' ').first;
    final existing = grouped[key];
    if (existing == null) {
      grouped[key] = _ClassLook(
        specId: id,
        names: [name],
        armor: armor,
        weaponId: look.weaponId,
        handed: look.handed,
        offId: look.offId,
        offIsWeapon: look.offIsWeapon,
        blurb: mixed ? '${spec.gearAffinity.name} · ${look.blurb}' : look.blurb,
      );
    } else {
      existing.names.add(name);
    }
  }
  final kits = grouped.values.toList();
  final coverWholeClass = kits.length == 1 && kits.single.names.length == specs.length;
  if (coverWholeClass) kits.single.names.clear();
  return kits;
}

Widget _classTag(String name, String armor) {
  return SizedBox(
    width: 120,
    height: 140,
    child: Padding(
      padding: const EdgeInsets.only(left: 10, top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            style: const TextStyle(color: Color(0xFFF4E4C4), fontSize: 13),
          ),
          Text(
            armor,
            style: const TextStyle(color: Color(0xFFE6C36A), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

Widget _classCell(_ClassLook kit, List<String> layers) {
  final items = <EquipmentSlot, EquipmentItem>{};
  for (final id in layers) {
    final item = gearLookbookItem(id, kit.armor);
    items[item.slot] = item;
  }
  items[EquipmentSlot.weapon] = gearLookbookItem(
    kit.weaponId,
    null,
  ).copyWith(handed: kit.handed);
  final offId = kit.offId;
  if (offId != null) {
    items[EquipmentSlot.offHand] = gearLookbookItem(
      offId,
      null,
      asOffHand: kit.offIsWeapon,
    );
  }
  final hero = PartyHero.starting(
    name: kit.names.isEmpty ? 'Class' : kit.names.first,
    specId: kit.specId,
    id: 'class-${kit.specId.name}-${kit.weaponId}',
    equipped: items,
  );
  final title = kit.names.join(' · ');
  return SizedBox(
    width: 132,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: const TextStyle(color: Color(0xFFE6C36A), fontSize: 9),
        ),
        Text(
          kit.blurb,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: const TextStyle(color: Color(0xFFB7A48A), fontSize: 9),
        ),
        HeroDollSprite(hero: hero, size: 96, forcePaperDoll: true),
      ],
    ),
  );
}

class _ClassLook {
  _ClassLook({
    required this.specId,
    required this.names,
    required this.armor,
    required this.weaponId,
    required this.handed,
    required this.offId,
    required this.offIsWeapon,
    required this.blurb,
  });

  final HeroSpecId specId;
  final List<String> names;
  final ArmorType armor;
  final String weaponId;
  final WeaponHanded handed;
  final String? offId;
  final bool offIsWeapon;
  final String blurb;
}

Widget _mixCell(
  BodyFamily family,
  String label,
  List<String> visualSetIds, {
  String? offHandWeapon,
}) {
  final items = <EquipmentSlot, EquipmentItem>{};
  for (final id in visualSetIds) {
    final item = gearLookbookItem(id, null);
    items[item.slot] = item;
  }
  if (offHandWeapon != null) {
    final item = gearLookbookItem(offHandWeapon, null, asOffHand: true);
    items[item.slot] = item;
  }
  final hero = PartyHero.starting(
    name: 'Mix',
    specId: gearLookbookSpec(family),
    id: 'mix-${family.name}-$label',
    equipped: items,
  );
  return _frame(label, HeroDollSprite(hero: hero, size: 96));
}

Widget _kitCell(Map<String, dynamic> outfits, BodyFamily family) {
  final weapon =
      (outfits['familyWeapon'] as Map)[family.name] as String? ?? 'sword_t0';
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
      theme: ThemeData(fontFamily: _font),
      home: Scaffold(
        backgroundColor: const Color(0xFF16141C),
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: sheet),
        ),
      ),
    ),
  );
  // Pump so each decode step can finish, and let real IO run between
  // pumps. A warm cache usually needs one pass, not a fixed half-second.
  final sw = Stopwatch()..start();
  while (HeroDollSprite.pendingLoads > 0 && sw.elapsedMilliseconds < 2000) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 16)),
    );
  }
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

Map<String, dynamic> _outfits() =>
    jsonDecode(File('tool/lookbook_outfits.json').readAsStringSync())
        as Map<String, dynamic>;

String _scope() {
  final file = File('tool/out/lookbook/scope.txt');
  if (!file.existsSync()) return 'summary';
  final parts = file.readAsStringSync().trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? 'summary' : parts.first;
}

String? _scopeFamily() {
  final file = File('tool/out/lookbook/scope.txt');
  if (!file.existsSync()) return null;
  final parts = file.readAsStringSync().trim().split(RegExp(r'\s+'));
  if (parts.length < 2 || parts.first != 'body') return null;
  return parts[1];
}

bool _wantsSheet(String scope, String group) {
  if (scope == 'all' || scope == 'body') return true;
  if (scope == 'armor') return group == 'armor' || group == 'snap';
  return false;
}

Future<void> _precache() async {
  final paths = <String>{
    for (final family in BodyFamily.values)
      BodyFamilyCatalog.defFor(family).idleAsset,
    for (final look in BodyFamilyCatalog.authoredRaceLooks)
      'assets/custom/char/${look.family.name}/'
          '${look.race.assetKey}_${look.sex.assetKey}_body_idle.png',
    for (final path in OwnedGearAssets.allAssetPaths)
      if (path.endsWith('_idle.png') || path.endsWith('_dye.png')) path,
  };
  await Future.wait(paths.map((path) async {
    try {
      await DecodedImageCache.load(path, targetWidth: 128);
    } catch (_) {
      // A missing optional dye must not blank the whole sheet.
    }
  }));
}
