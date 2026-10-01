import '../body_family.dart';
import 'hero_rig_flags.dart';
import 'rig_data.dart';

/// Loaded family skeletons. Missing files leave that family on the paper doll.
abstract final class HeroRigLibrary {
  static final Map<BodyFamily, RigData> _rigs = {};
  static final Set<BodyFamily> _failed = {};

  static RigData? peek(BodyFamily family) => _rigs[family];

  static Future<void> load(BodyFamily family) async {
    if (_rigs.containsKey(family) || _failed.contains(family)) return;
    if (!HeroRigFlags.use(family)) return;
    try {
      _rigs[family] = await RigData.loadAsset(family.name);
    } catch (_) {
      _failed.add(family);
    }
  }

  static Future<void> loadEnabled() => Future.wait([
    for (final family in HeroRigFlags.families) load(family),
  ]);
}
