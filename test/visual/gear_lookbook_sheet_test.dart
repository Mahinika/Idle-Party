@Tags(['lookbook'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/decoded_image_cache.dart';
import 'package:idle_party/ui/hero_doll_sprite.dart';
import 'package:idle_party/ui/shell/dev_gear_lookbook.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/equipment_model_catalog.dart';
import 'package:idle_party/visual/owned_gear_assets.dart';

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
    also: ['$outDir/fit_compare.png'],
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
  Size size, {
  List<String> also = const [],
}) async {
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
  final png = bytes!.buffer.asUint8List();
  for (final target in [path, ...also]) {
    File(target).writeAsBytesSync(png);
  }
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
