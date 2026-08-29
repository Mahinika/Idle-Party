import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../spatial/spatial_combat.dart';

/// One glanceable party combat meter row (dps / hps / dtps).
class PartyMeterRow {
  const PartyMeterRow({
    required this.tag,
    required this.rate,
    required this.unit,
    required this.bar,
    required this.highlight,
  });

  final String tag;
  final int rate;
  final String unit;
  final double bar;
  final bool highlight;

  String get valueLabel => '${PartyMeter.compact(rate)} $unit';
}

/// Snapshot for the dungeon METER chip + panel.
class PartyMeterSnapshot {
  const PartyMeterSnapshot({
    required this.chipLabel,
    required this.rows,
  });

  /// Closed-chip text without the expand glyph (e.g. `12k dps` or `0 DPS`).
  final String chipLabel;
  final List<PartyMeterRow> rows;

  bool get isEmpty => rows.isEmpty;
}

/// Pure party-meter math (SpatialCombat counters → HUD rows).
class PartyMeter {
  PartyMeter._();

  static String compact(int n) {
    if (n >= 10000) return '${(n / 1000).round()}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static int perSecond(int total, double elapsed) {
    final t = elapsed < 0.5 ? 0.5 : elapsed;
    return (total / t).round();
  }

  static String heroTag(SpatialActor h) {
    final specId = h.heroSpecId;
    final raw = specId != null
        ? HeroSpecs.def(specId).shortLabel
        : switch (h.heroRole) {
            HeroRole.warrior => 'WAR',
            HeroRole.healer => 'HEAL',
            HeroRole.mage => 'MAGE',
            HeroRole.rogue => 'ROG',
            null => '---',
          };
    return switch (raw) {
      'COMBAT' => 'COM',
      _ => raw.length <= 6 ? raw : raw.substring(0, 6),
    };
  }

  static SpecRoleTag? roleTag(SpatialActor h) {
    final specId = h.heroSpecId;
    if (specId == null) return null;
    return HeroSpecs.def(specId).roleTag;
  }

  /// Build chip + panel rows from live spatial heroes.
  ///
  /// Bars normalize **within the same unit** (dps vs dps, hps vs hps).
  /// Tanks/healers also get a damage row when they dealt damage.
  static PartyMeterSnapshot fromHeroes(
    Iterable<SpatialActor> heroes, {
    required double elapsed,
  }) {
    final party = <SpatialActor>[
      for (final h in heroes)
        if (!h.isPet) h,
    ];

    final candidates = <({String tag, int rate, String unit, int sort})>[];
    for (final h in party) {
      final tag = heroTag(h);
      final role = roleTag(h);
      final dps = perSecond(h.damageDealt, elapsed);
      final hps = perSecond(h.healingDone, elapsed);
      final dtps = perSecond(h.damageTaken, elapsed);

      if (role == SpecRoleTag.tank) {
        if (dtps >= 1) {
          candidates.add((tag: tag, rate: dtps, unit: 'dtps', sort: 2));
        }
        if (dps >= 1) {
          candidates.add((tag: tag, rate: dps, unit: 'dps', sort: 0));
        }
      } else if (role == SpecRoleTag.healer) {
        if (hps >= 1) {
          candidates.add((tag: tag, rate: hps, unit: 'hps', sort: 1));
        }
        if (dps >= 1) {
          candidates.add((tag: tag, rate: dps, unit: 'dps', sort: 0));
        }
      } else {
        if (dps >= 1) {
          candidates.add((tag: tag, rate: dps, unit: 'dps', sort: 0));
        }
      }
    }

    if (candidates.isEmpty) {
      return const PartyMeterSnapshot(chipLabel: '0 DPS', rows: []);
    }

    candidates.sort((a, b) {
      final byUnit = a.sort.compareTo(b.sort);
      if (byUnit != 0) return byUnit;
      return b.rate.compareTo(a.rate);
    });

    final peakByUnit = <String, int>{};
    for (final c in candidates) {
      final prev = peakByUnit[c.unit] ?? 0;
      if (c.rate > prev) peakByUnit[c.unit] = c.rate;
    }

    final rows = <PartyMeterRow>[
      for (final c in candidates)
        PartyMeterRow(
          tag: c.tag,
          rate: c.rate,
          unit: c.unit,
          bar: c.rate / (peakByUnit[c.unit] ?? 1).clamp(1, 1 << 30),
          highlight: c.rate == (peakByUnit[c.unit] ?? 0),
        ),
    ];

    // Chip prefers party damage glance; fall back to heal / tank soak.
    final topDps = peakByUnit['dps'] ?? 0;
    final topHps = peakByUnit['hps'] ?? 0;
    final topDtps = peakByUnit['dtps'] ?? 0;
    final String chipLabel;
    if (topDps >= 1) {
      chipLabel = '${compact(topDps)} dps';
    } else if (topHps >= 1) {
      chipLabel = '${compact(topHps)} hps';
    } else {
      chipLabel = '${compact(topDtps)} dtps';
    }

    return PartyMeterSnapshot(chipLabel: chipLabel, rows: rows);
  }
}
