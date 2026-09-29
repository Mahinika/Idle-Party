import 'room_silhouette.dart';

/// Visual mood for a whole floor (docs/FLOOR_BLUEPRINT.md). One per floor so
/// the rooms read as one place (coherence), chosen from zone weights.
enum FloorTheme {
  torchlit('Torchlit Halls', [FloorDecalKind.cracks], 0x00000000),
  flooded('Flooded Halls', [
    FloorDecalKind.puddle,
    FloorDecalKind.puddle,
    FloorDecalKind.moss,
  ], 0x10208CA0),
  collapsed('Collapsed Tunnels', [
    FloorDecalKind.cracks,
    FloorDecalKind.cracks,
    FloorDecalKind.ash,
  ], 0x0C000000),
  overgrown('Overgrown Hollows', [
    FloorDecalKind.moss,
    FloorDecalKind.moss,
    FloorDecalKind.roots,
  ], 0x0C308020),
  ritual('Ritual Chambers', [
    FloorDecalKind.cracks,
    FloorDecalKind.ash,
    FloorDecalKind.scorch,
  ], 0x0E6020A0),
  frozen('Frozen Halls', [
    FloorDecalKind.iceSheen,
    FloorDecalKind.iceSheen,
    FloorDecalKind.cracks,
  ], 0x1080D0F0),
  smoldering('Smoldering Deep', [
    FloorDecalKind.lavaCrack,
    FloorDecalKind.ash,
    FloorDecalKind.ash,
  ], 0x10D04010),
  bone('Bone Galleries', [
    FloorDecalKind.boneDust,
    FloorDecalKind.boneDust,
    FloorDecalKind.cracks,
  ], 0x0A405848),
  gilded('Gilded Halls', [
    FloorDecalKind.grate,
    FloorDecalKind.cracks,
  ], 0x0CC0A040),
  stormlit('Stormlit Ledges', [
    FloorDecalKind.scorch,
    FloorDecalKind.puddle,
    FloorDecalKind.cracks,
  ], 0x0E6048E0),
  webbed('Webbed Dens', [
    FloorDecalKind.cobweb,
    FloorDecalKind.cobweb,
    FloorDecalKind.ash,
  ], 0x0CD0B0E0),
  clockwork('Clockwork Halls', [
    FloorDecalKind.gearInlay,
    FloorDecalKind.grate,
    FloorDecalKind.grate,
  ], 0x0CD09020),
  drifted('Sand-Choked Halls', [
    FloorDecalKind.sandDrift,
    FloorDecalKind.sandDrift,
    FloorDecalKind.cracks,
  ], 0x0CE0A050),
  crystalline('Crystal Galleries', [
    FloorDecalKind.iceSheen,
    FloorDecalKind.cracks,
  ], 0x0E60A0F0);

  const FloorTheme(this.label, this.decals, this.tintArgb);

  /// Player-facing floor name (English, HUD place line).
  final String label;

  /// Weighted decal pool for clumped floor detail.
  final List<FloorDecalKind> decals;

  /// Very soft floor tint baked under the zone wash.
  final int tintArgb;
}

/// Walkable, purely visual floor detail (never blocks, never on gate/exit).
enum FloorDecalKind {
  cracks,
  moss,
  puddle,
  runeCircle,
  grate,
  lavaCrack,
  iceSheen,
  bridge,
  dais,
  roots,
  cobweb,
  sandDrift,
  gearInlay,
  ash,
  carpet,
  scorch,
  boneDust,
  coins,
  starlight,
}

class FloorDecal {
  const FloorDecal({
    required this.x,
    required this.y,
    required this.kind,
    this.w = 1,
    this.h = 1,
  });

  final int x;
  final int y;
  final FloorDecalKind kind;

  /// Multi-cell decals (rune circle, dais, starlight) span a rect.
  final int w;
  final int h;

  bool covers(int cx, int cy) =>
      cx >= x && cx < x + w && cy >= y && cy < y + h;
}

/// Slow ambient motes per zone (soft fascination; never competes with combat).
enum AmbientParticleKind { none, dust, snow, embers, spores, bubbles, sparks, moths, motes }

/// Rare pure-visual surprise rooms (about 1 floor in 12).
enum WonderKind { hoard, giantSkeleton, starfall, soulWell }

/// Composed prop groups (docs/FLOOR_BLUEPRINT.md, placement layer).
enum PropVignetteKind { camp, crypt, forge, storage, shrine, library, ruin }

/// Floor look knobs per zone — silhouettes, themes, vignettes, particles.
class ZoneFloorStyle {
  const ZoneFloorStyle({
    required this.silhouettes,
    required this.themes,
    required this.vignettes,
    required this.wonders,
    required this.particles,
    required this.setpieceDecal,
    required this.accentArgb,
    this.organicEdges = false,
  });

  /// Normal fight-room shapes (shrine / boss use symmetric shapes).
  final List<RoomSilhouette> silhouettes;

  /// Weighted floor themes (duplicates = more common).
  final List<FloorTheme> themes;

  /// Weighted vignette templates for approach / hub / elite rooms.
  final List<PropVignetteKind> vignettes;
  final List<WonderKind> wonders;
  final AmbientParticleKind particles;

  /// Floor detail under the zone's signature room.
  final FloorDecalKind setpieceDecal;

  /// Hero / setpiece light colour (ARGB).
  final int accentArgb;

  /// Natural caves get ±1 cell wall roughness; built halls stay straight.
  final bool organicEdges;

  static ZoneFloorStyle byId(String dungeonId) =>
      _byId[dungeonId] ?? _fallback;

  static const ZoneFloorStyle _fallback = ZoneFloorStyle(
    silhouettes: RoomSilhouette.values,
    themes: [FloorTheme.torchlit, FloorTheme.collapsed],
    vignettes: [PropVignetteKind.storage, PropVignetteKind.camp],
    wonders: [WonderKind.hoard],
    particles: AmbientParticleKind.dust,
    setpieceDecal: FloorDecalKind.cracks,
    accentArgb: 0xFFE0C080,
  );

  static const Map<String, ZoneFloorStyle> _byId = {
    'sandy': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.oval, RoomSilhouette.chamfer],
      themes: [FloorTheme.drifted, FloorTheme.drifted, FloorTheme.torchlit, FloorTheme.collapsed],
      vignettes: [PropVignetteKind.storage, PropVignetteKind.camp, PropVignetteKind.ruin],
      wonders: [WonderKind.hoard, WonderKind.giantSkeleton],
      particles: AmbientParticleKind.dust,
      setpieceDecal: FloorDecalKind.sandDrift,
      accentArgb: 0xFFF0B060,
      organicEdges: true,
    ),
    'goblin': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.blob, RoomSilhouette.el],
      themes: [FloorTheme.torchlit, FloorTheme.torchlit, FloorTheme.collapsed, FloorTheme.overgrown],
      vignettes: [PropVignetteKind.camp, PropVignetteKind.camp, PropVignetteKind.storage, PropVignetteKind.crypt],
      wonders: [WonderKind.hoard],
      particles: AmbientParticleKind.motes,
      setpieceDecal: FloorDecalKind.ash,
      accentArgb: 0xFF70D070,
      organicEdges: true,
    ),
    'king': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.rect, RoomSilhouette.plus],
      themes: [FloorTheme.gilded, FloorTheme.gilded, FloorTheme.torchlit],
      vignettes: [PropVignetteKind.library, PropVignetteKind.camp, PropVignetteKind.storage],
      wonders: [WonderKind.hoard, WonderKind.starfall],
      particles: AmbientParticleKind.dust,
      setpieceDecal: FloorDecalKind.carpet,
      accentArgb: 0xFFF0D070,
    ),
    'underworld': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.plus, RoomSilhouette.diamond],
      themes: [FloorTheme.ritual, FloorTheme.ritual, FloorTheme.collapsed],
      vignettes: [PropVignetteKind.shrine, PropVignetteKind.crypt, PropVignetteKind.ruin],
      wonders: [WonderKind.soulWell, WonderKind.starfall],
      particles: AmbientParticleKind.motes,
      setpieceDecal: FloorDecalKind.runeCircle,
      accentArgb: 0xFFB070F0,
    ),
    'dead': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.diamond, RoomSilhouette.blob],
      themes: [FloorTheme.bone, FloorTheme.bone, FloorTheme.collapsed, FloorTheme.ritual],
      vignettes: [PropVignetteKind.crypt, PropVignetteKind.crypt, PropVignetteKind.ruin],
      wonders: [WonderKind.giantSkeleton],
      particles: AmbientParticleKind.dust,
      setpieceDecal: FloorDecalKind.boneDust,
      accentArgb: 0xFF90C0A8,
      organicEdges: true,
    ),
    'hell': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.el, RoomSilhouette.blob],
      themes: [FloorTheme.smoldering, FloorTheme.smoldering, FloorTheme.ritual],
      vignettes: [PropVignetteKind.forge, PropVignetteKind.crypt, PropVignetteKind.ruin],
      wonders: [WonderKind.giantSkeleton, WonderKind.soulWell],
      particles: AmbientParticleKind.embers,
      setpieceDecal: FloorDecalKind.lavaCrack,
      accentArgb: 0xFFFF5030,
      organicEdges: true,
    ),
    'crystal': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.diamond, RoomSilhouette.plus],
      themes: [FloorTheme.crystalline, FloorTheme.crystalline, FloorTheme.torchlit],
      vignettes: [PropVignetteKind.ruin, PropVignetteKind.library, PropVignetteKind.shrine],
      wonders: [WonderKind.starfall],
      particles: AmbientParticleKind.motes,
      setpieceDecal: FloorDecalKind.iceSheen,
      accentArgb: 0xFF90D8FF,
    ),
    'tide': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.oval, RoomSilhouette.el],
      themes: [FloorTheme.flooded, FloorTheme.flooded, FloorTheme.overgrown],
      vignettes: [PropVignetteKind.storage, PropVignetteKind.ruin, PropVignetteKind.shrine],
      wonders: [WonderKind.hoard, WonderKind.soulWell],
      particles: AmbientParticleKind.bubbles,
      setpieceDecal: FloorDecalKind.puddle,
      accentArgb: 0xFF50E0C8,
      organicEdges: true,
    ),
    'ember': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.chamfer, RoomSilhouette.blob],
      themes: [FloorTheme.smoldering, FloorTheme.smoldering, FloorTheme.torchlit],
      vignettes: [PropVignetteKind.forge, PropVignetteKind.forge, PropVignetteKind.storage],
      wonders: [WonderKind.hoard],
      particles: AmbientParticleKind.embers,
      setpieceDecal: FloorDecalKind.ash,
      accentArgb: 0xFFFFB040,
    ),
    'grove': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.blob, RoomSilhouette.oval],
      themes: [FloorTheme.overgrown, FloorTheme.overgrown, FloorTheme.flooded],
      vignettes: [PropVignetteKind.camp, PropVignetteKind.ruin, PropVignetteKind.shrine],
      wonders: [WonderKind.starfall, WonderKind.giantSkeleton],
      particles: AmbientParticleKind.spores,
      setpieceDecal: FloorDecalKind.roots,
      accentArgb: 0xFF90E060,
      organicEdges: true,
    ),
    'storm': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.plus, RoomSilhouette.chamfer],
      themes: [FloorTheme.stormlit, FloorTheme.stormlit, FloorTheme.collapsed],
      vignettes: [PropVignetteKind.ruin, PropVignetteKind.forge],
      wonders: [WonderKind.starfall],
      particles: AmbientParticleKind.sparks,
      setpieceDecal: FloorDecalKind.scorch,
      accentArgb: 0xFFC0D8FF,
    ),
    'rime': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.oval, RoomSilhouette.diamond],
      themes: [FloorTheme.frozen, FloorTheme.frozen, FloorTheme.collapsed],
      vignettes: [PropVignetteKind.ruin, PropVignetteKind.shrine, PropVignetteKind.crypt],
      wonders: [WonderKind.starfall, WonderKind.giantSkeleton],
      particles: AmbientParticleKind.snow,
      setpieceDecal: FloorDecalKind.iceSheen,
      accentArgb: 0xFF90F0FF,
    ),
    'fen': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.el, RoomSilhouette.oval],
      themes: [FloorTheme.overgrown, FloorTheme.overgrown, FloorTheme.flooded],
      vignettes: [PropVignetteKind.camp, PropVignetteKind.crypt, PropVignetteKind.ruin],
      wonders: [WonderKind.giantSkeleton],
      particles: AmbientParticleKind.spores,
      setpieceDecal: FloorDecalKind.puddle,
      accentArgb: 0xFFD0E050,
      organicEdges: true,
    ),
    'brass': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.rect, RoomSilhouette.chamfer],
      themes: [FloorTheme.clockwork, FloorTheme.clockwork, FloorTheme.gilded],
      vignettes: [PropVignetteKind.forge, PropVignetteKind.storage, PropVignetteKind.library],
      wonders: [WonderKind.hoard],
      particles: AmbientParticleKind.sparks,
      setpieceDecal: FloorDecalKind.gearInlay,
      accentArgb: 0xFFF0C850,
    ),
    'veil': ZoneFloorStyle(
      silhouettes: [RoomSilhouette.el, RoomSilhouette.plus],
      themes: [FloorTheme.webbed, FloorTheme.webbed, FloorTheme.ritual],
      vignettes: [PropVignetteKind.crypt, PropVignetteKind.shrine, PropVignetteKind.library],
      wonders: [WonderKind.starfall],
      particles: AmbientParticleKind.moths,
      setpieceDecal: FloorDecalKind.cobweb,
      accentArgb: 0xFFF0D0FF,
      organicEdges: true,
    ),
  };
}
