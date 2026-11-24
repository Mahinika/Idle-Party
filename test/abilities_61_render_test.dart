import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/theme.dart';
import 'package:idle_party/ui/spatial_dungeon_view.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';

import 'shell_golden_harness.dart';

// Keep in sync with test/abilities_61_test.dart
const _newIds = <AbilityId>[
  AbilityId.colossusSmash,
  AbilityId.dieByTheSword,
  AbilityId.armsCharge,
  AbilityId.executeFury,
  AbilityId.piercingHowl,
  AbilityId.lightOfDawn,
  AbilityId.hammerOfJusticeHoly,
  AbilityId.ardentDefender,
  AbilityId.wordOfGloryProt,
  AbilityId.consecrationRet,
  AbilityId.hammerOfJusticeRet,
  AbilityId.wordOfGloryRet,
  AbilityId.stampede,
  AbilityId.killShotBm,
  AbilityId.claw,
  AbilityId.killShotMm,
  AbilityId.bindingShot,
  AbilityId.wildfireBomb,
  AbilityId.harpoonSurvival,
  AbilityId.kidneyShotAssa,
  AbilityId.crimsonVial,
  AbilityId.adrenalineRush,
  AbilityId.revealingStrike,
  AbilityId.secretTechnique,
  AbilityId.powerWordBarrier,
  AbilityId.halo,
  AbilityId.shadowfiendDisc,
  AbilityId.holyFire,
  AbilityId.holyWordSanctify,
  AbilityId.prayerOfMendingHoly,
  AbilityId.shadowWordDeath,
  AbilityId.shadowfiendShadow,
  AbilityId.frozenOrb,
  AbilityId.breathOfSindragosa,
  AbilityId.empowerRuneWeapon,
  AbilityId.soulReaper,
  AbilityId.darkTransformation,
  AbilityId.fireElemental,
  AbilityId.crashLightning,
  AbilityId.healingSurge,
  AbilityId.healingTideTotem,
  AbilityId.earthbindTotem,
  AbilityId.manaTideTotem,
  AbilityId.arcaneBarrage,
  AbilityId.prismaticBarrier,
  AbilityId.evocation,
  AbilityId.meteor,
  AbilityId.iceBarrierFrost,
  AbilityId.frostMageConeOfCold,
  AbilityId.darkSoul,
  AbilityId.howlOfTerror,
  AbilityId.callDreadstalkers,
  AbilityId.soulFireDemo,
  AbilityId.summonInfernal,
  AbilityId.shadowburn,
  AbilityId.starsurge,
  AbilityId.forceOfNature,
  AbilityId.maim,
  AbilityId.ironbark,
  AbilityId.innervateDruid,
  AbilityId.entanglingRoots,
];

const _compareSix = <({AbilityId id, Rect v3Sample})>[
  (id: AbilityId.meteor, v3Sample: Rect.fromLTWH(96, 520, 128, 128)),
  (id: AbilityId.holyFire, v3Sample: Rect.fromLTWH(96, 920, 128, 128)),
  (id: AbilityId.arcaneBarrage, v3Sample: Rect.fromLTWH(96, 1320, 128, 128)),
  (id: AbilityId.frozenOrb, v3Sample: Rect.fromLTWH(96, 1720, 128, 128)),
  (id: AbilityId.powerWordBarrier, v3Sample: Rect.fromLTWH(96, 2120, 128, 128)),
  (id: AbilityId.summonInfernal, v3Sample: Rect.fromLTWH(96, 2520, 128, 128)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  test('61 abilities contact sheet uses SpellShapePaint', () async {
    expect(_newIds.length, 61);
    const tileW = 184.0;
    const tileH = 196.0;
    const cols = 7;
    final rows = (_newIds.length / cols).ceil();
    final w = (tileW * cols).round();
    final h = (tileH * rows + 24).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintDungeonBackdrop(canvas, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    final labelStyle = GameTheme.body(size: 11, color: const Color(0xFFE8D8C8));

    for (var i = 0; i < _newIds.length; i++) {
      final id = _newIds[i];
      final def = ClassKits.defFor(id)!;
      final col = i % cols;
      final row = i ~/ cols;
      final rect = Rect.fromLTWH(
        col * tileW + 6,
        row * tileH + 8,
        tileW - 12,
        tileH - 36,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(6)),
        Paint()..color = const Color(0xFF231A28),
      );
      SpellShapePaint.paintAbilityShowcase(canvas, tileRect: rect, def: def);
      final tp = TextPainter(
        text: TextSpan(text: def.name, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: tileW - 8);
      tp.paint(canvas, Offset(col * tileW + 4, row * tileH + tileH - 30));
    }

    final bytes = await _pngFromRecorder(recorder, w, h);
    expect(bytes.lengthInBytes, greaterThan(12000));

    if (Platform.environment['RENDER_ABILITIES_61'] == '1') {
      final dir = Directory('docs/design/abilities-61/rendered');
      dir.createSync(recursive: true);
      File('${dir.path}/contact_sheet_61.png').writeAsBytesSync(bytes);
    }
  });

  test('v3 reference vs in-game for 6 key spells', () async {
    const rowH = 196.0;
    const w = 420;
    final h = (_compareSix.length * rowH).round();
  final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF100C14));

    ui.Image? ref;
    final refPath = 'docs/design/abilities-61/sheet_v3.png';
    if (await File(refPath).exists()) {
      final codec = await ui.instantiateImageCodec(await File(refPath).readAsBytes());
      ref = (await codec.getNextFrame()).image;
    }

    for (var i = 0; i < _compareSix.length; i++) {
      final row = _compareSix[i];
      final y = i * rowH;
      canvas.drawRect(Rect.fromLTWH(0, y, w.toDouble(), rowH), Paint()..color = const Color(0xFF1A1420));
      if (ref != null) {
        canvas.drawImageRect(
          ref,
          row.v3Sample,
          Rect.fromLTWH(12, y + 18, 160, 160),
          Paint(),
        );
      }
      final def = ClassKits.defFor(row.id)!;
      SpellShapePaint.paintAbilityShowcase(
        canvas,
        tileRect: Rect.fromLTWH(220, y + 18, 160, 160),
        def: def,
      );
      final tp = TextPainter(
        text: TextSpan(text: def.name, style: GameTheme.body(size: 11)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 16);
      tp.paint(canvas, Offset(12, y + rowH - 22));
    }

    final bytes = await _pngFromRecorder(recorder, w, h);
    expect(bytes.lengthInBytes, greaterThan(8000));
    if (Platform.environment['RENDER_ABILITIES_61'] == '1') {
      File('docs/design/abilities-61/rendered/compare_v3_vs_game_6.png').writeAsBytesSync(bytes);
    }
  });

  const scenes = <({String file, List<AbilityId> picks})>[
    (
      file: 'fight_mage_elemental.png',
      picks: [
        AbilityId.meteor,
        AbilityId.arcaneBarrage,
        AbilityId.frozenOrb,
        AbilityId.fireElemental,
      ],
    ),
    (
      file: 'fight_hunter_holy.png',
      picks: [
        AbilityId.stampede,
        AbilityId.killShotMm,
        AbilityId.bindingShot,
        AbilityId.holyFire,
      ],
    ),
    (
      file: 'fight_mixed_endgame.png',
      picks: [
        AbilityId.crashLightning,
        AbilityId.summonInfernal,
        AbilityId.entanglingRoots,
        AbilityId.starsurge,
        AbilityId.secretTechnique,
      ],
    ),
    (
      file: 'fight_tank_support.png',
      picks: [
        AbilityId.dieByTheSword,
        AbilityId.powerWordBarrier,
        AbilityId.ironbark,
        AbilityId.shadowfiendDisc,
      ],
    ),
  ];

  for (final scene in scenes) {
    testWidgets('in-context ${scene.file}', (tester) async {
      debugHoldFloorBake();
      bindA56View(tester);
      final director = await fightHitGoldenDirector(vfx: VfxQuality.full);
      var directorLive = true;
      addTearDown(() {
        if (directorLive) director.dispose();
      });
      _stageAbilities61Vfx(director, scene.picks);
      final key = GlobalKey();
      await tester.pumpWidget(
        shellGoldenScaffold(
          RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 360,
              height: 620,
              child: SpatialDungeonView(director: director),
            ),
          ),
        ),
      );
      await _waitForFightRender(tester, director);
      director.setUiPaused(true);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);

      if (Platform.environment['RENDER_ABILITIES_61'] == '1') {
        final bytes = await _capturePng(tester, key);
        final dir = Directory('docs/design/abilities-61/rendered');
        dir.createSync(recursive: true);
        File('${dir.path}/${scene.file}').writeAsBytesSync(bytes);
      }

      directorLive = false;
      director.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

void _stageAbilities61Vfx(GameDirector director, List<AbilityId> ids) {
  final world = director.spatial;
  if (world == null) return;
  world.reducedVfx = false;
  world.spawnPersistentVfx = true;
  final foes = world.enemies.where((e) => e.hp > 0).toList();
  if (foes.isEmpty) return;
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    final def = ClassKits.defFor(id)!;
    final foe = foes[i % foes.length];
    final style = def.boltStyle ?? SpellBoltStyle.weapon;
    final x = foe.x + (i % 3 - 1) * 0.55;
    final y = foe.y + (i ~/ 3) * 0.35;
    SpellVfx.spawnImpact(
      world,
      x: x,
      y: y,
      style: style,
      id: id,
      shape: def.aoeShape,
      radius: SpellVfx.isBig(id) ? 0.95 : 0.72,
    );
    if (def.vfx?.groundDisc == true) {
      final gkind = SpellVfx.groundKindFor(style: style, id: id);
      SpatialCombat.spawnGroundFx(
        world,
        x: x,
        y: y + 0.35,
        argb: def.vfx?.groundArgb ?? SpatialCombat.burstArgbForStyle(style),
        radius: 1.4,
        life: 4.2,
        kind: gkind,
      );
    }
    final hero = world.heroes.firstWhere((h) => !h.isPet && h.hp > 0);
    if (def.effect == AbilityEffectKind.damage || def.effect == AbilityEffectKind.aoe) {
      SpatialCombat.addProjectile(
        world,
        SpatialCombat.spellBolt(
          from: hero,
          to: foe,
          damage: 12,
          style: style,
          label: def.shortLabel,
        )..delay = 0,
      );
    }
    if (world.bursts.isNotEmpty) {
      world.bursts.last.life = 0.32;
    }
  }
}

Future<Uint8List> _capturePng(WidgetTester tester, GlobalKey key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final data = await image!.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void _paintDungeonBackdrop(Canvas canvas, Rect full) {
  canvas.drawRect(full, Paint()..color = const Color(0xFF141018));
  const step = 32.0;
  final grid = Paint()
    ..color = const Color(0xFF2A2030)
    ..strokeWidth = 1;
  for (var x = 0.0; x < full.width; x += step) {
    canvas.drawLine(Offset(x, 0), Offset(x, full.height), grid);
  }
  for (var y = 0.0; y < full.height; y += step) {
    canvas.drawLine(Offset(0, y), Offset(full.width, y), grid);
  }
}

Future<void> _waitForFightRender(WidgetTester tester, GameDirector director) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    if (director.dungeonTilesReady) break;
    expect(tester.takeException(), isNull);
  }
  await tester.pump(const Duration(milliseconds: 320));
}

Future<Uint8List> _pngFromRecorder(ui.PictureRecorder recorder, int w, int h) async {
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}