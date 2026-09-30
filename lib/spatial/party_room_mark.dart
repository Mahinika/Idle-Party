import '../models/hero_spec.dart';
import 'prop_vignettes.dart';
import 'tile_map.dart';

/// What the party leaves in the first room of a floor.
enum PartyRoomMark { breach, shrine, focus, stash }

/// One hero's trace for this floor. The walk stays the same size.
class PartyFloorMark {
  const PartyFloorMark({required this.kind, required this.line});

  final PartyRoomMark kind;
  final String line;

  /// Cycles the active party so each floor shows a different person.
  static PartyFloorMark? pick({
    required List<HeroSpecDef> specs,
    required List<String> names,
    required int floorNumber,
  }) {
    if (specs.isEmpty) return null;
    final n = floorNumber < 1 ? 0 : floorNumber - 1;
    final i = n % specs.length;
    final spec = specs[i];
    final raw = i < names.length ? names[i].trim() : '';
    final name = raw.isEmpty ? 'Someone' : raw;
    final kind = forSpec(spec);
    return PartyFloorMark(kind: kind, line: _line(kind, name));
  }

  static PartyRoomMark forSpec(HeroSpecDef spec) {
    if (spec.isHealer) return PartyRoomMark.shrine;
    if (spec.isTank) return PartyRoomMark.breach;
    return switch (spec.classId) {
      HeroClassId.rogue ||
      HeroClassId.hunter ||
      HeroClassId.druid => PartyRoomMark.stash,
      HeroClassId.mage ||
      HeroClassId.warlock ||
      HeroClassId.priest ||
      HeroClassId.shaman => PartyRoomMark.focus,
      HeroClassId.warrior ||
      HeroClassId.paladin ||
      HeroClassId.deathKnight => PartyRoomMark.breach,
    };
  }

  static String _line(PartyRoomMark kind, String name) => switch (kind) {
    PartyRoomMark.breach => '$name smashed a way through.',
    PartyRoomMark.shrine => '$name found a shrine — look only.',
    PartyRoomMark.focus => '$name set a crystal.',
    PartyRoomMark.stash => '$name tucked a stash.',
  };

  static List<VignettePiece> pieces(PartyRoomMark kind) => switch (kind) {
    PartyRoomMark.breach => const [
      VignettePiece(0, 0, MapPropKind.rubble),
      VignettePiece(1, 0, MapPropKind.chains),
      VignettePiece(2, 0, MapPropKind.rubble),
    ],
    PartyRoomMark.shrine => const [
      VignettePiece(0, 0, MapPropKind.altar),
      VignettePiece(-1, 0, MapPropKind.torch),
      VignettePiece(1, 0, MapPropKind.torch),
    ],
    PartyRoomMark.focus => const [
      VignettePiece(0, 0, MapPropKind.crystalCluster),
      VignettePiece(1, 0, MapPropKind.bookshelf),
    ],
    PartyRoomMark.stash => const [
      VignettePiece(0, 0, MapPropKind.sacks),
      VignettePiece(1, 0, MapPropKind.crate),
      VignettePiece(2, 0, MapPropKind.barrel),
    ],
  };
}
