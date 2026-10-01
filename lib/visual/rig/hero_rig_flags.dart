import '../body_family.dart';

/// Families that paint through the cutout rig. Everyone else stays on the paper doll.
abstract final class HeroRigFlags {
  static const enabled = true;

  static const families = {
    BodyFamily.warrior,
    BodyFamily.rogue,
    BodyFamily.mage,
  };

  static bool use(BodyFamily? family) =>
      enabled && family != null && families.contains(family);
}
