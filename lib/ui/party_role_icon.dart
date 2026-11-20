import 'package:flutter/material.dart';

import '../models/hero.dart';
import '../models/hero_spec.dart';

/// Pixel role mark for tight fight rows: shield / cross / bow.
class PartyRoleIcon extends StatelessWidget {
  const PartyRoleIcon({
    super.key,
    required this.bucket,
    this.size = sizeDefault,
  });

  /// Readable on A56 at 1.0 and 1.45 without stealing the name row.
  static const double sizeDefault = 15;

  final PartyRoleBucket bucket;
  final double size;

  static String semanticsLabel(PartyRoleBucket bucket) => switch (bucket) {
        PartyRoleBucket.tank => 'Tank',
        PartyRoleBucket.healer => 'Healer',
        PartyRoleBucket.dps => 'DPS',
      };

  static Key keyFor(PartyRoleBucket bucket) =>
      ValueKey('party-role-icon-${bucket.name}');

  static const Color _shieldSteel = Color(0xFF5A7A9A);
  static const Color _shieldRim = Color(0xFF8CB4D8);
  static const Color _crossGold = Color(0xFFD4A83A);
  static const Color _crossGreen = Color(0xFF5A9A5A);
  static const Color _bowWood = Color(0xFF8B5A2B);
  static const Color _bowString = Color(0xFFC9A66B);

  static List<String> _rowsFor(PartyRoleBucket bucket) => switch (bucket) {
        PartyRoleBucket.tank => _kShield,
        PartyRoleBucket.healer => _kCross,
        PartyRoleBucket.dps => _kBow,
      };

  static Color? _colorFor(PartyRoleBucket bucket, String ch) => switch (bucket) {
        PartyRoleBucket.tank => switch (ch) {
            'b' => _shieldSteel,
            'B' => _shieldRim,
            _ => null,
          },
        PartyRoleBucket.healer => switch (ch) {
            'g' => _crossGold,
            'G' => _crossGreen,
            _ => null,
          },
        PartyRoleBucket.dps => switch (ch) {
            'w' => _bowWood,
            's' => _bowString,
            _ => null,
          },
      };

  @override
  Widget build(BuildContext context) {
    final label = semanticsLabel(bucket);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          key: keyFor(bucket),
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RolePixelPainter(
              rows: _rowsFor(bucket),
              colorFor: (ch) => _colorFor(bucket, ch),
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePixelPainter extends CustomPainter {
  _RolePixelPainter({required this.rows, required this.colorFor});

  final List<String> rows;
  final Color? Function(String ch) colorFor;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    final h = rows.length;
    final w = rows.first.length;
    final px = size.width / w;
    final py = size.height / h;
    for (var y = 0; y < h; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final c = colorFor(row[x]);
        if (c == null) continue;
        final paint = Paint()
          ..color = c
          ..isAntiAlias = false;
        canvas.drawRect(Rect.fromLTWH(x * px, y * py, px, py), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RolePixelPainter old) =>
      old.rows != rows || old.colorFor != colorFor;
}

/// Maps [SpecRoleTag] to the fixed party [PartyRoleBucket].
PartyRoleBucket partyRoleBucketFor(PartyHero hero) =>
    HeroSpecs.partyRole(hero.specId);

// 16×16 chunky marks — `#` in comments only; `.` = transparent.
const _kShield = <String>[
  '....bbbb....',
  '...bbbbbb...',
  '..bbbbbbbb..',
  '.bbbbbbbbbb.',
  '.bbbbbbbbbb.',
  '.bbb....bbb.',
  '.bbb....bbb.',
  '.bbbbbbbbbb.',
  '.bbbbbbbbbb.',
  '..bbbbbbbb..',
  '...bbbbbb...',
  '....bbbb....',
  '............',
  '............',
  '............',
  '............',
];

const _kCross = <String>[
  '.....g......',
  '.....g......',
  '.....g......',
  '..GGGGGGG...',
  '.....g......',
  '.....g......',
  '.....g......',
  '.....g......',
  '.....g......',
  '............',
  '............',
  '............',
  '............',
  '............',
  '............',
  '............',
];

const _kBow = <String>[
  's..........s',
  '.w........w.',
  '..w......w..',
  '...w....w...',
  '....w..w....',
  '.....ww.....',
  '....w..w....',
  '...w....w...',
  '..w......w..',
  '.w........w.',
  's..........s',
  '............',
  '............',
  '............',
  '............',
  '............',
];