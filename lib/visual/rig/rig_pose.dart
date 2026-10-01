import 'dart:math' as math;

import 'rig_data.dart';

/// One posed skeleton. Angles are screen-clockwise degrees.
class RigPose {
  const RigPose({
    this.angles = const {},
    this.rootX = 0,
    this.rootY = 0,
  });

  final Map<String, double> angles;
  final double rootX;
  final double rootY;

  static const rest = RigPose();
}

/// World placement of one bone: position in source pixels, rotation in degrees.
class RigWorld {
  const RigWorld(this.x, this.y, this.deg);

  final double x;
  final double y;
  final double deg;
}

/// Same solve as the skeleton demo: child = parent + rotate_cw(rest delta).
abstract final class RigSolver {
  static Map<String, RigWorld> world(RigData rig, RigPose pose) {
    final out = <String, RigWorld>{};
    for (final name in rig.order) {
      final bone = rig.bones[name]!;
      final local = pose.angles[name] ?? 0;
      final parent = bone.parent;
      if (parent == null) {
        out[name] = RigWorld(bone.restX + pose.rootX, bone.restY + pose.rootY, local);
        continue;
      }
      final pw = out[parent]!;
      final pb = rig.bones[parent]!;
      final spun = _rotCw(bone.restX - pb.restX, bone.restY - pb.restY, pw.deg);
      out[name] = RigWorld(pw.x + spun.$1, pw.y + spun.$2, pw.deg + local);
    }
    return out;
  }

  static (double, double) _rotCw(double dx, double dy, double deg) {
    final a = deg * math.pi / 180;
    final c = math.cos(a);
    final s = math.sin(a);
    return (c * dx - s * dy, s * dx + c * dy);
  }
}
