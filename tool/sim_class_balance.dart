import 'dart:io';
import 'dart:math';

import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero_spec.dart';

import 'sim_harness.dart';

/// Class-kit balance sweeps over SpatialCombat.
///
/// Prefer Flutter test runner (imports Flutter via game code):
/// ```
/// flutter test test/class_balance_sim_test.dart --reporter expanded
/// ```
/// Quick: pass `--dart-define=QUICK=1` or edit args in the test.
///
/// Direct (may fail outside Flutter embedder on some SDKs):
/// ```
/// dart run tool/sim_class_balance.dart --quick
/// ```
void main(List<String> args) {
  runClassBalanceSim(args);
}

String runClassBalanceSim(List<String> args) {
  final trials = _argInt(args, 'trials', 20);
  final bandFilter = _argString(args, 'band');
  final quick = args.contains('--quick');
  final partyLevel = _argInt(args, 'level', 12);
  final dungeonId = _argString(args, 'dungeon') ?? 'sandy';

  seedEquipmentRng(42);

  final bands = quick
      ? <String>['light']
      : (bandFilter != null
          ? <String>[bandFilter]
          : <String>['fresh', 'light', 'mid']);
  // Mid focuses on clear-rate gates (F5 + boss). Fresh/light keep F1+F5.
  final floors = quick
      ? <int>[5]
      : (bands.length == 1 && bands.first == 'mid')
          ? <int>[5]
          : <int>[1, 5];

  final buf = StringBuffer();
  void log(String line) {
    // ignore: avoid_print
    print(line);
    buf.writeln(line);
  }

  log('# Class balance simulation');
  log('');
  log('- trials: $trials');
  log('- party level: $partyLevel');
  log('- bands: ${bands.join(', ')}');
  log('- dungeon: $dungeonId');
  log('- quick: $quick');
  log('');

  final dpsSpecs = HeroSpecId.values
      .where((id) {
        final t = HeroSpecs.def(id).roleTag;
        return t == SpecRoleTag.meleeDps ||
            t == SpecRoleTag.rangedDps ||
            t == SpecRoleTag.caster;
      })
      .toList();
  final tankSpecs =
      HeroSpecId.values.where((id) => HeroSpecs.def(id).isTank).toList();
  final healerSpecs =
      HeroSpecId.values.where((id) => HeroSpecs.def(id).isHealer).toList();

  final dpsAnchors = <(String, HeroSpecId, HeroSpecId)>[
    ('Prot+Disc', HeroSpecId.protection, HeroSpecId.discipline),
    if (!quick)
      ('ProtPala+Holy', HeroSpecId.protPaladin, HeroSpecId.holyPaladin),
  ];

  for (final band in bands) {
    for (final anchor in dpsAnchors) {
      final floorList = <int>{
        ...floors,
        if (!quick)
          GameLogic.bossFloorFor(
            createPartyState(
              partySpecs: [anchor.$2, anchor.$3, dpsSpecs.first],
            ),
          ),
      };
      for (final floor in floorList) {
        log('## DPS · $band · ${anchor.$1} · F$floor');
        log('');
        final rows = <_AggRow>[];
        for (final dps in dpsSpecs) {
          rows.add(
            _runAgg(
              label: dps.name,
              focusSpec: dps,
              partySpecs: [anchor.$2, anchor.$3, dps],
              band: band,
              dungeonId: dungeonId,
              floor: floor,
              partyLevel: partyLevel,
              trials: trials,
            ),
          );
        }
        _printDpsTable(log, rows);
        if (floor == 5 &&
            anchor.$1 == 'Prot+Disc' &&
            (band == 'light' || band == 'mid')) {
          _flagDpsOutliers(log, rows);
          _flagClearPctOutliers(log, rows);
        }
        if (band == 'light' && floor == 1 && anchor.$1 == 'Prot+Disc') {
          _flagClearTimeOutliers(log, rows);
        }
        log('');
      }
    }
  }

  if (!quick) {
    for (final band in bands.where((b) => b == 'light' || b == 'mid')) {
      const floor = 5;
      log('## Tank · $band · Disc+Fire · F$floor');
      log('');
      final rows = <_AggRow>[];
      for (final tank in tankSpecs) {
        rows.add(
          _runAgg(
            label: tank.name,
            focusSpec: tank,
            partySpecs: [tank, HeroSpecId.discipline, HeroSpecId.fire],
            band: band,
            dungeonId: dungeonId,
            floor: floor,
            partyLevel: partyLevel,
            trials: trials,
          ),
        );
      }
      _printTankTable(log, rows);
      if (band == 'light' || band == 'mid') {
        _flagTankOutliers(log, rows);
      }
      log('');
    }

    for (final band in bands.where((b) => b == 'light' || b == 'mid')) {
      const floor = 5;
      log('## Healer · $band · Prot+Fire · F$floor');
      log('');
      final rows = <_AggRow>[];
      for (final heal in healerSpecs) {
        rows.add(
          _runAgg(
            label: heal.name,
            focusSpec: heal,
            partySpecs: [HeroSpecId.protection, heal, HeroSpecId.fire],
            band: band,
            dungeonId: dungeonId,
            floor: floor,
            partyLevel: partyLevel,
            trials: trials,
          ),
        );
      }
      _printHealerTable(log, rows);
      if (band == 'light' || band == 'mid') {
        _flagHealerOutliers(log, rows);
      }
      log('');
    }
  }

  final outDir = Directory('tool/out');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  final outFile = File('tool/out/class_balance_latest.md');
  outFile.writeAsStringSync(buf.toString());
  log('Wrote ${outFile.path}');
  return buf.toString();
}

class _AggRow {
  _AggRow({
    required this.label,
    required this.clearPct,
    required this.wipePct,
    required this.timeoutPct,
    required this.clearTimeMedian,
    required this.clearTimeP25,
    required this.clearTimeP75,
    required this.hpMedian,
    required this.shareMedian,
    required this.dpsMedian,
    required this.focusHpMedian,
  });

  final String label;
  final double clearPct;
  final double wipePct;
  final double timeoutPct;
  final double clearTimeMedian;
  final double clearTimeP25;
  final double clearTimeP75;
  final double hpMedian;
  final double shareMedian;
  final double dpsMedian;
  final double focusHpMedian;
}

_AggRow _runAgg({
  required String label,
  required HeroSpecId focusSpec,
  required List<HeroSpecId> partySpecs,
  required String band,
  required String dungeonId,
  required int floor,
  required int partyLevel,
  required int trials,
}) {
  var clears = 0;
  var wipes = 0;
  var timeouts = 0;
  final clearTimes = <double>[];
  final hpOnClear = <double>[];
  final shares = <double>[];
  final dpsVals = <double>[];
  final focusHp = <double>[];

  for (var t = 0; t < trials; t++) {
    seedEquipmentRng(42 + t);
    var state = createPartyState(partySpecs: partySpecs);
    state = applyPowerBand(state, band);
    state = levelPartyTo(state, partyLevel);
    state = enterFloor(
      state,
      dungeonId: dungeonId,
      floor: floor,
      seed: 1000 + t * 97 + floor * 13 + focusSpec.index * 3,
    );
    final r = simulateFloor(state);
    if (r.cleared) {
      clears++;
      clearTimes.add(r.seconds);
      hpOnClear.add(r.hpPct);
    } else if (r.wiped) {
      wipes++;
    } else {
      timeouts++;
    }

    final focusDmg = r.damageBySpec[focusSpec] ?? 0;
    final totalDmg = r.damageBySpec.values.fold<int>(0, (a, b) => a + b);
    if (totalDmg > 0) {
      shares.add(100.0 * focusDmg / totalDmg);
    }
    final elapsed = max(0.01, r.combatElapsed);
    dpsVals.add(focusDmg / elapsed);
    focusHp.add(r.hpPctBySpec[focusSpec] ?? 0);
  }

  final timesSorted = [...clearTimes]..sort();
  return _AggRow(
    label: label,
    clearPct: clears / trials,
    wipePct: wipes / trials,
    timeoutPct: timeouts / trials,
    clearTimeMedian: medianOf(clearTimes),
    clearTimeP25: percentile(timesSorted, 0.25),
    clearTimeP75: percentile(timesSorted, 0.75),
    hpMedian: medianOf(hpOnClear),
    shareMedian: medianOf(shares),
    dpsMedian: medianOf(dpsVals),
    focusHpMedian: medianOf(focusHp),
  );
}

void _printDpsTable(void Function(String) log, List<_AggRow> rows) {
  log('| spec | clear% | wipe% | t_med | t_p25 | t_p75 | hp% | share% | dps |');
  log('|---|---:|---:|---:|---:|---:|---:|---:|---:|');
  final sorted = [...rows]
    ..sort((a, b) => b.shareMedian.compareTo(a.shareMedian));
  for (final r in sorted) {
    log(
      '| ${r.label} | ${_pct(r.clearPct)} | ${_pct(r.wipePct)} | '
      '${r.clearTimeMedian.toStringAsFixed(1)} | '
      '${r.clearTimeP25.toStringAsFixed(1)} | '
      '${r.clearTimeP75.toStringAsFixed(1)} | '
      '${r.hpMedian.toStringAsFixed(0)} | '
      '${r.shareMedian.toStringAsFixed(1)} | '
      '${r.dpsMedian.toStringAsFixed(1)} |',
    );
  }
}

void _printTankTable(void Function(String) log, List<_AggRow> rows) {
  log('| tank | clear% | wipe% | t_med | partyHP% | tankHP% | dmgShare% |');
  log('|---|---:|---:|---:|---:|---:|---:|');
  for (final r in rows) {
    log(
      '| ${r.label} | ${_pct(r.clearPct)} | ${_pct(r.wipePct)} | '
      '${r.clearTimeMedian.toStringAsFixed(1)} | '
      '${r.hpMedian.toStringAsFixed(0)} | '
      '${r.focusHpMedian.toStringAsFixed(0)} | '
      '${r.shareMedian.toStringAsFixed(1)} |',
    );
  }
}

void _printHealerTable(void Function(String) log, List<_AggRow> rows) {
  log('| healer | clear% | wipe% | t_med | partyHP% |');
  log('|---|---:|---:|---:|---:|');
  for (final r in rows) {
    log(
      '| ${r.label} | ${_pct(r.clearPct)} | ${_pct(r.wipePct)} | '
      '${r.clearTimeMedian.toStringAsFixed(1)} | '
      '${r.hpMedian.toStringAsFixed(0)} |',
    );
  }
}

void _flagDpsOutliers(void Function(String) log, List<_AggRow> rows) {
  final shares = rows.map((r) => r.shareMedian).where((v) => v > 0).toList();
  if (shares.isEmpty) return;
  final med = medianOf(shares);
  final lo = med * 0.80;
  final hi = med * 1.20;
  log('');
  log('### Outliers (DPS share vs median ${med.toStringAsFixed(1)}%, band ±20%)');
  for (final r in rows) {
    if (r.shareMedian <= 0) continue;
    if (r.shareMedian > hi) {
      log('- **HIGH** ${r.label}: share ${r.shareMedian.toStringAsFixed(1)}%');
    } else if (r.shareMedian < lo) {
      log('- **LOW** ${r.label}: share ${r.shareMedian.toStringAsFixed(1)}%');
    }
  }
}

void _flagClearTimeOutliers(void Function(String) log, List<_AggRow> rows) {
  final times =
      rows.where((r) => r.clearPct >= 0.3).map((r) => r.clearTimeMedian).toList();
  if (times.isEmpty) return;
  final med = medianOf(times);
  final lo = med * 0.85;
  final hi = med * 1.15;
  log('');
  log(
    '### Outliers (clear time vs median ${med.toStringAsFixed(1)}s, band ±15%)',
  );
  for (final r in rows) {
    if (r.clearPct < 0.3) continue;
    if (r.clearTimeMedian < lo) {
      log(
        '- **FAST** ${r.label}: ${r.clearTimeMedian.toStringAsFixed(1)}s '
        '(strong)',
      );
    } else if (r.clearTimeMedian > hi) {
      log(
        '- **SLOW** ${r.label}: ${r.clearTimeMedian.toStringAsFixed(1)}s '
        '(weak)',
      );
    }
  }
}

void _flagClearPctOutliers(void Function(String) log, List<_AggRow> rows) {
  final clears = rows.map((r) => r.clearPct * 100).toList();
  if (clears.every((c) => c <= 0)) {
    log('');
    log('### Clear% gate: all wipe — use share outliers only');
    return;
  }
  final med = medianOf(clears);
  log('');
  log(
    '### Outliers (clear% vs median ${med.toStringAsFixed(0)}%, band ±15pp)',
  );
  for (final r in rows) {
    final c = r.clearPct * 100;
    if (c > med + 15) {
      log('- **HIGH CLEAR** ${r.label}: ${_pct(r.clearPct)}');
    } else if (c < med - 15) {
      log('- **LOW CLEAR** ${r.label}: ${_pct(r.clearPct)}');
    }
  }
}

void _flagTankOutliers(void Function(String) log, List<_AggRow> rows) {
  final wipeMed = medianOf(rows.map((r) => r.wipePct * 100).toList());
  final hpMed = medianOf(
    rows.where((r) => r.clearPct > 0).map((r) => r.hpMedian).toList(),
  );
  log('');
  log(
    '### Outliers (tank wipe≤${(wipeMed + 15).toStringAsFixed(0)}pp; '
    'HP≥${(hpMed - 10).toStringAsFixed(0)}%)',
  );
  for (final r in rows) {
    if (r.wipePct * 100 > wipeMed + 15) {
      log('- **HIGH WIPE** ${r.label}: ${_pct(r.wipePct)}');
    }
    if (r.clearPct > 0 && r.hpMedian < hpMed - 10) {
      log('- **LOW HP** ${r.label}: ${r.hpMedian.toStringAsFixed(0)}%');
    }
  }
}

void _flagHealerOutliers(void Function(String) log, List<_AggRow> rows) {
  final clearMed = medianOf(rows.map((r) => r.clearPct * 100).toList());
  final hpMed = medianOf(
    rows.where((r) => r.clearPct > 0).map((r) => r.hpMedian).toList(),
  );
  log('');
  log(
    '### Outliers (healer clear≥${(clearMed - 10).toStringAsFixed(0)}%; '
    'HP≥${(hpMed - 10).toStringAsFixed(0)}%)',
  );
  for (final r in rows) {
    if (r.clearPct * 100 < clearMed - 10) {
      log('- **LOW CLEAR** ${r.label}: ${_pct(r.clearPct)}');
    }
    if (r.clearPct > 0 && r.hpMedian < hpMed - 10) {
      log('- **LOW HP** ${r.label}: ${r.hpMedian.toStringAsFixed(0)}%');
    }
  }
}

String _pct(double f) => '${(f * 100).toStringAsFixed(0)}%';

int _argInt(List<String> args, String name, int fallback) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) {
      return int.tryParse(a.substring(prefix.length)) ?? fallback;
    }
  }
  return fallback;
}

String? _argString(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}
