import 'dart:math' as math;
import 'dart:ui';

/// Sprite pixel sizes from `tool/generate_town_art.py`.
abstract final class TownSpriteSize {
  static const forge = Size(120, 156);
  static const market = Size(120, 140);
  static const inn = Size(120, 160);
  static const guild = Size(156, 176);
  static const vault = Size(88, 104);
  static const well = Size(56, 68);
}

/// One planting. Each uses its own sprite so the yard is not six copies.
class TownPlanting {
  const TownPlanting(this.rect, this.asset);

  final Rect rect;
  final String asset;
}

/// Packed town square. Hit boxes do not overlap. Name chips sit on the
/// facades. The yard between the rows is the walking lane.
class TownSceneLayout {
  const TownSceneLayout({
    required this.guild,
    required this.vault,
    required this.well,
    required this.front,
    required this.party,
    required this.guildLabel,
    required this.vaultLabel,
    required this.frontLabels,
    required this.lane,
    required this.folkScale,
    required this.courtyardPath,
    required this.doorPath,
    required this.streets,
    required this.approaches,
    required this.trees,
    required this.plantings,
    required this.thresholds,
    required this.contacts,
    required this.grassTop,
  });

  final Rect guild;
  final Rect vault;
  final Rect well;
  final List<Rect> front;
  final Rect party;
  final Rect guildLabel;
  final Rect vaultLabel;
  final List<Rect> frontLabels;
  final Rect lane;
  final int folkScale;
  final Rect courtyardPath;
  final Rect doorPath;

  /// Cobble streets. Horizontal, painted from `path.png`.
  final List<Rect> streets;

  /// Cobble spurs that join the streets. Painted from `approach.png`.
  final List<Rect> approaches;

  final List<Rect> trees;
  final List<TownPlanting> plantings;

  /// Worn stone in front of each front door. Not a second full-width path.
  final List<Rect> thresholds;

  /// Dark grass under each structure, so the walls meet the ground.
  final List<Rect> contacts;

  /// Grass starts here. The backdrop shows above it.
  final double grassTop;

  List<Rect> get hitTargets => [guild, vault, ...front];

  List<Rect> get labels => [guildLabel, vaultLabel, ...frontLabels];

  static TownSceneLayout pack(Size size, {double textScale = 1}) {
    final w = size.width;
    final h = size.height;
    final labelH = math.min(14 * textScale + 6, 40).toDouble();
    final partyH = h < 380 ? 46.0 : 54.0;
    final skyMin = h < 380 ? 16.0 : 28.0;
    final skyCap = h < 380 ? 56.0 : 84.0;
    // A yard tall enough for one row of townsfolk when the square allows it.
    final minYard = h >= 420 ? 58.0 : (h >= 320 ? 28.0 : 0.0);

    var frontW = math.min(108.0, (w - 32) / 3);
    var guildW = math.min(136.0, w * 0.38);
    if (frontW < 8) frontW = 8;
    if (guildW < 8) guildW = 8;
    final fullInn =
        frontW * TownSpriteSize.inn.height / TownSpriteSize.inn.width;
    final fullGuild =
        guildW * TownSpriteSize.guild.height / TownSpriteSize.guild.width;
    final room = math.max(40.0, h - partyH - skyMin - minYard);
    final scale = math.min(1.0, room / (fullInn + fullGuild));
    var yard = minYard;
    final skyRoom = h - partyH - (fullInn + fullGuild) * scale - yard;
    final sky = skyRoom.clamp(0.0, skyCap);
    yard += math.max(0.0, skyRoom - sky);

    final fw = frontW * scale;
    final forgeH =
        fw * TownSpriteSize.forge.height / TownSpriteSize.forge.width;
    final marketH =
        fw * TownSpriteSize.market.height / TownSpriteSize.market.width;
    final innHeight = fw * TownSpriteSize.inn.height / TownSpriteSize.inn.width;
    final gh =
        guildW *
        scale *
        TownSpriteSize.guild.height /
        TownSpriteSize.guild.width;
    final gw = guildW * scale;

    final partyTop = math.max(0.0, h - partyH);
    final party = Rect.fromLTWH(
      8,
      partyTop,
      math.max(0, w - 16),
      math.min(partyH, h),
    );
    final frontBottom = partyTop;
    const gap = 8.0;
    final total = fw * 3 + gap * 2;
    final start = (w - total) / 2;
    Rect frontAt(int i, double height) =>
        Rect.fromLTWH(start + i * (fw + gap), frontBottom - height, fw, height);
    final front = [
      frontAt(0, forgeH),
      frontAt(1, marketH),
      frontAt(2, innHeight),
    ];
    final frontTop = front.map((r) => r.top).reduce(math.min);

    final backBottom = frontTop - yard;
    final guild = Rect.fromLTWH(6, backBottom - gh, gw, gh);

    var vaultW = math.min(84.0, w * 0.24) * math.max(0.7, scale);
    var vaultH =
        vaultW * TownSpriteSize.vault.height / TownSpriteSize.vault.width;
    if (vaultH > gh) {
      vaultH = gh;
      vaultW =
          vaultH * TownSpriteSize.vault.width / TownSpriteSize.vault.height;
    }
    final vault = Rect.fromLTWH(
      w - 6 - vaultW,
      backBottom - vaultH,
      vaultW,
      vaultH,
    );

    var wellW = (h < 380 ? 34.0 : 44.0) * math.max(0.75, scale);
    var wellH = wellW * TownSpriteSize.well.height / TownSpriteSize.well.width;
    final gapW = vault.left - guild.right;
    if (wellW > gapW - 8) {
      wellW = math.max(24.0, gapW - 8);
      wellH = wellW * TownSpriteSize.well.height / TownSpriteSize.well.width;
    }
    final well = Rect.fromLTWH(
      (w - wellW) / 2,
      backBottom - wellH,
      wellW,
      wellH,
    );

    Rect labelOn(Rect b) {
      final base = math.min(math.max(28.0, b.width - 8), 88.0);
      final lw = math.min(b.width - 4, base * math.max(1.0, textScale));
      final lh = math.min(labelH, math.max(10.0, b.height - 4));
      final top = math.max(b.top, b.bottom - lh - 2);
      final height = math.min(lh, b.bottom - top);
      return Rect.fromLTWH(b.center.dx - lw / 2, top, lw, height);
    }

    final lane = Rect.fromLTRB(
      8,
      backBottom + 1,
      math.max(8, w - 8),
      frontTop - 1,
    );
    // 1 means "draw them" at the 48×56 yard size. A short yard shrinks them.
    var folkScale = 0;
    if (lane.width >= 48 && lane.height >= 16) {
      folkScale = 1;
    }

    final canopy = math.max(0.0, (backBottom - gh) - 48);
    // Two canopies, both fully on the phone. The left one used to start at x=-6.
    final trees = <Rect>[
      Rect.fromLTWH(0, canopy, 78, 102),
      // Pine sits a row lower so the crown clears the top bar.
      Rect.fromLTWH(w - 58, math.max(12.0, canopy + 20), 58, 96),
    ];

    final plantings = <TownPlanting>[
      TownPlanting(Rect.fromLTWH(0, backBottom - 36, 56, 44), 'flowers'),
      TownPlanting(Rect.fromLTWH(w - 56, backBottom - 40, 56, 44), 'shrub'),
    ];
    if (lane.height >= 40) {
      plantings.add(
        TownPlanting(Rect.fromLTWH(0, lane.bottom - 44, 52, 44), 'wild'),
      );
      plantings.add(
        TownPlanting(Rect.fromLTWH(w - 52, lane.bottom - 48, 52, 44), 'herbs'),
      );
      // One worn patch in the open lawn, off the cobbles.
      if (lane.height >= 96) {
        plantings.add(
          TownPlanting(Rect.fromLTWH(18, lane.top + 52, 72, 36), 'scuff'),
        );
      }
    }
    final streets = <Rect>[];
    final approaches = <Rect>[];
    final laneH = frontTop - backBottom;
    if (laneH < 88) {
      final pathH = math.min(36.0, math.max(12.0, laneH));
      streets.add(Rect.fromLTWH(0, frontTop - pathH, w, pathH));
    } else {
      // A street at the back doors, a street along the shop roofs,
      // and one spur that joins them. The lawn on either side stays open.
      streets.add(Rect.fromLTWH(8, backBottom - 4, math.max(0, w - 16), 36));
      streets.add(Rect.fromLTWH(0, frontTop - 36, w, 36));
      final spurTop = backBottom + 32;
      final spurBottom = frontTop - 36;
      approaches.add(
        Rect.fromLTWH(well.center.dx - 16, spurTop, 32, spurBottom - spurTop),
      );
    }
    final grass = math.max(0.0, backBottom - gh - 6);
    plantings.add(
      TownPlanting(Rect.fromLTWH(w * 0.34, grass + 2, 104, 52), 'meadow'),
    );
    final rightGap = vault.left - well.right - 12;
    if (rightGap >= 36) {
      plantings.add(
        TownPlanting(
          Rect.fromLTWH(
            well.right + 6,
            well.center.dy - 8,
            math.min(rightGap, 88),
            48,
          ),
          'thicket',
        ),
      );
    }
    // Hedge along the ridge. Spaced shrubs, not a wall.
    for (var x = 72.0; x < w - 70; x += 54) {
      plantings.add(TownPlanting(Rect.fromLTWH(x, grass - 6, 32, 26), 'shrub'));
    }
    // Clusters at the lawn edges and beside the spur. Not on the doors.
    plantings.add(TownPlanting(Rect.fromLTWH(4, grass + 16, 40, 32), 'flowers'));
    plantings.add(TownPlanting(Rect.fromLTWH(34, grass + 30, 34, 28), 'herbs'));
    plantings.add(TownPlanting(Rect.fromLTWH(w - 42, grass + 18, 38, 30), 'wild'));
    if (lane.height >= 70) {
      plantings.add(TownPlanting(Rect.fromLTWH(6, lane.top + 6, 40, 32), 'shrub'));
      plantings.add(TownPlanting(Rect.fromLTWH(w - 46, lane.top + 14, 40, 32), 'flowers'));
      if (approaches.isNotEmpty) {
        final spur = approaches.first;
        plantings.add(
          TownPlanting(Rect.fromLTWH(spur.left - 34, spur.top + 6, 30, 26), 'wild'),
        );
        plantings.add(
          TownPlanting(Rect.fromLTWH(spur.right + 4, spur.top + 16, 30, 26), 'herbs'),
        );
      }
    }
    if (rightGap >= 16) {
      plantings.add(
        TownPlanting(
          Rect.fromLTWH(
            well.right + 2,
            well.bottom - 26,
            math.min(34, rightGap + 6),
            28,
          ),
          'flowers',
        ),
      );
    }
    final thresholds = <Rect>[
      for (final building in front)
        Rect.fromLTWH(building.center.dx - 28, building.bottom + 1, 56, 22),
    ];
    List<Rect> feet(Rect body) {
      final y = body.bottom - 10;
      return [
        Rect.fromLTWH(body.left + body.width * 0.18, y, 26, 14),
        Rect.fromLTWH(body.right - body.width * 0.42, y + 1, 26, 14),
      ];
    }

    final contacts = <Rect>[
      ...feet(guild),
      ...feet(vault),
      ...feet(well),
      for (final building in front) ...feet(building),
    ];

    return TownSceneLayout(
      guild: guild,
      vault: vault,
      well: well,
      front: front,
      party: party,
      guildLabel: labelOn(guild),
      vaultLabel: labelOn(vault),
      frontLabels: front.map(labelOn).toList(),
      lane: lane,
      folkScale: folkScale,
      courtyardPath: Rect.fromLTRB(0, backBottom - 8, w, frontTop),
      streets: streets,
      approaches: approaches,
      doorPath: Rect.fromLTRB(
        0,
        frontBottom - 16,
        w,
        math.min(h, frontBottom + 10),
      ),
      trees: trees,
      plantings: plantings,
      thresholds: thresholds,
      contacts: contacts,
      grassTop: math.max(0, backBottom - gh - 6),
    );
  }
}
